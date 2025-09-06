//
//  SystemHUDManager.swift
//  DynamicIsland
//
//  Created by GitHub Copilot on 06/09/25.
//

import Foundation
import Defaults

class SystemHUDManager: ObservableObject {
    static let shared = SystemHUDManager()
    
    private var changesObserver: SystemChangesObserver?
    private weak var coordinator: DynamicIslandViewCoordinator?
    
    @Default(.enableSystemHUD) var enableSystemHUD {
        didSet {
            Task { @MainActor in
                if enableSystemHUD {
                    await startSystemHUD()
                } else {
                    await stopSystemHUD()
                }
            }
        }
    }
    
    private init() {}
    
    func setup(coordinator: DynamicIslandViewCoordinator) {
        self.coordinator = coordinator
        
        if enableSystemHUD {
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
        changesObserver = nil
        
        // Re-enable system HUD
        enableOriginalSystemHUD()
        
        print("System HUD replacement stopped")
    }
    
    private func disableSystemHUD() {
        // Disable the system HUD using SystemOSDManager
        SystemOSDManager.disableSystemHUD()
    }
    
    private func enableOriginalSystemHUD() {
        // Re-enable the system HUD using SystemOSDManager
        SystemOSDManager.enableSystemHUD()
    }
    
    deinit {
        Task { @MainActor in
            await stopSystemHUD()
        }
    }
}