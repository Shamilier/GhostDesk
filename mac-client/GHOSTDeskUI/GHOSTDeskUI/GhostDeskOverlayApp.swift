import SwiftUI
import AppKit

@main
struct GhostDeskOverlayApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var model = OverlayModel.shared
    @StateObject private var auth = AuthState()

    var body: some Scene {
        // создаём пустое невидимое окно-сцены, панель показываем сами
        WindowGroup {
            Color.clear.frame(width: 1, height: 1)
                .onAppear {
                    appDelegate.authState = auth
                }
        }
        .windowStyle(.hiddenTitleBar)
        .onChange(of: model.isOverlayVisible) { visible in   // старая сигнатура — без двусмысленностей
            if visible { OverlayWindowManager.shared.show(model: model, auth: auth) }
            else { OverlayWindowManager.shared.hide() }
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    var authState: AuthState? {
        didSet {
            oauthCoordinator.configure(authState: authState)
            attemptInitialShowIfNeeded()
        }
    }
    private let oauthCoordinator = OAuthCoordinator.shared
    private var pendingInitialShow = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)        // LSUIElement-поведение
        let model = OverlayModel.shared
        pendingInitialShow = true
        attemptInitialShowIfNeeded()
        HotKeyManager.shared.registerDefaultHotkeys()
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationWillTerminate(_ notification: Notification) {
        HotKeyManager.shared.unregisterAll()
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            if handleIncoming(url: url) { break }
        }
    }

    private func attemptInitialShowIfNeeded() {
        guard pendingInitialShow, let authState else { return }
        pendingInitialShow = false
        OverlayWindowManager.shared.show(model: OverlayModel.shared, auth: authState)
    }

    private func handleIncoming(url: URL) -> Bool {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              components.scheme == "ghostdesk",
              components.host == "auth",
              components.path == "/callback",
              let code = components.queryItems?.first(where: { $0.name == "code" })?.value,
              let state = components.queryItems?.first(where: { $0.name == "state" })?.value else {
            return false
        }

        oauthCoordinator.handleCallback(code: code, state: state)
        return true
    }
}
