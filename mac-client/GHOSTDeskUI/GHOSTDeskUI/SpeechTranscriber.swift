import Foundation
import Combine
import WhisperKit
import ScreenCaptureKit
import AVFoundation
import CoreMedia
import CoreML
import CoreGraphics

final class SpeechTranscriber: NSObject, ObservableObject {

    enum CaptureMode {
        case systemAudio
        case microphone
    }

    enum Phase { case idle, starting, running, stopping }

    @Published private(set) var phase: Phase = .idle
    @Published private(set) var transcriptLog: [OverlayModel.TranscriptMessage] = []
    @Published private(set) var partialText: String = ""
    @Published var lastError: String?
    @Published private(set) var isTranscribing = false

    var isTranscribingLegacy: Bool { isTranscribing }

    private let captureMode: CaptureMode
    private let sourceKind: OverlayModel.AudioSourceKind
    private let speakerRole: SpeakerRole
    private let config: TranscriptionConfig

    private var provider: TranscriptionProvider?
    private var localProvider: WhisperLocalProvider?
    private var providerSubscriptions: Set<AnyCancellable> = []

    private let outputQueue: DispatchQueue
    private var stream: SCStream?
    private var microphoneService: MicrophoneCaptureService?
    private let noopVideoSink = NoopVideoSink()
    private var converter: AVAudioConverter?

    private let targetSampleRate = 24_000.0
    private lazy var targetFormat: AVAudioFormat = {
        AVAudioFormat(commonFormat: .pcmFormatFloat32,
                      sampleRate: targetSampleRate,
                      channels: 1,
                      interleaved: false)!
    }()

    init(captureMode: CaptureMode, config: TranscriptionConfig = TranscriptionConfig()) {
        self.captureMode = captureMode
        self.config = config
        switch captureMode {
        case .systemAudio:
            self.sourceKind = .system
            self.speakerRole = .them
            self.outputQueue = DispatchQueue(label: "SystemAudio.StreamOutput.Deepgram")
        case .microphone:
            self.sourceKind = .microphone
            self.speakerRole = .me
            self.outputQueue = DispatchQueue(label: "MicrophoneAudio.StreamOutput.Deepgram")
        }
        super.init()
    }

    override convenience init() {
        self.init(captureMode: .systemAudio)
    }

    // MARK: - Public API

    @MainActor
    func clearLog() {
        switch config.provider {
        case .whisperLocal:
            localProvider?.clearLog()
        case .deepgram:
            transcriptLog.removeAll()
            partialText = ""
            TranscriptBuffer.shared.clear()
            TranscriptBuffer.shared.setPartial("", at: Date())
        }
    }

    func start() {
        guard phase == .idle else { return }
        lastError = nil
        phase = .starting

        switch config.provider {
        case .whisperLocal:
            startLocalProvider()
        case .deepgram:
            startDeepgramProvider()
        }
    }

    func stop() {
        switch config.provider {
        case .whisperLocal:
            localProvider?.stop()
        case .deepgram:
            stopDeepgramProvider()
        }
    }

    // MARK: - Provider wiring
    private func mapLocalPhase(_ p: WhisperLocalProvider.Phase) -> Phase {
        switch p {
        case .idle:     return .idle
        case .starting: return .starting
        case .running:  return .running
        case .stopping: return .stopping
        }
    }

