import Foundation
import AVFoundation
import CoreMedia
import Starscream

final class DeepgramStreamingProvider: NSObject, TranscriptionProvider {

    // MARK: Public API

    weak var delegate: TranscriptionProviderDelegate?

    func start() throws {
        workQueue.sync {
            guard !isRunning else { return }
            isRunning = true
            sessions[.me]   = createSession(for: .me)
            sessions[.them] = createSession(for: .them)
        }
    }

    func stop() {
        workQueue.sync {
            guard isRunning else { return }
            isRunning = false

            for context in sessions.values {
                // финализируем текущую реплику
                sendFinalize(on: context)

                // закрываем сокет
                context.socket?.disconnect()
                context.socket = nil
            }

            sessions.removeAll()
        }
    }

    func pushAudioBuffer(_ buffer: AVAudioPCMBuffer, at _: CMTime, speaker: SpeakerRole) {
        workQueue.async { [weak self] in
            guard
                let self,
                self.isRunning,
                let context = self.sessions[speaker]
            else { return }

            // конвертим входной буфер в 16-bit PCM @24kHz mono
            guard let convertedData = self.convert(buffer, using: context) else { return }

            // накапливаем
            context.pendingData.append(convertedData)

            // если накопили >= chunkByteCount — шлём чанки
            self.flushPendingDataIfNeeded(context)
        }
    }

    // MARK: Internal model

    private final class SessionContext {
        let speaker: SpeakerRole
        var socket: WebSocket?
        var converter: AVAudioConverter?
        var pendingData = Data()
        var isReady = false

        init(speaker: SpeakerRole) {
            self.speaker = speaker
        }
    }

    // MARK: Private state

    private let apiKey = "98ef6e40ddd50cd58d26e286cb9d6e36b9f228dc"

    private let endpointURL: URL
    private let workQueue = DispatchQueue(label: "DeepgramStreamingProvider.Queue")

    private var sessions: [SpeakerRole: SessionContext] = [:]
    private var isRunning = false

    private let targetFormat: AVAudioFormat
    private let chunkFrameCount: AVAudioFrameCount = 2_400 // ~100мс при 24kHz
    private let chunkByteCount: Int

    // MARK: Init

    override init() {
        var comps = URLComponents()
        comps.scheme = "wss"
        comps.host   = "api.deepgram.com"
        comps.path   = "/v1/listen"
        comps.queryItems = [
            URLQueryItem(name: "model", value: "nova-2"),
            URLQueryItem(name: "language", value: "ru"),
            URLQueryItem(name: "smart_format", value: "true"),
            URLQueryItem(name: "encoding", value: "linear16"),
            URLQueryItem(name: "sample_rate", value: "24000"),
            URLQueryItem(name: "channels", value: "1"),
            URLQueryItem(name: "interim_results", value: "true"),
            URLQueryItem(name: "endpointing", value: "100")
        ]

        guard let url = comps.url else {
            fatalError("[Deepgram] Failed to build WebSocket URL")
        }
        self.endpointURL = url

        self.targetFormat = AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: 24_000,
            channels: 1,
            interleaved: false
        )!
        self.chunkByteCount = Int(chunkFrameCount) * MemoryLayout<Int16>.size

