import SwiftUI
import AppKit

// MARK: - Design Tokens
private enum ST {
    static let corner: CGFloat = 24
    static let padX: CGFloat = 56
    static let padY: CGFloat = 48
    static let width: CGFloat = 560
    static let minHeight: CGFloat = 480

    static let textPri   = Color.white
    static let textSec   = Color.white.opacity(0.72)
    static let textTri   = Color.white.opacity(0.48)

    static let line      = Color.white.opacity(0.06)

    static let secBase        = Color.white.opacity(0.06)
    static let secBaseHover   = Color.white.opacity(0.12)

    static let redText   = Color(red: 1.00, green: 0.37, blue: 0.34)
    static let redStroke = Color(red: 1.00, green: 0.37, blue: 0.34).opacity(0.45)

    static let greenFg   = Color(red: 0.61, green: 0.95, blue: 0.79)
    static let greenBg   = Color(red: 0.18, green: 0.73, blue: 0.46).opacity(0.18)

    static let shadow    = Color.black.opacity(0.28)
}

// MARK: - SettingsSheet
struct SettingsSheet: View {
    @Binding var isShown: Bool
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @EnvironmentObject private var auth: AuthState

    @State private var isRefreshing = false

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
        // Прозрачный контейнер окна, чтобы не было «полосы»
        ZStack {
            Color.clear
            cardView
                .frame(width: ST.width)
                .frame(minHeight: ST.minHeight)
                .background(liquidGlassBackground)
                .overlay(singleStroke)
                .clipShape(RoundedRectangle(cornerRadius: ST.corner, style: .continuous))
                .shadow(color: ST.shadow, radius: 24, x: 0, y: 18)
                .padding(.top, 12)
                .padding(.trailing, 20)
                .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .topTrailing)))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(SettingsWindowConfigurator()) // прозрачное окно без системной тени
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
    }

    // MARK: Card visuals
    private var liquidGlassBackground: some View {
        Group {
            if reduceTransparency {
                RoundedRectangle(cornerRadius: ST.corner, style: .continuous)
                    .fill(Color.black.opacity(0.78))
            } else {
                RoundedRectangle(cornerRadius: ST.corner, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: ST.corner, style: .continuous)
                            .fill(Color.white.opacity(0.06))
                            .blur(radius: 18)
                            .blendMode(.plusLighter)
                            .clipShape(RoundedRectangle(cornerRadius: ST.corner, style: .continuous))
                    )
            }
        }
        .compositingGroup()
        .clipped()
    }

    private var singleStroke: some View {
        RoundedRectangle(cornerRadius: ST.corner, style: .continuous)
            .stroke(Color.white.opacity(0.08), lineWidth: 1)
            .overlay(
                // мягкий edge-shadow снизу
                RoundedRectangle(cornerRadius: ST.corner, style: .continuous)
                    .stroke(Color.black.opacity(0.25), lineWidth: 1.2)
                    .blur(radius: 4)
                    .offset(y: 1)
                    .mask(
                        LinearGradient(colors: [.black, .clear],
                                       startPoint: .top, endPoint: .bottom)
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

private struct DestructiveOutlineButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
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

// MARK: - Close button
private struct CloseButton: View {
    var action: () -> Void
    @State private var hover = false
    var body: some View {
        Button(action: action) {
            Image(systemName: "xmark")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(ST.textPri)
                .frame(width: 28, height: 28)
                .background(
                    Circle().fill(hover ? ST.secBaseHover : ST.secBase)
                        .overlay(Circle().stroke(Color.white.opacity(0.22), lineWidth: 1))
                )
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
        .accessibilityLabel("Закрыть")
    }
}

// MARK: - Transparent, no-shadow window
struct SettingsWindowConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let v = NSView()
        DispatchQueue.main.async {
            if let w = v.window {
                w.isOpaque = false
                w.backgroundColor = .clear
                w.hasShadow = false
                w.titleVisibility = .hidden
                w.titlebarAppearsTransparent = true

                // фикс размера окна (убери, если не нужно)
                w.setContentSize(NSSize(width: ST.width, height: ST.minHeight))
                w.styleMask.remove(.resizable)
                w.minSize = NSSize(width: ST.width, height: ST.minHeight)
                w.maxSize = NSSize(width: ST.width, height: ST.minHeight)
            }
        }
        return v
    }
    func updateNSView(_ nsView: NSView, context: Context) {}
}
