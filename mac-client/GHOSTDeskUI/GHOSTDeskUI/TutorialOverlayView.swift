import SwiftUI

struct TutorialOverlayView: View {
    @ObservedObject private var overlay = OverlayModel.shared
    let screenFrame: CGRect

    @State private var isVisible = false
    private let calloutSize = CGSize(width: 340, height: 210)
    // Измените значение ниже, чтобы регулировать степень затемнения фона обучения (1.0 = полностью чёрный).
    private let dimOpacity: Double = 0.75

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .topLeading) {
                spotlightLayer(in: proxy)

                if let step = overlay.activeTutorialStep, overlay.isCalloutReady(for: step.id) {
                    connector(for: step, in: proxy)
                    callout(for: step, in: proxy)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .onTapGesture { } // захватываем клики, чтобы фон не пропускал к окнам под оверлеем
            .onAppear {
                withAnimation(.easeOut(duration: 0.28)) {
                    isVisible = true
                }
            }
        }
    }

    private func spotlightLayer(in proxy: GeometryProxy) -> some View {
        let hasReadyCallout = overlay.isCalloutReady(for: overlay.activeTutorialStep?.id)
        let targetRect = hasReadyCallout ? localRect(for: overlay.activeTutorialStep?.targetFrameInScreenSpace ?? .zero) : .zero

        return ZStack {
            Color.black.opacity(dimOpacity)
                .ignoresSafeArea()
                .opacity(isVisible ? 1 : 0)
                .animation(.easeOut(duration: 0.28), value: isVisible)

            if overlay.activeTutorialStep != nil, !targetRect.isEmpty {
                highlightView(rect: targetRect)
            }
        }
    }

    private func highlightView(rect: CGRect) -> some View {
        let accent = Color.accentColor
        let glowColor = accent.opacity(0.9)
        let cornerRadius: CGFloat = 12

        return RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .inset(by: -4)
            .strokeBorder(accent.opacity(0.95), lineWidth: 2)
            .shadow(color: glowColor, radius: 14, x: 0, y: 0)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(
                        RadialGradient(
                            gradient: Gradient(colors: [accent.opacity(0.9), accent.opacity(0.5)]),
                            center: .center,
                            startRadius: 4,
                            endRadius: max(rect.width, rect.height) * 0.75
                        )
                    )
                    .blendMode(.screen)
            )
            .frame(width: rect.width, height: rect.height)
            .position(x: rect.midX, y: rect.midY)
            .scaleEffect(isVisible ? 1 : 0.96)
            .opacity(isVisible ? 1 : 0)
            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: isVisible)
            .animation(.spring(response: 0.4, dampingFraction: 0.85), value: overlay.activeTutorialStepIndex)
    }

    private func connector(for step: OverlayModel.TutorialStep, in proxy: GeometryProxy) -> some View {
        let layout = calloutLayout(for: step, canvas: proxy.size)
        let start = connectorStart(for: layout.rect, position: layout.position)
        let end = connectorEnd(from: start, to: layout.highlight)

        let connectorColor = Color.white.opacity(0.92)

        return ConnectorShape(start: start, end: end)
            .stroke(connectorColor, style: StrokeStyle(lineWidth: 2.4, lineCap: .round, lineJoin: .round))
            .shadow(color: .black.opacity(0.35), radius: 4, x: 0, y: 2)
            .overlay(
                ArrowHead(end: end, start: start)
                    .fill(connectorColor)
                    .shadow(color: .black.opacity(0.4), radius: 4, x: 0, y: 2)
            )
            .animation(.spring(response: 0.4, dampingFraction: 0.85), value: overlay.activeTutorialStepIndex)
            .zIndex(1)
    }

    private func callout(for step: OverlayModel.TutorialStep, in proxy: GeometryProxy) -> some View {
        let layout = calloutLayout(for: step, canvas: proxy.size)

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

            Spacer(minLength: 4)

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
        .frame(width: calloutSize.width, minHeight: calloutSize.height, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.3), radius: 12, x: 0, y: 8)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.18), lineWidth: 1)
        )
        .position(x: layout.rect.midX, y: layout.rect.midY)
        .id(step.id)
        .transition(
            .asymmetric(
                insertion: .scale(scale: 0.96).combined(with: .opacity),
                removal: .opacity
            )
        )
        .animation(.spring(response: 0.34, dampingFraction: 0.85), value: overlay.activeTutorialStepIndex)
        .zIndex(2)
    }

    private func localRect(for rect: CGRect) -> CGRect {
        guard !rect.isEmpty else { return .zero }
        // Приводим screen-space AppKit (origin внизу) в локальные координаты SwiftUI (origin вверху).
        let localX = rect.minX - screenFrame.minX
        let localY = screenFrame.maxY - rect.maxY

        return CGRect(x: localX, y: localY, width: rect.width, height: rect.height)
    }

    private func calloutLayout(for step: OverlayModel.TutorialStep, canvas: CGSize) -> CalloutLayout {
        let highlight = localRect(for: step.targetFrameInScreenSpace)
        let obstacles = obstacleLocalRects()
        let paddedObstacles = inflate(obstacles, by: obstaclePadding)
        let best = bestCalloutRect(
            for: step,
            highlight: highlight,
            canvas: canvas,
            size: calloutSize,
            obstacles: paddedObstacles
        )
        return CalloutLayout(rect: best.rect, position: best.position, highlight: highlight)
    }

    private func obstacleLocalRects() -> [CGRect] {
        overlay.tutorialObstacles.activeFramesInScreen.map(localRect(for:))
    }

    private var obstaclePadding: CGFloat { 14 }

    private func bestCalloutRect(
        for step: OverlayModel.TutorialStep,
        highlight: CGRect,
        canvas: CGSize,
        size: CGSize,
        obstacles: [CGRect]
    ) -> (rect: CGRect, position: OverlayModel.CalloutPosition) {
        let baseOrder: [OverlayModel.CalloutPosition]
        if step.anchorID == .listenRecordingControls {
            baseOrder = [.trailing, .leading]
        } else {
            baseOrder = [.above, .below, .leading, .trailing]
        }

        var candidates: [OverlayModel.CalloutPosition] = []
        if baseOrder.contains(step.calloutPosition) {
            candidates.append(step.calloutPosition)
        }
        candidates.append(contentsOf: baseOrder.filter { !candidates.contains($0) })

        var best: (rect: CGRect, position: OverlayModel.CalloutPosition, overlap: CGFloat)?

        for position in candidates {
            let ideal = calloutRect(for: position, highlight: highlight, size: size)
            let clamped = clampedCalloutRect(ideal, canvas: canvas)
            let adjusted = offsetRect(clamped, avoiding: obstacles, canvas: canvas)
            let overlap = overlapArea(of: adjusted, with: obstacles)

            if overlap == 0 { return (adjusted, position) }

            if let currentBest = best {
                if overlap < currentBest.overlap {
                    best = (adjusted, position, overlap)
                }
            } else {
                best = (adjusted, position, overlap)
            }
        }

        if let best { return (best.rect, best.position) }

        let fallbackPosition: OverlayModel.CalloutPosition
        if let firstAllowed = baseOrder.first {
            fallbackPosition = firstAllowed
        } else {
            fallbackPosition = step.calloutPosition
        }

        let fallback = clampedCalloutRect(calloutRect(for: fallbackPosition, highlight: highlight, size: size), canvas: canvas)
        let adjustedFallback = offsetRect(fallback, avoiding: obstacles, canvas: canvas)
        return (adjustedFallback, fallbackPosition)
    }

    private func calloutRect(for position: OverlayModel.CalloutPosition, highlight: CGRect, size: CGSize) -> CGRect {
        var origin = CGPoint(x: highlight.midX - size.width / 2, y: highlight.midY - size.height / 2)

        switch position {
        case .above:
            origin = CGPoint(x: highlight.midX - size.width / 2, y: highlight.maxY + 32)
        case .below:
            origin = CGPoint(x: highlight.midX - size.width / 2, y: highlight.minY - size.height - 32)
        case .leading:
            origin = CGPoint(x: highlight.minX - size.width - 32, y: highlight.midY - size.height / 2)
        case .trailing:
            origin = CGPoint(x: highlight.maxX + 32, y: highlight.midY - size.height / 2)
        }

        return CGRect(origin: origin, size: size)
    }

    private func clampedCalloutRect(_ rect: CGRect, canvas: CGSize) -> CGRect {
        let clampedX = min(max(rect.origin.x, 24), canvas.width - rect.width - 24)
        let clampedY = min(max(rect.origin.y, 24), canvas.height - rect.height - 24)
        return CGRect(origin: CGPoint(x: clampedX, y: clampedY), size: rect.size)
    }

    private func offsetRect(_ rect: CGRect, avoiding obstacles: [CGRect], canvas: CGSize) -> CGRect {
        guard !obstacles.isEmpty else { return rect }

        var adjusted = rect
        let bounds = CGRect(x: 24, y: 24, width: canvas.width - 48, height: canvas.height - 48)

        for obstacle in obstacles {
            guard adjusted.intersects(obstacle) else { continue }

            let moveLeft = obstacle.minX - adjusted.maxX
            let moveRight = obstacle.maxX - adjusted.minX
            let moveUp = obstacle.minY - adjusted.maxY
            let moveDown = obstacle.maxY - adjusted.minY

            let candidates: [CGPoint] = [
                CGPoint(x: moveLeft, y: 0),
                CGPoint(x: moveRight, y: 0),
                CGPoint(x: 0, y: moveUp),
                CGPoint(x: 0, y: moveDown)
            ]

            var bestTranslation: CGPoint?

            for translation in candidates {
                let shifted = adjusted.offsetBy(dx: translation.x, dy: translation.y)
                let clamped = clamp(shifted, within: bounds)

                guard !clamped.intersects(obstacle) else { continue }

                if let current = bestTranslation {
                    if abs(translation.x) + abs(translation.y) < abs(current.x) + abs(current.y) {
                        bestTranslation = translation
                    }
                } else {
                    bestTranslation = translation
                }
            }

            if let translation = bestTranslation {
                adjusted = adjusted.offsetBy(dx: translation.x, dy: translation.y)
                adjusted = clamp(adjusted, within: bounds)
            }
        }

        return adjusted
    }

    private func clamp(_ rect: CGRect, within bounds: CGRect) -> CGRect {
        let clampedX = min(max(rect.origin.x, bounds.minX), bounds.maxX - rect.width)
        let clampedY = min(max(rect.origin.y, bounds.minY), bounds.maxY - rect.height)
        return CGRect(origin: CGPoint(x: clampedX, y: clampedY), size: rect.size)
    }

    private func inflate(_ rects: [CGRect], by padding: CGFloat) -> [CGRect] {
        rects.map { $0.insetBy(dx: -padding, dy: -padding) }
    }

    private func overlapArea(of rect: CGRect, with obstacles: [CGRect]) -> CGFloat {
        obstacles.reduce(0) { partialResult, obstacle in
            partialResult + overlapArea(rect, obstacle)
        }
    }

    private func overlapArea(_ lhs: CGRect, _ rhs: CGRect) -> CGFloat {
        let intersection = lhs.intersection(rhs)
        guard !intersection.isNull, !intersection.isEmpty else { return 0 }
        return intersection.width * intersection.height
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

    private func connectorEnd(from start: CGPoint, to highlight: CGRect) -> CGPoint {
        guard !highlight.isEmpty else { return start }

        let center = CGPoint(x: highlight.midX, y: highlight.midY)
        let dx = center.x - start.x
        let dy = center.y - start.y

        guard dx != 0 || dy != 0 else { return center }

        var intersections: [CGPoint] = []

        if dx != 0 {
            let tMinX = (highlight.minX - start.x) / dx
            let yAtMinX = start.y + tMinX * dy
            if tMinX >= 0, tMinX <= 1, yAtMinX >= highlight.minY, yAtMinX <= highlight.maxY {
                intersections.append(CGPoint(x: highlight.minX, y: yAtMinX))
            }

            let tMaxX = (highlight.maxX - start.x) / dx
            let yAtMaxX = start.y + tMaxX * dy
            if tMaxX >= 0, tMaxX <= 1, yAtMaxX >= highlight.minY, yAtMaxX <= highlight.maxY {
                intersections.append(CGPoint(x: highlight.maxX, y: yAtMaxX))
            }
        }

        if dy != 0 {
            let tMinY = (highlight.minY - start.y) / dy
            let xAtMinY = start.x + tMinY * dx
            if tMinY >= 0, tMinY <= 1, xAtMinY >= highlight.minX, xAtMinY <= highlight.maxX {
                intersections.append(CGPoint(x: xAtMinY, y: highlight.minY))
            }

            let tMaxY = (highlight.maxY - start.y) / dy
            let xAtMaxY = start.x + tMaxY * dx
            if tMaxY >= 0, tMaxY <= 1, xAtMaxY >= highlight.minX, xAtMaxY <= highlight.maxX {
                intersections.append(CGPoint(x: xAtMaxY, y: highlight.maxY))
            }
        }

        guard let nearest = intersections.min(by: { lhs, rhs in
            let lhsDistance = hypot(lhs.x - start.x, lhs.y - start.y)
            let rhsDistance = hypot(rhs.x - start.x, rhs.y - start.y)
            return lhsDistance < rhsDistance
        }) else {
            return center
        }

        let pullback: CGFloat = 8
        let vector = CGVector(dx: nearest.x - start.x, dy: nearest.y - start.y)
        let length = hypot(vector.dx, vector.dy)

        guard length > 0 else { return nearest }

        let scale = max((length - pullback) / length, 0)
        return CGPoint(x: start.x + vector.dx * scale, y: start.y + vector.dy * scale)
    }
}

private struct CalloutLayout {
    let rect: CGRect
    let position: OverlayModel.CalloutPosition
    let highlight: CGRect
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
