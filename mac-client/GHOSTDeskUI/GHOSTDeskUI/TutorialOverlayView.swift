import SwiftUI

struct TutorialOverlayView: View {
    @ObservedObject var state: TutorialOverlayState
    var onClose: () -> Void

    @State private var didAppear = false

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .center) {
                overlayBackground(in: proxy.size)

                if let step = state.currentStep, let highlight = highlightFrame(for: step, canvasSize: proxy.size) {
                    highlightMask(for: highlight, padding: step.highlightPadding)
                    arrow(from: highlight, padding: step.highlightPadding, placement: step.position, canvasSize: proxy.size)
                    tooltip(for: step, highlight: highlight, canvasSize: proxy.size)
                } else {
                    fallbackTooltip(canvasSize: proxy.size)
                }

                closeButton
            }
            .ignoresSafeArea()
            .opacity(didAppear && state.isPresented ? 1 : 0)
            .scaleEffect(didAppear ? 1 : 1.01)
            .animation(.easeInOut(duration: 0.28), value: didAppear)
            .animation(.spring(response: 0.4, dampingFraction: 0.85), value: state.currentIndex)
            .onAppear { didAppear = true }
        }
    }

    private func highlightFrame(for step: TutorialStep, canvasSize: CGSize) -> CGRect? {
        guard let frame = state.targetFrames[step.target] else { return nil }
        let invertedY = canvasSize.height - frame.origin.y - frame.height
        return CGRect(x: frame.origin.x, y: invertedY, width: frame.width, height: frame.height)
    }

    private func overlayBackground(in size: CGSize) -> some View {
        let activeHighlight = state.currentStep.flatMap { highlightFrame(for: $0, canvasSize: size) }
        return ZStack {
            Canvas { context, canvasSize in
                var path = Path(CGRect(origin: .zero, size: canvasSize))
                if let highlight = activeHighlight?.insetBy(dx: -24, dy: -24) {
                    path.addRoundedRect(in: highlight, cornerSize: CGSize(width: 20, height: 20))
                }
                context.fill(path, with: .color(Color.black.opacity(0.32)), style: FillStyle(eoFill: true))
            }
            .allowsHitTesting(false)
            .blur(radius: 2)

            RadialGradient(colors: [Color.white.opacity(0.08), .clear], center: .center, startRadius: 30, endRadius: max(size.width, size.height))
                .allowsHitTesting(false)
        }
        .animation(.easeInOut(duration: 0.35), value: activeHighlight)
    }

    private func highlightMask(for frame: CGRect, padding: CGFloat) -> some View {
        let padded = frame.insetBy(dx: -padding, dy: -padding)
        return RoundedRectangle(cornerRadius: 16, style: .continuous)
            .stroke(Color.white.opacity(0.9), lineWidth: 1.5)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white.opacity(0.08))
                    .shadow(color: .black.opacity(0.45), radius: 18, x: 0, y: 12)
            )
            .frame(width: padded.width, height: padded.height)
            .position(x: padded.midX, y: padded.midY)
            .blendMode(.screen)
            .transition(.opacity)
    }

    private func arrow(from frame: CGRect, padding: CGFloat, placement: TutorialTooltipPosition, canvasSize: CGSize) -> some View {
        let padded = frame.insetBy(dx: -padding, dy: -padding)
        let start: CGPoint
        let end: CGPoint

        switch placement {
        case .top:
            start = CGPoint(x: padded.midX, y: padded.minY)
            end = CGPoint(x: padded.midX, y: max(32, padded.minY - 80))
        case .bottom:
            start = CGPoint(x: padded.midX, y: padded.maxY)
            end = CGPoint(x: padded.midX, y: min(canvasSize.height - 32, padded.maxY + 80))
        case .left:
            start = CGPoint(x: padded.minX, y: padded.midY)
            end = CGPoint(x: max(32, padded.minX - 120), y: padded.midY)
        case .right:
            start = CGPoint(x: padded.maxX, y: padded.midY)
            end = CGPoint(x: min(canvasSize.width - 32, padded.maxX + 120), y: padded.midY)
        }

        return Path { path in
            path.move(to: start)
            path.addLine(to: end)
        }
        .stroke(style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
        .foregroundStyle(LinearGradient(colors: [Color.accentColor.opacity(0.9), .white.opacity(0.85)], startPoint: .leading, endPoint: .trailing))
        .shadow(color: .black.opacity(0.25), radius: 8, x: 0, y: 10)
        .animation(.easeInOut(duration: 0.25), value: start)
        .animation(.easeInOut(duration: 0.25), value: end)
    }

    private func tooltip(for step: TutorialStep, highlight: CGRect, canvasSize: CGSize) -> some View {
        let padded = highlight.insetBy(dx: -step.highlightPadding, dy: -step.highlightPadding)
        let size = CGSize(width: 280, height: 140)
        let origin: CGPoint

        switch step.position {
        case .top:
            origin = CGPoint(x: padded.midX - size.width / 2, y: max(16, padded.minY - size.height - 16))
        case .bottom:
            origin = CGPoint(x: padded.midX - size.width / 2, y: min(canvasSize.height - size.height - 16, padded.maxY + 16))
        case .left:
            origin = CGPoint(x: max(16, padded.minX - size.width - 16), y: padded.midY - size.height / 2)
        case .right:
            origin = CGPoint(x: min(canvasSize.width - size.width - 16, padded.maxX + 16), y: padded.midY - size.height / 2)
        }

        let clampedX = min(max(origin.x, 16), canvasSize.width - size.width - 16)
        let clampedY = min(max(origin.y, 16), canvasSize.height - size.height - 16)
        let cardOrigin = CGPoint(x: clampedX, y: clampedY)

        return VStack(alignment: .leading, spacing: 10) {
            Text(step.title)
                .font(.title3.weight(.semibold))
            Text(step.subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)

            Spacer()

            HStack(spacing: 12) {
                Button("Назад") { withAnimation { state.previous() } }
                    .buttonStyle(.bordered)
                    .disabled(state.currentIndex == 0)
                Spacer()
                Button("Далее") { withAnimation { state.next() } }
                    .buttonStyle(.borderedProminent)
                    .disabled(state.currentIndex >= (state.steps.count - 1))
            }
        }
        .padding(16)
        .frame(width: size.width, height: size.height)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.35), radius: 18, x: 0, y: 16)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
        .position(x: cardOrigin.x + size.width / 2, y: cardOrigin.y + size.height / 2)
        .transition(.opacity.combined(with: .scale(scale: 0.98)))
    }

    private func fallbackTooltip(canvasSize: CGSize) -> some View {
        VStack(spacing: 12) {
            Text("Готовим обучение…")
                .font(.headline)
            Text("Дайте секунду, чтобы подсветить элементы тулбара")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.3), radius: 18, x: 0, y: 12)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.14), lineWidth: 1)
        )
        .position(x: canvasSize.width / 2, y: canvasSize.height / 2)
    }

    private var closeButton: some View {
        VStack {
            HStack {
                Spacer()
                Button(action: onClose) {
                    Label("Завершить", systemImage: "xmark")
                        .labelStyle(.titleAndIcon)
                }
                .buttonStyle(.bordered)
                .padding(20)
            }
            Spacer()
        }
    }
}
