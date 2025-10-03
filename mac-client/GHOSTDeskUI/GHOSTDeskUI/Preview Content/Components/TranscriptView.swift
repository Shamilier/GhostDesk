//
//  TranscriptView.swift
//  GHOSTDeskUI
//
//  Created by Shamil on 30.09.2025.
//

import SwiftUI

public struct TranscriptView: View {
    public let logLines: [String]
    public let partial: String
    @Binding public var autoScroll: Bool
    @State private var hasAppeared = false

    public init(
        logLines: [String],
        partial: String,
        autoScroll: Binding<Bool>
    ) {
        self.logLines = logLines
        self.partial = partial
        self._autoScroll = autoScroll
    }

    public var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(0..<logLines.count, id: \.self) { idx in
                        let line = logLines[idx]
                        Text(line)
                            .font(.body)
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .id(idx)
                    }

                    if !partial.isEmpty {
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text("…").foregroundColor(.secondary)
                            Text(partial).italic()
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .id("__partial__")
                    }
                }
                .padding(14)
            }
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
            .onAppear {
                hasAppeared = true
                guard autoScroll else { return }
                withAnimation(.easeOut(duration: 0.2)) {
                    if !partial.isEmpty {
                        proxy.scrollTo("__partial__", anchor: .bottom)
                    } else if let last = (0..<logLines.count).last {
                        proxy.scrollTo(last, anchor: .bottom)
                    }
                }
            }
            .onChange(of: logLines.count) { _ in
                guard autoScroll, hasAppeared else { return }
                withAnimation(.easeOut(duration: 0.2)) {
                    if let last = (0..<logLines.count).last {
                        proxy.scrollTo(last, anchor: .bottom)
                    }
                }
            }
            .onChange(of: partial) { _ in
                guard autoScroll, hasAppeared else { return }
                withAnimation(.easeOut(duration: 0.15)) {
                    proxy.scrollTo("__partial__", anchor: .bottom)
                }
            }
        }
    }
}
