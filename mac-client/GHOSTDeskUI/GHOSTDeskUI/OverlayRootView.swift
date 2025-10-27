import SwiftUI
import Combine
import AVFoundation
import CoreML
import WhisperKit

import ScreenCaptureKit
import CoreMedia
import Accelerate
import CoreGraphics



struct OverlayRootView: View {

    @ObservedObject private var overlay = OverlayModel.shared
    @EnvironmentObject private var auth: AuthState
    @State private var autoScroll = true
    @State private var isExpanded = false
    @State private var selectedTab: CommandTab = .listen
    @Namespace private var islandNS
    @State private var question: String = ""
    @State private var smartMode: Bool = false
    @FocusState private var askFocused: Bool
    @ObservedObject private var hint = HintAgent.shared
    @State private var showTranscript = true
    @State private var showResponse: Bool = false





    // наш безопасный ленивый транскрайбер
    @StateObject private var transcriptionCoordinator = TranscriptionCoordinator()

    // NEW: вью-модель для снапшота/отправки
    @StateObject private var askVM: AskVM
    @ObservedObject private var oauthCoordinator = OAuthCoordinator.shared

    init(auth: AuthState) {
        _askVM = StateObject(wrappedValue: AskVM(auth: auth))
        OAuthCoordinator.shared.configure(authState: auth)
    }

    private var systemChannelState: OverlayModel.TranscriptionChannelState {
        overlay.transcriptionState(for: .system)
    }

    private var microphoneChannelState: OverlayModel.TranscriptionChannelState {
        overlay.transcriptionState(for: .microphone)
    }

    var body: some View {
        Group {
            if auth.isAuthorized {
                authorizedOverlay

            } else {
                ApiKeyGateView()
                    .environmentObject(oauthCoordinator)
            }
        }


        // Если когда-нибудь захочешь дать AskVM доступ к активному SCStream,
        // просто присвой сюда askVM.stream = <твой stream> после старта.
    }

    private var authorizedOverlay: some View {
        ZStack {
            VStack(spacing: 14) {
                FloatingToolbar(
                    isRecording: overlay.anyChannelIsTranscribing,
                    selected: $selectedTab,
                    onPrimaryTap: { isExpanded = true },
                    onEyeTap: { isExpanded.toggle() },
                    onMenuTap: { overlay.showSettings = true }
                )
                .padding(.top, 8)

                if isExpanded {
                    Group {
                        if selectedTab == .listen {
                            listenPanel
                        } else {
                            askPanel
                        }
                    }
                    .padding(.horizontal, 8)
                    .matchedGeometryEffect(id: "island", in: islandNS)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(1)
                }

                Spacer(minLength: 0)

                    .onChange(of: isExpanded) { v in
                        if v && selectedTab == .ask { askFocused = true }
                    }
                    .onChange(of: selectedTab) { tab in
                        if isExpanded && tab == .ask { askFocused = true }
                    }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .animation(.spring(response: 0.35, dampingFraction: 0.86), value: isExpanded)

        }
        .onChange(of: overlay.askSolveTrigger) { _ in
            isExpanded = true
            selectedTab = .ask
            question = ""
            askFocused = true

            let transcriptTail = makeTranscriptTail(seconds: 40, maxChars: 900)
            Task {
                await askVM.submitWithoutQuery(transcript: transcriptTail)
            }
        }
        .background(Color.clear)
        .sheet(isPresented: Binding(
            get: { overlay.showSettings },
            set: { overlay.showSettings = $0 }
        )) {
            SettingsSheet(
                isShown: Binding(
                    get: { overlay.showSettings },
                    set: { overlay.showSettings = $0 }
                )
            )
                .environmentObject(auth)
        }
    }

    // MARK: - Listen Panel

    private var listenPanel: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {

                // HEADER
                HStack(spacing: 12) {
                    LogoOrb()

                    VStack(alignment: .leading, spacing: 2) {
                        Text(showTranscript ? "Транскрипт" : "Инсайты в реальном времени")
                            .font(.headline.weight(.semibold))
                        HStack(spacing: 8) {
                            LiveDot(active: overlay.anyChannelIsTranscribing)
                            Text(overlay.anyChannelIsTranscribing ? "Идёт запись…" : "Готов к запуску")
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(overlay.anyChannelIsTranscribing ? .green.opacity(0.9) : .secondary)
                        }
                    }

                    Spacer()

                    let microphonePhase = microphoneChannelState.phase
                    let microphoneBusy = microphonePhase == .starting || microphonePhase == .stopping

                    Button(showTranscript ? "Показать инсайты" : "Показать транскрипт") {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.9)) {
                            showTranscript.toggle()
                        }
                    }
                    .buttonStyle(GlassPill())

                    Button(action: {
                        transcriptionCoordinator.setMicrophoneArmed(!transcriptionCoordinator.isMicrophoneArmed)
                    }) {
                        Label("Микрофон", systemImage: transcriptionCoordinator.isMicrophoneArmed ? "mic.fill" : "mic")
                    }
                    .buttonStyle(GlassPill(tint: transcriptionCoordinator.isMicrophoneArmed ? .pink : .secondary))
                    .disabled(microphoneBusy)

                    Button(action: {
                        switch transcriptionCoordinator.overallPhase {
                        case .idle:
                            transcriptionCoordinator.startRecording()
                        case .starting, .running, .stopping:
                            transcriptionCoordinator.stopAll()
                        }
                    }) {
                        let phase = transcriptionCoordinator.overallPhase
                        let running  = phase == .running
                        let starting = phase == .starting
                        let stopping = phase == .stopping
                        Label(
                            starting ? "Запуск…" : (stopping ? "Остановка…" : (running ? "Стоп" : "Старт")),
                            systemImage: (running || stopping) ? "stop.fill" : "play.fill"
                        )
                    }
                    .buttonStyle(
                        GlassPill(
                            tint: {
                                let phase = transcriptionCoordinator.overallPhase
                                return (phase == .running || phase == .stopping) ? .red : .accentColor
                            }()
                        )
                    )
                    .disabled(transcriptionCoordinator.overallPhase == .starting)
                }

