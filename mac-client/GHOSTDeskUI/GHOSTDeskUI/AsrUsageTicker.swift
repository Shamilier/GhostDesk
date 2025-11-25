import Foundation
import os.log

@MainActor
final class AsrUsageTicker {
    static let shared = AsrUsageTicker()

    private let logger = Logger(subsystem: "ai.ghost.recorder", category: "AsrUsageTicker")
    private let baseURL = URL(string: "https://api.ghostai.ru")!
    private let session: URLSession

    private(set) var isRunning = false
    private(set) var startDate: Date?
    private var timer: Timer?
    private weak var authState: AuthState?
    private var inFlightTask: Task<Void, Never>?

    private(set) var lastKnownTokenBalance: Int?
    private(set) var lastInsufficientTokensMessage: String?

    var onInsufficientTokens: (() -> Void)?

    init(session: URLSession = .shared) {
        self.session = session
    }

    func start(authState: AuthState) {
        guard !isRunning else { return }
        guard authState.currentKey?.isEmpty == false else {
            logger.error("Attempted to start ASR usage ticker without access token")
            return
        }

        self.authState = authState
        startDate = Date()
        isRunning = true
        lastKnownTokenBalance = nil
        scheduleTimer()
        logger.debug("ASR usage ticker started at \(String(describing: self.startDate), privacy: .public)")
    }

    func stop() {
        stopInternal(preserveMessage: false)
    }
}

@MainActor
private extension AsrUsageTicker {
    func scheduleTimer() {
        timer?.invalidate()
        let timer = Timer(timeInterval: 60, repeats: true) { [weak self] _ in
            self?.handleTimerFire()
        }
        self.timer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    func handleTimerFire() {
        guard isRunning else { return }
        guard inFlightTask == nil else {
            logger.debug("Skipping ASR usage tick — previous request still running")
            return
        }
        guard let authState else {
            logger.error("ASR usage ticker has no auth state while running; stopping")
            stopInternal(preserveMessage: false)
            return
        }

        let client = UsageAPIClient(baseURL: baseURL, authState: authState, session: session)
        inFlightTask = Task { [weak self] in
            guard let self else { return }
            await self.performTick(using: client, authState: authState)
        }
    }

    func performTick(using client: UsageAPIClient, authState: AuthState) async {
        do {
            let balance = try await client.sendAsrTick()
            await MainActor.run {
                self.lastKnownTokenBalance = balance
                self.lastInsufficientTokensMessage = nil
                self.logger.debug("ASR usage tick succeeded, balance=\(balance, privacy: .public)")
                self.inFlightTask = nil
            }
        } catch let error as UsageError {
            await MainActor.run {
                self.logger.error("ASR usage tick failed with usage error: \(error.localizedDescription, privacy: .public)")
                self.handleUsageError(error, authState: authState)
                self.inFlightTask = nil
            }
        } catch is CancellationError {
            await MainActor.run {
                self.logger.debug("ASR usage tick request cancelled")
                self.inFlightTask = nil
            }
        } catch {
            await MainActor.run {
                self.logger.error("ASR usage tick failed: \(error.localizedDescription, privacy: .public)")
                self.inFlightTask = nil
            }
        }
    }

    func handleUsageError(_ error: UsageError, authState: AuthState) {
        switch error {
        case let .insufficientTokens(message, _):
            lastInsufficientTokensMessage = message
            stopInternal(preserveMessage: true)
            onInsufficientTokens?()
        case .unauthorized:
            stopInternal(preserveMessage: false)
            _ = ServerClient.shared.handleUnauthorizedStatus(401, auth: authState)
        case .server:
            break
        }
    }

    func stopInternal(preserveMessage: Bool) {
        timer?.invalidate()
        timer = nil
        inFlightTask?.cancel()
        inFlightTask = nil
        isRunning = false
        startDate = nil
        authState = nil
        if !preserveMessage {
            lastInsufficientTokensMessage = nil
        }
    }
}
