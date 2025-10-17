import Foundation
import AVFoundation
import CoreMedia

final class MicrophoneCaptureService: NSObject {

    // MARK: - Public types

    enum State {
        case idle
        case running
    }

    enum CaptureError: LocalizedError {
        case permissionDenied
        case noInputAvailable
        case noOutputAvailable
        case sessionStartFailed

        var errorDescription: String? {
            switch self {
            case .permissionDenied:   return "Доступ к микрофону отклонён."
            case .noInputAvailable:   return "Микрофон недоступен."
            case .noOutputAvailable:  return "Невозможно добавить аудио-выход."
            case .sessionStartFailed: return "Не удалось запустить аудио-сессию."
            }
        }
    }

    // MARK: - Public API

    /// Коллбэк с нормализованными сэмплами Float32 16kHz mono
    var onSamples: (([Float]) -> Void)?

    private(set) var state: State = .idle

    // MARK: - Init

    init(targetSampleRate: Double = 16_000,
         queueLabel: String = "MicCapture.AutoZoomLike") {
        self.targetFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32,
                                          sampleRate: targetSampleRate,
                                          channels: 1,
                                          interleaved: false)!
        self.captureQueue = DispatchQueue(label: queueLabel)
        super.init()
        observeHotPlug()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        stop()
    }

    // MARK: - Start/Stop

    /// Старт захвата: автоматически выбирает лучшее устройство (BT/USB/проводной > камера > встроенный)
    func start() async throws {
        guard state == .idle else { return }

        guard await ensureMicrophonePermission() else {
            throw CaptureError.permissionDenied
        }
        guard let device = pickBestInputDevice() else {
            throw CaptureError.noInputAvailable
        }
        try startCapture(with: device)
        state = .running
        #if DEBUG
        print("🎙️ [MicCapture] Input = \(device.localizedName)")
        #endif
    }

    func stop() {
        guard state == .running else { return }
        session?.stopRunning()
        session = nil
        deviceInput = nil
        audioOutput = nil
        converter = nil
        state = .idle
    }

    // MARK: - Private (session & conversion)

    private var session: AVCaptureSession?
    private var deviceInput: AVCaptureDeviceInput?
    private var audioOutput: AVCaptureAudioDataOutput?
    private var converter: AVAudioConverter?

    private let targetFormat: AVAudioFormat
    private let captureQueue: DispatchQueue

    private func startCapture(with device: AVCaptureDevice) throws {
        let s = AVCaptureSession()
        s.beginConfiguration()

        let input = try AVCaptureDeviceInput(device: device)
        guard s.canAddInput(input) else { throw CaptureError.noInputAvailable }
        s.addInput(input)

        let out = AVCaptureAudioDataOutput()
        out.setSampleBufferDelegate(self, queue: captureQueue)
        guard s.canAddOutput(out) else { throw CaptureError.noOutputAvailable }
        s.addOutput(out)

        s.commitConfiguration()
        s.startRunning()

        guard s.isRunning else { throw CaptureError.sessionStartFailed }

        self.session = s
        self.deviceInput = input
        self.audioOutput = out
        self.converter = nil // создадим лениво под фактический входной формат
    }

    // MARK: - Permissions

    private func ensureMicrophonePermission() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized: return true
        case .notDetermined:
            return await withCheckedContinuation { continuation in
                AVCaptureDevice.requestAccess(for: .audio) { granted in
                    continuation.resume(returning: granted)
                }
            }
        case .denied, .restricted: return false
        @unknown default: return false
        }
    }

    // MARK: - Device picking "как Zoom" (без AVAudioSession)

    /// Список «виртуальных» устройств, которые не хотим выбирать по умолчанию.
    private let virtualMarks = [
        "blackhole","loopback","soundflower","vb-audio","dante","reastream","audio hijack","aggregate"
    ]

    private func looksVirtual(_ dev: AVCaptureDevice) -> Bool {
        let n = dev.localizedName.lowercased()
        return virtualMarks.contains { n.contains($0) }
    }

    /// Эвристика: определить BT-гарнитуру по uniqueID/имени/форматам (HFP/HSP 8–16kHz mono).
    private func isBluetoothDevice(_ dev: AVCaptureDevice) -> Bool {
        let uid = dev.uniqueID.lowercased()
        if uid.contains("bluetooth") || uid.contains("hands-free") { return true }

        let n = dev.localizedName.lowercased()
        if n.contains("airpods") || n.contains("beats") || n.contains("bluetooth") || n.contains("headset") || n.contains("hands-free") {
            return true
        }

        for f in dev.formats {
            if let asbd = CMAudioFormatDescriptionGetStreamBasicDescription(f.formatDescription) {
                let sr = asbd.pointee.mSampleRate
                let ch = asbd.pointee.mChannelsPerFrame
                if (sr <= 16_000) && (ch == 1) { return true }
            }
        }
        return false
    }

    /// Баллы по имени (USB-мики, бренды и т.п.)
    private func nameScore(_ name: String) -> Int {
        let s = name.lowercased()
        if s.contains("airpods") || s.contains("beats") || s.contains("hands-free") || s.contains("headset") || s.contains("bluetooth") { return 30 }
        if s.contains("usb") || s.contains("focusrite") || s.contains("yeti") || s.contains("rode") { return 25 }
        if s.contains("camera") || s.contains("webcam") { return 10 }
        if s.contains("macbook") || s.contains("built") { return 5 }
        return 0
    }

    /// По возможностям форматов: большие sample rate и кол-во каналов — косвенно лучше тракт.
    private func capabilityScore(for dev: AVCaptureDevice) -> Int {
        var bestSR: Double = 0
        var bestCh: Int32 = 0
        for f in dev.formats {
            if let asbd = CMAudioFormatDescriptionGetStreamBasicDescription(f.formatDescription) {
                bestSR = max(bestSR, asbd.pointee.mSampleRate)
                bestCh = max(bestCh, Int32(asbd.pointee.mChannelsPerFrame))
            }
        }
        let sr = (bestSR >= 48_000 ? 40 : bestSR >= 44_100 ? 30 : bestSR >= 16_000 ? 20 : 5)
        let ch = (bestCh >= 2 ? 10 : 5)
        return sr + ch
    }

    /// Выбираем лучший доступный вход: BT/USB/проводной > камера > встроенный. Отбрасываем виртуальные.
    private func pickBestInputDevice() -> AVCaptureDevice? {
        let all = AVCaptureDevice.devices(for: .audio).filter { !looksVirtual($0) }
        guard !all.isEmpty else { return nil }

        let ranked: [(AVCaptureDevice, Int)] = all.map { d in
            var score = 0
            if isBluetoothDevice(d) { score += 100 } // жёсткий буст для BT-гарнитур
            score += nameScore(d.localizedName)
            score += capabilityScore(for: d)
            return (d, score)
        }

        return ranked.max(by: { $0.1 < $1.1 })?.0
    }

    // MARK: - Hot-plug наблюдение

    private func observeHotPlug() {
        let nc = NotificationCenter.default
        nc.addObserver(forName: .AVCaptureDeviceWasConnected, object: nil, queue: .main) { [weak self] _ in
            self?.restartOnTopologyChange()
        }
        nc.addObserver(forName: .AVCaptureDeviceWasDisconnected, object: nil, queue: .main) { [weak self] _ in
            self?.restartOnTopologyChange()
        }
    }

    private func restartOnTopologyChange() {
        guard state == .running else { return }
        stop()
        Task { try? await start() }
    }
}

