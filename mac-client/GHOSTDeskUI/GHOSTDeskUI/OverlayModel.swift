import Foundation
import AppKit
import Combine

final class OverlayModel: ObservableObject {
    static let shared = OverlayModel()

    @Published var isRecording: Bool = false
    @Published var transcriptLog: [String] = []
    @Published var partialText: String = ""
    @Published var lastError: String? = nil

    @Published private(set) var systemMessages: [TranscriptMessage] = []
    @Published private(set) var microphoneMessages: [TranscriptMessage] = []

    // Видимость/поведение
    @Published var isOverlayVisible: Bool = true
    @Published var isFocusable: Bool = true
    @Published var transparencyIndex: Int = 1     // 0…5
    @Published var fontScaleIndex: Int = 1        // 0…5

    // Левый блок (заглушки)
    @Published var proLevel: String = "PRO"
    @Published var audioMinutesLeft: Int = 14
    @Published var hintsLeft: Int = 73

    // Нижняя панель (заглушки)
    @Published var isAutoHints: Bool = false

    // Настройки
    @Published var showSettings: Bool = false
    

    // Константы
    let transparencySteps: [CGFloat] = [1.0, 0.9, 0.8, 0.7, 0.6, 0.5]
    let fontScaleSteps: [CGFloat]     = [0.9, 1.0, 1.15, 1.3, 1.5, 1.7]
    let moveStep: CGFloat = 10.0
    private let maxTranscriptMessages = 500

    // Вычисляемые
    var alpha: CGFloat { transparencySteps[clamp(transparencyIndex, 0, transparencySteps.count - 1)] }
    var fontScale: CGFloat { fontScaleSteps[clamp(fontScaleIndex, 0, fontScaleSteps.count - 1)] }

    // MARK: helpers/actions
    func clamp(_ v: Int, _ lo: Int, _ hi: Int) -> Int { max(lo, min(v, hi)) }

    func resetDefaults() {
        fontScaleIndex = 1
        transparencyIndex = 1
        if let screen = NSScreen.main { OverlayWindowManager.shared.center(on: screen) }
    }

    func startStopRecording() {
        isRecording.toggle()
        ServerClient.shared.log("[STUB] recording = \(isRecording ? "on" : "off")")
    }
    func askHint() {
        Task { await HintAgent.shared.requestHint(windowSeconds: 40, maxChars: 900) }
    }
    func askSolve() {
        ServerClient.shared.log("[STUB] solve: сделать скрин и отправить на бэк (пока нет)")
    }

    @MainActor
    func appendTranscript(_ text: String, from source: TranscriptSource, at timestamp: Date = .init()) {
        let message = TranscriptMessage(source: source, text: text, timestamp: timestamp)
        switch source {
        case .system:
            systemMessages.append(message)
            if systemMessages.count > maxTranscriptMessages {
                systemMessages.removeFirst(systemMessages.count - maxTranscriptMessages)
            }
        case .microphone:
            microphoneMessages.append(message)
            if microphoneMessages.count > maxTranscriptMessages {
                microphoneMessages.removeFirst(microphoneMessages.count - maxTranscriptMessages)
            }
        }
    }

    @MainActor
    func clearTranscripts(for source: TranscriptSource? = nil) {
        switch source {
        case .system?:
            systemMessages.removeAll(keepingCapacity: false)
        case .microphone?:
            microphoneMessages.removeAll(keepingCapacity: false)
        case nil:
            systemMessages.removeAll(keepingCapacity: false)
            microphoneMessages.removeAll(keepingCapacity: false)
        }
    }
}
//
// /Users/shamilgaliev18mail.ru/Library/Developer/Xcode/Archives/2025-10-08/Ghost Desk 08.10.2025, 18.34.xcarchive/Products/Applications/Ghost Desk.app



