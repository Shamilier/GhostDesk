import SwiftUI
import AppKit

// MARK: - Design Tokens




private enum GD {
    // Card
    static let corner: CGFloat = 24
    static let padX: CGFloat = 56
    static let padY: CGFloat = 48
    static let maxWidth: CGFloat = 560
    static let minHeight: CGFloat = 400

    // Colors
    static let cardStrokeLight = Color.white.opacity(0.07)
    static let cardStrokeDark  = Color.black.opacity(0.35)
    static let textPrimary     = Color.white
    static let textSecondary   = Color.white.opacity(0.72)
    static let textTertiary    = Color.white.opacity(0.48)

    // CTA gradient
    static let ctaA = Color(red: 0.965, green: 0.26,  blue: 0.996) // #F642E0-ish
    static let ctaB = Color(red: 0.423, green: 0.475, blue: 1.000) // #6C79FF

    // Secondary button bases
    static let secondaryBase       = Color.white.opacity(0.06)
    static let secondaryBaseHover  = Color.white.opacity(0.12)

    // Shadows
    static let cardShadow   = Color.black.opacity(0.30)
    static let ctaGlowA     = Color(red: 0.65, green: 0.42, blue: 1.0).opacity(0.34)
    static let ctaGlowB     = Color(red: 0.30, green: 0.43, blue: 1.0).opacity(0.22)
}



private final class WindowConfiguratorView: NSView {
    private var originalMinSize: NSSize?
    private var originalMaxSize: NSSize?
    private var originalHasShadow: Bool?
    private var originalStyleMask: NSWindow.StyleMask?
    private weak var observedWindow: NSWindow?

    private let onboardingContentSize = NSSize(width: 640, height: 460)
    private let overlayMinimumContentSize = NSSize(width: 320, height: 60)

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()

        guard let window = window else {
            restoreWindowStateIfNeeded()
            return
        }

        observedWindow = window

        if originalMinSize == nil { originalMinSize = window.minSize }
        if originalMaxSize == nil { originalMaxSize = window.maxSize }
        if originalHasShadow == nil { originalHasShadow = window.hasShadow }
        if originalStyleMask == nil { originalStyleMask = window.styleMask }

        applyOnboardingConstraints(to: window)
    }

    private func applyOnboardingConstraints(to window: NSWindow) {
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true

        window.setContentSize(onboardingContentSize)
        window.minSize = onboardingContentSize
        window.maxSize = onboardingContentSize

        var styleMask = window.styleMask
        styleMask.remove(.resizable)
        window.styleMask = styleMask
    }

    private func restoreWindowStateIfNeeded() {
        guard let window = observedWindow else { return }

        if let originalStyleMask {
            window.styleMask = originalStyleMask
        }

        if let originalHasShadow {
            window.hasShadow = originalHasShadow
        }

        if let originalMinSize {
            let width = max(originalMinSize.width, overlayMinimumContentSize.width)
            let height = max(originalMinSize.height, overlayMinimumContentSize.height)
            window.minSize = NSSize(width: width, height: height)
        } else {
            window.minSize = overlayMinimumContentSize
        }

        if let originalMaxSize {
            var adjustedMax = originalMaxSize
            adjustedMax.width = max(adjustedMax.width, window.minSize.width)
            adjustedMax.height = max(adjustedMax.height, window.minSize.height)
            window.maxSize = adjustedMax
        }

        originalMinSize = nil
        originalMaxSize = nil
        originalHasShadow = nil
        originalStyleMask = nil
        observedWindow = nil
    }
}

struct WindowConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        WindowConfiguratorView()
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}


// MARK: - View

