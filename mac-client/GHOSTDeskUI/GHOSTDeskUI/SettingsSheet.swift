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

    private var sanitizedToken: String? {
        guard let token = auth.profileToken?.trimmingCharacters(in: .whitespacesAndNewlines), !token.isEmpty else {
            return nil
        }
        return token
    }

    private var sanitizedPlan: String? {
        guard let plan = auth.plan?.trimmingCharacters(in: .whitespacesAndNewlines), !plan.isEmpty else {
            return nil
        }
        return plan
    }

    private var sanitizedReferral: String? {
        guard let referral = auth.referral?.trimmingCharacters(in: .whitespacesAndNewlines), !referral.isEmpty else {
            return nil
        }
        return referral
    }

    var body: some View {
        VStack(spacing: 22) {
            header

            VStack(alignment: .leading, spacing: 16) {
                statusSection

                if let message = auth.authorizationIssue {
                    Text(message)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.red.opacity(0.9))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color.red.opacity(colorScheme == .dark ? 0.12 : 0.08))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .stroke(Color.red.opacity(colorScheme == .dark ? 0.25 : 0.18), lineWidth: 1)
                                )
                        )
                }

                profileSection

                actionButtons
            }
        }
        .padding(26)
        .frame(width: 400)
        .background(backgroundDecoration)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(colorScheme == .dark ? 0.08 : 0.12), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.35 : 0.18), radius: 30, y: 16)
        .padding(.top, 12)
        .padding(.trailing, 20)
        .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .topTrailing)))
        .accessibilityElement(children: .contain)
    }

    private var backgroundDecoration: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(
                LinearGradient(colors: [Color.cyan.opacity(0.35), Color.purple.opacity(0.25)],
                               startPoint: .topLeading,
                               endPoint: .bottomTrailing)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Панель управления")
                    .font(.system(size: 18, weight: .bold, design: .rounded))

                Text("Настройте аккаунт и подписку")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 12)

            CloseCircleButton {
                withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                    isShown = false
                }
            }
        }
    }

    private var statusSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Статус")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                statusChip(systemImage: auth.isAuthorized ? "checkmark.seal.fill" : "exclamationmark.triangle.fill",
                           title: auth.isAuthorized ? "Авторизация активна" : "Нет активной сессии",
                           tint: auth.isAuthorized ? .green : .orange)

                statusChip(systemImage: "calendar",
                           title: "Действует до \(expiresDescription)",
                           tint: .blue)
            }
        }
    }

    private var profileSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Аккаунт")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)

            VStack(spacing: 12) {
                infoRow(icon: "person.text.rectangle", title: "Токен", value: sanitizedToken, placeholder: "Не найден")
                infoRow(icon: "creditcard", title: "Тариф", value: sanitizedPlan, placeholder: "Не определён")
                infoRow(icon: "gift", title: "Реферальный код", value: sanitizedReferral, placeholder: "Нет данных")
                infoRow(icon: "calendar.badge.clock", title: "Создан", value: auth.createdAt != nil ? createdDescription : nil, placeholder: "Неизвестно")
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.white.opacity(colorScheme == .dark ? 0.05 : 0.55))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(Color.white.opacity(colorScheme == .dark ? 0.12 : 0.25), lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.25 : 0.12), radius: 14, y: 6)
            )
        }
    }

    private var actionButtons: some View {
        HStack(spacing: 14) {
            Button {
                auth.restoreSession()
            } label: {
                Label("Обновить данные", systemImage: "arrow.clockwise")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .labelStyle(.titleAndIcon)
            }
            .buttonStyle(SecondaryGlassButtonStyle())

            Button(role: .destructive) {
                auth.signOut()
                withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                    isShown = false
                }
            } label: {
                Label("Выйти", systemImage: "rectangle.portrait.and.arrow.forward")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .labelStyle(.titleAndIcon)
            }
            .buttonStyle(PrimaryGlassButtonStyle())

            Spacer()
        }
    }

    @ViewBuilder
    private func statusChip(systemImage: String, title: String, tint: Color) -> some View {
        HStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(tint.opacity(colorScheme == .dark ? 0.22 : 0.18))
                    .frame(width: 26, height: 26)

                Image(systemName: systemImage)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(tint)
            }

            Text(title)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(tint)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 14)
        .background(
            Capsule(style: .continuous)
                .fill(tint.opacity(colorScheme == .dark ? 0.14 : 0.10))
        )
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
                        .fill(
                            LinearGradient(colors: [Color.cyan.opacity(0.32), Color.purple.opacity(0.30)],
                                           startPoint: .topLeading,
                                           endPoint: .bottomTrailing)
                        )
                        .overlay(
                            Circle()
                                .strokeBorder(Color.white.opacity(isHovering ? 0.55 : 0.35), lineWidth: 1)
                        )
                        .shadow(color: Color.purple.opacity(isHovering ? 0.32 : 0.18), radius: isHovering ? 8 : 5, y: isHovering ? 4 : 2)
                )
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in isHovering = hovering }
        .accessibilityLabel("Закрыть")
    }
}

// MARK: - Glass button styles & Info Row

private struct PrimaryGlassButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.vertical, 10)
            .padding(.horizontal, 18)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(
                        LinearGradient(colors: [Color.pink.opacity(0.92), Color.purple.opacity(0.85)],
                                       startPoint: .topLeading,
                                       endPoint: .bottomTrailing)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color.white.opacity(0.35), lineWidth: 1)
                    )
            )
            .foregroundStyle(.white)
            .shadow(color: Color.purple.opacity(configuration.isPressed ? 0.15 : 0.32), radius: configuration.isPressed ? 6 : 16, y: 8)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.75), value: configuration.isPressed)
    }
}

private struct SecondaryGlassButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.vertical, 10)
            .padding(.horizontal, 18)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white.opacity(0.35))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color.white.opacity(0.45), lineWidth: 1)
                    )
            )
            .foregroundStyle(.primary)
            .shadow(color: Color.black.opacity(configuration.isPressed ? 0.10 : 0.18), radius: configuration.isPressed ? 3 : 8, y: 4)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.75), value: configuration.isPressed)
    }
}

private struct InfoIcon: View {
    let systemName: String

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.primary.opacity(0.08))
                .frame(width: 34, height: 34)

            Image(systemName: systemName)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(.primary)
        }
    }
}

private struct InfoRow: View {
    let icon: String
    let title: String
    let value: String
    let isPlaceholder: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            InfoIcon(systemName: icon)

            VStack(alignment: .leading, spacing: 4) {
                Text(title.uppercased())
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)

                Text(value)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(isPlaceholder ? .secondary : .primary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }
    }
}

private extension SettingsSheet {
    func infoRow(icon: String, title: String, value: String?, placeholder: String) -> some View {
        InfoRow(icon: icon,
                title: title,
                value: value ?? placeholder,
                isPlaceholder: value == nil)
    }
}
