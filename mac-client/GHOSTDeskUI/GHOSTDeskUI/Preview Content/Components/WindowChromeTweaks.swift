//#if os(macOS)
//import AppKit
//import SwiftUI
//
//public struct WindowChromeTweaks: NSViewRepresentable {
//    public init() {}
//
//    // ← Возвращаем NSView (публичный тип), а фактически создаём наш internal подкласс
//    public func makeNSView(context: Context) -> NSView {
//        let v = PassthroughView()
//        v.wantsLayer = true
//        v.layer?.backgroundColor = NSColor.clear.cgColor
//
//        DispatchQueue.main.async {
//            if let w = v.window {
//                w.titleVisibility = .hidden
//                w.titlebarAppearsTransparent = true
//                w.isMovableByWindowBackground = false   // <— ВАЖНО
//                w.backgroundColor = .clear
//            }
//        }
//        return v
//    }
//
//    // ← Принимаем NSView (публичный тип)
//    public func updateNSView(_ nsView: NSView, context: Context) {}
//}
//
//// internal — не «торчит» в публичный API
//final class PassthroughView: NSView {
//    // Не перехватываем события — отдаём системе обычный хит-тест
//    override func hitTest(_ point: NSPoint) -> NSView? {
//        super.hitTest(point)
//    }
//    override var isOpaque: Bool { false }
//}
//
//#else
//public struct WindowChromeTweaks: View {
//    public init() {}
//    public var body: some View { Color.clear.ignoresSafeArea() }
//}
//#endif
