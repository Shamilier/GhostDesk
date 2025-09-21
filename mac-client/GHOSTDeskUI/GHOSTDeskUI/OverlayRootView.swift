//
//  OverlayRootView.swift
//  GHOSTDeskUI
//
//  Created by Danil Bazhitov on 20.09.2025.
//


import SwiftUI

struct OverlayRootView: View {
    @EnvironmentObject var model: OverlayModel

    var body: some View {
        VStack(spacing: 10) {
            topBar
            bottomBar
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.ultraThinMaterial)
                .shadow(radius: 12)
        )
        .overlay( // кнопка настроек
            HStack {
                Spacer()
                Button {
                    model.showSettings.toggle()
                } label: {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 18 * model.fontScale))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(.thinMaterial, in: Capsule())
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 6)
            .padding(.trailing, 6)
            , alignment: .top
        )
        .overlay {
            if model.showSettings {
                SettingsSheet(isShown: $model.showSettings)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .frame(minWidth: 900)
        .environment(\.sizeCategory, .large) // базовый масштаб элементов
    }

    private var topBar: some View {
        HStack(spacing: 10) {
            // Левый блок – заглушки лимитов
            HStack(spacing: 8) {
                Image(systemName: "diamond.fill")
                Image(systemName: "antenna.radiowaves.left.and.right")
                Image(systemName: "mic.fill")
                Text(model.proLevel)
                Text("\(model.audioMinutesLeft)")
                Text("\(model.hintsLeft)")
            }
            .font(.system(size: 12 * model.fontScale, weight: .semibold, design: .rounded))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.black.opacity(0.25), in: Capsule())

            Divider().frame(height: 24)

            ControlGroup(label: "Показать/Скрыть", key: "⌘ 1") {
                let vis = OverlayWindowManager.shared.toggleVisibility()
                model.isOverlayVisible = vis
            }

            ToggleGroup(label: "Фокус", key: "⌘ 2", isOn: model.isFocusable)

            HStack(spacing: 6) {
                ControlGroup(label: "Подвинуть", key: "⌘ ←", action: { HotKeyManager.shared.registerDefaultHotkeys() }).disabled(true)
                shortcutTag("⌘ ↑"); shortcutTag("⌘ ↓"); shortcutTag("⌘ →")
            }

            HStack(spacing: 6) {
                ControlGroup(label: "Масштаб −", key: "⌘ -") {
                    model.fontScaleIndex = max(0, model.fontScaleIndex - 1)
                }
                ControlGroup(label: "Масштаб +", key: "⌘ +") {
                    model.fontScaleIndex = min(model.fontScaleSteps.count-1, model.fontScaleIndex + 1)
                }
            }

            HStack(spacing: 6) {
                ControlGroup(label: "Прозрачность −", key: "⌘ [") {
                    model.transparencyIndex = max(0, model.transparencyIndex - 1)
                    OverlayWindowManager.shared.setAlpha(model.alpha)
                }
                ControlGroup(label: "Прозрачность +", key: "⌘ ]") {
                    model.transparencyIndex = min(model.transparencySteps.count-1, model.transparencyIndex + 1)
                    OverlayWindowManager.shared.setAlpha(model.alpha)
                }
            }

            ControlGroup(label: "Сбросить", key: "⌘ 3") {
                model.resetDefaults()
                OverlayWindowManager.shared.setAlpha(model.alpha)
            }
            .tint(.red)

            Spacer(minLength: 0)
        }
    }

    private var bottomBar: some View {
        HStack(spacing: 10) {
            HStack(spacing: 8) {
                Circle().fill(model.isRecording ? Color.red : Color.gray).frame(width: 10, height: 10)
                Text("00:00")
                ControlGroup(label: model.isRecording ? "Стоп" : "Запись", key: "⌘ O") {
                    model.startStopRecording()
                }
            }
            .font(.system(size: 12 * model.fontScale, weight: .semibold, design: .rounded))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.black.opacity(0.25), in: Capsule())

            ControlGroup(label: "Подсказать", key: "⌘ N") { model.askHint() }
                .tint(.teal)

            ToggleGroup(label: "Авто", key: "⌘ P", isOn: model.isAutoHints) // просто визуальный переключатель
                .tint(.teal)

            ControlGroup(label: "Решить", key: "⌘ M") { model.askSolve() }
                .tint(.orange)

            Spacer(minLength: 0)
        }
    }

    // MARK: - маленькие строительные блоки
    private func shortcutTag(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11 * model.fontScale, weight: .semibold, design: .rounded))
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(Color.black.opacity(0.25), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
    }
}

struct ControlGroup: View {
    let label: String
    let key: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(label)
                shortcutTag(key)
            }
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background(Color.black.opacity(0.25), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .foregroundStyle(.white)
    }

    private func shortcutTag(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .padding(.horizontal, 6).padding(.vertical, 3)
            .background(Color.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
    }
}

struct ToggleGroup: View {
    let label: String
    let key: String
    @State var isOnLocal: Bool = false
    @EnvironmentObject var model: OverlayModel

    init(label: String, key: String, isOn: Bool) {
        self.label = label
        self.key = key
        _isOnLocal = State(initialValue: isOn)
    }

    var body: some View {
        Button {
            isOnLocal.toggle()
            if label == "Фокус" {
                model.isFocusable = isOnLocal
                OverlayWindowManager.shared.applyFocus(model.isFocusable)
            } else if label == "Авто" {
                model.isAutoHints = isOnLocal
            }
        } label: {
            HStack(spacing: 6) {
                Text(label)
                shortcutTag("i")
                Text(isOnLocal ? "on" : "off").foregroundStyle(isOnLocal ? .green : .red)
                shortcutTag(key)
            }
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background(Color.black.opacity(0.25), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .foregroundStyle(.white)
        .onChange(of: model.isFocusable) { _, new in
            if label == "Фокус" { isOnLocal = new }
        }
        .onChange(of: model.isAutoHints) { _, new in
            if label == "Авто" { isOnLocal = new }
        }
    }

    private func shortcutTag(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .padding(.horizontal, 6).padding(.vertical, 3)
            .background(Color.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
    }
}
