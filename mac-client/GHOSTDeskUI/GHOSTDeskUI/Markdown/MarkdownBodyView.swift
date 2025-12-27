import MarkdownUI
import SwiftUI

struct MarkdownBodyView: View {
    var markdown: String
    var minHeight: CGFloat = 180
    var maxHeight: CGFloat = 500

    @Environment(\.colorScheme) private var colorScheme

    private var codeBackground: Color {
        colorScheme == .dark ? Color.white.opacity(0.07) : Color.black.opacity(0.05)
    }

    private var codeBorder: Color {
        colorScheme == .dark ? Color.white.opacity(0.14) : Color.black.opacity(0.08)
    }

    var body: some View {
        ScrollView {
            Markdown(markdown)
                .markdownTheme(.ghostDesk(codeBackground: codeBackground, codeBorder: codeBorder))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
        }
        .frame(minHeight: minHeight, maxHeight: maxHeight)
        .animation(nil, value: markdown)
    }
}

private extension MarkdownTheme {
    static func ghostDesk(codeBackground: Color, codeBorder: Color) -> MarkdownTheme {
        MarkdownTheme()
            .text { label in
                label
                    .font(.system(size: 15, weight: .regular, design: .default))
                    .lineSpacing(5)
                    .foregroundStyle(Color.primary.opacity(0.95))
            }
            .strong { label in
                label.fontWeight(.semibold)
            }
            .link { label, _ in
                label
                    .foregroundStyle(.accentColor)
                    .underline()
            }
            .paragraphSpacing(10)
            .listItemSpacing(8)
            .code { label in
                label
                    .font(.system(.body, design: .monospaced))
                    .padding(.vertical, 3)
                    .padding(.horizontal, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(codeBackground)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .stroke(codeBorder, lineWidth: 1)
                    )
            }
            .codeBlock { configuration in
                ScrollView(.horizontal, showsIndicators: true) {
                    Text(verbatim: configuration.content)
                        .font(.system(.body, design: .monospaced))
                        .lineSpacing(4)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: true, vertical: false)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(codeBackground)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(codeBorder, lineWidth: 1)
                )
            }
    }
}
