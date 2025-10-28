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
        selection?.strapline ?? "Выберите подсказку, чтобы GhostDesk проанализировал беседу."
    }

    private var cardIcon: String {
        selection?.symbolName ?? "sparkles"
    }

    private var placeholder: String {
        if let active = hint.activeIntent { return active.placeholder }
        if let last = hint.lastCompletedIntent { return last.placeholder }
        return "GhostDesk соберёт контекст и предложит идеи, как только вы нажмёте одну из кнопок."
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            header

            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: 24) {
                    detailCard
                        .frame(maxWidth: .infinity)

                    scenarioStack
                        .frame(maxWidth: 320)
                }

                VStack(alignment: .leading, spacing: 24) {
                    detailCard
                    scenarioStack
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .padding(.vertical, 6)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Live AI-подсказки", systemImage: "sparkles")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule(style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [Color.accentColor.opacity(0.24), Color.accentColor.opacity(0.08)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .overlay(
                                    Capsule(style: .continuous)
                                        .stroke(Color.white.opacity(0.18), lineWidth: 1)
                                )
                        )
                        .foregroundStyle(.white)

                    Text("Быстрые инсайты")
                        .font(.system(size: 20, weight: .semibold, design: .rounded))

                    Text("GhostDesk анализирует последние реплики и подсказывает, как вести диалог увереннее.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 12)

                Button(action: onClose) {
                    Label("Скрыть", systemImage: "xmark")
                        .labelStyle(.iconOnly)
                }
                .accessibilityLabel("Скрыть инсайты")
            }
        }
    }

    private var scenarioStack: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Сценарии")
                    .font(.caption.weight(.semibold))
                    .textCase(.uppercase)
                    .foregroundStyle(.secondary)

                Text("Выберите подходящий сценарий — мы мгновенно соберём контекст и подготовим подсказку.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            intentGrid
        }
    }

    private var intentGrid: some View {
        ViewThatFits(in: .horizontal) {
            VStack(spacing: 16) {
                ForEach(Array(intentRows.enumerated()), id: \.offset) { _, row in
                    HStack(spacing: 16) {
                        ForEach(row, id: \.id) { intent in
                            let isSelected = selection == intent
                            InsightIntentCard(
                                intent: intent,
                                isSelected: isSelected,
                                isDimmed: hint.isRunning && hint.activeIntent != intent,
                                action: { onRequest(intent) }
                            )
                            .animation(.spring(response: 0.35, dampingFraction: 0.82), value: isSelected)
                            .frame(maxWidth: .infinity)
                        }

                        if row.count == 1 {
                            Spacer(minLength: 0)
                                .frame(maxWidth: .infinity)
                                .opacity(0)
                        }
                    }
                }
            }

            VStack(spacing: 16) {
                ForEach(HintAgent.insightIntents) { intent in
                    let isSelected = selection == intent
                    InsightIntentCard(
                        intent: intent,
                        isSelected: isSelected,
                        isDimmed: hint.isRunning && hint.activeIntent != intent,
                        action: { onRequest(intent) }
                    )
                    .animation(.spring(response: 0.35, dampingFraction: 0.82), value: isSelected)
                }
            }
        }
    }

    private var intentRows: [[HintAgent.Intent]] {
        var rows: [[HintAgent.Intent]] = []
        var current: [HintAgent.Intent] = []

        for intent in HintAgent.insightIntents {
            current.append(intent)

            if current.count == 2 {
                rows.append(current)
                current.removeAll(keepingCapacity: true)
            }
        }

        if !current.isEmpty {
            rows.append(current)
        }

        return rows
    }

    private var detailCard: some View {
        let shape = RoundedRectangle(cornerRadius: 20, style: .continuous)

        return VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .center, spacing: 18) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color.accentColor.opacity(0.32), Color.accentColor.opacity(0.12)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .frame(width: 44, height: 44)
                            .overlay(
                                Circle()
                                    .stroke(Color.white.opacity(0.28), lineWidth: 1)
                            )

                        Image(systemName: cardIcon)
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(.white)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text(cardTitle)
                            .font(.system(size: 20, weight: .semibold, design: .rounded))
                            .foregroundStyle(.primary)
                            .fixedSize(horizontal: false, vertical: true)

                        Text(cardSubtitle)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 12)

                    VStack(alignment: .trailing, spacing: 6) {
                        statusBadge

                        if let started = hint.startedAt, hint.isRunning {
                            Label {
                                Text(started, style: .time)
                            } icon: {
                                Image(systemName: "clock")
                            }
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        }

                        if let finished = hint.lastFinishedAt, !hint.isRunning {
                            Label {
                                Text(finished, style: .time)
                            } icon: {
                                Image(systemName: "clock")
                            }
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .padding(.bottom, 18)

            Divider()
                .overlay(Color.white.opacity(0.08))
                .padding(.horizontal, 24)

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    if let err = hint.error {
                        Label(err, systemImage: "exclamationmark.triangle.fill")
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
                        Text("GhostDesk анализирует последние реплики…")
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
                .padding(.horizontal, 24)
                .padding(.vertical, 20)
            }
            .frame(minHeight: 180, maxHeight: 260)

            Divider()
                .overlay(Color.white.opacity(0.08))
                .padding(.horizontal, 24)

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
            .padding(.horizontal, 24)
            .padding(.vertical, 18)
        }
        .background(
            shape
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.08), Color.white.opacity(0.02)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    shape.stroke(
                        LinearGradient(
                            colors: [Color.accentColor.opacity(0.28), Color.white.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.2
                    )
                )
        )
        .clipShape(shape)
        .shadow(color: Color.black.opacity(0.18), radius: 20, x: 0, y: 16)
    }

    @ViewBuilder
    private var statusBadge: some View {
        if hint.isRunning {
            HStack(spacing: 6) {
                ProgressView()
                    .controlSize(.small)
                    .tint(.white)
                Text("Готовим подсказку")
                    .font(.caption.weight(.semibold))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule(style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color.accentColor.opacity(0.6), Color.accentColor.opacity(0.4)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            )
            .foregroundStyle(.white)
        } else if hint.error != nil {
            Label("Ошибка", systemImage: "exclamationmark.triangle.fill")
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule(style: .continuous)
                        .fill(Color.red.opacity(0.18))
                )
                .foregroundStyle(.red.opacity(0.9))
        } else if hint.lastFinishedAt != nil {
            Label("Подсказка готова", systemImage: "checkmark.seal.fill")
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule(style: .continuous)
                        .fill(Color.green.opacity(0.18))
                )
                .foregroundStyle(Color.green.opacity(0.85))
        } else {
            Label("Выберите сценарий", systemImage: "bolt.horizontal")
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule(style: .continuous)
                        .fill(Color.white.opacity(0.08))
                )
                .foregroundStyle(.secondary)
        }
    }
}

