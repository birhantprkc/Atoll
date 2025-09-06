//
//  AppleScriptError.swift
//  DynamicIsland
//
//  Adapted from TheBoringWorker-HUD
//  Created by GitHub Copilot on 06/09/25.
//

import Foundation

enum AppleScriptError: Error {
    case initScriptFailed
    case runtimeError
    case emptyOutput
}