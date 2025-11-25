// OverlayWindowManager.swift
import AppKit
import SwiftUI
import Carbon.HIToolbox

final class OverlayWindowManager {
    static let shared = OverlayWindowManager()
    private init() {}

    private var window: OverlayPanel?
    private var hostingView: NSHostingView<AnyView>?   // ✅ конкретный тип
    private var lastContentSize: CGSize = .zero
    private var anchorInWindow: CGPoint?
    private let minimumContentSize = CGSize(width: 320, height: 60)
    private var authState: AuthState?
    private var hidesFromScreenCapture = true
    private let snapDistance: CGFloat = 12
    // MARK: - Coalesced resize
    private var resizeWorkItem: DispatchWorkItem?
    private var finalResizeWorkItem: DispatchWorkItem?
    private var didApplyInitialPlacement = false
    
    // MARK: - Coalesced & Suppressed resize
    private var suppressAutoResize = false

    /// Публичный флаг для SwiftUI-модификатора
    var isAutoResizeSuppressed: Bool { suppressAutoResize }

    /// Коалесим частые ресайзы (используется из overlayAutoResize).
    func scheduleResize(animate: Bool = false, coalesce: TimeInterval = 0.02) {
        // Если подавление включено — просто игнорируем текущий тик
        guard !suppressAutoResize else { return }
        resizeWorkItem?.cancel()
        let item = DispatchWorkItem { [weak self] in
            self?.resizeToFitContent(animate: animate)
        }
        resizeWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + coalesce, execute: item)
    }

    /// На время анимации блокируем авто-ресайзы и делаем один финальный.
    func withResizeSuspended(_ duration: TimeInterval, finalAnimate: Bool = true) {
        suppressAutoResize = true
        // Сбросим отложенный коалессер, чтобы не мигал
        resizeWorkItem?.cancel()
        resizeWorkItem = nil
        // По окончании анимации — один красивый ресайз
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) { [weak self] in
            guard let self else { return }
            self.suppressAutoResize = false
            self.resizeToFitContent(animate: finalAnimate)
        }
    }

    /// Полностью «замораживает» авто-ресайзы и отменяет отложенные тикеты.
    func freezeAutoResize() {
        suppressAutoResize = true
        resizeWorkItem?.cancel()
        resizeWorkItem = nil
        finalResizeWorkItem?.cancel()
        finalResizeWorkItem = nil
    }

    /// Возобновляет авто-ресайз и сразу подгоняет окно под текущий контент.
    func resumeAutoResize(animate: Bool = true) {
        suppressAutoResize = false
        resizeWorkItem?.cancel()
        resizeWorkItem = nil
        finalResizeWorkItem?.cancel()
        finalResizeWorkItem = nil
        resizeToFitContent(animate: animate)
    }

    /// Один финальный анимированный ресайз после завершения spring-анимации SwiftUI.
    func kickFinalResize(after delay: TimeInterval = 0.38) {
        finalResizeWorkItem?.cancel()
        let item = DispatchWorkItem { [weak self] in
            self?.finalResizeWorkItem = nil
            self?.resizeToFitContent(animate: true)
        }
        finalResizeWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: item)
    }
    

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
                    .background(WindowDragHandle())   // drag только по «пустому» месту
            )

            let hosting = NSHostingView(rootView: root)
            panel.contentView = hosting
            hostingView = hosting
            lastContentSize = .zero
            anchorInWindow = nil
            panel.alphaValue = model.alpha
            panel.sharingType = hidesFromScreenCapture ? .none : .readOnly

            NSApp.activate(ignoringOtherApps: true)
            panel.makeKeyAndOrderFront(nil)
            panel.setIsVisible(true)

            window = panel
            applyFocus(model.isFocusable)

            // 1) стартовая позиция — под меню-баром, по центру экрана (как по ⌘3)
            centerTop(on: NSScreen.main!, topInset: 12, animate: false)

            // 2) подгоняем размер под контент
            resizeToFitContent(animate: false)

            // 3) один корректирующий шаг после первого layout SwiftUI (на случай, если размер изменится)
            if !didApplyInitialPlacement {
                didApplyInitialPlacement = true
                DispatchQueue.main.async { [weak self] in
                    self?.centerTop(on: NSScreen.main!, topInset: 12, animate: false)
                }
            }

        } else {
            window?.alphaValue = model.alpha
            NSApp.activate(ignoringOtherApps: true)
            window?.makeKeyAndOrderFront(nil)
            window?.setIsVisible(true)
            updateScreenCaptureVisibility(hidden: hidesFromScreenCapture)

            if hostingView == nil, let existing = window?.contentView as? NSHostingView<AnyView> {
                hostingView = existing
            }

            // ✅ на всякий случай подгоняем и тут, если до этого окно «раздулось»
            resizeToFitContent()
        }
    }

    func updateSize(to newContentSize: CGSize, animate: Bool = true) {
        guard let window else { return }

        // Clamp к нашим минимальным ограничениям, чтобы окно не схлопывалось
        let targetW = max(newContentSize.width, minimumContentSize.width)
        let targetH = max(newContentSize.height, minimumContentSize.height)

        // Якорим верхнюю грань окна, как и в обычном resizeToFitContent
        var frame = window.frame
        let deltaH = targetH - frame.size.height
        frame.origin.y -= deltaH
        frame.size = CGSize(width: targetW, height: targetH)

        if animate {
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.25
                ctx.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                window.animator().setFrame(frame, display: true)
            }
        } else {
            window.setFrame(frame, display: true)
        }

        lastContentSize = CGSize(width: targetW, height: targetH)
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
        let contentSize = lastContentSize == .zero ? f.size : lastContentSize
        let fallbackAnchor = CGPoint(x: contentSize.width / 2, y: contentSize.height / 2)
        let anchor = anchorInWindow ?? fallbackAnchor
        f.origin.x = rect.midX - anchor.x
        f.origin.y = rect.midY - anchor.y
        w.setFrame(clamped(f, to: rect), display: true, animate: false)
    }

    func setAlpha(_ a: CGFloat) { window?.alphaValue = a }

    func applyFocus(_ focusable: Bool) {
        window?.ignoresMouseEvents = !focusable
    }

    func updateScreenCaptureVisibility(hidden: Bool) {
        hidesFromScreenCapture = hidden
        window?.sharingType = hidden ? .none : .readOnly
    }

    // MARK: - Helpers

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

    private func convertToAppKitAnchor(_ anchor: CGPoint, contentSize: CGSize) -> CGPoint {
        CGPoint(x: anchor.x, y: contentSize.height - anchor.y)
    }
}

