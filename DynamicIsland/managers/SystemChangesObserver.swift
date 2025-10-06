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
import CoreAudio

class SystemChangesObserver {
    private var oldVolume: Float = 0
    private var oldMuted: Bool = false
    private var oldBrightness: Float = 0
    
    private weak var coordinator: DynamicIslandViewCoordinator?
    
    // Adaptive polling timer
    private var pollingTimer: Timer?
    private var currentPollingInterval: TimeInterval = 2.0
    
    // Polling intervals
    private let rapidPollingInterval: TimeInterval = 0.05 // Burst mode for 5 seconds after key press
    private let fastPollingInterval: TimeInterval = 0.3   // Fast mode when headphones connected
    private let normalPollingInterval: TimeInterval = 2.0 // Normal mode when idle
    
    // Activity tracking
    private var lastBrightnessChangeTime: Date = Date.distantPast
    private var lastVolumeChangeTime: Date = Date.distantPast
    private var lastVolumeCheckTime: Date = Date.distantPast
    
    // Headphone detection
    private var hasHeadphonesConnected: Bool = false

    init(coordinator: DynamicIslandViewCoordinator) {
        self.coordinator = coordinator
        
        // Initialize baseline values only once
        oldVolume = SystemVolumeManager.getOutputVolume()
        oldMuted = SystemVolumeManager.isMuted()
        
        do {
            oldBrightness = try SystemDisplayManager.getDisplayBrightness()
        } catch {
            NSLog("Failed to retrieve initial display brightness: \(error)")
        }
        
        // Detect headphones on init
        updateHeadphoneStatus()
        setupAudioRouteChangeListener()
    }

    func startObserving() {
        guard Defaults[.enableSystemHUD] else { return }
        
        // Start with appropriate polling rate
        startPollingTimer(interval: determinePollingInterval())
    }
    
    private func determinePollingInterval() -> TimeInterval {
        let now = Date()
        
        // Burst mode: Rapid polling within 5 seconds of any key press
        if now.timeIntervalSince(lastVolumeChangeTime) < 5.0 ||
           now.timeIntervalSince(lastBrightnessChangeTime) < 5.0 {
            return rapidPollingInterval
        }
        
        // Fast mode: When headphones are connected
        if hasHeadphonesConnected {
            return fastPollingInterval
        }
        
        // Normal mode: Idle state
        return normalPollingInterval
    }
    
    private func startPollingTimer(interval: TimeInterval) {
        // Don't restart if same interval
        if pollingTimer != nil && currentPollingInterval == interval {
            return
        }
        
        currentPollingInterval = interval
        pollingTimer?.invalidate()
        
        pollingTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            guard let self = self, Defaults[.enableSystemHUD] else { return }
            
            // Check if we need to adjust polling rate
            let newInterval = self.determinePollingInterval()
            if newInterval != self.currentPollingInterval {
                self.startPollingTimer(interval: newInterval)
                return
            }
            
            // Poll volume
            self.checkVolumeChanges()
            
            // Poll brightness only within 5 seconds of key press
            if Date().timeIntervalSince(self.lastBrightnessChangeTime) < 5.0 {
                self.checkBrightnessChanges()
            }
        }
        
