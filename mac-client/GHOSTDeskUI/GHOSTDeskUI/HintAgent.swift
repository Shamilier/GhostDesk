import Foundation
import Combine

@MainActor
final class HintAgent: ObservableObject {
    static let shared = HintAgent()
    private weak var auth: AuthState?
    private let serverClient: ServerClient

    private init(serverClient: ServerClient = .shared) {
        self.serverClient = serverClient
    }

    enum Intent: String, CaseIterable, Identifiable {
        case general
        case nextUtterance
        case topicSummary
        case followUpQuestion

        var id: String { rawValue }

        var buttonTitle: String {
            switch self {
            case .general: return "Подсказка"
            case .nextUtterance: return "Что сказать дальше?"
            case .topicSummary: return "О чём речь?"
            case .followUpQuestion: return "Какой вопрос задать?"
            }
        }

        var displayTitle: String {
            switch self {
            case .general: return "Живой совет"
            case .nextUtterance: return "Что сказать дальше"
            case .topicSummary: return "О чём речь"
            case .followUpQuestion: return "Какой вопрос задать"
            }
        }

        var strapline: String {
            switch self {
            case .general:
                return "Короткая подсказка для продолжения разговора"
            case .nextUtterance:
                return "Подсказывает точную реплику, которую можно произнести"
            case .topicSummary:
                return "Выделяет тему и ключевые акценты текущего диалога"
            case .followUpQuestion:
                return "Формулирует уточняющие вопросы, чтобы продвинуть беседу"
            }
        }

        var placeholder: String {
            switch self {
            case .general:
                return "Нажмите, чтобы получить быстрый совет по живой речи."
            case .nextUtterance:
                return "GhostDesk подготовит точную реплику, которую можно произнести прямо сейчас."
            case .topicSummary:
                return "Получите короткое резюме того, что сейчас обсуждают."
            case .followUpQuestion:
                return "Попросите GhostDesk предложить сильный уточняющий вопрос."
            }
        }

        var symbolName: String {
            switch self {
            case .general: return "sparkles"
            case .nextUtterance: return "quote.bubble"
            case .topicSummary: return "list.bullet.rectangle"
            case .followUpQuestion: return "questionmark.bubble"
            }
        }

        var stripTitle: String {
            switch self {
            case .general: return "Подсказка"
            case .nextUtterance: return "Что сказать дальше"
            case .topicSummary: return "О чём речь"
            case .followUpQuestion: return "Какой вопрос задать"
            }
        }

        var windowSeconds: Int {
            switch self {
            case .general: return 40
            case .nextUtterance: return 45
            case .topicSummary: return 75
            case .followUpQuestion: return 60
            }
        }

        var maxChars: Int {
            switch self {
            case .general: return 900
            case .nextUtterance: return 900
            case .topicSummary: return 1300
            case .followUpQuestion: return 1000
            }
        }

