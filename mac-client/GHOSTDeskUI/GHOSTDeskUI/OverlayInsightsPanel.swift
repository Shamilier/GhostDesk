import SwiftUI

struct InsightsPanel: View {
    @ObservedObject var hint: HintAgent
    var onRequest: (HintAgent.Intent) -> Void
    var onClose: () -> Void
    @ObservedObject private var overlay = OverlayModel.shared

    private var selection: HintAgent.Intent? {
        hint.activeIntent ?? hint.lastCompletedIntent
    }

    private var cardTitle: String {
        selection?.displayTitle ?? "Инсайты разговора"
    }

    private var cardSubtitle: String {
        selection?.strapline ?? "Выберите подсказку, чтобы Ghost AI проанализировал беседу."
    }

    private var cardIcon: String {
        selection?.symbolName ?? "sparkles"
    }

    private var placeholder: String {
        if let active = hint.activeIntent { return active.placeholder }
        if let last = hint.lastCompletedIntent { return last.placeholder }
        return "Ghost AI соберёт контекст и предложит идеи, как только вы нажмёте одну из кнопок."
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            headerSection
            quickInsightsSection
            insightResultCard
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}

private extension InsightsPanel {
    var statusText: String {
        overlay.anyChannelIsTranscribing ? "Анализируем…" : "Готово к запуску"
    }

    var statusTint: Color {
        overlay.anyChannelIsTranscribing ? .accentColor : .secondary
    }

    var headerSection: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Инсайты в реальном времени")
                    .font(.title3.weight(.semibold))

                Text("Ghost AI анализирует системный звук и микрофон, чтобы подсказать идеи для разговора.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 12)

            VStack(alignment: .trailing, spacing: 8) {
                statusChip

                Button(action: onClose) {
                    Image(systemName: "xmark")
                }
                .buttonStyle(MiniIconButton())
                .accessibilityLabel("Скрыть инсайты")
            }
        }
    }

    var statusChip: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(statusTint.opacity(0.8))
                .frame(width: 8, height: 8)
            Text(statusText)
                .font(.caption.weight(.semibold))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule(style: .continuous)
                .fill(statusTint.opacity(0.12))
        )
        .overlay(
            Capsule(style: .continuous)
                .stroke(statusTint.opacity(0.25), lineWidth: 1)
        )
    }

    var quickInsightsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Быстрые инсайты")
                    .font(.headline.weight(.semibold))
                Text("Выберите сценарий, чтобы получить подсказку для разговора.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 160), spacing: 8, alignment: .leading)],
                alignment: .leading,
                spacing: 8
            ) {
                ForEach(HintAgent.insightIntents) { intent in
                    let isSelected = selection == intent

                    Button {
                        onRequest(intent)
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: intent.symbolName)
                            Text(intent.buttonTitle)
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .multilineTextAlignment(.leading)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(QuickInsightChip(tint: isSelected ? .accentColor : .secondary.opacity(0.9)))
                    .disabled(hint.isRunning && hint.activeIntent != intent)
                }
            }
        }
    }

    var insightResultCard: some View {
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)

        return VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Инсайты разговора")
                        .font(.caption.weight(.semibold))
                        .textCase(.uppercase)
                        .foregroundStyle(.secondary)

                    Spacer()

                    Button {
                        hint.draft = ""
                        hint.error = nil
                        hint.activeIntent = nil
                    } label: {
                        Label("Сбросить", systemImage: "arrow.counterclockwise")
                            .labelStyle(.titleAndIcon)
                            .font(.caption.weight(.semibold))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .disabled(hint.isRunning)
                    .opacity(hint.isRunning ? 0.4 : 1)
                }

                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: cardIcon)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(Color.accentColor)

                    VStack(alignment: .leading, spacing: 6) {
                        Text(cardTitle)
                            .font(.title3.weight(.semibold))
                            .fixedSize(horizontal: false, vertical: true)

                        Text(cardSubtitle)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 6) {
                        if hint.isRunning {
                            HStack(spacing: 6) {
                                ProgressView()
                                    .controlSize(.small)
                                Text("Анализируем…")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            if let started = hint.startedAt {
                                HStack(spacing: 4) {
                                    Image(systemName: "clock")
                                    Text(started, style: .time)
                                }
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            }
                        } else if let finished = hint.lastFinishedAt {
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark.circle")
                                Text(finished, style: .time)
                            }
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 18)
            .padding(.bottom, 12)
            .overlay(alignment: .bottomLeading) {
                Divider().overlay(Color.white.opacity(0.10))
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    if let err = hint.error {
                        Label(err, systemImage: "exclamationmark.triangle")
                            .font(.subheadline)
                            .foregroundStyle(.red)
                            .fixedSize(horizontal: false, vertical: true)
                    } else if !hint.draft.isEmpty {
                        Text(hint.draft)
                            .font(.system(size: 15, weight: .regular, design: .default))
                            .foregroundStyle(.primary)
                            .textSelection(.enabled)
                            .lineSpacing(4)
                            .fixedSize(horizontal: false, vertical: true)
                    } else if hint.isRunning {
                        Text("Ghost AI анализирует последние реплики…")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .italic()
                    } else {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Пока здесь пусто.")
                                .font(.subheadline.weight(.semibold))
                            Text("Выберите один из сценариев выше, и Ghost AI подготовит инсайты по вашему разговору.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)

                            VStack(alignment: .leading, spacing: 4) {
                                Text("🕒 Частые упоминания сроков")
                                Text("💬 Могут быть скрытые сомнения у клиента")
                            }
                            .font(.footnote)
                            .foregroundStyle(.secondary.opacity(0.9))
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 18)
                .padding(.vertical, 16)
                .transition(.opacity)
                .animation(.easeOut(duration: 0.2), value: hint.draft)
                .animation(.easeOut(duration: 0.2), value: hint.error)
                .animation(.easeOut(duration: 0.2), value: hint.isRunning)
            }
            .frame(minHeight: 160, maxHeight: 230)

            Divider().overlay(Color.white.opacity(0.08))

            HStack(spacing: 12) {
                if !hint.draft.isEmpty {
                    Button {
                        #if os(macOS)
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(hint.draft, forType: .string)
                        #endif
                    } label: {
                        Label("Скопировать", systemImage: "doc.on.doc")
                    }
                    .buttonStyle(GlassPill())
                }

                if hint.canStop {
                    Button(action: hint.cancel) {
                        Label("Стоп", systemImage: "stop.fill")
                    }
                    .buttonStyle(GlassPill(tint: .red))
                }

                Spacer()
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
        }
        .background(
            Group {
                if overlay.usesLiquidGlass, #available(macOS 26.0, *) {
                    shape
                        .fill(Color.clear)
                        .glassEffect(.clear, in: .rect(cornerRadius: 16))
                } else {
                    shape
                        .fill(Color.white.opacity(0.03))
                        .overlay(shape.stroke(.white.opacity(0.08), lineWidth: 1))
                }
            }
        )
        .clipShape(shape)
    }
}

private struct QuickInsightChip: ButtonStyle {
    var tint: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .semibold, design: .rounded))
            .foregroundStyle(tint)
            .padding(.vertical, 6)
            .padding(.horizontal, 10)
            .background(
                Capsule(style: .continuous)
                    .fill(tint.opacity(configuration.isPressed ? 0.18 : 0.12))
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(tint.opacity(configuration.isPressed ? 0.35 : 0.25), lineWidth: 1)
            )
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

