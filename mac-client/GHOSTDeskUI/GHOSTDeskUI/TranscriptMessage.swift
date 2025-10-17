import Foundation

enum TranscriptSource: String, CaseIterable, Identifiable {
    case system
    case microphone

    var id: String { rawValue }
}

struct TranscriptMessage: Identifiable, Equatable {
    let id: UUID
    let source: TranscriptSource
    let text: String
    let timestamp: Date

    init(id: UUID = UUID(), source: TranscriptSource, text: String, timestamp: Date = .init()) {
        self.id = id
        self.source = source
        self.text = text
        self.timestamp = timestamp
    }
}
