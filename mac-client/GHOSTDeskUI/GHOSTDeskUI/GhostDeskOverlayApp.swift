import SwiftUI
import AppKit

@main
struct GhostDeskOverlayApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var model = OverlayModel.shared

    var body: some Scene {
        // создаём пустое невидимое окно-сцены, панель показываем сами
        WindowGroup {
            Color.clear.frame(width: 1, height: 1)
        }
        .windowStyle(.hiddenTitleBar)
        .onChange(of: model.isOverlayVisible) { visible in   // старая сигнатура — без двусмысленностей
            if visible { OverlayWindowManager.shared.show(model: model) }
            else { OverlayWindowManager.shared.hide() }
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)        // LSUIElement-поведение
        let model = OverlayModel.shared
        OverlayWindowManager.shared.show(model: model)
        HotKeyManager.shared.registerDefaultHotkeys()
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationWillTerminate(_ notification: Notification) {
        HotKeyManager.shared.unregisterAll()
    }
}
