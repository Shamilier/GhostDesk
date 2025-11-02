import SwiftUI
import AppKit
import Combine   // ← добавить

@main
struct GhostAIOverlayApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings { EmptyView() }   // без WindowGroup — лишнее окно не создаётся
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let oauthCoordinator = OAuthCoordinator.shared
    private let model = OverlayModel.shared
    private let authState = AuthState()
    private let uploadManager = UploadManager.shared

    private var cancellables = Set<AnyCancellable>()  // теперь тип виден

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        oauthCoordinator.configure(authState: authState)
        model.attachAuth(authState)
        uploadManager.attachAuthState(authState)

        authState.$session
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self else { return }
                self.uploadManager.attachAuthState(self.authState)
            }
            .store(in: &cancellables)

        model.$isOverlayVisible
            .receive(on: RunLoop.main)
            .sink { [weak self] visible in
                guard let self else { return }
                if visible {
                    OverlayWindowManager.shared.show(model: self.model, auth: self.authState)
                } else {
                    OverlayWindowManager.shared.hide()
                }
            }
            .store(in: &cancellables)

        // показать при старте
        OverlayWindowManager.shared.show(model: model, auth: authState)

        HotKeyManager.shared.registerDefaultHotkeys()
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationWillTerminate(_ notification: Notification) {
        HotKeyManager.shared.unregisterAll()
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls { if handleIncoming(url: url) { break } }
    }

    func application(_ application: NSApplication, handleEventsForBackgroundURLSession identifier: String, completionHandler: @escaping () -> Void) {
        uploadManager.handleBackgroundEvents(identifier: identifier, completionHandler: completionHandler)
    }

    private func handleIncoming(url: URL) -> Bool {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              components.scheme == "ghostai",
              components.host == "auth",
              components.path == "/callback",
              let code = components.queryItems?.first(where: { $0.name == "code" })?.value,
              let state = components.queryItems?.first(where: { $0.name == "state" })?.value else { return false }
        oauthCoordinator.handleCallback(code: code, state: state)
        return true
    }
}