// MARK: - AVCaptureAudioDataOutputSampleBufferDelegate

extension MicrophoneCaptureService: AVCaptureAudioDataOutputSampleBufferDelegate {

    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        guard CMSampleBufferDataIsReady(sampleBuffer),
              let pcmIn = sampleBuffer.asPCMBuffer() else { return }

        // Ленивая (пере)инициализация конвертера под фактический входной формат
        if converter == nil || converter?.inputFormat != pcmIn.format {
            converter = AVAudioConverter(from: pcmIn.format, to: targetFormat)
        }
        guard let converter else { return }

        let ratio = targetFormat.sampleRate / pcmIn.format.sampleRate
        let outFrames = AVAudioFrameCount(Double(pcmIn.frameLength) * ratio + 32)
        guard let out = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: outFrames) else { return }

        var provided = false
        var err: NSError?
        converter.convert(to: out, error: &err) { _, io in
            if provided {
                io.pointee = .noDataNow
                return nil
            } else {
                provided = true
                io.pointee = .haveData
                return pcmIn
            }
        }
        if let err {
            #if DEBUG
            print("[MicCapture] convert error: \(err.localizedDescription)")
            #endif
            return
        }

        guard let ch = out.floatChannelData else { return }
        let count = Int(out.frameLength)
        let samples = Array(UnsafeBufferPointer(start: ch[0], count: count))
        onSamples?(samples)
    }
}

// MARK: - Helpers

private extension CMSampleBuffer {
    /// Преобразуем CMSampleBuffer -> AVAudioPCMBuffer (входной формат устройства)
    func asPCMBuffer() -> AVAudioPCMBuffer? {
        guard let fmtDesc = CMSampleBufferGetFormatDescription(self),
              let asbd = CMAudioFormatDescriptionGetStreamBasicDescription(fmtDesc),
              let format = AVAudioFormat(streamDescription: asbd) else { return nil }

        guard let block = CMSampleBufferGetDataBuffer(self) else { return nil }

        var lengthAtOffset: Int = 0
        var totalLength: Int = 0
        var dataPointer: UnsafeMutablePointer<Int8>?
        let status = CMBlockBufferGetDataPointer(block,
                                                 atOffset: 0,
                                                 lengthAtOffsetOut: &lengthAtOffset,
                                                 totalLengthOut: &totalLength,
                                                 dataPointerOut: &dataPointer)
        guard status == kCMBlockBufferNoErr, let dataPointer else { return nil }

        let bytesPerFrame = Int(format.streamDescription.pointee.mBytesPerFrame)
        guard bytesPerFrame > 0 else { return nil }
        let frames = AVAudioFrameCount(totalLength / bytesPerFrame)

        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames) else { return nil }
        buffer.frameLength = frames

        // Копируем «как есть» — формат (int16/float32/… ) нам не важен здесь,
        // конвертация произойдёт в AVAudioConverter далее.
        let dst = buffer.audioBufferList.pointee.mBuffers.mData
        memcpy(dst, dataPointer, totalLength)

        return buffer
    }
}
