//
//  LiveDot.swift
//  GHOSTDeskUI
//
//  Created by Shamil on 30.09.2025.
//

import SwiftUI

public struct LiveDot: View {
    public var active: Bool
    @State private var pulse = false

    public init(active: Bool) { self.active = active }

    public var body: some View {
        Circle()
            .fill(active ? Color.red : .gray)
            .frame(width: 7, height: 7)
            .opacity(active ? (pulse ? 0.35 : 1) : 0.4)
            .onAppear {
                guard active else { return }
                withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                    pulse = true
                }
            }
            .onChange(of: active) { newVal in
                if newVal {
                    withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                        pulse = true
                    }
                } else {
                    pulse = false
                }
            }
    }
}