                Divider().overlay(Color.white.opacity(0.10))

                // BODY — единая чатовая лента
                Group {
                    if showTranscript {
                        TranscriptChatView(
                            systemState: systemChannelState,
                            microphoneState: microphoneChannelState,
                            autoScroll: $autoScroll
                        )
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    } else {
                        InsightsPanel(
                            onNext: { /* TODO */ },
                            onTopic: { /* TODO */ },
                            onQuestion: { /* TODO */ }
                        )
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
                .frame(minHeight: 320, maxHeight: 520) // ↑ единое окно с чатом
                HintStrip()
            }
        }
        .frame(maxWidth: 600)   // ↓ уже, чем раньше
        .padding(.horizontal, 8)
    }

    private struct InsightsPanel: View {
        var onNext: () -> Void = {}
        var onTopic: () -> Void = {}
        var onQuestion: () -> Void = {}

        var body: some View {
            ZStack {
                let shape = RoundedRectangle(cornerRadius: 12, style: .continuous)
                shape
                    .fill(Color.white.opacity(0.03))
                    .overlay(shape.stroke(.white.opacity(0.08), lineWidth: 1))

                // КНОПКИ ВНУТРИ ПОЛЯ (по центру)
                VStack(spacing: 12) {
                    LazyVGrid(
                        columns: [GridItem(.flexible())],
                        alignment: .center,
                        spacing: 8
                    ) {
                        Button("Что сказать дальше?", action: onNext)
                            .buttonStyle(GlassPill())
                        Button("О чём речь?", action: onTopic)
                            .buttonStyle(GlassPill())
                        Button("Какой вопрос задать?", action: onQuestion)
                            .buttonStyle(GlassPill())
                    }
                }
                .padding(16)
                .frame(maxWidth: 420) // чтобы сетка держала красивую ширину
            }
            .frame(maxWidth: .infinity, minHeight: 240, alignment: .center)
        }
    }



    private struct TranscriptChatView: View {
        let systemState: OverlayModel.TranscriptionChannelState
        let microphoneState: OverlayModel.TranscriptionChannelState
        @Binding var autoScroll: Bool

        @State private var hasAppeared = false

        private var mergedMessages: [OverlayModel.TranscriptMessage] {
            (systemState.transcriptLog + microphoneState.transcriptLog)
                .sorted { lhs, rhs in
                    if lhs.timestamp == rhs.timestamp {
                        return lhs.id.uuidString < rhs.id.uuidString
                    }
                    return lhs.timestamp < rhs.timestamp
                }
        }

        private func partialText(for kind: OverlayModel.AudioSourceKind) -> String? {
            let text: String
            switch kind {
            case .system:
                text = systemState.partialText
            case .microphone:
                text = microphoneState.partialText
            }
            return text.isEmpty ? nil : text
        }

        private func partialIdentifier(_ kind: OverlayModel.AudioSourceKind) -> String {
            "partial_\(kind.rawValue)"
        }

        private var lastAnchorID: AnyHashable? {
            if let micPartial = partialText(for: .microphone) {
                return AnyHashable(partialIdentifier(.microphone) + micPartial)
            }
            if let systemPartial = partialText(for: .system) {
                return AnyHashable(partialIdentifier(.system) + systemPartial)
            }
            return mergedMessages.last?.id
        }

        var body: some View {
            VStack(alignment: .leading, spacing: 12) {
                ScrollViewReader { proxy in
                    ZStack {
                        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)

                        shape
                            .fill(Color.white.opacity(0.03))
                            .overlay(
                                shape.stroke(Color.white.opacity(0.08), lineWidth: 1)
                            )

                        ScrollView {
                            LazyVStack(spacing: 12) {
                                ForEach(mergedMessages) { message in
                                    let style = TranscriptSourceStyle.for(kind: message.source)
                                    TranscriptMessageBubble(message: message, style: style)
                                        .id(message.id)
                                }

                                if let text = partialText(for: .system) {
                                    PartialTranscriptBubble(text: text, style: .for(kind: .system))
                                        .id(partialIdentifier(.system) + text)
                                }

                                if let text = partialText(for: .microphone) {
                                    PartialTranscriptBubble(text: text, style: .for(kind: .microphone))
                                        .id(partialIdentifier(.microphone) + text)
                                }
                            }
                            .padding(.vertical, 16)
                            .padding(.horizontal, 14)
                        }
                        .clipShape(shape)
                    }
                    .frame(minHeight: 320, maxHeight: .infinity, alignment: .top)
                    .onAppear {
                        hasAppeared = true
                        DispatchQueue.main.async {
                            scrollToBottom(proxy, animated: false)
                        }
                    }
                    .onChange(of: systemState.transcriptLog.last?.id) { _ in
                        guard hasAppeared else { return }
                        scrollToBottom(proxy)
                    }
                    .onChange(of: microphoneState.transcriptLog.last?.id) { _ in
                        guard hasAppeared else { return }
                        scrollToBottom(proxy)
                    }
                    .onChange(of: systemState.partialText) { _ in
                        guard hasAppeared else { return }
                        scrollToBottom(proxy)
                    }
                    .onChange(of: microphoneState.partialText) { _ in
                        guard hasAppeared else { return }
                        scrollToBottom(proxy)
                    }
                    .onChange(of: autoScroll) { enabled in
                        guard enabled, hasAppeared else { return }
                        scrollToBottom(proxy, animated: false)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }

        private func scrollToBottom(_ proxy: ScrollViewProxy, animated: Bool = true) {
            guard autoScroll, let anchor = lastAnchorID else { return }
            let action = {
                proxy.scrollTo(anchor, anchor: .bottom)
            }
            if animated {
                withAnimation(.easeOut(duration: 0.22)) { action() }
            } else {
                action()
            }
        }
    }

    private struct TranscriptMessageBubble: View {
        let message: OverlayModel.TranscriptMessage
        let style: TranscriptSourceStyle

        var body: some View {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: style.icon)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(style.color.opacity(0.85))
                    Text(style.title)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(style.color.opacity(0.85))
                    Spacer(minLength: 0)
                }

                Text(message.text)
                    .font(.system(size: 14))
                    .foregroundStyle(.primary)
                    .textSelection(.enabled)

                Text(message.timestamp, style: .time)
                    .font(.caption2)
                    .foregroundStyle(style.color.opacity(0.8))
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 14)
            .frame(maxWidth: 320, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(style.color.opacity(0.16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(style.color.opacity(0.22), lineWidth: 1)
                    )
            )
            .frame(maxWidth: .infinity, alignment: style.bubbleAlignment)
            .transition(.move(edge: .trailing).combined(with: .opacity))
        }
    }

    private struct PartialTranscriptBubble: View {
        let text: String
        let style: TranscriptSourceStyle

        var body: some View {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Image(systemName: "ellipsis")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(style.color.opacity(0.8))
                Text(text)
                    .italic()
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 9)
            .padding(.horizontal, 12)
            .frame(maxWidth: 240, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(style.color.opacity(0.10))
            )
            .frame(maxWidth: .infinity, alignment: style.bubbleAlignment)
        }
    }

    private struct TranscriptStatusBadge: View {
        let kind: OverlayModel.AudioSourceKind
        let state: OverlayModel.TranscriptionChannelState

        private var style: TranscriptSourceStyle { .for(kind: kind) }

        var body: some View {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(style.color.opacity(0.18))
                        .frame(width: 30, height: 30)
                    Image(systemName: style.icon)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(style.color)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(style.title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(style.caption)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 4)

                VStack(alignment: .trailing, spacing: 4) {
                    LiveDot(active: state.isTranscribing)
                    Text(state.isTranscribing ? "Активно" : "Ожидание")
                        .font(.caption2)
                        .foregroundStyle(state.isTranscribing ? style.color : .secondary)
                }
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white.opacity(0.04))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
            )
            .frame(maxWidth: .infinity, alignment: style.bubbleAlignment)
        }
    }

    private struct TranscriptSourceStyle {
        let icon: String
        let color: Color
        let caption: String
        let title: String
        let bubbleAlignment: Alignment

        static func `for`(kind: OverlayModel.AudioSourceKind) -> TranscriptSourceStyle {
            switch kind {
            case .system:
                return TranscriptSourceStyle(
                    icon: "waveform.circle.fill",
                    color: .cyan,
                    caption: "Системный поток",
                    title: kind.title,
                    bubbleAlignment: .leading
                )
            case .microphone:
                return TranscriptSourceStyle(
                    icon: "mic.circle.fill",
                    color: .pink,
                    caption: "Микрофон",
                    title: kind.title,
                    bubbleAlignment: .trailing
                )
            }
        }
    }

    private struct GlassCard<Content: View>: View {
        @ViewBuilder var content: () -> Content

        var body: some View {
            ZStack {
                let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)

                shape
                    .fill(.thinMaterial) // без дымки и лишних теней
                    .overlay(
                        shape.stroke(
                            LinearGradient(
                                colors: [.white.opacity(0.45), .white.opacity(0.12)],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                    )

                // ВАЖНО: контент ВНУТРИ, а не в overlay
                VStack(spacing: 0) { content() }
                    .padding(12)
            }
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }





    // MARK: - Ask Panel

    private var askPanel: some View {
        VStack(spacing: 12) {
            AskBar(
                text: $question,
                isSubmitting: askVM.isSubmitting,
                onSubmit: submitQuestion
            )
            .frame(maxWidth: 720)

            if showResponse {
                AIResponseCard(
                    title: "AI Response",
                    query: question,
                    markdown: askVM.answerDraft.isEmpty ? "Генерация ответа…" : askVM.answerDraft,
                    isStreaming: askVM.isSubmitting,
                    canStop: askVM.canStop,
                    onCopy: {
                        #if os(macOS)
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(askVM.answerDraft, forType: .string)
                        #endif
                    },
                    onClose: {
                        askVM.cancelStream()
                        askVM.answerDraft = ""
                        askVM.answerError = nil
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.9)) { showResponse = false }
                    },
                    onStop: { askVM.cancelStream() }
                )

                .frame(maxWidth: 860, minHeight: 220)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .onChange(of: askVM.isSubmitting) { v in
            if v { withAnimation(.spring(response: 0.28, dampingFraction: 0.9)) { showResponse = true } }
        }
        .onChange(of: askVM.answerDraft) { v in
            if !v.isEmpty { showResponse = true }          // на случай мгновенного ответа
        }
        .padding(.horizontal, 8)
    }




    // MARK: - Header

    private var header: some View {
        HStack(spacing: 12) {
            LogoOrb()

            VStack(alignment: .leading, spacing: 2) {
                PhotonText("Распознавание системного звука")
                    .font(.headline)

                HStack(spacing: 8) {
                    LiveDot(active: overlay.anyChannelIsTranscribing)
                    Text(overlay.anyChannelIsTranscribing ? "Идёт запись…" : "Готов к запуску")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(overlay.anyChannelIsTranscribing ? .green.opacity(0.9) : .secondary)
                }
                    }

            Spacer()

            HStack(spacing: 10) {
                let microphonePhase = microphoneChannelState.phase
                let microphoneBusy = microphonePhase == .starting || microphonePhase == .stopping

                Button {
                    transcriptionCoordinator.setMicrophoneArmed(!transcriptionCoordinator.isMicrophoneArmed)
                } label: {
                    Label("Микрофон", systemImage: transcriptionCoordinator.isMicrophoneArmed ? "mic.fill" : "mic")
                }
                .buttonStyle(GlassPill(tint: transcriptionCoordinator.isMicrophoneArmed ? .pink : .secondary))
                .disabled(microphoneBusy)

                // Start/Stop управляет обоими каналами
                Button {
                    switch transcriptionCoordinator.overallPhase {
                    case .idle:
                        transcriptionCoordinator.startRecording()
                    case .starting, .running, .stopping:
                        transcriptionCoordinator.stopAll()
                    }
                } label: {
                    let phase = transcriptionCoordinator.overallPhase
                    let running  = phase == .running
                    let starting = phase == .starting
                    let stopping = phase == .stopping
                    Label(
                        starting ? "Запуск…" : (stopping ? "Остановка…" : (running ? "Стоп" : "Старт")),
                        systemImage: (running || stopping) ? "stop.fill" : "play.fill"
                    )
                }
                .buttonStyle(
                    GlassPill(
                        tint: {
                            let phase = transcriptionCoordinator.overallPhase
                            return (phase == .running || phase == .stopping) ? .red : .accentColor
                        }()
                    )
                )
                .disabled(transcriptionCoordinator.overallPhase == .starting)
            }
        }
    }

    // MARK: - Footer

    private var footer: some View {
        HStack(spacing: 12) {
            Toggle(isOn: $autoScroll) { Text("Автопрокрутка") }
                .toggleStyle(.switch)
                .tint(.accentColor)

            Spacer()

            Button {
                transcriptionCoordinator.clearLogs(for: .system)
            } label: {
                Label("Очистить", systemImage: "trash")
            }
            .buttonStyle(GlassPill(tint: .secondary))
            .disabled(systemChannelState.transcriptLog.isEmpty && systemChannelState.partialText.isEmpty)
        }
        .padding(.top, 2)
    }

    // MARK: - Actions


    // NEW: Submit ВСЕГДА шлёт ВОПРОС + ХВОСТ ТРАНСКРИПТА + СКРИНШОТ
    private func submitQuestion() async {
        let tr = makeTranscriptTail(seconds: 40, maxChars: 900) // хвост речи как контекст

        await askVM.submit(
            question: question,
            smart: smartMode,
            transcript: tr
        )

        ServerClient.shared.log("question submitted: \(question), smart=\(smartMode), speechTail=\(tr.count) chars")
    }

    // Хвост транскрибации из текущего транскрайбера (если не подключён TranscriptBuffer)
    private func makeTranscriptTail(seconds _: Int = 40, maxChars: Int = 900) -> String {
        transcriptionCoordinator.transcriptTail(for: .system, maxChars: maxChars)
    }

}


// Универсальная стеклянная карточка без теней
private struct GlassCard<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)

        ZStack {
            // материал кладём через background(_:in:), чтобы не ловить ошибки ShapeStyle
            Color.clear
                .background(.ultraThinMaterial, in: shape)
                .overlay(
                    shape.stroke(
                        LinearGradient(
                            colors: [.white.opacity(0.45), .white.opacity(0.12)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
                )

            VStack(spacing: 0) { content() }
                .padding(12)
        }
        .clipShape(shape)
        .contentShape(shape)
    }
}


private struct HintStrip: View {
    @ObservedObject var hint: HintAgent = .shared

    var body: some View {
        if hint.isRunning || !hint.draft.isEmpty || hint.error != nil {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Подсказка")
                        .font(.headline)
                    if hint.isRunning { ProgressView().controlSize(.small) }
                    Spacer()
                    if hint.canStop {
                        Button("Стоп") { hint.cancel() }
                            .buttonStyle(GlassPill(tint: .red))
                    }
                }

                if let err = hint.error {
                    Text(err).foregroundStyle(.red).font(.subheadline)
                }

                if !hint.draft.isEmpty {
                    Text(hint.draft)
                        .textSelection(.enabled)
                        .font(.body)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack {
                        Button("Копировать") {
                            #if os(macOS)
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(hint.draft, forType: .string)
                            #endif
                        }
                        .buttonStyle(GlassPill())
                        Spacer()
                        Button("Очистить") { hint.draft = "" }
                            .buttonStyle(GlassPill(tint: .secondary))
                    }
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white.opacity(0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(.white.opacity(0.12), lineWidth: 1)
                    )
            )
        }
    }
}

