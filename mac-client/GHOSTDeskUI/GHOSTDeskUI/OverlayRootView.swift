import SwiftUI
import Combine
import AVFoundation
import CoreML
import WhisperKit

import ScreenCaptureKit
import CoreMedia
import Accelerate
import CoreGraphics


struct OverlayRootView: View {
    
    @State private var autoScroll = true
    @State private var showCopiedToast = false
    @State private var isExpanded = false
    @State private var selectedTab: ToolbarTab = .listen
    @Namespace private var islandNS
    @State private var question: String = ""
    @State private var smartMode: Bool = false
    @FocusState private var askFocused: Bool


    // наш безопасный ленивый транскрайбер
    @StateObject private var transcriber = SpeechTranscriber()

    // NEW: вью-модель для снапшота/отправки
    @StateObject private var askVM = AskVM()

    var body: some View {
        ZStack {
            VStack(spacing: 14) {
                FloatingToolbar(
                    isRecording: transcriber.isTranscribing,
                    selected: $selectedTab,
                    onPrimaryTap: { isExpanded = true },
                    onEyeTap: { isExpanded.toggle() },
                    onMenuTap: {}
                )
                .padding(.top, 8)

                if isExpanded {
                    Group {
                        if selectedTab == .listen {
                            listenPanel
                        } else {
                            askPanel
                        }
                    }
                    .padding(.horizontal, 8)
                    .matchedGeometryEffect(id: "island", in: islandNS)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(1)
                }

                Spacer(minLength: 0)
            
                    .onChange(of: isExpanded) { v in
                        if v && selectedTab == .ask { askFocused = true }
                    }
                    .onChange(of: selectedTab) { tab in
                        if isExpanded && tab == .ask { askFocused = true }
                    }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .animation(.spring(response: 0.35, dampingFraction: 0.86), value: isExpanded)

            if showCopiedToast {
                CopiedToast()
                    .matchedGeometryEffect(id: "toast", in: islandNS)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .padding(.top, 60)
                    .allowsHitTesting(false)
                    .allowsHitTesting(false)
                    .zIndex(2)
            }
        }
        .background(Color.clear)


        // Если когда-нибудь захочешь дать AskVM доступ к активному SCStream,
        // просто присвой сюда askVM.stream = <твой stream> после старта.
    }

    // MARK: - Listen Panel

    private var listenPanel: some View {
        VStack(spacing: 14) {
            header
            TranscriptView(
                logLines: transcriber.transcriptLog,
                partial: transcriber.partialText,
                autoScroll: $autoScroll
            )
            .frame(minHeight: 200, maxHeight: 300)
            footer
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.1))
        )
        .shadow(radius: 10)
    }

    // MARK: - Ask Panel

    private var askPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                LogoOrb()
                PhotonText("Ask about your screen")
                    .font(.headline)
                Spacer()
            }

            AskField(
                text: $question,
                smartEnabled: $smartMode,
                isSubmitting: askVM.isSubmitting,
                onSubmit: submitQuestion,
                focused: $askFocused              // ← добавили
            )


        }
        .padding(.vertical, 2)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.1))
        )
        .shadow(radius: 10)
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 12) {
            LogoOrb()

            VStack(alignment: .leading, spacing: 2) {
                PhotonText("Распознавание системного звука")
                    .font(.headline)

                HStack(spacing: 8) {
                    LiveDot(active: transcriber.isTranscribing)
                    Text(transcriber.isTranscribing ? "Идёт запись…" : "Готов к запуску")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(transcriber.isTranscribing ? .green.opacity(0.9) : .secondary)
                }
            }

            Spacer()

            HStack(spacing: 10) {
                // Start/Stop управляет ТРАНСКРАЙБЕРОМ
                Button {
                    if transcriber.phase == .running {
                        transcriber.stop()
                    } else if transcriber.phase == .idle {
                        transcriber.start()
                    }
                } label: {
                    let running = transcriber.phase == .running
                    let starting = transcriber.phase == .starting
                    Label(starting ? "Запуск…" : (running ? "Стоп" : "Старт"),
                          systemImage: running ? "stop.fill" : "play.fill")
                }
                .buttonStyle(GlassPill(tint: (transcriber.phase == .running) ? .red : .accentColor))
                .disabled(transcriber.phase == .starting)

                // Copy
                Button {
                    let lines = transcriber.transcriptLog
                    let tail = transcriber.partialText.isEmpty ? [] : [transcriber.partialText]
                    let text = (lines + tail).joined(separator: "\n")
                    #if os(macOS)
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(text, forType: .string)
                    #endif
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { showCopiedToast = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) {
                        withAnimation(.easeOut(duration: 0.25)) { showCopiedToast = false }
                    }
                } label: {
                    Label("Копия", systemImage: "doc.on.doc")
                }
                .buttonStyle(GlassPill())
                .disabled(transcriber.transcriptLog.isEmpty && transcriber.partialText.isEmpty)
            }
        }
    }

    // MARK: - Footer

    private var footer: some View {
        HStack(spacing: 12) {
            Toggle(isOn: $autoScroll) { Text("Автопрокрутка") }
                .toggleStyle(.switch)
                .tint(.accentColor)

            Spacer()

            Button {
                transcriber.clearLog()
            } label: {
                Label("Очистить", systemImage: "trash")
            }
            .buttonStyle(GlassPill(tint: .secondary))
            .disabled(transcriber.transcriptLog.isEmpty)
        }
        .padding(.top, 2)
    }

    // MARK: - Actions

    // NEW: теперь async — дергает AskVM, который делает снапшот и отправляет в GPT
    private func submitQuestion() async {
        await askVM.submit(question: question, smart: smartMode)
        // если нужно логировать — пожалуйста:
        ServerClient.shared.log("question submitted: \(question), smart=\(smartMode)")
    }
}

