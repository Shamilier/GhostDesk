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
            // Panel background with a subtle border and minimal shadow
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(
                            Color.white.opacity(colorScheme == .dark ? 0.08 : 0.13),
                            lineWidth: 1
                        )
                )
                .shadow(color: Color.black.opacity(0.07), radius: 8, y: 2)

            VStack(alignment: .leading, spacing: 26) {
                // Header row
                HStack {
                    Label("Настройки", systemImage: "slider.horizontal.3")
                        .labelStyle(.titleOnly)
                        .font(.system(.title3, design: .rounded).weight(.semibold))
                        .foregroundStyle(.primary)

                    Spacer()
                    CloseCircleButton {
                        withAnimation(.spring) { isShown = false }
                    }
                }
                .padding(.top, 2)

                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("API-ключ")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))

                        TextField("sk-...", text: $auth.draftKey)
                            .textFieldStyle(.roundedBorder)
                            .disabled(auth.isVerifying)
                    }

                    if let message = auth.lastError {
                        Text(message)
                            .font(.system(size: 13, weight: .regular, design: .rounded))
                            .foregroundStyle(.red)
                    }

                    HStack(spacing: 12) {
                        statusChip(systemImage: auth.isVerified ? "checkmark.seal.fill" : "exclamationmark.triangle.fill",
                                   title: auth.isVerified ? "Проверено" : "Не подтверждено",
                                   tint: auth.isVerified ? .green : .orange)

                        statusChip(systemImage: "calendar",
                                   title: "Действует до: \(expiresDescription)",
                                   tint: .blue)
                    }

                    Spacer()

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
                        .disabled(isVerifyDisabled)

                        Button("Сохранить", action: saveDraft)
                            .buttonStyle(.bordered)
                            .disabled(isSaveDisabled)

                        Button("Очистить", action: clearKey)
                            .buttonStyle(.borderless)
                            .disabled(auth.isVerifying)

                        Spacer()
                    }
                }
            }
            .padding(.all, 22)
        }
        .frame(width: 340, height: 220, alignment: .topTrailing)
        .padding(.top, 10)
        .padding(.trailing, 16)
        .transition(.opacity.combined(with: .scale(scale: 0.97, anchor: .topTrailing)))
        .accessibilityElement(children: .contain)
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

    @ViewBuilder
    private func statusChip(systemImage: String, title: String, tint: Color) -> some View {
        Label(title, systemImage: systemImage)
            .font(.system(size: 12, weight: .semibold, design: .rounded))
            .padding(.vertical, 6)
            .padding(.horizontal, 10)
            .background(
                Capsule(style: .continuous)
                    .fill(tint.opacity(colorScheme == .dark ? 0.24 : 0.18))
            )
            .foregroundStyle(tint)
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
