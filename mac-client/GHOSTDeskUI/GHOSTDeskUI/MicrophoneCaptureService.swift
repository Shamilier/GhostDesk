import Foundation
import AVFoundation

final class MicrophoneCaptureService {
    enum State {
        case idle
        case running
    }

    enum CaptureError: LocalizedError {
        case permissionDenied
        case noInputAvailable
        case engineStartFailed(Error)

        var errorDescription: String? {
            switch self {
            case .permissionDenied:
                return "Доступ к микрофону отклонён."
            case .noInputAvailable:
                return "Микрофон недоступен."
            case .engineStartFailed(let error):
                return "Не удалось запустить аудио-движок: \(error.localizedDescription)"
            }
        }
    }

    private let engine = AVAudioEngine()
    private var converter: AVAudioConverter?
    private let targetFormat: AVAudioFormat
    private let processingQueue: DispatchQueue
    private let tapBufferSize: AVAudioFrameCount
    private var state: State = .idle
    private var routeChangeObserver: NSObjectProtocol?

    var onSamples: (([Float]) -> Void)?

    init(targetSampleRate: Double = 16_000,
         bufferSize: AVAudioFrameCount = 2048,
         queueLabel: String = "MicrophoneCaptureService") {
        self.targetFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32,
                                          sampleRate: targetSampleRate,
                                          channels: 1,
                                          interleaved: false)!
        self.tapBufferSize = bufferSize
        self.processingQueue = DispatchQueue(label: queueLabel)

        configureAudioRouteNotifications()
    }

    func start() async throws {
        guard state == .idle else { return }

        guard await ensureMicrophonePermission() else {
            throw CaptureError.permissionDenied
        }

        await configurePreferredInputRoute()

        let inputNode = engine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)
        guard inputFormat.channelCount > 0 else {
            throw CaptureError.noInputAvailable
        }

        converter = nil
        inputNode.removeTap(onBus: 0)

        inputNode.installTap(onBus: 0,
                              bufferSize: tapBufferSize,
                              format: inputFormat) { [weak self] buffer, _ in
            guard let self else { return }
            guard let copied = buffer.copy() else { return }
            self.processingQueue.async {
                self.process(buffer: copied)
            }
        }

        engine.prepare()
        do {
            try engine.start()
            state = .running
        } catch {
            inputNode.removeTap(onBus: 0)
            throw CaptureError.engineStartFailed(error)
        }
    }

    func stop() {
        guard state == .running else { return }
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        converter = nil
        state = .idle
    }

    deinit {
        if let routeChangeObserver {
            NotificationCenter.default.removeObserver(routeChangeObserver)
        }
    }

    private func ensureMicrophonePermission() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            return true
        case .notDetermined:
            return await withCheckedContinuation { continuation in
                AVCaptureDevice.requestAccess(for: .audio) { granted in
                    continuation.resume(returning: granted)
                }
            }
        case .denied, .restricted:
            return false
        @unknown default:
            return false
        }
    }

    private func process(buffer: AVAudioPCMBuffer) {
        if converter == nil || converter?.inputFormat != buffer.format {
            converter = AVAudioConverter(from: buffer.format, to: targetFormat)
        }

        guard let converter else { return }

        let ratio = targetFormat.sampleRate / buffer.format.sampleRate
        let capacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio + 32)
        guard let outBuffer = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: capacity) else { return }

        var error: NSError?
        var provided = false
        converter.convert(to: outBuffer, error: &error) { _, outStatus in
            defer { provided = true }
            outStatus.pointee = provided ? .noDataNow : .haveData
            return provided ? nil : buffer
        }

        if let error { print("[MicrophoneCapture] converter error: \(error.localizedDescription)"); return }
        guard let channelData = outBuffer.floatChannelData else { return }
        let frames = Int(outBuffer.frameLength)
        let samples = Array(UnsafeBufferPointer(start: channelData[0], count: frames))
        onSamples?(samples)
    }
}

// MARK: - Audio Route Management

private extension MicrophoneCaptureService {
    func configureAudioRouteNotifications() {
        guard #available(macOS 10.15, *) else { return }
        routeChangeObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: nil,
            queue: nil
        ) { [weak self] _ in
            Task { [weak self] in
                await self?.configurePreferredInputRoute()
            }
        }
    }

    func configurePreferredInputRoute() async {
        guard #available(macOS 10.15, *) else { return }
        await MainActor.run {
            let session = AVAudioSession.sharedInstance()
            do {
                try session.setCategory(.playAndRecord, mode: .voiceChat, options: [])
                try session.setActive(true, options: [])
                if let preferredPort = preferredInputPort(from: session.availableInputs) {
                    try session.setPreferredInput(preferredPort)
                }
            } catch {
                print("[MicrophoneCapture] audio route configuration error: \(error.localizedDescription)")
            }
        }
    }

    func preferredInputPort(from inputs: [AVAudioSessionPortDescription]?) -> AVAudioSessionPortDescription? {
        guard let inputs else { return nil }
        let priorityOrder: [AVAudioSession.Port] = {
            if #available(macOS 11.0, *) {
                return [.bluetoothHFP, .bluetoothLE, .bluetoothA2DP, .headsetMic]
            } else {
                return [.bluetoothHFP, .headsetMic]
            }
        }()

        for port in priorityOrder {
            if let match = inputs.first(where: { $0.portType == port }) {
                return match
            }
        }

        return inputs.first
    }
}

private extension AVAudioPCMBuffer {
    func copy() -> AVAudioPCMBuffer? {
        guard let newBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameLength) else { return nil }
        newBuffer.frameLength = frameLength

        guard let src = floatChannelData, let dst = newBuffer.floatChannelData else { return nil }
        let channels = Int(format.channelCount)
        let frames = Int(frameLength)
        for ch in 0..<channels {
            memcpy(dst[ch], src[ch], frames * MemoryLayout<Float>.size)
        }
        return newBuffer
    }
}
