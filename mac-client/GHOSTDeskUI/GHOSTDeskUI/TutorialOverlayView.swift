import SwiftUI

enum TutorialCalloutPosition {
    case top
    case bottom
    case leading
    case trailing
}

struct TutorialStep: Identifiable {
    let id = UUID()
    let target: OnboardingTarget
    let title: String
    let message: String
    let calloutPosition: TutorialCalloutPosition
    var padding: CGFloat = 14
    var cornerRadius: CGFloat = 18
}

struct TutorialOverlayView: View {
    let steps: [TutorialStep]
    @Binding var currentIndex: Int
    let targets: [OnboardingTarget: CGRect]
    var onClose: () -> Void

    @State private var isVisible = false

    private var activeStep: TutorialStep? {
        guard steps.indices.contains(currentIndex) else { return nil }
        return steps[currentIndex]
    }

    private var highlightFrame: CGRect? {
        guard let step = activeStep else { return nil }
        return targets[step.target]
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .topLeading) {
                dimmingLayer(in: proxy.size)
                    .opacity(isVisible ? 1 : 0)
                    .scaleEffect(isVisible ? 1 : 1.01)
                    .animation(.easeInOut(duration: 0.25), value: isVisible)

                if let step = activeStep {
                    if let frame = highlightFrame {
                        highlight(for: step, frame: frame)
                        connector(for: step, in: proxy.size, frame: frame)
                        callout(for: step, in: proxy.size, frame: frame)
                    } else {
                        callout(for: step, in: proxy.size, frame: CGRect(origin: .zero, size: proxy.size))
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.easeInOut(duration: 0.25)) {
                isVisible = true
            }
        }
    }

    private func dimmingLayer(in size: CGSize) -> some View {
        Canvas { context, canvasSize in
            var path = Path(CGRect(origin: .zero, size: canvasSize))
            if let frame = highlightFrame, let step = activeStep {
                let padded = frame.insetBy(dx: -step.padding, dy: -step.padding)
                path.addRoundedRect(in: padded, cornerSize: CGSize(width: step.cornerRadius, height: step.cornerRadius))
            }
            context.fill(path, with: .color(Color.black.opacity(0.28)), style: FillStyle(eoFill: true))
        }
        .allowsHitTesting(false)
    }

    private func highlight(for step: TutorialStep, frame: CGRect) -> some View {
        let padded = frame.insetBy(dx: -step.padding, dy: -step.padding)

        return RoundedRectangle(cornerRadius: step.cornerRadius, style: .continuous)
            .stroke(Color.white.opacity(0.85), lineWidth: 1.6)
            .background(
                RoundedRectangle(cornerRadius: step.cornerRadius, style: .continuous)
                    .fill(Color.white.opacity(0.08))
            )
            .frame(width: padded.width, height: padded.height)
            .position(x: padded.midX, y: padded.midY)
            .shadow(color: Color.accentColor.opacity(0.35), radius: 12, x: 0, y: 8)
            .animation(.spring(response: 0.42, dampingFraction: 0.85), value: currentIndex)
            .allowsHitTesting(false)
    }

    private func connector(for step: TutorialStep, in size: CGSize, frame: CGRect) -> some View {
        let calloutAnchor = calloutOrigin(for: step, in: size, frame: frame)
        let target = CGPoint(x: frame.midX, y: frame.midY)
        let control = CGPoint(
            x: (calloutAnchor.x + target.x) / 2,
            y: min(calloutAnchor.y, target.y) - 24
        )

        return Path { path in
            path.move(to: calloutAnchor)
            path.addQuadCurve(to: target, control: control)
        }
        .stroke(style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round, dash: [2, 8]))
        .fill(Color.white.opacity(0.6))
        .animation(.easeInOut(duration: 0.28), value: currentIndex)
        .allowsHitTesting(false)
    }

    private func callout(for step: TutorialStep, in size: CGSize, frame: CGRect) -> some View {
        let maxWidth: CGFloat = 360
        let origin = calloutOrigin(for: step, in: size, frame: frame)

        return VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(step.title)
                    .font(.title3.weight(.semibold))
                Text(step.message)
                    .font(.body)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 12) {
                if currentIndex > 0 {
                    Button(action: goBack) {
                        Label("Назад", systemImage: "chevron.left")
                    }
                }

                Button(action: goNext) {
                    Label(nextLabel, systemImage: nextIcon)
                }

                Spacer()

                Button(role: .cancel, action: onClose) {
                    Label("Закрыть", systemImage: "xmark")
                }
                .labelStyle(.iconOnly)
            }
        }
        .padding(16)
        .frame(maxWidth: maxWidth, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.white.opacity(0.28), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.35), radius: 18, x: 0, y: 14)
        .position(origin)
        .animation(.spring(response: 0.42, dampingFraction: 0.85), value: currentIndex)
    }

    private var nextLabel: String {
        currentIndex == steps.count - 1 ? "Готово" : "Далее"
    }

    private var nextIcon: String {
        currentIndex == steps.count - 1 ? "checkmark" : "chevron.right"
    }

    private func calloutOrigin(for step: TutorialStep, in size: CGSize, frame: CGRect) -> CGPoint {
        let padding: CGFloat = 22
        let tentative: CGPoint

        switch step.calloutPosition {
        case .top:
            tentative = CGPoint(x: frame.midX, y: frame.minY - 120)
        case .bottom:
            tentative = CGPoint(x: frame.midX, y: frame.maxY + 120)
        case .leading:
            tentative = CGPoint(x: frame.minX - 220, y: frame.midY)
        case .trailing:
            tentative = CGPoint(x: frame.maxX + 220, y: frame.midY)
        }

        let clampedX = min(max(tentative.x, padding), size.width - padding)
        let clampedY = min(max(tentative.y, padding), size.height - padding)

        return CGPoint(x: clampedX, y: clampedY)
    }

    private func goNext() {
        if currentIndex >= steps.count - 1 {
            onClose()
        } else {
            withAnimation(.spring(response: 0.42, dampingFraction: 0.85)) {
                currentIndex = min(currentIndex + 1, steps.count - 1)
            }
        }
    }

    private func goBack() {
        withAnimation(.spring(response: 0.42, dampingFraction: 0.85)) {
            currentIndex = max(currentIndex - 1, 0)
        }
    }
}