    private func startLocalProvider() {
        let localMode: WhisperLocalProvider.CaptureMode = captureMode == .systemAudio ? .systemAudio : .microphone
        let provider = WhisperLocalProvider(captureMode: localMode)
        localProvider = provider
        self.provider = provider
        provider.delegate = self

        providerSubscriptions.removeAll()
        transcriptLog = provider.transcriptLog
        partialText = provider.partialText
        lastError = provider.lastError
        isTranscribing = provider.isTranscribing


        provider.$phase
            .receive(on: DispatchQueue.main)
            .sink { [weak self] localPhase in
                self?.phase = self?.mapLocalPhase(localPhase) ?? .idle
            }
            .store(in: &providerSubscriptions)


        provider.$transcriptLog
            .receive(on: DispatchQueue.main)
            .sink { [weak self] log in self?.transcriptLog = log }
            .store(in: &providerSubscriptions)

        provider.$partialText
            .receive(on: DispatchQueue.main)
            .sink { [weak self] partial in self?.partialText = partial }
            .store(in: &providerSubscriptions)

        provider.$lastError
            .receive(on: DispatchQueue.main)
            .sink { [weak self] error in self?.lastError = error }
            .store(in: &providerSubscriptions)

        provider.$isTranscribing
            .receive(on: DispatchQueue.main)
            .sink { [weak self] value in self?.isTranscribing = value }
            .store(in: &providerSubscriptions)

        do {
            try provider.start()
        } catch {
            DispatchQueue.main.async { [weak self] in
                self?.phase = .idle
                self?.lastError = error.localizedDescription
                self?.isTranscribing = false
            }
        }
    }

    private func startDeepgramProvider() {
        let provider = DeepgramStreamingProvider()
        provider.delegate = self
        self.provider = provider
        partialText = ""
        TranscriptBuffer.shared.setPartial("", at: Date())

        do {
            try provider.start()
        } catch {
            phase = .idle
            lastError = "Не удалось подключиться к Deepgram: \(error.localizedDescription)"
            self.provider = nil
            return
        }

        Task {
            do {
                switch captureMode {
                case .systemAudio:
                    guard ensureScreenRecordingAuthorizedForStreaming() else {
                        throw NSError(domain: "Deepgram", code: 1,
                                      userInfo: [NSLocalizedDescriptionKey: "Доступ к записи экрана не выдан. Включи и перезапусти приложение."])
                    }
                    try await startSystemAudioStream()
                case .microphone:
                    try await startMicrophoneStream()
                }

                await MainActor.run {
                    guard self.phase == .starting else { return }
                    self.phase = .running
                    self.isTranscribing = true
                }
            } catch {
                await MainActor.run {
                    self.lastError = error.localizedDescription
                    self.phase = .idle
                    self.isTranscribing = false
                }
                provider.stop()
            }
        }
    }

