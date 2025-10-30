import SwiftUI

struct InsightsPanel: View {
    @ObservedObject var hint: HintAgent
    var onRequest: (HintAgent.Intent) -> Void
    var onClose: () -> Void

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
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Быстрые инсайты")
                        .font(.headline.weight(.semibold))
                    Text("Выберите сценарий, чтобы получить подсказку для разговора.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 12)

                Button(action: onClose) {
                    Image(systemName: "xmark")
                }
                .buttonStyle(MiniIconButton())
                .accessibilityLabel("Скрыть инсайты")
            }

            LazyVGrid(
                columns: [
                    GridItem(.adaptive(minimum: 180), spacing: 8, alignment: .leading)
                ],
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
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(GlassPill(tint: isSelected ? .accentColor : .secondary))
                    .disabled(hint.isRunning && hint.activeIntent != intent)
                }
            }

            let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)

            VStack(spacing: 0) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: cardIcon)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(Color.accentColor)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(cardTitle)
                            .font(.title3.weight(.semibold))
                        Text(cardSubtitle)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 6) {
                        if hint.isRunning {
                            ProgressView()
                                .controlSize(.small)
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
                            Text(placeholder)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 16)
                }
                .frame(minHeight: 140, maxHeight: 220)

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

                    Button {
                        hint.draft = ""
                        hint.error = nil
                        hint.activeIntent = nil
                    } label: {
                        Label("Сбросить", systemImage: "arrow.counterclockwise")
                    }
                    .buttonStyle(GlassPill(tint: .secondary))
                    .disabled(hint.isRunning)
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 14)
            }
            .background(
                shape
                    .fill(Color.white.opacity(0.03))
                    .overlay(shape.stroke(.white.opacity(0.08), lineWidth: 1))
            )
            .clipShape(shape)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}