struct ApiKeyGateView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @EnvironmentObject private var auth: AuthState
    @EnvironmentObject private var oauth: OAuthCoordinator
    @ObservedObject private var overlay = OverlayModel.shared

    @State private var didAppear = false

    var body: some View {
        ZStack {
            // Прозрачный фон: видна рабочая среда macOS
            Color.clear

            card
                .frame(maxWidth: GD.maxWidth, minHeight: GD.minHeight)
                .padding(.horizontal, 40)
                .opacity(didAppear ? 1 : 0)
                .scaleEffect(didAppear || reduceMotion ? 1 : 0.98)
                .offset(y: didAppear || reduceMotion ? 0 : 12)
                .animation(.easeOut(duration: 0.38), value: didAppear)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(WindowConfigurator())   // ← ДОБАВЬ ЭТО
        .contentShape(Rectangle())                // большая hit-area для перетаскивания окна
        .onAppear { didAppear = true }
    }

    // MARK: Card

    private var card: some View {
        VStack(spacing: 28) {
            VStack(spacing: 10) {
                Text("Добро пожаловать в Ghost AI")
                    .font(.system(size: 28, weight: .semibold, design: .rounded))
                    .foregroundStyle(GD.textPrimary)
                    .multilineTextAlignment(.center)

                Text("Ваш AI-ассистент прямо на рабочем столе.")
                    .font(.system(size: 17, weight: .regular, design: .rounded))
                    .foregroundStyle(GD.textSecondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 440)
            }

            VStack(spacing: 16) {
                Button("Зарегистрироваться", action: { openPortal(.signUp) })
                    .buttonStyle(GhostPrimaryButtonStyle())
                    .keyboardShortcut(.defaultAction)   // Enter
                    .focusable(true)
                    .focusEffectDisabled(false)

                Button("Войти", action: { openPortal(.signIn) })
                    .buttonStyle(GhostSecondaryButtonStyle())
            }
            .frame(maxWidth: 440)

            if let error = auth.lastError, !error.isEmpty {
                Text(error)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(Color(red: 0.98, green: 0.34, blue: 0.33))
                    .multilineTextAlignment(.center)
                    .padding(.top, -4)
                    .transition(.opacity)
            }

            if oauth.isAuthorizing {
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(.white)
            }

            Text("Powered by Ghost AI")
                .font(.system(size: 13, weight: .regular, design: .rounded))
                .foregroundStyle(GD.textTertiary)
                .padding(.top, 4)
        }
        .padding(.horizontal, GD.padX)
        .padding(.vertical, GD.padY)
        .background(cardBackgroundClipped)     // ✅ заменили на версию с clip
        .overlay(cardBorderSoft)               // ✅ заменили на мягкую обводку
        .clipShape(RoundedRectangle(cornerRadius: GD.corner, style: .continuous))
        .shadow(color: GD.cardShadow, radius: 24, x: 0, y: 18) // ✅ только один мягкий drop shadow
        .accessibilityElement(children: .contain)
        
    }
    private var glassBackgroundClipped: some View {
        Group {
            if overlay.usesLiquidGlass, #available(macOS 26.0, *) {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .fill(Color.white.opacity(0.06))
                            .blur(radius: 18)
                            .blendMode(.plusLighter)
                            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    )
                    .glassEffect(.clear, in: .rect(cornerRadius: 24))
            } else {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .fill(Color.white.opacity(0.06))
                            .blur(radius: 18)
                            .blendMode(.plusLighter)
                            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    )
            }
        }
    }
    private var cardBackgroundClipped: some View {
        Group {
            if overlay.usesLiquidGlass, #available(macOS 26.0, *) {
                RoundedRectangle(cornerRadius: GD.corner, style: .continuous)
                    .fill(Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: GD.corner, style: .continuous)
                            .fill(Color.white.opacity(0.06))
                            .blur(radius: 18)
                            .blendMode(.plusLighter)
                            .clipShape(RoundedRectangle(cornerRadius: GD.corner, style: .continuous))
                    )
                    .glassEffect(.clear, in: .rect(cornerRadius: GD.corner))
            } else {
                RoundedRectangle(cornerRadius: GD.corner, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: GD.corner, style: .continuous)
                            .fill(Color.white.opacity(0.06))
                            .blur(radius: 18)
                            .blendMode(.plusLighter)
                            .clipShape(RoundedRectangle(cornerRadius: GD.corner, style: .continuous))
                    )
            }
        }
    }
    private var cardBorderSoft: some View {
        RoundedRectangle(cornerRadius: GD.corner, style: .continuous)
            .stroke(Color.white.opacity(0.08), lineWidth: 1)
            .overlay(
                RoundedRectangle(cornerRadius: GD.corner, style: .continuous)
                    .stroke(Color.black.opacity(0.25), lineWidth: 1.2)
                    .blur(radius: 4)
                    .offset(y: 1)
                    .mask(
                        LinearGradient(colors: [.black, .clear],
                                       startPoint: .top,
                                       endPoint: .bottom)
                            .clipShape(RoundedRectangle(cornerRadius: GD.corner, style: .continuous))
                    )
            )
    }



    private var glassBorderSoft: some View {
        // без screen/saturation смешения — они дают ореол
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .stroke(Color.white.opacity(0.08), lineWidth: 1)
            .overlay(
                // чуть подчёркиваем низ, но очень мягко
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color.black.opacity(0.25), lineWidth: 1.2)
                    .blur(radius: 4)
                    .offset(y: 1)
                    .mask(
                        LinearGradient(colors: [.black, .clear], startPoint: .top, endPoint: .bottom)
                            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    )
            )
    }


    private var cardBackground: some View {
        Group {
            if reduceTransparency {
                RoundedRectangle(cornerRadius: GD.corner, style: .continuous)
                    .fill(Color.black.opacity(0.78))
            } else {
                Group {
                    if overlay.usesLiquidGlass, #available(macOS 26.0, *) {
                        RoundedRectangle(cornerRadius: GD.corner, style: .continuous)
                            .fill(Color.clear)
                            .overlay(
                                RoundedRectangle(cornerRadius: GD.corner, style: .continuous)
                                    .fill(Color.white.opacity(0.08))
                                    .blur(radius: 24)
                                    .blendMode(.plusLighter)
                            )
                            .glassEffect(.clear, in: .rect(cornerRadius: GD.corner))
                    } else {
                        RoundedRectangle(cornerRadius: GD.corner, style: .continuous)
                            .fill(.ultraThinMaterial)
                            .overlay(
                                RoundedRectangle(cornerRadius: GD.corner, style: .continuous)
                                    .fill(Color.white.opacity(0.08))
                                    .blur(radius: 24)
                                    .blendMode(.plusLighter)
                            )
                    }
                }
            }
        }
    }

    private var cardBorder: some View {
        RoundedRectangle(cornerRadius: GD.corner, style: .continuous)
            .stroke(GD.cardStrokeLight, lineWidth: 1)     // холодная светлая каёмка
            .overlay( // мягкая «нижняя» тень по периметру
                RoundedRectangle(cornerRadius: GD.corner, style: .continuous)
                    .stroke(GD.cardStrokeDark, lineWidth: 1.4)
                    .blur(radius: 6)
                    .offset(y: 2)
                    .mask(
                        RoundedRectangle(cornerRadius: GD.corner, style: .continuous)
                            .fill(
                                LinearGradient(colors: [.black, .clear],
                                               startPoint: .top,
                                               endPoint: .bottom)
                            )
                    )
            )
    }

    // MARK: Actions

    private func openPortal(_ flow: OAuthFlowKind) {
        oauth.startAuthorization(flow: flow)
    }
}

