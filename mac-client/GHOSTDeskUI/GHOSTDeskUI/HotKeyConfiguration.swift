import Foundation
import AppKit
import Combine
import Carbon.HIToolbox

struct HotKeyCombination: Codable {
    var keyCode: UInt16
    private var modifiersRaw: UInt
    var keyEquivalent: String

    init(keyCode: UInt16, modifiers: NSEvent.ModifierFlags = [], keyEquivalent: String? = nil) {
        self.keyCode = keyCode
        let sanitized = modifiers.sanitizedForHotKey()
        self.modifiersRaw = sanitized.rawValue
        if let keyEquivalent, !keyEquivalent.isEmpty {
            self.keyEquivalent = keyEquivalent
        } else {
            self.keyEquivalent = HotKeyCombination.symbol(for: keyCode)
        }
    }

    var modifiers: NSEvent.ModifierFlags {
        get { NSEvent.ModifierFlags(rawValue: modifiersRaw) }
        set { modifiersRaw = newValue.sanitizedForHotKey().rawValue }
    }

    var carbonModifiers: UInt32 {
        var mods = UInt32(cmdKey)
        let flags = modifiers
        if flags.contains(.shift) { mods |= UInt32(shiftKey) }
        if flags.contains(.option) { mods |= UInt32(optionKey) }
        if flags.contains(.control) { mods |= UInt32(controlKey) }
        return mods
    }

    var displayString: String {
        (["⌘"] + displayKeyParts).joined()
    }

    var displayKeyParts: [String] {
        modifierSymbols + [mainKeySymbol]
    }

    var modifierSymbols: [String] {
        var symbols: [String] = []
        let flags = modifiers
        if flags.contains(.shift) { symbols.append("⇧") }
        if flags.contains(.option) { symbols.append("⌥") }
        if flags.contains(.control) { symbols.append("⌃") }
        return symbols
    }

    var mainKeySymbol: String { Self.format(keyEquivalent) }

    static func symbol(for keyCode: UInt16) -> String {
        if let mapped = keySymbols[keyCode] { return mapped }
        return "#\(keyCode)"
    }

    private static func format(_ key: String) -> String {
        guard key.count == 1 else { return key }
        if let scalar = key.unicodeScalars.first, CharacterSet.letters.contains(scalar) {
            return key.uppercased()
        }
        return key
    }

    private static let keySymbols: [UInt16: String] = {
        var map: [UInt16: String] = [:]
        map[UInt16(kVK_ANSI_0)] = "0"
        map[UInt16(kVK_ANSI_1)] = "1"
        map[UInt16(kVK_ANSI_2)] = "2"
        map[UInt16(kVK_ANSI_3)] = "3"
        map[UInt16(kVK_ANSI_4)] = "4"
        map[UInt16(kVK_ANSI_5)] = "5"
        map[UInt16(kVK_ANSI_6)] = "6"
        map[UInt16(kVK_ANSI_7)] = "7"
        map[UInt16(kVK_ANSI_8)] = "8"
        map[UInt16(kVK_ANSI_9)] = "9"
        map[UInt16(kVK_ANSI_A)] = "A"
        map[UInt16(kVK_ANSI_B)] = "B"
        map[UInt16(kVK_ANSI_C)] = "C"
        map[UInt16(kVK_ANSI_D)] = "D"
        map[UInt16(kVK_ANSI_E)] = "E"
        map[UInt16(kVK_ANSI_F)] = "F"
        map[UInt16(kVK_ANSI_G)] = "G"
        map[UInt16(kVK_ANSI_H)] = "H"
        map[UInt16(kVK_ANSI_I)] = "I"
        map[UInt16(kVK_ANSI_J)] = "J"
        map[UInt16(kVK_ANSI_K)] = "K"
        map[UInt16(kVK_ANSI_L)] = "L"
        map[UInt16(kVK_ANSI_M)] = "M"
        map[UInt16(kVK_ANSI_N)] = "N"
        map[UInt16(kVK_ANSI_O)] = "O"
        map[UInt16(kVK_ANSI_P)] = "P"
        map[UInt16(kVK_ANSI_Q)] = "Q"
        map[UInt16(kVK_ANSI_R)] = "R"
        map[UInt16(kVK_ANSI_S)] = "S"
        map[UInt16(kVK_ANSI_T)] = "T"
        map[UInt16(kVK_ANSI_U)] = "U"
        map[UInt16(kVK_ANSI_V)] = "V"
        map[UInt16(kVK_ANSI_W)] = "W"
        map[UInt16(kVK_ANSI_X)] = "X"
        map[UInt16(kVK_ANSI_Y)] = "Y"
        map[UInt16(kVK_ANSI_Z)] = "Z"
        map[UInt16(kVK_ANSI_Equal)] = "="
        map[UInt16(kVK_ANSI_Minus)] = "-"
        map[UInt16(kVK_ANSI_LeftBracket)] = "["
        map[UInt16(kVK_ANSI_RightBracket)] = "]"
        map[UInt16(kVK_ANSI_Backslash)] = "\\"
        map[UInt16(kVK_ANSI_Semicolon)] = ";"
        map[UInt16(kVK_ANSI_Quote)] = "'"
        map[UInt16(kVK_ANSI_Comma)] = ","
        map[UInt16(kVK_ANSI_Period)] = "."
        map[UInt16(kVK_ANSI_Slash)] = "/"
        map[UInt16(kVK_ANSI_Grave)] = "`"
        map[UInt16(kVK_LeftArrow)] = "←"
        map[UInt16(kVK_RightArrow)] = "→"
        map[UInt16(kVK_UpArrow)] = "↑"
        map[UInt16(kVK_DownArrow)] = "↓"
        return map
    }()
}

