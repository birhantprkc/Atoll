//
//  SensorError.swift
//  DynamicIsland
//
//  Adapted from TheBoringWorker-HUD
//  Created by GitHub Copilot on 06/09/25.
//

import Foundation

enum SensorError: Error {
    enum Display: Error {
        case notFound
        case notSilicon
        case notStandard
    }
    enum Keyboard: Error {
        case notFound
        case notSilicon
        case notStandard
    }
}