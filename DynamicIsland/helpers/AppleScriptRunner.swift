//
//  AppleScriptRunner.swift
//  DynamicIsland
//
//  Adapted from TheBoringWorker-HUD
//  Created by GitHub Copilot on 06/09/25.
//

import Foundation

class AppleScriptRunner {
    private init() {}

    static func run(script: String) throws -> String {
        var error: NSDictionary?
        if let scriptObject = NSAppleScript(source: script) {
            let output: NSAppleEventDescriptor = scriptObject.executeAndReturnError(&error)
            guard error == nil else {
                throw AppleScriptError.runtimeError
            }
            if let outputString = output.stringValue {
                return outputString
            }
            throw AppleScriptError.emptyOutput
        }
        throw AppleScriptError.initScriptFailed
    }
}