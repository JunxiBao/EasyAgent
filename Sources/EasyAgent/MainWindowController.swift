import Cocoa
import SwiftUI

class AgentPanelWindow: NSWindow {
    private var dragOrigin: NSPoint?
    
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
    
    // Manual window dragging so buttons always get first click priority
    override func mouseDown(with event: NSEvent) {
        dragOrigin = event.locationInWindow
        // Intentionally don't call super — NSWindow.mouseDown enters
        // a blocking drag tracking loop that swallows subsequent mouse
        // events and prevents buttons from completing their click.
    }
    
    override func mouseDragged(with event: NSEvent) {
        guard let origin = dragOrigin else { return }
        let current = event.locationInWindow
        let dx = current.x - origin.x
        let dy = current.y - origin.y
        var frame = self.frame
        frame.origin.x += dx
        frame.origin.y += dy
        self.setFrameOrigin(frame.origin)
    }
    
    override func mouseUp(with event: NSEvent) {
        dragOrigin = nil
        super.mouseUp(with: event)
    }
}

public class MainWindowController: NSWindowController {
    
    public init(rootView: AnyView) {
        let window = AgentPanelWindow(
            contentRect: NSRect(x: 0, y: 0, width: 700, height: 70),
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = false
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = true
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        
        // Set default position: horizontally centered, near bottom of screen
        if let screen = NSScreen.main {
            let screenRect = screen.visibleFrame
            let windowWidth: CGFloat = 700
            let windowHeight: CGFloat = 70  // collapsed height
            let x = screenRect.origin.x + (screenRect.width - windowWidth) / 2
            // Place the window about 100pt above the bottom of the visible area
            let y = screenRect.origin.y + 100
            window.setFrame(NSRect(x: x, y: y, width: windowWidth, height: windowHeight), display: false)
        }
        
        // Remember user's preferred position across launches
        window.setFrameAutosaveName("EasyAgentMainWindow")
        
        let hostingView = NSHostingView(rootView: rootView)
        hostingView.frame = window.contentView?.bounds ?? .zero
        hostingView.autoresizingMask = [.width, .height]
        window.contentView = hostingView
        
        super.init(window: window)
        
        // Auto hide when user clicks outside
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowDidResignKey),
            name: NSWindow.didResignKeyNotification,
            object: window
        )
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public func toggle() {
        guard let window = window else { return }
        if window.isVisible && window.isKeyWindow {
            hide()
        } else {
            show()
        }
    }
    
    public func show() {
        guard let window = window else { return }
        
        // Notify the view to collapse to spotlight state
        NotificationCenter.default.post(name: Notification.Name("easyAgentDidShowWindow"), object: nil)
        
        window.alphaValue = 0.0
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.2
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            window.animator().alphaValue = 1.0
        }, completionHandler: nil)
    }
    
    @MainActor
    func updateWindowSize(isExpanded: Bool) {
        guard let window = self.window else { return }
        
        let newHeight: CGFloat = isExpanded ? 450 : 70
        let newWidth: CGFloat = 700
        
        var frame = window.frame
        // By NOT changing frame.origin.y, the window naturally expands UPWARDS
        frame.size.height = newHeight
        frame.size.width = newWidth
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.3
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            window.animator().setFrame(frame, display: true)
        }
    }
    
    public func hide() {
        guard let window = window else { return }
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.15
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            window.animator().alphaValue = 0.0
        }, completionHandler: {
            Task { @MainActor in
                window.orderOut(nil)
            }
        })
    }
    
    @objc private func windowDidResignKey(_ notification: Notification) {
        DispatchQueue.main.async { [weak self] in
            // Only keep visible if focus went to another window within THIS app
            // (e.g. Settings window). Hide for everything else (desktop, other apps).
            if let keyWindow = NSApp.keyWindow,
               keyWindow !== self?.window,
               keyWindow.isVisible {
                // Focus moved to another of our own windows — don't hide
                return
            }
            self?.hide()
        }
    }
}
