//
//  SystemHUDDebugger.swift
//  DynamicIsland
//
//  Debug utility for System HUD functionality
//  Created by GitHub Copilot on 06/09/25.
//

import Foundation

class SystemHUDDebugger {
    
    /// Test system HUD functionality and print status
    public static func testSystemHUD() {
        print("\n🔍 === System HUD Debug Report ===")
        
        // Check current OSDUIHelper status
        let isRunning = SystemOSDManager.isOSDUIHelperRunning()
        print("📊 OSDUIHelper Status: \(isRunning ? "✅ Running" : "❌ Not running")")
        
        // Test disable
        print("🔇 Testing disable...")
        SystemOSDManager.disableSystemHUD()
        
        // Wait and check
        usleep(500000)
        let isRunningAfterDisable = SystemOSDManager.isOSDUIHelperRunning()
        print("📊 After disable: \(isRunningAfterDisable ? "✅ Running (stopped)" : "❌ Not running")")
        
        // Test enable
        print("🔊 Testing re-enable...")
        SystemOSDManager.enableSystemHUD()
        
        // Wait and check
        usleep(1000000)
        let isRunningAfterEnable = SystemOSDManager.isOSDUIHelperRunning()
        print("📊 After re-enable: \(isRunningAfterEnable ? "✅ Running" : "❌ Not running")")
        
        print("🔍 === End Debug Report ===\n")
        
        if !isRunningAfterEnable {
            print("⚠️  WARNING: System HUD may not be working properly!")
            print("💡 Try pressing volume keys to test system HUD functionality")
        }
    }
    
    /// Force restart OSDUIHelper using multiple methods
    public static func forceRestartOSDUIHelper() {
        print("🔄 Force restarting OSDUIHelper...")
        
        // Method 1: Kill and kickstart
        SystemOSDManager.enableSystemHUD()
        
        // Method 2: Try launchctl bootstrap (more aggressive)
        do {
            let bootstrap = Process()
            bootstrap.executableURL = URL(fileURLWithPath: "/bin/launchctl")
            bootstrap.arguments = ["bootstrap", "gui/\(getuid())", "/System/Library/LaunchAgents/com.apple.OSDUIHelper.plist"]
            try bootstrap.run()
            bootstrap.waitUntilExit()
            print("✅ Bootstrap method completed")
        } catch {
            print("❌ Bootstrap method failed: \(error)")
        }
        
        // Method 3: Try direct service restart
        do {
            let restart = Process()
            restart.executableURL = URL(fileURLWithPath: "/bin/launchctl")
            restart.arguments = ["restart", "gui/\(getuid())/com.apple.OSDUIHelper"]
            try restart.run()
            restart.waitUntilExit()
            print("✅ Restart method completed")
        } catch {
            print("❌ Restart method failed: \(error)")
        }
        
        // Check final status
        usleep(1000000)
        let finalStatus = SystemOSDManager.isOSDUIHelperRunning()
        print("📊 Final OSDUIHelper status: \(finalStatus ? "✅ Running" : "❌ Not running")")
    }
}