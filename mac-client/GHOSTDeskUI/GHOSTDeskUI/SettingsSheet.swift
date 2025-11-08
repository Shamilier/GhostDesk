import SwiftUI
import AppKit

// MARK: - Design Tokens
private enum ST {
    // Card metrics
    static let corner: CGFloat = 24
    static let padX: CGFloat = 56
    static let padY: CGFloat = 48
    static let width: CGFloat = 560
    static let minHeight: CGFloat = 480
    static let windowWidth: CGFloat = 640
    static let windowHeight: CGFloat = 520

    // Typography
    static let textPri   = Color.white
    static let textSec   = Color.white.opacity(0.72)
    static let textTri   = Color.white.opacity(0.48)

    // Decor
    static let line      = Color.white.opacity(0.08)
    static let shadow    = Color.black.opacity(0.30)

    // Secondary controls
    static let secBase        = Color.white.opacity(0.06)
    static let secBaseHover   = Color.white.opacity(0.12)

    // Status colors
    static let redText   = Color(red: 1.00, green: 0.37, blue: 0.34)
    static let redStroke = Color(red: 1.00, green: 0.37, blue: 0.34).opacity(0.45)
    static let greenFg   = Color(red: 0.61, green: 0.95, blue: 0.79)
    static let greenBg   = Color(red: 0.18, green: 0.73, blue: 0.46).opacity(0.18)
}

// MARK: - SettingsSheet
struct SettingsSheet: View {
    @Binding var isShown: Bool           // ← вот так
    @EnvironmentObject private var auth: AuthState
    @ObservedObject private var overlay = OverlayModel.shared
    @ObservedObject private var hotKeys = HotKeyPreferences.shared
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    @State private var isRefreshing = false

    private var hotKeyGroups: [HotKeyGroup] { HotKeyGroup.presets }

