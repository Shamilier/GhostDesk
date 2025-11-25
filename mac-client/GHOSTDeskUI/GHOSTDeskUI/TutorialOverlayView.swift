import SwiftUI

struct TutorialOverlayView: View {
    @ObservedObject var model: OverlayModel
    @State private var appeared = false
    @State private var measuredCalloutSize: CGSize = CGSize(width: 380, height: 220)

    init(model: OverlayModel) {
        _model = ObservedObject(initialValue: model)
    }

    private var activeStep: OverlayModel.TutorialStep? { model.activeTutorialStep }

    private var paddedTarget: CGRect? {
        guard let step = activeStep else { return nil }
        return step.targetFrameInScreenSpace.insetBy(dx: -14, dy: -14)
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .topTrailing) {
                dimmingLayer(size: proxy.size)
                    .opacity(appeared ? 1 : 0)
                    .animation(.easeInOut(duration: 0.35), value: appeared)

                if let step = activeStep {
                    spotlight(for: step)
                    connector(for: step, in: proxy.size)
                    callout(for: step, in: proxy.size)
                }

                closeButton
                    .padding(.trailing, 18)
                    .padding(.top, 18)
            }
            .ignoresSafeArea()
            .onAppear {
                withAnimation(.easeInOut(duration: 0.35)) {
                    appeared = true
                }
            }
        }
    }

    // MARK: - Layers

    private func dimmingLayer(size: CGSize) -> some View {
        Canvas { context, canvasSize in
            var path = Path(CGRect(origin: .zero, size: canvasSize))
            if let cutout = paddedTarget {
                path.addRoundedRect(in: cutout, cornerSize: CGSize(width: 18, height: 18))
            }
            context.fill(path, with: .color(Color.black.opacity(0.64)), style: FillStyle(eoFill: true))
        }
        .overlay(
            LinearGradient(colors: [Color.white.opacity(0.08), .clear], startPoint: .top, endPoint: .bottom)
                .allowsHitTesting(false)
        )
    }

    private func spotlight(for step: OverlayModel.TutorialStep) -> some View {
        let target = paddedTarget ?? step.targetFrameInScreenSpace
        return RoundedRectangle(cornerRadius: 22, style: .continuous)
            .stroke(Color.white.opacity(0.9), lineWidth: 2)
            .shadow(color: Color.white.opacity(0.25), radius: 14)
            .frame(width: target.width, height: target.height)
            .position(x: target.midX, y: target.midY)
            .animation(.easeInOut(duration: 0.28), value: step.id)
            .allowsHitTesting(false)
    }

    private func connector(for step: OverlayModel.TutorialStep, in canvasSize: CGSize) -> some View {
        guard let target = paddedTarget else { return AnyView(EmptyView()) }
        let calloutFrame = calloutFrame(for: step, in: canvasSize)
        let start = CGPoint(x: target.midX, y: target.midY)
        let end = calloutAnchor(for: calloutFrame, relativeTo: target)
        let control = CGPoint(
            x: (start.x + end.x) / 2,
            y: start.y > end.y ? min(start.y, end.y) - 60 : max(start.y, end.y) + 60
        )

        let path = Path { path in
            path.move(to: start)
            path.addQuadCurve(to: end, control: control)
        }

        return AnyView(
            path
                .stroke(Color.accentColor.opacity(0.75), style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [6, 8]))
                .shadow(color: Color.accentColor.opacity(0.45), radius: 8)
                .overlay(arrowHead(at: end, towards: start))
                .animation(.easeInOut(duration: 0.28), value: step.id)
                .allowsHitTesting(false)
        )
    }

    private func callout(for step: OverlayModel.TutorialStep, in size: CGSize) -> some View {
        let frame = calloutFrame(for: step, in: size)

        return VStack(alignment: .leading, spacing: 14) {
            Text(step.title)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)
            Text(step.description)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Divider().overlay(Color.white.opacity(0.12))

            HStack(spacing: 10) {
                Button(action: model.goToPreviousTutorialStep) {
                    Label("Назад", systemImage: "arrow.left")
                        .font(.headline)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 14)
                        .frame(minWidth: 110)
                }
                .buttonStyle(.borderedProminent)
                .tint(.white.opacity(0.16))
                .foregroundStyle(.white)
                .disabled(model.activeTutorialStepIndex == 0)

                Spacer()

                Button(action: model.goToNextTutorialStep) {
                    Label(model.activeTutorialStepIndex == model.tutorialSteps.count - 1 ? "Завершить" : "Далее", systemImage: model.activeTutorialStepIndex == model.tutorialSteps.count - 1 ? "checkmark" : "arrow.right")
                        .font(.headline)
                        .padding(.vertical, 12)
                        .padding(.horizontal, 16)
                        .frame(minWidth: 150)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.accentColor)
            }
        }
        .padding(20)
        .frame(width: frame.width, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.35), radius: 18, x: 0, y: 10)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
        .overlay(
            GeometryReader { geo in
                Color.clear
                    .onAppear { measuredCalloutSize = geo.size }
                    .onChange(of: geo.size) { newValue in measuredCalloutSize = newValue }
            }
        )
        .position(x: frame.midX, y: frame.midY)
        .animation(.spring(response: 0.5, dampingFraction: 0.85), value: step.id)
    }

    private var closeButton: some View {
        Button(action: model.finishTutorial) {
            Label("Закрыть обучение", systemImage: "xmark")
                .font(.headline.weight(.semibold))
                .padding(.vertical, 10)
                .padding(.horizontal, 14)
                .background(
                    Capsule()
                        .fill(.ultraThinMaterial)
                        .shadow(color: .black.opacity(0.3), radius: 12, x: 0, y: 6)
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Geometry helpers

    private func calloutFrame(for step: OverlayModel.TutorialStep, in canvasSize: CGSize) -> CGRect {
        let width = min(canvasSize.width - 48, 420)
        let height = measuredCalloutSize.height
        var origin = CGPoint(x: step.targetFrameInScreenSpace.midX - width / 2, y: step.targetFrameInScreenSpace.maxY + 28)

        switch step.calloutPosition {
        case .above:
            origin.y = step.targetFrameInScreenSpace.minY - height - 28
        case .below:
            origin.y = step.targetFrameInScreenSpace.maxY + 28
        case .leading:
            origin.x = step.targetFrameInScreenSpace.minX - width - 28
            origin.y = step.targetFrameInScreenSpace.midY - height / 2
        case .trailing:
            origin.x = step.targetFrameInScreenSpace.maxX + 28
            origin.y = step.targetFrameInScreenSpace.midY - height / 2
        case .automatic:
            let spaceAbove = step.targetFrameInScreenSpace.minY
            let spaceBelow = canvasSize.height - step.targetFrameInScreenSpace.maxY
            origin.y = spaceAbove > spaceBelow ? (step.targetFrameInScreenSpace.minY - height - 24) : (step.targetFrameInScreenSpace.maxY + 24)
        }

        let clampedX = min(max(origin.x, 24), canvasSize.width - width - 24)
        let clampedY = min(max(origin.y, 24), canvasSize.height - height - 24)

        return CGRect(origin: CGPoint(x: clampedX, y: clampedY), size: CGSize(width: width, height: height))
    }

    private func calloutAnchor(for frame: CGRect, relativeTo target: CGRect) -> CGPoint {
        if frame.midY > target.midY {
            return CGPoint(x: frame.midX, y: frame.minY)
        } else {
            return CGPoint(x: frame.midX, y: frame.maxY)
        }
    }

    private func arrowHead(at point: CGPoint, towards target: CGPoint) -> some View {
        let angle = atan2(target.y - point.y, target.x - point.x)
        let size: CGFloat = 10
        let path = Path { p in
            p.move(to: point)
            p.addLine(to: CGPoint(x: point.x + cos(angle + .pi / 6) * size, y: point.y + sin(angle + .pi / 6) * size))
            p.addLine(to: CGPoint(x: point.x + cos(angle - .pi / 6) * size, y: point.y + sin(angle - .pi / 6) * size))
            p.addLine(to: point)
        }
        return path.fill(Color.accentColor.opacity(0.8))
    }
}
