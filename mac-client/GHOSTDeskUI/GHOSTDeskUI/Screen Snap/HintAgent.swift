import Foundation
import Combine

@MainActor
final class HintAgent: ObservableObject {
    static let shared = HintAgent()
    private init() {}

    @Published var isRunning = false
    @Published var draft = ""          // сюда льётся поток
    @Published var error: String? = nil
    @Published var canStop = false

    private var task: Task<Void, Never>?
    private let baseURL = URL(string: "http://localhost:8787")!
    private let sessionId = UUID().uuidString

    // Инструкция для режима подсказки (только речь)
    private let systemInstruction = """
    Ты ассистент для живого разговора.
    Если в самом конце контекста есть явный вопрос собеседника — дай краткий уверенный ответ (2–3 предложения).
    Если явного вопроса нет — предложи одну тактичную реплику (1–2 предложения), которую удобно произнести.
    Никаких дисклеймеров. Пиши естественно и по делу.
    """

    func cancel() {
        task?.cancel()
        task = nil
        isRunning = false
        canStop = false
    }

    func requestHint(windowSeconds: Int = 40, maxChars: Int = 900) async {
        // 1) Собираем хвост речи
        let ctx = TranscriptBuffer.shared.tail(lastSeconds: windowSeconds, maxChars: maxChars)
        draft = ""; error = nil
        guard !ctx.isEmpty else {
            error = "Нет свежего контекста за последние \(windowSeconds) секунд."
            return
        }

        isRunning = true
        canStop = true

        task?.cancel()
        task = Task { [weak self] in
            guard let self else { return }
            do {
                // 2) Сначала пытаемся /hint (JSON + SSE)
                let hintPaths = ["/hint", "/api/hint", "/v1/hint", "/hints/stream"]
                var success = false
                for p in hintPaths {
                    if try await self.tryHintJSON(path: p, context: ctx) {
                        success = true
                        break
                    }
                }

                // 3) Если /hint отсутствует → фолбэк на /ask (multipart + SSE)
                if !success {
                    try await self.fallbackAskWithMultipart(context: ctx)
                }
            } catch {
                if !Task.isCancelled { self.error = error.localizedDescription }
            }
            self.isRunning = false
            self.canStop = false
        }

        await task?.value
        task = nil
    }

    // MARK: - /hint (JSON) → true если 2xx и стрим прочитан
    private func tryHintJSON(path: String, context: String) async throws -> Bool {
        var req = URLRequest(url: baseURL.appendingPathComponent(path))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("text/event-stream", forHTTPHeaderField: "Accept")

        struct Payload: Codable { let sessionId: String; let instruction: String; let context: String }
        let payload = Payload(sessionId: sessionId, instruction: systemInstruction, context: context)
        req.httpBody = try JSONEncoder().encode(payload)

        let (bytes, response) = try await URLSession.shared.bytes(for: req)
        guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }

        // 404/405/415/501 и т.п. — считаем, что маршрута нет → вернуть false без ошибки
        if http.statusCode == 404 || http.statusCode == 405 || http.statusCode == 415 || http.statusCode == 501 {
            // вычитаем тело и молча переходим к следующему пути
            _ = try? await drain(bytes)
            return false
        }

        // Любой не-2xx (кроме указанных выше) — это уже реальная ошибка
        if !(200..<300).contains(http.statusCode) {
            let body = (try? await collectToString(bytes, limit: 16_000)) ?? ""
            throw NSError(domain: "net", code: http.statusCode,
                          userInfo: [NSLocalizedDescriptionKey:
                                     "HTTP \(http.statusCode) on \(path)\n\(body)"])
        }

        try await readSSE(bytes)
        return true
    }

    // MARK: - Фолбэк: /ask (multipart) — без реального скрина (1×1 PNG)
    private func fallbackAskWithMultipart(context: String) async throws {
        let path = "/ask"
        var req = URLRequest(url: baseURL.appendingPathComponent(path))
        req.httpMethod = "POST"
        req.setValue("text/event-stream", forHTTPHeaderField: "Accept")

        let boundary = "----ghostdesk-hint-\(UUID().uuidString)"
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

        // «Вопрос» для подсказки — даём явную постановку, что нужен короткий ответ по последнему вопросу
        let pseudoQuestion =
        """
        Нужна подсказка для живого ответа: если в конце контекста есть вопрос собеседника — дай краткий уверенный ответ (2–3 предложения). Если нет — предложи одну естественную реплику. Пиши без дисклеймеров.
        Контекст (речь): \(context)
        """

        // обязательные поля /ask
        appendField("question", pseudoQuestion)
        appendField("smart", "false")
        appendField("sessionId", sessionId)

        // прокинем транскрипт как отдельное поле — многие бэки его читают
        appendField("transcript", context)

        // tiny 1x1 прозрачный PNG — на случай, если бэк требует наличие image
        appendFile("image", filename: "blank.png", mime: "image/png", data: tinyTransparentPNG())

        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        req.httpBody = body

        let (bytes, response) = try await URLSession.shared.bytes(for: req)
        guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }

        if !(200..<300).contains(http.statusCode) {
            let bodyText = (try? await collectToString(bytes, limit: 16_000)) ?? ""
            throw NSError(domain: "net", code: http.statusCode,
                          userInfo: [NSLocalizedDescriptionKey:
                                     "HTTP \(http.statusCode) on \(path)\n\(bodyText)"])
        }

        try await readSSE(bytes)
    }

    // MARK: - SSE reader
    private func readSSE(_ bytes: URLSession.AsyncBytes) async throws {
        var buffer = ""
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
                let shouldFlushByLen = buffer.count >= 64
                let shouldFlushByPunct = buffer.last.map { ".,!?;:\n ".contains($0) } ?? false
                let shouldFlushByTime = Date().timeIntervalSince(lastFlush) > 0.06
                if shouldFlushByLen || shouldFlushByPunct || shouldFlushByTime {
                    self.draft += buffer
                    buffer.removeAll(keepingCapacity: true)
                    lastFlush = Date()
                }
            } else if type == "done" {
                if !buffer.isEmpty {
                    self.draft += buffer
                }
                break
            } else if type == "error" {
                let msg = (obj["message"] as? String) ?? "Unknown error"
                throw NSError(domain: "sse", code: -1,
                              userInfo: [NSLocalizedDescriptionKey: msg])
            }
        }
    }

    // MARK: - Utils
    private func collectToString(_ bytes: URLSession.AsyncBytes, limit: Int) async throws -> String {
        var data = Data()
        for try await b in bytes {
            data.append(b)
            if data.count > limit { break }
        }
        return String(data: data, encoding: .utf8) ?? "<binary>"
    }

    private func drain(_ bytes: URLSession.AsyncBytes) async throws -> Int {
        var n = 0
        for try await _ in bytes { n += 1 }
        return n
    }

    /// 1×1 прозрачный PNG (заглушка) — чтобы удовлетворить бэк, если image обязателен
    private func tinyTransparentPNG() -> Data {
        // Base64 1x1 RGBA transparent PNG
        let b64 = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADUlEQVR4nGMAAQAABQABDQotAAAAAElFTkSuQmCC"
        return Data(base64Encoded: b64) ?? Data()
    }
}

