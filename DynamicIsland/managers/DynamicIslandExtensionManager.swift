//
//  DynamicIslandExtensionManager.swift
//  DynamicIsland
//
//  Created by Harsh Vardhan  Goswami  on 04/08/24.
// DynamicIslandExtensionManager.swift
//  DynamicIsland
//
//  Created by Harsh Vardhan  Goswami  on 07/09/24.
//

import Foundation
import SwiftUI

var clipboardExtension: String = "dynamicisland.TheDynamicClipboard"
var hudExtension: String = "dynamicisland.TheDynamicHUDs"
var downloadManagerExtension: String = "dynamicisland.TheDynamicDownloadManager"

struct Extension: Identifiable, Hashable {
    var id = UUID()
    var name: String
    var bundleIdentifier: String
    var status: StatusModel = .enabled
}

enum StatusModel {
    case disabled
    case enabled
}

class DynamicIslandExtensionManager: ObservableObject {
    
    @Published var installedExtensions: [Extension] = [] {
        didSet {
            // Only log when there's an actual change in content, not just initialization
            if oldValue != installedExtensions {
                print("📦 Extensions installed: \(installedExtensions.map { $0.name })")
            }
        }
    }
    
    var extensions = [
        clipboardExtension,
        hudExtension
    ]

    init() {
        checkIfExtensionsAreInstalled()

        DistributedNotificationCenter.default().addObserver(self, selector: #selector(checkIfExtensionsAreInstalled), name: NSNotification.Name("NSWorkspaceDidLaunchApplicationNotification"), object: nil)
    }

    @objc func checkIfExtensionsAreInstalled() {
        installedExtensions = []
        for extensionName in extensions {
            if NSWorkspace.shared.urlForApplication(withBundleIdentifier: extensionName) != nil {
                let ext = Extension(name: extensionName.components(separatedBy: ".").last ?? extensionName, bundleIdentifier: extensionName)
                installedExtensions.append(ext)
            }
        }
    }
}
