import Foundation
import os.log

enum UsageError: Error, LocalizedError {
    case insufficientTokens(message: String, balance: Int)
    case unauthorized
    case server(message: String)

    var errorDescription: String? {
        switch self {
        case let .insufficientTokens(message, _):
            return message
        case .unauthorized:
            return "Сессия недействительна. Выполните вход заново."
        case let .server(message):
            return message
        }
    }
}

struct UsageAPIClient {
    static let insufficientTokensFallbackMessage = "У вас закончились токены. Пополните баланс на сайте ghostai.ru."

    let baseURL: URL
    let authState: AuthState
    var session: URLSession = .shared

    private let logger = Logger(subsystem: "ai.ghost.recorder", category: "UsageAPIClient")

    init(baseURL: URL, authState: AuthState, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.authState = authState
        self.session = session
    }

    func sendAsrTick() async throws -> Int {
        let accessToken = try await fetchAccessToken()

        var request = URLRequest(url: baseURL.appendingPathComponent("/v1/usage/asr-tick"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.httpBody = "{}".data(using: .utf8)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            logger.error("ASR usage tick request failed: \(error.localizedDescription, privacy: .public)")
            throw UsageError.server(message: "Не удалось связаться с сервером для списания токенов.")
        }

        guard let http = response as? HTTPURLResponse else {
            logger.error("ASR usage tick returned invalid response type")
            throw UsageError.server(message: "Сервер вернул некорректный ответ.")
        }

        switch http.statusCode {
        case 200:
            return try decodeBalance(from: data)
        case 401:
            throw UsageError.unauthorized
        case 402:
            throw try decodeInsufficientTokens(from: data)
        default:
            let message = Self.parseServerMessage(from: data)
                ?? "Списание токенов завершилось с ошибкой (код \(http.statusCode))."
            logger.error("ASR usage tick failed with status \(http.statusCode, privacy: .public): \(message, privacy: .public)")
            throw UsageError.server(message: message)
        }
    }
}

private extension UsageAPIClient {
    struct TokenBalancePayload: Decodable {
        let tokenBalance: Int
    }

    struct InsufficientTokensPayload: Decodable {
        let error: String?
        let message: String?
        let tokenBalance: Int?
    }

    func fetchAccessToken() async throws -> String {
        let token = await MainActor.run { authState.currentKey }
        guard let token, !token.isEmpty else {
            logger.error("ASR usage tick requested without a valid access token")
            throw UsageError.unauthorized
        }
        return token
    }

    func decodeBalance(from data: Data) throws -> Int {
        do {
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            return try decoder.decode(TokenBalancePayload.self, from: data).tokenBalance
        } catch {
            logger.error("Failed to decode ASR usage token balance: \(error.localizedDescription, privacy: .public)")
            throw UsageError.server(message: "Не удалось прочитать ответ сервера при списании токенов.")
        }
    }

    func decodeInsufficientTokens(from data: Data) throws -> UsageError {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        if let payload = try? decoder.decode(InsufficientTokensPayload.self, from: data),
           (payload.error == nil || payload.error == "insufficient_tokens") {
            let message = payload.message?.trimmingCharacters(in: .whitespacesAndNewlines)
            let resolvedMessage = (message?.isEmpty == false) ? message! : Self.insufficientTokensFallbackMessage
            let balance = payload.tokenBalance ?? 0
            return UsageError.insufficientTokens(message: resolvedMessage, balance: balance)
        }

        return UsageError.insufficientTokens(
            message: Self.insufficientTokensFallbackMessage,
            balance: 0
        )
    }

    static func parseServerMessage(from data: Data) -> String? {
        guard !data.isEmpty else { return nil }

        if let payload = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let message = payload["message"] as? String, !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return message
            }
            if let error = payload["error"] as? String, !error.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return error
            }
        }

        if let raw = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty {
            return raw
        }

        return nil
    }
}
