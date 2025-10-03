import Foundation
import CoreML
import ScreenCaptureKit
import WhisperKit
import AVFAudio
import Combine
import SwiftUI
import Combine
import AVFoundation
import CoreML
import WhisperKit

import ScreenCaptureKit
import CoreMedia
import Accelerate
import CoreGraphics

final class SpeechTranscriber: NSObject, ObservableObject, AudioProcessing {

    // MARK: - UI / State
    enum Phase { case idle, starting, running, stopping }
    @Published private(set) var phase: Phase = .idle
    @Published private(set) var transcriptLog: [String] = []
    @Published private(set) var partialText: String = ""
    @Published var lastError: String?
    @Published private(set) var isTranscribing = false

    var isTranscribingLegacy: Bool { isTranscribing } // если где-то в UI использовалось

    // MARK: - Capture (как в рабочем эталоне)
    private var stream: SCStream?
    private let outputQueue = DispatchQueue(label: "SystemAudio.StreamOutput")

    // MARK: - Audio converter (-> 16 kHz mono Float32)
    private var converter: AVAudioConverter?
    private let outFormat: AVAudioFormat = AVAudioFormat(
        commonFormat: .pcmFormatFloat32,
        sampleRate: 16_000,
        channels: 1,
        interleaved: false
    )!

    // MARK: - WhisperKit streaming (как в эталоне)
    private var whisper: WhisperKit?
    private var transcriber: AudioStreamTranscriber?
    private let noopVideoSink = NoopVideoSink()

    private var lastConfirmed = ""
    private var lastPartial = ""
    private var audioPackets = 0
    private var totalFedSamples = 0

    private let keepSeconds = 10
    private let sampleRate = 16_000

    // AudioProcessing storage
    private var samples: ContiguousArray<Float> = []
    private var energy: [Float] = []
    private var energyWindow: Int = 10
    private var bufferCallback: (([Float]) -> Void)? // приходит от WK

    // MARK: - Helpers (как в эталоне)
    @inline(__always)
    private func stripSpecialTokens(_ s: String) -> String {
        s.replacingOccurrences(of: #"<\|[^>]+\|>"#, with: "", options: .regularExpression)
         .replacingOccurrences(of: "Waiting for speech...", with: "")
         .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func streamFriendlyPartial(_ s: String) -> String {
        let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return "" }

        if let lastScalar = t.unicodeScalars.last,
           CharacterSet.alphanumerics.contains(lastScalar) {
            if let cut = t.lastIndex(where: { $0 == " " || ",.!?:;—-".contains($0) }) {
                return String(t[..<cut]).trimmingCharacters(in: .whitespacesAndNewlines)
            } else {
                return ""
            }
        }
        return t
    }

    private func applyConfirmedDelta(_ delta: String) {
        let clean = delta.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        transcriptLog.append(clean)
        partialText = ""
        lastPartial = ""
    }

    // MARK: - Public API
    @MainActor
    func clearLog() {
        transcriptLog.removeAll()
        partialText = ""
    }

    func start() {
        guard phase == .idle else { return }
        phase = .starting
        lastError = nil

        Task {
            do {
                // 0) Проверка доступа (без SCAuthorization — совместимо с 12.3+)
                guard ensureScreenRecordingAuthorized() else {
                    throw NSError(domain: "SystemAudio", code: 1,
                                  userInfo: [NSLocalizedDescriptionKey:
                                             "Доступ к записи экрана не выдан. Включи и перезапусти приложение."])
                }

                // 1) Запускаем захват системного аудио (как в «рабочем» коде)
                try await startSystemAudioStream()

                // 2) Поднимаем WhisperKit (локальная модель + загрузка при необходимости)
                let cfg = WhisperKitConfig(
                    model: "small",           // как в эталоне
                    audioProcessor: self,     // ВАЖНО: мы — источник аудио
                    load: true,
                    download: true,
                    useBackgroundDownloadSession: false
                )
                let wk = try await WhisperKit(cfg)
                self.whisper = wk

                // 3) Создаём стример с теми же опциями
                var options = DecodingOptions(
                    verbose: false,
                    task: .transcribe,
                    language: "ru",
                    usePrefillPrompt: true,
                    skipSpecialTokens: true,
                    withoutTimestamps: true,
                    wordTimestamps: false,
                    windowClipTime: 0.5
                )
                options.maxWindowSeek = 16_000 * 5 // как у тебя

                let tokenizer = wk.textDecoder.tokenizer!

                let tr = AudioStreamTranscriber(
                    audioEncoder: wk.audioEncoder,
                    featureExtractor: wk.featureExtractor,
                    segmentSeeker: wk.segmentSeeker,
                    textDecoder: wk.textDecoder,
                    tokenizer: tokenizer,
                    audioProcessor: self,
                    decodingOptions: options,
                    requiredSegmentsForConfirmation: 1,
                    silenceThreshold: 0.30,
                    compressionCheckWindow: 10,
                    useVAD: false // оставить как в «идеале»
                ) { [weak self] _, state in
                    guard let self else { return }

                    // confirmed -> в лог
                    let confirmedRaw = state.confirmedSegments.map(\.text).joined()
                    let confirmed = stripSpecialTokens(confirmedRaw)
                    if !confirmed.isEmpty, confirmed != lastConfirmed {
                        let delta = String(confirmed.dropFirst(lastConfirmed.count))
                        lastConfirmed = confirmed
                        DispatchQueue.main.async {
                            self.applyConfirmedDelta(delta)
                        }
                    }

                    // partial -> хвост в UI
                    let unconf = state.unconfirmedSegments.map(\.text).joined()
                    let liveRaw = state.currentText.isEmpty ? unconf : state.currentText
                    let live = stripSpecialTokens(liveRaw)
                    if live != lastPartial {
                        lastPartial = live
                        DispatchQueue.main.async {
                            self.partialText = self.streamFriendlyPartial(live)
                        }
                    }
                }

                self.transcriber = tr
                try await tr.startStreamTranscription()
                print("[WK] stream transcription started")

                await MainActor.run {
                    self.isTranscribing = true
                    self.phase = .running
                }
            } catch {
                await MainActor.run {
                    self.lastError = "Старт не удался: \(error.localizedDescription)"
                    self.isTranscribing = false
                    self.phase = .idle
                }
                stopCapture()
            }
        }
    }

    func stop() {
        guard phase == .running || phase == .starting else { return }
        phase = .stopping

        Task { await transcriber?.stopStreamTranscription() }
        transcriber = nil

        stopCapture()
        converter = nil

        Task { @MainActor in
            self.isTranscribing = false
            self.partialText = ""
            self.phase = .idle
        }
    }

    // MARK: - ScreenCaptureKit (audio-only) — как в эталоне
    private func startSystemAudioStream() async throws {
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        guard let display = content.displays.first else {
            throw NSError(domain: "SystemSpeechRecognizer", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "Нет доступных дисплеев"])
        }

        let filter = SCContentFilter(display: display, excludingWindows: [])
        let cfg = SCStreamConfiguration()
        cfg.capturesAudio = true
        cfg.excludesCurrentProcessAudio = false
        cfg.sampleRate = 44_100
        cfg.channelCount = 2
        cfg.width = 8
        cfg.height = 8
        cfg.showsCursor = false

        let stream = SCStream(filter: filter, configuration: cfg, delegate: self)
        self.stream = stream

        // фиктивный видео-синк, чтобы SK не ныл
        try stream.addStreamOutput(noopVideoSink, type: .screen, sampleHandlerQueue: outputQueue)
        try stream.addStreamOutput(self, type: .audio, sampleHandlerQueue: outputQueue)

        try await stream.startCapture()
    }

