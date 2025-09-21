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
}
