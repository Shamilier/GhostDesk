import AppKit
import SwiftUI
import Carbon.HIToolbox   // ← добавь это

final class OverlayWindowManager {
    static let shared = OverlayWindowManager()
    private init() {}

    private var window: OverlayPanel?

    var isVisible: Bool { window?.isVisible ?? false }

    func show(model: OverlayModel) {
        if window == nil {
            let panel = OverlayPanel(contentRect: NSRect(x: 0, y: 0, width: 920, height: 160))
            panel.contentView = NSHostingView(rootView: OverlayRootView().environmentObject(model))
            panel.alphaValue = model.alpha

            NSApp.activate(ignoringOtherApps: true)
            panel.makeKeyAndOrderFront(nil)
            panel.setIsVisible(true)

            if let screen = NSScreen.main { center(on: screen) }
            window = panel
            applyFocus(model.isFocusable)
        } else {
            window?.alphaValue = model.alpha
            NSApp.activate(ignoringOtherApps: true)
            window?.makeKeyAndOrderFront(nil)
            window?.setIsVisible(true)
        }
    }

    func hide() {
        window?.orderOut(nil)
        window?.setIsVisible(false)
    }

    @discardableResult
    func toggleVisibility() -> Bool {
        if isVisible {
            hide()
            return false
        } else {
            show(model: OverlayModel.shared)
            return true
        }
    }

    func nudge(dx: CGFloat, dy: CGFloat) {
        guard let w = window else { return }
        var f = w.frame
        f.origin.x += dx
        f.origin.y += dy
        w.setFrame(f, display: true, animate: false)
    }

    func center(on screen: NSScreen) {
        guard let w = window else { return }
        let rect = screen.visibleFrame
        var f = w.frame
        f.origin.x = rect.midX - f.width/2
        f.origin.y = rect.midY - f.height/2
        w.setFrame(f, display: true, animate: false)
    }

    func setAlpha(_ a: CGFloat) { window?.alphaValue = a }

    func applyFocus(_ focusable: Bool) {
        window?.ignoresMouseEvents = !focusable
    }
}

// Безрамочная панель, которая всегда находится поверх всех окон
final class OverlayPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        isMovableByWindowBackground = false

        hidesOnDeactivate = false
        isFloatingPanel = true
        becomesKeyOnlyIfNeeded = false
        worksWhenModal = true

        level = .statusBar
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle, .stationary]
        sharingType = .none
        acceptsMouseMovedEvents = true
    }

    // ← ЛОКАЛЬНЫЙ ПЕРЕХВАТ ШОРТКАТОВ (как в Cluely)
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        // интересуют только нажатия клавиш
        guard event.type == .keyDown else { return false }

        // ловим ИМЕННО Command (без Option/Control) — как у тебя в HotKeyManager
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard flags.contains(.command),
              !flags.contains(.option),
              !flags.contains(.control) else {
            return false
        }

        let kc = Int(event.keyCode)
        let model = OverlayModel.shared

        switch kc {

        // ⌘1 — показать/скрыть
        case kVK_ANSI_1:
            let visible = OverlayWindowManager.shared.toggleVisibility()
            model.isOverlayVisible = visible
            return true

        // ⌘2 — фокус on/off (клик-сквозь)
        case kVK_ANSI_2:
            model.isFocusable.toggle()
            OverlayWindowManager.shared.applyFocus(model.isFocusable)
            return true

        // ⌘3 — сброс
        case kVK_ANSI_3:
            model.resetDefaults()
            OverlayWindowManager.shared.setAlpha(model.alpha)
            return true

        // ⌘стрелки — подвинуть
        case kVK_LeftArrow:
            OverlayWindowManager.shared.nudge(dx: -model.moveStep, dy: 0); return true
        case kVK_RightArrow:
            OverlayWindowManager.shared.nudge(dx:  model.moveStep, dy: 0); return true
        case kVK_UpArrow:
            OverlayWindowManager.shared.nudge(dx: 0, dy:  model.moveStep); return true
        case kVK_DownArrow:
            OverlayWindowManager.shared.nudge(dx: 0, dy: -model.moveStep); return true

        // ⌘- / ⌘= — масштаб шрифта
        case kVK_ANSI_Minus:
            model.fontScaleIndex = max(0, model.fontScaleIndex - 1)
            return true
        case kVK_ANSI_Equal: // это «=», для «+» обычно Shift, но keyCode тот же
            model.fontScaleIndex = min(model.fontScaleSteps.count - 1, model.fontScaleIndex + 1)
            return true

        // ⌘[ / ⌘] — прозрачность
        case kVK_ANSI_LeftBracket:
            model.transparencyIndex = max(0, model.transparencyIndex - 1)
            OverlayWindowManager.shared.setAlpha(model.alpha)
            return true
        case kVK_ANSI_RightBracket:
            model.transparencyIndex = min(model.transparencySteps.count - 1, model.transparencyIndex + 1)
            OverlayWindowManager.shared.setAlpha(model.alpha)
            return true

        // ⌘O — запись on/off
        case kVK_ANSI_O:
            model.startStopRecording()
            return true

        // ⌘N — «Подсказать»
        case kVK_ANSI_N:
            model.askHint()
            return true

        // ⌘M — «Решить»
        case kVK_ANSI_M:
            model.askSolve()
            return true

        default:
            return false
        }
    }
}