    private func stopCapture() {
        let s = stream
        stream = nil
        Task { try? await s?.stopCapture() }
    }

    // MARK: - SCStreamDelegate
    // (оставляем пустым)
}

extension SpeechTranscriber: SCStreamDelegate {}

// MARK: - SCStreamOutput
extension SpeechTranscriber: SCStreamOutput {
    func stream(_ stream: SCStream,
                didOutputSampleBuffer sampleBuffer: CMSampleBuffer,
                of outputType: SCStreamOutputType) {
        guard outputType == .audio,
              CMSampleBufferDataIsReady(sampleBuffer) else { return }

        if let floats = convertTo16kMonoFloat(sampleBuffer: sampleBuffer) {
            audioPackets += 1
            totalFedSamples += floats.count
            append(samples: floats)
            bufferCallback?(floats) // триггер для стримера — как было у тебя
        }
    }
}

// MARK: - Converters (как в эталоне)
fileprivate extension SpeechTranscriber {
    func convertTo16kMonoFloat(sampleBuffer: CMSampleBuffer) -> [Float]? {
        guard CMSampleBufferDataIsReady(sampleBuffer),
              let _ = CMSampleBufferGetFormatDescription(sampleBuffer),
              let pcmIn = sampleBuffer.toPCMBuffer() else { return nil }

        if converter == nil || converter!.inputFormat != pcmIn.format {
            converter = AVAudioConverter(from: pcmIn.format, to: outFormat)
            print("Input format:", pcmIn.format)
            print("Target format:", outFormat)
        }
        guard let converter else { return nil }

        let ratio = outFormat.sampleRate / pcmIn.format.sampleRate
        let outFrames = AVAudioFrameCount(Double(pcmIn.frameLength) * ratio + 32)
        guard let pcmOut = AVAudioPCMBuffer(pcmFormat: outFormat, frameCapacity: outFrames) else { return nil }

        var err: NSError?
        var provided = false
        converter.convert(to: pcmOut, error: &err) { _, outStatus in
            defer { provided = true }
            outStatus.pointee = provided ? .noDataNow : .haveData
            return provided ? nil : pcmIn
        }
        if let err { print("AVAudioConverter error:", err); return nil }

        guard let ch = pcmOut.floatChannelData else { return nil }
        return Array(UnsafeBufferPointer(start: ch[0], count: Int(pcmOut.frameLength)))
    }
}

