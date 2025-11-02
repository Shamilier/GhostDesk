import Foundation
import os.log

final class UploadManager: NSObject {
    static let shared = UploadManager()

    private let outbox: OutboxService
    private let recordingManager: RecordingManager
    private let logger = Logger(subsystem: "ai.ghost.uploads", category: "UploadManager")

    private lazy var backgroundSession: URLSession = {
        let configuration = URLSessionConfiguration.background(withIdentifier: "ai.ghost.uploads")
        configuration.sessionSendsLaunchEvents = true
        configuration.isDiscretionary = false
        configuration.httpMaximumConnectionsPerHost = 1
        return URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
    }()

    private let foregroundSession = URLSession(configuration: .default)
    private let apiBase = URL(string: "https://api.ghostai.ru")!

    private let workQueue = DispatchQueue(label: "ai.ghost.uploads.queue")
    private var pending: [String] = []
    private var active: Set<String> = []
    private var taskContinuations: [Int: CheckedContinuation<Void, Error>] = [:]
    private var taskByLocalId: [String: URLSessionUploadTask] = [:]
    private var backgroundCompletionHandler: (() -> Void)?

    private let stateStore = UploadStateStore()
    private var hasAuth = false

    @MainActor private var authState: AuthState?

    private override init() {
        outbox = .shared
        recordingManager = .shared
        super.init()

        outbox.register { [weak self] localId in
            self?.schedule(localId: localId)
        }

        workQueue.async { [weak self] in
            guard let self else { return }
            let initial = self.outbox.pending()
            self.pending.append(contentsOf: initial)
            self.processQueue()
        }

        backgroundSession.getAllTasks { [weak self] tasks in
            guard let self else { return }
            self.workQueue.async {
                for task in tasks {
                    guard let localId = task.taskDescription else { continue }
                    if let upload = task as? URLSessionUploadTask {
                        self.taskByLocalId[localId] = upload
                        if !self.pending.contains(localId) {
                            self.pending.append(localId)
                        }
                    }
                }
                self.processQueue()
            }
        }
    }

    @MainActor
    func attachAuthState(_ auth: AuthState) {
        authState = auth
        let authorized = auth.isAuthorized
        workQueue.async { [weak self] in
            guard let self else { return }
            self.hasAuth = authorized
            if self.hasAuth {
                self.processQueue()
            }
        }
    }

    func handleBackgroundEvents(identifier: String, completionHandler: @escaping () -> Void) {
        guard identifier == "ai.ghost.uploads" else {
            completionHandler()
            return
        }
        workQueue.async { [weak self] in
            self?.backgroundCompletionHandler = completionHandler
            self?.processQueue()
        }
    }

    private func schedule(localId: String) {
        workQueue.async { [weak self] in
            guard let self else { return }
            if !self.pending.contains(localId) {
                self.pending.append(localId)
            }
            self.processQueue()
        }
    }

    private func processQueue() {
        workQueue.assertIsCurrent()
        guard hasAuth else { return }
        guard let localId = pending.first(where: { !active.contains($0) }) else { return }
        active.insert(localId)
        Task { [weak self] in
            await self?.runJob(localId: localId)
        }
    }

    private func dequeue(_ localId: String) {
        workQueue.assertIsCurrent()
        pending.removeAll { $0 == localId }
        active.remove(localId)
    }

    private func requeue(_ localId: String, after delay: TimeInterval) {
        workQueue.assertIsCurrent()
        if !pending.contains(localId) {
            pending.append(localId)
        }
        workQueue.asyncAfter(deadline: .now() + delay) { [weak self] in
            self?.processQueue()
        }
    }

    private func finishBackgroundEventsIfNeeded() {
        workQueue.assertIsCurrent()
        guard let handler = backgroundCompletionHandler else { return }
        if taskByLocalId.isEmpty {
            backgroundCompletionHandler = nil
            DispatchQueue.main.async {
                handler()
            }
        }
    }