private struct InsightIntentCard: View {
    let intent: HintAgent.Intent
    let isSelected: Bool
    let isDimmed: Bool
    var action: () -> Void

    private var titleFont: Font {
        .system(size: 15, weight: .semibold, design: .rounded)
    }

    private var descriptionFont: Font {
        .system(size: 12, weight: .medium, design: .default)
    }

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .center, spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(isSelected ? 0.25 : 0.08))
                            .frame(width: 34, height: 34)
                            .overlay(
                                Circle()
                                    .stroke(Color.white.opacity(isSelected ? 0.4 : 0.16), lineWidth: 1)
                            )

                        Image(systemName: intent.symbolName)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(isSelected ? Color.white : Color.primary)
                    }

                    Spacer(minLength: 8)

                    if isSelected {
                        Label("Выбрано", systemImage: "checkmark.circle.fill")
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(Color.white.opacity(0.18))
                            )
                            .foregroundStyle(Color.white)
                            .transition(.opacity.combined(with: .scale))
                    } else {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(intent.buttonTitle)
                        .font(titleFont)
                        .fixedSize(horizontal: false, vertical: true)
                        .foregroundStyle(Color.white.opacity(isSelected ? 0.95 : 1))

                    Text(intent.strapline)
                        .font(descriptionFont)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(background)
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(Color.white.opacity(isSelected ? 0.5 : 0.14), lineWidth: isSelected ? 1.4 : 1)
            )
        }
        .buttonStyle(.plain)
        .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .opacity(isDimmed ? 0.55 : 1)
        .shadow(color: Color.black.opacity(isSelected ? 0.22 : 0.08), radius: isSelected ? 20 : 10, x: 0, y: isSelected ? 12 : 6)
        .scaleEffect(isSelected ? 1.02 : 1.0)
    }

    private var background: some View {
        let shape = RoundedRectangle(cornerRadius: 22, style: .continuous)

        return shape
            .fill(
                LinearGradient(
                    colors: gradientColors,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
    }

    private var gradientColors: [Color] {
        if isSelected {
            return [
                Color.accentColor.opacity(0.55),
                Color.accentColor.opacity(0.32)
            ]
        } else {
            return [
                Color.white.opacity(0.09),
                Color.white.opacity(0.03)
            ]
        }
    }
}

#if os(macOS)
import AppKit
#endif