private struct AIResponseCard: View {
    var title: String
    var query: String
    var markdown: String
    var isStreaming: Bool
    var canStop: Bool
    var onCopy: () -> Void
    var onClose: () -> Void
    var onStop: () -> Void

    var body: some View {
        GlassCard {
            VStack(spacing: 0) {
                // Header
                HStack(spacing: 10) {
                    Label(title, systemImage: "sparkles")
                        .font(.headline.weight(.semibold))

                    Spacer()

                    if !query.isEmpty {
                        Text(query)
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(1)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(
                                Capsule().fill(Color.white.opacity(0.06))
                                    .overlay(Capsule().stroke(.white.opacity(0.12), lineWidth: 1))
                            )
                    }

                    Button(action: onCopy) { Image(systemName: "doc.on.doc") }
                        .buttonStyle(MiniIconButton())

                    if canStop {
                        Button(action: onStop) { Image(systemName: "stop.fill") }
                            .buttonStyle(MiniIconButton())
                    }

                    Button(action: onClose) { Image(systemName: "xmark") }
                        .buttonStyle(MiniIconButton())
                }
                .padding(.bottom, 8)

                Divider().overlay(Color.white.opacity(0.10))

                // Body (Markdown)
                ScrollView {
                    let attr = (try? AttributedString(markdown: markdown)) ?? AttributedString(markdown)
                    Text(attr)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                }
                .frame(minHeight: 180)
            }
            .padding(12)
        }
    }
}





