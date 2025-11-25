import SwiftUI

enum OnboardingTarget: Hashable {
    case toolbarShell
    case tabSwitcher
    case visibilityToggle
    case menu
}

struct OnboardingTargetPreferenceKey: PreferenceKey {
    static var defaultValue: [OnboardingTarget: Anchor<CGRect>] = [:]

    static func reduce(value: inout [OnboardingTarget: Anchor<CGRect>], nextValue: () -> [OnboardingTarget: Anchor<CGRect>]) {
        value.merge(nextValue()) { $1 }
    }
}

extension View {
    func onboardingTarget(_ target: OnboardingTarget) -> some View {
        anchorPreference(key: OnboardingTargetPreferenceKey.self, value: .bounds) { anchor in
            [target: anchor]
        }
    }
}

struct OnboardingOverlayView: View {
    struct Step: Identifiable {
        let id = UUID()
        let title: String
        let subtitle: String
        let icon: String
        let accent: Color
        let target: OnboardingTarget
        let tips: [String]
        var padding: CGFloat = 12
    }

    @State private var currentStepIndex: Int = 0
    @State private var pulse: Bool = false
    @Namespace private var hero

    var onSkip: () -> Void
    var onFinish: () -> Void
    var targets: [OnboardingTarget: CGRect]

    private var steps: [Step] {
        [
            Step(
                title: "Главное окно", // 1
                subtitle: "Это настоящий плавающий тулбар Ghost. Он всегда остаётся под рукой и отображает актуальное состояние записи.",
                icon: "rectangle.and.hand.point.up.left",
                accent: Color.cyan,
                target: .toolbarShell,
                tips: [
                    "Всё здесь интерактивно: попробуйте нажать вкладки или кнопку воспроизведения.",
                    "Цветовое свечение и статус совпадают с обычным режимом работы.",
                    "Закрепите окно в удобном месте — обучение повторяет реальный сценарий."
                ],
                padding: 18
            ),
            Step(
                title: "Переключатель вкладок",
                subtitle: "Listen показывает живой транскрипт и инсайты, Ask — задаёт вопросы Ghost по свежему контексту.",
                icon: "square.grid.2x2",
                accent: Color.green,
                target: .tabSwitcher,
                tips: [
                    "Клик по вкладке открывает соответствующую панель прямо под тулбаром.",
                    "Мы оставляем фокус в поле ввода на Ask, чтобы сразу начать печатать.",
                    "Реакции и горячие клавиши работают так же, как и вне обучения."
                ]
            ),
            Step(
                title: "Спрятать или развернуть",
                subtitle: "Кнопка с глазом разворачивает плавающее окно или убирает его, оставляя только компактный островок.",
                icon: "eye",
                accent: Color.purple,
                target: .visibilityToggle,
                tips: [
                    "Нажмите, чтобы увидеть, как окно сворачивается — это живое поведение реального UI.",
                    "Ghost запоминает состояние и размер даже после обучения.",
                    "В свернутом виде тулбар остаётся кликабельным для быстрого возврата."
                ],
                padding: 10
            ),
            Step(
                title: "Меню и настройки",
                subtitle: "Три точки открывают быстрые действия и доступ к Settings. Можно переключить источники и провайдеров транскрипции.",
                icon: "ellipsis",
                accent: Color.orange,
                target: .menu,
                tips: [
                    "Открывайте меню, чтобы увидеть пресеты и системные команды.",
                    "Настройки открываются в реальном окне — можно менять параметры прямо сейчас.",
                    "Закончите обучение кнопкой \"Готово\" ниже, когда будете готовы."
                ],
                padding: 12
            )
        ]
    }

