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
    @ObservedObject private var hint = HintAgent.shared


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
            if hint.isRunning || !hint.draft.isEmpty || hint.error != nil {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Подсказка")
                            .font(.headline)
                        if hint.isRunning { ProgressView().controlSize(.small) }
                        Spacer()
                        if hint.canStop {
                            Button("Стоп") { hint.cancel() }
                                .buttonStyle(GlassPill(tint: .red))
                        }
                    }
                    if let err = hint.error {
                        Text(err).foregroundColor(.red).font(.subheadline)
                    }
                    if !hint.draft.isEmpty {
                        Text(hint.draft)
                            .textSelection(.enabled)
                            .font(.body)
                            .fixedSize(horizontal: false, vertical: true)
                        HStack {
                            Button("Копировать") {
                                #if os(macOS)
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(hint.draft, forType: .string)
                                #endif
                            }.buttonStyle(GlassPill())
                            Spacer()
                            Button("Очистить") { hint.draft = "" }.buttonStyle(GlassPill(tint: .secondary))
                        }
                    }
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.08))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12).stroke(.white.opacity(0.12), lineWidth: 1)
                )
            }

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
                focused: $askFocused          // ← добавь эту строку
            )


            // ↓↓↓ БЛОК ОТВЕТА ↓↓↓
            VStack(alignment: .leading, spacing: 8) {
                if let err = askVM.answerError {
                    Text("Ошибка: \(err)")
                        .font(.subheadline)
                        .foregroundStyle(.red)
                }

                if !askVM.answerDraft.isEmpty || askVM.isSubmitting {
                    ScrollView {
                        Text(askVM.answerDraft.isEmpty ? "Генерация ответа…" : askVM.answerDraft)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                    }
                    .frame(minHeight: 80, maxHeight: 220)
                    .background(
                        RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.06))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12).stroke(.white.opacity(0.12), lineWidth: 1)
                    )

                    HStack {
                        Button("Копировать") {
                            #if os(macOS)
                            let s = askVM.answerDraft
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(s, forType: .string)
                            #endif
                        }
                        .buttonStyle(GlassPill())

                        if askVM.canStop {
                            Button("Стоп") { askVM.cancelStream() }
                                .buttonStyle(GlassPill(tint: .red))
                        }

                        Spacer()
                    }
                }
            }
            // ↑↑↑ БЛОК ОТВЕТА ↑↑↑

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


    // NEW: Submit ВСЕГДА шлёт ВОПРОС + ХВОСТ ТРАНСКРИПТА + СКРИНШОТ
    private func submitQuestion() async {
        let tr = makeTranscriptTail(seconds: 40, maxChars: 900) // хвост речи как контекст

        await askVM.submit(
            question: question,
            smart: smartMode,
            transcript: tr
        )

        ServerClient.shared.log("question submitted: \(question), smart=\(smartMode), speechTail=\(tr.count) chars")
    }

    // Хвост транскрибации из текущего транскрайбера (если не подключён TranscriptBuffer)
    private func makeTranscriptTail(seconds: Int = 40, maxChars: Int = 900) -> String {
        var s = transcriber.transcriptLog.suffix(14).joined(separator: " ")
        if !transcriber.partialText.isEmpty { s += " " + transcriber.partialText }
        if s.count > maxChars { s = String(s.suffix(maxChars)) }
        return s.trimmingCharacters(in: .whitespacesAndNewlines)
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


@MainActor
final class AskVM: ObservableObject {
    @Published var isSubmitting: Bool = false
    @Published var answerDraft: String = ""          // сюда льётся стрим
    @Published var answerError: String? = nil
    @Published var canStop: Bool = false             // показать кнопку «Стоп»

    private var streamTask: Task<Void, Never>?       // чтобы уметь отменять
    private let baseURL = URL(string: "https://api.disciplaner.online")!
    private let sessionId = UUID().uuidString        // одна сессия на жизненный цикл VM

    func cancelStream() {
        streamTask?.cancel()
        streamTask = nil
        canStop = false
        isSubmitting = false
    }

    // Submit ВСЕГДА отправляет вопрос + хвост транскрибации + скриншот
    func submit(
        question: String,
        smart: Bool,
        transcript: String
    ) async {
        let q = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else {
            NSLog("AskVM: skipped submit — empty question")
            return
        }

        // сброс состояния ответа
        answerDraft = ""
        answerError = nil
        isSubmitting = true
        canStop = true
        NSLog("AskVM isSubmitting = true")
        defer { NSLog("AskVM isSubmitting = false") }

        do {
            // 1) делаем PNG снимок
            let png = try await Snapshot.captureAllDisplaysPNG(maxSide: 1280)

            // 2) шлём на сервер и читаем SSE стрим
            try await sendToGPT(
                question: q,
                screenshotPNG: png,
                smart: smart,
                transcript: transcript
            )
        } catch {
            answerError = error.localizedDescription
            NSLog("AskVM submit failed: \(error.localizedDescription)")
        }

        isSubmitting = false
        canStop = false
    }

    // MARK: - сетевой вызов со streaming SSE
    private func sendToGPT(
        question: String,
        screenshotPNG: Data,
        smart: Bool,
        transcript: String
    ) async throws {
        var req = URLRequest(url: baseURL.appendingPathComponent("/ask"))
        req.httpMethod = "POST"
        req.setValue("text/event-stream", forHTTPHeaderField: "Accept") // ожидаем SSE

        // multipart/form-data
        let boundary = "----ghostdesk-\(UUID().uuidString)"
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        func appendField(_ name: String, _ value: String) {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(value)\r\n".data(using: .utf8)!)
        }
        func appendFile(_ name: String, filename: String, mime: String, data: Data) {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(name)\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
            body.append("Content-Type: \(mime)\r\n\r\n".data(using: .utf8)!)
            body.append(data)
            body.append("\r\n".data(using: .utf8)!)
        }

        // обязательные поля
        appendField("question", question)
        appendField("smart", smart ? "true" : "false")
        appendField("sessionId", sessionId)

        // контекст речи — ВСЕГДА (пусть даже пустая строка)
        appendField("transcript", transcript)

        // скрин — ВСЕГДА для Submit
        appendFile("image", filename: "screen.png", mime: "image/png", data: screenshotPNG)

        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        req.httpBody = body

        // 3) читаем SSE построчно. Важно: используем Task, чтобы уметь отменять
        streamTask?.cancel()
        streamTask = Task { [weak self] in
            guard let self else { return }
            do {
                let (bytes, response) = try await URLSession.shared.bytes(for: req)
                guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }

                if !(200..<300).contains(http.statusCode) {
                    var errText = "HTTP \(http.statusCode) \(HTTPURLResponse.localizedString(forStatusCode: http.statusCode))"
                    var data = Data()
                    do {
                        for try await b in bytes { data.append(b) } // вычитаем тело ошибки
                        if let s = String(data: data, encoding: .utf8), !s.isEmpty { errText += "\n\(s)" }
                    } catch {}
                    throw NSError(domain: "net", code: http.statusCode,
                                  userInfo: [NSLocalizedDescriptionKey: errText])
                }

                // читаем строки SSE
                var buffer = "" // микро-батчинг на клиенте, чтобы не дёргать UI по 1 символу
                var lastFlush = Date()

                for try await line in bytes.lines {
                    if Task.isCancelled { break }
                    guard line.hasPrefix("data: ") else { continue }

                    let jsonStr = String(line.dropFirst(6))
                    guard
                        let data = jsonStr.data(using: .utf8),
                        let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                        let type = obj["type"] as? String
                    else { continue }

                    if type == "delta", let text = obj["text"] as? String {
                        buffer += text
                        // флашим если буфер вырос или пришёл знак конца фразы, или прошло 60 мс
                        let shouldFlushByLen = buffer.count >= 64
                        let shouldFlushByPunct = buffer.last.map { ".,!?;:\n ".contains($0) } ?? false
                        let shouldFlushByTime = Date().timeIntervalSince(lastFlush) > 0.06
                        if shouldFlushByLen || shouldFlushByPunct || shouldFlushByTime {
                            self.answerDraft += buffer
                            buffer.removeAll(keepingCapacity: true)
                            lastFlush = Date()
                        }
                    } else if type == "done" {
                        // добросим хвост
                        if !buffer.isEmpty {
                            self.answerDraft += buffer
                            buffer.removeAll()
                        }
                        break
                    } else if type == "error" {
                        let msg = (obj["message"] as? String) ?? "Unknown error"
                        throw NSError(domain: "sse", code: -1,
                                      userInfo: [NSLocalizedDescriptionKey: msg])
                    }
                }
            } catch {
                if !Task.isCancelled {
                    self.answerError = error.localizedDescription
                }
            }
        }

        // ждём завершения Task (или отмены)
        await streamTask?.value
        streamTask = nil
    }
}

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





