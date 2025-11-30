import Foundation
import AppKit
import Combine
import SwiftUI

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
        case listenStartButton
        case listenMicButton
        case listenInsights
        case listenRecordingControls
        case ask
        case askSubmitButton
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

    enum TutorialControlID {
        case toolbarListenTab
        case toolbarAskTab
        case toolbarEye
        case toolbarMenu

        case askSubmitButton

        case listenInsightsToggle
        case listenStartButton
        case listenMicButton

        case quickInsightWhatToSayNext
        case quickInsightWhatIsThisAbout
        case quickInsightWhatToAsk
    }

    struct TutorialInteractionPolicy {
        let allowedControlsByStepID: [String: Set<TutorialControlID>]

        func isControlEnabled(_ control: TutorialControlID, for stepID: String?) -> Bool {
            guard let stepID else { return true }
            guard let allowedControls = allowedControlsByStepID[stepID] else { return true }
            return allowedControls.contains(control)
        }
    }

    struct TutorialStep: Identifiable, Equatable {
        let id: String
        var title: String
        var description: String
        var targetFrameInScreenSpace: CGRect
        var calloutPosition: CalloutPosition
        var anchorID: ToolbarAnchorID?
        var showsSpotlight: Bool = true
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
    @Published var activeTutorialStepIndex: Int = 0 {
        didSet {
            if oldValue != activeTutorialStepIndex {
                handleTutorialStepChange(fromIndex: oldValue, toIndex: activeTutorialStepIndex)
            }
        }
    }
    @Published private(set) var toolbarAnchors: [ToolbarAnchorID: CGRect] = [:]
    @Published private(set) var tutorialObstacles = TutorialObstacles()
    @Published private(set) var listenPanelAdvanceToken: Int = 0
    @Published private(set) var tutorialCollapseToken: Int = 0
    @Published private(set) var tutorialCollapseDestination: CommandTab = .ask
    @Published private(set) var tutorialEnsureExpandedToken: Int = 0
    @Published private(set) var tutorialEnsureAskExpandedToken: Int = 0
    @Published private(set) var tutorialShowInsightsToken: Int = 0
    @Published private(set) var tutorialShowTranscriptToken: Int = 0
    @Published var tutorialTranscriptScript: [TranscriptMessage] = []
    @Published var isInsightsCalloutReady: Bool = true
    @Published var suppressCalloutForCurrentStep: Bool = false
    @Published var tutorialQuickInsightSample: String? = nil
    @Published var tutorialAskSampleResponse: String? = nil
    private var pendingTutorialStepID: String?


    // Константы
    let transparencySteps: [CGFloat] = [1.0, 0.9, 0.8, 0.7, 0.6, 0.5]
    let fontScaleSteps: [CGFloat]     = [0.9, 1.0, 1.15, 1.3, 1.5, 1.7]
    let moveStep: CGFloat = 70.0
    private let listenPanelAdvanceDelay: TimeInterval = 0.5
    private let listenStepID = "listen"
    private let listenRecordingControlsStepID = "listen_panel_controls"
    private let listenInsightsIntroStepID = "listen_insights_intro"
    private let listenQuickInsightsStepID = "listen_quick_insights"
    private let askStepID = "ask"
    private let askSubmitStepID = "ask_submit"
    private let eyeStepID = "eye"
    private let menuStepID = "menu"
    let interactionPolicy = TutorialInteractionPolicy(
        allowedControlsByStepID: [
            "listen_panel_controls": [
                .listenStartButton,
                .listenMicButton,
            ],
            "listen_insights_intro": [
                .listenInsightsToggle
            ],
            "listen_quick_insights": [
                .quickInsightWhatToSayNext,
                .quickInsightWhatIsThisAbout,
                .quickInsightWhatToAsk
            ],
            "ask": [
                .toolbarAskTab
            ],
            "eye": [
                .toolbarEye
            ]
        ]
    )
    private weak var authState: AuthState?
    private var listenPanelAdvanceTask: Task<Void, Never>?
    private var insightsIntroTask: Task<Void, Never>?
    private var quickInsightsToAskTask: Task<Void, Never>?
    private var backTransitionTask: Task<Void, Never>?
    private var askToSubmitTransitionTask: Task<Void, Never>?
    private var askSubmitToEyeTransitionTask: Task<Void, Never>?
    private var eyeToMenuTransitionTask: Task<Void, Never>?
    private var isTransitioningFromListenToControls = false
    private var shouldUnsuppressAfterListenAdvance = false
    private var isTransitioningFromQuickInsights = false
    private var isTransitioningFromAskToSubmit = false
    private var isAskSubmitToEyeTransitionInProgress = false
    private var isEyeToMenuTransitionInProgress = false
    private var isBackTransitionInProgress = false

    var listenTutorialStepID: String { listenStepID }
    var listenPanelControlsTutorialStepID: String { listenRecordingControlsStepID }
    var listenInsightsIntroTutorialStepID: String { listenInsightsIntroStepID }
    var listenQuickInsightsTutorialStepID: String { listenQuickInsightsStepID }
    var askTutorialStepID: String { askStepID }
    var askSubmitTutorialStepID: String { askSubmitStepID }
    var eyeTutorialStepID: String { eyeStepID }

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

    func isCalloutReady(for stepID: String?) -> Bool {
        guard let stepID else { return true }
        if suppressCalloutForCurrentStep { return false }
        if stepID == listenInsightsIntroStepID { return isInsightsCalloutReady }
        return true
    }

    func isControlEnabled(_ control: TutorialControlID) -> Bool {
        guard isTutorialVisible else { return true }
        return interactionPolicy.isControlEnabled(control, for: activeTutorialStep?.id)
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
        updateTutorialTargetsForAnchors()
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
        cancelInsightsIntroSequence()
        cancelQuickInsightsToAskTransition()
        cancelBackTransitionIfNeeded()
        cancelAskToSubmitTransition()
        cancelAskSubmitToEyeTransition()
        cancelEyeToMenuTransition()
        isTransitioningFromListenToControls = false
        shouldUnsuppressAfterListenAdvance = false
        suppressCalloutForCurrentStep = false
        tutorialQuickInsightSample = nil
        tutorialAskSampleResponse = nil
    }

    func nextTutorialStep() {
        guard !tutorialSteps.isEmpty else { return }
        if isTutorialVisible, let currentStepID = activeTutorialStep?.id {
            if currentStepID == listenStepID {
                advanceFromListenToControlsAnimated()
                return
            }

            if currentStepID == listenInsightsIntroStepID {
                advanceFromInsightsIntroToQuickInsights()
                return
            }

            if currentStepID == listenQuickInsightsStepID {
                advanceFromQuickInsightsToAskAnimated()
                return
            }

            if currentStepID == askStepID {
                advanceFromAskTabToAskSubmitStepAnimated()
                return
            }

            if currentStepID == askSubmitStepID {
                advanceFromAskSubmitToEyeAnimated()
                return
            }

            if currentStepID == eyeStepID {
                advanceFromEyeToMenuAnimated()
                return
            }
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
        if isAskSubmitToEyeTransitionInProgress {
            cancelAskSubmitToEyeTransition()
        }
        guard !isTransitioningFromQuickInsights else { return }
        guard !isTransitioningFromAskToSubmit else { return }
        guard !isBackTransitionInProgress else { return }

        guard let step = activeTutorialStep else {
            activeTutorialStepIndex = max(0, activeTutorialStepIndex - 1)
            return
        }

        if step.id == askStepID {
            goBackFromAskToQuickInsightsAnimated()
            return
        }

        if step.id == listenQuickInsightsStepID {
            goBackFromQuickInsightsToInsightsIntroAnimated()
            return
        }

        if step.id == listenInsightsIntroStepID {
            goBackFromInsightsIntroToListenControlsAnimated()
            return
        }

        if step.id == listenRecordingControlsStepID {
            goBackFromListenControlsToListenStepAnimated()
            return
        }

        activeTutorialStepIndex = max(0, activeTutorialStepIndex - 1)
    }

    func advanceFromListenToControlsAnimated() {
        guard isTutorialVisible, activeTutorialStep?.id == listenStepID else { return }
        guard !isTransitioningFromListenToControls else { return }

        isTransitioningFromListenToControls = true
        shouldUnsuppressAfterListenAdvance = true

        withAnimation(.easeOut(duration: 0.2)) {
            suppressCalloutForCurrentStep = true
        }

        tutorialEnsureExpandedToken &+= 1
        requestListenPanelAdvance()
    }

    func requestListenPanelAdvance() {
        guard isTutorialVisible, activeTutorialStep?.id == listenStepID || isTransitioningFromListenToControls else { return }

        cancelListenPanelAdvanceTask(resetTransitionState: false)
        listenPanelAdvanceToken &+= 1

        let startedAt = Date()
        listenPanelAdvanceTask = Task { [weak self] in
            guard let self else { return }

            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 20_000_000)

                let hasAnchor = await MainActor.run { () -> Bool in
                    guard self.isTutorialVisible, self.activeTutorialStep?.id == self.listenStepID else { return false }
                    guard let frame = self.recordingControlsFrame(), !frame.isEmpty else { return false }
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
                    guard let frame = self.recordingControlsFrame(), !frame.isEmpty else { return }
                    self.goToTutorialStep(withID: self.listenRecordingControlsStepID)
                    self.listenPanelAdvanceTask = nil
                }

                return
            }
        }
    }

    private func cancelListenPanelAdvanceTask(resetTransitionState: Bool = true) {
        listenPanelAdvanceTask?.cancel()
        listenPanelAdvanceTask = nil
        if resetTransitionState {
            isTransitioningFromListenToControls = false
            shouldUnsuppressAfterListenAdvance = false
        }
    }

    func requestAskPanelExpandedForTutorial() {
        tutorialEnsureAskExpandedToken &+= 1
    }

    func advanceFromListenControlsToInsightsIntro() {
        guard isTutorialVisible, activeTutorialStep?.id == listenRecordingControlsStepID else { return }
        goToTutorialStep(withID: listenInsightsIntroStepID)
    }

    func advanceFromInsightsIntroToQuickInsights() {
        guard isTutorialVisible, activeTutorialStep?.id == listenInsightsIntroStepID else { return }
        tutorialEnsureExpandedToken &+= 1
        tutorialShowInsightsToken &+= 1
        goToTutorialStep(withID: listenQuickInsightsStepID)
    }

    private func goToTutorialStep(withID id: String) {
        guard let index = tutorialSteps.firstIndex(where: { $0.id == id }) else { return }

        if id == listenRecordingControlsStepID {
            guard recordingControlsFrame().map({ !$0.isEmpty }) == true else {
                pendingTutorialStepID = id
                return
            }
        }

        pendingTutorialStepID = nil
        activeTutorialStepIndex = index
        completeListenToControlsTransitionIfNeeded()
    }

    private func completeListenToControlsTransitionIfNeeded() {
        guard shouldUnsuppressAfterListenAdvance else { return }
        guard activeTutorialStep?.id == listenRecordingControlsStepID else { return }

        withAnimation(.spring(response: 0.32, dampingFraction: 0.9)) {
            suppressCalloutForCurrentStep = false
        }

        isTransitioningFromListenToControls = false
        shouldUnsuppressAfterListenAdvance = false
    }

    private func tryActivatePendingTutorialStepIfNeeded() {
        guard let pending = pendingTutorialStepID else { return }
        guard pending == listenRecordingControlsStepID else { return }
        guard recordingControlsFrame().map({ !$0.isEmpty }) == true else { return }

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

    private func recordingControlsFrame() -> CGRect? {
        let start = toolbarAnchors[.listenStartButton]
        let mic = toolbarAnchors[.listenMicButton]

        if let start, let mic, !start.isEmpty, !mic.isEmpty {
            return start.union(mic)
        }

        if let start, !start.isEmpty {
            return start
        }

        if let mic, !mic.isEmpty {
            return mic
        }

        if let fallback = toolbarAnchors[.listenPanelControls], !fallback.isEmpty {
            return fallback
        }

        return nil
    }

    private func updateTutorialTargetsForAnchors() {
        guard !tutorialSteps.isEmpty else { return }
        var updated = tutorialSteps
        var didChange = false

        for index in updated.indices {
            let step = updated[index]
            let targetFrame: CGRect?
            let anchorID = step.anchorID

            if step.id == listenQuickInsightsStepID {
                targetFrame = quickInsightsTargetFrame()
            } else if anchorID == .listenRecordingControls {
                targetFrame = recordingControlsFrame()
            } else if let anchorID {
                targetFrame = toolbarAnchors[anchorID]
            } else {
                targetFrame = step.targetFrameInScreenSpace
            }

            if let frame = targetFrame, !frame.isEmpty {
                if updated[index].targetFrameInScreenSpace != frame {
                    updated[index].targetFrameInScreenSpace = frame
                    didChange = true
                }
            } else if (anchorID == .listenPanelControls || anchorID == .listenRecordingControls || step.id == listenQuickInsightsStepID), !updated[index].targetFrameInScreenSpace.isEmpty {
                updated[index].targetFrameInScreenSpace = .zero
                didChange = true
            }
        }

        if didChange {
            tutorialSteps = updated
        }
    }

    private func quickInsightsTargetFrame() -> CGRect? {
        if let listenPanel = tutorialObstacles.listenPanelFrameInScreen, !listenPanel.isEmpty {
            return listenPanel
        }

        if let listenAnchor = toolbarAnchors[.listen], !listenAnchor.isEmpty {
            return listenAnchor
        }

        return toolbarAnchors[.listenInsights]
    }

    private func makeDefaultTutorialSteps() -> [TutorialStep] {
        let shell = toolbarAnchors[.shell] ?? CGRect(x: 300, y: 160, width: 420, height: 60)
        let listen = toolbarAnchors[.listen] ?? shell
        let listenPanelControls = recordingControlsFrame() ?? .zero
        let listenInsights = toolbarAnchors[.listenInsights] ?? listen
        let listenPanel = tutorialObstacles.listenPanelFrameInScreen ?? listen
        let ask = toolbarAnchors[.ask] ?? shell
        let askSubmit = toolbarAnchors[.askSubmitButton] ?? ask
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
                id: listenRecordingControlsStepID,
                title: "Запускайте запись и микрофон",
                description: "Используйте кнопки Старт/Стоп и «Микрофон», чтобы включать нужные каналы перед отправкой запроса в Ask.",
                targetFrameInScreenSpace: listenPanelControls,
                calloutPosition: .trailing,
                anchorID: .listenRecordingControls
            ),
            TutorialStep(
                id: listenInsightsIntroStepID,
                title: "Инсайты по звуку",
                description: "Здесь будут появляться готовые инсайты и резюме по системному звуку и микрофону. Нажмите «Инсайты», чтобы переключиться из транскрипта в аналитический режим.",
                targetFrameInScreenSpace: listenInsights,
                calloutPosition: .trailing,
                anchorID: .listenInsights
            ),
            TutorialStep(
                id: listenQuickInsightsStepID,
                title: "Быстрые инсайты",
                description: "Выберите один из сценариев, чтобы Ghost AI предложил идею, как продолжить разговор или о чём спросить собеседника.",
                targetFrameInScreenSpace: listenPanel,
                calloutPosition: .trailing,
                anchorID: nil,
                showsSpotlight: false
            ),
            TutorialStep(
                id: askStepID,
                title: "Задавайте вопросы",
                description: "Перейдите на вкладку Ask, чтобы сформулировать запрос к ассистенту или отправить свежий транскрипт одним нажатием.",
                targetFrameInScreenSpace: ask,
                calloutPosition: .trailing,
                anchorID: .ask
            ),
            TutorialStep(
                id: askSubmitStepID,
                title: "Отправка запроса",
                description: "Когда вы нажимаете кнопку Submit, Ghost AI делает снимок экрана и учитывает ваш разговор. Это помогает понять контекст: что происходит на экране и о чём вы говорите. Нажмите «Submit», чтобы получить подсказку с учётом вашего контекста.",
                targetFrameInScreenSpace: askSubmit,
                calloutPosition: .above,
                anchorID: .askSubmitButton
            ),
            TutorialStep(
                id: eyeStepID,
                title: "Прячьте и показывайте",
                description: "Кнопка с глазом мгновенно скрывает панель без остановки фоновой работы. Используйте её, если интерфейс мешает содержимому экрана.",
                targetFrameInScreenSpace: eye,
                calloutPosition: .below,
                anchorID: .eye
            ),
            TutorialStep(
                id: menuStepID,
                title: "Откройте меню",
                description: "Встроенное меню ведёт к настройкам и дополнительным действиям. Позиция панели остаётся неизменной на протяжении обучения.",
                targetFrameInScreenSpace: menu,
                calloutPosition: .above,
                anchorID: .menu
            )
        ]
    }

    private func handleTutorialStepChange(fromIndex: Int, toIndex: Int) {
        let oldID = tutorialStepID(at: fromIndex)
        let newID = tutorialStepID(at: toIndex)

        if abs(fromIndex - toIndex) > 1 {
            cancelBackTransitionIfNeeded()
            suppressCalloutForCurrentStep = false
        }

        if oldID == listenInsightsIntroStepID, newID != listenInsightsIntroStepID {
            cancelInsightsIntroSequence()
        }

        if newID == listenInsightsIntroStepID {
            startInsightsIntroSequence()
        }

        if oldID == listenQuickInsightsStepID, newID != listenQuickInsightsStepID {
            cancelQuickInsightsToAskTransition()
            tutorialQuickInsightSample = nil
            suppressCalloutForCurrentStep = false
        }

        if newID == listenQuickInsightsStepID {
            tutorialQuickInsightSample = nil
        }

        if oldID == askSubmitStepID, newID != askSubmitStepID, newID != eyeStepID {
            cancelAskSubmitToEyeTransition()
        }

        if newID == askSubmitStepID {
            cancelAskSubmitToEyeTransition()
            tutorialAskSampleResponse = nil
        }
    }

    private func tutorialStepID(at index: Int) -> String? {
        guard tutorialSteps.indices.contains(index) else { return nil }
        return tutorialSteps[index].id
    }

    private func startInsightsIntroSequence() {
        cancelInsightsIntroSequence()

        insightsIntroTask = Task { [weak self] in
            guard let self else { return }

            await MainActor.run {
                self.isInsightsCalloutReady = false
                self.tutorialTranscriptScript = []
            }

            let script: [TranscriptMessage] = [
                TranscriptMessage(source: .system, text: "Вот так будут выглядеть фрагменты транскрипта системного звука."),
                TranscriptMessage(source: .microphone, text: "А здесь — фразы, записанные с микрофона пользователя."),
            ]

            let delays: [UInt64] = [420_000_000, 520_000_000]

            for (index, message) in script.enumerated() {
                if index < delays.count {
                    try? await Task.sleep(nanoseconds: delays[index])
                }

                guard !Task.isCancelled else { return }

                await MainActor.run {
                    withAnimation(.spring(response: 0.48, dampingFraction: 0.86)) {
                        self.tutorialTranscriptScript.append(message)
                    }
                }
            }

            try? await Task.sleep(nanoseconds: 500_000_000)
            guard !Task.isCancelled else { return }

            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.28)) {
                    self.isInsightsCalloutReady = true
                }
            }
        }
    }

    private func cancelInsightsIntroSequence() {
        insightsIntroTask?.cancel()
        insightsIntroTask = nil

        Task { @MainActor [weak self] in
            guard let self else { return }
            self.tutorialTranscriptScript = []
            self.isInsightsCalloutReady = true
        }
    }

    func advanceFromQuickInsightsToAskAnimated() {
        guard isTutorialVisible, activeTutorialStep?.id == listenQuickInsightsStepID else { return }
        guard !isTransitioningFromQuickInsights else { return }

        tutorialCollapseDestination = .ask
        isTransitioningFromQuickInsights = true
        tutorialQuickInsightSample = nil
        withAnimation(.easeOut(duration: 0.2)) {
            suppressCalloutForCurrentStep = true
        }

        tutorialCollapseToken &+= 1

        quickInsightsToAskTask?.cancel()
        quickInsightsToAskTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 520_000_000)

            await MainActor.run { [weak self] in
                guard let self else { return }

                self.goToTutorialStep(withID: self.askStepID)

                withAnimation(.spring(response: 0.32, dampingFraction: 0.9)) {
                    self.suppressCalloutForCurrentStep = false
                }

                self.isTransitioningFromQuickInsights = false
                self.quickInsightsToAskTask = nil
            }
        }
    }

    func advanceFromAskTabToAskSubmitStepAnimated() {
        guard isTutorialVisible, activeTutorialStep?.id == askStepID else { return }
        guard !isTransitioningFromAskToSubmit else { return }

        isTransitioningFromAskToSubmit = true

        withAnimation(.easeOut(duration: 0.2)) {
            suppressCalloutForCurrentStep = true
        }

        requestAskPanelExpandedForTutorial()

        askToSubmitTransitionTask?.cancel()
        askToSubmitTransitionTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 300_000_000)

            await MainActor.run { [weak self] in
                guard let self else { return }

                self.goToTutorialStep(withID: self.askSubmitStepID)

                withAnimation(.spring(response: 0.32, dampingFraction: 0.9)) {
                    self.suppressCalloutForCurrentStep = false
                }

                self.isTransitioningFromAskToSubmit = false
                self.askToSubmitTransitionTask = nil
            }
        }
    }

    func advanceFromAskSubmitToEyeAnimated() {
        guard isTutorialVisible, activeTutorialStep?.id == askSubmitStepID else { return }
        guard !isAskSubmitToEyeTransitionInProgress else { return }

        isAskSubmitToEyeTransitionInProgress = true

        withAnimation(.easeOut(duration: 0.2)) {
            suppressCalloutForCurrentStep = true
        }

        askSubmitToEyeTransitionTask?.cancel()
        let sample = """
Здесь будут появляться ответы Ghost AI.
Мы учитываем ваш скриншот и контекст разговора, чтобы дать максимально уместный совет.
"""

        askSubmitToEyeTransitionTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 200_000_000)

            await MainActor.run { [weak self] in
                guard let self else { return }
                withAnimation(.easeInOut(duration: 0.24)) {
                    self.tutorialAskSampleResponse = sample
                }
            }

            try? await Task.sleep(nanoseconds: 320_000_000)

            await MainActor.run { [weak self] in
                guard let self else { return }

                self.goToTutorialStep(withID: self.eyeStepID)
                self.suppressCalloutForCurrentStep = false
                self.isAskSubmitToEyeTransitionInProgress = false
                self.askSubmitToEyeTransitionTask = nil
            }
        }
    }

    private func cancelQuickInsightsToAskTransition() {
        quickInsightsToAskTask?.cancel()
        quickInsightsToAskTask = nil
        isTransitioningFromQuickInsights = false
    }

    private func cancelAskToSubmitTransition() {
        askToSubmitTransitionTask?.cancel()
        askToSubmitTransitionTask = nil
        isTransitioningFromAskToSubmit = false
    }

    private func cancelAskSubmitToEyeTransition(resetSample: Bool = true) {
        askSubmitToEyeTransitionTask?.cancel()
        askSubmitToEyeTransitionTask = nil
        isAskSubmitToEyeTransitionInProgress = false
        if resetSample {
            tutorialAskSampleResponse = nil
        }
        suppressCalloutForCurrentStep = false
    }

    func advanceFromEyeToMenuAnimated() {
        guard isTutorialVisible, activeTutorialStep?.id == eyeStepID else { return }
        guard !isEyeToMenuTransitionInProgress else { return }

        isEyeToMenuTransitionInProgress = true

        withAnimation(.easeOut(duration: 0.2)) {
            suppressCalloutForCurrentStep = true
        }

        tutorialCollapseDestination = .ask
        tutorialCollapseToken &+= 1

        eyeToMenuTransitionTask?.cancel()
        eyeToMenuTransitionTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 300_000_000)

            await MainActor.run { [weak self] in
                guard let self else { return }
                guard self.isTutorialVisible else {
                    self.isEyeToMenuTransitionInProgress = false
                    self.eyeToMenuTransitionTask = nil
                    return
                }

                self.goToTutorialStep(withID: self.menuStepID)

                withAnimation(.spring(response: 0.32, dampingFraction: 0.9)) {
                    self.suppressCalloutForCurrentStep = false
                }

                self.isEyeToMenuTransitionInProgress = false
                self.eyeToMenuTransitionTask = nil
            }
        }
    }

    private func goBackFromAskToQuickInsightsAnimated() {
        guard isTutorialVisible, activeTutorialStep?.id == askStepID else { return }
        guard !isBackTransitionInProgress else { return }

        isBackTransitionInProgress = true

        withAnimation(.easeOut(duration: 0.2)) {
            suppressCalloutForCurrentStep = true
        }

        tutorialEnsureExpandedToken &+= 1
        tutorialShowInsightsToken &+= 1

        backTransitionTask?.cancel()
        backTransitionTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 520_000_000)

            await MainActor.run { [weak self] in
                guard let self else { return }

                self.goToTutorialStep(withID: self.listenQuickInsightsStepID)

                withAnimation(.spring(response: 0.32, dampingFraction: 0.9)) {
                    self.suppressCalloutForCurrentStep = false
                }

                self.isBackTransitionInProgress = false
                self.backTransitionTask = nil
            }
        }
    }

    private func goBackFromQuickInsightsToInsightsIntroAnimated() {
        guard isTutorialVisible, activeTutorialStep?.id == listenQuickInsightsStepID else { return }
        guard !isBackTransitionInProgress else { return }

        isBackTransitionInProgress = true

        withAnimation(.easeOut(duration: 0.2)) {
            suppressCalloutForCurrentStep = true
        }

        tutorialShowTranscriptToken &+= 1

        backTransitionTask?.cancel()
        backTransitionTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 200_000_000)

            await MainActor.run { [weak self] in
                guard let self else { return }

                self.goToTutorialStep(withID: self.listenInsightsIntroStepID)

                withAnimation(.spring(response: 0.32, dampingFraction: 0.9)) {
                    self.suppressCalloutForCurrentStep = false
                }

                self.isBackTransitionInProgress = false
                self.backTransitionTask = nil
            }
        }
    }

    private func goBackFromInsightsIntroToListenControlsAnimated() {
        guard isTutorialVisible, activeTutorialStep?.id == listenInsightsIntroStepID else { return }
        guard !isBackTransitionInProgress else { return }

        isBackTransitionInProgress = true

        withAnimation(.easeOut(duration: 0.2)) {
            suppressCalloutForCurrentStep = true
        }

        backTransitionTask?.cancel()
        backTransitionTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 150_000_000)

            await MainActor.run { [weak self] in
                guard let self else { return }

                self.goToTutorialStep(withID: self.listenRecordingControlsStepID)

                withAnimation(.spring(response: 0.32, dampingFraction: 0.9)) {
                    self.suppressCalloutForCurrentStep = false
                }

                self.isBackTransitionInProgress = false
                self.backTransitionTask = nil
            }
        }
    }

    private func goBackFromListenControlsToListenStepAnimated() {
        guard isTutorialVisible, activeTutorialStep?.id == listenRecordingControlsStepID else { return }
        guard !isBackTransitionInProgress else { return }

        isBackTransitionInProgress = true

        withAnimation(.easeOut(duration: 0.2)) {
            suppressCalloutForCurrentStep = true
        }

        tutorialCollapseDestination = .listen
        tutorialCollapseToken &+= 1

        backTransitionTask?.cancel()
        backTransitionTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 300_000_000)

            await MainActor.run { [weak self] in
                guard let self else { return }

                self.goToTutorialStep(withID: self.listenStepID)

                withAnimation(.spring(response: 0.32, dampingFraction: 0.9)) {
                    self.suppressCalloutForCurrentStep = false
                }

                self.isBackTransitionInProgress = false
                self.backTransitionTask = nil
            }
        }
    }

    private func cancelBackTransitionIfNeeded() {
        backTransitionTask?.cancel()
        backTransitionTask = nil
        isBackTransitionInProgress = false
    }

    private func cancelEyeToMenuTransition() {
        eyeToMenuTransitionTask?.cancel()
        eyeToMenuTransitionTask = nil
        isEyeToMenuTransitionInProgress = false
        suppressCalloutForCurrentStep = false
    }
}