extension HotKeyCombination: Equatable {
    static func == (lhs: HotKeyCombination, rhs: HotKeyCombination) -> Bool {
        lhs.keyCode == rhs.keyCode && lhs.modifiersRaw == rhs.modifiersRaw
    }
}

enum HotKeyAction: String, CaseIterable, Identifiable {
    case toggleOverlay
    case toggleFocus
    case resetPosition
    case toggleRecording
    case askHint
    case askSolve
    case transparencyDecrease
    case transparencyIncrease
    case fontDecrease
    case fontIncrease
    case nudgeLeft
    case nudgeRight
    case nudgeUp
    case nudgeDown

    var id: String { rawValue }

    var title: String {
        switch self {
        case .toggleOverlay: return "Показать/скрыть панель"
        case .toggleFocus: return "Фокус окна"
        case .resetPosition: return "Сбросить позицию"
        case .toggleRecording: return "Запись аудио"
        case .askHint: return "Подсказать"
        case .askSolve: return "Решить"
        case .transparencyDecrease: return "Уменьшить прозрачность"
        case .transparencyIncrease: return "Увеличить прозрачность"
        case .fontDecrease: return "Уменьшить шрифт"
        case .fontIncrease: return "Увеличить шрифт"
        case .nudgeLeft: return "Сдвинуть влево"
        case .nudgeRight: return "Сдвинуть вправо"
        case .nudgeUp: return "Сдвинуть вверх"
        case .nudgeDown: return "Сдвинуть вниз"
        }
    }

    var detail: String? {
        switch self {
        case .toggleOverlay: return "Переключает видимость панели GhostDesk"
        case .toggleFocus: return "Делает окно кликабельным или прозрачным для курсора"
        case .resetPosition: return "Центрирует панель и возвращает параметры по умолчанию"
        case .toggleRecording: return "Запускает или останавливает запись"
        case .askHint: return "Отправляет запрос на подсказку"
        case .askSolve: return "Отправляет запрос на решение"
        case .transparencyDecrease: return "Шагом уменьшает прозрачность панели"
        case .transparencyIncrease: return "Шагом увеличивает прозрачность панели"
        case .fontDecrease: return "Уменьшает размер шрифта"
        case .fontIncrease: return "Увеличивает размер шрифта"
        case .nudgeLeft: return "Сдвигает панель на шаг влево"
        case .nudgeRight: return "Сдвигает панель на шаг вправо"
        case .nudgeUp: return "Сдвигает панель вверх"
        case .nudgeDown: return "Сдвигает панель вниз"
        }
    }

    var defaultCombination: HotKeyCombination {
        switch self {
        case .toggleOverlay: return HotKeyCombination(keyCode: UInt16(kVK_ANSI_1), keyEquivalent: "1")
        case .toggleFocus: return HotKeyCombination(keyCode: UInt16(kVK_ANSI_2), keyEquivalent: "2")
        case .resetPosition: return HotKeyCombination(keyCode: UInt16(kVK_ANSI_3), keyEquivalent: "3")
        case .toggleRecording: return HotKeyCombination(keyCode: UInt16(kVK_ANSI_O), keyEquivalent: "O")
        case .askHint: return HotKeyCombination(keyCode: UInt16(kVK_ANSI_N), keyEquivalent: "N")
        case .askSolve: return HotKeyCombination(keyCode: UInt16(kVK_ANSI_M), keyEquivalent: "M")
        case .transparencyDecrease: return HotKeyCombination(keyCode: UInt16(kVK_ANSI_LeftBracket), keyEquivalent: "[")
        case .transparencyIncrease: return HotKeyCombination(keyCode: UInt16(kVK_ANSI_RightBracket), keyEquivalent: "]")
        case .fontDecrease: return HotKeyCombination(keyCode: UInt16(kVK_ANSI_Minus), keyEquivalent: "-")
        case .fontIncrease: return HotKeyCombination(keyCode: UInt16(kVK_ANSI_Equal), keyEquivalent: "=")
        case .nudgeLeft: return HotKeyCombination(keyCode: UInt16(kVK_LeftArrow), keyEquivalent: "←")
        case .nudgeRight: return HotKeyCombination(keyCode: UInt16(kVK_RightArrow), keyEquivalent: "→")
        case .nudgeUp: return HotKeyCombination(keyCode: UInt16(kVK_UpArrow), keyEquivalent: "↑")
        case .nudgeDown: return HotKeyCombination(keyCode: UInt16(kVK_DownArrow), keyEquivalent: "↓")
        }
    }

