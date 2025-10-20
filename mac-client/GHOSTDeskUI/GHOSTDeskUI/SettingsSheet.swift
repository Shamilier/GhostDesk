//
//  SettingsSheet.swift
//  GHOSTDeskUI
//
//  Created by Danil Bazhitov on 20.09.2025.
//

import SwiftUI

struct SettingsSheet: View {
    @Binding var isShown: Bool
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var auth: AuthState

    private var isSaveDisabled: Bool {
        auth.isVerifying || !auth.isDraftValid
    }

    private var isVerifyDisabled: Bool {
        auth.isVerifying || !auth.isDraftValid
    }

    private var expiresDescription: String {
        guard let expiresAt = auth.expiresAt else { return "Не установлен" }
        return expiresAt.formatted(date: .abbreviated, time: .shortened)
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.white.opacity(colorScheme == .dark ? 0.08 : 0.13), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.07), radius: 8, y: 2)

            VStack(spacing: 0) {
                header

                Divider()
                    .overlay(Color.primary.opacity(0.08))

                content
            }
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .frame(width: 360, alignment: .topTrailing)
        .padding(.top, 10)
        .padding(.trailing, 16)
        .transition(.opacity.combined(with: .scale(scale: 0.97, anchor: .topTrailing)))
        .accessibilityElement(children: .contain)
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "slider.horizontal.3")
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundStyle(.primary.opacity(0.85))

            Text("Настройки")
                .font(.system(.title3, design: .rounded).weight(.semibold))
                .foregroundStyle(.primary)

            Spacer(minLength: 12)

            CloseCircleButton {
                withAnimation(.spring) { isShown = false }
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 18)
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 10) {
                Text("API-ключ")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))

                TextField("sk-...", text: $auth.draftKey)
                    .textFieldStyle(.roundedBorder)
                    .disabled(auth.isVerifying)
                    .font(.system(size: 14, weight: .regular, design: .rounded))
            }

            if let message = auth.lastError {
                Text(message)
                    .font(.system(size: 13, weight: .regular, design: .rounded))
                    .foregroundStyle(.red)
            }

            statusSection

            actionButtons
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 22)
    }

    private var statusSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Статус ключа")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 12) {
                statusRow(
                    title: "Проверка",
                    description: auth.isVerified ? "Ключ подтверждён" : "Не подтверждено",
                    systemImage: auth.isVerified ? "checkmark.shield" : "xmark.shield",
                    tint: auth.isVerified ? .green : .orange
                )

                statusRow(
                    title: "Истекает",
                    description: expiresDescription,
                    systemImage: "calendar.badge.exclamationmark",
                    tint: .blue
                )
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.primary.opacity(colorScheme == .dark ? 0.07 : 0.04))
            )
        }
    }

    private var actionButtons: some View {
        VStack(alignment: .leading, spacing: 14) {
            Divider()
                .overlay(Color.primary.opacity(0.05))

            HStack(spacing: 12) {
                Button(action: verifyKey) {
                    if auth.isVerifying {
                        HStack(spacing: 8) {
                            ProgressView()
                                .progressViewStyle(.circular)
                                .controlSize(.small)
                            Text("Проверяем…")
                        }
                    } else {
                        Text("Проверить")
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
                .disabled(isVerifyDisabled)

                Button("Сохранить", action: saveDraft)
                    .buttonStyle(.bordered)
                    .controlSize(.regular)
                    .disabled(isSaveDisabled)

                Button("Очистить", action: clearKey)
                    .buttonStyle(.borderless)
                    .controlSize(.regular)
                    .disabled(auth.isVerifying)

                Spacer()
            }
        }
    }

    private func verifyKey() {
        Task {
            let success = await auth.verifyKey()
            if success {
                withAnimation(.spring) {
                    isShown = false
                }
            }
        }
    }

    private func saveDraft() {
        auth.updateApiKey(auth.draftKey)
        auth.lastError = nil
    }

    private func clearKey() {
        auth.updateApiKey(nil)
        auth.lastError = nil
    }

    private func statusRow(title: String, description: String, systemImage: String, tint: Color) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(tint.opacity(colorScheme == .dark ? 0.28 : 0.18))
                    .frame(width: 32, height: 32)

                Image(systemName: systemImage)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(tint)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title.uppercased())
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)

                Text(description)
                    .font(.system(size: 13.5, weight: .medium, design: .rounded))
                    .foregroundStyle(.primary)
            }
        }
    }
}


// MARK: - Minimalist Close Button

private struct CloseCircleButton: View {
    var action: () -> Void
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: "xmark")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(.primary)
                .frame(width: 28, height: 28)
                .background(
                    Circle()
                        .fill(.ultraThinMaterial)
                        .overlay(
                            Circle()
                                .stroke(Color.primary.opacity(isHovering ? 0.13 : 0.08), lineWidth: 1)
                        )
                        .shadow(color: Color.black.opacity(isHovering ? 0.10 : 0), radius: 4, y: 1)
                )
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in isHovering = hovering }
        .accessibilityLabel("Закрыть")
    }
}