        var instruction: String {
            switch self {
            case .general:
                return """
                Ты ассистент для живого разговора.
                Если в самом конце контекста есть явный вопрос собеседника — дай краткий уверенный ответ (2–3 предложения).
                Если явного вопроса нет — предложи одну тактичную реплику (1–2 предложения), которую удобно произнести.
                Никаких дисклеймеров. Пиши естественно и по делу.
                """.trimmingCharacters(in: .whitespacesAndNewlines)
            case .nextUtterance:
                return """
                Ты коуч по переговорам. Нужно придумать следующую реплику пользователя на основе последних реплик беседы.
                Соблюдай формат:
                **Суть собеседника** — одно короткое предложение с пониманием намерения собеседника.
                **Что сказать** — прямая речь пользователя, 1–2 предложения без кавычек, как будто он произносит их сейчас.
                Если уместно, добавь строку «Альтернатива: …» с вторым вариантом, только если он ощутимо отличается.
                Всегда отвечай на русском. Без дисклеймеров и слов от лица ассистента.
                """.trimmingCharacters(in: .whitespacesAndNewlines)
            case .topicSummary:
                return """
                Ты аналитик встречи. Сформулируй краткое резюме текущей темы разговора по последним репликам.
                Формат ответа:
                **Тема** — заголовок ≤6 слов.
                **Ключевые моменты** — 2–3 bullets по 10–15 слов.
                **Что важно дальше** — одно предложение о следующем шаге или риске.
                Всегда отвечай на русском. Без дисклеймеров.
                """.trimmingCharacters(in: .whitespacesAndNewlines)
            case .followUpQuestion:
                return """
                Ты ассистент-интервьюер. Подготовь точные уточняющие вопросы, чтобы продвинуть разговор вперёд.
                Формат:
                **Цель** — одно предложение с намерением пользователя.
                **Вопросы** — 1–2 bullets в формате прямой речи пользователя.
                При необходимости добавь строку «Поддержка: …» с короткой подсказкой, как реагировать на ответ.
                Ответ на русском, без дисклеймеров.
                """.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
    }

    static let insightIntents: [Intent] = [.nextUtterance, .topicSummary, .followUpQuestion]

    @Published var isRunning = false
    @Published var draft = ""          // сюда льётся поток
    @Published var error: String? = nil
    @Published var canStop = false
    @Published var activeIntent: Intent? = nil
    @Published var lastCompletedIntent: Intent? = nil
    @Published var startedAt: Date? = nil
    @Published var lastFinishedAt: Date? = nil

    private var task: Task<Void, Never>?
    private let baseURL = URL(string: "https://api.disciplaner.online")!
    private var sessionIds: [Intent: String] = [:]

    private func sessionId(for intent: Intent) -> String {
        if let cached = sessionIds[intent] {
            return cached
        }
        let new = UUID().uuidString
        sessionIds[intent] = new
        return new
    }

    func cancel() {
        task?.cancel()
        task = nil
        isRunning = false
        canStop = false
        activeIntent = nil
        startedAt = nil
    }

    func requestHint(for intent: Intent = .general) async {
        // 1) Собираем хвост речи
        let ctx = TranscriptBuffer.shared.tail(lastSeconds: intent.windowSeconds, maxChars: intent.maxChars)
        draft = ""; error = nil

        guard !ctx.isEmpty else {
            error = "Нет свежего контекста за последние \(intent.windowSeconds) секунд."
            return
        }

        guard let auth, let token = auth.currentKey, !token.isEmpty else {
            error = "Добавьте API-ключ, чтобы получать подсказки."
            return
        }

        isRunning = true
        canStop = true
        activeIntent = intent
        lastCompletedIntent = intent
        startedAt = Date()
        lastFinishedAt = nil

        task?.cancel()
        task = Task { [weak self] in
            guard let self else { return }
            do {
                self.serverClient.log("HintAgent: requesting \(intent.rawValue) — ctx=\(ctx.count) chars")
                let sessionId = self.sessionId(for: intent)
                let instruction = intent.instruction
                // 2) Сначала пытаемся /hint (JSON + SSE)
                let hintPaths = ["/hint", "/api/hint", "/v1/hint", "/hints/stream"]
                var success = false
                for p in hintPaths {
                    if try await self.tryHintJSON(path: p, context: ctx, token: token, instruction: instruction, intent: intent, sessionId: sessionId) {
                        success = true
                        break
                    }
                }

                // 3) Если /hint отсутствует → фолбэк на /ask (multipart + SSE)
                if !success {
                    try await self.fallbackAskWithMultipart(context: ctx, token: token, instruction: instruction, intent: intent, sessionId: sessionId)
                }
            } catch {
                if !Task.isCancelled { self.error = error.localizedDescription }
            }
            self.isRunning = false
            self.canStop = false
            self.activeIntent = nil
            self.startedAt = nil
            self.lastFinishedAt = Date()
        }

        await task?.value
        task = nil
    }

    // MARK: - /hint (JSON) → true если 2xx и стрим прочитан
    private func tryHintJSON(path: String, context: String, token: String, instruction: String, intent: Intent, sessionId: String) async throws -> Bool {
        var req = URLRequest(url: baseURL.appendingPathComponent(path))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        serverClient.authorize(&req, token: token)

        struct Payload: Codable { let sessionId: String; let instruction: String; let context: String; let intent: String }
        let payload = Payload(sessionId: sessionId, instruction: instruction, context: context, intent: intent.rawValue)
        req.httpBody = try JSONEncoder().encode(payload)

        let (bytes, response) = try await URLSession.shared.bytes(for: req)
        guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }

        if serverClient.handleUnauthorizedStatus(http.statusCode, auth: self.auth) {
            throw NSError(domain: "auth", code: http.statusCode,
                          userInfo: [NSLocalizedDescriptionKey: serverClient.unauthorizedMessage])
        }

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
    private func fallbackAskWithMultipart(context: String, token: String, instruction: String, intent: Intent, sessionId: String) async throws {
        let path = "/ask"
        var req = URLRequest(url: baseURL.appendingPathComponent(path))
        req.httpMethod = "POST"
        req.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        serverClient.authorize(&req, token: token)

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
        [insight: \(intent.rawValue)]
        Инструкция:
        \(instruction)

        Контекст (речь):
        \(context)
        """

        // обязательные поля /ask
        appendField("question", pseudoQuestion)
        appendField("smart", "false")
        appendField("sessionId", sessionId)
        appendField("intent", intent.rawValue)

        // прокинем транскрипт как отдельное поле — многие бэки его читают
        appendField("transcript", context)

        // tiny 1x1 прозрачный PNG — на случай, если бэк требует наличие image
        appendFile("image", filename: "blank.png", mime: "image/png", data: tinyTransparentPNG())

        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        req.httpBody = body

        let (bytes, response) = try await URLSession.shared.bytes(for: req)
        guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }

        if serverClient.handleUnauthorizedStatus(http.statusCode, auth: self.auth) {
            throw NSError(domain: "auth", code: http.statusCode,
                          userInfo: [NSLocalizedDescriptionKey: serverClient.unauthorizedMessage])
        }

        if !(200..<300).contains(http.statusCode) {
            let bodyText = (try? await collectToString(bytes, limit: 16_000)) ?? ""
            throw NSError(domain: "net", code: http.statusCode,
                          userInfo: [NSLocalizedDescriptionKey:
                                     "HTTP \(http.statusCode) on \(path)\n\(bodyText)"])
        }

        try await readSSE(bytes)
    }

    func attachAuth(_ auth: AuthState) {
        self.auth = auth
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

