import Foundation
import os.log

struct RecordingMetadata: Codable {
    enum CodingKeys: String, CodingKey {
        case version
        case localId = "local_id"
        case startedAt = "started_at"
        case endedAt = "ended_at"
        case contentType = "content_type"
        case codec
        case bitrateKbps = "bitrate_kbps"
        case sampleRateHz = "sample_rate_hz"
        case sizeBytes = "size_bytes"
    }

    let version: Int
    let localId: String
    let startedAt: Date
    var endedAt: Date?
    let contentType: String
    let codec: String
    let bitrateKbps: Int
    let sampleRateHz: Int
    var sizeBytes: Int
}

final class RecordingManager {
    static let shared = RecordingManager()

    private let fileManager = FileManager.default
    private let baseDirectory: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let logger = Logger(subsystem: "ai.ghost.recorder", category: "RecordingManager")

    private init() {
        let support = fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("Application Support", isDirectory: true)
            .appendingPathComponent("GhostAI", isDirectory: true)
            .appendingPathComponent("outbox", isDirectory: true)
        baseDirectory = support

        encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        try? fileManager.createDirectory(at: baseDirectory, withIntermediateDirectories: true)
    }

    var outboxDirectory: URL { baseDirectory }

    func beginSession() throws -> (localId: String, fileURL: URL, startedAt: Date) {
        let localId = UUID().uuidString
        let sessionDirectory = baseDirectory.appendingPathComponent(localId, isDirectory: true)
        try fileManager.createDirectory(at: sessionDirectory, withIntermediateDirectories: true)

        let startedAt = Date()
        let metadata = RecordingMetadata(
            version: 1,
            localId: localId,
            startedAt: startedAt,
            endedAt: nil,
            contentType: "audio/mp4",
            codec: "aac",
            bitrateKbps: 64,
            sampleRateHz: 48_000,
            sizeBytes: 0
        )
        try write(metadata, to: metadataURL(for: localId))
        logger.log("Session \(localId, privacy: .public) started at \(startedAt.ISO8601Format(), privacy: .public)")

        return (localId, audioURL(for: localId), startedAt)
    }

    func finalizeSession(localId: String) throws -> (fileURL: URL, endedAt: Date, sizeBytes: Int) {
        let audioURL = audioURL(for: localId)
        guard fileManager.fileExists(atPath: audioURL.path) else {
            throw NSError(domain: "ai.ghost.recorder", code: -10, userInfo: [NSLocalizedDescriptionKey: "Audio file missing"])
        }

        var metadata = try metadata(for: localId)
        let endedAt = Date()
        let attributes = try fileManager.attributesOfItem(atPath: audioURL.path)
        let size = (attributes[.size] as? NSNumber)?.intValue ?? 0
        metadata.endedAt = endedAt
        metadata.sizeBytes = size
        try write(metadata, to: metadataURL(for: localId))
        logger.log("Session \(localId, privacy: .public) finalized, size=\(size, privacy: .public)")
        return (audioURL, endedAt, size)
    }

    func metadata(for localId: String) throws -> RecordingMetadata {
        let url = metadataURL(for: localId)
        let data = try Data(contentsOf: url)
        return try decoder.decode(RecordingMetadata.self, from: data)
    }

    func metadataURL(for localId: String) -> URL {
        sessionDirectory(for: localId).appendingPathComponent("metadata.json", isDirectory: false)
    }

    func audioURL(for localId: String) -> URL {
        sessionDirectory(for: localId).appendingPathComponent("audio.m4a", isDirectory: false)
    }

    func sessionDirectory(for localId: String) -> URL {
        baseDirectory.appendingPathComponent(localId, isDirectory: true)
    }

    func removeSession(localId: String) throws {
        let directory = sessionDirectory(for: localId)
        if fileManager.fileExists(atPath: directory.path) {
            try fileManager.removeItem(at: directory)
            logger.log("Removed session \(localId, privacy: .public)")
        }
    }

    private func write(_ metadata: RecordingMetadata, to url: URL) throws {
        let data = try encoder.encode(metadata)
        try data.write(to: url, options: [.atomic])
    }
}
