import SwiftUI
#if os(macOS)
import AppKit
#endif

struct ApiKeyGateView: View {
    @EnvironmentObject private var auth: AuthState

    private var isVerifyDisabled: Bool {
        auth.isVerifying || auth.draftKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        ZStack {
            Color.clear
                .background(.ultraThinMaterial)
                .ignoresSafeArea()

            VStack(spacing: 28) {
                VStack(spacing: 12) {
                    Text("Требуется API-ключ GhostDesk")
                        .font(.title2.weight(.semibold))

                    Text("Чтобы продолжить работу, вставьте действующий API-ключ. Получить ключ можно на портале GhostDesk по ссылке ниже.")
                        .multilineTextAlignment(.center)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: 420)
                }

                VStack(alignment: .leading, spacing: 10) {
                    if let message = auth.authorizationIssue {
                        Text(message)
                            .font(.subheadline)
                            .foregroundStyle(.red)
                    }

                    TextField("API-ключ", text: $auth.draftKey, prompt: Text("sk-..."))
                        .textFieldStyle(.roundedBorder)
                        .disabled(auth.isVerifying)
                }
                .frame(maxWidth: 420)

                HStack(spacing: 12) {
                    Button("Получить ключ") {
                        openPortal()
                    }
                    .buttonStyle(.bordered)

                    Spacer()

                    Button(action: verifyDraft) {
                        if auth.isVerifying {
                            HStack(spacing: 8) {
                                ProgressView()
                                    .progressViewStyle(.circular)
                                    .controlSize(.small)
                                Text("Проверяем…")
                            }
                        } else {
                            Text("Проверить ключ")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isVerifyDisabled)
                }
                .frame(maxWidth: 420)
            }
            .padding(32)
            .frame(maxWidth: 560)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color.white.opacity(0.08))
                    .background(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .fill(.thinMaterial)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .stroke(Color.white.opacity(0.18), lineWidth: 1)
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func verifyDraft() {
        Task {
            await auth.verifyDraftKey()
        }
    }

    private func openPortal() {
        guard let url = URL(string: "https://resistible-opinionative-jeanie.ngrok-free.dev") else { return }
        #if os(macOS)
        NSWorkspace.shared.open(url)
        #endif
    }
}