// MARK: - AskField

private struct AskBar: View {
    @Binding var text: String
    var isSubmitting: Bool
    var onSubmit: () async -> Void

    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "text.magnifyingglass")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.secondary)

                TextField("Задай вопрос об экране или аудио", text: $text, axis: .vertical)
                    .lineLimit(1...3)
                    .textFieldStyle(.plain)
                    .focused($focused)
                    .onSubmit { Task { await onSubmit() } }
            }
            .padding(.horizontal, 14)
            .frame(height: 42) // ← внутренняя капсула

            Button(isSubmitting ? "Submitting…" : "Submit") {
                Task { await onSubmit() }
            }
            .keyboardShortcut(.return, modifiers: [])
            .buttonStyle(GlassPill(tint: .accentColor))
            .disabled(isSubmitting)
        }
        .padding(8)
        .frame(height: 58) // ← ВСЯ панель фиксирована по высоте
        .background(
            Color.clear.background(
                .ultraThinMaterial,
                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
            )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(.white.opacity(0.18), lineWidth: 1)
        )
    }
}



private struct AskInputBar: View {
    @Binding var text: String
    @Binding var smart: Bool
    var isSubmitting: Bool
    var focus: FocusState<Bool>.Binding
    var onSubmit: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            // маленький чип Smart
            Button {
                smart.toggle()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "bolt.fill")
                    Text("Smart")
                }
                .font(.system(size: 12, weight: .semibold))
                .padding(.horizontal, 10).padding(.vertical, 6)
                .background(
                    .ultraThinMaterial,
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(.white.opacity(0.18), lineWidth: 1)
                )

            }
            .buttonStyle(.plain)

            // поле ввода — одна строка, как у Glass
            TextField("Ask about your screen or audio", text: $text)
                .focused(focus)
                .textFieldStyle(.plain)
                .font(.system(size: 16, weight: .medium))
                .padding(.horizontal, 14).padding(.vertical, 10)
                .background(
                    Capsule().fill(Color.white.opacity(0.06))
                        .overlay(Capsule().stroke(.white.opacity(0.10), lineWidth: 1))
                )
                .onSubmit { onSubmit() }                    // Enter отправляет
                .disableAutocorrection(true)

            Button(isSubmitting ? "Submitting…" : "Submit") {
                onSubmit()
            }
            .font(.system(size: 14, weight: .semibold))
            .padding(.horizontal, 14).padding(.vertical, 9)
            .background(
                Capsule().fill(Color.accentColor)
                    .overlay(Capsule().stroke(.white.opacity(0.20), lineWidth: 0.5))
            )
            .foregroundStyle(.white)
            .disabled(isSubmitting)
            .keyboardShortcut(.return, modifiers: [.command]) // ⌘↩ тоже шлёт
        }
    }
}


