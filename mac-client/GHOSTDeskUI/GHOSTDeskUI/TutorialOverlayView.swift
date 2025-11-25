import SwiftUI

struct TutorialStep: Identifiable {
    enum CalloutPlacement {
        case top, bottom, leading, trailing
    }

    let id = UUID()
    let target: OnboardingTarget
    let title: String
    let message: String
    let placement: CalloutPlacement
    var highlightPadding: CGFloat = 12
}

struct TutorialOverlayView: View {
    var steps: [TutorialStep]
    var targets: [OnboardingTarget: CGRect]
    @Binding var currentStepIndex: Int
    var onClose: () -> Void

    @State private var isVisible = false

    private var step: TutorialStep { steps[safe: currentStepIndex] ?? steps[0] }
    private var highlightFrame: CGRect? {
        targets[step.target]
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .center) {
                backdropLayer(in: proxy.size)

                if let frame = highlightFrame {
                    highlight(for: frame)
                    focusArrow(for: frame, in: proxy.size)
                    callout(for: frame, in: proxy.size)
                } else {
                    callout(CGRect(origin: .zero, size: proxy.size), proxy.size)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .opacity(isVisible ? 1 : 0)
            .scaleEffect(isVisible ? 1 : 0.98)
            .animation(.easeInOut(duration: 0.28), value: isVisible)
            .animation(.easeInOut(duration: 0.32), value: currentStepIndex)
            .ignoresSafeArea()
            .onAppear {
                withAnimation { isVisible = true }
            }
            .onDisappear { isVisible = false }
        }
    }