    private var expiresDescription: String {
        guard let expiresAt = auth.expiresAt else { return "Не установлено" }
        return expiresAt.formatted(date: .abbreviated, time: .shortened)
    }
    private var createdDescription: String {
        guard let createdAt = auth.createdAt else { return "Неизвестно" }
        return createdAt.formatted(date: .abbreviated, time: .shortened)
    }
    private var tokenString: String { (auth.profileToken ?? "").trimmingCharacters(in: .whitespacesAndNewlines) }
    private var planString: String  { (auth.plan ?? "").trimmingCharacters(in: .whitespacesAndNewlines) }
    private var refString: String   { (auth.referral ?? "").trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        GlassCard {
            VStack(spacing: 0) {

                // Header
                HStack(spacing: 10) {
                    Label("Настройки", systemImage: "gearshape")
                        .font(.headline.weight(.semibold))
                    Spacer()
                    Button(action: { isShown = false }) {    // ← было isShown.wrappedValue = false
                        Image(systemName: "xmark")
                    }
                    .buttonStyle(MiniIconButton())
                }
                .padding(.bottom, 8)

                Divider().overlay(Color.white.opacity(0.10))

                // Content
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {

                        // === Пример секции с ключом API ===
                        GlassSection("Аккаунт") {
                            VStack(alignment: .leading, spacing: 10) {
                                // Статус
                                HStack(spacing: 8) {
                                    if auth.isAuthorized {
                                        Image(systemName: "checkmark.seal.fill").foregroundStyle(.green)
                                        Text("Авторизовано").font(.subheadline.weight(.semibold))
                                    } else {
                                        Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.yellow)
                                        Text("Вход не выполнен").font(.subheadline.weight(.semibold))
                                    }
                                }

                                // Базовая информация
                                if let email = auth.email {
                                    LabeledContent("Email") { Text(email).monospaced() }
                                }
                                if let plan = auth.plan {
                                    LabeledContent("Тариф") { Text(plan) }
                                }
                                if let created = auth.createdAt {
                                    LabeledContent("Аккаунт с") { Text(created.formatted(date: .abbreviated, time: .omitted)) }
                                }
                                if let expires = auth.expiresAt {
                                    LabeledContent("Сессия истекает") { Text(expires.formatted(date: .abbreviated, time: .shortened)) }
                                }

                                // Замаскированный access token (нередактируемый)
                                LabeledContent("Access Token") {
                                    TextField("", text: .constant(maskedAccessToken))
                                        .font(.system(size: 14, weight: .medium, design: .monospaced))
                                        .glassCapsuleField()
                                        .disabled(true)
                                        .textSelection(.enabled)
                                }

                                // Действия
                                HStack(spacing: 10) {
                                    if auth.isAuthorized {
                                        Button("Выйти") { auth.signOut() }
                                            .buttonStyle(GlassPill(tint: .secondary))
                                    }
                                    Spacer()
                                    Button("Готово") { isShown = false }
                                        .buttonStyle(GlassPill(tint: .accentColor))
                                }

                                // Сообщение об ошибке/проблеме
                                if let issue = auth.authorizationIssue ?? auth.lastError {
                                    Text(issue).font(.caption).foregroundStyle(.red)
                                }
                            }
                        }

                        GlassSection("Отображение окна") {
                            Toggle(
                                isOn: Binding(
                                    get: { !overlay.isHiddenFromScreenCapture },
                                    set: { overlay.isHiddenFromScreenCapture = !$0 }
                                )
                            ) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Показывать при захвате экрана")
                                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                                        .foregroundStyle(ST.textPri)
                                    Text("Отключите, чтобы панель GhostDesk оставалась невидимой на скриншотах и при трансляции экрана.")
                                        .font(.system(size: 13, weight: .regular, design: .rounded))
                                        .foregroundStyle(ST.textSec)
                                }
                            }
                            .toggleStyle(.switch)
                            .tint(.accentColor)
                        }

                        GlassSection("Горячие клавиши") {
                            VStack(alignment: .leading, spacing: 18) {
                                ForEach(hotKeyGroups) { group in
                                    VStack(alignment: .leading, spacing: 14) {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Label {
                                                Text(group.title)
                                                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                                                    .foregroundStyle(ST.textPri)
                                            } icon: {
                                                Image(systemName: group.systemImage)
                                                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                                                    .foregroundStyle(Color.white.opacity(0.9))
                                                    .shadow(color: Color.black.opacity(0.12), radius: 4, x: 0, y: 2)
                                            }
                                            if !group.subtitle.isEmpty {
                                                Text(group.subtitle)
                                                    .font(.system(size: 12.5, weight: .medium, design: .rounded))
                                                    .foregroundStyle(ST.textSec)
                                            }
                                        }

                                        VStack(spacing: 12) {
                                            ForEach(group.actions) { action in
                                                HotKeyEditorRow(
                                                    action: action,
                                                    combination: hotKeys.combination(for: action),
                                                    onUpdate: { hotKeys.update($0, for: action) },
                                                    onReset: { hotKeys.reset(action) }
                                                )
                                            }
                                        }
                                        .padding(16)
                                        .background(
                                            Group {
                                                if #available(macOS 26.0, *) {
                                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                                        .fill(Color.clear)
                                                        .background(
                                                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                                                .fill(group.gradient(reduceTransparency: reduceTransparency))
                                                                .opacity(reduceTransparency ? 0.28 : 0.6)
                                                        )
                                                        .overlay(
                                                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                                                .stroke(Color.white.opacity(0.16), lineWidth: 1)
                                                        )
                                                        .glassEffect(.clear, in: .rect(cornerRadius: 18))
                                                } else {
                                                    ZStack {
                                                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                                                            .fill(.ultraThinMaterial)
                                                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                                                            .fill(group.gradient(reduceTransparency: reduceTransparency))
                                                            .opacity(reduceTransparency ? 0.28 : 0.6)
                                                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                                                            .stroke(Color.white.opacity(0.16), lineWidth: 1)
                                                    }
                                                }
                                            }
                                        )
                                    }
                                }

                                HStack(spacing: 6) {
                                    Image(systemName: "lock.fill")
                                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                                        .foregroundStyle(Color.accentColor)
                                    Text("⌘ зафиксирована в каждой комбинации. Просто нажмите нужную клавишу, чтобы изменить хоткей.")
                                }
                                .font(.system(size: 11.5, weight: .medium, design: .rounded))
                                .foregroundStyle(ST.textSec)
                                .padding(.horizontal, 4)
                            }
                        }


                        // === Низ (кнопки действия) ===
                    }
                    .padding(.top, 12)
                }
                .frame(minHeight: 260, maxHeight: 520)
            }
            .padding(12)
        }
        .frame(maxWidth: 620)
    }
    
    private var maskedAccessToken: String {
        guard let t = auth.accessToken, !t.isEmpty else { return "—" }
        return maskMiddle(t)
    }

    private func maskMiddle(_ s: String, keep: Int = 6) -> String {
        guard s.count > keep * 2 else { return s }
        let start = s.prefix(keep)
        let end   = s.suffix(keep)
        return "\(start)••••••••••\(end)"
    }

    // MARK: Card content
    private var cardView: some View {
        VStack(spacing: 24) {
            header
            Divider().background(ST.line)

            statusSection
            Divider().background(ST.line)

            accountSection

            // фикс-слот под сообщение, чтобы высота не прыгала
            Group {
                if let message = auth.authorizationIssue, !message.isEmpty {
                    Text(message)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(ST.redText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .transition(.opacity)
                } else {
                    Color.clear
                }
            }
            .frame(height: 22)

            actionsRow
        }
        .padding(.horizontal, ST.padX)
        .padding(.vertical, ST.padY)
        .overlay(cardBorder)
        .clipShape(RoundedRectangle(cornerRadius: ST.corner, style: .continuous))
        .shadow(color: ST.shadow, radius: 24, x: 0, y: 18)
    }

    // MARK: Card visuals

    private var cardBorder: some View {
        RoundedRectangle(cornerRadius: ST.corner, style: .continuous)
            .stroke(Color.white.opacity(0.08), lineWidth: 1)
            .overlay(
                RoundedRectangle(cornerRadius: ST.corner, style: .continuous)
                    .stroke(Color.black.opacity(0.25), lineWidth: 1.2)
                    .blur(radius: 4)
                    .offset(y: 1)
                    .mask(
                        LinearGradient(colors: [.black, .clear],
                                       startPoint: .top,
                                       endPoint: .bottom)
                            .clipShape(RoundedRectangle(cornerRadius: ST.corner, style: .continuous))
                    )
            )
    }

    // MARK: Header
    private var header: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Панель управления")
                    .font(.system(size: 28, weight: .semibold, design: .rounded))
                    .foregroundStyle(ST.textPri)
                Text("Настройте аккаунт и подписку")
                    .font(.system(size: 15, weight: .regular, design: .rounded))
                    .foregroundStyle(ST.textSec)
            }
            Spacer(minLength: 12)
            CloseButton {
                withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                    isShown = false
                }
            }
        }
    }

    // MARK: Status
    private var statusSection: some View {
        HStack(spacing: 12) {
            StatusPill(
                systemImage: auth.isAuthorized ? "checkmark.seal.fill" : "exclamationmark.triangle.fill",
                title: auth.isAuthorized ? "Авторизация активна" : "Нет активной сессии",
                fg: auth.isAuthorized ? ST.greenFg : .orange,
                bg: auth.isAuthorized ? ST.greenBg : Color.orange.opacity(0.18)
            )
            Spacer()
            Text("Действует до \(expiresDescription)")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(ST.textSec)
        }
    }

    // MARK: Account
    private var accountSection: some View {
        VStack(spacing: 12) {
            InfoRow(label: "ТОКЕН") {
                CopyableTokenField(text: tokenString, placeholder: "Не найден")
            }
            InfoRow(label: "ТАРИФ") {
                Text(planString.isEmpty ? "Не определён" : planString)
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(planString.isEmpty ? ST.textTri : ST.textPri)
            }
            InfoRow(label: "РЕФЕРАЛЬНЫЙ КОД") {
                Text(refString.isEmpty ? "Нет данных" : refString)
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(refString.isEmpty ? ST.textTri : ST.textPri)
            }
            InfoRow(label: "СОЗДАН") {
                Text(createdDescription)
                    .font(.system(size: 15, weight: .regular, design: .rounded))
                    .foregroundStyle(ST.textSec)
            }
        }
    }

    // MARK: Actions
    private var actionsRow: some View {
        HStack(spacing: 12) {
            Button {
                isRefreshing = true
                Task {
                    auth.restoreSession()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        isRefreshing = false
                    }
                }
            } label: {
                HStack(spacing: 8) {
                    if isRefreshing {
                        ProgressView().controlSize(.small).tint(.white)
                    } else {
                        Image(systemName: "arrow.clockwise")
                    }
                    Text(isRefreshing ? "Обновляем…" : "Обновить данные")
                }
                .font(.system(size: 14, weight: .semibold, design: .rounded))
            }
            .buttonStyle(SecondaryButtonStyle())
            .disabled(isRefreshing)

            Spacer()

            Button(role: .destructive) {
                auth.signOut()
                withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                    isShown = false
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "rectangle.portrait.and.arrow.forward")
                    Text("Выйти")
                }
                .font(.system(size: 14, weight: .semibold, design: .rounded))
            }
            .buttonStyle(DestructiveOutlineButtonStyle())
        }
    }
}

