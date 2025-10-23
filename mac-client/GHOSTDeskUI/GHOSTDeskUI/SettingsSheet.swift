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

    private var expiresDescription: String {
        guard let expiresAt = auth.expiresAt else { return "Не установлено" }
        return expiresAt.formatted(date: .abbreviated, time: .shortened)
    }

    private var createdDescription: String {
        guard let createdAt = auth.createdAt else { return "Неизвестно" }
        return createdAt.formatted(date: .abbreviated, time: .shortened)
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

                VStack(alignment: .leading, spacing: 18) {
                    HStack(spacing: 12) {
                        statusChip(systemImage: auth.isAuthorized ? "checkmark.seal.fill" : "exclamationmark.triangle.fill",
                                   title: auth.isAuthorized ? "Авторизовано" : "Нет сессии",
                                   tint: auth.isAuthorized ? .green : .orange)

                        statusChip(systemImage: "calendar",
                                   title: "Действует до: \(expiresDescription)",
                                   tint: .blue)
                    }

                    if let message = auth.authorizationIssue {
                        Text(message)
                            .font(.system(size: 13, weight: .regular, design: .rounded))
                            .foregroundStyle(.red)
                    }

                    Divider()

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Профиль")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))

                        if let profileToken = auth.profileToken {
                            Label {
                                Text("Токен: \(profileToken)")
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            } icon: {
                                Image(systemName: "person.text.rectangle")
                            }
                            .font(.system(size: 13, weight: .regular, design: .rounded))
                        } else {
                            Label("Токен не найден", systemImage: "person.text.rectangle")
                                .font(.system(size: 13, weight: .regular, design: .rounded))
                                .foregroundStyle(.secondary)
                        }

                        if let plan = auth.plan {
                            Label("Тариф: \(plan)", systemImage: "creditcard")
                                .font(.system(size: 13, weight: .regular, design: .rounded))
                        } else {
                            Label("Тариф не определён", systemImage: "creditcard")
                                .font(.system(size: 13, weight: .regular, design: .rounded))
                                .foregroundStyle(.secondary)
                        }

                        if let referral = auth.referral, !referral.isEmpty {
                            Label("Реферал: \(referral)", systemImage: "gift")
                                .font(.system(size: 13, weight: .regular, design: .rounded))
                        } else {
                            Label("Реферальный код отсутствует", systemImage: "gift")
                                .font(.system(size: 13, weight: .regular, design: .rounded))
                                .foregroundStyle(.secondary)
                        }

                        Label("Создан: \(createdDescription)", systemImage: "calendar.badge.clock")
                            .font(.system(size: 13, weight: .regular, design: .rounded))
                    }

                    Spacer()

                    HStack(spacing: 12) {
                        Button("Обновить данные") {
                            auth.restoreSession()
                        }
                            .buttonStyle(.bordered)

                        Button("Выйти", role: .destructive) {
                            auth.signOut()
                            withAnimation(.spring) {
                                isShown = false
                            }
                        }
                            .buttonStyle(.borderedProminent)

                        Spacer()
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .frame(width: 360, alignment: .topTrailing)
        .padding(.top, 10)
        .padding(.trailing, 16)
        .transition(.opacity.combined(with: .scale(scale: 0.97, anchor: .topTrailing)))
        .accessibilityElement(children: .contain)
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
