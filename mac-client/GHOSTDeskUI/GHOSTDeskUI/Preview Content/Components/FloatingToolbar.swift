import SwiftUI

/// Плавающая капсула-панель а-ля Cluely
public struct FloatingToolbar: View {
    public var isRecording: Bool
    @Binding public var selected: ToolbarTab
    public var onPrimaryTap: () -> Void
    public var onEyeTap: () -> Void
    public var onMenuTap: () -> Void

    public init(
        isRecording: Bool,
        selected: Binding<ToolbarTab>,
        onPrimaryTap: @escaping () -> Void,
        onEyeTap: @escaping () -> Void,
        onMenuTap: @escaping () -> Void
    ) {
        self.isRecording = isRecording
        self._selected = selected
        self.onPrimaryTap = onPrimaryTap
        self.onEyeTap = onEyeTap
        self.onMenuTap = onMenuTap
    }

    public var body: some View {
        HStack(spacing: 10) {
            // Лого-семечко
            Circle()
                .fill(.ultraThinMaterial)
                .overlay(Image(systemName: "bolt.circle").font(.system(size: 16, weight: .semibold)))
                .frame(width: 32, height: 32)

            SegmentedPill(
                segments: ToolbarTab.allCases.map(\.rawValue),
                selectedIndex: Binding(
                    get: { ToolbarTab.allCases.firstIndex(of: selected) ?? 0 },
                    set: { selected = ToolbarTab.allCases[$0] }
                ),
                primaryActionTitle: selected == .listen ? (isRecording ? "Stop" : "Listen") : "Ask"
            ) {
                onPrimaryTap()
            }

            IconButton(system: "eye", action: onEyeTap)
            IconButton(system: "ellipsis", action: onMenuTap)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            Capsule(style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(Capsule().stroke(.white.opacity(0.22), lineWidth: 1))
                .shadow(color: .black.opacity(0.18), radius: 16, x: 0, y: 8)
                .shadow(color: .accentColor.opacity(0.22), radius: 28, x: 0, y: 0)
        )
        .frame(maxWidth: 560) // визуально как в Cluely
    }
}
