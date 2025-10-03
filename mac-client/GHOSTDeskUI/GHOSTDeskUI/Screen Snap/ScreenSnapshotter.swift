//import Foundation
//import ScreenCaptureKit
//import CoreImage
//import CoreMedia
//import AppKit
//
///// Одноразовый снимок с уже работающего SCStream (.screen).
//final class ScreenSnapshotter: NSObject, SCStreamOutput {
//    private weak var stream: SCStream?
//    private let queue: DispatchQueue
//    private let ci = CIContext()
//    private var cont: CheckedContinuation<CGImage, Error>?
//    private var finished = false
////
//    init(stream: SCStream, queue: DispatchQueue = .init(label: "snapshot.queue")) {
//        self.stream = stream
//        self.queue = queue
//        super.init()
//    }
//
//    /// Возвращает первый пришедший кадр. Ничего не блокирует главный поток.
//    func snapshot(timeout: TimeInterval = 1.2) async throws -> CGImage {
//        guard let stream else {
//            throw NSError(domain: "ScreenSnapshotter", code: -2,
//                          userInfo: [NSLocalizedDescriptionKey: "Stream is nil/deallocated"])
//        }
//        try stream.addStreamOutput(self, type: .screen, sampleHandlerQueue: queue)
//
//        return try await withTaskCancellationHandler(operation: {
//            try await withCheckedThrowingContinuation { (c: CheckedContinuation<CGImage, Error>) in
//                self.cont = c
//                self.queue.asyncAfter(deadline: .now() + timeout) { [weak self] in
//                    guard let self, !self.finished else { return }
//                    self.finish(error: NSError(domain: "ScreenSnapshotter", code: -1,
//                                               userInfo: [NSLocalizedDescriptionKey: "Timed out waiting for frame"]))
//                }
//            }
//        }, onCancel: { [weak self] in
//            self?.finish(error: NSError(domain: "ScreenSnapshotter", code: -999,
//                                        userInfo: [NSLocalizedDescriptionKey: "Cancelled"]))
//        })
//    }
//
//    // MARK: - SCStreamOutput
//    func stream(_ stream: SCStream, didOutputSampleBuffer sb: CMSampleBuffer, of type: SCStreamOutputType) {
//        guard type == .screen, let pb = sb.imageBuffer else { return }
//        let ciImage = CIImage(cvPixelBuffer: pb)
//        if let cg = ci.createCGImage(ciImage, from: ciImage.extent) {
//            finish(image: cg) // первый кадр получили — готово
//        }
//    }
//
//    // MARK: - finish
//    private func finish(image: CGImage) {
//        guard !finished else { return }
//        finished = true
//        if let stream { try? stream.removeStreamOutput(self, type: .screen) }
//        cont?.resume(returning: image)
//        cont = nil
//    }
//
//    private func finish(error: Error) {
//        guard !finished else { return }
//        finished = true
//        if let stream { try? stream.removeStreamOutput(self, type: .screen) }
//        cont?.resume(throwing: error)
//        cont = nil
//    }
//}
