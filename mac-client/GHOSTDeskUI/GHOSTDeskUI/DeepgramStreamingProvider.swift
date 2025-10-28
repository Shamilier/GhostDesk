import Foundation
import AVFoundation
import CoreMedia

final class DeepgramStreamingProvider: NSObject, TranscriptionProvider {
    weak var delegate: TranscriptionProviderDelegate?

    private final class SessionContext {
        let speaker: SpeakerRole
        var task: URLSessionWebSocketTask?
        var converter: AVAudioConverter?
        var pendingData = Data()
        var isListening = false

        init(speaker: SpeakerRole) {
            self.speaker = speaker
        }
    }

    private let apiKey: String
    private let endpointURL: URL
    private let urlSession: URLSession
    private let workQueue = DispatchQueue(label: "DeepgramStreamingProvider.Queue")
    private var sessions: [SpeakerRole: SessionContext] = [:]
    private var isRunning = false

    private let targetFormat: AVAudioFormat
    private let chunkFrameCount: AVAudioFrameCount = 2_400
    private let chunkByteCount: Int

    init(apiKey: String = "98ef6e40ddd50cd58d26e286cb9d6e36b9f228dc") {
        var components = URLComponents()
        components.scheme = "wss"
        components.host = "api.deepgram.com"
        components.path = "/v1/listen"
        components.queryItems = [
            URLQueryItem(name: "model", value: "nova-3"),
            URLQueryItem(name: "language", value: "ru"),
            URLQueryItem(name: "smart_format", value: "true"),
            URLQueryItem(name: "encoding", value: "linear16"),
            URLQueryItem(name: "sample_rate", value: "24000"),
            URLQueryItem(name: "channels", value: "1"),
            URLQueryItem(name: "interim_results", value: "true"),
            URLQueryItem(name: "endpointing", value: "100")
        ]
        self.endpointURL = components.url!
        self.apiKey = apiKey
        self.urlSession = URLSession(configuration: .default)
        self.targetFormat = AVAudioFormat(commonFormat: .pcmFormatInt16,
                                          sampleRate: 24_000,
                                          channels: 1,
                                          interleaved: false)!
        self.chunkByteCount = Int(chunkFrameCount) * MemoryLayout<Int16>.size
        super.init()
    }

    func start() throws {
        workQueue.sync {
            guard !isRunning else { return }
            isRunning = true
            sessions[.me] = createSession(for: .me)
            sessions[.them] = createSession(for: .them)
        }
    }

    func stop() {
        workQueue.sync {
            guard isRunning else { return }
            isRunning = false
            for context in sessions.values {
                guard let task = context.task else { continue }
                if !context.pendingData.isEmpty {
                    let data = context.pendingData
                    context.pendingData.removeAll()
                    task.send(.data(data)) { _ in }
                }
                task.send(.string("{\"type\":\"Finalize\"}")) { _ in
                    task.cancel(with: .goingAway, reason: nil)
                }
            }
            sessions.removeAll()
        }
    }

    func pushAudioBuffer(_ buffer: AVAudioPCMBuffer, at _: CMTime, speaker: SpeakerRole) {
        workQueue.async { [weak self] in
            guard let self, self.isRunning, let context = self.sessions[speaker] else { return }
            guard let converted = self.convert(buffer, using: context) else { return }
            context.pendingData.append(converted)
            self.flushPendingDataIfNeeded(context)
        }
    }

    // MARK: - Session lifecycle

    private func createSession(for speaker: SpeakerRole) -> SessionContext {
        let context = SessionContext(speaker: speaker)
        var request = URLRequest(url: endpointURL)
        request.addValue("Token \(apiKey)", forHTTPHeaderField: "Authorization")
        let task = urlSession.webSocketTask(with: request)
        context.task = task
        task.resume()
        listen(for: context)
        return context
    }

    private func listen(for context: SessionContext) {
        guard let task = context.task else { return }
        context.isListening = true
        task.receive { [weak self] result in
            guard let self else { return }
            switch result {
            case .failure:
                break
            case .success(let message):
                self.handle(message: message, speaker: context.speaker)
                self.listen(for: context)
            }
        }
    }

    // MARK: - Conversion & sending

    private func convert(_ buffer: AVAudioPCMBuffer, using context: SessionContext) -> Data? {
        let inputFormat = buffer.format
        if context.converter == nil || context.converter?.inputFormat != inputFormat {
            context.converter = AVAudioConverter(from: inputFormat, to: targetFormat)
        }
        guard let converter = context.converter else { return nil }

        let ratio = targetFormat.sampleRate / inputFormat.sampleRate
        let capacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio + 32)
        guard let pcmOut = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: capacity) else { return nil }

        var error: NSError?
        var provided = false
        converter.convert(to: pcmOut, error: &error) { _, outStatus in
            defer { provided = true }
            outStatus.pointee = provided ? .noDataNow : .haveData
            return provided ? nil : buffer
        }

        if let error { print("[Deepgram] converter error: \(error.localizedDescription)"); return nil }
        guard let channelData = pcmOut.int16ChannelData else { return nil }
        let frameLength = Int(pcmOut.frameLength)
        guard frameLength > 0 else { return nil }
        return Data(bytes: channelData[0], count: frameLength * MemoryLayout<Int16>.size)
    }

    private func flushPendingDataIfNeeded(_ context: SessionContext) {
        guard let task = context.task else { return }
        while context.pendingData.count >= chunkByteCount {
            let chunk = context.pendingData.prefix(chunkByteCount)
            context.pendingData.removeFirst(chunkByteCount)
            task.send(.data(chunk)) { error in
                if let error {
                    print("[Deepgram] send error: \(error.localizedDescription)")
                }
            }
        }
    }

    // MARK: - Message handling

    private func handle(message: URLSessionWebSocketTask.Message, speaker: SpeakerRole) {
        workQueue.async { [weak self] in
            guard let self else { return }

            let data: Data
            switch message {
            case .data(let d):
                data = d
            case .string(let string):
                guard let d = string.data(using: .utf8) else { return }
                data = d
            @unknown default:
                return
            }

            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
            guard let type = json["type"] as? String else { return }
            guard type == "transcript" else { return }

            guard
                let channel = json["channel"] as? [String: Any],
                let alternatives = channel["alternatives"] as? [[String: Any]],
                let transcript = alternatives.first?["transcript"] as? String
            else { return }

            let trimmed = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return }

            let isFinal = (channel["is_final"] as? Bool) ?? (json["is_final"] as? Bool) ?? false
            if isFinal {
                self.delegate?.provider(self, didFinishUtterance: trimmed, speaker: speaker)
            } else {
                self.delegate?.provider(self, didUpdatePartial: trimmed, speaker: speaker)
            }
        }
    }
}
