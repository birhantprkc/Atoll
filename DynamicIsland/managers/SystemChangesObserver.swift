//
//  SystemChangesObserver.swift
//  DynamicIsland
//
//  Adapted from TheBoringWorker-HUD ChangesObserver.swift
//  Created by GitHub Copilot on 06/09/25.
//

import Cocoa
import Foundation
import Defaults

class SystemChangesObserver {
    private var oldVolume: Float
    private var oldMuted: Bool
    private var oldBrightness: Float = 0
    
    private weak var coordinator: DynamicIslandViewCoordinator?
    private var timer: Timer?

    init(coordinator: DynamicIslandViewCoordinator) {
        self.coordinator = coordinator
        oldVolume = SystemVolumeManager.getOutputVolume()
        oldMuted = SystemVolumeManager.isMuted()

        do {
            oldBrightness = try SystemDisplayManager.getDisplayBrightness()
        } catch {
            NSLog("Failed to retrieve display brightness: \(error)")
        }
    }

    func startObserving() {
        guard Defaults[.enableSystemHUD] else { return }
        
        createObservers()
        createTimerForContinuousChangesCheck(with: 0.2)
    }

    private func createTimerForContinuousChangesCheck(with seconds: TimeInterval) {
        timer = Timer(
            timeInterval: seconds, target: self, selector: #selector(checkChanges), userInfo: nil,
            repeats: true)
        let mainLoop = RunLoop.main
        mainLoop.add(timer!, forMode: .common)
    }

    private func createObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(showVolumeHUD),
            name: SystemKeyObserver.volumeChanged,
            object: nil)
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(showBrightnessHUD),
            name: SystemKeyObserver.brightnessChanged,
            object: nil)
    }

    @objc func showVolumeHUD() {
        guard Defaults[.enableSystemHUD] && Defaults[.enableVolumeHUD] else { return }
        
        if oldVolume == 0.0 || oldVolume == 1.0 {
            sendVolumeNotification(value: oldVolume)
        }
        print("Showing volume HUD")
    }
    
    @objc func showBrightnessHUD() {
        guard Defaults[.enableSystemHUD] && Defaults[.enableBrightnessHUD] else { return }
        
        if oldBrightness == 0.0 || oldBrightness == 1.0 {
            sendBrightnessNotification(value: oldBrightness)
        }
        print("Showing brightness HUD")
    }

    @objc func checkChanges() {
        guard Defaults[.enableSystemHUD] else { return }
        
        checkBrightnessChanges()
        checkVolumeChanges()
    }

    private func isAlmost(firstNumber: Float, secondNumber: Float) -> Bool {
        let marginValue = 5 / 100.0
        return (firstNumber + Float(marginValue) >= secondNumber && firstNumber - Float(marginValue) <= secondNumber)
    }

    private func checkVolumeChanges() {
        guard Defaults[.enableVolumeHUD] else { return }
        
        let newVolume = SystemVolumeManager.getOutputVolume()
        let newMuted = SystemVolumeManager.isMuted()
        
        if !isAlmost(firstNumber: oldVolume, secondNumber: newVolume) || newMuted != oldMuted {
            if newMuted {
                sendVolumeNotification(value: 0.0)
            } else {
                sendVolumeNotification(value: newVolume)
            }
            oldVolume = newVolume
            oldMuted = newMuted
        }
    }

    private func checkBrightnessChanges() {
        guard Defaults[.enableBrightnessHUD] else { return }
        
        if NSScreen.screens.count == 0 {
            return
        }
        
        do {
            let newBrightness = try SystemDisplayManager.getDisplayBrightness()
            if !isAlmost(firstNumber: oldBrightness, secondNumber: newBrightness) {
                sendBrightnessNotification(value: newBrightness)
                oldBrightness = newBrightness
            }
        } catch {
            NSLog("Failed to retrieve display brightness: \(error)")
        }
    }
    
    // MARK: - Internal Notification Methods
    
    private func sendVolumeNotification(value: Float) {
        coordinator?.toggleSneakPeek(
            status: true,
            type: .volume,
            value: CGFloat(value),
            icon: ""
        )
    }
    
    private func sendBrightnessNotification(value: Float) {
        coordinator?.toggleSneakPeek(
            status: true,
            type: .brightness,
            value: CGFloat(value),
            icon: ""
        )
    }
    
    deinit {
        stopObserving()
    }
    
    func stopObserving() {
        timer?.invalidate()
        timer = nil
        NotificationCenter.default.removeObserver(self)
    }
}