        let mode = interval == rapidPollingInterval ? "BURST (50ms)" :
                   interval == fastPollingInterval ? "FAST (300ms)" : "NORMAL (2s)"
        print("✅ Polling started: \(mode) mode")
    }
    
    // MARK: - Headphone Detection
    
    private func setupAudioRouteChangeListener() {
        // Listen for default audio device changes
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        AudioObjectAddPropertyListener(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            audioDeviceChangeListener,
            Unmanaged.passUnretained(self).toOpaque()
        )
    }
    
    @objc fileprivate func audioRouteChanged() {
        updateHeadphoneStatus()
        
        // Adjust polling rate immediately
        startPollingTimer(interval: determinePollingInterval())
    }
    
    private func updateHeadphoneStatus() {
        // Check for headphones/external audio devices
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        var deviceID: AudioDeviceID = 0
        var propertySize = UInt32(MemoryLayout<AudioDeviceID>.size)
        
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            &propertySize,
            &deviceID
        )
        
        guard status == noErr else {
            hasHeadphonesConnected = false
            return
        }
        
        // Check if device is not built-in speakers
        var transportType: UInt32 = 0
        var transportSize = UInt32(MemoryLayout<UInt32>.size)
        var transportAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyTransportType,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        let transportStatus = AudioObjectGetPropertyData(
            deviceID,
            &transportAddress,
            0,
            nil,
            &transportSize,
            &transportType
        )
        
        // Consider headphones if: Bluetooth, USB, or any non-built-in device
        let wasConnected = hasHeadphonesConnected
        hasHeadphonesConnected = transportStatus == noErr && 
                                 transportType != kAudioDeviceTransportTypeBuiltIn
        
        if wasConnected != hasHeadphonesConnected {
            print(hasHeadphonesConnected ? "🎧 Headphones connected - switching to FAST polling" : 
                                          "🔊 Headphones disconnected - switching to NORMAL polling")
        }
    }
    
    // MARK: - Public Media Key Event Handlers (called from MediaKeyApplication)
    
    func handleVolumeKeyEvent() {
        // Mark as user-initiated and trigger burst mode
        lastVolumeChangeTime = Date()
        
        // Switch to burst mode immediately
        startPollingTimer(interval: rapidPollingInterval)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            self.handleVolumeKeyPress()
        }
    }
    
    func handleBrightnessKeyEvent() {
        // Mark as user-initiated and trigger burst mode
        lastBrightnessChangeTime = Date()
        
        // Switch to burst mode immediately
        startPollingTimer(interval: rapidPollingInterval)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            self.handleBrightnessKeyPress()
        }
    }
    
    // MARK: - Key Press Event Handlers
    
    private func handleVolumeKeyPress() {
        guard Defaults[.enableVolumeHUD] else { return }
        
        // Mark as user-initiated (don't debounce key presses)
        lastVolumeChangeTime = Date()
        
        let newVolume = SystemVolumeManager.getOutputVolume()
        let newMuted = SystemVolumeManager.isMuted()
        
        // Always show HUD for key press feedback, even if value doesn't change
        print("🔊 Volume key pressed - showing HUD: volume=\(newVolume), muted=\(newMuted)")
        
        if newMuted {
            sendVolumeNotification(value: 0.0)
        } else {
            sendVolumeNotification(value: newVolume)
        }
        
        // Update stored values
        oldVolume = newVolume
        oldMuted = newMuted
    }
    
    private func handleBrightnessKeyPress() {
        guard Defaults[.enableBrightnessHUD] else { return }
        guard NSScreen.screens.count > 0 else { return }
        
        do {
            let newBrightness = try SystemDisplayManager.getDisplayBrightness()
            
            // Always show HUD for key press feedback, even if value doesn't change
            print("☀️ Brightness key pressed - showing HUD: brightness=\(newBrightness) [BURST MODE]")
            sendBrightnessNotification(value: newBrightness)
            
            // Update stored value
            oldBrightness = newBrightness
        } catch {
            // Silently ignore brightness errors to reduce log spam
        }
    }
    
    // MARK: - Polling Check Methods
    
    private func checkVolumeChanges() {
        guard Defaults[.enableVolumeHUD] else { return }
        
        // Throttle AppleScript checks based on current mode
        let now = Date()
        let minInterval: TimeInterval = currentPollingInterval == rapidPollingInterval ? 0.05 : 0.2
        
        if now.timeIntervalSince(lastVolumeCheckTime) < minInterval {
            return
        }
        lastVolumeCheckTime = now
        
        let newVolume = SystemVolumeManager.getOutputVolume()
        let newMuted = SystemVolumeManager.isMuted()
        
        let volumeChanged = !isAlmost(firstNumber: oldVolume, secondNumber: newVolume)
        let muteChanged = newMuted != oldMuted
        
        if volumeChanged || muteChanged {
            // Don't show HUD if change was just triggered by key press (within 0.1s in burst mode, 0.3s otherwise)
            let debounceWindow = currentPollingInterval == rapidPollingInterval ? 0.1 : 0.3
            let timeSinceKeyPress = now.timeIntervalSince(lastVolumeChangeTime)
            
            if timeSinceKeyPress > debounceWindow {
                let mode = currentPollingInterval == rapidPollingInterval ? "[BURST]" : "[EXTERNAL]"
                print("🔊 Volume change detected \(mode): \(oldVolume) → \(newVolume), muted: \(oldMuted) → \(newMuted)")
                
                if newMuted {
                    sendVolumeNotification(value: 0.0)
                } else {
                    sendVolumeNotification(value: newVolume)
                }
            }
            
            oldVolume = newVolume
            oldMuted = newMuted
        }
    }

    private func checkBrightnessChanges() {
        guard Defaults[.enableBrightnessHUD] else { return }
        guard NSScreen.screens.count > 0 else { return }
        
        do {
            let newBrightness = try SystemDisplayManager.getDisplayBrightness()
            let brightnessChanged = !isAlmost(firstNumber: oldBrightness, secondNumber: newBrightness)
            
            if brightnessChanged {
                print("☀️ Brightness change detected: \(oldBrightness) → \(newBrightness)")
                sendBrightnessNotification(value: newBrightness)
                oldBrightness = newBrightness
            }
        } catch {
            // Silently ignore brightness errors to reduce log spam
        }
    }
    
    private func isAlmost(firstNumber: Float, secondNumber: Float) -> Bool {
        // Convert sensitivity setting to a more responsive threshold
        // Sensitivity 1-10 scale maps to 0.01-0.10 threshold range
        let marginValue = Float(Defaults[.systemHUDSensitivity]) / 100.0
        let threshold = max(0.01, marginValue) // Minimum threshold for responsiveness
        return abs(firstNumber - secondNumber) <= threshold
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
        // Remove audio device change listener
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        AudioObjectRemovePropertyListener(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            audioDeviceChangeListener,
            Unmanaged.passUnretained(self).toOpaque()
        )
        
        stopObserving()
    }
    
    func stopObserving() {
        // Clean up polling timer
        pollingTimer?.invalidate()
        pollingTimer = nil
        
        print("🎹 Media key detection stopped")
    }
}

// MARK: - CoreAudio Callback for Device Changes

private func audioDeviceChangeListener(
    _ inObjectID: AudioObjectID,
    _ inNumberAddresses: UInt32,
    _ inAddresses: UnsafePointer<AudioObjectPropertyAddress>,
    _ inClientData: UnsafeMutableRawPointer?
) -> OSStatus {
    guard let inClientData = inClientData else { return noErr }
    
    let observer = Unmanaged<SystemChangesObserver>.fromOpaque(inClientData).takeUnretainedValue()
    
    // Handle on main thread
    DispatchQueue.main.async {
        observer.audioRouteChanged()
    }
    
    return noErr
}


