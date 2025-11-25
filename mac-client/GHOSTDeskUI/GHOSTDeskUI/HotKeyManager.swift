//
//  HotKeyManager.swift
//  GHOSTDeskUI
//
//  Created by Danil Bazhitov on 20.09.2025.
//


import Cocoa
import Combine
import Carbon.HIToolbox

final class HotKeyManager {
    static let shared = HotKeyManager()

    private var hotKeys: [HotKeyAction: EventHotKeyRef?] = [:]
    private var cancellables: Set<AnyCancellable> = []

    private init() {
        HotKeyPreferences.shared.$combinations
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.applyCurrentBindings()
            }
            .store(in: &cancellables)
    }

    func activate() {
        applyCurrentBindings()
    }

    func unregisterAll() {
        for (_, ref) in hotKeys {
            if let ref { UnregisterEventHotKey(ref) }
        }
        hotKeys.removeAll()
        Self.handlers.removeAll()
    }

    private func applyCurrentBindings() {
        unregisterAll()

        for action in HotKeyAction.allCases {
            let combination = HotKeyPreferences.shared.combination(for: action)
            register(action: action, combination: combination)
        }
    }

    private func register(action: HotKeyAction, combination: HotKeyCombination) {
        var hotKeyRef: EventHotKeyRef?
        let hotKeyID = EventHotKeyID(signature: Self.signature, id: action.eventID)
        let status = RegisterEventHotKey(UInt32(combination.keyCode), combination.carbonModifiers, hotKeyID, GetEventDispatcherTarget(), 0, &hotKeyRef)

        guard status == noErr, let hotKeyRef else {
            NSLog("[HotKeyManager] Unable to register hotkey for \(action.rawValue): status = \(status)")
            return
        }

        hotKeys[action] = hotKeyRef

        if Self.eventHandlerInstalled == false {
            Self.installHandler()
        }
        Self.handlers[hotKeyID.id] = { action.perform() }
    }

    private static let signature = OSType(UInt32(bigEndian: 0x47485354)) // 'GHST'

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
