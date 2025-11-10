//
//  ServerClient.swift
//  GHOSTDeskUI
//
//  Created by Danil Bazhitov on 20.09.2025.
//


import Foundation

final class ServerClient {
    static let shared = ServerClient()
    let baseURL = URL(string: "https://ghostai.ru")!

    private init() {}

    func log(_ message: String) { print("➡️ \(message)") }

    let unauthorizedMessage = "Сервер отклонил текущую сессию. Войдите снова, чтобы продолжить."

    func authorize(_ request: inout URLRequest, token: String) {
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    }

    @discardableResult
    func handleUnauthorizedStatus(_ statusCode: Int, auth: AuthState?) -> Bool {
        guard statusCode == 401 || statusCode == 403 else { return false }
        log("Unauthorized response (status=\(statusCode)). Clearing stored auth session.")
        Task { @MainActor in
            auth?.signOut(reason: unauthorizedMessage)
        }
        return true
    }
}
