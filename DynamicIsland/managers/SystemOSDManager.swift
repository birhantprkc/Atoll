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
            // First, stop any existing OSDUIHelper process
            let stopTask = Process()
            stopTask.executableURL = URL(fileURLWithPath: "/usr/bin/killall")
            stopTask.arguments = ["-9", "OSDUIHelper"]
            try stopTask.run()
            stopTask.waitUntilExit()
            
            // Small delay to ensure process is fully stopped
            usleep(200000) // 200ms
            
            // Then kickstart it again to ensure it's running properly
            let kickstart = Process()
            kickstart.executableURL = URL(fileURLWithPath: "/bin/launchctl")
            kickstart.arguments = ["kickstart", "gui/\(getuid())/com.apple.OSDUIHelper"]
            try kickstart.run()
            kickstart.waitUntilExit()
            
            // Additional delay to ensure service is fully started
            usleep(300000) // 300ms
            
            print("✅ System HUD re-enabled")
        } catch {
            NSLog("❌ Error while trying to re-enable OSDUIHelper: \(error)")
            
            // Fallback: Try to restart the service using launchctl load
            do {
                let fallbackTask = Process()
                fallbackTask.executableURL = URL(fileURLWithPath: "/bin/launchctl")
                fallbackTask.arguments = ["load", "-w", "/System/Library/LaunchAgents/com.apple.OSDUIHelper.plist"]
                try fallbackTask.run()
                fallbackTask.waitUntilExit()
                print("✅ System HUD re-enabled via fallback method")
            } catch {
                NSLog("❌ Fallback method also failed: \(error)")
            }
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
            task.waitUntilExit()
            
            print("✅ System HUD disabled")
        } catch {
            NSLog("❌ Error while trying to hide OSDUIHelper: \(error)")
        }
    }
    
    /// Check if OSDUIHelper is currently running
    public static func isOSDUIHelperRunning() -> Bool {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/pgrep")
        task.arguments = ["OSDUIHelper"]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        
        do {
            try task.run()
            task.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
            
            return task.terminationStatus == 0 && !output!.isEmpty
        } catch {
            return false
        }
    }
}