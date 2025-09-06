//
//  SystemOSDManager.swift
//  DynamicIsland
//
//  Adapted from TheBoringWorker-HUD OSDUIManager.swift
//  Created by GitHub Copilot on 06/09/25.
//

import Foundation

class SystemOSDManager {
    private init() {}

    /// Re-enables the system HUD by restarting OSDUIHelper
    public static func enableSystemHUD() {
        do {
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/usr/bin/killall")
            task.arguments = ["-9", "OSDUIHelper"]
            try task.run()
            print("System HUD re-enabled")
        } catch {
            NSLog("Error while trying to re-enable OSDUIHelper. \(error)")
        }
    }

    /// Disables the system HUD by stopping OSDUIHelper
    public static func disableSystemHUD() {
        do {
            let kickstart = Process()
            kickstart.executableURL = URL(fileURLWithPath: "/bin/launchctl")
            // When macOS boots, OSDUIHelper does not start until a volume button is pressed. We can workaround this by kickstarting it.
            kickstart.arguments = ["kickstart", "gui/\(getuid())/com.apple.OSDUIHelper"]
            try kickstart.run()
            kickstart.waitUntilExit()
            usleep(500000) // Make sure it started
            
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/usr/bin/killall")
            task.arguments = ["-STOP", "OSDUIHelper"]
            try task.run()
            print("System HUD disabled")
        } catch {
            NSLog("Error while trying to hide OSDUIHelper. Please create an issue on GitHub. Error: \(error)")
        }
    }
}