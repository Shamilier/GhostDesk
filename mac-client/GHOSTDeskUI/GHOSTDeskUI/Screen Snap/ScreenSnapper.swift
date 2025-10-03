////
////  ScreenSnapper.swift
////  GHOSTDeskUI
////
////  Created by Shamil on 01.10.2025.
////
//
//import AppKit
//import CoreGraphics
//
//enum ScreenSnapError: Error {
//    case noAccess
//    case noImage
//}
//
//struct ScreenSnapper {
//    // MARK: - Permissions
//
//    /// Проверяем доступ к записи экрана БЕЗ системного окна
//    static func canCaptureWithoutPrompt() -> Bool {
//        CGPreflightScreenCaptureAccess()
//    }
//
//    /// Запрашиваем доступ (покажет системный диалог один раз)
//    @discardableResult
//    static func requestAccessIfNeeded() -> Bool {
//        if CGPreflightScreenCaptureAccess() { return true }
//        return CGRequestScreenCaptureAccess()
//    }
//
//    // MARK: - Captures
//
//    /// Снимок основного дисплея
//    static func captureMainDisplay() throws -> NSImage {
//        guard canCaptureWithoutPrompt() || requestAccessIfNeeded() else { throw ScreenSnapError.noAccess }
//        let displayID = CGMainDisplayID()
//        guard let cg = CGDisplayCreateImage(displayID) else { throw ScreenSnapError.noImage }
//        return nsImage(from: cg)
//    }
//
//    /// Композит всех видимых экранов (как ты их видишь сейчас)
//    static func captureAllDisplays() throws -> NSImage {
//        guard canCaptureWithoutPrompt() || requestAccessIfNeeded() else { throw ScreenSnapError.noAccess }
//        let rect = CGRect.infinite
//        guard let cg = CGWindowListCreateImage(
//            rect,
//            .optionOnScreenOnly,
//            kCGNullWindowID,
//            [.bestResolution, .boundsIgnoreFraming]
//        ) else { throw ScreenSnapError.noImage }
//        return nsImage(from: cg)
//    }
//
//    /// Снимок произвольного прямоугольника в глобальных координатах экранов
//    static func capture(rect: CGRect) throws -> NSImage {
//        guard canCaptureWithoutPrompt() || requestAccessIfNeeded() else { throw ScreenSnapError.noAccess }
//        guard let cg = CGWindowListCreateImage(
//            rect,
//            .optionOnScreenOnly,
//            kCGNullWindowID,
//            [.bestResolution, .boundsIgnoreFraming]
//        ) else { throw ScreenSnapError.noImage }
//        return nsImage(from: cg)
//    }
//
//    // MARK: - Encoding
//
//    static func pngData(from image: NSImage) -> Data? {
//        guard let tiff = image.tiffRepresentation,
//              let rep = NSBitmapImageRep(data: tiff) else { return nil }
//        return rep.representation(using: .png, properties: [:])
//    }
//
//    // MARK: - Utils
//
//    private static func nsImage(from cg: CGImage) -> NSImage {
//        // Корректный физический размер в поинтах c учётом Retina
//        let scale = NSScreen.main?.backingScaleFactor ?? 2.0
//        let size = NSSize(width: CGFloat(cg.width)/scale, height: CGFloat(cg.height)/scale)
//        return NSImage(cgImage: cg, size: size)
//    }
//}