    var isEditable: Bool {
        switch self {
        case .toggleOverlay, .toggleFocus, .resetPosition, .toggleRecording, .askHint, .askSolve, .transparencyDecrease, .transparencyIncrease, .fontDecrease, .fontIncrease:
            return true
        case .nudgeLeft, .nudgeRight, .nudgeUp, .nudgeDown:
            return false
        }
    }

    static var editableActions: [HotKeyAction] {
        allCases.filter { $0.isEditable }
    }

    var eventID: UInt32 {
        guard let idx = Self.allCases.firstIndex(of: self) else { return 0 }
        return UInt32(idx + 1)
    }

    func perform() {
        let model = OverlayModel.shared
        switch self {
        case .toggleOverlay:
            let visible = OverlayWindowManager.shared.toggleVisibility()
            model.isOverlayVisible = visible
        case .toggleFocus:
            model.isFocusable.toggle()
            OverlayWindowManager.shared.applyFocus(model.isFocusable)
        case .resetPosition:
            OverlayWindowManager.shared.setAlpha(model.alpha)
            if let screen = NSScreen.main {
                OverlayWindowManager.shared.centerTop(on: screen, topInset: 0, animate: true)
            }
        case .toggleRecording:
            model.startStopRecording()
        case .askHint:
            model.askHint()
        case .askSolve:
            model.askSolve()
        case .transparencyDecrease:
            model.transparencyIndex = max(0, model.transparencyIndex - 1)
            OverlayWindowManager.shared.setAlpha(model.alpha)
        case .transparencyIncrease:
            model.transparencyIndex = min(model.transparencySteps.count - 1, model.transparencyIndex + 1)
            OverlayWindowManager.shared.setAlpha(model.alpha)
        case .fontDecrease:
            model.fontScaleIndex = max(0, model.fontScaleIndex - 1)
        case .fontIncrease:
            model.fontScaleIndex = min(model.fontScaleSteps.count - 1, model.fontScaleIndex + 1)
        case .nudgeLeft:
            OverlayWindowManager.shared.nudge(dx: -model.moveStep, dy: 0)
        case .nudgeRight:
            OverlayWindowManager.shared.nudge(dx: model.moveStep, dy: 0)
        case .nudgeUp:
            OverlayWindowManager.shared.nudge(dx: 0, dy: model.moveStep)
        case .nudgeDown:
            OverlayWindowManager.shared.nudge(dx: 0, dy: -model.moveStep)
        }
    }
}

final class HotKeyPreferences: ObservableObject {
    static let shared = HotKeyPreferences()

    @Published private(set) var combinations: [HotKeyAction: HotKeyCombination]

    private static let storagePrefix = "hotkey.binding."
    private let defaults = UserDefaults.standard

    private init() {
        var map: [HotKeyAction: HotKeyCombination] = [:]
        for action in HotKeyAction.allCases {
            if let stored = Self.loadCombination(for: action) {
                map[action] = stored
            } else {
                map[action] = action.defaultCombination
            }
        }
        combinations = map
    }

    func combination(for action: HotKeyAction) -> HotKeyCombination {
        combinations[action] ?? action.defaultCombination
    }

    @discardableResult
    func update(_ combination: HotKeyCombination, for action: HotKeyAction) -> Bool {
        var newValue = combinations
        newValue[action] = combination
        var fallbacks: [(HotKeyAction, HotKeyCombination)] = []

        for other in HotKeyAction.allCases where other != action {
            guard let existing = newValue[other], existing == combination else { continue }

            if other.isEditable {
                let fallback = other.defaultCombination
                guard fallback != combination else { return false }
                newValue[other] = fallback
                fallbacks.append((other, fallback))
            } else {
                return false
            }
        }

        combinations = newValue
        persist(combination, for: action)
        fallbacks.forEach { persist($0.1, for: $0.0) }
        return true
    }

    func reset(_ action: HotKeyAction) {
        update(action.defaultCombination, for: action)
    }

    private func persist(_ combination: HotKeyCombination, for action: HotKeyAction) {
        let key = Self.storagePrefix + action.rawValue
        if combination == action.defaultCombination {
            defaults.removeObject(forKey: key)
        } else if let data = try? JSONEncoder().encode(combination) {
            defaults.set(data, forKey: key)
        }
    }

    private static func loadCombination(for action: HotKeyAction) -> HotKeyCombination? {
        let defaults = UserDefaults.standard
        let key = storagePrefix + action.rawValue
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(HotKeyCombination.self, from: data)
    }
}

// стало (доступно всему модулю)
extension NSEvent.ModifierFlags {
    /// Нормализуем модификаторы хоткея: оставляем только разрешённые клавиши-модификаторы.
    func sanitizedForHotKey() -> NSEvent.ModifierFlags {
        // Команда у тебя обязательна при захвате, так что имеет смысл её тоже сохранять.
        intersection([.command, .shift, .option, .control, .function, .numericPad])
    }
}