    private func runJob(localId: String) async {
        do {
            let metadata = try recordingManager.metadata(for: localId)
            let fileURL = recordingManager.audioURL(for: localId)
            var state = stateStore.state(for: localId) ?? UploadState(stage: .pendingInit, recordingId: nil, uploadURL: nil)

            let initResult = try await ensureInit(localId: localId, metadata: metadata, state: state)
            state.recordingId = initResult.recordingId
            state.uploadURL = initResult.uploadURL.absoluteString
            if state.stage != .uploaded {
                state.stage = .uploading
                stateStore.set(state, for: localId)
                try await ensureUpload(localId: localId, fileURL: fileURL, uploadURL: initResult.uploadURL)
                state.stage = .uploaded
                stateStore.set(state, for: localId)
            } else {
                stateStore.set(state, for: localId)
            }

            try await ensureComplete(localId: localId, recordingId: initResult.recordingId, metadata: metadata)

            try recordingManager.removeSession(localId: localId)
            outbox.remove(localId: localId)
            stateStore.remove(localId: localId)
            logger.log("Upload finished for \(localId, privacy: .public)")
            workQueue.async { [weak self] in
                guard let self else { return }
                self.dequeue(localId)
                self.finishBackgroundEventsIfNeeded()
                self.processQueue()
            }
        } catch UploadError.missingAuth {
            logger.error("Upload halted for \(localId, privacy: .public) – no auth")
            workQueue.async { [weak self] in
                guard let self else { return }
                self.hasAuth = false
                self.dequeue(localId)
            }
        } catch UploadError.unauthorized {
            logger.error("Upload requires re-authentication for \(localId, privacy: .public)")
            workQueue.async { [weak self] in
                guard let self else { return }
                self.hasAuth = false
                self.dequeue(localId)
            }
        } catch UploadError.presignedExpired {
            logger.warning("Presigned URL expired for \(localId, privacy: .public); retrying init")
            stateStore.set(UploadState(stage: .pendingInit, recordingId: nil, uploadURL: nil), for: localId)
            workQueue.async { [weak self] in
                guard let self else { return }
                self.dequeue(localId)
                self.requeue(localId, after: 5)
            }
        } catch {
            logger.error("Upload failed for \(localId, privacy: .public): \(error.localizedDescription, privacy: .public)")
            workQueue.async { [weak self] in
                guard let self else { return }
                self.dequeue(localId)
                self.requeue(localId, after: 15)
            }
        }
    }

    private func ensureInit(localId: String, metadata: RecordingMetadata, state: UploadState) async throws -> (recordingId: String, uploadURL: URL) {
        if let recordingId = state.recordingId,
           let uploadString = state.uploadURL,
           let uploadURL = URL(string: uploadString),
           state.stage != .pendingInit {
            return (recordingId, uploadURL)
        }

        guard let endedAt = metadata.endedAt else {
            throw UploadError.metadataIncomplete
        }

        let body: [String: Any] = [
            "started_at": metadata.startedAt.iso8601String(),
            "ended_at": endedAt.iso8601String(),
            "lang": "ru",
            "codec": metadata.codec,
            "bitrate_kbps": metadata.bitrateKbps,
            "content_type": metadata.contentType,
            "client_request_id": localId
        ]

        let data = try JSONSerialization.data(withJSONObject: body, options: [])
        let url = apiBase.appendingPathComponent("/v1/recordings/init")
        let (responseData, http) = try await authorizedRequest(url: url, method: "POST", body: data)
        guard http.statusCode == 200 else {
            throw UploadError.http(status: http.statusCode)
        }
        let payload = try JSONSerialization.jsonObject(with: responseData) as? [String: Any]
        guard
            let dictionary = payload,
            let recordingId = dictionary["recording_id"] as? String,
            let uploadInfo = dictionary["upload"] as? [String: Any],
            let urlString = uploadInfo["url"] as? String,
            let uploadURL = URL(string: urlString)
        else {
            throw UploadError.invalidResponse
        }
        logger.log("Init ok for \(localId, privacy: .public) → recording=\(recordingId, privacy: .public)")
        return (recordingId, uploadURL)
    }

    private func ensureUpload(localId: String, fileURL: URL, uploadURL: URL) async throws {
        if let state = stateStore.state(for: localId), state.stage == .uploaded {
            return
        }

        if let existing = existingTask(for: localId) {
            logger.log("Resuming background upload for \(localId, privacy: .public)")
            try await waitFor(task: existing, autoResume: existing.state == .suspended)
            clearTask(for: localId)
            return
        }

        var request = URLRequest(url: uploadURL)
        request.httpMethod = "PUT"
        request.setValue("audio/mp4", forHTTPHeaderField: "Content-Type")
        let task = backgroundSession.uploadTask(with: request, fromFile: fileURL)
        task.taskDescription = localId
        store(task: task, for: localId)
        logger.log("Starting upload PUT for \(localId, privacy: .public)")
        try await waitFor(task: task, autoResume: true)
        clearTask(for: localId)
    }

    private func ensureComplete(localId: String, recordingId: String, metadata: RecordingMetadata) async throws {
        let url = apiBase.appendingPathComponent("/v1/recordings/complete")
        let body: [String: Any] = [
            "recording_id": recordingId,
            "size_bytes": metadata.sizeBytes
        ]
        let data = try JSONSerialization.data(withJSONObject: body, options: [])
        let (responseData, http) = try await authorizedRequest(url: url, method: "POST", body: data)
        guard (200..<300).contains(http.statusCode) else {
            throw UploadError.http(status: http.statusCode)
        }
        logger.log("Complete ok for \(localId, privacy: .public)")
        if !responseData.isEmpty {
            logger.debug("Complete response bytes: \(responseData.count, privacy: .public)")
        }
    }

