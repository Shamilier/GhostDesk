import SwiftUI
import AppKit

enum TutorialTooltipPosition {
    case top, bottom, left, right
}

struct TutorialStep: Identifiable {
    let id = UUID()
    let target: OnboardingTarget
    let title: String
    let subtitle: String
    let position: TutorialTooltipPosition
    let highlightPadding: CGFloat
}

final class TutorialOverlayState: ObservableObject {
    @Published var isPresented: Bool = false
    @Published var steps: [TutorialStep] = []
    @Published var currentIndex: Int = 0
    @Published var targetFrames: [OnboardingTarget: CGRect] = [:]

    var currentStep: TutorialStep? {
        guard steps.indices.contains(currentIndex) else { return nil }
        return steps[currentIndex]
    }

    func next() {
        guard !steps.isEmpty else { return }
        currentIndex = min(currentIndex + 1, steps.count - 1)
    }

    func previous() {
        guard !steps.isEmpty else { return }
        currentIndex = max(currentIndex - 1, 0)
    }
}

final class TutorialOverlayManager {
    static let shared = TutorialOverlayManager()
    private init() {}

    private var window: NSPanel?
    private var hostingView: NSHostingView<TutorialOverlayView>?
    private let state = TutorialOverlayState()
    private var completion: (() -> Void)?

    func present(steps: [TutorialStep], targets: [OnboardingTarget: CGRect], onClose: @escaping () -> Void) {
        state.steps = steps
        state.targetFrames = targets
        state.currentIndex = 0
        state.isPresented = true
        completion = onClose

        let screenFrame = NSScreen.main?.frame ?? NSRect(x: 0, y: 0, width: 1400, height: 900)

        if window == nil {
            let panel = NSPanel(contentRect: screenFrame, styleMask: [.borderless], backing: .buffered, defer: false)
            panel.backgroundColor = .clear
            panel.isOpaque = false
            panel.hasShadow = false
            panel.level = .floating
            panel.ignoresMouseEvents = false
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]

            let root = TutorialOverlayView(state: state, onClose: { [weak self] in
                self?.handleClose()
            })

            let host = NSHostingView(rootView: root)
            host.frame = screenFrame
            panel.contentView = host
            window = panel
            hostingView = host
        }

        hostingView?.rootView = TutorialOverlayView(state: state, onClose: { [weak self] in
            self?.handleClose()
        })

        window?.setFrame(screenFrame, display: true)
        hostingView?.frame = screenFrame

        if let window {
            window.alphaValue = 0
            window.orderFrontRegardless()
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.22
                ctx.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                window.animator().alphaValue = 1
            }
        }
    }

    func updateTargets(_ targets: [OnboardingTarget: CGRect]) {
        state.targetFrames = targets
    }

    func dismiss() {
        guard let window else { return }
        state.isPresented = false
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.2
            ctx.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            window.animator().alphaValue = 0
        } completionHandler: { [weak self] in
            self?.window?.orderOut(nil)
        }
    }

    private func handleClose() {
        dismiss()
        completion?()
    }
}