private struct ResponseCard: View {
    var questionTitle: String
    var bodyText: String
    var isLoading: Bool
    var canStop: Bool
    var onCopy: () -> Void
    var onClose: () -> Void
    var onStop: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            // header
            HStack(spacing: 10) {
                HStack(spacing: 8) {
                    Circle().fill(Color.white.opacity(0.15)).frame(width: 10, height: 10)
                    Text(questionTitle)
                        .font(.system(size: 14, weight: .semibold))
                }

                Spacer()

                Button(action: onCopy) {
                    Image(systemName: "doc.on.doc")
                }
                .buttonStyle(MiniIconButton())

                if canStop {
                    Button(action: onStop) {
                        Image(systemName: "xmark")
                    }
                    .buttonStyle(MiniIconButton())
                }

                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                }
                .buttonStyle(MiniIconButton())
            }

            Divider().overlay(Color.white.opacity(0.08))

            // body
            ScrollView {
                Text(bodyText)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .font(.system(size: 15))
                    .padding(.vertical, 4)
            }
            .frame(minHeight: 160, maxHeight: 420)
        }
        .padding(6)
    }
}


private struct MiniIconButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12.5, weight: .semibold))
            .frame(width: 28, height: 28)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(.thinMaterial)
                    .overlay(RoundedRectangle(cornerRadius: 7).stroke(.white.opacity(0.18), lineWidth: 0.75))
            )
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
    }
}


