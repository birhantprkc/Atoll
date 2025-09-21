//
//  ScreenshotSnippingTool.swift
//  DynamicIsland
//
//  Created by Assistant based on ScreenshotApp-main research

import AppKit
import SwiftUI
import Foundation

// MARK: - Simplified Screenshot Tool (Based on ScreenshotApp Research)
class ScreenshotSnippingTool: NSObject, ObservableObject {
    static let shared = ScreenshotSnippingTool()
    
    @Published var isSnipping = false
    private var completion: ((URL) -> Void)?
    
    enum ScreenshotError: Error {
        case captureFailed
        case noImageInPasteboard
        case saveFailed
    }
    
    override init() {
        super.init()
    }
    
    // MARK: - Simple API (Based on ScreenshotApp Implementation)
    func startSnipping(completion: @escaping (URL) -> Void) {
        guard !isSnipping else { return }
        
        print("🖼️ ScreenshotTool: Starting area screenshot using screencapture tool")
        self.completion = completion
        isSnipping = true
        
        // Use the same approach as ScreenshotApp - direct screencapture command
        takeAreaScreenshot()
    }
    
    // MARK: - ScreenshotApp-Style Implementation
    private func takeAreaScreenshot() {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        task.arguments = ["-cs"] // -c = clipboard, -s = area selection
        
        do {
            print("📸 ScreenshotTool: Running screencapture -cs command")
            try task.run()
            task.waitUntilExit()
            
            // Process completed - check if successful
            if task.terminationStatus == 0 {
                print("✅ ScreenshotTool: screencapture completed successfully")
                getImageFromPasteboard()
            } else {
                print("❌ ScreenshotTool: screencapture failed with status: \(task.terminationStatus)")
                finishSnipping()
            }
            
        } catch {
            print("❌ ScreenshotTool: Failed to run screencapture: \(error)")
            finishSnipping()
        }
    }
    
    // MARK: - Pasteboard Integration (ScreenshotApp Pattern)
    private func getImageFromPasteboard() {
        print("� ScreenshotTool: Checking pasteboard for screenshot")
        
        guard NSPasteboard.general.canReadItem(withDataConformingToTypes: NSImage.imageTypes) else {
            print("❌ ScreenshotTool: No image data in pasteboard")
            finishSnipping()
            return
        }
        
        guard let image = NSImage(pasteboard: NSPasteboard.general) else {
            print("❌ ScreenshotTool: Failed to create NSImage from pasteboard")
            finishSnipping()
            return
        }
        
        print("✅ ScreenshotTool: Got image from pasteboard: \(image.size)")
        saveImageAndComplete(image: image)
    }
    
    // MARK: - Image Saving
    private func saveImageAndComplete(image: NSImage) {
        let filename = "screenshot_\(Int(Date().timeIntervalSince1970)).png"
        let screenshotDir = ScreenAssistantManager.screenshotDataDirectory
        
        // Ensure directory exists
        if !FileManager.default.fileExists(atPath: screenshotDir.path) {
            try? FileManager.default.createDirectory(at: screenshotDir, withIntermediateDirectories: true)
        }
        
        let screenshotURL = screenshotDir.appendingPathComponent(filename)
        
        // Convert NSImage to PNG data
        guard let imageData = image.tiffRepresentation,
              let bitmapRep = NSBitmapImageRep(data: imageData),
              let pngData = bitmapRep.representation(using: NSBitmapImageRep.FileType.png, properties: [:]) else {
            print("❌ ScreenshotTool: Failed to convert image to PNG")
            finishSnipping()
            return
        }
        
        do {
            try pngData.write(to: screenshotURL)
            print("✅ ScreenshotTool: Screenshot saved to: \(screenshotURL.path)")
            
            // Execute completion callback
            let callback = self.completion
            self.completion = nil
            finishSnipping()
            
            // Call completion on main thread
            DispatchQueue.main.async {
                callback?(screenshotURL)
            }
            
        } catch {
            print("❌ ScreenshotTool: Failed to save image: \(error)")
            finishSnipping()
        }
    }
    
    // MARK: - State Management
    private func finishSnipping() {
        print("🔄 ScreenshotTool: Finishing snipping process")
        
        DispatchQueue.main.async {
            self.isSnipping = false
            self.completion = nil
            print("✅ ScreenshotTool: Snipping process completed")
        }
    }
    
    func cancelSnipping() {
        print("❌ ScreenshotTool: Snipping cancelled")
        finishSnipping()
    }
}