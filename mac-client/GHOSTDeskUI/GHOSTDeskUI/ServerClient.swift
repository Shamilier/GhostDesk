//
//  ServerClient.swift
//  GHOSTDeskUI
//
//  Created by Danil Bazhitov on 20.09.2025.
//


import Foundation

final class ServerClient {
    static let shared = ServerClient()
    private init() {}

    func log(_ message: String) { print("➡️ \(message)") }

    let unauthorizedMessage = "Сервер не принял API-ключ. Введите новый ключ и попробуйте снова."

    func authorize(_ request: inout URLRequest, token: String) {
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    }

    @discardableResult
    func handleUnauthorizedStatus(_ statusCode: Int, auth: AuthState?) -> Bool {
        guard statusCode == 401 || statusCode == 403 else { return false }
        log("Unauthorized response (status=\(statusCode)). Forcing API key reset prompt.")
        Task { @MainActor in
            auth?.isVerified = false
            auth?.lastError = unauthorizedMessage
        }
        return true
    }
}
