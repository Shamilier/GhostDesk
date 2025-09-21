//
//  SettingsSheet.swift
//  GHOSTDeskUI
//
//  Created by Danil Bazhitov on 20.09.2025.
//


import SwiftUI

struct SettingsSheet: View {
    @Binding var isShown: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Настройки", systemImage: "slider.horizontal.3")
                    .font(.headline)
                Spacer()
                Button {
                    withAnimation(.spring) { isShown = false }
                } label: { Image(systemName: "xmark.circle.fill").imageScale(.large) }
                .buttonStyle(.plain)
            }
            Divider()
            Text("Тут позже будут реальные опции (сервер, токен, звук и т.д.)")
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(16)
        .frame(width: 360, height: 260)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(radius: 16)
        .padding(.trailing, -380) // имитируем «выезд» справа поверх панели
        .padding(.top, 6)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
    }
}
