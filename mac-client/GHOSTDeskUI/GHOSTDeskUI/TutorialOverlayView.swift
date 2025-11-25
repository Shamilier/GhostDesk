import SwiftUI
import AppKit

struct TutorialStep: Identifiable {
    enum CalloutPosition {
        case top
        case bottom
        case leading
        case trailing
    }

    let id = UUID()
    let target: OnboardingTarget
    let title: String
    let description: String
    let position: CalloutPosition
    let padding: CGFloat
    let cornerRadius: CGFloat
}

@MainActor
final class TutorialFlow: ObservableObject {
    static let shared = TutorialFlow()

    @Published var isActive: Bool = false
    @Published var currentStepIndex: Int = 0
    @Published private(set) var targetFrames: [OnboardingTarget: CGRect] = [:]

    let steps: [TutorialStep]

    private init() {
        steps = [
            TutorialStep(
                target: .toolbarShell,
                title: "Панель всегда поверх",
                description: "Основной Floating Toolbar остаётся интерактивным и всегда лежит выше любых вспомогательных слоёв.",
                position: .bottom,
                padding: 22,
                cornerRadius: 18
            ),
            TutorialStep(
                target: .tabSwitcher,
                title: "Вкладки",
                description: "Listen и Ask переключают реальные панели прямо под тулбаром. Навигация в обучении повторяет живую логику.",
                position: .top,
                padding: 18,
                cornerRadius: 14
            ),
            TutorialStep(
                target: .visibilityToggle,
                title: "Свернуть/раскрыть",
                description: "Кнопка с глазом сворачивает и разворачивает окно без пересчёта положения оверлея.",
                position: .trailing,
                padding: 16,
                cornerRadius: 14
            ),
            TutorialStep(
                target: .menu,
                title: "Меню",
                description: "Три точки открывают меню и настройки. В режиме обучения подсветка реагирует только на активный шаг.",
                position: .leading,
                padding: 12,
                cornerRadius: 14
            )
        ]
    }

    func start() {
        currentStepIndex = 0
        withAnimation(.easeInOut(duration: 0.3)) {
            isActive = true
        }
        TutorialOverlayWindowManager.shared.present(flow: self)
    }

    func finish() {
        withAnimation(.easeInOut(duration: 0.25)) {
            isActive = false
        }
        TutorialOverlayWindowManager.shared.hide()
    }

    func nextStep() {
        guard currentStepIndex < steps.count - 1 else {
            finish()
            return
        }
        withAnimation(.spring(response: 0.32, dampingFraction: 0.88)) {
            currentStepIndex += 1
        }
    }

    func previousStep() {
        guard currentStepIndex > 0 else { return }
        withAnimation(.spring(response: 0.32, dampingFraction: 0.88)) {
            currentStepIndex -= 1
        }
    }

    func updateTargets(_ frames: [OnboardingTarget: CGRect]) {
        targetFrames = frames
    }

    var currentStep: TutorialStep { steps[currentStepIndex] }
}

struct TutorialOverlayView: View {
    @ObservedObject var flow: TutorialFlow
    @State private var appeared = false

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let step = flow.currentStep
            let highlight = flow.targetFrames[step.target] ?? fallbackFrame(in: size)