// MARK: - HotKey helpers

private struct HotKeyEditorRow: View {
    let action: HotKeyAction
    let combination: HotKeyCombination
    let onUpdate: (HotKeyCombination) -> Bool
    let onReset: () -> Void

    @State private var updateFailed = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .center, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(action.title)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(ST.textPri)
                    if let detail = action.detail {
                        Text(detail)
                            .font(.system(size: 13, weight: .regular, design: .rounded))
                            .foregroundStyle(ST.textSec)
                    }
                }

                Spacer(minLength: 24)

                HotKeyCaptureField(
                    combination: combination,
                    onUpdate: { newValue in
                        let success = onUpdate(newValue)
                        updateFailed = !success
                        return success
                    }
                )
                .help("⌘ уже закреплена — выберите дополнительную клавишу")

                if combination != action.defaultCombination {
                    Button("Сбросить") {
                        updateFailed = false
                        onReset()
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.accentColor)
                    .padding(.horizontal, 4)
                }
            }

            if updateFailed {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 11.5, weight: .bold, design: .rounded))
                        .foregroundStyle(ST.redText)
                    Text("Комбинация конфликтует с закреплённым хоткеем. Попробуйте другое сочетание.")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(ST.redText)
                }
                .padding(.leading, 2)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .onChange(of: combination) { _ in
            updateFailed = false
        }
    }
}