private extension OverlayWindowManager {
    func resolveDimension(
        measured rawMeasured: CGFloat,
        intrinsic rawIntrinsic: CGFloat,
        previous rawPrevious: CGFloat,
        minimum: CGFloat
    ) -> CGFloat {
        let measured = rawMeasured.isFinite && rawMeasured > 0 ? rawMeasured : nil
        let intrinsic = rawIntrinsic.isFinite && rawIntrinsic > 0 ? rawIntrinsic : nil
        let previous = rawPrevious.isFinite && rawPrevious > 0 ? rawPrevious : minimum

        if let measured, let intrinsic {
            let shrinking = measured < previous || intrinsic < previous
            let candidate = shrinking ? min(measured, intrinsic) : max(measured, intrinsic)
            return max(candidate, minimum)
        }
        if let measured { return max(measured, minimum) }
        if let intrinsic { return max(intrinsic, minimum) }
        return max(previous, minimum)
    }
}

extension OverlayWindowManager {
    /// Подгоняет NSPanel под intrinsic-размер SwiftUI-контента (без бесконечных высот).
    func resizeToFitContent(animate: Bool = true) {
        guard let window = window else { return }

        // Берём уже существующий NSHostingView<AnyView>
        let hosting = hostingView ?? (window.contentView as? NSHostingView<AnyView>)
        guard let hosting else { return }

        hosting.layoutSubtreeIfNeeded()

        // Текущая доступная ширина контента внутри окна
        let contentRect = window.contentLayoutRect
        let availableWidth = max(minimumContentSize.width, floor(contentRect.width))

        // Верхняя граница по высоте — видимая область экрана минус небольшой зазор
        let screen = window.screen ?? NSScreen.main
        let screenMaxH = screen?.visibleFrame.height ?? 1200
        let hardMaxHeight = max(200, floor(screenMaxH - 20)) // clamp сверху

        // ✅ Измеряем: фиксируем ШИРИНУ и ставим БЕЗОПАСНУЮ "потолочную" высоту
        let originalSize = hosting.frame.size
        hosting.setFrameSize(NSSize(width: availableWidth, height: hardMaxHeight))
        hosting.layoutSubtreeIfNeeded()
        var measured = hosting.fittingSize
        // вернуть как было (на всякий)
        hosting.setFrameSize(originalSize)

        // Санитизируем
        if !measured.width.isFinite || measured.width <= 0 { measured.width = availableWidth }
        if !measured.height.isFinite || measured.height <= 0 { measured.height = minimumContentSize.height }

        var targetW = max(measured.width,  minimumContentSize.width)
        var targetH = max(measured.height, minimumContentSize.height)
        targetH = min(targetH, hardMaxHeight) // жёсткий потолок по высоте

        // Ранний выход, если почти не изменилось
        if abs(targetW - lastContentSize.width) < 0.5 &&
           abs(targetH - lastContentSize.height) < 0.5 {
            return
        }

        // Якорим верх окна (чтобы при сжатии не «падало» вниз)
        // Якорим верх окна (верх остаётся на месте, низ растёт/сжимается)
        var frame = window.frame
        let deltaH = targetH - frame.size.height
        frame.origin.y -= deltaH            // ← всегда двигаем origin.y на разницу высот
        frame.size.height = targetH
        frame.size.width  = max(frame.size.width, targetW)

        // выставляем фрейм (лучше через анимационный контекст)
        if animate {
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.25
                ctx.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                window.animator().setFrame(frame, display: true)
            }
        } else {
            window.setFrame(frame, display: true)
        }
        lastContentSize = CGSize(width: targetW, height: targetH)
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
        isMovableByWindowBackground = false // двигаем только по DragHandle