// AskField
struct AskField: View {
    @Binding var text: String
    @Binding var smartEnabled: Bool
    var isSubmitting: Bool = false
    var onSubmit: () async -> Void
    var focused: FocusState<Bool>.Binding    // ← новый параметр


    

    var body: some View {
        HStack(spacing: 10) {
            // Заменить TextField на TextEditor, если нужна многострочность
            TextEditor(text: $text)
                .focused(focused)                         // ← фокус сюда
                .font(.title3.weight(.medium))
                .frame(minHeight: 80)                     // чуть больше, чтобы точно хватало
                .padding(.vertical, 10)
                .padding(.leading, 12)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(NSColor.textBackgroundColor))
                )





            HStack(spacing: 8) {
                Toggle(isOn: $smartEnabled) {
                    Label("Smart Mode", systemImage: "bolt")
                        .labelStyle(.titleAndIcon)
                        .font(.subheadline.weight(.semibold))
                }
                .toggleStyle(.button)
                .tint(.accentColor.opacity(0.7))

                Button(isSubmitting ? "Submitting…" : "Submit") {
                    print("Submit tapped")
                    Task { await onSubmit() }
                }
                .buttonStyle(GlassPill(tint: .accentColor))
                .disabled(isSubmitting) // ← только этот флаг
            }
            .padding(.trailing, 8)
        }
        .padding(.horizontal, 6)
        .contentShape(Rectangle())
        .allowsHitTesting(true)
    }
}




// MARK: - GlassPill

struct GlassPill: ButtonStyle {
    var tint: Color? = nil
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.primary)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                Capsule(style: .continuous)
                    .fill(.thinMaterial)
                    .overlay(Capsule().stroke(.white.opacity(0.2), lineWidth: 1))
                    .shadow(
                        color: (tint ?? .accentColor).opacity(configuration.isPressed ? 0.25 : 0.4),
                        radius: configuration.isPressed ? 6 : 12,
                        x: 0, y: 0
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.spring(response: 0.28, dampingFraction: 0.9), value: configuration.isPressed)
    }
}


@MainActor
final class AskVM: ObservableObject {
    @Published var isSubmitting: Bool = false
    @Published var answerDraft: String = ""          // сюда льётся стрим
    @Published var answerError: String? = nil
    @Published var canStop: Bool = false             // показать кнопку «Стоп»

    private var streamTask: Task<Void, Never>?       // чтобы уметь отменять
    private var streamRunID = UUID()
    private let baseURL = URL(string: "https://api.disciplaner.online")!
    private let sessionId = UUID().uuidString        // одна сессия на жизненный цикл VM
    private let auth: AuthState
    private let serverClient: ServerClient

    init(auth: AuthState, serverClient: ServerClient = .shared) {
        self.auth = auth
        self.serverClient = serverClient
    }

    func cancelStream() {
        streamTask?.cancel()
        streamRunID = UUID()
        streamTask = nil
        canStop = false
        isSubmitting = false
    }

    // Submit ВСЕГДА отправляет вопрос + хвост транскрибации + скриншот
    func submit(
        question: String,
        smart: Bool,
        transcript: String
    ) async {
        let q = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else {
            NSLog("AskVM: skipped submit — empty question")
            return
        }

        await performSubmission(
            endpoint: "/ask",
            question: q,
            smart: smart,
            transcript: transcript
        )
    }

    func submitWithoutQuery(
        transcript: String,
        smart: Bool = true
    ) async {
        await performSubmission(
            endpoint: "/ask_without_query",
            question: nil,
            smart: smart,
            transcript: transcript
        )
    }

    private func performSubmission(
        endpoint: String,
        question: String?,
        smart: Bool,
        transcript: String
    ) async {
        guard let token = auth.currentKey, !token.isEmpty else {
            answerError = "Добавьте API-ключ, чтобы отправить вопрос."
            return
        }

        streamTask?.cancel()
        let runID = UUID()
        streamRunID = runID

        // сброс состояния ответа
        answerDraft = ""
        answerError = nil
        isSubmitting = true
        canStop = true
        NSLog("AskVM isSubmitting = true")
        defer {
            NSLog("AskVM isSubmitting = false")
            isSubmitting = false
            canStop = false
        }

        do {
            // 1) делаем PNG снимок
            let png = try await Snapshot.captureAllDisplaysPNG(maxSide: 1280)

            // 2) шлём на сервер и читаем SSE стрим
            try await sendToGPT(
                endpoint: endpoint,
                question: question,
                screenshotPNG: png,
                smart: smart,
                transcript: transcript,
                token: token
            )
        } catch {
            answerError = error.localizedDescription
            NSLog("AskVM submit failed: \(error.localizedDescription)")
        }
    }

    // MARK: - сетевой вызов со streaming SSE
    private func sendToGPT(
        endpoint: String,
        question: String?,
        screenshotPNG: Data,
        smart: Bool,
        transcript: String,
        token: String
    ) async throws {
        var req = URLRequest(url: baseURL.appendingPathComponent(endpoint))
        req.httpMethod = "POST"
        req.setValue("text/event-stream", forHTTPHeaderField: "Accept") // ожидаем SSE
        serverClient.authorize(&req, token: token)

        // multipart/form-data
        let boundary = "----ghostdesk-\(UUID().uuidString)"
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        func appendField(_ name: String, _ value: String) {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(value)\r\n".data(using: .utf8)!)
        }
        func appendFile(_ name: String, filename: String, mime: String, data: Data) {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(name)\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
            body.append("Content-Type: \(mime)\r\n\r\n".data(using: .utf8)!)
            body.append(data)
            body.append("\r\n".data(using: .utf8)!)
        }

        // обязательные поля
        if let question {
            appendField("question", question)
        }
        appendField("smart", smart ? "true" : "false")
        appendField("sessionId", sessionId)

        // контекст речи добавляем только если он не пустой
        let transcriptPayload = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        if !transcriptPayload.isEmpty {
            appendField("transcript", transcriptPayload)
        }

        // скрин — ВСЕГДА для Submit
        appendFile("image", filename: "screen.png", mime: "image/png", data: screenshotPNG)

        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        req.httpBody = body

        // 3) читаем SSE построчно.
        let (bytes, response) = try await URLSession.shared.bytes(for: req)
        guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }

