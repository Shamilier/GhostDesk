import Foundation

actor AuthAPI {
    static let shared = AuthAPI()

    nonisolated var baseURL: URL { ServerClient.shared.baseURL }

    private let session: URLSession
    private var cachedConfiguration: CachedConfiguration?

    private init(session: URLSession = .shared) {
        self.session = session
    }

    func fetchOAuthConfiguration() async throws -> OAuthConfiguration {
        let base = ServerClient.shared.baseURL

        if let cachedConfiguration, cachedConfiguration.baseURL == base {
            return cachedConfiguration.configuration
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
        cachedConfiguration = CachedConfiguration(baseURL: base, configuration: configuration)
        return configuration
    }

    func exchangeAuthorizationCode(
        _ code: String,
        codeVerifier: String,
        configuration: OAuthConfiguration
    ) async throws -> AuthSession {
        let base = ServerClient.shared.baseURL
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

        do {
            #if DEBUG
            print("[AuthAPI][DEBUG] Parsing token response...")
            #endif
            return try Self.makeSession(from: data)
        } catch {
            #if DEBUG
            Self.logDecodeFailure(statusCode: http.statusCode, data: data)
            #endif
            throw error
        }
    }

    func refreshTokens(refreshToken: String) async throws -> AuthSession {
        let base = ServerClient.shared.baseURL
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

        do {
            #if DEBUG
            print("[AuthAPI][DEBUG] Parsing token response...")
            #endif
            return try Self.makeSession(from: data)
        } catch {
            #if DEBUG
            Self.logDecodeFailure(statusCode: http.statusCode, data: data)
            #endif
            throw error
        }
    }

    func fetchProfile(accessToken: String) async throws -> UserProfile {
        let base = ServerClient.shared.baseURL
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

        do {
            #if DEBUG
            print("[AuthAPI][DEBUG] Parsing user profile...")
            #endif
            return try AuthAPI.tolerantDecoder.decode(UserProfile.self, from: data)
        } catch {
            #if DEBUG
            Self.logDecodeFailure(statusCode: http.statusCode, data: data)
            #endif
            throw error
        }
    }

    func invalidateConfigurationCache() {
        cachedConfiguration = nil
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
        if http.statusCode == 200,
           let contentType = http.value(forHTTPHeaderField: "Content-Type"),
           contentType.contains("application/json") == false {
            #if DEBUG
            print("[AuthAPI][DEBUG] Unexpected Content-Type: \(contentType)")
            #endif
        }
        return http
    }

    private static func makeSession(from data: Data) throws -> AuthSession {
        let payload = try tolerantDecoder.decode(TokenResponse.self, from: data)
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

private extension AuthAPI {
    static let tolerantDecoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            if let timestamp = try? container.decode(Double.self) {
                return Date(timeIntervalSince1970: timestamp)
            }

            let value = try container.decode(String.self)
            if let timestamp = Double(value) {
                return Date(timeIntervalSince1970: timestamp)
            }

            if let flexible = parseRFC3339Flexible(value) {
                return flexible
            }

            if let isoDate = iso8601Formatter.date(from: value) {
                return isoDate
            }

            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unsupported date format"
            )
        }
        return decoder
    }()

    static let iso8601Formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    static let flexibleRFC3339Formatters: [DateFormatter] = {
        let formats = [
            "yyyy-MM-dd'T'HH:mm:ssXXXXX",
            "yyyy-MM-dd'T'HH:mm:ss.SSSXXXXX",
            "yyyy-MM-dd'T'HH:mm:ss.SSSSSSXXXXX",
            "yyyy-MM-dd'T'HH:mm:ss'Z'",
            "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'",
            "yyyy-MM-dd'T'HH:mm:ss.SSSSSS'Z'"
        ]

        return formats.map { format in
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = TimeZone(secondsFromGMT: 0)
            formatter.dateFormat = format
            return formatter
        }
    }()

    static func parseRFC3339Flexible(_ string: String) -> Date? {
        for formatter in flexibleRFC3339Formatters {
            if let date = formatter.date(from: string) {
                return date
            }
        }
        return nil
    }

    static func logDecodeFailure(statusCode: Int, data: Data) {
        if let body = String(data: data, encoding: .utf8) {
            let preview = body.prefix(512)
            print("[AuthAPI][DEBUG] Decode failed. Status=\(statusCode). Body prefix:\n\(preview)")
        } else {
            print("[AuthAPI][DEBUG] Decode failed. Status=\(statusCode). Body is non-UTF8 (\(data.count) bytes)")
        }
    }
}

private extension AuthAPI {
    struct CachedConfiguration {
        let baseURL: URL
        let configuration: OAuthConfiguration
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
