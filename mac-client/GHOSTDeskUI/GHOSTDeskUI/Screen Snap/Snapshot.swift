import Foundation
import ScreenCaptureKit
import CoreGraphics
import CoreImage
import CoreMedia
import CoreVideo
import UniformTypeIdentifiers

enum Snapshot {
    enum Error: Swift.Error {
        case noDisplays
        case timeout
        case cancelled
        case internalFailure(String)
    }

    /// Публичная точка: PNG сжат до `maxSide` по большей стороне
    static func captureAllDisplaysPNG(maxSide: CGFloat = 1280) async throws -> Data {
        let cg = try await captureAllDisplaysCGImage(width: 1280, height: 720, showsCursor: false, timeout: 2.0)
        let resized = resizeCGImage(cg, maxSide: maxSide)
        return pngData(from: resized)
    }

    /// Одноразовый CGImage через временный SCStream
    static func captureAllDisplaysCGImage(
        width: Int = 1280,
        height: Int = 720,
        showsCursor: Bool = false,
        timeout: TimeInterval = 2.0
    ) async throws -> CGImage {
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)

        guard let main = content.displays.first else { throw Error.noDisplays }

        // Самый совместимый вариант для разных SDK/macOS
        let filter = SCContentFilter(display: main, excludingWindows: [])

        // Конфигурация стрима
        let cfg = SCStreamConfiguration()
        cfg.width = (width / 8) * 8
        cfg.height = (height / 8) * 8
        cfg.showsCursor = showsCursor
        cfg.pixelFormat = kCVPixelFormatType_32BGRA

        // Захват одного кадра
        let grabber = SingleFrameGrabber(queueLabel: "sc.single.grab.queue")
        return try await grabber.grab(filter: filter, configuration: cfg, timeout: timeout)
    }

    // MARK: - Helpers (PNG и ресайз)

    private static func pngData(from cg: CGImage) -> Data {
        let data = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil) else {
            fatalError("CGImageDestinationCreateWithData failed")
        }
        CGImageDestinationAddImage(dest, cg, nil)
        CGImageDestinationFinalize(dest)
        return data as Data
    }

    private static func resizeCGImage(_ src: CGImage, maxSide: CGFloat) -> CGImage {
        let w = CGFloat(src.width), h = CGFloat(src.height)
        let scale = min(1, maxSide / max(w, h))
        let newW = max(1, Int(w * scale))
        let newH = max(1, Int(h * scale))

        let cs = src.colorSpace ?? CGColorSpaceCreateDeviceRGB()
        let ctx = CGContext(
            data: nil,
            width: newW, height: newH,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: cs,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        ctx.interpolationQuality = .high
        ctx.draw(src, in: CGRect(x: 0, y: 0, width: newW, height: newH))
        return ctx.makeImage()!
    }

    // MARK: - Одноразовый граббер кадра

    private final class SingleFrameGrabber: NSObject, SCStreamOutput, SCStreamDelegate {
        private var stream: SCStream?
        private var cont: CheckedContinuation<CGImage, Swift.Error>?
        private var finished = false

        private let ci = CIContext()
        private let queue: DispatchQueue

        init(queueLabel: String) {
            self.queue = DispatchQueue(label: queueLabel)
            super.init()
        }

        deinit { stop() }

        func grab(filter: SCContentFilter, configuration: SCStreamConfiguration, timeout: TimeInterval) async throws -> CGImage {
            let stream = SCStream(filter: filter, configuration: configuration, delegate: self)
            self.stream = stream

            // Обрабатываем кадры НЕ на main
            try stream.addStreamOutput(self, type: .screen, sampleHandlerQueue: queue)
            try await stream.startCapture()

            return try await withTaskCancellationHandler(operation: {
                try await withCheckedThrowingContinuation { (c: CheckedContinuation<CGImage, Swift.Error>) in
                    self.cont = c
                    // Таймаут
                    self.queue.asyncAfter(deadline: .now() + timeout) { [weak self] in
                        guard let self, !self.finished else { return }
                        self.finish(error: Snapshot.Error.timeout)
                    }
                }
            }, onCancel: { [weak self] in
                self?.finish(error: Snapshot.Error.cancelled)
            })
        }

        func stop() {
            queue.async {
                guard !self.finished else { return }
                self.stream?.stopCapture { _ in }
                self.stream = nil
            }
        }

        // MARK: - SCStreamOutput

        func stream(_ stream: SCStream, didOutputSampleBuffer sb: CMSampleBuffer, of type: SCStreamOutputType) {
            guard type == .screen else { return }
            guard let imageBuffer = CMSampleBufferGetImageBuffer(sb) else { return }
            let ciImage = CIImage(cvImageBuffer: imageBuffer)
            guard let cgImage = ci.createCGImage(ciImage, from: ciImage.extent) else { return }
            finish(image: cgImage)
        }

        // MARK: - SCStreamDelegate

        func stream(_ stream: SCStream, didStopWithError error: Swift.Error) {
            finish(error: error)
        }

        // MARK: - Finish helpers

        private func finish(image: CGImage) {
            queue.async {
                guard !self.finished else { return }
                self.finished = true
                self.stop()
                self.cont?.resume(returning: image)
                self.cont = nil
            }
        }

        private func finish(error: Swift.Error) {
            queue.async {
                guard !self.finished else { return }
                self.finished = true
                self.stop()
                self.cont?.resume(throwing: error)
                self.cont = nil
            }
        }
    }
}