            ZStack(alignment: .topLeading) {
                dimLayer(size: size, highlight: highlight, padding: step.padding, radius: step.cornerRadius)

                highlightOutline(for: highlight, padding: step.padding, radius: step.cornerRadius)

                callout(for: step, target: highlight, canvas: size)

                arrow(from: step, target: highlight, canvas: size)
            }
            .frame(width: size.width, height: size.height)
        }
        .ignoresSafeArea()
        .opacity(appeared ? 1 : 0)
        .scaleEffect(appeared ? 1 : 1.02)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.28)) {
                appeared = true
            }
        }
    }

    private func dimLayer(size: CGSize, highlight: CGRect, padding: CGFloat, radius: CGFloat) -> some View {
        Canvas { context, canvasSize in
            var path = Path(CGRect(origin: .zero, size: canvasSize))
            let hole = highlight.insetBy(dx: -padding, dy: -padding)
            path.addRoundedRect(in: hole, cornerSize: CGSize(width: radius, height: radius))
            context.fill(path, with: .color(Color.black.opacity(0.55)), style: FillStyle(eoFill: true))
        }
        .overlay(
            Rectangle()
                .fill(.ultraThinMaterial.opacity(0.35))
        )
        .blur(radius: 1.5)
        .transition(.opacity)
    }

    private func highlightOutline(for frame: CGRect, padding: CGFloat, radius: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: radius)
            .strokeBorder(Color.white.opacity(0.7), lineWidth: 2)
            .frame(width: frame.width + padding * 2, height: frame.height + padding * 2)
            .position(x: frame.midX, y: frame.midY)
            .shadow(color: Color.white.opacity(0.18), radius: 16, y: 8)
            .animation(.easeInOut(duration: 0.25), value: flow.currentStepIndex)
    }

    private func arrow(from step: TutorialStep, target: CGRect, canvas: CGSize) -> some View {
        let calloutFrame = calloutFrame(for: step, target: target, canvas: canvas)
        let start = anchorPoint(for: step.position, in: calloutFrame)
        let end = targetAnchor(for: step.position, frame: target, padding: step.padding)

        return TutorialArrow(start: start, end: end)
            .stroke(Color.accentColor.opacity(0.9), style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
            .shadow(color: Color.accentColor.opacity(0.3), radius: 8)
            .animation(.easeInOut(duration: 0.25), value: flow.currentStepIndex)
    }

    private func callout(for step: TutorialStep, target: CGRect, canvas: CGSize) -> some View {
        let frame = calloutFrame(for: step, target: target, canvas: canvas)

        return VStack(alignment: .leading, spacing: 10) {
            Text(step.title)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)
            Text(step.description)
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 4)

            HStack(spacing: 12) {
                Button(action: { flow.previousStep() }) {
                    Label("Назад", systemImage: "chevron.left")
                }
                .buttonStyle(.borderedProminent)
                .tint(.gray.opacity(0.3))
                .disabled(flow.currentStepIndex == 0)

                Spacer()

                Button(action: { flow.nextStep() }) {
                    Label(flow.currentStepIndex == flow.steps.count - 1 ? "Готово" : "Далее", systemImage: "chevron.right")
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(16)
        .frame(width: frame.width, height: frame.height, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.ultraThinMaterial.opacity(0.92))
                .shadow(color: .black.opacity(0.55), radius: 20, x: 0, y: 10)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
        .position(x: frame.midX, y: frame.midY)
        .animation(.spring(response: 0.32, dampingFraction: 0.88), value: flow.currentStepIndex)
    }

    private func calloutFrame(for step: TutorialStep, target: CGRect, canvas: CGSize) -> CGRect {
        let maxWidth = min(420.0, canvas.width - 40)
        let height: CGFloat = 180
        var origin = CGPoint(x: target.midX - maxWidth / 2, y: target.maxY + 20)

        switch step.position {
        case .top:
            origin = CGPoint(x: target.midX - maxWidth / 2, y: target.minY - height - 20)
        case .bottom:
            origin = CGPoint(x: target.midX - maxWidth / 2, y: target.maxY + 20)
        case .leading:
            origin = CGPoint(x: target.minX - maxWidth - 20, y: target.midY - height / 2)
        case .trailing:
            origin = CGPoint(x: target.maxX + 20, y: target.midY - height / 2)
        }

        origin.x = min(max(20, origin.x), canvas.width - maxWidth - 20)
        origin.y = min(max(20, origin.y), canvas.height - height - 20)

        return CGRect(origin: origin, size: CGSize(width: maxWidth, height: height))
    }

    private func anchorPoint(for position: TutorialStep.CalloutPosition, in callout: CGRect) -> CGPoint {
        switch position {
        case .top:
            return CGPoint(x: callout.midX, y: callout.minY)
        case .bottom:
            return CGPoint(x: callout.midX, y: callout.maxY)
        case .leading:
            return CGPoint(x: callout.minX, y: callout.midY)
        case .trailing:
            return CGPoint(x: callout.maxX, y: callout.midY)
        }
    }

    private func targetAnchor(for position: TutorialStep.CalloutPosition, frame: CGRect, padding: CGFloat) -> CGPoint {
        switch position {
        case .top:
            return CGPoint(x: frame.midX, y: frame.maxY + padding)
        case .bottom:
            return CGPoint(x: frame.midX, y: frame.minY - padding)
        case .leading:
            return CGPoint(x: frame.maxX + padding, y: frame.midY)
        case .trailing:
            return CGPoint(x: frame.minX - padding, y: frame.midY)
        }
    }

    private func fallbackFrame(in size: CGSize) -> CGRect {
        CGRect(x: size.width / 2 - 80, y: size.height / 2 - 24, width: 160, height: 48)
    }
}

struct TutorialArrow: Shape {
    var start: CGPoint
    var end: CGPoint

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: start)
        path.addLine(to: end)

        let angle = atan2(end.y - start.y, end.x - start.x)
        let length: CGFloat = 12
        let spread: CGFloat = .pi / 8

        let arrow1 = CGPoint(x: end.x - length * cos(angle - spread), y: end.y - length * sin(angle - spread))
        let arrow2 = CGPoint(x: end.x - length * cos(angle + spread), y: end.y - length * sin(angle + spread))

        path.move(to: end)
        path.addLine(to: arrow1)
        path.move(to: end)
        path.addLine(to: arrow2)

        return path
    }
}

#if DEBUG
#Preview {
    TutorialOverlayView(flow: TutorialFlow.shared)
}
#endif