import Foundation

/// Потокобезопасный буфер последних реплик с таймстемпами.
/// Хранит подтверждённые куски и актуальный partial-хвост.
final class TranscriptBuffer {
    static let shared = TranscriptBuffer()
    private init() {}

    private struct Item { let t: Date; let text: String }
    private let q = DispatchQueue(label: "TranscriptBuffer.q", qos: .userInitiated)
    private var items: [Item] = []
    private var partial: Item? = nil

    /// Добавить подтверждённый (final) текст
    func appendFinal(_ text: String, at time: Date = .init()) {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        q.async {
            self.items.append(.init(t: time, text: clean))
            // ограничим рост буфера (по числу элементов)
            if self.items.count > 500 { self.items.removeFirst(self.items.count - 500) }
            self.partial = nil // сбрасываем текущий хвост
        }
    }

    /// Обновить текущий partial (неподтверждённый) текст
    func setPartial(_ text: String, at time: Date = .init()) {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        q.async {
            self.partial = clean.isEmpty ? nil : .init(t: time, text: clean)
        }
    }

    /// Хвост за N секунд, с жёстной усечкой по символам.
    func tail(lastSeconds: Int = 40, maxChars: Int = 900) -> String {
        let now = Date()
        return q.sync {
            let cut = now.addingTimeInterval(TimeInterval(-lastSeconds))
            var chunks = items.filter { $0.t >= cut }.map { $0.text }
            if let p = partial, p.t >= cut { chunks.append(p.text) }
            var s = chunks.joined(separator: " ")
            if s.count > maxChars {
                s = String(s.suffix(maxChars))
            }
            return s.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    func clear() {
        q.async {
            self.items.removeAll(keepingCapacity: false)
            self.partial = nil
        }
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