// MARK: - AskField

// AskField
struct AskField: View {
    @Binding var text: String
    @Binding var smartEnabled: Bool
    var isSubmitting: Bool = false
    var onSubmit: () async -> Void
    var focused: FocusState<Bool>.Binding    // ← новый параметр


    

    var body: some View {
        HStack(spacing: 10) {
            // Заменить TextField на TextEditor, если нужна многострочность
            TextEditor(text: $text)
                .focused(focused)                         // ← фокус сюда
                .font(.title3.weight(.medium))
                .frame(minHeight: 80)                     // чуть больше, чтобы точно хватало
                .padding(.vertical, 10)
                .padding(.leading, 12)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(NSColor.textBackgroundColor))
                )





            HStack(spacing: 8) {
                Toggle(isOn: $smartEnabled) {
                    Label("Smart Mode", systemImage: "bolt")
                        .labelStyle(.titleAndIcon)
                        .font(.subheadline.weight(.semibold))
                }
                .toggleStyle(.button)
                .tint(.accentColor.opacity(0.7))

                Button(isSubmitting ? "Submitting…" : "Submit") {
                    print("Submit tapped")
                    Task { await onSubmit() }
                }
                .buttonStyle(GlassPill(tint: .accentColor))
                .disabled(isSubmitting) // ← только этот флаг
            }
            .padding(.trailing, 8)
        }
        .padding(.horizontal, 6)
        .contentShape(Rectangle())
        .allowsHitTesting(true)
    }
}




// MARK: - GlassPill

struct GlassPill: ButtonStyle {
    var tint: Color? = nil
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.primary)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                Capsule(style: .continuous)
                    .fill(.thinMaterial)
                    .overlay(Capsule().stroke(.white.opacity(0.2), lineWidth: 1))
                    .shadow(
                        color: (tint ?? .accentColor).opacity(configuration.isPressed ? 0.25 : 0.4),
                        radius: configuration.isPressed ? 6 : 12,
                        x: 0, y: 0
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.spring(response: 0.28, dampingFraction: 0.9), value: configuration.isPressed)
    }
}

@MainActor
final class AskVM: ObservableObject {
    /// Если хочешь блокировать кнопку "Submit" — можешь привязать её к этому флагу
    @Published var isSubmitting: Bool = false

    /// Точка входа: дергается из OverlayRootView.submitQuestion()
    func submit(question: String, smart: Bool) async {
        let q = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else {
            NSLog("AskVM: skipped submit — empty question")
            return
        }
        isSubmitting = true
        NSLog("AskVM isSubmitting = true")
        defer {
            isSubmitting = false
            NSLog("AskVM isSubmitting = false")
        }

        do {
            let png = try await Snapshot.captureAllDisplaysPNG(maxSide: 1280)
            try await sendToGPT(question: q, screenshotPNG: png, smart: smart)
        } catch {
            NSLog("AskVM submit failed: \(error.localizedDescription)")
        }
    }


    // MARK: - Реальный сетевой вызов (заглушка)
    private func sendToGPT(question: String, screenshotPNG: Data, smart: Bool) async throws {
        // TODO: реализуй multipart/JSON. Пример протокола оставлен за тобой.
        NSLog("GPT SEND -> q=\(question), smart=\(smart), bytes=\(screenshotPNG.count)")
    }
}

// MARK: - Внутренняя однофайловая реализация снимка экрана

private enum Snapshot {
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


        // let filter = SCContentFilter(display: main, excludingWindows: [], exceptingWindows: [])

        // Самый совместимый вариант для разных SDK/macOS
        let filter = SCContentFilter(display: main, excludingWindows: [])





        // Конфигурация стрима
        let cfg = SCStreamConfiguration()
        cfg.width  = (width  / 8) * 8        // чуть выравниваем для стабильности
        cfg.height = (height / 8) * 8
        cfg.showsCursor = showsCursor
        cfg.pixelFormat = kCVPixelFormatType_32BGRA
        // Можно задать минимальный интервал кадров, но для "одного кадра" не критично:
        // cfg.minimumFrameInterval = CMTime(value: 1, timescale: 30)

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

        private func stop() {
            try? stream?.stopCapture()
            stream = nil
        }

        // MARK: - SCStreamOutput

        func stream(_ stream: SCStream, didOutputSampleBuffer sb: CMSampleBuffer, of type: SCStreamOutputType) {
            guard type == .screen, let pb = sb.imageBuffer else { return }
            let ciImage = CIImage(cvPixelBuffer: pb)
            if let cg = ci.createCGImage(ciImage, from: ciImage.extent) {
                finish(image: cg)
            }
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


#if os(macOS)
import AppKit
import SwiftUI

public struct WindowChromeTweaks: NSViewRepresentable {
    public init() {}

    public func makeNSView(context: Context) -> NSView {
        let v = NSView()                       // ← обычный NSView без хит-тест трюков
        v.wantsLayer = true
        v.layer?.backgroundColor = NSColor.clear.cgColor
        DispatchQueue.main.async {
            if let w = v.window {
                w.titleVisibility = .hidden
                w.titlebarAppearsTransparent = true
                w.isMovableByWindowBackground = false   // ← ВАЖНО: выключено
                w.backgroundColor = .clear
            }
        }
        return v
    }

    public func updateNSView(_ nsView: NSView, context: Context) {}
}
#else
public struct WindowChromeTweaks: View {
    public init() {}
    public var body: some View { Color.clear.ignoresSafeArea() }
}
#endif

