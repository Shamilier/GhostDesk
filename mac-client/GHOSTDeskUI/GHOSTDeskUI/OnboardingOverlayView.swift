import SwiftUI

struct OnboardingOverlayView: View {
    struct Step: Identifiable, Hashable {
        let id = UUID()
        let title: String
        let subtitle: String
        let icon: String
        let accent: Color
        let highlightSize: CGSize
        let highlightAlignment: Alignment
        let highlightOffset: CGSize
        let tips: [String]
    }

    @State private var currentStepIndex: Int = 0
    @State private var pulse: Bool = false
    @Namespace private var hero

    var onSkip: () -> Void
    var onFinish: () -> Void

    private var steps: [Step] {
        [
            Step(
                title: "Центр управления",
                subtitle: "Запускайте/останавливайте запись, открывайте настройки и переключайтесь между режимами на верхней панели островка.",
                icon: "rectangle.3.offgrid",
                accent: Color.cyan,
                highlightSize: CGSize(width: 340, height: 84),
                highlightAlignment: .top,
                highlightOffset: CGSize(width: 0, height: 40),
                tips: [
                    "Нажмите кнопку глаза, чтобы спрятать или развернуть островок.",
                    "Клик по меню откроет быстрые настройки и пресеты.",
                    "Цвет индикатора показывает текущий статус записи."
                ]
            ),
            Step(
                title: "Живой транскрипт",
                subtitle: "Мы слушаем системный звук или микрофон и показываем живой транскрипт. Ghost может резюмировать и подсвечивать инсайты.",
                icon: "waveform",
                accent: Color.green,
                highlightSize: CGSize(width: 420, height: 260),
                highlightAlignment: .center,
                highlightOffset: CGSize(width: 0, height: -12),
                tips: [
                    "Переключайтесь между \"Транскрипт\" и \"Инсайты\" одной кнопкой.",
                    "Состояние LiveDot подсказывает, когда мы записываем.",
                    "Скролл автоматически следует за новым текстом, если авто-прокрутка включена."
                ]
            ),
            Step(
                title: "Задавайте вопросы",
                subtitle: "Во вкладке Вопрос можно отправить свой запрос или попросить Ghost продолжить мысль, опираясь на свежий контекст.",
                icon: "bubble.left.and.bubble.right",
                accent: Color.purple,
                highlightSize: CGSize(width: 420, height: 210),
                highlightAlignment: .center,
                highlightOffset: CGSize(width: 0, height: 180),
                tips: [
                    "Начните печатать — поле сразу получает фокус при открытии вкладки.",
                    "Используйте кнопку отправки, чтобы получить ответ Ghost прямо в оверлее.",
                    "Мы подставим последние минуты диалога, даже если текстовое поле пустое."
                ]
            ),
            Step(
                title: "Готовы к работе",
                subtitle: "Ghost работает в фоне. Горячие клавиши и иконка в меню помогут быстро открыть/скрыть оверлей.",
                icon: "sparkles",
                accent: Color.orange,
                highlightSize: CGSize(width: 240, height: 60),
                highlightAlignment: .bottomTrailing,
                highlightOffset: CGSize(width: -20, height: -22),
                tips: [
                    "Нажмите комбинацию горячих клавиш, чтобы развернуть окно из любой точки.",
                    "Кнопка \"Готово\" закроет обучение и сохранит настройки.",
                    "В настройках можно подключить Deepgram/Whisper и выбрать источник звука."
                ]
            )
        ]
    }

    private var step: Step { steps[currentStepIndex] }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Color.black.opacity(0.76)
                    .ignoresSafeArea()

                RadialGradient(
                    colors: [step.accent.opacity(0.35), .clear],
                    center: .center,
                    startRadius: 80,
                    endRadius: min(proxy.size.width, proxy.size.height)
                )
                .blur(radius: 40)
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 0.35), value: step.accent)

                spotlight(in: proxy.size)

                VStack(alignment: .leading, spacing: 20) {
                    header
                    Spacer()
                    infoCard(proxy.size)
                }
                .padding(.horizontal, 32)
                .padding(.top, 32)
                .padding(.bottom, 28)

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
                .fill(.ultraThinMaterial.opacity(0.7))
                .shadow(color: .black.opacity(0.35), radius: 16, x: 0, y: 10)
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

    private func anchorPoint(for alignment: Alignment, in size: CGSize) -> CGPoint {
        switch alignment {
        case .top:
            return CGPoint(x: size.width / 2, y: size.height * 0.20)
        case .bottom:
            return CGPoint(x: size.width / 2, y: size.height * 0.80)
        case .bottomTrailing:
            return CGPoint(x: size.width * 0.80, y: size.height * 0.82)
        default:
            return CGPoint(x: size.width / 2, y: size.height / 2)
        }
    }

    private func spotlight(in size: CGSize) -> some View {
        let anchor = anchorPoint(for: step.highlightAlignment, in: size)
        let frame = CGRect(
            x: anchor.x - (step.highlightSize.width / 2) + step.highlightOffset.width,
            y: anchor.y - (step.highlightSize.height / 2) + step.highlightOffset.height,
            width: step.highlightSize.width,
            height: step.highlightSize.height
        )

        return ZStack {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(step.accent.opacity(0.9), lineWidth: 2)
                .background(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [step.accent.opacity(0.14), step.accent.opacity(0.02)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .blur(radius: pulse ? 20 : 34)
                        .opacity(0.9)
                        .animation(.easeInOut(duration: 1.2), value: pulse)
                )
                .frame(width: frame.width, height: frame.height)
                .position(x: frame.midX, y: frame.midY)
                .shadow(color: step.accent.opacity(0.45), radius: 18, x: 0, y: 10)
                .overlay(alignment: .topTrailing) {
                    if currentStepIndex == 0 {
                        Label("Кликни, чтобы развернуть", systemImage: "hand.tap")
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(RoundedRectangle(cornerRadius: 12).fill(.ultraThinMaterial.opacity(0.9)))
                            .foregroundStyle(.primary)
                            .offset(x: 6, y: -10)
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }
                }
        }
    }

    private func infoCard(_ size: CGSize) -> some View {
        VStack(alignment: .leading, spacing: 16) {
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

            HStack {
                Text("Шаг \(currentStepIndex + 1) из \(steps.count)")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
                Spacer()
                Button(action: advance) {
                    Label(currentStepIndex == steps.count - 1 ? "Готово" : "Далее", systemImage: currentStepIndex == steps.count - 1 ? "checkmark" : "arrow.right")
                        .font(.headline.weight(.semibold))
                        .padding(.vertical, 12)
                        .padding(.horizontal, 18)
                        .frame(minWidth: 140)
                        .background(step.accent.opacity(0.9), in: Capsule())
                        .foregroundStyle(.black.opacity(0.9))
                }
                .buttonStyle(.plain)
                .shadow(color: step.accent.opacity(0.55), radius: 12, x: 0, y: 8)
            }
        }
        .padding(24)
        .frame(maxWidth: min(size.width - 64, 560))
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.45), radius: 28, x: 0, y: 20)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .strokeBorder(step.accent.opacity(0.35), lineWidth: 1)
        )
        .animation(.spring(response: 0.5, dampingFraction: 0.86), value: currentStepIndex)
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
}

#Preview {
    OnboardingOverlayView(onSkip: {}, onFinish: {})
        .background(.black)
        .preferredColorScheme(.dark)
}