// MARK: - Button Styles

private struct GhostPrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) var isEnabled
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        let scale: CGFloat = (pressed && !reduceMotion) ? 0.985 : 1.0

        configuration.label
            .font(.system(size: 18, weight: .semibold, design: .rounded))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 56)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(LinearGradient(colors: [GD.ctaA, GD.ctaB],
                                         startPoint: .leading, endPoint: .trailing))
                    .overlay(
                        // «liquid» внутренний свет
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.white.opacity(0.10))
                            .blur(radius: 36)
                            .blendMode(.plusLighter)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.white.opacity(0.25), lineWidth: 1)
                    .blendMode(.screen)
            )
            .shadow(color: GD.ctaGlowA, radius: 18, x: 0, y: 10)
            .shadow(color: GD.ctaGlowB, radius: 22, x: 0, y: 0)
            .scaleEffect(scale)
            .opacity(isEnabled ? 1 : 0.65)
            .animation(.easeOut(duration: 0.16), value: pressed)
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .accessibilityHint("Основная кнопка регистрации")
    }
}

private struct GhostSecondaryButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        let scale: CGFloat = (pressed && !reduceMotion) ? 0.985 : 1.0

        configuration.label
            .font(.system(size: 17, weight: .semibold, design: .rounded))
            .foregroundStyle(Color.white.opacity(0.92))
            .frame(maxWidth: .infinity, minHeight: 56)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(GD.secondaryBase)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.white.opacity(0.14), lineWidth: 1)
                            .blendMode(.screen)
                    )
            )
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .scaleEffect(scale)
            .animation(.easeOut(duration: 0.16), value: pressed)
            .onHover { hover in
#if os(macOS)
                // лёгкий hover-highlight
                NSAnimationContext.runAnimationGroup { _ in
                    // handled by overlay via conditional
                }
#endif
            }
            .background( // ховер-подсветка
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(GD.secondaryBaseHover)
                    .opacity(0) // базово скрыт
                    .allowsHitTesting(false)
                    .overlay(EmptyView())
            )
    }
}

// MARK: - Preview