    private var step: Step { steps[currentStepIndex] }
    private var highlightFrame: CGRect? { targets[step.target] }

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .topLeading) {
                dimmedBackdrop(in: proxy.size)

                if let frame = highlightFrame {
                    highlightRing(for: frame)
                    connector(from: frame, in: proxy.size)
                    infoCard(frame, proxy.size)
                } else {
                    infoCard(CGRect(origin: .zero, size: proxy.size), proxy.size)
                }

                header
                    .padding(.top, 22)
                    .padding(.horizontal, 24)

                skipButton
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                pulse.toggle()
            }
        }
        .transition(.opacity)
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            ZStack {
                Circle()
                    .fill(step.accent.opacity(0.18))
                    .frame(width: 52, height: 52)
                Image(systemName: step.icon)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(step.accent)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("Обучение Ghost Desk")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.white)
                Text("Покажем главное за минуту — шаг за шагом")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            progressPills
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 18)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial.opacity(0.8))
                .shadow(color: .black.opacity(0.45), radius: 16, x: 0, y: 10)
        )
    }

    private var progressPills: some View {
        HStack(spacing: 6) {
            ForEach(steps.indices, id: \.self) { idx in
                Capsule()
                    .fill(idx <= currentStepIndex ? step.accent : Color.white.opacity(0.15))
                    .frame(width: idx == currentStepIndex ? 22 : 10, height: 8)
                    .animation(.spring(response: 0.5, dampingFraction: 0.8), value: currentStepIndex)
            }
        }
    }

    private func dimmedBackdrop(in size: CGSize) -> some View {
        ZStack {
            Canvas { context, canvasSize in
                var path = Path(CGRect(origin: .zero, size: canvasSize))
                if let frame = highlightFrame?.insetBy(dx: -step.padding, dy: -step.padding) {
                    path.addRoundedRect(in: frame, cornerSize: CGSize(width: 18, height: 18))
                }
                context.fill(path, with: .color(Color.black.opacity(0.72)), style: FillStyle(eoFill: true))
            }
            .blur(radius: 2)
            .ignoresSafeArea()
            .allowsHitTesting(false)

            RadialGradient(
                colors: [step.accent.opacity(0.25), .clear],
                center: .center,
                startRadius: 60,
                endRadius: min(size.width, size.height)
            )
            .blur(radius: 32)
            .ignoresSafeArea()
            .allowsHitTesting(false)
        }
        .animation(.easeInOut(duration: 0.35), value: highlightFrame)
        .animation(.easeInOut(duration: 0.35), value: step.accent)
    }

    private func highlightRing(for frame: CGRect) -> some View {
        let padded = frame.insetBy(dx: -step.padding, dy: -step.padding)

        return RoundedRectangle(cornerRadius: 22, style: .continuous)
            .stroke(step.accent.opacity(0.95), lineWidth: 2)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [step.accent.opacity(0.22), step.accent.opacity(0.05)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .blur(radius: pulse ? 18 : 28)
                    .opacity(0.9)
            )
            .frame(width: padded.width, height: padded.height)
            .position(x: padded.midX, y: padded.midY)
            .shadow(color: step.accent.opacity(0.55), radius: 18, x: 0, y: 12)
            .animation(.easeInOut(duration: 1.2), value: pulse)
            .allowsHitTesting(false)
    }

    private func connector(from frame: CGRect, in size: CGSize) -> some View {
        let calloutPoint = calloutPosition(for: frame, in: size)
        let start = CGPoint(x: frame.midX, y: frame.midY)
        let control = CGPoint(x: (start.x + calloutPoint.x) / 2, y: min(start.y, calloutPoint.y) - 20)

        return Path { path in
            path.move(to: start)
            path.addQuadCurve(to: calloutPoint, control: control)
        }
        .stroke(step.accent.opacity(0.65), style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round, dash: [2, 6]))
        .shadow(color: step.accent.opacity(0.35), radius: 8)
        .animation(.easeInOut(duration: 0.35), value: currentStepIndex)
        .allowsHitTesting(false)
    }

    private func calloutPosition(for frame: CGRect, in size: CGSize) -> CGPoint {
        let cardWidth = min(size.width - 48, 420)
        let x = clamp(frame.midX - cardWidth / 2, lower: 24, upper: size.width - cardWidth - 24)
        let placeAbove = frame.midY > size.height * 0.52
        let tentativeY = placeAbove ? (frame.minY - cardSize.height - 32) : (frame.maxY + 32)
        let safeY = clamp(tentativeY, lower: 56, upper: size.height - cardSize.height - 36)
        return CGPoint(x: x + cardWidth / 2, y: safeY + cardSize.height / 2)
    }

    @State private var cardSize: CGSize = CGSize(width: 380, height: 200)

    private func infoCard(_ frame: CGRect, _ size: CGSize) -> some View {
        let cardWidth = min(size.width - 48, 420)
        let placeAbove = frame.midY > size.height * 0.52
        let origin = calloutPosition(for: frame, in: size)

        return VStack(alignment: .leading, spacing: 16) {
            Text(step.title)
                .font(.title2.weight(.bold))
                .foregroundStyle(.white)
                .matchedGeometryEffect(id: "title", in: hero)
            Text(step.subtitle)
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .animation(.easeInOut, value: currentStepIndex)

            VStack(alignment: .leading, spacing: 10) {
                ForEach(step.tips, id: \.self) { tip in
                    HStack(alignment: .top, spacing: 10) {
                        Circle()
                            .fill(step.accent.opacity(0.75))
                            .frame(width: 8, height: 8)
                            .padding(.top, 6)
                        Text(tip)
                            .foregroundStyle(.white)
                            .font(.callout)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(step.accent.opacity(0.3), lineWidth: 1)
                    )
            )

            HStack(spacing: 10) {
                Button(action: retreat) {
                    Label("Назад", systemImage: "arrow.left")
                        .font(.headline.weight(.semibold))
                        .padding(.vertical, 11)
                        .padding(.horizontal, 16)
                        .frame(minWidth: 110)
                        .background(.ultraThinMaterial.opacity(currentStepIndex == 0 ? 0.5 : 0.9), in: Capsule())
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
                .disabled(currentStepIndex == 0)

                Spacer()

                Text("Шаг \(currentStepIndex + 1) из \(steps.count)")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)

                Button(action: advance) {
                    Label(currentStepIndex == steps.count - 1 ? "Готово" : "Далее", systemImage: currentStepIndex == steps.count - 1 ? "checkmark" : "arrow.right")
                        .font(.headline.weight(.semibold))
                        .padding(.vertical, 12)
                        .padding(.horizontal, 18)
                        .frame(minWidth: 140)
                        .background(step.accent.opacity(0.95), in: Capsule())
                        .foregroundStyle(.black.opacity(0.9))
                }
                .buttonStyle(.plain)
                .shadow(color: step.accent.opacity(0.55), radius: 12, x: 0, y: 8)
            }
        }
        .padding(24)
        .frame(width: cardWidth, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.45), radius: 28, x: 0, y: 20)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .strokeBorder(step.accent.opacity(0.35), lineWidth: 1)
        )
        .overlay(
            GeometryReader { cardGeo in
                Color.clear
                    .onAppear { cardSize = cardGeo.size }
                    .onChange(of: cardGeo.size) { new in cardSize = new }
            }
        )
        .position(origin)
        .animation(.spring(response: 0.5, dampingFraction: 0.86), value: currentStepIndex)
        .transition(placeAbove ? .move(edge: .bottom).combined(with: .opacity) : .move(edge: .top).combined(with: .opacity))
    }

    private var skipButton: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                Button(action: onSkip) {
                    Label("Пропустить обучение", systemImage: "forward.fill")
                        .font(.subheadline.weight(.semibold))
                        .padding(.vertical, 10)
                        .padding(.horizontal, 16)
                        .background(
                            Capsule()
                                .fill(.ultraThinMaterial.opacity(0.9))
                                .shadow(color: .black.opacity(0.35), radius: 12, x: 0, y: 8)
                        )
                }
                .buttonStyle(.plain)
                .padding(.trailing, 28)
                .padding(.bottom, 12)
            }
        }
    }

    private func advance() {
        if currentStepIndex < steps.count - 1 {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.88)) {
                currentStepIndex += 1
            }
        } else {
            onFinish()
        }
    }

    private func retreat() {
        guard currentStepIndex > 0 else { return }
        withAnimation(.spring(response: 0.5, dampingFraction: 0.88)) {
            currentStepIndex -= 1
        }
    }

    private func clamp(_ value: CGFloat, lower: CGFloat, upper: CGFloat) -> CGFloat {
        min(max(value, lower), upper)
    }
}

#Preview {
    let frames: [OnboardingTarget: CGRect] = [
        .toolbarShell: CGRect(x: 120, y: 120, width: 360, height: 60),
        .tabSwitcher: CGRect(x: 200, y: 120, width: 160, height: 36),
        .visibilityToggle: CGRect(x: 380, y: 122, width: 36, height: 36),
        .menu: CGRect(x: 430, y: 122, width: 36, height: 36)
    ]
    return OnboardingOverlayView(onSkip: {}, onFinish: {}, targets: frames)
        .background(.black)
        .preferredColorScheme(.dark)
}
