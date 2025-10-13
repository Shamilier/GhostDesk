//
//  GlassDesign.swift
//  GHOSTDeskUI
//
//  Created by Shamil on 13.10.2025.
//

// GlassDesign.swift
import SwiftUI

public enum Glass {
    public static let cornerMd: CGFloat = 16
    public static let cornerLg: CGFloat = 24
    public static let capsulePadH: CGFloat = 12
    public static let capsulePadV: CGFloat = 8
    public static let strokeOpacityTop: CGFloat = 0.38
    public static let strokeOpacityBottom: CGFloat = 0.10
    public static let innerStrokeOpacity: CGFloat = 0.09

    public static var stroke: LinearGradient {
        LinearGradient(
            colors: [
                .white.opacity(strokeOpacityTop),
                .white.opacity(strokeOpacityBottom)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    public static func glow(_ tint: Color) -> some View {
        ZStack {
            Color.clear
                .shadow(color: tint.opacity(0.28), radius: 30, x: 0, y: 0)
                .shadow(color: tint.opacity(0.12), radius: 60, x: 0, y: 0)
        }
    }
}

// MARK: - Modifiers

public struct GlassCard: ViewModifier {
    var radius: CGFloat
    var material: Material = .ultraThinMaterial
    public func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(material)
                    .overlay(
                        // внешний «полировочный» штрих
                        RoundedRectangle(cornerRadius: radius, style: .continuous)
                            .stroke(Glass.stroke, lineWidth: 1)
                    )
                    .overlay(
                        // мягкий внутренний штрих, добавляет глубину
                        RoundedRectangle(cornerRadius: radius - 1.5, style: .continuous)
                            .stroke(.white.opacity(Glass.innerStrokeOpacity))
                            .padding(1.5)
                    )
                    .shadow(color: .black.opacity(0.22), radius: 20, x: 0, y: 10)
                    .shadow(color: .black.opacity(0.08), radius: 40, x: 0, y: 0)
            )
    }
}

public struct GlassCapsule: ViewModifier {
    var material: Material = .ultraThinMaterial
    public func body(content: Content) -> some View {
        content
            .background(
                Capsule(style: .continuous)
                    .fill(material)
                    .overlay(Capsule().stroke(Glass.stroke, lineWidth: 1))
                    .overlay(
                        Capsule().stroke(.white.opacity(Glass.innerStrokeOpacity)).padding(1.5)
                    )
                    .shadow(color: .black.opacity(0.18), radius: 16, x: 0, y: 8)
            )
    }
}

public extension View {
    func glassCard(radius: CGFloat = Glass.cornerLg, material: Material = .ultraThinMaterial) -> some View {
        modifier(GlassCard(radius: radius, material: material))
    }
    func glassCapsule(material: Material = .ultraThinMaterial) -> some View {
        modifier(GlassCapsule(material: material))
    }
}

// MARK: - Button styles

public struct PrimaryGlassButton: ButtonStyle {
    var tint: Color = .accentColor
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.primary)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                Capsule(style: .continuous)
                    .fill(.thinMaterial)
                    .overlay(Capsule().stroke(Glass.stroke, lineWidth: 1))
                    .overlay(Glass.glow(tint))
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.spring(response: 0.28, dampingFraction: 0.9), value: configuration.isPressed)
    }
}

public struct GhostIconButton: ButtonStyle {
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .semibold))
            .frame(width: 30, height: 30)
            .background(Circle().fill(.thinMaterial))
            .overlay(Circle().stroke(Glass.stroke, lineWidth: 1))
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .shadow(color: .black.opacity(0.12), radius: 8, x: 0, y: 4)
            .animation(.spring(response: 0.25, dampingFraction: 0.92), value: configuration.isPressed)
    }
}
