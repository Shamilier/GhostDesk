import AppKit
import SwiftUI

final class OverlayWindowManager {
    static let shared = OverlayWindowManager()
    private init() {}

    private var window: OverlayPanel?

    // Публичный индикатор видимости
    var isVisible: Bool { window?.isVisible ?? false }

    // Показать панель
    func show(model: OverlayModel) {
        if window == nil {
            let panel = OverlayPanel(contentRect: NSRect(x: 0, y: 0, width: 920, height: 160))
            panel.contentView = NSHostingView(rootView: OverlayRootView().environmentObject(model))
            panel.alphaValue = model.alpha
            panel.orderFrontRegardless()
            panel.setIsVisible(true)
            if let screen = NSScreen.main { center(on: screen) }
            window = panel
            applyFocus(model.isFocusable)
        } else {
            window?.alphaValue = model.alpha
            window?.orderFrontRegardless()
            window?.setIsVisible(true)
        }
    }

    // Спрятать панель
    func hide() {
        window?.orderOut(nil)
        window?.setIsVisible(false)
    }

    // Переключить видимость (возвращает новое состояние)
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

    // Сервисные действия
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

// Безрамочная неактивирующаяся панель поверх всех окон
final class OverlayPanel: NSPanel {
    init(contentRect: NSRect) {
        super.init(contentRect: contentRect, styleMask: [.borderless], backing: .buffered, defer: false)
        isReleasedWhenClosed = false
        isOpaque = false
        hasShadow = true
        backgroundColor = .clear
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        sharingType = .none              // не светимся в чужих CGWindow-снимках
        becomesKeyOnlyIfNeeded = false
        worksWhenModal = true
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}
