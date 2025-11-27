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

    enum CalloutPosition {
        case above
        case below
        case leading
        case trailing
    }

    enum ToolbarAnchorID: String, CaseIterable {
        case shell
        case listen
        case listenPanelControls
        case ask
        case eye
        case menu
    }

    struct ToolbarAnchor: Identifiable, Equatable {
        let id: ToolbarAnchorID
        var frameInScreen: CGRect
    }

    enum TutorialObstacleKind: CaseIterable {
        case toolbar
        case listenPanel
        case askPanel
        case settingsPanel
    }

    struct TutorialObstacles: Equatable {
        var toolbarFrameInScreen: CGRect?
        var listenPanelFrameInScreen: CGRect?
        var askPanelFrameInScreen: CGRect?
        var settingsPanelFrameInScreen: CGRect?

        var activeFramesInScreen: [CGRect] {
            [toolbarFrameInScreen, listenPanelFrameInScreen, askPanelFrameInScreen, settingsPanelFrameInScreen]
                .compactMap { frame in
                    guard let frame, !frame.isNull, !frame.isEmpty else { return nil }
                    return frame
                }
        }
    }

    struct TutorialObstacleFrame: Equatable {
        let kind: TutorialObstacleKind
        let frameInScreen: CGRect?
    }

    struct TutorialStep: Identifiable, Equatable {
        let id: String
        var title: String
        var description: String
        var targetFrameInScreenSpace: CGRect
        var calloutPosition: CalloutPosition
        var anchorID: ToolbarAnchorID?
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

    // Tutorial
    @Published var isTutorialVisible: Bool = false
    @Published var tutorialSteps: [TutorialStep] = []
    @Published var activeTutorialStepIndex: Int = 0
    @Published private(set) var toolbarAnchors: [ToolbarAnchorID: CGRect] = [:]
    @Published private(set) var tutorialObstacles = TutorialObstacles()
    @Published private(set) var listenPanelAdvanceToken: Int = 0
    private var pendingTutorialStepID: String?


    // Константы
    let transparencySteps: [CGFloat] = [1.0, 0.9, 0.8, 0.7, 0.6, 0.5]
    let fontScaleSteps: [CGFloat]     = [0.9, 1.0, 1.15, 1.3, 1.5, 1.7]
    let moveStep: CGFloat = 70.0
    private let listenPanelAdvanceDelay: TimeInterval = 0.5
    private let listenStepID = "listen"
    private let listenPanelControlsStepID = "listen_panel_controls"
    private weak var authState: AuthState?
    private var listenPanelAdvanceTask: Task<Void, Never>?

    var listenTutorialStepID: String { listenStepID }
    var listenPanelControlsTutorialStepID: String { listenPanelControlsStepID }

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

    // MARK: - Tutorial

    func updateToolbarAnchors(_ anchors: [ToolbarAnchor]) {
        // Обновление приходит из SwiftUI-преференсов, которые иногда триггерятся
        // вне главного потока. Публикация @Published-свойств в таком случае
        // падает с "_crashOnException", поэтому мягко перебрасываем работу на main.
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in
                self?.updateToolbarAnchors(anchors)
            }
            return
        }

        let incomingIDs = Set(anchors.map(\.id))

        var next = toolbarAnchors
        var changed = false

        for anchor in anchors {
            if next[anchor.id] != anchor.frameInScreen {
                next[anchor.id] = anchor.frameInScreen
                changed = true
            }
        }

        let removed = Set(next.keys).subtracting(incomingIDs)
        if !removed.isEmpty {
            next = next.filter { !removed.contains($0.key) }
            changed = true
        }

        guard changed else { return }

        toolbarAnchors = next
        updateTutorialTargetsForAnchors()
        tryActivatePendingTutorialStepIfNeeded()
    }

    func updateToolbarFrameInScreen(_ frame: CGRect?) {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in self?.updateToolbarFrameInScreen(frame) }
            return
        }

        var next = tutorialObstacles
        next.toolbarFrameInScreen = sanitizeObstacleFrame(frame)
        if tutorialObstacles != next { tutorialObstacles = next }
    }

    func updateTutorialPanelFrames(_ frames: [TutorialObstacleFrame]) {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in self?.updateTutorialPanelFrames(frames) }
            return
        }

        var next = tutorialObstacles
        next.listenPanelFrameInScreen = nil
        next.askPanelFrameInScreen = nil
        next.settingsPanelFrameInScreen = nil

        for frame in frames {
            let sanitized = sanitizeObstacleFrame(frame.frameInScreen)
            switch frame.kind {
            case .listenPanel:
                next.listenPanelFrameInScreen = sanitized
            case .askPanel:
                next.askPanelFrameInScreen = sanitized
            case .settingsPanel:
                next.settingsPanelFrameInScreen = sanitized
            case .toolbar:
                next.toolbarFrameInScreen = sanitized
            }
        }

        if tutorialObstacles != next { tutorialObstacles = next }
    }

    private func sanitizeObstacleFrame(_ frame: CGRect?) -> CGRect? {
        guard let frame, !frame.isNull, !frame.isEmpty else { return nil }
        return frame
    }

    func prepareDefaultTutorialSteps() {
        guard tutorialSteps.isEmpty else { return }
        tutorialSteps = makeDefaultTutorialSteps()
    }

    func showTutorial() {
        prepareDefaultTutorialSteps()
        activeTutorialStepIndex = 0
        updateTutorialTargetsForAnchors()
        isTutorialVisible = true
    }

    func hideTutorial() {
        isTutorialVisible = false
        cancelListenPanelAdvanceTask()
        pendingTutorialStepID = nil
    }

    func nextTutorialStep() {
        guard !tutorialSteps.isEmpty else { return }
        if isTutorialVisible, activeTutorialStep?.id == listenStepID {
            requestListenPanelAdvance()
            return
        }
        cancelListenPanelAdvanceTask()
        if activeTutorialStepIndex < tutorialSteps.count - 1 {
            activeTutorialStepIndex += 1
        } else {
            hideTutorial()
        }
    }

    func previousTutorialStep() {
        guard !tutorialSteps.isEmpty else { return }
        cancelListenPanelAdvanceTask()
        activeTutorialStepIndex = max(0, activeTutorialStepIndex - 1)
    }

    func requestListenPanelAdvance() {
        guard isTutorialVisible, activeTutorialStep?.id == listenStepID else { return }

        cancelListenPanelAdvanceTask()
        listenPanelAdvanceToken &+= 1

        let startedAt = Date()
        listenPanelAdvanceTask = Task { [weak self] in
            guard let self else { return }

            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 50_000_000)

                let hasAnchor = await MainActor.run { () -> Bool in
                    guard self.isTutorialVisible, self.activeTutorialStep?.id == self.listenStepID else { return false }
                    guard let anchor = self.toolbarAnchors[.listenPanelControls], !anchor.isEmpty else { return false }
                    return true
                }

                guard hasAnchor else { continue }

                let elapsed = Date().timeIntervalSince(startedAt)
                let remaining = max(0, listenPanelAdvanceDelay - elapsed)

                if remaining > 0 {
                    try? await Task.sleep(nanoseconds: UInt64(remaining * 1_000_000_000))
                }

                await MainActor.run { [weak self] in
                    guard let self else { return }
                    guard self.isTutorialVisible, self.activeTutorialStep?.id == self.listenStepID else { return }
                    guard let anchor = self.toolbarAnchors[.listenPanelControls], !anchor.isEmpty else { return }
                    self.goToTutorialStep(withID: self.listenPanelControlsStepID)
                }

                return
            }
        }
    }

    private func cancelListenPanelAdvanceTask() {
        listenPanelAdvanceTask?.cancel()
        listenPanelAdvanceTask = nil
    }

    private func goToTutorialStep(withID id: String) {
        guard let index = tutorialSteps.firstIndex(where: { $0.id == id }) else { return }

        if id == listenPanelControlsStepID {
            guard let anchor = toolbarAnchors[.listenPanelControls], !anchor.isEmpty else {
                pendingTutorialStepID = id
                return
            }
        }

        pendingTutorialStepID = nil
        activeTutorialStepIndex = index
    }

    private func tryActivatePendingTutorialStepIfNeeded() {
        guard let pending = pendingTutorialStepID else { return }
        guard pending == listenPanelControlsStepID else { return }
        guard let anchor = toolbarAnchors[.listenPanelControls], !anchor.isEmpty else { return }

        pendingTutorialStepID = nil
        goToTutorialStep(withID: pending)
    }

    func shiftToolbarAnchors(dx: CGFloat, dy: CGFloat) {
        guard dx != 0 || dy != 0 else { return }

        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in
                self?.shiftToolbarAnchors(dx: dx, dy: dy)
            }
            return
        }

        guard !toolbarAnchors.isEmpty else { return }

        let shifted = toolbarAnchors.mapValues { $0.offsetBy(dx: dx, dy: dy) }
        toolbarAnchors = shifted
        updateTutorialTargetsForAnchors()
    }

    func refreshTutorialTargetsFromAnchors() {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in
                self?.refreshTutorialTargetsFromAnchors()
            }
            return
        }

        updateTutorialTargetsForAnchors()
    }

    private func updateTutorialTargetsForAnchors() {
        guard !tutorialSteps.isEmpty else { return }
        var updated = tutorialSteps
        var didChange = false

        for index in updated.indices {
            guard let anchorID = updated[index].anchorID else { continue }

            if let frame = toolbarAnchors[anchorID], !frame.isEmpty {
                if updated[index].targetFrameInScreenSpace != frame {
                    updated[index].targetFrameInScreenSpace = frame
                    didChange = true
                }
            } else if anchorID == .listenPanelControls, !updated[index].targetFrameInScreenSpace.isEmpty {
                updated[index].targetFrameInScreenSpace = .zero
                didChange = true
            }
        }

        if didChange {
            tutorialSteps = updated
        }
    }

    private func makeDefaultTutorialSteps() -> [TutorialStep] {
        let shell = toolbarAnchors[.shell] ?? CGRect(x: 300, y: 160, width: 420, height: 60)
        let listen = toolbarAnchors[.listen] ?? shell
        let listenPanelControls = toolbarAnchors[.listenPanelControls] ?? .zero
        let ask = toolbarAnchors[.ask] ?? shell
        let eye = toolbarAnchors[.eye] ?? shell
        let menu = toolbarAnchors[.menu] ?? shell

        return [
            TutorialStep(
                id: listenStepID,
                title: "Слушайте происходящее",
                description: "Эта зона включает транскрибирование системного звука. Данные появляются мгновенно и не мешают работе других панелей.",
                targetFrameInScreenSpace: listen,
                calloutPosition: .above,
                anchorID: .listen
            ),
            TutorialStep(
                id: listenPanelControlsStepID,
                title: "Запускайте запись и микрофон",
                description: "Используйте кнопки Старт/Стоп и «Микрофон», чтобы включать нужные каналы перед отправкой запроса в Ask.",
                targetFrameInScreenSpace: listenPanelControls,
                calloutPosition: .below,
                anchorID: .listenPanelControls
            ),
            TutorialStep(
                id: "ask",
                title: "Задавайте вопросы",
                description: "Перейдите на вкладку Ask, чтобы сформулировать запрос к ассистенту или отправить свежий транскрипт одним нажатием.",
                targetFrameInScreenSpace: ask,
                calloutPosition: .trailing,
                anchorID: .ask
            ),
            TutorialStep(
                id: "eye",
                title: "Прячьте и показывайте",
                description: "Кнопка с глазом мгновенно скрывает панель без остановки фоновой работы. Используйте её, если интерфейс мешает содержимому экрана.",
                targetFrameInScreenSpace: eye,
                calloutPosition: .below,
                anchorID: .eye
            ),
            TutorialStep(
                id: "menu",
                title: "Откройте меню",
                description: "Встроенное меню ведёт к настройкам и дополнительным действиям. Позиция панели остаётся неизменной на протяжении обучения.",
                targetFrameInScreenSpace: menu,
                calloutPosition: .above,
                anchorID: .menu
            )
        ]
    }
}
