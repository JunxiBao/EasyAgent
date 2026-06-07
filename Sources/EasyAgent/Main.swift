import SwiftUI
import AppKit
import Carbon

@main
struct EasyAgentApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    @AppStorage("ShortcutCmd") var cmd = true
    @AppStorage("ShortcutOpt") var opt = true
    @AppStorage("ShortcutCtrl") var ctrl = false
    @AppStorage("ShortcutShift") var shift = false
    @AppStorage("ShortcutKey") var keyName = "Space"
    
    var shortcutKey: KeyEquivalent {
        switch keyName {
        case "Space": return .space
        case "Enter": return .return
        case "Tab": return .tab
        default:
            if let first = keyName.first {
                return KeyEquivalent(Character(first.lowercased()))
            }
            return .space
        }
    }
    
    var shortcutModifiers: SwiftUI.EventModifiers {
        var mods: SwiftUI.EventModifiers = []
        if cmd { mods.insert(.command) }
        if opt { mods.insert(.option) }
        if ctrl { mods.insert(.control) }
        if shift { mods.insert(.shift) }
        return mods
    }
    
    var body: some Scene {
        MenuBarExtra("Easy Agent", systemImage: "cpu") {
            Button("Show Chat Panel") {
                appDelegate.showMainWindow()
            }
            .keyboardShortcut(shortcutKey, modifiers: shortcutModifiers)
            
            Button("Settings...") {
                appDelegate.showSettingsWindow()
            }
            
            Divider()
            
            Button("Quit Easy Agent") {
                NSApp.terminate(nil)
            }
        }
    }
}

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    var mainWindowController: MainWindowController?
    var settingsWindow: NSWindow?
    let connection = AgentConnection()
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Set activation policy to accessory so it runs in menu bar
        NSApp.setActivationPolicy(.accessory)
        
        let defaults = UserDefaults.standard
        
        // Load Appearance
        let scheme = defaults.integer(forKey: "AppColorScheme")
        switch scheme {
        case 1: NSApp.appearance = NSAppearance(named: .aqua)
        case 2: NSApp.appearance = NSAppearance(named: .darkAqua)
        default: NSApp.appearance = nil
        }
        
        // Load configurations and connect if a path is configured
        let path = defaults.string(forKey: "AgentExecutablePath") ?? ""
        if !path.isEmpty {
            let config = AgentConfig.fromDefaults()
            connection.connect(config: config)
        }
        
        // Setup global hotkey
        registerGlobalHotkey()
        
        // Setup main window controller
        let mainView = MainWindowView(
            connection: connection,
            onSettingsClicked: { [weak self] in
                self?.showSettingsWindow()
            },
            onHideClicked: { [weak self] in
                self?.mainWindowController?.hide()
            },
            onResize: { [weak self] isExpanded in
                self?.mainWindowController?.updateWindowSize(isExpanded: isExpanded)
            }
        )
        mainWindowController = MainWindowController(rootView: AnyView(mainView))
    }
    
    func showMainWindow() {
        checkAndConnect()
        mainWindowController?.show()
    }
    
    private func checkAndConnect() {
        var needsConnection = false
        if connection.status == .disconnected { needsConnection = true }
        if case .error = connection.status { needsConnection = true }
        
        if needsConnection {
            let path = UserDefaults.standard.string(forKey: "AgentExecutablePath") ?? ""
            if !path.isEmpty {
                let config = AgentConfig.fromDefaults()
                connection.connect(config: config)
            }
        }
    }
    
    func showSettingsWindow() {
        if let window = settingsWindow {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 550),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Easy Agent Settings"
        window.center()
        window.isReleasedWhenClosed = false
        
        let settingsView = SettingsWindowView(
            connection: connection,
            onSave: { [weak self] in
                self?.handleSettingsSaved()
            },
            onClose: { [weak self] in
                self?.settingsWindow?.close()
                self?.settingsWindow = nil
            }
        )
        
        window.contentView = NSHostingView(rootView: settingsView)
        self.settingsWindow = window
        
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    func handleSettingsSaved() {
        // 1. Reconnect the agent with new configs
        let config = AgentConfig.fromDefaults()
        connection.connect(config: config)
        
        // 2. Re-register global hotkey
        registerGlobalHotkey()
        
        // 3. Close settings window
        settingsWindow?.close()
        settingsWindow = nil
    }
    
    private func registerGlobalHotkey() {
        let defaults = UserDefaults.standard
        
        let cmd = defaults.object(forKey: "ShortcutCmd") == nil ? true : defaults.bool(forKey: "ShortcutCmd")
        let opt = defaults.object(forKey: "ShortcutOpt") == nil ? true : defaults.bool(forKey: "ShortcutOpt")
        let ctrl = defaults.bool(forKey: "ShortcutCtrl")
        let shift = defaults.bool(forKey: "ShortcutShift")
        let keyName = defaults.string(forKey: "ShortcutKey") ?? "Space"
        
        // Carbon modifiers calculation
        var carbonMods: UInt32 = 0
        if cmd { carbonMods |= UInt32(cmdKey) }
        if opt { carbonMods |= UInt32(optionKey) }
        if ctrl { carbonMods |= UInt32(controlKey) }
        if shift { carbonMods |= UInt32(shiftKey) }
        
        let keyCode = carbonKeyCodes[keyName] ?? 49 // Default to Space
        
        HotkeyManager.shared.register(keyCode: keyCode, carbonModifiers: carbonMods) { [weak self] in
            DispatchQueue.main.async {
                self?.mainWindowController?.toggle()
                if self?.mainWindowController?.window?.isVisible == true {
                    self?.checkAndConnect()
                }
            }
        }
    }

    
    func applicationWillTerminate(_ notification: Notification) {
        connection.disconnect()
    }
}
