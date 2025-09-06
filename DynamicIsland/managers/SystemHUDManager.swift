//
//  SystemHUDManager.swift
//  DynamicIsland
//
//  Created by GitHub Copilot on 06/09/25.
//

import Foundation
import Defaults
import Combine

class SystemHUDManager {
    static let shared = SystemHUDManager()
    
    private var changesObserver: SystemChangesObserver?
    private weak var coordinator: DynamicIslandViewCoordinator?
    
    private init() {
        // Set up observer for settings changes
        setupSettingsObserver()
    }
    
    private func setupSettingsObserver() {
        // Use Defaults publisher instead of @Default property wrapper
        Defaults.publisher(.enableSystemHUD, options: []).sink { [weak self] change in
            Task { @MainActor in
                if change.newValue {
                    await self?.startSystemHUD()
                } else {
                    await self?.stopSystemHUD()
                }
            }
        }.store(in: &cancellables)
    }
    
    private var cancellables = Set<AnyCancellable>()
    
    func setup(coordinator: DynamicIslandViewCoordinator) {
        self.coordinator = coordinator
        
        if Defaults[.enableSystemHUD] {
            Task { @MainActor in
                await startSystemHUD()
            }
        }
    }
    
    @MainActor
    private func startSystemHUD() async {
        guard let coordinator = coordinator else { return }
        
        await stopSystemHUD() // Stop any existing observer
        
        changesObserver = SystemChangesObserver(coordinator: coordinator)
        changesObserver?.startObserving()
        
        // Disable system HUD if possible
        // Note: This would require additional implementation similar to OSDUIManager
        disableSystemHUD()
        
        print("System HUD replacement started")
    }
    
    @MainActor
    private func stopSystemHUD() async {
        changesObserver?.stopObserving()
        changesObserver = nil
        
        // Re-enable system HUD
        enableOriginalSystemHUD()
        
        print("System HUD replacement stopped")
    }
    
    private func disableSystemHUD() {
        print("🔇 Disabling system HUD (OSDUIHelper running: \(SystemOSDManager.isOSDUIHelperRunning()))")
        // Disable the system HUD using SystemOSDManager
        SystemOSDManager.disableSystemHUD()
    }
    
    private func enableOriginalSystemHUD() {
        print("🔊 Re-enabling system HUD (OSDUIHelper running: \(SystemOSDManager.isOSDUIHelperRunning()))")
        // Re-enable the system HUD using SystemOSDManager
        SystemOSDManager.enableSystemHUD()
        
        // Verify it's working after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            let isRunning = SystemOSDManager.isOSDUIHelperRunning()
            print("🔍 OSDUIHelper status after re-enable: \(isRunning ? "✅ Running" : "❌ Not running")")
        }
    }
    
    deinit {
        print("🧹 SystemHUDManager deinitializing - ensuring system HUD is restored")
        cancellables.removeAll()
        Task { @MainActor in
            await stopSystemHUD()
        }
        // Also call the emergency restore as backup
        SystemHUDDebugger.forceRestartOSDUIHelper()
    }
    
    /// Emergency restore function - call this if system HUD is not working
    public static func emergencyRestoreSystemHUD() {
        print("🚨 Emergency system HUD restore initiated")
        SystemHUDDebugger.forceRestartOSDUIHelper()
    }
}