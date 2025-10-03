//
//  CopiedToast.swift
//  GHOSTDeskUI
//
//  Created by Shamil on 30.09.2025.
//

import SwiftUI

public struct CopiedToast: View {
    public init() {}

    public var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
            Text("Скопировано").font(.subheadline.weight(.semibold))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().stroke(.white.opacity(0.25), lineWidth: 1))
        .shadow(color: .black.opacity(0.2), radius: 12, x: 0, y: 6)
    }
}
