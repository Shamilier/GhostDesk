import Foundation

actor AuthAPI {
    static let shared = AuthAPI()

    nonisolated var baseURL: URL { base }

    private let base: URL
    private let session: URLSession
    private var cachedConfiguration: OAuthConfiguration?

    private init(baseURL: URL = ServerClient.shared.baseURL,
                 session: URLSession = .shared) {
        self.base = baseURL
        self.session = session
    }

    func fetchOAuthConfiguration() async throws -> OAuthConfiguration {
        if let cachedConfiguration {
            return cachedConfiguration
        }

        let url = base.appendingPathComponent("/oauth/client-config")
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await session.data(for: request)
        let http = try Self.validate(response: response, data: data)

        guard http.statusCode == 200 else {
            throw APIError.unexpectedStatus(http.statusCode)
        }

        let decoder = JSONDecoder()
        let configuration = try decoder.decode(OAuthConfiguration.self, from: data)
        cachedConfiguration = configuration
        return configuration
    }

    func exchangeAuthorizationCode(
        _ code: String,
        codeVerifier: String,
        configuration: OAuthConfiguration
    ) async throws -> AuthSession {
        let url = base.appendingPathComponent("/oauth/token")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.httpBody = Self.formURLEncoded([
            "grant_type": "authorization_code",
            "code": code,
            "client_id": configuration.clientId,
            "redirect_uri": configuration.redirectUri,
            "code_verifier": codeVerifier
        ])

        let (data, response) = try await session.data(for: request)
        let http = try Self.validate(response: response, data: data)
        guard http.statusCode == 200 else {
            if http.statusCode == 400 {
                throw APIError.authorizationRejected
            }
            throw APIError.unexpectedStatus(http.statusCode)
        }

        return try Self.makeSession(from: data)
    }

    func refreshTokens(refreshToken: String) async throws -> AuthSession {
        let configuration = try await fetchOAuthConfiguration()
        let url = base.appendingPathComponent("/oauth/token")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.httpBody = Self.formURLEncoded([
            "grant_type": "refresh_token",
            "refresh_token": refreshToken,
            "client_id": configuration.clientId
        ])

        let (data, response) = try await session.data(for: request)
        let http = try Self.validate(response: response, data: data)
        guard http.statusCode == 200 else {
            if http.statusCode == 400 || http.statusCode == 401 {
                throw APIError.refreshFailed
            }
            throw APIError.unexpectedStatus(http.statusCode)
        }

        return try Self.makeSession(from: data)
    }

    func fetchProfile(accessToken: String) async throws -> UserProfile {
        let url = base.appendingPathComponent("/oauth/profile")
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await session.data(for: request)
        let http = try Self.validate(response: response, data: data)

        guard http.statusCode == 200 else {
            if http.statusCode == 401 || http.statusCode == 403 {
                throw APIError.unauthorized
            }
            throw APIError.unexpectedStatus(http.statusCode)
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(UserProfile.self, from: data)
    }

    private static func formURLEncoded(_ parameters: [String: String]) -> Data {
        parameters
            .map { key, value in
                let encodedKey = Self.percentEncode(key)
                let encodedValue = Self.percentEncode(value)
                return "\(encodedKey)=\(encodedValue)"
            }
            .joined(separator: "&")
            .data(using: .utf8) ?? Data()
    }

    private static func percentEncode(_ string: String) -> String {
        var allowed = CharacterSet.urlQueryAllowed
        allowed.remove(charactersIn: ":#[]@!$&'()*+,;=")
        return string.addingPercentEncoding(withAllowedCharacters: allowed) ?? string
    }

    private static func validate(response: URLResponse, data: Data) throws -> HTTPURLResponse {
        guard let http = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        return http
    }

    private static func makeSession(from data: Data) throws -> AuthSession {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let payload = try decoder.decode(TokenResponse.self, from: data)
        let expiresAt: Date
        if let absolute = payload.expiresAt {
            expiresAt = absolute
        } else if let expiresIn = payload.expiresIn {
            expiresAt = Date().addingTimeInterval(TimeInterval(expiresIn))
        } else {
            expiresAt = Date().addingTimeInterval(3600)
        }
        return AuthSession(accessToken: payload.accessToken, refreshToken: payload.refreshToken, expiresAt: expiresAt)
    }
}

extension AuthAPI {
    enum APIError: LocalizedError {
        case invalidResponse
        case unexpectedStatus(Int)
        case authorizationRejected
        case refreshFailed
        case unauthorized

        var errorDescription: String? {
            switch self {
            case .invalidResponse:
                return "Сервер вернул неожиданный ответ. Попробуйте позже."
            case .unexpectedStatus(let status):
                return "Ошибка сервера (код \(status)). Попробуйте позже."
            case .authorizationRejected:
                return "Не удалось завершить авторизацию. Проверьте данные и повторите попытку."
            case .refreshFailed:
                return "Не удалось обновить сессию. Войдите снова."
            case .unauthorized:
                return "Сессия истекла. Войдите снова."
            }
        }
    }
}

private struct TokenResponse: Decodable {
    let accessToken: String
    let refreshToken: String
    let expiresIn: Double?
    let expiresAt: Date?

    private enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
        case expiresAt = "expires_at"
    }
}