fileprivate extension CMSampleBuffer {
    func toPCMBuffer() -> AVAudioPCMBuffer? {
        guard let fdesc = CMSampleBufferGetFormatDescription(self) else { return nil }
        let maybeFormat: AVAudioFormat? = AVAudioFormat(cmAudioFormatDescription: fdesc)
        guard let format = maybeFormat else { return nil }

        let frames = AVAudioFrameCount(CMSampleBufferGetNumSamples(self))
        guard let buf = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames) else { return nil }
        buf.frameLength = frames

        let status = CMSampleBufferCopyPCMDataIntoAudioBufferList(
            self, at: 0, frameCount: Int32(frames), into: buf.mutableAudioBufferList
        )
        return status == noErr ? buf : nil
    }
}

// MARK: - AudioProcessing (как в эталоне)
extension SpeechTranscriber {
    static func loadAudio(fromPath audioFilePath: String,
                          channelMode: ChannelMode,
                          startTime: Double?,
                          endTime: Double?,
                          maxReadFrameSize: AVAudioFrameCount?) throws -> AVAudioPCMBuffer {
        try AudioProcessor.loadAudio(fromPath: audioFilePath,
                                     channelMode: channelMode,
                                     startTime: startTime,
                                     endTime: endTime,
                                     maxReadFrameSize: maxReadFrameSize)
    }

    static func loadAudio(at audioPaths: [String],
                          channelMode: ChannelMode) async -> [Result<[Float], any Error>] {
        await AudioProcessor.loadAudio(at: audioPaths, channelMode: channelMode)
    }

    static func padOrTrimAudio(fromArray audioArray: [Float],
                               startAt startIndex: Int,
                               toLength frameLength: Int,
                               saveSegment: Bool) -> MLMultiArray? {
        AudioProcessor.padOrTrimAudio(fromArray: audioArray,
                                      startAt: startIndex,
                                      toLength: frameLength,
                                      saveSegment: saveSegment)
    }

    func padOrTrim(fromArray audioArray: [Float],
                   startAt startIndex: Int,
                   toLength frameLength: Int) -> (any AudioProcessorOutputType)? {
        Self.padOrTrimAudio(fromArray: audioArray, startAt: startIndex, toLength: frameLength, saveSegment: false)
    }

    var audioSamples: ContiguousArray<Float> { samples }

    func purgeAudioSamples(keepingLast keep: Int) {
        if samples.count > keep {
            samples.removeFirst(samples.count - keep)
        }
        if energy.count > max(relativeEnergyWindow, 200) {
            energy.removeFirst(energy.count - max(relativeEnergyWindow, 200))
        }
    }

    var relativeEnergy: [Float] { energy }
    var relativeEnergyWindow: Int {
        get { energyWindow }
        set { energyWindow = newValue }
    }

    func startRecordingLive(inputDeviceID: DeviceID? = nil,
                            callback: (([Float]) -> Void)?) throws {
        // как в эталоне: SCStream уже запущен, здесь только сохраняем колбэк и чистим буферы
        bufferCallback = callback
        samples.removeAll(keepingCapacity: true)
        energy.removeAll(keepingCapacity: true)
    }

    func pauseRecording() { /* ScreenCaptureKit не умеет паузу */ }

    func stopRecording() {
        bufferCallback = nil
        samples.removeAll(keepingCapacity: false)
        energy.removeAll(keepingCapacity: false)
    }

    func resumeRecordingLive(inputDeviceID: DeviceID? = nil,
                             callback: (([Float]) -> Void)?) throws {
        bufferCallback = callback
    }

    // добавление семплов + «относительная энергия» (как в эталоне)
    fileprivate func append(samples new: [Float]) {
        samples.append(contentsOf: new)
        let hop = max(1, 16_000 / 10) // 0.1s
        new.withUnsafeBufferPointer { ptr in
            var i = 0
            while i + hop <= new.count {
                var rms: Float = 0
                vDSP_rmsqv(ptr.baseAddress! + i, 1, &rms, vDSP_Length(hop))
                let db = 20 * log10(max(rms, 1e-6))
                let norm = max(0, min(1, (db + 60) / 60))
                energy.append(norm)
                i += hop
            }
        }
    }
}

// фиктивный видео-синк (как в эталоне)
final class NoopVideoSink: NSObject, SCStreamOutput {
    func stream(_ stream: SCStream,
                didOutputSampleBuffer sampleBuffer: CMSampleBuffer,
                of outputType: SCStreamOutputType) {
        // ignore
    }
}

// MARK: - Screen Recording permission (CoreGraphics-путь)
@discardableResult
private func ensureScreenRecordingAuthorized() -> Bool {
    if CGPreflightScreenCaptureAccess() { return true }
    let granted = CGRequestScreenCaptureAccess()
    return granted
}
