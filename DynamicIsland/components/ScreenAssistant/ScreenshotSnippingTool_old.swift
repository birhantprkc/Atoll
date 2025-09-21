// This file has been replaced - keeping for reference only

// MARK: - Screenshot Snipping Tool
class ScreenshotSnippingTool: NSObject, ObservableObject {
    static let shared = ScreenshotSnippingTool()
    
    @Published var isSnipping = false
    @Published var hasPermissions = false
    @Published var permissionStatus: PermissionStatus = .unknown
    private var snippingWindow: SnippingWindow?
    
    enum PermissionStatus {
        case unknown
        case granted
        case denied
        case restricted
    }
    
    override init() {
        super.init()
        checkPermissionsAsync()
    }
    
    private func checkPermissionsAsync() {
        Task {
            await checkPermissions()
        }
    }
    
    @MainActor
    func checkPermissions() async {
        print("🔍 ScreenshotTool: Checking permissions for bundle: \(Bundle.main.bundleIdentifier ?? "unknown")")
        
        do {
            // First try a simple content check to see if we can access ScreenCaptureKit
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)
            
            // If we get here without error, permissions are granted
            self.hasPermissions = true
            self.permissionStatus = .granted
            print("✅ ScreenshotTool: Permissions granted for \(content.displays.count) displays")
            
        } catch let error as NSError {
            print("❌ ScreenshotTool: Permission error - Code: \(error.code), Domain: \(error.domain)")
            
            // Handle specific error codes
            switch error.code {
            case -3801: // User declined TCC permission
                self.hasPermissions = false
                self.permissionStatus = .denied
                print("❌ ScreenshotTool: Permission denied by user - TCC database entry missing or denied")
                
            case -3802: // App is not authorized for screen capture
                self.hasPermissions = false
                self.permissionStatus = .restricted
                print("❌ ScreenshotTool: App not authorized for screen capture - System restriction")
                
            default:
                self.hasPermissions = false
                self.permissionStatus = .unknown
                print("❌ ScreenshotTool: Unknown permission error - \(error.localizedDescription)")
            }
            
            // Provide user guidance
            DispatchQueue.main.async {
                self.showPermissionGuidance()
            }
        }
    }
    
    private func showPermissionGuidance() {
        let alert = NSAlert()
        alert.messageText = "Screen Recording Permission Required"
        alert.informativeText = """
        Dynamic Island needs screen recording permission to capture screenshots.
        
        To enable this:
        1. Open System Settings (or System Preferences)
        2. Go to Privacy & Security → Screen Recording
        3. Enable 'Dynamic Island'
        4. Restart the app if needed
        """
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Cancel")
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            // Open System Settings to Screen Recording
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
                NSWorkspace.shared.open(url)
            }
        }
    }
    
    func requestPermissions() async {
        // Only request if we don't already have them
        guard !hasPermissions else { return }
        await checkPermissions()
    }
    
    func startSnipping() {
        guard !isSnipping else { return }
        
        // Check permissions first
        if !hasPermissions {
            print("❌ ScreenshotTool: No permissions - checking status")
            Task {
                await requestPermissions()
            }
            return
        }
        
        print("🖼️ ScreenshotTool: Starting screen snipping")
        isSnipping = true
        
        // Hide all app windows temporarily
        hideAppWindows()
        
        // Create snipping overlay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.createSnippingOverlay()
        }
    }
    
    private func hideAppWindows() {
        for window in NSApp.windows {
            window.orderOut(nil)
        }
    }
    
    private func restoreAppWindows() {
        for window in NSApp.windows {
            if window != snippingWindow {
                window.orderFront(nil)
            }
        }
    }
    
    private func createSnippingOverlay() {
        guard let screen = NSScreen.main else { 
            print("❌ ScreenshotTool: No main screen available")
            finishSnipping()
            return 
        }
        
        print("🎯 ScreenshotTool: Creating snipping overlay")
        
        snippingWindow = SnippingWindow(screen: screen) { [weak self] rect in
            guard let self = self else {
                print("❌ ScreenshotTool: Self deallocated during area selection")
                return
            }
            self.captureScreenArea(rect)
        }
        
        guard let window = snippingWindow else {
            print("❌ ScreenshotTool: Failed to create snipping window")
            finishSnipping()
            return
        }
        
        // Just make it key and order front, don't try to make it main
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
        
        // Activate the app to ensure proper focus
        NSApp.activate(ignoringOtherApps: true)
        
        print("✅ ScreenshotTool: Snipping overlay created and activated")
    }
    
    private func captureScreenArea(_ rect: CGRect) {
        print("🖼️ ScreenshotTool: Capturing area: \(rect)")
        
        Task {
            do {
                let screenshot = try await captureScreenshot(rect: rect)
                
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { 
                        print("❌ ScreenshotTool: Self deallocated during screenshot callback")
                        return 
                    }
                    
                    print("✅ ScreenshotTool: Screenshot saved successfully")
                    
                    // Capture screenshot URL before cleanup
                    let screenshotURL = screenshot
                    
                    // Finish snipping first to clean up window state
                    self.finishSnipping()
                    
                    // Post notification after cleanup with captured URL
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        print("📸 ScreenshotTool: Posting screenshot notification")
                        NotificationCenter.default.post(
                            name: Notification.Name("screenshotCaptured"),
                            object: screenshotURL
                        )
                        print("✅ ScreenshotTool: Notification posted successfully")
                    }
                }
            } catch {
                print("❌ ScreenshotTool: Failed to capture screenshot - \(error)")
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    
                    // Show error to user
                    self.showScreenshotError(error)
                    self.finishSnipping()
                }
            }
        }
    }
    
    private func showScreenshotError(_ error: Error) {
        let alert = NSAlert()
        alert.messageText = "Screenshot Failed"
        alert.informativeText = "Failed to capture screenshot: \(error.localizedDescription)"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    
    private func captureScreenshot(rect: CGRect) async throws -> URL {
        // Use ScreenCaptureKit for modern screenshot capture
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        
        guard let display = content.displays.first else {
            throw ScreenshotError.noDisplayFound
        }
        
        let config = SCStreamConfiguration()
        config.width = Int(rect.width)
        config.height = Int(rect.height)
        config.sourceRect = rect
        config.pixelFormat = kCVPixelFormatType_32BGRA
        config.showsCursor = false
        
        let filter = SCContentFilter(display: display, excludingWindows: [])
        let image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
        
        // Ensure screenshot directory exists
        let screenshotDir = ScreenAssistantManager.screenshotDataDirectory
        if !FileManager.default.fileExists(atPath: screenshotDir.path) {
            try FileManager.default.createDirectory(at: screenshotDir, withIntermediateDirectories: true)
        }
        
        // Save to temporary file
        let filename = "screenshot_\(Date().timeIntervalSince1970).png"
        let screenshotURL = screenshotDir.appendingPathComponent(filename)
        
        // Create NSImage from CGImage and convert to PNG
        let nsImage = NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height))
        
        guard let imageData = nsImage.tiffRepresentation,
              let bitmapRep = NSBitmapImageRep(data: imageData),
              let pngData = bitmapRep.representation(using: NSBitmapImageRep.FileType.png, properties: [:]) else {
            throw ScreenshotError.imageConversionFailed
        }
        
        do {
            try pngData.write(to: screenshotURL)
            print("✅ ScreenshotTool: Saved screenshot to: \(screenshotURL.path)")
            return screenshotURL
        } catch {
            print("❌ ScreenshotTool: Failed to write screenshot file - \(error)")
            throw ScreenshotError.fileWriteError
        }
    }
    
    private func finishSnipping() {
        guard isSnipping else { 
            print("⚠️ ScreenshotTool: finishSnipping called but not currently snipping")
            return 
        }
        
        print("🔄 ScreenshotTool: Finishing snipping process")
        
        isSnipping = false
        
        // Close and cleanup snipping window safely
        if let window = snippingWindow {
            window.orderOut(nil)
            window.close()
            snippingWindow = nil
            print("🪟 ScreenshotTool: Snipping window closed and cleared")
        }
        
        // Restore app windows with delay to prevent conflicts
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.restoreAppWindows()
            print("🏠 ScreenshotTool: App windows restored")
        }
        
        print("✅ ScreenshotTool: Snipping process completed")
    }
    
    func cancelSnipping() {
        finishSnipping()
    }
}

