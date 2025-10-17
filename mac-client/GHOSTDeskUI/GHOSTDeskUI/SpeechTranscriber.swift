import Foundation
import CoreML
import ScreenCaptureKit
import WhisperKit
import AVFAudio
import Combine
import SwiftUI
import AVFoundation
import CoreMedia
import Accelerate
import CoreGraphics

// MARK: - Простой Energy VAD с гистерезисом и zero-fill для пауз
fileprivate struct EnergyVAD {
    enum Mode { case passThrough, zeroFill }

    let sr: Int
    var mode: Mode = .zeroFill
    var noiseDb: Float = -50
    let enterMarginDb: Float = 6      // было 8 — чуть легче входить в речь
    let exitMarginDb: Float = 3       // было 4 — легче удерживать "речь"
    let hardSpeechFloorDb: Float = -45
    let emaAlpha: Float = 0.95
    let hangoverFrames: Int = 18      // было 10 — дольше держим после микропауз
    let attackFrames: Int = 2         // быстрый старт

    private(set) var inSpeech = false
    private var hangover = 0
    private var attack = 0

    fileprivate init(sr: Int, mode: Mode = .zeroFill) {
        self.sr = sr
        self.mode = mode
    }

    mutating func process(_ x: [Float]) -> [Float] {
        guard !x.isEmpty else { return x }

        var rms: Float = 0
        x.withUnsafeBufferPointer { ptr in
            vDSP_rmsqv(ptr.baseAddress!, 1, &rms, vDSP_Length(x.count))
        }
        let db = 20 * log10(max(rms, 1e-7))

        let thrEnter = max(noiseDb + enterMarginDb, hardSpeechFloorDb)
        let thrExit  = noiseDb + exitMarginDb

        if inSpeech {
            if db > thrExit {
                hangover = hangoverFrames
            } else {
                hangover = max(0, hangover - 1)
                if hangover == 0 { inSpeech = false }
                noiseDb = emaAlpha * noiseDb + (1 - emaAlpha) * db
            }
        } else {
            noiseDb = emaAlpha * noiseDb + (1 - emaAlpha) * db
            if db > thrEnter {
                attack = min(attackFrames, attack + 1)
                if attack >= attackFrames {
                    inSpeech = true
                    hangover = hangoverFrames
                }
            } else {
                attack = 0
            }
        }

        if inSpeech {
            return x
        } else {
            switch mode {
            case .passThrough: return []
            case .zeroFill:    return [Float](repeating: 0, count: x.count)
            }
        }
    }
}

final class SpeechTranscriber: NSObject, ObservableObject, AudioProcessing {

    // MARK: - UI / State
    enum Phase { case idle, starting, running, stopping }
    @Published private(set) var phase: Phase = .idle
    @Published private(set) var transcriptLog: [String] = []
    @Published private(set) var partialText: String = ""
    @Published var lastError: String?
    @Published private(set) var isTranscribing = false

    var isTranscribingLegacy: Bool { isTranscribing }

    // MARK: - Capture
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

    // MARK: - WhisperKit streaming
    private var whisper: WhisperKit?
    private var transcriber: AudioStreamTranscriber?
    private let noopVideoSink = NoopVideoSink()

    // Sticky partial bookkeeping
    private var lastNonEmptyPartialAt = Date()
    private var lastShownPartial = ""
    private var lastPartialChangeAt = Date()

    // Confirmed bookkeeping
    private var lastConfirmed = ""
    private var lastPartial = ""

    // Pending confirmed (анти-обрыв слова)
    private var pendingConfirmed: String = ""
    private var commitTimer: DispatchSourceTimer?

    // Counters
    private var audioPackets = 0
    private var totalFedSamples = 0

    private let keepSeconds = 10
    private let sampleRate = 16_000

    // VAD
    private var vad = EnergyVAD(sr: 16_000)

    // AudioProcessing storage
    private var samples: ContiguousArray<Float> = []
    private var energy: [Float] = []
    private var energyWindow: Int = 10
    private var bufferCallback: (([Float]) -> Void)? // приходит от WK

    // Soft-confirm timer (дожим хвоста по тишине)
    private var softConfirmTimer: DispatchSourceTimer?

