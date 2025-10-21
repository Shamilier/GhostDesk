//import Foundation
//
///// Потокобезопасный буфер последних реплик с таймстемпами.
///// Хранит подтверждённые куски и актуальный partial-хвост.
//final class TranscriptBuffer {
//    static let shared = TranscriptBuffer()
//    private init() {}
//
//    private struct Item { let t: Date; let text: String }
//    private let q = DispatchQueue(label: "TranscriptBuffer.q", qos: .userInitiated)
//    private var items: [Item] = []
//    private var partial: Item? = nil
//
//    /// Добавить подтверждённый (final) текст
//    func appendFinal(_ text: String, at time: Date = .init()) {
//        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
//        guard !clean.isEmpty else { return }
//        q.async {
//            self.items.append(.init(t: time, text: clean))
//            // ограничим рост буфера (по числу элементов)
//            if self.items.count > 500 { self.items.removeFirst(self.items.count - 500) }
//            self.partial = nil // сбрасываем текущий хвост
//        }
//    }
//
//    /// Обновить текущий partial (неподтверждённый) текст
//    func setPartial(_ text: String, at time: Date = .init()) {
//        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
//        q.async {
//            self.partial = clean.isEmpty ? nil : .init(t: time, text: clean)
//        }
//    }
//
//    /// Хвост за N секунд, с жёстной усечкой по символам.
//    func tail(lastSeconds: Int = 40, maxChars: Int = 900) -> String {
//        let now = Date()
//        return q.sync {
//            let cut = now.addingTimeInterval(TimeInterval(-lastSeconds))
//            var chunks = items.filter { $0.t >= cut }.map { $0.text }
//            if let p = partial, p.t >= cut { chunks.append(p.text) }
//            var s = chunks.joined(separator: " ")
//            if s.count > maxChars {
//                s = String(s.suffix(maxChars))
//            }
//            return s.trimmingCharacters(in: .whitespacesAndNewlines)
//        }
//    }
//
//    func clear() {
//        q.async {
//            self.items.removeAll(keepingCapacity: false)
//            self.partial = nil
//        }
//    }
//}
//
