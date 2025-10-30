import Foundation
import AppKit
import Combine

final class OverlayModel: ObservableObject {
    struct TranscriptMessage: Identifiable, Equatable {
        let id: UUID
        let source: AudioSourceKind
        let text: String
        let timestamp: Date

        init(id: UUID = UUID(), source: AudioSourceKind, text: String, timestamp: Date = Date()) {
            self.id = id
            self.source = source
            self.text = text
            self.timestamp = timestamp
        }
    }

    enum AudioSourceKind: String, CaseIterable, Identifiable {
        case system
        case microphone

        var id: String { rawValue }

        var title: String {
            switch self {
            case .system: return "Системный звук"
            case .microphone: return "Микрофон"
            }
        }
    }

    enum AudioChannelPhase: Equatable {
        case idle, starting, running, stopping
    }

    struct TranscriptionChannelState: Equatable {
        var phase: AudioChannelPhase = .idle
        var isTranscribing: Bool = false
        var transcriptLog: [TranscriptMessage] = []
        var partialText: String = ""
        var lastError: String? = nil
    }

    static let shared = OverlayModel()

    @Published private(set) var transcriptionStates: [AudioSourceKind: TranscriptionChannelState]

    @Published var isRecording: Bool = false
    @Published var transcriptLog: [TranscriptMessage] = []
    @Published var partialText: String = ""
    @Published var lastError: String? = nil

    // Видимость/поведение
    @Published var isOverlayVisible: Bool = true
    @Published var isFocusable: Bool = true
    @Published var transparencyIndex: Int = 1     // 0…5
    @Published var fontScaleIndex: Int = 1        // 0…5

    // Левый блок (заглушки)
    @Published var proLevel: String = "PRO"
    @Published var audioMinutesLeft: Int = 14
    @Published var hintsLeft: Int = 73

    // Нижняя панель (заглушки)
    @Published var isAutoHints: Bool = false

    // Настройки
    @Published var showSettings: Bool = false
    @Published var askSolveTrigger: Int = 0


    // Константы
    let transparencySteps: [CGFloat] = [1.0, 0.9, 0.8, 0.7, 0.6, 0.5]
    let fontScaleSteps: [CGFloat]     = [0.9, 1.0, 1.15, 1.3, 1.5, 1.7]
    let moveStep: CGFloat = 70.0
    private weak var authState: AuthState?

    // Вычисляемые
    var alpha: CGFloat { transparencySteps[clamp(transparencyIndex, 0, transparencySteps.count - 1)] }
    var fontScale: CGFloat { fontScaleSteps[clamp(fontScaleIndex, 0, fontScaleSteps.count - 1)] }

    private init() {
        transcriptionStates = Dictionary(uniqueKeysWithValues: AudioSourceKind.allCases.map { ($0, TranscriptionChannelState()) })
        updateDerivedTranscriptionState()
    }

    // MARK: - Transcription helpers
    func transcriptionState(for source: AudioSourceKind) -> TranscriptionChannelState {
        transcriptionStates[source] ?? TranscriptionChannelState()
    }

    func updateTranscriptionState(for source: AudioSourceKind, mutate: (inout TranscriptionChannelState) -> Void) {
        var state = transcriptionStates[source] ?? TranscriptionChannelState()
        mutate(&state)
        transcriptionStates[source] = state
        updateDerivedTranscriptionState()
    }

    func clearTranscription(for source: AudioSourceKind) {
        transcriptionStates[source] = TranscriptionChannelState()
        updateDerivedTranscriptionState()
    }

    var anyChannelIsTranscribing: Bool {
        transcriptionStates.values.contains { $0.isTranscribing }
    }

    var aggregatedPhase: AudioChannelPhase {
        if transcriptionStates.values.contains(where: { $0.phase == .stopping }) { return .stopping }
        if transcriptionStates.values.contains(where: { $0.phase == .starting }) { return .starting }
        if transcriptionStates.values.contains(where: { $0.phase == .running }) { return .running }
        return .idle
    }

    func combinedTranscript(includePartials: Bool = true) -> String {
        var blocks: [String] = []
        for source in AudioSourceKind.allCases {
            let state = transcriptionState(for: source)
            var lines = state.transcriptLog.map(\.text)
            if includePartials, !state.partialText.isEmpty {
                lines.append(state.partialText)
            }
            guard !lines.isEmpty else { continue }
            blocks.append(([source.title] + lines).joined(separator: "\n"))
        }
        return blocks.joined(separator: "\n\n")
    }

    func transcriptTail(for source: AudioSourceKind, maxChars: Int = 900) -> String {
        let state = transcriptionState(for: source)
        var text = state.transcriptLog.suffix(14).map(\.text).joined(separator: " ")
        if !state.partialText.isEmpty { text += " " + state.partialText }
        if text.count > maxChars { text = String(text.suffix(maxChars)) }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func updateDerivedTranscriptionState() {
        isRecording = transcriptionStates.values.contains { $0.isTranscribing }
        if let system = transcriptionStates[.system] {
            transcriptLog = system.transcriptLog
            partialText = system.partialText
            lastError = system.lastError
        } else {
            transcriptLog = []
            partialText = ""
            lastError = nil
        }
    }

    // MARK: helpers/actions
    func clamp(_ v: Int, _ lo: Int, _ hi: Int) -> Int { max(lo, min(v, hi)) }

    func resetDefaults() {
        fontScaleIndex = 1
        transparencyIndex = 1
        if let screen = NSScreen.main { OverlayWindowManager.shared.center(on: screen) }
    }

    func attachAuth(_ auth: AuthState) {
        Task { @MainActor [weak self] in
            self?.authState = auth
            HintAgent.shared.attachAuth(auth)
        }
    }

    func startStopRecording() {
        isRecording.toggle()
        ServerClient.shared.log("[STUB] recording = \(isRecording ? "on" : "off")")
    }

    func askHint() {
        Task { @MainActor [weak self] in
            guard let self else { return }

            guard let auth = self.authState else {
                HintAgent.shared.error = "Авторизация не инициализирована. Перезапустите приложение."
                return
            }

            guard auth.isAuthorized else {
                let message = auth.authorizationIssue ?? "API-ключ недействителен. Обновите ключ, чтобы получить подсказку."
                HintAgent.shared.error = message
                return
            }

            await HintAgent.shared.requestHint(for: .general)
        }
    }

    func askSolve() {
        Task { @MainActor [weak self] in
            guard let self else { return }

            guard let auth = self.authState else {
                ServerClient.shared.log("Авторизация недоступна. Добавьте API-ключ, чтобы отправлять запросы.")
                return
            }

            guard auth.isAuthorized else {
                let message = auth.authorizationIssue ?? "API-ключ недействителен. Обновите ключ, чтобы продолжить."
                ServerClient.shared.log(message)
                return
            }

            askSolveTrigger &+= 1
        }
    }
}