        hidesOnDeactivate = false
        isFloatingPanel = true
        becomesKeyOnlyIfNeeded = false
        worksWhenModal = true

        level = .statusBar + 2
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle, .stationary]
        sharingType = .none
        acceptsMouseMovedEvents = true
    }

    var screenFrame: CGRect? { window?.frame }

    func frameInScreen(from localRect: CGRect) -> CGRect? {
        guard let window, let hostingView else { return nil }
        let windowRect = hostingView.convert(NSRect(origin: localRect.origin, size: localRect.size), to: nil)
        let screenRect = window.convertToScreen(windowRect)
        return CGRect(x: screenRect.origin.x, y: screenRect.origin.y, width: screenRect.width, height: screenRect.height)
    }

    func framesInScreenSpace(from localFrames: [OnboardingTarget: CGRect]) -> [OnboardingTarget: CGRect] {
        var result: [OnboardingTarget: CGRect] = [:]
        for (target, frame) in localFrames {
            guard let screenRect = frameInScreen(from: frame) else { continue }
            result[target] = screenRect
        }
        return result
    }

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

// SwiftUI-прокладка для drag области (двигает всю панель только за «пустые» места)
fileprivate struct WindowDragHandle: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let v = NSView()
        let pan = NSPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.onPan(_:)))
        v.addGestureRecognizer(pan)
        return v
    }
    func updateNSView(_ nsView: NSView, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator: NSObject {
        private var last: CGPoint = .zero
        @objc func onPan(_ g: NSPanGestureRecognizer) {
            guard let w = g.view?.window else { return }
            let loc = g.location(in: nil)
            switch g.state {
            case .began: last = loc
            case .changed:
                let dx = loc.x - last.x
                let dy = loc.y - last.y
                var f = w.frame
                f.origin.x += dx
                f.origin.y += dy
                w.setFrame(f, display: true)
                last = loc
            default: break
            }
        }
    }
}
extension OverlayWindowManager {
    /// Центрирует окно так, чтобы ВЕРХНЯЯ КРОМКА была выровнена по центру экрана.
    /// topInset — если нужно опустить якорь чуть ниже верхней кромки (например, на высоту паддинга тулбара).
    func centerTop(on screen: NSScreen, topInset: CGFloat = 12, animate: Bool = false) {
        guard let w = window else { return }
            // Экран — тот, на котором сейчас окно; fallback на main
            let screen = w.screen ?? NSScreen.main!
            let vf = screen.visibleFrame

            var f = w.frame
            let size = f.size // берем фактический размер окна

            // Горизонтальный центр экрана (ровно под «островком»)
            f.origin.x = vf.midX - size.width / 2
            // Верх окна — под меню-баром с небольшим отступом
            f.origin.y = vf.maxY - topInset - size.height

            f = clamped(f, to: vf)

            if animate {
                NSAnimationContext.runAnimationGroup { ctx in
                    ctx.duration = 0.25
                    ctx.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                    w.animator().setFrame(f, display: true)
                }
            } else {
                w.setFrame(f, display: true)
            }
    }
}
