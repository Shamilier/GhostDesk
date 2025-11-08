//
//  LogoOrb.swift
//  GHOSTDeskUI
//
//  Created by Shamil on 30.09.2025.
//

import SwiftUI

public struct LogoOrb: View {
    public init() {}

    public var body: some View {
        ZStack {
            Circle()
                .fill(
                    AngularGradient(
                        gradient: Gradient(colors: [
                            Color.accentColor.opacity(0.7),
                            .purple.opacity(0.7),
                            .blue.opacity(0.7),
                            Color.accentColor.opacity(0.7)
                        ]),
                        center: .center
                    )
                )
                .frame(width: 36, height: 36)
                .blur(radius: 6)
                .opacity(0.6)

            Circle()
                .fill(Color.clear)
                .frame(width: 36, height: 36)
                .liquidGlassBackground(
                    Circle(),
                    highlightOpacity: 0.34,
                    highlightBlur: 38,
                    tint: .gradient(
                        LinearGradient(
                            colors: [
                                Color.accentColor.opacity(0.45),
                                Color.purple.opacity(0.32)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        opacity: 1
                    ),
                    fallbackColor: Color.black.opacity(0.72)
                )
                .overlay {
                    Image(systemName: "waveform")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.primary.opacity(0.9))
                }
                .glassLifted()
        }
    }
}
