//
//  SegmentedPill.swift
//  GHOSTDeskUI
//
//  Created by Shamil on 30.09.2025.
//

import SwiftUI

public struct SegmentedPill: View {
    public let segments: [String]
    @Binding public var selectedIndex: Int
    public var primaryActionTitle: String
    public var primaryAction: () -> Void

    @Namespace private var ns

    public init(
        segments: [String],
        selectedIndex: Binding<Int>,
        primaryActionTitle: String,
        primaryAction: @escaping () -> Void
    ) {
        self.segments = segments
        self._selectedIndex = selectedIndex
        self.primaryActionTitle = primaryActionTitle
        self.primaryAction = primaryAction
    }

    public var body: some View {
        HStack(spacing: 0) {
            ForEach(segments.indices, id: \.self) { idx in
                Button {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.88)) {
                        selectedIndex = idx
                    }
                } label: {
                    Text(segments[idx])
                        .font(.system(size: 13, weight: .semibold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .frame(height: 32)
                        .frame(minWidth: 90)
                        .contentShape(Rectangle())
                        .foregroundStyle(idx == selectedIndex ? .primary : .secondary)
                        .background(
                            ZStack {
                                if idx == selectedIndex {
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(
                                            LinearGradient(colors: [
                                                Color.accentColor.opacity(0.28),
                                                Color.accentColor.opacity(0.18)
                                            ], startPoint: .topLeading, endPoint: .bottomTrailing)
                                        )
                                        .matchedGeometryEffect(id: "seg", in: ns)
                                }
                            }
                        )
                }
                .buttonStyle(.plain)
                
                if idx < segments.count - 1 {
                    Divider().frame(height: 18).opacity(0.15)
                }
            }
            
            Divider().frame(height: 18).opacity(0.15).padding(.horizontal, 8)
            
            Button(primaryActionTitle) { primaryAction() }
                .buttonStyle(GlassPill(tint: .accentColor))
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.thinMaterial)
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(.white.opacity(0.16), lineWidth: 1))
        )
    }
}
