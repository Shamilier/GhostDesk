// OverlayWindowManager.swift
import AppKit
import SwiftUI
import Carbon.HIToolbox

final class OverlayWindowManager {
    static let shared = OverlayWindowManager()
    private init() {}

    private var window: OverlayPanel?
    private var hostingView: NSHostingView<AnyView>? // <--- CHANGED
    private var lastContentSize: CGSize = .zero
    private let minimumContentSize = CGSize(width: 320, height: 60)
    private var authState: AuthState?
    private let snapDistance: CGFloat = 12

    var isVisible: Bool { window?.isVisible ?? false }

    func show(model: OverlayModel, auth: AuthState) {
        authState = auth
        model.attachAuth(auth)
        if window == nil {
            let panel = OverlayPanel(contentRect: NSRect(x: 0, y: 0, width: 920, height: 160))
            let root = AnyView(
                OverlayRootView(auth: auth)
                    .environmentObject(model)
                    .environmentObject(auth)
            )
            let hosting = NSHostingView(rootView: root)
            panel.contentView = hosting
            hostingView = hosting
            lastContentSize = .zero
            panel.alphaValue = model.alpha
            panel.isMovableByWindowBackground = true

            NSApp.activate(ignoringOtherApps: true)
            panel.makeKeyAndOrderFront(nil)
            panel.setIsVisible(true)

            if let screen = NSScreen.main { center(on: screen) }
            window = panel
            applyFocus(model.isFocusable)
            DispatchQueue.main.async { [weak self] in self?.sizeToFitContent() }
        } else {
            window?.alphaValue = model.alpha
            NSApp.activate(ignoringOtherApps: true)
            window?.makeKeyAndOrderFront(nil)
            window?.setIsVisible(true)
            if hostingView == nil, let existing = window?.contentView as? NSHostingView<AnyView> {
                hostingView = existing
            }
            DispatchQueue.main.async { [weak self] in self?.sizeToFitContent() }
        }
    }

    func sizeToFitContent() {
        guard let hostingView, hostingView.bounds.size != .zero else { return }
        hostingView.layoutSubtreeIfNeeded()
        var fittingSize = hostingView.fittingSize
        if fittingSize == .zero {
            fittingSize = hostingView.intrinsicContentSize
        }
        applyWindowSize(using: fittingSize)
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
            guard let auth = authState else { return false }
            show(model: OverlayModel.shared, auth: auth)
            return true
        }
    }

    func nudge(dx: CGFloat, dy: CGFloat) {
        guard let w = window, let screen = w.screen ?? NSScreen.main else { return }
        var f = w.frame
        f.origin.x += dx
        f.origin.y += dy
        f = clamped(f, to: screen.visibleFrame)
        w.setFrame(f, display: true, animate: false)
    }

    func center(on screen: NSScreen) {
        guard let w = window else { return }
        let rect = screen.visibleFrame
        var f = w.frame
        f.origin.x = rect.midX - f.width/2
        f.origin.y = rect.midY - f.height/2
        w.setFrame(clamped(f, to: rect), display: true, animate: false)
    }

    func setAlpha(_ a: CGFloat) { window?.alphaValue = a }

    func applyFocus(_ focusable: Bool) {
        window?.ignoresMouseEvents = !focusable
    }

    // MARK: - Helpers

    private func applyWindowSize(using measuredSize: CGSize) {
        guard measuredSize.width.isFinite,
              measuredSize.height.isFinite,
              measuredSize.width > 0,
              measuredSize.height > 0,
              let panel = window else { return }

        let width = max(measuredSize.width, minimumContentSize.width)
        let height = max(measuredSize.height, minimumContentSize.height)
        let desiredSize = CGSize(width: width, height: height)

        guard lastContentSize != desiredSize else { return }
        lastContentSize = desiredSize

        var frame = panel.frame
        let heightDelta = frame.size.height - desiredSize.height
        frame.origin.y += heightDelta
        frame.size = NSSize(width: desiredSize.width, height: desiredSize.height)

        if let screen = panel.screen ?? NSScreen.main {
            frame = clamped(frame, to: screen.visibleFrame)
        }

        panel.setFrame(frame, display: true, animate: false)
        panel.contentView?.setFrameSize(frame.size)
        hostingView?.setFrameSize(frame.size)
        hostingView?.layoutSubtreeIfNeeded()
    }

    private func clamped(_ frame: NSRect, to visible: NSRect) -> NSRect {
        var f = frame
        if f.maxX > visible.maxX { f.origin.x = visible.maxX - f.width }
        if f.minX < visible.minX { f.origin.x = visible.minX }
        if f.maxY > visible.maxY { f.origin.y = visible.maxY - f.height }
        if f.minY < visible.minY { f.origin.y = visible.minY }
        // магнит к краям
        if abs(f.minX - visible.minX) < snapDistance { f.origin.x = visible.minX }
        if abs(f.maxX - visible.maxX) < snapDistance { f.origin.x = visible.maxX - f.width }
        if abs(f.minY - visible.minY) < snapDistance { f.origin.y = visible.minY }
        if abs(f.maxY - visible.maxY) < snapDistance { f.origin.y = visible.maxY - f.height }
        return f
    }
}

