import SwiftUI

struct FloatingGlassToolbar: View {
    var isRecording: Bool
    @Binding var selected: CommandTab
    @Binding var isExpanded: Bool
    @Binding var query: String
    var onPrimaryTap: () -> Void
    var onEyeTap: () -> Void
    var onMenuTap: () -> Void
    var onSubmit: ((String) -> Void)?

    @Namespace private var glassNamespace
    @State private var queryDraft: String
    @FocusState private var isQueryFocused: Bool
    @Environment(\.colorScheme) private var colorScheme

    init(
        isRecording: Bool,
        selected: Binding<CommandTab>,
        isExpanded: Binding<Bool>,
        query: Binding<String>,
        onPrimaryTap: @escaping () -> Void,
        onEyeTap: @escaping () -> Void,
        onMenuTap: @escaping () -> Void,
        onSubmit: ((String) -> Void)? = nil
    ) {
        self.isRecording = isRecording
        self._selected = selected
        self._isExpanded = isExpanded
        self._query = query
        self.onPrimaryTap = onPrimaryTap
        self.onEyeTap = onEyeTap
        self.onMenuTap = onMenuTap
        self.onSubmit = onSubmit
        _queryDraft = State(initialValue: query.wrappedValue)
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            collapsedBar
                .glassEffectID("toolbar.primary", in: glassNamespace)

            if isExpanded && selected == .ask {
                expandedPanel
                    .glassEffectID("toolbar.expanded", in: glassNamespace)
                    .glassEffectTransition(.matchedGeometry)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .padding(.top, 76)
                    .zIndex(2)
            }
        }
        .frame(maxWidth: 560)
        .padding(.bottom, 24)
        .padding(.horizontal, 24)
        .background(floatingBackground)
        .onChange(of: isExpanded) { expanded in
            withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                if expanded {
                    queryDraft = query
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        isQueryFocused = true
                    }
                } else {
                    isQueryFocused = false
                }
            }
        }
        .onChange(of: queryDraft) { newValue in
            if newValue != query { query = newValue }
        }
        .onChange(of: query) { newValue in
            if newValue != queryDraft { queryDraft = newValue }
        }
    }

    // MARK: - Layers

    private var floatingBackground: some View {
        GeometryReader { proxy in
            let gradient = LinearGradient(
                colors: backgroundColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            ZStack {
                gradient
                gradient
                    .blur(radius: 36)
                    .opacity(0.55)
                radialHighlights(in: proxy.size)
            }
        }
        .allowsHitTesting(false)
    }

    private func radialHighlights(in size: CGSize) -> some View {
        ZStack {
            Circle()
                .fill(Color.white.opacity(0.18))
                .frame(width: size.width * 0.74, height: size.width * 0.74)
                .blur(radius: 140)
                .offset(x: -size.width * 0.32, y: -size.height * 0.22)
            Circle()
                .fill(Color.accentColor.opacity(0.22))
                .frame(width: size.width * 0.46, height: size.width * 0.46)
                .blur(radius: 120)
                .offset(x: size.width * 0.28, y: size.height * 0.28)
        }
    }

    private var collapsedBar: some View {
        GlassEffectContainer {
            HStack(spacing: 12) {
                statusBadge
                    .glassEffectUnion(Circle(), id: "toolbar.recording", in: glassNamespace, highlight: Color.white.opacity(0.3))

                commandSelector
                    .frame(maxWidth: 220)

                Spacer(minLength: 0)

                Button(action: toggleAskPanel) {
                    let isShowingAsk = isExpanded && selected == .ask
                    Label(isShowingAsk ? "Hide" : "Ask Ghost", systemImage: isShowingAsk ? "chevron.down" : "sparkles")
                        .labelStyle(.titleAndIcon)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .frame(minWidth: 120)
                }
                .buttonStyle(.glassProminent)
                .glassEffectID("toolbar.askButton", in: glassNamespace)

                Button(action: onEyeTap) {
                    Image(systemName: "eye")
                        .font(.system(size: 14, weight: .semibold))
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(.glass)
                .glassEffectID("toolbar.eye", in: glassNamespace)

                Button(action: onMenuTap) {
                    Image(systemName: "ellipsis")
                        .rotationEffect(.degrees(90))
                        .font(.system(size: 14, weight: .semibold))
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(.glass)
                .glassEffectID("toolbar.menu", in: glassNamespace)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
        }
        .glassEffect(
            material: collapsedMaterial,
            in: Capsule(style: .continuous),
            borderGradient: accentBorderGradient,
            borderColor: Color.white.opacity(colorScheme == .dark ? 0.22 : 0.18),
            lineWidth: 1.05,
            shadowColor: Color.black.opacity(colorScheme == .dark ? 0.55 : 0.28),
            shadowRadius: 22,
            shadowYOffset: 14
        )
        .glassEffectUnion(
            Capsule(style: .continuous),
            id: "toolbar.primary.union",
            in: glassNamespace,
            highlight: Color.white.opacity(colorScheme == .dark ? 0.45 : 0.25)
        )
    }

    private var statusBadge: some View {
        let indicatorColor = isRecording ? Color.red : Color.green
        return ZStack {
            Circle()
                .fill(Color.white.opacity(colorScheme == .dark ? 0.15 : 0.18))
            Circle()
                .fill(indicatorColor.opacity(0.86))
                .frame(width: 12, height: 12)
                .overlay(
                    Circle().stroke(Color.white.opacity(0.65), lineWidth: 0.6)
                )
                .shadow(color: indicatorColor.opacity(0.45), radius: 10, y: 4)
        }
        .frame(width: 36, height: 36)
        .overlay(
            Circle()
                .stroke(Color.white.opacity(colorScheme == .dark ? 0.35 : 0.24), lineWidth: 0.8)
        )
        .glassEffect(
            material: .ultraThinMaterial,
            in: Circle(),
            borderColor: Color.white.opacity(0.25),
            lineWidth: 0.8,
            shadowColor: Color.black.opacity(0.18),
            shadowRadius: 8,
            shadowYOffset: 4
        )
    }

    private var commandSelector: some View {
        GlassEffectContainer {
            HStack(spacing: 6) {
                commandChip(title: "Listen", systemImage: "waveform", tab: .listen, isActive: selected == .listen)
                commandChip(title: "Ask", systemImage: "bubble.right", tab: .ask, isActive: selected == .ask)
            }
            .padding(6)
            .background(alignment: .leading) {
                if selected == .listen {
                    Capsule()
                        .fill(accentFill(for: .listen))
                        .matchedGeometryEffect(id: "toolbar.command.selection", in: glassNamespace)
                }
                if selected == .ask {
                    Capsule()
                        .fill(accentFill(for: .ask))
                        .matchedGeometryEffect(id: "toolbar.command.selection", in: glassNamespace)
                }
            }
        }
        .glassEffect(
            material: .ultraThinMaterial,
            in: Capsule(style: .continuous),
            borderGradient: accentBorderGradient,
            borderColor: Color.white.opacity(0.2),
            lineWidth: 0.9,
            shadowColor: Color.black.opacity(0.22),
            shadowRadius: 14,
            shadowYOffset: 8
        )
        .glassEffectUnion(
            Capsule(style: .continuous),
            id: "toolbar.command.union",
            in: glassNamespace,
            highlight: Color.white.opacity(colorScheme == .dark ? 0.4 : 0.22)
        )
    }

    private func commandChip(title: String, systemImage: String, tab: CommandTab, isActive: Bool) -> some View {
        Button {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.85)) {
                selected = tab
                if tab == .ask {
                    isExpanded = true
                } else if !isExpanded {
                    isExpanded = true
                }
            }
            onPrimaryTap()
        } label: {
            Label(title, systemImage: systemImage)
                .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .frame(maxWidth: .infinity)
                .contentShape(Capsule())
                .foregroundStyle(isActive ? Color.white : Color.white.opacity(0.88))
                .opacity(isActive ? 1 : 0.82)
        }
        .buttonStyle(.plain)
        .background(
            Capsule()
                .fill(isActive ? Color.clear : Color.white.opacity(colorScheme == .dark ? 0.16 : 0.12))
        )
        .overlay(
            Capsule()
                .stroke(Color.white.opacity(isActive ? 0.5 : 0.18), lineWidth: 0.7)
        )
        .accessibilityAddTraits(isActive ? .isSelected : [])
    }

    private var expandedPanel: some View {
        GlassEffectContainer {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .center, spacing: 12) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.accentColor)
                        .frame(width: 28, height: 28)
                        .glassEffect(
                            material: .ultraThinMaterial,
                            in: Circle(),
                            borderColor: Color.white.opacity(0.22),
                            lineWidth: 0.7,
                            shadowColor: Color.black.opacity(0.15),
                            shadowRadius: 6,
                            shadowYOffset: 4
                        )

                    TextField("Ask Ghost anything…", text: $queryDraft, axis: .vertical)
                        .textFieldStyle(.plain)
                        .font(.system(size: 14.5, weight: .regular, design: .rounded))
                        .focused($isQueryFocused)
                        .lineLimit(2...4)
                        .padding(.vertical, 8)

                    if !queryDraft.isEmpty {
                        Button(action: { queryDraft = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 14, weight: .semibold))
                                .symbolRenderingMode(.hierarchical)
                                .foregroundStyle(Color.white.opacity(0.9))
                        }
                        .buttonStyle(.glass)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(Color.white.opacity(colorScheme == .dark ? 0.12 : 0.16))
                        .blur(radius: 0.4)
                )
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(Color.white.opacity(0.18), lineWidth: 0.7)
                )

                HStack(spacing: 12) {
                    quickActionButton(title: "Summarize", systemImage: "text.quote")
                    quickActionButton(title: "Action Items", systemImage: "list.clipboard")
                    quickActionButton(title: "Outline", systemImage: "list.bullet.rectangle")
                    Button(action: submitQuery) {
                        Label("Send", systemImage: "paperplane.fill")
                            .font(.system(size: 13.5, weight: .semibold, design: .rounded))
                    }
                    .buttonStyle(.glassProminent)
                    .disabled(queryDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .padding(24)
        }
        .glassEffect(
            material: .regularMaterial,
            in: RoundedRectangle(cornerRadius: 30, style: .continuous),
            borderGradient: accentBorderGradient,
            borderColor: Color.white.opacity(colorScheme == .dark ? 0.28 : 0.2),
            lineWidth: 1.1,
            shadowColor: Color.black.opacity(colorScheme == .dark ? 0.48 : 0.22),
            shadowRadius: 28,
            shadowYOffset: 18
        )
        .glassEffectUnion(
            RoundedRectangle(cornerRadius: 30, style: .continuous),
            id: "toolbar.expanded.union",
            in: glassNamespace,
            highlight: Color.white.opacity(colorScheme == .dark ? 0.45 : 0.28)
        )
    }

    private func quickActionButton(title: String, systemImage: String) -> some View {
        Button {
            queryDraft = title + " "
            withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                isExpanded = true
                selected = .ask
            }
            onPrimaryTap()
        } label: {
            Label(title, systemImage: systemImage)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
        }
        .buttonStyle(.glass)
    }

    private func submitQuery() {
        let trimmed = queryDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        onSubmit?(trimmed)
        withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
            isExpanded = false
        }
    }

    private func toggleAskPanel() {
        var shouldNotify = false
        withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
            if selected == .ask && isExpanded {
                isExpanded = false
            } else {
                selected = .ask
                isExpanded = true
                shouldNotify = true
            }
        }
        if shouldNotify {
            onPrimaryTap()
        }
    }

    private var backgroundColors: [Color] {
        if colorScheme == .dark {
            return [
                Color(red: 0.07, green: 0.09, blue: 0.14),
                Color(red: 0.10, green: 0.14, blue: 0.21),
                Color(red: 0.05, green: 0.07, blue: 0.13)
            ]
        } else {
            return [
                Color(red: 0.82, green: 0.88, blue: 1.0),
                Color(red: 0.74, green: 0.82, blue: 1.0),
                Color(red: 0.92, green: 0.96, blue: 1.0)
            ]
        }
    }

    private var accentBorderGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color.white.opacity(colorScheme == .dark ? 0.7 : 0.55),
                Color.white.opacity(colorScheme == .dark ? 0.25 : 0.18)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private func accentFill(for tab: CommandTab) -> LinearGradient {
        let base = Color.accentColor
        let end = Color.accentColor.opacity(colorScheme == .dark ? 0.75 : 0.65)
        return LinearGradient(colors: [base, end], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    private var collapsedMaterial: Material {
        if colorScheme == .dark {
            return .ultraThinMaterial
        } else {
            return .thinMaterial
        }
    }
}

// MARK: - Glass Effect Infrastructure

private struct GlassEffectContainer<Content: View>: View {
    @ViewBuilder private var content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View { content }
}

private struct GlassEffectModifier<S: InsettableShape>: ViewModifier {
    let material: AnyShapeStyle
    let shape: S
    let borderGradient: LinearGradient?
    let borderColor: Color
    let lineWidth: CGFloat
    let shadowColor: Color
    let shadowRadius: CGFloat
    let shadowYOffset: CGFloat

    func body(content: Content) -> some View {
        let borderStyle = borderGradient.map(AnyShapeStyle.init) ?? AnyShapeStyle(borderColor)
        return content
            .background(material, in: shape)
            .overlay(
                shape.stroke(borderStyle, lineWidth: lineWidth)
                    .blendMode(.overlay)
            )
            .shadow(color: shadowColor.opacity(shadowRadius > 0 ? 1 : 0), radius: shadowRadius, y: shadowYOffset)
    }
}

extension View {
    func glassEffect<S: InsettableShape>(
        material: Material = .ultraThinMaterial,
        in shape: S,
        borderGradient: LinearGradient? = nil,
        borderColor: Color = Color.white.opacity(0.22),
        lineWidth: CGFloat = 1,
        shadowColor: Color = Color.black.opacity(0.25),
        shadowRadius: CGFloat = 16,
        shadowYOffset: CGFloat = 8
    ) -> some View {
        modifier(
            GlassEffectModifier(
                material: AnyShapeStyle(material),
                shape: shape,
                borderGradient: borderGradient,
                borderColor: borderColor,
                lineWidth: lineWidth,
                shadowColor: shadowColor,
                shadowRadius: shadowRadius,
                shadowYOffset: shadowYOffset
            )
        )
    }
}

private struct GlassEffectUnionModifier<S: Shape>: ViewModifier {
    let shape: S
    let highlight: Color
    let id: AnyHashable?
    let namespace: Namespace.ID?

    func body(content: Content) -> some View {
        Group {
            if let id, let namespace {
                content
                    .clipShape(shape)
                    .overlay(
                        shape
                            .stroke(highlight, lineWidth: 0.85)
                            .blendMode(.overlay)
                            .matchedGeometryEffect(id: id, in: namespace, properties: .frame)
                    )
            } else {
                content
                    .clipShape(shape)
                    .overlay(
                        shape
                            .stroke(highlight, lineWidth: 0.85)
                            .blendMode(.overlay)
                    )
            }
        }
    }
}

extension View {
    func glassEffectUnion<S: Shape>(
        _ shape: S,
        id: AnyHashable? = nil,
        in namespace: Namespace.ID? = nil,
        highlight: Color = Color.white.opacity(0.25)
    ) -> some View {
        modifier(
            GlassEffectUnionModifier(
                shape: shape,
                highlight: highlight,
                id: id,
                namespace: namespace
            )
        )
    }
}

enum GlassEffectTransitionStyle {
    case matchedGeometry
    case fade
}

private struct GlassEffectTransitionModifier: ViewModifier {
    let style: GlassEffectTransitionStyle
    let id: AnyHashable?
    let namespace: Namespace.ID?

    func body(content: Content) -> some View {
        Group {
            switch style {
            case .matchedGeometry:
                if let id, let namespace {
                    content
                        .matchedGeometryEffect(id: id, in: namespace, properties: .frame)
                } else {
                    content
                        .transition(.opacity.combined(with: .scale))
                }
            case .fade:
                content
                    .transition(.opacity.combined(with: .scale))
            }
        }
    }
}

extension View {
    func glassEffectTransition(
        _ style: GlassEffectTransitionStyle,
        id: AnyHashable? = nil,
        in namespace: Namespace.ID? = nil
    ) -> some View {
        modifier(
            GlassEffectTransitionModifier(
                style: style,
                id: id,
                namespace: namespace
            )
        )
    }

    func glassEffectID<ID: Hashable>(_ id: ID, in namespace: Namespace.ID) -> some View {
        matchedGeometryEffect(id: id, in: namespace, properties: .frame)
    }
}

// MARK: - Button Style

struct GlassButtonStyle: ButtonStyle {
    var isProminent: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        GlassButton(configuration: configuration, isProminent: isProminent)
    }

    private struct GlassButton: View {
        @Environment(\.colorScheme) private var colorScheme
        @Environment(\.tint) private var tint
        let configuration: Configuration
        var isProminent: Bool

        var body: some View {
            configuration.label
                .padding(.horizontal, isProminent ? 16 : 12)
                .padding(.vertical, isProminent ? 12 : 8)
                .frame(minHeight: isProminent ? 40 : 34)
                .background(background)
                .overlay(border)
                .foregroundStyle(foreground)
                .opacity(configuration.isPressed ? 0.78 : 1)
                .scaleEffect(configuration.isPressed ? 0.97 : 1)
                .animation(.easeOut(duration: 0.14), value: configuration.isPressed)
        }

        private var background: some View {
            RoundedRectangle(cornerRadius: isProminent ? 18 : 16, style: .continuous)
                .fill(backgroundStyle)
                .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.38 : 0.22), radius: isProminent ? 16 : 10, y: isProminent ? 12 : 6)
        }

        private var backgroundStyle: AnyShapeStyle {
            if isProminent {
                let base = tint ?? Color.accentColor
                let gradient = LinearGradient(
                    colors: [
                        base.opacity(colorScheme == .dark ? 0.95 : 1),
                        base.opacity(colorScheme == .dark ? 0.7 : 0.72)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                return AnyShapeStyle(gradient)
            } else {
                return AnyShapeStyle(.ultraThinMaterial)
            }
        }

        private var border: some View {
            RoundedRectangle(cornerRadius: isProminent ? 18 : 16, style: .continuous)
                .stroke(Color.white.opacity(colorScheme == .dark ? (isProminent ? 0.52 : 0.32) : (isProminent ? 0.32 : 0.22)), lineWidth: isProminent ? 1.05 : 0.85)
                .blendMode(.overlay)
        }

        private var foreground: AnyShapeStyle {
            if isProminent {
                return AnyShapeStyle(Color.white)
            } else {
                return AnyShapeStyle(Color.primary)
            }
        }
    }
}

extension ButtonStyle where Self == GlassButtonStyle {
    static var glass: GlassButtonStyle { GlassButtonStyle(isProminent: false) }
    static var glassProminent: GlassButtonStyle { GlassButtonStyle(isProminent: true) }
}

// MARK: - Preview

#if DEBUG
struct FloatingGlassToolbar_Previews: PreviewProvider {
    struct PreviewWrapper: View {
        @State private var selected: CommandTab = .listen
        @State private var isExpanded: Bool = false
        @State private var query: String = ""

        var body: some View {
            FloatingGlassToolbar(
                isRecording: true,
                selected: $selected,
                isExpanded: $isExpanded,
                query: $query,
                onPrimaryTap: {},
                onEyeTap: { withAnimation { isExpanded.toggle() } },
                onMenuTap: { withAnimation { selected = .settings } },
                onSubmit: { _ in }
            )
            .frame(height: 400)
            .previewLayout(.sizeThatFits)
        }
    }

    static var previews: some View {
        Group {
            PreviewWrapper()
                .environment(\.colorScheme, .dark)
            PreviewWrapper()
                .environment(\.colorScheme, .light)
        }
    }
}
#endif
