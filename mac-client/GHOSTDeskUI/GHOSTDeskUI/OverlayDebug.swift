import Foundation

enum OverlayDebug {
    private static let formatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    static func log(_ message: @autoclosure () -> String,
                    file: String = #fileID,
                    function: String = #function,
                    line: Int = #line) {
        #if DEBUG
        let ts = formatter.string(from: Date())
        print("[Overlay][\(ts)] \(file) · \(function) · L\(line): \(message())")
        #else
        let ts = formatter.string(from: Date())
        print("[Overlay][\(ts)] \(file) · \(function) · L\(line): \(message())")
        #endif
    }
}
