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

    enum CaptureMode {
        case systemAudio
        case microphone
    }

    // MARK: - UI / State
    enum Phase { case idle, starting, running, stopping }
    @Published private(set) var phase: Phase = .idle
    @Published private(set) var transcriptLog: [OverlayModel.TranscriptMessage] = []
    @Published private(set) var partialText: String = ""
    @Published var lastError: String?
    @Published private(set) var isTranscribing = false

    var isTranscribingLegacy: Bool { isTranscribing }

    // MARK: - Capture
    private var stream: SCStream?
    private var microphoneService: MicrophoneCaptureService?
    private let captureMode: CaptureMode
    private let sourceKind: OverlayModel.AudioSourceKind
    private let outputQueue: DispatchQueue

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
    private var engineConfirmed = ""
    private var awaitingEngineConfirmation = ""
    private var lastPartial = ""

    // Pending confirmed (анти-обрыв слова)
    private var pendingConfirmed: String = ""
    private var confirmedAccumulator: String = ""
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
    private var silenceStartedAt: Date?

    // Акумулятор до ровных чанков ~20мс
    private var acc: [Float] = []
    private var minChunk: Int { sampleRate / 50 } // 20ms => 320 при 16кГц

    // MARK: - Init
    override convenience init() {
        self.init(captureMode: .systemAudio)
    }

    init(captureMode: CaptureMode) {
        self.captureMode = captureMode
        switch captureMode {
        case .systemAudio:
            self.sourceKind = .system
            self.outputQueue = DispatchQueue(label: "SystemAudio.StreamOutput")
        case .microphone:
            self.sourceKind = .microphone
            self.outputQueue = DispatchQueue(label: "MicrophoneAudio.StreamOutput")
        }
        super.init()

        if captureMode == .microphone {
            self.microphoneService = MicrophoneCaptureService(targetSampleRate: Double(sampleRate),
                                                             queueLabel: "MicrophoneCaptureService.Stream")
        }
    }

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

    private lazy var noiseTagRegexes: [NSRegularExpression] = {
        [
            #"(?i)\[[^\[\]]{1,120}\]"#,
            #"(?i)\([^\(\)]{1,120}\)"#
        ].compactMap { try? NSRegularExpression(pattern: $0) }
    }()

    private let noiseKeywords = [
        "музык", "динамич", "песня", "инструмент", "минус", "мелод",
        "music", "melody", "song", "instrumental", "beat", "rhythm",
        "аплод", "applause", "laugh", "смех", "noise", "шум", "тишин",
        "background", "fx", "зву"
    ]

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
    }

    private func stripNoiseTags(_ s: String) -> String {
        guard !s.isEmpty else { return s }
        let nsSource = s as NSString
        let mutable = NSMutableString(string: s)

        for regex in noiseTagRegexes {
            let matches = regex.matches(in: s, options: [], range: NSRange(location: 0, length: nsSource.length))
            for match in matches.reversed() {
                let tag = nsSource.substring(with: match.range).lowercased()
                if noiseKeywords.contains(where: { tag.contains($0) }) {
                    mutable.replaceCharacters(in: match.range, with: " ")
                }
            }
        }

        var result = mutable as String
        result = result.replacingOccurrences(of: #"\s{2,}"#, with: " ", options: .regularExpression)
        return result
    }

    private func sanitizeTranscription(_ s: String) -> String {
        stripNoiseTags(stripSpecialTokens(s))
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func isNoiseTag(_ s: String) -> Bool {
        let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        let ns = trimmed as NSString
        let range = NSRange(location: 0, length: ns.length)
        for regex in noiseTagRegexes {
            if let match = regex.firstMatch(in: trimmed, options: [], range: range),
               match.range.length == ns.length {
                let lower = trimmed.lowercased()
                if noiseKeywords.contains(where: { lower.contains($0) }) {
                    return true
                }
            }
        }
        return false
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

    @MainActor
    private func appendMessage(_ text: String, at time: Date = Date()) {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        let message = OverlayModel.TranscriptMessage(source: sourceKind, text: clean, timestamp: time)
        transcriptLog.append(message)
    }

    @MainActor
    private func applyConfirmedDelta(_ delta: String, at time: Date = Date(), force: Bool = false) {
        let clean = delta.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }

        if let addition = appendToConfirmedBuffer(clean, at: time, force: force) {
            registerAddition(addition, forced: force)
        }
        partialText = ""
        lastPartial = ""
    }

    @MainActor
    private func appendToConfirmedBuffer(_ text: String, at time: Date, force: Bool) -> String? {
        guard !text.isEmpty else { return nil }

        let addition = normalizedAddition(text, relativeTo: confirmedAccumulator)
        confirmedAccumulator.append(addition)
        flushConfirmedBuffer(force: force, at: time)
        return addition
    }

    @MainActor
    private func flushConfirmedBuffer(force: Bool, at time: Date) {
        guard !confirmedAccumulator.isEmpty else { return }

        let sentenceTerminators: Set<Character> = [".", "!", "?", "…", "\n"]
        let trailingClosers = "»\"')]}”’"

        var start = confirmedAccumulator.startIndex
        var idx = start
        while idx < confirmedAccumulator.endIndex {
            let ch = confirmedAccumulator[idx]
            if sentenceTerminators.contains(ch) {
                var end = confirmedAccumulator.index(after: idx)
                while end < confirmedAccumulator.endIndex,
                      let closer = confirmedAccumulator[end].unicodeScalars.first,
                      trailingClosers.unicodeScalars.contains(closer) {
                    end = confirmedAccumulator.index(after: end)
                }
                while end < confirmedAccumulator.endIndex,
                      confirmedAccumulator[end].isWhitespace {
                    end = confirmedAccumulator.index(after: end)
                }

                let sentence = confirmedAccumulator[start..<end]
                let trimmed = sentence.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    appendMessage(trimmed, at: time)
                    TranscriptBuffer.shared.appendFinal(trimmed, at: time)
                }
                start = end
                idx = end
                continue
            }
            idx = confirmedAccumulator.index(after: idx)
        }

        if start < confirmedAccumulator.endIndex {
            confirmedAccumulator = String(confirmedAccumulator[start...])
        } else {
            confirmedAccumulator = ""
        }

        if force {
            let remainder = confirmedAccumulator.trimmingCharacters(in: .whitespacesAndNewlines)
            if !remainder.isEmpty {
                appendMessage(remainder, at: time)
                TranscriptBuffer.shared.appendFinal(remainder, at: time)
            }
            confirmedAccumulator = ""
        }
    }

    private func normalizedAddition(_ text: String, relativeTo base: String) -> String {
        guard !text.isEmpty else { return "" }

        if base.isEmpty { return text }

        var addition = text
        if let lastChar = base.last,
           let firstChar = text.first,
           shouldInsertSpace(between: lastChar, and: firstChar) {
            addition.insert(" ", at: addition.startIndex)
        }
        return addition
    }

    private func dropPrefix(_ length: Int, from string: inout String) {
        guard length > 0 else { return }
        if length >= string.count {
            string.removeAll(keepingCapacity: false)
            return
        }
        let idx = string.index(string.startIndex, offsetBy: length)
        string.removeSubrange(string.startIndex..<idx)
    }

    private func shouldInsertSpace(between lhs: Character, and rhs: Character) -> Bool {
        if lhs.isWhitespace || rhs.isWhitespace { return false }
        if "-—–".contains(lhs) { return false }
        if "'’\"“”".contains(lhs) { return false }
        let punctuation = CharacterSet(charactersIn: ".,!?:;…—-")
        if let scalar = rhs.unicodeScalars.first, punctuation.contains(scalar) { return false }
        if "'’\"«()[]{}".contains(rhs) { return false }
        return true
    }

    private func mergeChunksForCommit(_ chunks: [String]) -> String {
        let cleaned = chunks
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard var result = cleaned.first else { return "" }

        for part in cleaned.dropFirst() {
            if let lastChar = result.last,
               let firstChar = part.first,
               shouldInsertSpace(between: lastChar, and: firstChar) {
                result.append(" ")
            }
            result.append(part)
        }

        return result.trimmingCharacters(in: .whitespacesAndNewlines)
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
            let timestamp = Date()
            DispatchQueue.main.async {
                self.applyConfirmedDelta(chunk, at: timestamp)
            }
        }
        commitTimer = t
        t.resume()
    }

    private func registerAddition(_ addition: String, forced: Bool) {
        guard !addition.isEmpty else { return }
        outputQueue.sync {
            if forced {
                self.awaitingEngineConfirmation.append(addition)
            } else if !self.awaitingEngineConfirmation.isEmpty {
                if self.awaitingEngineConfirmation.hasPrefix(addition) {
                    dropPrefix(addition.count, from: &self.awaitingEngineConfirmation)
                } else if addition.hasPrefix(self.awaitingEngineConfirmation) {
                    self.awaitingEngineConfirmation = ""
                } else {
                    let overlap = self.awaitingEngineConfirmation.commonPrefix(with: addition, options: .literal)
                    if !overlap.isEmpty {
                        dropPrefix(overlap.count, from: &self.awaitingEngineConfirmation)
                    } else {
                        self.awaitingEngineConfirmation = ""
                    }
                }
            }
        }
    }

    private func deltaFromEngine(_ confirmed: String) -> String? {
        guard !confirmed.isEmpty else { return nil }

        if !awaitingEngineConfirmation.isEmpty {
            let baseline = engineConfirmed
            let expected = baseline + awaitingEngineConfirmation

            if confirmed.hasPrefix(expected) {
                let idx = confirmed.index(confirmed.startIndex, offsetBy: expected.count)
                let remainder = String(confirmed[idx...])
                engineConfirmed = confirmed
                awaitingEngineConfirmation = ""
                return remainder.isEmpty ? nil : remainder
            }

            if confirmed.hasPrefix(baseline) {
                let producedIndex = confirmed.index(confirmed.startIndex, offsetBy: baseline.count)
                let produced = String(confirmed[producedIndex...])

                if produced.isEmpty {
                    engineConfirmed = confirmed
                    return nil
                }

                if awaitingEngineConfirmation.hasPrefix(produced) {
                    dropPrefix(produced.count, from: &awaitingEngineConfirmation)
                    engineConfirmed = confirmed
                    return nil
                }

                if produced.hasPrefix(awaitingEngineConfirmation) {
                    let remainderIndex = produced.index(produced.startIndex, offsetBy: awaitingEngineConfirmation.count)
                    let remainder = String(produced[remainderIndex...])
                    awaitingEngineConfirmation = ""
                    engineConfirmed = confirmed
                    return remainder.isEmpty ? nil : remainder
                }

                let overlap = awaitingEngineConfirmation.commonPrefix(with: produced, options: .literal)
                if !overlap.isEmpty {
                    dropPrefix(overlap.count, from: &awaitingEngineConfirmation)
                }
                let remainder = String(produced.dropFirst(overlap.count))
                awaitingEngineConfirmation = ""
                engineConfirmed = confirmed
                return remainder.isEmpty ? nil : remainder
            } else {
                let common = confirmed.commonPrefix(with: engineConfirmed, options: .literal)
                engineConfirmed = String(common)
                awaitingEngineConfirmation = ""
            }
        }

        if !confirmed.hasPrefix(engineConfirmed) {
            let common = confirmed.commonPrefix(with: engineConfirmed, options: .literal)
            engineConfirmed = String(common)
        }

        guard confirmed.count > engineConfirmed.count else {
            engineConfirmed = confirmed
            return nil
        }

        let idx = confirmed.index(confirmed.startIndex, offsetBy: engineConfirmed.count)
        let remainder = String(confirmed[idx...])
        engineConfirmed = confirmed
        return remainder.isEmpty ? nil : remainder
    }

    private func processIncomingSamples(_ floats: [Float]) {
        let gated = vad.process(floats)
        guard !gated.isEmpty else { return }

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

    // MARK: - Public API
    @MainActor
    func clearLog() {
        transcriptLog.removeAll()
        partialText = ""
        confirmedAccumulator = ""
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
        engineConfirmed = ""
        awaitingEngineConfirmation = ""
        lastPartial = ""
        lastShownPartial = ""
        lastNonEmptyPartialAt = Date()
        lastPartialChangeAt = Date()
        pendingConfirmed = ""
        confirmedAccumulator = ""
        commitTimer?.cancel(); commitTimer = nil
        silenceStartedAt = nil

        Task {
            do {
                switch captureMode {
                case .systemAudio:
                    guard ensureScreenRecordingAuthorized() else {
                        throw NSError(domain: "SystemAudio", code: 1,
                                      userInfo: [NSLocalizedDescriptionKey:
                                                 "Доступ к записи экрана не выдан. Включи и перезапусти приложение."])
                    }
                    try await startSystemAudioStream()
                case .microphone:
                    try await startMicrophoneStream()
                }

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
                    let confirmed = self.sanitizeTranscription(confirmedRaw)
                    if let newChunk = self.deltaFromEngine(confirmed) {
                        var delta = newChunk.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !delta.isEmpty, !self.isKnownHallucination(delta) else { return }

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
                            let timestamp = Date()
                            DispatchQueue.main.async {
                                self.applyConfirmedDelta(delta, at: timestamp)
                            }
                        }
                    }

                    // PARTIAL -> живой хвост с «липкостью»
                    let unconf = state.unconfirmedSegments.map(\.text).joined()
                    let liveRaw = state.currentText.isEmpty ? unconf : state.currentText
                    let live = self.sanitizeTranscription(liveRaw)

                    if live != self.lastPartial {
                        self.lastPartial = live
                        let candidate = self.streamFriendlyPartial(live)

                        DispatchQueue.main.async {
                            if !candidate.isEmpty &&
                                !self.isKnownHallucination(candidate) &&
                                !self.isNoiseTag(candidate) {
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

                await MainActor.run {
                    self.isTranscribing = true
                    self.phase = .running
                }

                // soft-confirm таймер: дожимает хвост на паузе
                startSoftConfirmTimer()

                try await tr.startStreamTranscription()
                print("[WK] stream transcription started")
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
        silenceStartedAt = nil

        Task { await transcriber?.stopStreamTranscription() }
        transcriber = nil

        // добиваем хвост, если он остался
        let tail = mergeChunksForCommit([pendingConfirmed, lastPartial])
        pendingConfirmed = ""
        let flushTime = Date()
        stopCapture()
        converter = nil

        Task { @MainActor in
            if !tail.isEmpty {
                self.applyConfirmedDelta(tail, at: flushTime, force: true)
            } else {
                self.flushConfirmedBuffer(force: true, at: flushTime)
            }
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
        let now = Date()
        let silent = recentEnergyMean(seconds: 0.6) < 0.07

        if silent {
            if silenceStartedAt == nil { silenceStartedAt = now }
        } else {
            silenceStartedAt = nil
            return
        }

        guard let silenceStart = silenceStartedAt else { return }

        let silentFor = now.timeIntervalSince(silenceStart)
        let stable = now.timeIntervalSince(lastPartialChangeAt) > 0.45
        let tail = mergeChunksForCommit([pendingConfirmed, lastPartial])

        guard !tail.isEmpty, stable else { return }

        let hasBoundary = endsWithBoundary(tail)
        let looksComplete = hasBoundary || !isLikelyMidWord(tail)

        guard looksComplete || silentFor > 1.0 else { return }

        let timestamp = now
        pendingConfirmed = ""
        commitTimer?.cancel()
        commitTimer = nil
        DispatchQueue.main.async {
            self.applyConfirmedDelta(tail, at: timestamp, force: true)
        }
        lastPartial = ""
        lastShownPartial = ""
        lastPartialChangeAt = now
    }

    // MARK: - ScreenCaptureKit (audio-only)
    private func startMicrophoneStream() async throws {
        let service: MicrophoneCaptureService
        if let existing = microphoneService {
            service = existing
        } else {
            let created = MicrophoneCaptureService(targetSampleRate: Double(sampleRate),
                                                   queueLabel: "MicrophoneCaptureService.Stream")
            microphoneService = created
            service = created
        }

        service.onSamples = { [weak self] samples in
            guard let self else { return }
            self.outputQueue.async {
                self.processIncomingSamples(samples)
            }
        }

        try await service.start()
    }

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
        switch captureMode {
        case .systemAudio:
            let s = stream
            stream = nil
            Task { try? await s?.stopCapture() }
        case .microphone:
            microphoneService?.stop()
            microphoneService?.onSamples = nil
        }
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
            processIncomingSamples(floats)
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
