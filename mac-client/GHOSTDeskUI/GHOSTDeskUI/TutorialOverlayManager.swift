import AppKit
import SwiftUI

final class TutorialOverlayManager {
    static let shared = TutorialOverlayManager()

    private var window: TutorialOverlayWindow?
    private var hostingView: NSHostingView<AnyView>?      // ← тут

    private var currentScreen: NSScreen?

    private init() {}

    func presentOverlay(on screen: NSScreen? = NSScreen.main) {
        guard let screen else { return }
        currentScreen = screen

        let rootView = AnyView(                      // ← оборачиваем в AnyView
            TutorialOverlayView(screenFrame: screen.frame)
                .environmentObject(OverlayModel.shared)
        )

        if window == nil {
            let overlayWindow = TutorialOverlayWindow(contentRect: screen.frame)
            let host = NSHostingView(rootView: rootView)
            overlayWindow.contentView = host
            window = overlayWindow
            hostingView = host
        } else if let host = hostingView {
            host.rootView = rootView                 // ← тип теперь совпадает
        }

        window?.setFrame(screen.frame, display: true)
        window?.alphaValue = 0
        window?.makeKeyAndOrderFront(nil)
        window?.orderFrontRegardless()

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.25
            ctx.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            window?.animator().alphaValue = 1
        }
    }

    func refreshOverlayFrame() {
        guard let screen = currentScreen ?? NSScreen.main else { return }
        window?.setFrame(screen.frame, display: true)
    }

    func hideOverlay() {
        guard let window else { return }
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.18
            ctx.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            window.animator().alphaValue = 0
        } completionHandler: { [weak self] in
            window.orderOut(nil)
            self?.window?.alphaValue = 1
        }
    }
}

private final class TutorialOverlayWindow: NSPanel {
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
        ignoresMouseEvents = false
        level = .statusBar
        hasShadow = false
        hidesOnDeactivate = false
        isFloatingPanel = true
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
    }
}