    // Акумулятор до ровных чанков ~20мс
    private var acc: [Float] = []
    private var minChunk: Int { sampleRate / 50 } // 20ms => 320 при 16кГц

    // MARK: - Known-hallucinations filter (regex)
    private lazy var hallucinationRegexes: [NSRegularExpression] = {
        let patterns = [
            #"(?i)редактор[^\n]{0,40}субтитр"#,
            #"(?i)субтитр(ы|ов)?\s+(подогнал|добавил|добавила)"#,
            #"(?i)спасибо\s+за\s+субтитры"#,
            #"(?i)подпис(ись|ывайся|ка)#?"#,
            #"(?i)смотрите\s+продолжение"#,
            #"(?i)продолжение\s+следует"#
        ]
        return patterns.compactMap { try? NSRegularExpression(pattern: $0) }
    }()

    @inline(__always)
    private func isKnownHallucination(_ s: String) -> Bool {
        guard !s.isEmpty else { return false }
        let range = NSRange(location: 0, length: (s as NSString).length)
        return hallucinationRegexes.contains { $0.firstMatch(in: s, options: [], range: range) != nil }
    }

    // MARK: - Helpers
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

    private func recentEnergyMean(seconds: Double) -> Float {
        let perSec = 50 // мы пишем энергию каждые 20мс
        let n = max(1, Int(seconds * Double(perSec)))
        let start = max(0, energy.count - n)
        guard start < energy.count else { return 0 }
        let slice = energy[start..<energy.count]
        return slice.reduce(0, +) / Float(slice.count)
    }

    private func applyConfirmedDelta(_ delta: String) {
        let clean = delta.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        transcriptLog.append(clean)
        partialText = ""
        lastPartial = ""
    }

    @inline(__always)
    private func endsWithBoundary(_ s: String) -> Bool {
        guard let ch = s.trimmingCharacters(in: .whitespacesAndNewlines).last else { return false }
        return " .,!?:;…—-«»\"'()[]{}".contains(ch)
    }

    @inline(__always)
    private func isLikelyMidWord(_ s: String) -> Bool {
        guard let u = s.unicodeScalars.last else { return false }
        return CharacterSet.alphanumerics.contains(u) // буква/цифра в конце → слово не закончено
    }

    private func scheduleCommit(delay: TimeInterval = 0.22) {
        commitTimer?.cancel()
        let t = DispatchSource.makeTimerSource(queue: outputQueue)
        t.schedule(deadline: .now() + delay)
        t.setEventHandler { [weak self] in
            guard let self else { return }
            let chunk = self.pendingConfirmed.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !chunk.isEmpty else { return }
            self.pendingConfirmed = ""
            DispatchQueue.main.async { self.applyConfirmedDelta(chunk) }
            TranscriptBuffer.shared.appendFinal(chunk, at: Date())
        }
        commitTimer = t
        t.resume()
    }

    // MARK: - Public API
    @MainActor
    func clearLog() {
        transcriptLog.removeAll()
        partialText = ""
        TranscriptBuffer.shared.clear()
    }

