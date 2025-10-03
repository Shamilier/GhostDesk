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

                // Info/placeholder content
                Text("Здесь появятся настройки сервера, токена, звука и другие опции.")
                    .font(.system(size: 15, weight: .regular, design: .rounded))
                    .foregroundStyle(.secondary)
                    .padding(.top, -6)
                    .padding(.trailing, 2)

                Spacer()
            }
            .padding(.all, 22)
        }
        .frame(width: 340, height: 220, alignment: .topTrailing)
        .padding(.top, 10)
        .padding(.trailing, 16)
        .transition(.opacity.combined(with: .scale(scale: 0.97, anchor: .topTrailing)))
        .accessibilityElement(children: .contain)
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