    private func stopDeepgramProvider() {
        guard phase == .running || phase == .starting else { return }
        phase = .stopping

        switch captureMode {
        case .systemAudio:
            let s = stream
            stream = nil
            Task { try? await s?.stopCapture() }
        case .microphone:
            microphoneService?.stop()
            microphoneService?.onSamples = nil
        }
        converter = nil

        provider?.stop()
        provider = nil

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.isTranscribing = false
            self.partialText = ""
            TranscriptBuffer.shared.setPartial("", at: Date())
            self.phase = .idle
        }
    }

    // MARK: - Capture -> Deepgram

    private func startMicrophoneStream() async throws {
        let service: MicrophoneCaptureService
        if let existing = microphoneService {
            service = existing
        } else {
            let created = MicrophoneCaptureService(targetSampleRate: targetSampleRate,
                                                   queueLabel: "MicrophoneCaptureService.Deepgram")
            microphoneService = created
            service = created
        }

        service.onSamples = { [weak self] samples in
            guard let self else { return }
            self.outputQueue.async {
                self.handleMicrophoneSamples(samples)
            }
        }

        try await service.start()
    }

    private func handleMicrophoneSamples(_ samples: [Float]) {
        guard let provider else { return }
        guard !samples.isEmpty else { return }

        let frameCount = AVAudioFrameCount(samples.count)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: frameCount) else { return }
        buffer.frameLength = frameCount
        samples.withUnsafeBufferPointer { ptr in
            if let channel = buffer.floatChannelData?[0], let base = ptr.baseAddress {
                channel.assign(from: base, count: Int(frameCount))
            }
        }
        provider.pushAudioBuffer(buffer, at: .invalid, speaker: speakerRole)
    }

    private func startSystemAudioStream() async throws {
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        guard let display = content.displays.first else {
            throw NSError(domain: "Deepgram", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "Нет доступных дисплеев"])
        }

        let filter = SCContentFilter(display: display, excludingWindows: [])
        let cfg = SCStreamConfiguration()
        cfg.capturesAudio = true
        cfg.excludesCurrentProcessAudio = true
        cfg.sampleRate = 44_100
        cfg.channelCount = 2
        cfg.width = 8
        cfg.height = 8
        cfg.showsCursor = false

        let stream = SCStream(filter: filter, configuration: cfg, delegate: self)
        self.stream = stream
        converter = nil

        try stream.addStreamOutput(noopVideoSink, type: .screen, sampleHandlerQueue: outputQueue)
        try stream.addStreamOutput(self, type: .audio, sampleHandlerQueue: outputQueue)
        try await stream.startCapture()
    }

    private func handleSystemBuffer(_ sampleBuffer: CMSampleBuffer) {
        guard let provider else { return }
        guard CMSampleBufferDataIsReady(sampleBuffer),
              let pcmIn = sampleBuffer.toPCMBuffer() else { return }

        if converter == nil || converter?.inputFormat != pcmIn.format {
            converter = AVAudioConverter(from: pcmIn.format, to: targetFormat)
        }
        guard let converter else { return }

        let ratio = targetFormat.sampleRate / pcmIn.format.sampleRate
        let capacity = AVAudioFrameCount(Double(pcmIn.frameLength) * ratio + 32)
        guard let pcmOut = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: capacity) else { return }

        var error: NSError?
        var provided = false
        converter.convert(to: pcmOut, error: &error) { _, outStatus in
            defer { provided = true }
            outStatus.pointee = provided ? .noDataNow : .haveData
            return provided ? nil : pcmIn
        }

        if error != nil { return }
        provider.pushAudioBuffer(pcmOut, at: .invalid, speaker: speakerRole)
    }

    // MARK: - Transcript Helpers

    @MainActor
    private func appendFinal(_ text: String) {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }

        let now = Date()

        if let lastIndex = transcriptLog.indices.last,
           transcriptLog[lastIndex].source == sourceKind {
            let lastMessage = transcriptLog[lastIndex]
            let mergedText = TranscriptBuffer.mergeSegments(base: lastMessage.text, addition: clean)
            let updated = OverlayModel.TranscriptMessage(
                id: lastMessage.id,
                source: lastMessage.source,
                text: mergedText,
                timestamp: now
            )
            transcriptLog[lastIndex] = updated
            TranscriptBuffer.shared.replaceLastFinal(with: mergedText, at: now)
        } else {
            let message = OverlayModel.TranscriptMessage(source: sourceKind, text: clean, timestamp: now)
            transcriptLog.append(message)
            TranscriptBuffer.shared.appendFinal(clean, at: now)
        }
    }

}

extension SpeechTranscriber: TranscriptionProviderDelegate {
    func provider(_ provider: TranscriptionProvider, didUpdatePartial text: String, speaker: SpeakerRole) {
        guard speaker == speakerRole else { return }
        DispatchQueue.main.async { [weak self] in
            self?.partialText = text
            TranscriptBuffer.shared.setPartial(text, at: Date())
        }
    }

    func provider(_ provider: TranscriptionProvider, didFinishUtterance text: String, speaker: SpeakerRole) {
        guard speaker == speakerRole else { return }
        DispatchQueue.main.async { [weak self] in
            self?.partialText = ""
            TranscriptBuffer.shared.setPartial("", at: Date())
            self?.appendFinal(text)
        }
    }
}

extension SpeechTranscriber: SCStreamDelegate {}

