//
//  HotKeyManager.swift
//  GHOSTDeskUI
//
//  Created by Danil Bazhitov on 20.09.2025.
//


import Cocoa
import Carbon.HIToolbox

final class HotKeyManager {
    static let shared = HotKeyManager()
    private init() {}

    private var hotKeys: [EventHotKeyRef?] = []

    func registerDefaultHotkeys() {
        unregisterAll()
        
        // ⌘1 — показать/скрыть
        register(key: kVK_ANSI_1, mods: cmd()) {
            let visible = OverlayWindowManager.shared.toggleVisibility()
            OverlayModel.shared.isOverlayVisible = visible
        }


        // ⌘2 — фокус on/off
        register(key: kVK_ANSI_1, mods: cmd()) {
            let visible = OverlayWindowManager.shared.toggleVisibility()
            OverlayModel.shared.isOverlayVisible = visible
        }

        // ⌘стрелки — подвинуть
        register(key: kVK_LeftArrow,  mods: cmd()) { OverlayWindowManager.shared.nudge(dx: -OverlayModel.shared.moveStep, dy: 0) }
        register(key: kVK_RightArrow, mods: cmd()) { OverlayWindowManager.shared.nudge(dx:  OverlayModel.shared.moveStep, dy: 0) }
        register(key: kVK_UpArrow,    mods: cmd()) { OverlayWindowManager.shared.nudge(dx: 0, dy:  OverlayModel.shared.moveStep) }
        register(key: kVK_DownArrow,  mods: cmd()) { OverlayWindowManager.shared.nudge(dx: 0, dy: -OverlayModel.shared.moveStep) }

        // ⌘- / ⌘+ — масштаб шрифта
        register(key: kVK_ANSI_Minus, mods: cmd()) {
            let m = OverlayModel.shared
            m.fontScaleIndex = max(0, m.fontScaleIndex - 1)
        }
        register(key: kVK_ANSI_Equal, mods: cmd()) { // это клавиша «+» в сочетании с Shift, но ловим равно
            let m = OverlayModel.shared
            m.fontScaleIndex = min(m.fontScaleSteps.count-1, m.fontScaleIndex + 1)
        }

        // ⌘[ / ⌘] — прозрачность
        register(key: kVK_ANSI_LeftBracket,  mods: cmd()) {
            let m = OverlayModel.shared
            m.transparencyIndex = max(0, m.transparencyIndex - 1)
            OverlayWindowManager.shared.setAlpha(m.alpha)
        }
        register(key: kVK_ANSI_RightBracket, mods: cmd()) {
            let m = OverlayModel.shared
            m.transparencyIndex = min(m.transparencySteps.count-1, m.transparencyIndex + 1)
            OverlayWindowManager.shared.setAlpha(m.alpha)
        }

        // ⌘3 — Сброс (центр + дефолт)
        register(key: kVK_ANSI_3, mods: cmd()) {
            let m = OverlayModel.shared
            m.resetDefaults()
            OverlayWindowManager.shared.setAlpha(m.alpha)
        }

        // ⌘O — запись on/off
        register(key: kVK_ANSI_O, mods: cmd()) { OverlayModel.shared.startStopRecording() }

        // ⌘N — «Подсказать»
        register(key: kVK_ANSI_N, mods: cmd()) { OverlayModel.shared.askHint() }

        // ⌘M — «Решить»
        register(key: kVK_ANSI_M, mods: cmd()) { OverlayModel.shared.askSolve() }
    }

    func unregisterAll() {
        for hk in hotKeys where hk != nil {
            UnregisterEventHotKey(hk!)
        }
        hotKeys.removeAll()
    }

    // MARK: - low level
    private func cmd() -> UInt32 { UInt32(cmdKey) }

    private func register(key: Int, mods: UInt32, handler: @escaping () -> Void) {
        var gMyHotKeyRef: EventHotKeyRef?
        let gMyHotKeyID = EventHotKeyID(signature: OSType(UInt32(truncatingIfNeeded: "GHST".hashValue)), id: UInt32(hotKeys.count + 1))

        RegisterEventHotKey(UInt32(key), mods, gMyHotKeyID, GetEventDispatcherTarget(), 0, &gMyHotKeyRef)
        hotKeys.append(gMyHotKeyRef)

        // Устанавливаем глобальный обработчик (единожды)
        if HotKeyManager.eventHandlerInstalled == false {
            HotKeyManager.installHandler()
        }
        HotKeyManager.handlers[gMyHotKeyID.id] = handler
    }

    private static var eventHandlerInstalled = false
    private static var handlers: [UInt32: () -> Void] = [:]

    private static func installHandler() {
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: OSType(kEventHotKeyPressed))
        InstallEventHandler(GetEventDispatcherTarget(), { (_, eventRef, _) -> OSStatus in
            var hkID = EventHotKeyID()
            GetEventParameter(eventRef, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil, MemoryLayout<EventHotKeyID>.size, nil, &hkID)
            if let handler = HotKeyManager.handlers[hkID.id] { handler() }
            return noErr
        }, 1, &eventType, nil, nil)
        eventHandlerInstalled = true
    }
}