// MARK: - Snipping Window
class SnippingWindow: NSWindow {
    private let onAreaSelected: (CGRect) -> Void
    private var selectionOverlay: SelectionOverlayView?
    
    init(screen: NSScreen, onAreaSelected: @escaping (CGRect) -> Void) {
        self.onAreaSelected = onAreaSelected
        
        super.init(
            contentRect: screen.frame,
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        setupWindow(screen: screen)
        setupContent()
    }
    
    override var canBecomeKey: Bool {
        return true
    }
    
    override var canBecomeMain: Bool {
        return true
    }
    
    private func setupWindow(screen: NSScreen) {
        backgroundColor = NSColor.black.withAlphaComponent(0.3)
        isOpaque = false
        level = .screenSaver
        ignoresMouseEvents = false
        acceptsMouseMovedEvents = true
        isMovableByWindowBackground = false
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        setFrame(screen.frame, display: true)
    }
    
    private func setupContent() {
        selectionOverlay = SelectionOverlayView { [weak self] rect in
            self?.onAreaSelected(rect)
        }
        
        if let overlay = selectionOverlay {
            let hostingView = NSHostingView(rootView: overlay)
            contentView = hostingView
        }
    }
    
    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { // ESC key
            close()
            ScreenshotSnippingTool.shared.cancelSnipping()
        } else {
            super.keyDown(with: event)
        }
    }
}