extension SpeechTranscriber: SCStreamOutput {
    func stream(_ stream: SCStream,
                didOutputSampleBuffer sampleBuffer: CMSampleBuffer,
                of outputType: SCStreamOutputType) {
        guard outputType == .audio else { return }
        handleSystemBuffer(sampleBuffer)
    }
}

// MARK: - Audio utilities

fileprivate extension CMSampleBuffer {
    func toPCMBuffer() -> AVAudioPCMBuffer? {
        guard let fdesc = CMSampleBufferGetFormatDescription(self) else { return nil }

        // На твоём SDK это non-optional
        let format = AVAudioFormat(cmAudioFormatDescription: fdesc)

        let frames = AVAudioFrameCount(CMSampleBufferGetNumSamples(self))
        guard let buf = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames) else { return nil }
        buf.frameLength = frames

        let status = CMSampleBufferCopyPCMDataIntoAudioBufferList(
            self,
            at: 0,
            frameCount: Int32(frames),
            into: buf.mutableAudioBufferList
        )

        return status == noErr ? buf : nil
    }
}



private func ensureScreenRecordingAuthorizedForStreaming() -> Bool {
    if CGPreflightScreenCaptureAccess() { return true }
    return CGRequestScreenCaptureAccess()
}

// MARK: - Legacy helpers

extension SpeechTranscriber {
    static func loadAudio(fromPath audioFilePath: String,
                          channelMode: ChannelMode,
                          startTime: Double?,
                          endTime: Double?,
                          maxReadFrameSize: AVAudioFrameCount?) throws -> AVAudioPCMBuffer {
        try WhisperLocalProvider.loadAudio(fromPath: audioFilePath,
                                           channelMode: channelMode,
                                           startTime: startTime,
                                           endTime: endTime,
                                           maxReadFrameSize: maxReadFrameSize)
    }

    static func loadAudio(at audioPaths: [String],
                          channelMode: ChannelMode) async -> [Result<[Float], any Error>] {
        await WhisperLocalProvider.loadAudio(at: audioPaths, channelMode: channelMode)
    }

    static func padOrTrimAudio(fromArray audioArray: [Float],
                               startAt startIndex: Int,
                               toLength frameLength: Int,
                               saveSegment: Bool) -> MLMultiArray? {
        WhisperLocalProvider.padOrTrimAudio(fromArray: audioArray,
                                            startAt: startIndex,
                                            toLength: frameLength,
                                            saveSegment: saveSegment)
    }

    func padOrTrim(fromArray audioArray: [Float],
                   startAt startIndex: Int,
                   toLength frameLength: Int) -> (any AudioProcessorOutputType)? {
        WhisperLocalProvider.padOrTrimAudio(fromArray: audioArray,
                                            startAt: startIndex,
                                            toLength: frameLength,
                                            saveSegment: false)
    }

    var audioSamples: ContiguousArray<Float> {
        localProvider?.audioSamples ?? []
    }

    func purgeAudioSamples(keepingLast keep: Int) {
        localProvider?.purgeAudioSamples(keepingLast: keep)
    }

    var relativeEnergy: [Float] {
        localProvider?.relativeEnergy ?? []
    }

    var relativeEnergyWindow: Int {
        get { localProvider?.relativeEnergyWindow ?? 0 }
        set { localProvider?.relativeEnergyWindow = newValue }
    }

    func startRecordingLive(inputDeviceID: DeviceID? = nil,
                            callback: (([Float]) -> Void)?) throws {
        try localProvider?.startRecordingLive(inputDeviceID: inputDeviceID, callback: callback)
    }

    func pauseRecording() {
        localProvider?.pauseRecording()
    }

    func stopRecording() {
        localProvider?.stopRecording()
    }

    func resumeRecordingLive(inputDeviceID: DeviceID? = nil,
                             callback: (([Float]) -> Void)?) throws {
        try localProvider?.resumeRecordingLive(inputDeviceID: inputDeviceID, callback: callback)
    }
}