    private func waitFor(task: URLSessionTask, autoResume: Bool) async throws {
        if task.state == .completed {
            try evaluate(task: task, error: task.error)
            return
        }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            workQueue.async { [weak self] in
                guard let self else { return }
                self.taskContinuations[task.taskIdentifier] = continuation
                if autoResume {
                    task.resume()
                }
            }
        }
    }

    private func existingTask(for localId: String) -> URLSessionUploadTask? {
        workQueue.sync {
            taskByLocalId[localId]
        }
    }

    private func store(task: URLSessionUploadTask, for localId: String) {
        workQueue.async { [weak self] in
            self?.taskByLocalId[localId] = task
        }
    }

    private func clearTask(for localId: String) {
        workQueue.async { [weak self] in
            guard let self else { return }
            self.taskByLocalId.removeValue(forKey: localId)
            self.finishBackgroundEventsIfNeeded()
        }
    }

    private func evaluate(task: URLSessionTask, error: Error?) throws {
        if let error {
            throw error
        }
        guard let response = task.response as? HTTPURLResponse else {
            throw UploadError.invalidResponse
        }
        guard (200..<300).contains(response.statusCode) else {
            if response.statusCode == 403 { throw UploadError.presignedExpired }
            throw UploadError.http(status: response.statusCode)
        }
    }

    private func authorizedRequest(url: URL, method: String, body: Data) async throws -> (Data, HTTPURLResponse) {
        for attempt in 0..<2 {
            let token = try await currentAccessToken()
            var request = URLRequest(url: url)
            request.httpMethod = method
            request.httpBody = body
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            ServerClient.shared.authorize(&request, token: token)

            let (data, response) = try await foregroundSession.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                throw UploadError.invalidResponse
            }
            if http.statusCode == 401 {
                if attempt == 0 {
                    try await refreshSession()
                    continue
                } else {
                    throw UploadError.unauthorized
                }
            }
            return (data, http)
        }
        throw UploadError.unauthorized
    }

    private func currentAccessToken() async throws -> String {
        try await MainActor.run { [weak self] () -> String in
            guard let auth = self?.authState, let token = auth.currentKey, !token.isEmpty else {
                throw UploadError.missingAuth
            }
            return token
        }
    }

    private func refreshSession() async throws {
        let refreshToken = try await MainActor.run { [weak self] () -> String in
            guard let auth = self?.authState, let token = auth.refreshToken, !token.isEmpty else {
                throw UploadError.missingAuth
            }
            return token
        }
        let newSession = try await AuthAPI.shared.refreshTokens(refreshToken: refreshToken)
        let profile = try await AuthAPI.shared.fetchProfile(accessToken: newSession.accessToken)
        await MainActor.run { [weak self] in
            guard let auth = self?.authState else { return }
            auth.updateSession(newSession, profile)
        }
    }
}

extension UploadManager: URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        workQueue.async { [weak self] in
            guard let self else { return }
            defer { self.finishBackgroundEventsIfNeeded() }
            let continuation = self.taskContinuations.removeValue(forKey: task.taskIdentifier)
            do {
                try self.evaluate(task: task, error: error)
                continuation?.resume()
            } catch {
                continuation?.resume(throwing: error)
            }
        }
    }
}

extension UploadManager: URLSessionDelegate {
    func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        workQueue.async { [weak self] in
            self?.finishBackgroundEventsIfNeeded()
        }
    }
}

private struct UploadState: Codable {
    enum Stage: String, Codable { case pendingInit, readyForUpload, uploading, uploaded }
    var stage: Stage
    var recordingId: String?
    var uploadURL: String?
}

private final class UploadStateStore {
    private let defaults = UserDefaults.standard
    private let key = "UploadManager.state"
    private let lock = NSLock()
    private var cache: [String: UploadState]

    init() {
        if let data = defaults.data(forKey: key), let decoded = try? JSONDecoder().decode([String: UploadState].self, from: data) {
            cache = decoded
        } else {
            cache = [:]
        }
    }

    func state(for localId: String) -> UploadState? {
        lock.lock()
        defer { lock.unlock() }
        return cache[localId]
    }

    func set(_ state: UploadState, for localId: String) {
        lock.lock()
        cache[localId] = state
        persist()
        lock.unlock()
    }

    func remove(localId: String) {
        lock.lock()
        cache.removeValue(forKey: localId)
        persist()
        lock.unlock()
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(cache) {
            defaults.set(data, forKey: key)
        }
    }
}

private enum UploadError: Error {
    case missingAuth
    case unauthorized
    case invalidResponse
    case http(status: Int)
    case metadataIncomplete
    case presignedExpired
}

extension UploadError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .missingAuth:
            return "Missing authorization token"
        case .unauthorized:
            return "Unauthorized after token refresh"
        case .invalidResponse:
            return "Invalid server response"
        case .http(let status):
            return "HTTP status \(status)"
        case .metadataIncomplete:
            return "Recording metadata is incomplete"
        case .presignedExpired:
            return "Presigned URL expired"
        }
    }
}

private extension DispatchQueue {
    func assertIsCurrent(file: StaticString = #file, line: UInt = #line) {
        dispatchPrecondition(condition: .onQueue(self))
    }
}

private extension Date {
    func iso8601String() -> String {
        ISO8601DateFormatter.uploadsFormatter.string(from: self)
    }
}

private extension ISO8601DateFormatter {
    static let uploadsFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()
}