private struct HotKeyGroup: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let systemImage: String
    let gradientColors: [Color]
    let actions: [HotKeyAction]

    func gradient(reduceTransparency: Bool) -> LinearGradient {
        let opacity: Double = reduceTransparency ? 0.35 : 0.65
        return LinearGradient(
            colors: gradientColors.map { $0.opacity(opacity) },
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static let presets: [HotKeyGroup] = [
        HotKeyGroup(
            title: "Навигация панели",
            subtitle: "Быстрый контроль появления и положения",
            systemImage: "rectangle.3.group",
            gradientColors: [
                Color(red: 0.33, green: 0.69, blue: 1.00),
                Color(red: 0.20, green: 0.35, blue: 0.82)
            ],
            actions: [.toggleOverlay, .toggleFocus, .resetPosition]
        ),
        HotKeyGroup(
            title: "Взаимодействие с задачами",
            subtitle: "Создание заметок, подсказки и запись",
            systemImage: "bolt.badge.clock",
            gradientColors: [
                Color(red: 1.00, green: 0.56, blue: 0.64),
                Color(red: 0.79, green: 0.33, blue: 0.69)
            ],
            actions: [.toggleRecording, .askHint, .askSolve]
        ),
        HotKeyGroup(
            title: "Внешний вид",
            subtitle: "Настройка прозрачности панели",
            systemImage: "slider.horizontal.3",
            gradientColors: [
                Color(red: 0.45, green: 0.51, blue: 0.96),
                Color(red: 0.21, green: 0.25, blue: 0.55)
            ],
            actions: [.transparencyDecrease, .transparencyIncrease]
        )
    ]
}

private struct HotKeyCaptureField: View {
    let combination: HotKeyCombination
    let onUpdate: (HotKeyCombination) -> Bool

    @State private var isCapturing = false
    @State private var eventMonitor: Any?

    var body: some View {
        HStack(spacing: 8) {
            if isCapturing {
                Image(systemName: "keyboard")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.accentColor)
                Text("Нажмите клавишу…")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.accentColor)
            } else {
                HotKeyKeycap(symbol: "⌘", locked: true)
                ForEach(combination.modifierSymbols, id: \.self) { symbol in
                    HotKeyKeycap(symbol: symbol)
                }
                HotKeyKeycap(symbol: combination.mainKeySymbol)
            }
        }
        .frame(minWidth: 160, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(isCapturing ? 0.12 : 0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(isCapturing ? Color.accentColor.opacity(0.6) : Color.white.opacity(0.14), lineWidth: 1)
                )
        )
        .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .onTapGesture { toggleCapture() }
        .onDisappear { stopCapture() }
    }

    private func toggleCapture() {
        if isCapturing {
            stopCapture()
        } else {
            startCapture()
        }
    }

    private func startCapture() {
        isCapturing = true
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { event in
            handle(event: event)
            return nil
        }
    }

    private func stopCapture() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
        isCapturing = false
    }

    private func handle(event: NSEvent) {
        if event.keyCode == 53 { // Escape cancels capture
            stopCapture()
            return
        }

        var modifiers = event.modifierFlags.sanitizedForHotKey()
        modifiers.subtract(.command)
        modifiers.subtract(.function)
        modifiers.subtract(.numericPad)
        let symbol = keySymbol(for: event)
        let newCombination = HotKeyCombination(keyCode: event.keyCode, modifiers: modifiers, keyEquivalent: symbol)

        if onUpdate(newCombination) {
            stopCapture()
        } else {
            NSSound.beep()
        }
    }

    private func keySymbol(for event: NSEvent) -> String {
        if let special = event.specialKey {
            switch special {
            case .leftArrow: return "←"
            case .rightArrow: return "→"
            case .upArrow: return "↑"
            case .downArrow: return "↓"
            default: break
            }
        }

        if let chars = event.characters, !chars.isEmpty {
            return String(chars.prefix(1))
        }

        if let chars = event.charactersIgnoringModifiers, !chars.isEmpty {
            return String(chars.prefix(1))
        }

        return HotKeyCombination.symbol(for: event.keyCode)
    }
}