        super.init()
    }

    // MARK: Session lifecycle

    private func createSession(for speaker: SpeakerRole) -> SessionContext {
        let context = SessionContext(speaker: speaker)

        // 1. собираем URLRequest
        var request = URLRequest(url: endpointURL)
        request.timeoutInterval = 10

        // ✅ Единственный способ авторизации: Authorization
        // apiKey = "98ef6e40..." (без слова Token внутри)
        request.setValue("token \(apiKey)", forHTTPHeaderField: "Authorization")


        // 🚫 Больше НЕ добавляем Sec-WebSocket-Protocol вообще
        // request.setValue("token, \(apiKey)", forHTTPHeaderField: "Sec-WebSocket-Protocol") <-- удалить

        // 2. создаём сокет
        let socket = WebSocket(request: request)
        socket.callbackQueue = workQueue
        socket.delegate = self

        context.socket = socket
        context.isReady = false

        // 3. коннект
        socket.connect()

        return context
    }


    /// Найти SessionContext по сокету Starscream
    private func context(for socket: any WebSocketClient) -> SessionContext? {
        // В наших сессиях мы храним конкретный Starscream.WebSocket (класс).
        // Делегат даёт нам client как "any WebSocketClient" (протокол).
        // Кастим обратно в WebSocket и сравниваем по идентичности.
        guard let realSocket = socket as? WebSocket else { return nil }
        return sessions.values.first(where: { $0.socket === realSocket })
    }

    // MARK: Deepgram inbound messages

    private func handleIncomingText(_ text: String, speaker: SpeakerRole) {
        guard
            let data = text.data(using: .utf8),
            let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let type = obj["type"] as? String
        else {
            return
        }

        guard type == "Results" else {
            return
        }

        guard
            let channel = obj["channel"] as? [String: Any],
            let alts = channel["alternatives"] as? [[String: Any]],
            let transcript = alts.first?["transcript"] as? String
        else { return }

        let cleaned = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return }

        let isFinalOuter = (obj["is_final"] as? Bool) ?? false
        let isFinalInner = (channel["is_final"] as? Bool) ?? false
        let isFinal = isFinalOuter || isFinalInner

        if isFinal {
            delegate?.provider(self, didFinishUtterance: cleaned, speaker: speaker)
        } else {
            delegate?.provider(self, didUpdatePartial: cleaned, speaker: speaker)
        }
    }

    // MARK: Audio convert & send

    private func convert(_ buffer: AVAudioPCMBuffer, using context: SessionContext) -> Data? {
        let inputFormat = buffer.format

        if context.converter == nil || context.converter?.inputFormat != inputFormat {
            context.converter = AVAudioConverter(from: inputFormat, to: targetFormat)
        }
        guard let converter = context.converter else { return nil }

        let ratio = targetFormat.sampleRate / inputFormat.sampleRate
        let capacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio + 32)

        guard let pcmOut = AVAudioPCMBuffer(pcmFormat: targetFormat,
                                            frameCapacity: capacity) else { return nil }

        var error: NSError?
        var provided = false
        converter.convert(to: pcmOut, error: &error) { _, outStatus in
            defer { provided = true }
            outStatus.pointee = provided ? .noDataNow : .haveData
            return provided ? nil : buffer
        }

        if let error {
            print("[Deepgram] converter error: \(error.localizedDescription)")
            return nil
        }

        guard let channelData = pcmOut.int16ChannelData else { return nil }
        let frameLength = Int(pcmOut.frameLength)
        guard frameLength > 0 else { return nil }

        return Data(bytes: channelData[0],
                    count: frameLength * MemoryLayout<Int16>.size)
    }

    private func flushPendingDataIfNeeded(_ context: SessionContext) {
        guard
            context.isReady,
            let socket = context.socket
        else {
            return
        }

        while context.pendingData.count >= chunkByteCount {
            // 1. Берём первые chunkByteCount байт как слайс
            let slice = context.pendingData.prefix(chunkByteCount)

            // 2. Делаем ИМЕННО копию в новый Data,
            //    чтобы он больше не зависел от context.pendingData
            let sendData = Data(slice)

            // 3. Удаляем отправленные байты из очереди
            context.pendingData.removeFirst(chunkByteCount)

            // 4. Пишем уже стабильный буфер
            socket.write(data: sendData)
        }
    }


    private func sendFinalize(on context: SessionContext) {
        guard let socket = context.socket else { return }
        let finalizeJSON = #"{"type":"Finalize"}"#
        socket.write(string: finalizeJSON)
    }
}

// MARK: - Starscream WebSocketDelegate (новый стиль)
extension DeepgramStreamingProvider: WebSocketDelegate {
    func didReceive(event: WebSocketEvent, client: any WebSocketClient) {
        workQueue.async { [weak self] in
            guard let self else { return }
            guard let ctx = self.context(for: client) else { return }

            switch event {

            case .connected(_):
                ctx.isReady = true
                print("[Deepgram][\(ctx.speaker)] CONNECTED ✅")
                // если мы успели накопить аудио до connect — выливаем
                self.flushPendingDataIfNeeded(ctx)

            case .disconnected(let reason, let code):
                ctx.isReady = false
                print("[Deepgram][\(ctx.speaker)] DISCONNECTED ❌ reason=\(reason) code=\(code)")

            case .text(let text):
                // Deepgram шлёт распознанный текст как JSON-строку
                self.handleIncomingText(text, speaker: ctx.speaker)

            case .binary(let data):
                // иногда может прилететь бинарь, попробуем трактовать как UTF-8 json
                if let asString = String(data: data, encoding: .utf8) {
                    self.handleIncomingText(asString, speaker: ctx.speaker)
                } else {
                    print("[Deepgram][\(ctx.speaker)] << binary \(data.count) bytes (ignored)")
                }

            case .ping(_),
                 .pong(_):
                // сервисные heartbeat события, можно игнорить
                break

            case .viabilityChanged(let ok):
                print("[Deepgram][\(ctx.speaker)] viabilityChanged=\(ok)")

            case .reconnectSuggested(let shouldReconnect):
                print("[Deepgram][\(ctx.speaker)] reconnectSuggested=\(shouldReconnect)")

            case .cancelled:
                ctx.isReady = false
                print("[Deepgram][\(ctx.speaker)] CANCELLED ❌")

            case .error(let err):
                ctx.isReady = false
                print("[Deepgram][\(ctx.speaker)] ERROR ❌ \(String(describing: err))")

            case .peerClosed:
                // новое событие в твоей версии Starscream:
                // сервер закрыл соединение своей стороной
                ctx.isReady = false
                print("[Deepgram][\(ctx.speaker)] PEER CLOSED ❌")
            }
        }
    }
}