        if serverClient.handleUnauthorizedStatus(http.statusCode, auth: auth) {
            throw NSError(domain: "auth", code: http.statusCode,
                          userInfo: [NSLocalizedDescriptionKey: serverClient.unauthorizedMessage])
        }

        if !(200..<300).contains(http.statusCode) {
            var errText = "HTTP \(http.statusCode) \(HTTPURLResponse.localizedString(forStatusCode: http.statusCode))"
            var data = Data()
            do {
                for try await b in bytes { data.append(b) } // вычитаем тело ошибки
                if let s = String(data: data, encoding: .utf8), !s.isEmpty { errText += "\n\(s)" }
            } catch {}
            throw NSError(domain: "net", code: http.statusCode,
                          userInfo: [NSLocalizedDescriptionKey: errText])
        }

        // читаем строки SSE
        var buffer = "" // микро-батчинг на клиенте, чтобы не дёргать UI по 1 символу
        var lastFlush = Date()

        for try await line in bytes.lines {
            try Task.checkCancellation()
            guard line.hasPrefix("data: ") else { continue }

            let jsonStr = String(line.dropFirst(6))
            guard
                let data = jsonStr.data(using: .utf8),
                let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                let type = obj["type"] as? String
            else { continue }

            if type == "delta", let text = obj["text"] as? String {
                buffer += text
                // флашим если буфер вырос или пришёл знак конца фразы, или прошло 60 мс
                let shouldFlushByLen = buffer.count >= 64
                let shouldFlushByPunct = buffer.last.map { ".,!?;:\n ".contains($0) } ?? false
                let shouldFlushByTime = Date().timeIntervalSince(lastFlush) > 0.06
                if shouldFlushByLen || shouldFlushByPunct || shouldFlushByTime {
                    answerDraft += buffer
                    buffer.removeAll(keepingCapacity: true)
                    lastFlush = Date()
                }
            } else if type == "done" {
                // добросим хвост
                if !buffer.isEmpty {
                    answerDraft += buffer
                    buffer.removeAll()
                }
                break
            } else if type == "error" {
                let msg = (obj["message"] as? String) ?? "Unknown error"
                throw NSError(domain: "sse", code: -1,
                              userInfo: [NSLocalizedDescriptionKey: msg])
            }
        }

        if !buffer.isEmpty {
            answerDraft += buffer
        }
    }
}


// MARK: - Внутренняя однофайловая реализация снимка экрана

private enum Snapshot {
    enum Error: Swift.Error {
        case noDisplays
        case timeout
        case cancelled
        case internalFailure(String)
    }

    /// Публичная точка: PNG сжат до `maxSide` по большей стороне
    static func captureAllDisplaysPNG(maxSide: CGFloat = 1280) async throws -> Data {
        let cg = try await captureAllDisplaysCGImage(width: 1280, height: 720, showsCursor: false, timeout: 2.0)
        let resized = resizeCGImage(cg, maxSide: maxSide)
        return pngData(from: resized)
    }

    /// Одноразовый CGImage через временный SCStream
    static func captureAllDisplaysCGImage(
        width: Int = 1280,
        height: Int = 720,
        showsCursor: Bool = false,
        timeout: TimeInterval = 2.0
    ) async throws -> CGImage {

        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)

        guard let main = content.displays.first else { throw Error.noDisplays }


        // let filter = SCContentFilter(display: main, excludingWindows: [], exceptingWindows: [])

        // Самый совместимый вариант для разных SDK/macOS
        let filter = SCContentFilter(display: main, excludingWindows: [])

        // Конфигурация стрима
        let cfg = SCStreamConfiguration()
        cfg.width  = (width  / 8) * 8        // чуть выравниваем для стабильности
        cfg.height = (height / 8) * 8
        cfg.showsCursor = showsCursor
        cfg.pixelFormat = kCVPixelFormatType_32BGRA
        // Можно задать минимальный интервал кадров, но для "одного кадра" не критично:
        // cfg.minimumFrameInterval = CMTime(value: 1, timescale: 30)

