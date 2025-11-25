import Foundation
import AppKit
import Combine

final class OverlayModel: ObservableObject {
    private enum Defaults {
        static let screenCaptureHidden = "overlay.screenCaptureHidden"
        static let designStyle = "overlay.designStyle"
    }

    enum DesignStyle: String {
        case classic
        case liquid

        static let `default`: DesignStyle = .classic
    }

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

    enum CalloutPosition: String, Codable {
        case automatic
        case above
        case below
        case leading
        case trailing
    }

    struct TutorialStep: Identifiable, Equatable {
        let id: String
        var title: String
        var description: String
        var targetFrameInScreenSpace: CGRect
        var calloutPosition: CalloutPosition

        init(
            id: String,
            title: String,
            description: String,
            targetFrameInScreenSpace: CGRect = .zero,
            calloutPosition: CalloutPosition = .automatic
        ) {
            self.id = id
            self.title = title
            self.description = description
            self.targetFrameInScreenSpace = targetFrameInScreenSpace
            self.calloutPosition = calloutPosition
        }
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
    @Published var isTutorialVisible: Bool = false
    @Published var tutorialSteps: [TutorialStep] = TutorialStep.sampleSteps()
    @Published var activeTutorialStepIndex: Int = 0
    @Published var isHiddenFromScreenCapture: Bool = {
        let defaults = UserDefaults.standard
        guard defaults.object(forKey: Defaults.screenCaptureHidden) != nil else { return true }
        return defaults.bool(forKey: Defaults.screenCaptureHidden)
    }() {
        didSet {
            let defaults = UserDefaults.standard
            defaults.set(isHiddenFromScreenCapture, forKey: Defaults.screenCaptureHidden)
            OverlayWindowManager.shared.updateScreenCaptureVisibility(hidden: isHiddenFromScreenCapture)
        }
    }

    @Published var preferredDesignStyle: DesignStyle = {
        let defaults = UserDefaults.standard
        guard let rawValue = defaults.string(forKey: Defaults.designStyle),
              let stored = DesignStyle(rawValue: rawValue) else {
            return .default
        }
        return stored
    }() {
        didSet {
            let defaults = UserDefaults.standard
            defaults.set(preferredDesignStyle.rawValue, forKey: Defaults.designStyle)
        }
    }

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

    var supportsLiquidGlass: Bool {
        if #available(macOS 26.0, *) {
            return true
        } else {
            return false
        }
    }

    var usesLiquidGlass: Bool {
        guard supportsLiquidGlass else { return false }
        return preferredDesignStyle == .liquid
    }

    var prefersLiquidGlass: Bool {
        get { preferredDesignStyle == .liquid }
        set { preferredDesignStyle = newValue ? .liquid : .classic }
    }

    var activeTutorialStep: TutorialStep? {
        guard tutorialSteps.indices.contains(activeTutorialStepIndex) else { return nil }
        return tutorialSteps[activeTutorialStepIndex]
    }

    private init() {
        transcriptionStates = Dictionary(uniqueKeysWithValues: AudioSourceKind.allCases.map { ($0, TranscriptionChannelState()) })
        updateDerivedTranscriptionState()
        OverlayWindowManager.shared.updateScreenCaptureVisibility(hidden: isHiddenFromScreenCapture)
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

    // MARK: - Tutorial

    func startTutorial() {
        activeTutorialStepIndex = 0
        isTutorialVisible = true
    }

    func finishTutorial() {
        isTutorialVisible = false
    }

    func goToNextTutorialStep() {
        let next = activeTutorialStepIndex + 1
        guard next < tutorialSteps.count else {
            finishTutorial()
            return
        }
        activeTutorialStepIndex = next
    }

    func goToPreviousTutorialStep() {
        guard activeTutorialStepIndex > 0 else { return }
        activeTutorialStepIndex -= 1
    }

    func updateTutorialAnchors(_ anchors: [String: CGRect]) {
        for idx in tutorialSteps.indices {
            let id = tutorialSteps[idx].id
            if let newFrame = anchors[id] {
                tutorialSteps[idx].targetFrameInScreenSpace = newFrame
            }
        }
    }

    func refreshTutorialAnchors(from onboardingTargets: [OnboardingTarget: CGRect]) {
        let mapped = onboardingTargets.reduce(into: [String: CGRect]()) { partialResult, pair in
            let id = tutorialIdentifier(for: pair.key)
            partialResult[id] = pair.value
        }
        updateTutorialAnchors(mapped)
    }

    private func tutorialIdentifier(for target: OnboardingTarget) -> String {
        switch target {
        case .toolbarShell: return "toolbar-shell"
        case .tabSwitcher: return "tab-switcher"
        case .visibilityToggle: return "visibility-toggle"
        case .menu: return "menu-button"
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

extension OverlayModel.TutorialStep {
    static func sampleSteps() -> [OverlayModel.TutorialStep] {
        [
            OverlayModel.TutorialStep(
                id: "toolbar-shell",
                title: "Плавающее окно Ghost",
                description: "Тулбар всегда остаётся поверх всего остального и сохраняет привычное поведение.",
                targetFrameInScreenSpace: CGRect(x: 120, y: 620, width: 420, height: 64),
                calloutPosition: .above
            ),
            OverlayModel.TutorialStep(
                id: "tab-switcher",
                title: "Переключение Listen / Ask",
                description: "Подсказка показывает, где менять контекст: транскрипт или вопросы к Ghost.",
                targetFrameInScreenSpace: CGRect(x: 180, y: 624, width: 160, height: 40),
                calloutPosition: .below
            ),
            OverlayModel.TutorialStep(
                id: "visibility-toggle",
                title: "Кнопка разворота",
                description: "Иконка глаза сворачивает или разворачивает интерфейс. В обучении кнопка остаётся интерактивной.",
                targetFrameInScreenSpace: CGRect(x: 360, y: 624, width: 42, height: 42),
                calloutPosition: .trailing
            ),
            OverlayModel.TutorialStep(
                id: "menu-button",
                title: "Меню действий",
                description: "Три точки открывают меню. В обучении можно нажимать элементы и видеть реальное поведение.",
                targetFrameInScreenSpace: CGRect(x: 420, y: 624, width: 42, height: 42),
                calloutPosition: .trailing
            )
        ]
    }
}