// Безрамочная панель, поверх всех окон
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
        isMovableByWindowBackground = true

        hidesOnDeactivate = false
        isFloatingPanel = true
        becomesKeyOnlyIfNeeded = false
        worksWhenModal = true

        level = .statusBar
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle, .stationary]
        sharingType = .none      // best-effort «невидимость» в шаринге
        acceptsMouseMovedEvents = true
    }

    // Локальный перехват шорткатов (как в Cluely)
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard event.type == .keyDown else { return false }
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard flags.contains(.command),
              !flags.contains(.option),
              !flags.contains(.control) else { return false }

        let kc = Int(event.keyCode)
        let model = OverlayModel.shared

        switch kc {
        case kVK_ANSI_1:
            let visible = OverlayWindowManager.shared.toggleVisibility()
            model.isOverlayVisible = visible
            return true
        case kVK_ANSI_2:
            model.isFocusable.toggle()
            OverlayWindowManager.shared.applyFocus(model.isFocusable)
            return true
        case kVK_ANSI_3:
            model.resetDefaults()
            OverlayWindowManager.shared.setAlpha(model.alpha)
            return true
        case kVK_LeftArrow:
            OverlayWindowManager.shared.nudge(dx: -model.moveStep, dy: 0); return true
        case kVK_RightArrow:
            OverlayWindowManager.shared.nudge(dx:  model.moveStep, dy: 0); return true
        case kVK_UpArrow:
            OverlayWindowManager.shared.nudge(dx: 0, dy:  model.moveStep); return true
        case kVK_DownArrow:
            OverlayWindowManager.shared.nudge(dx: 0, dy: -model.moveStep); return true
        case kVK_ANSI_Minus:
            model.fontScaleIndex = max(0, model.fontScaleIndex - 1); return true
        case kVK_ANSI_Equal:
            model.fontScaleIndex = min(model.fontScaleSteps.count - 1, model.fontScaleIndex + 1); return true
        case kVK_ANSI_LeftBracket:
            model.transparencyIndex = max(0, model.transparencyIndex - 1)
            OverlayWindowManager.shared.setAlpha(model.alpha); return true
        case kVK_ANSI_RightBracket:
            model.transparencyIndex = min(model.transparencySteps.count - 1, model.transparencyIndex + 1)
            OverlayWindowManager.shared.setAlpha(model.alpha); return true
        case kVK_ANSI_O: model.startStopRecording(); return true
        case kVK_ANSI_N: model.askHint(); return true
        case kVK_ANSI_M: model.askSolve(); return true
        default:
            return false
        }
    }
}

