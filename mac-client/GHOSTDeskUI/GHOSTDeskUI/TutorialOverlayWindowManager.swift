import Foundation
import AppKit
import SwiftUI

final class TutorialOverlayWindowManager {
    static let shared = TutorialOverlayWindowManager()
    private init() {}

    private var window: NSPanel?
    private var hostingView: NSHostingView<TutorialOverlayView>?

    func present(flow: TutorialFlow) {
        guard flow.isActive else { return }
        let screenFrame = NSScreen.main?.frame ?? .zero

        if window == nil {
            let panel = NSPanel(contentRect: screenFrame, styleMask: [.borderless], backing: .buffered, defer: false)
            panel.level = .mainMenu
            panel.isOpaque = false
            panel.backgroundColor = .clear
            panel.hasShadow = false
            panel.hidesOnDeactivate = false
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
            panel.isMovable = false
            panel.ignoresMouseEvents = false
            panel.becomesKeyOnlyIfNeeded = true

            let hosting = NSHostingView(rootView: TutorialOverlayView(flow: flow))
            hosting.frame = panel.contentView?.bounds ?? .zero
            hosting.autoresizingMask = [.width, .height]
            panel.contentView = hosting

            window = panel
            hostingView = hosting
        } else {
            hostingView?.rootView = TutorialOverlayView(flow: flow)
        }

        window?.setFrame(screenFrame, display: true)
        window?.orderFront(nil)
    }

    func hide() {
        window?.orderOut(nil)
        window = nil
        hostingView = nil
    }
}
