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
        .liquidGlassBackground(
            Capsule(style: .continuous),
            highlightOpacity: 0.24,
            highlightBlur: 34,
            tint: .gradient(
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.24),
                        Color.white.opacity(0.06)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                opacity: 1
            ),
            fallbackColor: Color.black.opacity(0.72)
        )
        .glassLifted()
    }
}