    private func backdropLayer(in size: CGSize) -> some View {
        ZStack {
            Color.black.opacity(0.35)
                .ignoresSafeArea()
                .mask(dimmedMask(in: size))
                .blur(radius: 0.5)

            LinearGradient(colors: [.white.opacity(0.08), .clear], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
                .allowsHitTesting(false)
        }
    }

    private func dimmedMask(in size: CGSize) -> some View {
        Canvas { context, canvasSize in
            var path = Path(CGRect(origin: .zero, size: canvasSize))
            if let frame = highlightFrame?.insetBy(dx: -step.highlightPadding, dy: -step.highlightPadding) {
                path.addRoundedRect(in: frame, cornerSize: CGSize(width: 20, height: 20))
            }
            context.fill(path, with: .color(.black), style: FillStyle(eoFill: true))
        }
    }

    private func highlight(for frame: CGRect) -> some View {
        let padded = frame.insetBy(dx: -step.highlightPadding, dy: -step.highlightPadding)
        return RoundedRectangle(cornerRadius: 18, style: .continuous)
            .stroke(Color.white.opacity(0.9), lineWidth: 1.5)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.white.opacity(0.08))
                    .shadow(color: Color.black.opacity(0.24), radius: 16)
            )
            .frame(width: padded.width, height: padded.height)
            .position(x: padded.midX, y: padded.midY)
            .animation(.easeInOut(duration: 0.3), value: highlightFrame)
            .allowsHitTesting(false)
    }

    private func focusArrow(for frame: CGRect, in size: CGSize) -> some View {
        let start = anchorPoint(for: frame)
        let end = calloutAnchor(for: frame, in: size)
        let control = CGPoint(x: (start.x + end.x) / 2, y: (start.y + end.y) / 2 - 26)
        let arrowHead = arrowHeadPoints(tip: end, from: start)

        return ZStack {
            Path { path in
                path.move(to: start)
                path.addQuadCurve(to: end, control: control)
            }
            .stroke(Color.white.opacity(0.85), style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
            .shadow(color: Color.black.opacity(0.25), radius: 12)

            Path { path in
                path.move(to: arrowHead.tip)
                path.addLine(to: arrowHead.left)
                path.addLine(to: arrowHead.right)
                path.closeSubpath()
            }
            .fill(Color.white.opacity(0.92))
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.86), value: currentStepIndex)
        .allowsHitTesting(false)
    }

    private func callout(_ frame: CGRect, _ size: CGSize) -> some View {
        callout(for: frame, in: size)
    }

    private func callout(for frame: CGRect, in size: CGSize) -> some View {
        let position = calloutAnchor(for: frame, in: size)

        return VStack(alignment: .leading, spacing: 12) {
            Text(step.title)
                .font(.headline.weight(.semibold))
                .foregroundStyle(.white)
            Text(step.message)
                .font(.body)
                .foregroundStyle(.white.opacity(0.9))
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 12) {
                Button(action: moveBack) {
                    Label("Назад", systemImage: "chevron.backward")
                        .labelStyle(.titleAndIcon)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(Color.white.opacity(0.12)))
                }
                .buttonStyle(.plain)
                .disabled(currentStepIndex == 0)
                .opacity(currentStepIndex == 0 ? 0.6 : 1)

                Button(action: moveForward) {
                    Label(currentStepIndex == steps.count - 1 ? "Готово" : "Далее", systemImage: "chevron.forward")
                        .labelStyle(.titleAndIcon)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(Capsule().fill(Color.white.opacity(0.92)))
                        .foregroundStyle(.black)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(18)
        .frame(maxWidth: 360, alignment: .leading)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: .black.opacity(0.45), radius: 18, x: 0, y: 14)
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.35), lineWidth: 1)
        )
        .position(position)
        .animation(.spring(response: 0.5, dampingFraction: 0.88), value: currentStepIndex)
    }

    private func anchorPoint(for frame: CGRect) -> CGPoint {
        switch step.placement {
        case .top: return CGPoint(x: frame.midX, y: frame.minY - step.highlightPadding)
        case .bottom: return CGPoint(x: frame.midX, y: frame.maxY + step.highlightPadding)
        case .leading: return CGPoint(x: frame.minX - step.highlightPadding, y: frame.midY)
        case .trailing: return CGPoint(x: frame.maxX + step.highlightPadding, y: frame.midY)
        }
    }

    private func calloutAnchor(for frame: CGRect, in size: CGSize) -> CGPoint {
        let calloutSize = CGSize(width: min(size.width - 64, 380), height: 160)
        let clampX = { (x: CGFloat) in min(max(x, calloutSize.width / 2 + 16), size.width - calloutSize.width / 2 - 16) }
        let clampY = { (y: CGFloat) in min(max(y, calloutSize.height / 2 + 16), size.height - calloutSize.height / 2 - 16) }

        switch step.placement {
        case .top:
            return CGPoint(x: clampX(frame.midX), y: clampY(frame.minY - calloutSize.height / 2 - 32))
        case .bottom:
            return CGPoint(x: clampX(frame.midX), y: clampY(frame.maxY + calloutSize.height / 2 + 32))
        case .leading:
            return CGPoint(x: clampX(frame.minX - calloutSize.width / 2 - 32), y: clampY(frame.midY))
        case .trailing:
            return CGPoint(x: clampX(frame.maxX + calloutSize.width / 2 + 32), y: clampY(frame.midY))
        }
    }

    private func arrowHeadPoints(tip: CGPoint, from start: CGPoint) -> (tip: CGPoint, left: CGPoint, right: CGPoint) {
        let angle = atan2(tip.y - start.y, tip.x - start.x)
        let length: CGFloat = 12
        let spread: CGFloat = .pi / 7
        let left = CGPoint(x: tip.x - length * cos(angle - spread), y: tip.y - length * sin(angle - spread))
        let right = CGPoint(x: tip.x - length * cos(angle + spread), y: tip.y - length * sin(angle + spread))
        return (tip, left, right)
    }

    private func moveForward() {
        if currentStepIndex < steps.count - 1 {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.88)) {
                currentStepIndex += 1
            }
        } else {
            onClose()
        }
    }

    private func moveBack() {
        guard currentStepIndex > 0 else { return }
        withAnimation(.spring(response: 0.5, dampingFraction: 0.88)) {
            currentStepIndex -= 1
        }
    }
}

private extension Collection {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
