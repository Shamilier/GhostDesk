import Foundation
import os.log

final class OutboxService {
    static let shared = OutboxService()

    private let recordingManager: RecordingManager
    private let fileManager = FileManager.default
    private let logger = Logger(subsystem: "ai.ghost.recorder", category: "OutboxService")

    private var pendingIds: Set<String>
    private var listeners: [(String) -> Void] = []
    private let lock = NSLock()

    init(recordingManager: RecordingManager = .shared) {
        self.recordingManager = recordingManager
        self.pendingIds = []
        self.pendingIds = Set(Self.scanOutbox(at: recordingManager.outboxDirectory))
    }

    func pending() -> [String] {
        lock.lock()
        let ids = Array(pendingIds)
        lock.unlock()
        return ids.sorted()
    }

    func enqueue(localId: String) {
        lock.lock()
        let inserted = pendingIds.insert(localId).inserted
        let listeners = self.listeners
        lock.unlock()
        guard inserted else { return }
        logger.log("Enqueued local recording \(localId, privacy: .public)")
        listeners.forEach { $0(localId) }
    }

    func remove(localId: String) {
        lock.lock()
        let removed = pendingIds.remove(localId) != nil
        lock.unlock()
        if removed {
            logger.log("Outbox cleared for \(localId, privacy: .public)")
        }
    }

    func register(listener: @escaping (String) -> Void) {
        lock.lock()
        listeners.append(listener)
        lock.unlock()
    }

    private static func scanOutbox(at url: URL) -> [String] {
        let fm = FileManager.default
        guard let contents = try? fm.contentsOfDirectory(at: url, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]) else {
            return []
        }

        var ids: [String] = []
        for item in contents {
            guard let values = try? item.resourceValues(forKeys: [.isDirectoryKey]), values.isDirectory == true else { continue }
            let audioURL = item.appendingPathComponent("audio.m4a", isDirectory: false)
            if fm.fileExists(atPath: audioURL.path) {
                ids.append(item.lastPathComponent)
            }
        }
        return ids
    }
}
