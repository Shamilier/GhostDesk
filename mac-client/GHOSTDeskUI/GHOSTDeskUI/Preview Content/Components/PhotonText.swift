//
//  PhotonText..swift
//  GHOSTDeskUI
//
//  Created by Shamil on 30.09.2025.
//

import SwiftUI

public struct PhotonText: View {
    public var text: String
    public init(_ text: String) { self.text = text }

    public var body: some View {
        Text(text)
            .foregroundStyle(
                LinearGradient(
                    colors: [.primary.opacity(0.98), .primary.opacity(0.85)],
                    startPoint: .top, endPoint: .bottom
                )
            )
            .shadow(color: .accentColor.opacity(0.35), radius: 6, x: 0, y: 0)
            .shadow(color: .accentColor.opacity(0.18), radius: 16, x: 0, y: 0)
            .shadow(color: .accentColor.opacity(0.08), radius: 30, x: 0, y: 0)
    }
}
