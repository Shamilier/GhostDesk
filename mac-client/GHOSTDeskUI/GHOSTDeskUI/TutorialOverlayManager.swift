import AppKit
import SwiftUI

final class TutorialOverlayManager {
    static let shared = TutorialOverlayManager()

    private var window: TutorialOverlayPanel?
    private var hostingView: NSHostingView<TutorialOverlayView>?

    private init() {}

    func present(model: OverlayModel) {
        guard let screen = NSScreen.main else { return }
        let frame = screen.frame

        if window == nil {
            let panel = TutorialOverlayPanel(contentRect: frame)
            let overlayView = TutorialOverlayView(model: model)
            let hosting = NSHostingView(rootView: overlayView)

            panel.contentView = hosting
            panel.setFrame(frame, display: true)

            window = panel
            hostingView = hosting
        }

        guard let window else { return }

        window.alphaValue = 0
        window.setFrame(frame, display: true)
        window.orderFrontRegardless()

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.28
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            window.animator().alphaValue = 1
        }

        OverlayWindowManager.shared.bringToFront()
    }

    func hide() {
        guard let window else { return }

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.22
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            window.animator().alphaValue = 0
        } completionHandler: { [weak self] in
            self?.window?.orderOut(nil)
            self?.window?.setIsVisible(false)
        }
    }
}

final class TutorialOverlayPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    init(contentRect: NSRect) {
        super.init(contentRect: contentRect, styleMask: [.borderless], backing: .buffered, defer: false)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        level = .statusBar
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        ignoresMouseEvents = false
        isMovableByWindowBackground = false
    }
}
