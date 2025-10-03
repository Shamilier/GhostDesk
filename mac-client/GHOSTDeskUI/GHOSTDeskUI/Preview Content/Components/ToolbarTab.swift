//
//  ToolbarTab.swift
//  GHOSTDeskUI
//
//  Created by Shamil on 30.09.2025.
//

import SwiftUI

/// Вкладки тулбара (делаем отдельным файлом, чтобы был доступен и из OverlayRootView, и из FloatingToolbar)
public enum ToolbarTab: String, CaseIterable {
    case listen = "Listen"
    case ask = "Ask question"
}