// MARK: - Selection Overlay View
struct SelectionOverlayView: NSViewRepresentable {
    let onAreaSelected: (CGRect) -> Void
    
    func makeNSView(context: Context) -> SelectionView {
        let view = SelectionView()
        view.onAreaSelected = onAreaSelected
        return view
    }
    
    func updateNSView(_ nsView: SelectionView, context: Context) {}
}

// MARK: - Selection View
class SelectionView: NSView {
    var onAreaSelected: ((CGRect) -> Void)?
    private var startPoint: CGPoint?
    private var currentRect: CGRect = .zero
    private var isDragging = false
    
    override func awakeFromNib() {
        super.awakeFromNib()
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
    }
    
    override func mouseDown(with event: NSEvent) {
        startPoint = convert(event.locationInWindow, from: nil)
        isDragging = true
        currentRect = .zero
        needsDisplay = true
    }
    
    override func mouseDragged(with event: NSEvent) {
        guard let start = startPoint, isDragging else { return }
        
        let currentPoint = convert(event.locationInWindow, from: nil)
        
        let x = min(start.x, currentPoint.x)
        let y = min(start.y, currentPoint.y)
        let width = abs(currentPoint.x - start.x)
        let height = abs(currentPoint.y - start.y)
        
        currentRect = CGRect(x: x, y: y, width: width, height: height)
        needsDisplay = true
    }
    
    override func mouseUp(with event: NSEvent) {
        guard isDragging, !currentRect.isEmpty else {
            isDragging = false
            return
        }
        
        isDragging = false
        
        // Convert to screen coordinates
        if let window = self.window {
            let screenRect = window.convertToScreen(currentRect)
            // Flip Y coordinate for screen capture
            let flippedRect = CGRect(
                x: screenRect.origin.x,
                y: NSScreen.main!.frame.height - screenRect.origin.y - screenRect.height,
                width: screenRect.width,
                height: screenRect.height
            )
            onAreaSelected?(flippedRect)
        }
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        guard isDragging, !currentRect.isEmpty else { return }
        
        // Draw selection rectangle
        NSColor.systemBlue.withAlphaComponent(0.3).setFill()
        currentRect.fill()
        
        NSColor.systemBlue.setStroke()
        let path = NSBezierPath(rect: currentRect)
        path.lineWidth = 2.0
        path.stroke()
        
        // Draw selection info
        let infoText = String(format: "%.0f × %.0f", currentRect.width, currentRect.height)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 12),
            .foregroundColor: NSColor.white,
            .backgroundColor: NSColor.black.withAlphaComponent(0.8)
        ]
        
        let attributedString = NSAttributedString(string: infoText, attributes: attributes)
        let textRect = CGRect(
            x: currentRect.maxX - 80,
            y: currentRect.minY - 20,
            width: 80,
            height: 20
        )
        
        attributedString.draw(in: textRect)
    }
}

// MARK: - Screenshot Error Types
enum ScreenshotError: Error, LocalizedError {
    case noDisplayFound
    case imageConversionFailed
    case fileWriteError
    
    var errorDescription: String? {
        switch self {
        case .noDisplayFound:
            return "No display found for screenshot capture"
        case .imageConversionFailed:
            return "Failed to convert screenshot image"
        case .fileWriteError:
            return "Failed to save screenshot file"
        }
    }
}

// MARK: - ScreenAssistantManager Extension for Screenshot Directory
extension ScreenAssistantManager {
    static var screenshotDataDirectory: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDir = appSupport.appendingPathComponent(bundleIdentifier)
        let screenshotDir = appDir.appendingPathComponent("Screenshots")
        
        // Create directory if it doesn't exist
        try? FileManager.default.createDirectory(at: screenshotDir, withIntermediateDirectories: true)
        
        return screenshotDir
    }
}