private struct HotKeyKeycap: View {
    let symbol: String
    var locked: Bool = false

    var body: some View {
        HStack(spacing: 4) {
            if locked {
                Image(systemName: "lock.fill")
                    .font(.system(size: 9.5, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.accentColor)
            }
            Text(symbol)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.92))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(locked ? Color.accentColor.opacity(0.22) : Color.white.opacity(0.10))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(locked ? Color.accentColor.opacity(0.45) : Color.white.opacity(0.18), lineWidth: 1)
                )
        )
    }
}

// MARK: - Pieces

private struct StatusPill: View {
    let systemImage: String
    let title: String
    let fg: Color
    let bg: Color
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(fg)
            Text(title)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(fg)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .background(Capsule(style: .continuous).fill(bg))
    }
}

private struct InfoRow<Content: View>: View {
    let label: String
    @ViewBuilder var content: Content
    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            Text(label)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(ST.textSec)
                .frame(width: 160, alignment: .leading)
            content
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct CopyableTokenField: View {
    var text: String
    var placeholder: String
    @State private var copied = false

    var body: some View {
        HStack(spacing: 8) {
            Text(display)
                .font(.system(size: 15, weight: .medium, design: .rounded).monospaced())
                .foregroundStyle(text.isEmpty ? ST.textTri : ST.textPri)
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer(minLength: 8)

            Button {
                if !text.isEmpty {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(text, forType: .string)
                    copied = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { copied = false }
                }
            } label: {
                Image(systemName: copied ? "checkmark" : "doc.on.doc")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
            }
            .buttonStyle(.plain)
            .foregroundStyle(copied ? ST.greenFg : ST.textSec)
            .padding(.horizontal, 6)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(ST.secBase))
    }

    private var display: String { text.isEmpty ? placeholder : text }
}

// MARK: - Buttons

private struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        Group {
            if #available(macOS 26.0, *) {
                configuration.label
                    .foregroundStyle(Color.white.opacity(0.92))
                    .padding(.vertical, 10)
                    .padding(.horizontal, 14)
                    .glassEffect(.clear, in: .rect(cornerRadius: 14))
                    .glassEffectTransition(.matchedGeometry)
                    .scaleEffect(configuration.isPressed ? 0.985 : 1)
                    .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
            } else {
                configuration.label
                    .foregroundStyle(Color.white.opacity(0.92))
                    .padding(.vertical, 10).padding(.horizontal, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(configuration.isPressed ? ST.secBaseHover : ST.secBase)
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(Color.white.opacity(0.14), lineWidth: 1)
                            )
                    )
                    .scaleEffect(configuration.isPressed ? 0.985 : 1)
                    .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
            }
        }
    }
}

private struct DestructiveOutlineButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        Group {
            if #available(macOS 26.0, *) {
                configuration.label
                    .foregroundStyle(ST.redText)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 14)
                    .glassEffect(.regular.tint(ST.redText).interactive(), in: .rect(cornerRadius: 14))
                    .scaleEffect(configuration.isPressed ? 0.985 : 1)
                    .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
            } else {
                configuration.label
                    .foregroundStyle(ST.redText)
                    .padding(.vertical, 10).padding(.horizontal, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(ST.redStroke, lineWidth: 1)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(configuration.isPressed ? ST.redText.opacity(0.08) : Color.clear)
                            )
                    )
                    .scaleEffect(configuration.isPressed ? 0.985 : 1)
                    .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
            }
        }
    }
}

// MARK: - Close button
private struct CloseButton: View {
    var action: () -> Void
    @State private var hover = false
    var body: some View {
        Button(action: action) {
            Group {
                if #available(macOS 26.0, *) {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(ST.textPri)
                        .frame(width: 28, height: 28)
                        .glassEffect(.clear, in: .circle)
                } else {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(ST.textPri)
                        .frame(width: 28, height: 28)
                        .background(
                            Circle().fill(hover ? ST.secBaseHover : ST.secBase)
                                .overlay(Circle().stroke(Color.white.opacity(0.22), lineWidth: 1))
                        )
                }
            }
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
        .accessibilityLabel("Закрыть")
    }
}