        // Захват одного кадра
        let grabber = SingleFrameGrabber(queueLabel: "sc.single.grab.queue")
        return try await grabber.grab(filter: filter, configuration: cfg, timeout: timeout)
    }

    // MARK: - Helpers (PNG и ресайз)

    private static func pngData(from cg: CGImage) -> Data {
        let data = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil) else {
            fatalError("CGImageDestinationCreateWithData failed")
        }
        CGImageDestinationAddImage(dest, cg, nil)
        CGImageDestinationFinalize(dest)
        return data as Data
    }

    private static func resizeCGImage(_ src: CGImage, maxSide: CGFloat) -> CGImage {
        let w = CGFloat(src.width), h = CGFloat(src.height)
        let scale = min(1, maxSide / max(w, h))
        let newW = max(1, Int(w * scale))
        let newH = max(1, Int(h * scale))

        let cs = src.colorSpace ?? CGColorSpaceCreateDeviceRGB()
        let ctx = CGContext(
            data: nil,
            width: newW, height: newH,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: cs,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        ctx.interpolationQuality = .high
        ctx.draw(src, in: CGRect(x: 0, y: 0, width: newW, height: newH))
        return ctx.makeImage()!
    }

    // MARK: - Одноразовый граббер кадра

    private final class SingleFrameGrabber: NSObject, SCStreamOutput, SCStreamDelegate {
        private var stream: SCStream?
        private var cont: CheckedContinuation<CGImage, Swift.Error>?
        private var finished = false

        private let ci = CIContext()
        private let queue: DispatchQueue

        init(queueLabel: String) {
            self.queue = DispatchQueue(label: queueLabel)
            super.init()
        }

        deinit { stop() }

        func grab(filter: SCContentFilter, configuration: SCStreamConfiguration, timeout: TimeInterval) async throws -> CGImage {
            let stream = SCStream(filter: filter, configuration: configuration, delegate: self)
            self.stream = stream

            // Обрабатываем кадры НЕ на main
            try stream.addStreamOutput(self, type: .screen, sampleHandlerQueue: queue)
            try await stream.startCapture()

            return try await withTaskCancellationHandler(operation: {
                try await withCheckedThrowingContinuation { (c: CheckedContinuation<CGImage, Swift.Error>) in
                    self.cont = c
                    // Таймаут
                    self.queue.asyncAfter(deadline: .now() + timeout) { [weak self] in
                        guard let self, !self.finished else { return }
                        self.finish(error: Snapshot.Error.timeout)
                    }
                }
            }, onCancel: { [weak self] in
                self?.finish(error: Snapshot.Error.cancelled)
            })
        }

        private func stop() {
            try? stream?.stopCapture()
            stream = nil
        }

        // MARK: - SCStreamOutput

        func stream(_ stream: SCStream, didOutputSampleBuffer sb: CMSampleBuffer, of type: SCStreamOutputType) {
            guard type == .screen, let pb = sb.imageBuffer else { return }
            let ciImage = CIImage(cvPixelBuffer: pb)
            if let cg = ci.createCGImage(ciImage, from: ciImage.extent) {
                finish(image: cg)
            }
        }

        // MARK: - SCStreamDelegate

        func stream(_ stream: SCStream, didStopWithError error: Swift.Error) {
            finish(error: error)
        }

        // MARK: - Finish helpers

        private func finish(image: CGImage) {
            queue.async {
                guard !self.finished else { return }
                self.finished = true
                self.stop()
                self.cont?.resume(returning: image)
                self.cont = nil
            }
        }

        private func finish(error: Swift.Error) {
            queue.async {
                guard !self.finished else { return }
                self.finished = true
                self.stop()
                self.cont?.resume(throwing: error)
                self.cont = nil
            }
        }
    }
}


#if os(macOS)
import AppKit
import SwiftUI

public struct WindowChromeTweaks: NSViewRepresentable {
    public init() {}

    public func makeNSView(context: Context) -> NSView {
        let v = NSView()                       // ← обычный NSView без хит-тест трюков
        v.wantsLayer = true
        v.layer?.backgroundColor = NSColor.clear.cgColor
        DispatchQueue.main.async {
            if let w = v.window {
                w.titleVisibility = .hidden
                w.titlebarAppearsTransparent = true
                w.isMovableByWindowBackground = false   // ← ВАЖНО: выключено
                w.backgroundColor = .clear
            }
        }
        return v
    }

    public func updateNSView(_ nsView: NSView, context: Context) {}
}
#else
public struct WindowChromeTweaks: View {
    public init() {}
    public var body: some View { Color.clear.ignoresSafeArea() }
}
#endif





import Foundation

/// Потокобезопасный буфер последних реплик с таймстемпами.
/// Хранит подтверждённые куски и актуальный partial-хвост.
final class TranscriptBuffer {
    static let shared = TranscriptBuffer()
    private init() {}

    private struct Item { let t: Date; let text: String }
    private let q = DispatchQueue(label: "TranscriptBuffer.q", qos: .userInitiated)
    private var items: [Item] = []
    private var partial: Item? = nil

    /// Добавить подтверждённый (final) текст
    func appendFinal(_ text: String, at time: Date = .init()) {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        q.async {
            self.items.append(.init(t: time, text: clean))
            // ограничим рост буфера (по числу элементов)
            if self.items.count > 500 { self.items.removeFirst(self.items.count - 500) }
            self.partial = nil // сбрасываем текущий хвост
        }
    }

    /// Обновить текущий partial (неподтверждённый) текст
    func setPartial(_ text: String, at time: Date = .init()) {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        q.async {
            self.partial = clean.isEmpty ? nil : .init(t: time, text: clean)
        }
    }

    /// Хвост за N секунд, с жёстной усечкой по символам.
    func tail(lastSeconds: Int = 40, maxChars: Int = 900) -> String {
        let now = Date()
        return q.sync {
            let cut = now.addingTimeInterval(TimeInterval(-lastSeconds))
            var chunks = items.filter { $0.t >= cut }.map { $0.text }
            if let p = partial, p.t >= cut { chunks.append(p.text) }
            var s = chunks.joined(separator: " ")
            if s.count > maxChars {
                s = String(s.suffix(maxChars))
            }
            return s.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    func clear() {
        q.async {
            self.items.removeAll(keepingCapacity: false)
            self.partial = nil
        }
    }
}