    func start() {
        guard phase == .idle else { return }
        phase = .starting
        lastError = nil

        // сброс состояния
        vad = EnergyVAD(sr: sampleRate)
        samples.removeAll(keepingCapacity: true)
        energy.removeAll(keepingCapacity: true)
        acc.removeAll(keepingCapacity: true)
        lastConfirmed = ""
        lastPartial = ""
        lastShownPartial = ""
        lastNonEmptyPartialAt = Date()
        lastPartialChangeAt = Date()
        pendingConfirmed = ""
        commitTimer?.cancel(); commitTimer = nil

        Task {
            do {
                guard ensureScreenRecordingAuthorized() else {
                    throw NSError(domain: "SystemAudio", code: 1,
                                  userInfo: [NSLocalizedDescriptionKey:
                                             "Доступ к записи экрана не выдан. Включи и перезапусти приложение."])
                }

                try await startSystemAudioStream()

                var cfg = WhisperKitConfig(
                    model: "medium",
                    audioProcessor: self,
                    load: true,
                    download: false   // ничего не качаем
                )

                // WhisperKit по умолчанию ищет модели прямо в Resources,
                // поэтому cfg.modelFolder можно не трогать
                // Если хочешь явно:
                cfg.modelFolder = Bundle.main.resourcePath
                let wk = try await WhisperKit(cfg)
                self.whisper = wk

                var options = DecodingOptions(
                    verbose: false,
                    task: .transcribe,
                    language: "ru",
                    usePrefillPrompt: true,
                    skipSpecialTokens: true,
                    withoutTimestamps: true,
                    wordTimestamps: false,
                    windowClipTime: 1.0 // подлиннее окно — проще закрывать сегмент
                )
                options.maxWindowSeek = sampleRate * 3
                options.suppressBlank = false            // важно: не душим blank-токены
                options.temperature = 0.0

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
                    silenceThreshold: 0.30,                // мягче, меньше обрубов в середине слов
                    compressionCheckWindow: 8,
                    useVAD: true
                ) { [weak self] _, state in
                    guard let self else { return }

                    // CONFIRMED -> в лог (с «анти-обрыв» логикой)
                    let confirmedRaw = state.confirmedSegments.map(\.text).joined()
                    let confirmed = self.stripSpecialTokens(confirmedRaw)
                    if !confirmed.isEmpty, confirmed != self.lastConfirmed {
                        var delta = String(confirmed.dropFirst(self.lastConfirmed.count))
                            .trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !delta.isEmpty, !self.isKnownHallucination(delta) else { return }

                        self.lastConfirmed = confirmed

                        // если на конце нет явной границы и похоже на середину слова — ждём 220мс
                        if !self.endsWithBoundary(delta) && self.isLikelyMidWord(delta) {
                            self.pendingConfirmed += delta // без вставки пробелов — это может быть продолжение слова
                            self.scheduleCommit()           // чуть ждём возможное продолжение
                        } else {
                            // есть граница — коммитим сразу + добавляем то, что накопили ранее
                            if !self.pendingConfirmed.isEmpty {
                                delta = self.pendingConfirmed + delta
                                self.pendingConfirmed = ""
                                self.commitTimer?.cancel()
                                self.commitTimer = nil
                            }
                            DispatchQueue.main.async { self.applyConfirmedDelta(delta) }
                            TranscriptBuffer.shared.appendFinal(delta, at: Date())
                        }
                    }

                    // PARTIAL -> живой хвост с «липкостью»
                    let unconf = state.unconfirmedSegments.map(\.text).joined()
                    let liveRaw = state.currentText.isEmpty ? unconf : state.currentText
                    let live = self.stripSpecialTokens(liveRaw)

                    if live != self.lastPartial {
                        self.lastPartial = live
                        let candidate = self.streamFriendlyPartial(live)

                        DispatchQueue.main.async {
                            if !candidate.isEmpty && !self.isKnownHallucination(candidate) {
                                self.partialText = candidate
                                self.lastShownPartial = candidate
                                self.lastNonEmptyPartialAt = Date()
                                self.lastPartialChangeAt = Date()
                            } else {
                                // тишина/пусто — держим хвост до 1.2 c
                                if Date().timeIntervalSince(self.lastNonEmptyPartialAt) > 1.2 {
                                    self.partialText = ""
                                    self.lastShownPartial = ""
                                } else {
                                    self.partialText = self.lastShownPartial
                                }
                            }
                        }

                        TranscriptBuffer.shared.setPartial(live, at: Date())
                    }
                }

                self.transcriber = tr
                try await tr.startStreamTranscription()
                print("[WK] stream transcription started")

                // soft-confirm таймер: дожимает хвост на паузе
                startSoftConfirmTimer()

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
                stopSoftConfirmTimer()
            }
        }
    }

    func stop() {
        guard phase == .running || phase == .starting else { return }
        phase = .stopping

        stopSoftConfirmTimer()
        commitTimer?.cancel(); commitTimer = nil

        Task { await transcriber?.stopStreamTranscription() }
        transcriber = nil

        // добиваем хвост, если он остался
        let tail = (pendingConfirmed + " " + partialText).trimmingCharacters(in: .whitespacesAndNewlines)
        pendingConfirmed = ""
        if !tail.isEmpty {
            applyConfirmedDelta(tail)
            TranscriptBuffer.shared.appendFinal(tail, at: Date())
        }

        stopCapture()
        converter = nil

        Task { @MainActor in
            self.isTranscribing = false
            self.partialText = ""
            self.phase = .idle
        }
    }

    // MARK: - Soft-confirm timer
    private func startSoftConfirmTimer() {
        stopSoftConfirmTimer()
        let timer = DispatchSource.makeTimerSource(queue: outputQueue)
        timer.schedule(deadline: .now() + .milliseconds(150), repeating: .milliseconds(150))
        timer.setEventHandler { [weak self] in
            self?.softConfirmTick()
        }
        self.softConfirmTimer = timer
        timer.resume()
    }

    private func stopSoftConfirmTimer() {
        softConfirmTimer?.cancel()
        softConfirmTimer = nil
    }

    private func softConfirmTick() {
        // Тихо уже ~0.8 c и partial не менялся ~0.6 c — коммитим хвост
        let silent = recentEnergyMean(seconds: 0.8) < 0.08
        let stable = Date().timeIntervalSince(lastPartialChangeAt) > 0.6
        let tail = partialText.trimmingCharacters(in: .whitespacesAndNewlines)

        guard silent, stable, !tail.isEmpty else { return }

        // Не коммитим совсем короткие/обрывочные куски
        if tail.count > 20 || [".","!","?","…",":",";"].contains(tail.last) {
            DispatchQueue.main.async {
                self.applyConfirmedDelta(tail)
            }
            TranscriptBuffer.shared.appendFinal(tail, at: Date())
            lastPartial = ""
            lastShownPartial = ""
        }
    }

    // MARK: - ScreenCaptureKit (audio-only)
    private func startSystemAudioStream() async throws {
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        guard let display = content.displays.first else {
            throw NSError(domain: "SystemSpeechRecognizer", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "Нет доступных дисплеев"])
        }

        let filter = SCContentFilter(display: display, excludingWindows: [])
        let cfg = SCStreamConfiguration()
        cfg.capturesAudio = true
        cfg.excludesCurrentProcessAudio = true   // не ловим свой звук
        cfg.sampleRate = 44_100
        cfg.channelCount = 2
        cfg.width = 8
        cfg.height = 8
        cfg.showsCursor = false

        let stream = SCStream(filter: filter, configuration: cfg, delegate: self)
        self.stream = stream

        try stream.addStreamOutput(noopVideoSink, type: .screen, sampleHandlerQueue: outputQueue)
        try stream.addStreamOutput(self, type: .audio, sampleHandlerQueue: outputQueue)

        try await stream.startCapture()
    }

    private func stopCapture() {
        let s = stream
        stream = nil
        Task { try? await s?.stopCapture() }
    }
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
            // Пропускаем через внешний VAD: тишина -> нули той же длины
            let gated = vad.process(floats)
            guard !gated.isEmpty else { return }

            // Аккумулируем до ровных ~20мс чанков (уменьшает рваные стыки)
            acc.append(contentsOf: gated)
            while acc.count >= minChunk {
                let frame = Array(acc.prefix(minChunk))
                acc.removeFirst(minChunk)
                audioPackets += 1
                totalFedSamples += frame.count
                append(samples: frame)
                bufferCallback?(frame)
            }
        }
    }
}

// MARK: - Converters
fileprivate extension SpeechTranscriber {
    func convertTo16kMonoFloat(sampleBuffer: CMSampleBuffer) -> [Float]? {
        guard CMSampleBufferDataIsReady(sampleBuffer),
              CMSampleBufferGetFormatDescription(sampleBuffer) != nil,
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

// MARK: - AudioProcessing (WhisperKit)
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

    // шаг 20 мс для энергии
    fileprivate func append(samples new: [Float]) {
        samples.append(contentsOf: new)
        let hop = max(1, sampleRate / 50) // 20 ms (320 семплов при 16 кГц)
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

// фиктивный видео-синк
final class NoopVideoSink: NSObject, SCStreamOutput {
    func stream(_ stream: SCStream,
                didOutputSampleBuffer sampleBuffer: CMSampleBuffer,
                of outputType: SCStreamOutputType) {
        // ignore
    }
}

// MARK: - Screen Recording permission (CoreGraphics)
@discardableResult
private func ensureScreenRecordingAuthorized() -> Bool {
    if CGPreflightScreenCaptureAccess() { return true }
    let granted = CGRequestScreenCaptureAccess()
    return granted
}
