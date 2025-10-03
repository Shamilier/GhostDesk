//
//  IconButton.swift
//  GHOSTDeskUI
//
//  Created by Shamil on 30.09.2025.
//

import SwiftUI

public struct IconButton: View {
    public let system: String
    public let action: () -> Void

    public init(system: String, action: @escaping () -> Void) {
        self.system = system
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Image(systemName: system)
                .font(.system(size: 14, weight: .semibold))
                .frame(width: 30, height: 30)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .background(Circle().fill(.thinMaterial))
        .overlay(Circle().stroke(.white.opacity(0.18), lineWidth: 1))
        .shadow(color: .black.opacity(0.12), radius: 8, x: 0, y: 4)
    }
}
