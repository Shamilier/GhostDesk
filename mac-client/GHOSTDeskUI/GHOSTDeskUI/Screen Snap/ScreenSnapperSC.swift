//import Foundation
//import AppKit
//import ScreenCaptureKit
//import CoreImage
//import CoreMedia
//
//enum ScreenSnapSCError: Error {
//    case noDisplays
//    case failed
//}
//
///// Один кадр через ScreenCaptureKit (без постоянного стрима)
//struct ScreenSnapperSC {
//
//    /// Снять композит главного дисплея и вернуть PNG (ужатый до maxSide)
//    static func captureAllDisplaysPNG(maxSide: CGFloat = 1280) async throws -> Data {
//        let cg = try await captureAllDisplaysCGImage()
//        let resized = resizeCGImage(cg, maxSide: maxSide)
//        return pngData(from: resized)
//    }
//
//    /// Снять один кадр как CGImage (через временный SCStream)
//    static func captureAllDisplaysCGImage(
//        width: Int = 1280,
//        height: Int = 720,
//        showsCursor: Bool = false
//    ) async throws -> CGImage {
//
//        // 1) Shareable content
//        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
//        guard let main = content.displays.first else { throw ScreenSnapSCError.noDisplays }
//
//        // 2) Контент-фильтр: старый API требует Set<SCWindow>
//        let filter: SCContentFilter
//        if #available(macOS 15.0, *) {
//            // Новая перегрузка (15+)
//            filter = SCContentFilter(
//                display: main,
//                excludingWindows: [],
//                exceptingWindows: []
//            )
//        } else if #available(macOS 14.0, *) {
//            // Sonoma: есть версия с excludingWindows
//            filter = SCContentFilter(
//                display: main,
//                excludingWindows: []
//            )
//        } else {
//            // Ventura и ниже – самый базовый
//            filter = SCContentFilter(display: main)
//        }
//
//
//        // 3) Одноразовый граб
//        let grabber = SingleFrameGrabber()
//        return try await grabber.grab(
//            filter: filter,
//            width: width,
//            height: height,
//            showsCursor: showsCursor,
//            timeout: 1.5
//        )
//    }
//
//    // MARK: - helpers
//
//    private static func pngData(from cg: CGImage) -> Data {
//        let ns = NSImage(cgImage: cg, size: .zero)
//        let rep = NSBitmapImageRep(data: ns.tiffRepresentation!)!
//        return rep.representation(using: .png, properties: [:])!
//    }
//
//    private static func resizeCGImage(_ src: CGImage, maxSide: CGFloat) -> CGImage {
//        let w = CGFloat(src.width), h = CGFloat(src.height)
//        let scale = min(1, maxSide / max(w, h))
//        let newW = Int(w * scale), newH = Int(h * scale)
//        let cs = CGColorSpaceCreateDeviceRGB()
//        let ctx = CGContext(
//            data: nil,
//            width: newW, height: newH,
//            bitsPerComponent: 8, bytesPerRow: 0,
//            space: cs,
//            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
//        )!
//        ctx.interpolationQuality = .high
//        ctx.draw(src, in: CGRect(x: 0, y: 0, width: newW, height: newH))
//        return ctx.makeImage()!
//    }
//}
//
///// Вспомогательный граббер одного кадра через SCStream
//final class SingleFrameGrabber: NSObject, SCStreamOutput, SCStreamDelegate {
//    private var stream: SCStream?
//    private var continuation: CheckedContinuation<CGImage, Error>?
//    private let ciContext = CIContext()
//    private var finished = false
//
//    deinit { stop() }
//
//    func grab(
//        filter: SCContentFilter,
//        width: Int = 1280,
//        height: Int = 720,
//        showsCursor: Bool = false,
//        timeout: TimeInterval = 1.5
//    ) async throws -> CGImage {
//
//        let cfg = SCStreamConfiguration()
//        cfg.width = width
//        cfg.height = height
//        cfg.showsCursor = showsCursor
//        cfg.pixelFormat = kCVPixelFormatType_32BGRA
//
//        let stream = SCStream(filter: filter, configuration: cfg, delegate: self)
//        self.stream = stream
//        try stream.addStreamOutput(self, type: .screen, sampleHandlerQueue: .main)
//        try await stream.startCapture()
//
//        return try await withTaskCancellationHandler(operation: {
//            try await withCheckedThrowingContinuation { (c: CheckedContinuation<CGImage, Error>) in
//                self.continuation = c
//                DispatchQueue.main.asyncAfter(deadline: .now() + timeout) { [weak self] in
//                    guard let self, !self.finished else { return }
//                    self.finish(with: NSError(
//                        domain: "SingleFrameGrabber",
//                        code: -1,
//                        userInfo: [NSLocalizedDescriptionKey: "Timed out"]
//                    ))
//                }
//            }
//        }, onCancel: { [weak self] in
//            self?.finish(with: NSError(
//                domain: "SingleFrameGrabber",
//                code: -999,
//                userInfo: [NSLocalizedDescriptionKey: "Cancelled"]
//            ))
//        })
//    }
//
//    private func stop() {
//        try? stream?.stopCapture()
//        stream = nil
//    }
//
//    // MARK: - SCStreamOutput
//    func stream(_ stream: SCStream, didOutputSampleBuffer sb: CMSampleBuffer, of type: SCStreamOutputType) {
//        guard type == .screen,
//              let pb = sb.imageBuffer else { return }
//        let ci = CIImage(cvPixelBuffer: pb)
//        if let cg = ciContext.createCGImage(ci, from: ci.extent) {
//            finish(with: cg)
//        }
//    }
//
//    func stream(_ stream: SCStream, didStopWithError error: Error) {
//        if !finished { finish(with: error) }
//    }
//
//    private func finish(with image: CGImage) {
//        guard !finished else { return }
//        finished = true
//        stop()
//        continuation?.resume(returning: image)
//        continuation = nil
//    }
//
//    private func finish(with error: Error) {
//        guard !finished else { return }
//        finished = true
//        stop()
//        continuation?.resume(throwing: error)
//        continuation = nil
//    }
//}
