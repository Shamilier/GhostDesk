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
            let isCompact = proxy.size.width < 1120

            ZStack {
                backgroundLayer

                VStack(alignment: .leading, spacing: 22) {
                    heroHeader

                    glassContainer(isCompact: isCompact)

                    footerBar
                }
                .padding(.horizontal, isCompact ? 20 : 36)
                .padding(.vertical, 28)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                pulse.toggle()
            }
        }
    }

    private var backgroundLayer: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.07, green: 0.09, blue: 0.16), Color(red: 0.03, green: 0.05, blue: 0.08)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            RadialGradient(
                colors: [step.accent.opacity(0.32), .clear],
                center: .center,
                startRadius: 90,
                endRadius: 680
            )
            .blendMode(.screen)
            .blur(radius: 42)
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 0.35), value: step.accent)

            Circle()
                .fill(Color.white.opacity(0.02))
                .blur(radius: 80)
                .frame(width: 420, height: 420)
                .offset(x: -260, y: -180)

            Circle()
                .fill(step.accent.opacity(0.14))
                .blur(radius: 120)
                .frame(width: 360, height: 360)
                .offset(x: 220, y: 260)
        }
    }

    private var heroHeader: some View {
        HStack(alignment: .center, spacing: 14) {
            LinearGradient(
                colors: [Color(red: 0.35, green: 0.62, blue: 1), Color(red: 0.55, green: 0.35, blue: 1)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .mask(
                Image(systemName: "sparkles.rectangle.stack.fill")
                    .resizable()
                    .scaledToFit()
            )
            .frame(width: 32, height: 32)
            .overlay(
                Circle()
                    .stroke(Color.white.opacity(0.18), lineWidth: 1)
            )

            VStack(alignment: .leading, spacing: 4) {
                Text("Ghost AI — ассистент, который всегда рядом")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.white)
                Text("Обновлённый стартовый опыт покажет, как выглядит панель и что вы получите в первые минуты работы.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 12)
            progressPills
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 20)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.ultraThinMaterial.opacity(0.7))
                .shadow(color: .black.opacity(0.4), radius: 14, x: 0, y: 12)
        )
    }

    private var progressPills: some View {
        HStack(spacing: 6) {
            ForEach(steps.indices, id: \.self) { idx in
                Capsule()
                    .fill(idx <= currentStepIndex ? step.accent.opacity(0.95) : Color.white.opacity(0.14))
                    .frame(width: idx == currentStepIndex ? 24 : 12, height: 8)
                    .overlay(
                        Capsule()
                            .stroke(Color.white.opacity(0.18), lineWidth: 1)
                    )
                    .animation(.spring(response: 0.5, dampingFraction: 0.8), value: currentStepIndex)
            }
        }
    }

    private func glassContainer(isCompact: Bool) -> some View {
        let layout = isCompact ? AnyLayout(VStackLayout(spacing: 18)) : AnyLayout(HStackLayout(spacing: 18))

        return layout {
            onboardingSteps
            Divider()
                .overlay(Color.white.opacity(0.08))
                .frame(maxHeight: isCompact ? 1 : .infinity)
                .frame(maxWidth: isCompact ? .infinity : 1)
                .padding(isCompact ? .horizontal : .vertical, 4)
            GhostPanelPreview(step: step, pulse: $pulse) {
                spotlight(in: $0)
            }
        }
        .padding(isCompact ? 18 : 22)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(glassBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(step.accent.opacity(0.22), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .shadow(color: .black.opacity(0.45), radius: 32, x: 0, y: 18)
    }

    private var glassBackground: some ShapeStyle {
        LinearGradient(
            colors: [Color.white.opacity(0.08), Color.white.opacity(0.02)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var onboardingSteps: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center, spacing: 8) {
                Text("Как работает панель")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white)
                Spacer()
                Button(action: onSkip) {
                    Label("Пропустить", systemImage: "xmark")
                        .labelStyle(.titleAndIcon)
                        .font(.subheadline.weight(.semibold))
                }
                .buttonStyle(.borderless)
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.06)))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.12), lineWidth: 1))
            }

            VStack(alignment: .leading, spacing: 12) {
                ForEach(steps.indices, id: \.self) { index in
                    stepRow(step: steps[index], index: index)
                        .onTapGesture { selectStep(index) }
                }
            }

            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Шаг \(currentStepIndex + 1) из \(steps.count)")
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.secondary)
                    Text(step.subtitle)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                Spacer()
                HStack(spacing: 8) {
                    Button(action: goBack) {
                        Label("Назад", systemImage: "chevron.left")
                            .labelStyle(.titleAndIcon)
                    }
                    .buttonStyle(.plain)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 14)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.06)))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.12), lineWidth: 1))
                    .opacity(currentStepIndex == 0 ? 0.45 : 1)
                    .animation(.easeInOut, value: currentStepIndex)

                    Button(action: advance) {
                        Label(currentStepIndex == steps.count - 1 ? "Готово" : "Далее", systemImage: currentStepIndex == steps.count - 1 ? "checkmark" : "arrow.right")
                            .font(.headline.weight(.semibold))
                            .padding(.vertical, 12)
                            .padding(.horizontal, 18)
                            .frame(minWidth: 140)
                            .background(step.accent.gradient, in: Capsule())
                            .foregroundStyle(.black.opacity(0.9))
                    }
                    .buttonStyle(.plain)
                    .shadow(color: step.accent.opacity(0.55), radius: 12, x: 0, y: 8)
                }
            }
        }
    }

    private func anchorPoint(for alignment: Alignment, in size: CGSize) -> CGPoint {
        switch alignment {
        case .top:
            return CGPoint(x: size.width / 2, y: size.height * 0.22)
        case .bottom:
            return CGPoint(x: size.width / 2, y: size.height * 0.78)
        case .bottomTrailing:
            return CGPoint(x: size.width * 0.80, y: size.height * 0.80)
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

    private func stepRow(step: Step, index: Int) -> some View {
        let isActive = index == currentStepIndex

        return HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(step.accent.opacity(isActive ? 0.18 : 0.08))
                    .frame(width: 32, height: 32)
                Image(systemName: step.icon)
                    .foregroundStyle(isActive ? step.accent : Color.white.opacity(0.7))
                    .font(.callout.weight(.semibold))
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("0\(index + 1)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                    Text(step.title)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.white)
                }

                Text(step.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                HStack(alignment: .center, spacing: 6) {
                    ForEach(step.tips.prefix(2), id: \.self) { tip in
                        Text(tip)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.8))
                            .padding(.vertical, 6)
                            .padding(.horizontal, 10)
                            .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.06)))
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.12), lineWidth: 1))
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(isActive ? step.accent.opacity(0.12) : Color.white.opacity(0.02))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(isActive ? step.accent.opacity(0.35) : Color.white.opacity(0.08), lineWidth: 1)
        )
        .animation(.easeInOut(duration: 0.25), value: isActive)
    }

    private func selectStep(_ index: Int) {
        guard index != currentStepIndex else { return }
        withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
            currentStepIndex = index
        }
    }

    private func goBack() {
        guard currentStepIndex > 0 else { return }
        withAnimation(.spring(response: 0.5, dampingFraction: 0.88)) {
            currentStepIndex -= 1
        }
    }

    private var footerBar: some View {
        HStack {
            Label("Powered by Ghost AI", systemImage: "bolt.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.04)))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.08), lineWidth: 1))
            Spacer()
            progressPills
        }
        .padding(.horizontal, 12)
    }

    private struct GhostPanelPreview<Spotlight: View>: View {
        let step: Step
        @Binding var pulse: Bool
        var spotlight: (CGSize) -> Spotlight

        var body: some View {
            VStack(alignment: .leading, spacing: 14) {
                previewHeader
                ZStack(alignment: .top) {
                    GeometryReader { proxy in
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(panelBackground)
                            .overlay(panelContent)
                            .overlay(alignment: .top) {
                                spotlight(proxy.size)
                            }
                            .overlay(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
                            )
                    }
                    .frame(height: 320)
                }
                .background(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(Color.white.opacity(0.02))
                        .shadow(color: .black.opacity(0.4), radius: 24, x: 0, y: 16)
                )
            }
        }

        private var previewHeader: some View {
            HStack(spacing: 10) {
                Text("Превью панели Ghost AI")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white)
                Spacer()
                Capsule()
                    .fill(step.accent.opacity(0.18))
                    .frame(width: 12, height: 12)
                    .overlay(Capsule().stroke(step.accent.opacity(0.45), lineWidth: 1))
                Text("Live")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(step.accent)
            }
        }

        private var panelBackground: some ShapeStyle {
            LinearGradient(
                colors: [Color(red: 0.08, green: 0.1, blue: 0.14), Color(red: 0.06, green: 0.08, blue: 0.12)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }

        private var panelContent: some View {
            VStack(spacing: 0) {
                headerBar
                Divider().overlay(Color.white.opacity(0.05))
                mainContent
                Divider().overlay(Color.white.opacity(0.05))
                footerBar
            }
        }

        private var headerBar: some View {
            HStack(spacing: 10) {
                Label("Ghost AI", systemImage: "sparkles")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                Spacer()
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.white.opacity(0.05))
                    .frame(width: 110, height: 26)
                    .overlay(
                        HStack(spacing: 6) {
                            Circle().fill(step.accent).frame(width: 8, height: 8)
                            Text("Live transcript")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.white.opacity(0.9))
                        }
                            .padding(.horizontal, 8)
                    )
            }
            .padding(12)
        }

        private var mainContent: some View {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    ghostCard(title: "Транскрипт", subtitle: "Live", gradient: gradientAccent)
                    ghostCard(title: "Инсайты", subtitle: "AI Highlights", gradient: gradientAccent)
                    Spacer()
                }
                .frame(width: 160)

                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.white.opacity(0.02))
                    .overlay(
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(0..<4) { row in
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color.white.opacity(0.05))
                                    .frame(height: 46)
                                    .overlay(
                                        HStack(spacing: 12) {
                                            Circle()
                                                .fill(step.accent.opacity(0.8))
                                                .frame(width: 10, height: 10)
                                                .shadow(color: step.accent.opacity(0.5), radius: 6, x: 0, y: 4)
                                            VStack(alignment: .leading, spacing: 4) {
                                                RoundedRectangle(cornerRadius: 4).fill(Color.white.opacity(0.22)).frame(height: 6)
                                                RoundedRectangle(cornerRadius: 4).fill(Color.white.opacity(0.12)).frame(width: 120, height: 5)
                                            }
                                            Spacer()
                                            Image(systemName: row % 2 == 0 ? "sparkles" : "ellipsis")
                                                .foregroundStyle(Color.white.opacity(0.55))
                                        }
                                        .padding(.horizontal, 12)
                                    )
                            }
                        }
                        .padding(12)
                    )
            }
            .padding(12)
        }

        private var footerBar: some View {
            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.white.opacity(0.05))
                    .frame(width: 46, height: 36)
                    .overlay(Image(systemName: "keyboard").foregroundStyle(.white.opacity(0.75)))
                RoundedRectangle(cornerRadius: 10)
                    .fill(step.accent.opacity(0.16))
                    .frame(height: 36)
                    .overlay(
                        HStack(spacing: 8) {
                            Image(systemName: "mic.fill").foregroundStyle(step.accent)
                            Text("Слушаем Mac")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.white)
                        }
                            .padding(.horizontal, 12)
                    )
                Spacer()
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.white.opacity(0.05))
                    .frame(width: 120, height: 36)
                    .overlay(
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.up.message")
                                .foregroundStyle(.white.opacity(0.7))
                            Text("Спросить Ghost")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.white)
                        }
                    )
            }
            .padding(12)
        }

        private var gradientAccent: LinearGradient {
            LinearGradient(
                colors: [step.accent.opacity(0.9), step.accent.opacity(0.45)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }

        private func ghostCard(title: String, subtitle: String, gradient: LinearGradient) -> some View {
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.white.opacity(0.03))
                .overlay(
                    VStack(alignment: .leading, spacing: 6) {
                        Text(title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Capsule()
                            .fill(gradient)
                            .frame(height: 6)
                    }
                    .padding(10)
                )
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
