import SwiftUI

struct TutorialOverlayView: View {
    @ObservedObject private var overlay = OverlayModel.shared
    let screenFrame: CGRect

    @State private var isVisible = false

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .topLeading) {
                spotlightLayer(in: proxy)

                if let step = overlay.activeTutorialStep {
                    connector(for: step, in: proxy)
                    callout(for: step, in: proxy)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .onTapGesture { } // захватываем клики, чтобы фон не пропускал к окнам под оверлеем
            .onAppear {
                withAnimation(.easeInOut(duration: 0.25)) {
                    isVisible = true
                }
            }
        }
    }

    private func spotlightLayer(in proxy: GeometryProxy) -> some View {
        let targetRect = localRect(for: overlay.activeTutorialStep?.targetFrameInScreenSpace ?? .zero)
        return SpotlightShape(highlight: targetRect, radius: 14)
            .fill(Color.black.opacity(0.55), style: FillStyle(eoFill: true))
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 0.28), value: overlay.activeTutorialStepIndex)
            .opacity(isVisible ? 1 : 0)
    }

    private func connector(for step: OverlayModel.TutorialStep, in proxy: GeometryProxy) -> some View {
        let highlight = localRect(for: step.targetFrameInScreenSpace)
        let cardSize = CGSize(width: 320, height: 170)
        let calloutRect = clampedCalloutRect(for: step, highlight: highlight, canvas: proxy.size, size: cardSize)
        let start = connectorStart(for: calloutRect, position: step.calloutPosition)
        let end = CGPoint(x: highlight.midX, y: highlight.midY)

        return ConnectorShape(start: start, end: end)
            .stroke(Color.white.opacity(0.85), style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
            .overlay(
                ArrowHead(end: end, start: start)
                    .fill(Color.white.opacity(0.9))
            )
            .animation(.easeInOut(duration: 0.25), value: overlay.activeTutorialStepIndex)
    }

    private func callout(for step: OverlayModel.TutorialStep, in proxy: GeometryProxy) -> some View {
        let highlight = localRect(for: step.targetFrameInScreenSpace)
        let cardSize = CGSize(width: 320, height: 170)
        let calloutRect = clampedCalloutRect(for: step, highlight: highlight, canvas: proxy.size, size: cardSize)

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(step.title)
                    .font(.system(size: 17, weight: .semibold))
                Spacer()
                Button("Завершить") { overlay.hideTutorial() }
                    .buttonStyle(.borderless)
            }

            Text(step.description)
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer()

            HStack {
                Button("Назад") { overlay.previousTutorialStep() }
                    .disabled(overlay.activeTutorialStepIndex == 0)
                Spacer()
                Button(overlay.activeTutorialStepIndex == overlay.tutorialSteps.count - 1 ? "Готово" : "Далее") {
                    overlay.nextTutorialStep()
                }
                .keyboardShortcut(.return, modifiers: [])
            }
        }
        .padding(16)
        .frame(width: cardSize.width, height: cardSize.height, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.3), radius: 12, x: 0, y: 8)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.18), lineWidth: 1)
        )
        .position(x: calloutRect.midX, y: calloutRect.midY)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: overlay.activeTutorialStepIndex)
    }

    private func localRect(for rect: CGRect) -> CGRect {
        guard !rect.isEmpty else { return .zero }
        // Приводим screen-space AppKit (origin внизу) в локальные координаты SwiftUI (origin вверху).
        let localX = rect.minX - screenFrame.minX
        let localY = screenFrame.maxY - rect.maxY

        return CGRect(x: localX, y: localY, width: rect.width, height: rect.height)
    }

    private func clampedCalloutRect(for step: OverlayModel.TutorialStep, highlight: CGRect, canvas: CGSize, size: CGSize) -> CGRect {
        var origin = CGPoint(x: highlight.midX - size.width / 2, y: highlight.midY - size.height / 2)

        switch step.calloutPosition {
        case .above:
            origin = CGPoint(x: highlight.midX - size.width / 2, y: highlight.maxY + 32)
        case .below:
            origin = CGPoint(x: highlight.midX - size.width / 2, y: highlight.minY - size.height - 32)
        case .leading:
            origin = CGPoint(x: highlight.minX - size.width - 32, y: highlight.midY - size.height / 2)
        case .trailing:
            origin = CGPoint(x: highlight.maxX + 32, y: highlight.midY - size.height / 2)
        }

        let clampedX = min(max(origin.x, 24), canvas.width - size.width - 24)
        let clampedY = min(max(origin.y, 24), canvas.height - size.height - 24)
        return CGRect(origin: CGPoint(x: clampedX, y: clampedY), size: size)
    }

    private func connectorStart(for callout: CGRect, position: OverlayModel.CalloutPosition) -> CGPoint {
        switch position {
        case .above:
            return CGPoint(x: callout.midX, y: callout.minY)
        case .below:
            return CGPoint(x: callout.midX, y: callout.maxY)
        case .leading:
            return CGPoint(x: callout.maxX, y: callout.midY)
        case .trailing:
            return CGPoint(x: callout.minX, y: callout.midY)
        }
    }
}

private struct SpotlightShape: Shape {
    var highlight: CGRect
    var radius: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addRect(rect)
        if !highlight.isEmpty {
            path.addRoundedRect(in: highlight, cornerSize: CGSize(width: radius, height: radius))
        }
        return path
    }
}

private struct ConnectorShape: Shape {
    var start: CGPoint
    var end: CGPoint

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let control = CGPoint(x: (start.x + end.x) / 2, y: (start.y + end.y) / 2 + 30)
        path.move(to: start)
        path.addQuadCurve(to: end, control: control)
        return path
    }
}

private struct ArrowHead: Shape {
    var end: CGPoint
    var start: CGPoint

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let angle = atan2(end.y - start.y, end.x - start.x)
        let size: CGFloat = 10
        let p1 = end
        let p2 = CGPoint(x: end.x - size * cos(angle - .pi / 7), y: end.y - size * sin(angle - .pi / 7))
        let p3 = CGPoint(x: end.x - size * cos(angle + .pi / 7), y: end.y - size * sin(angle + .pi / 7))
        path.move(to: p1)
        path.addLine(to: p2)
        path.addLine(to: p3)
        path.closeSubpath()
        return path
    }
}
