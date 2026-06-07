import SwiftUI

public struct SettingsWindowView: View {
    @ObservedObject var connection: AgentConnection
    var onSave: () -> Void
    var onClose: () -> Void
    
    // Agent config fields
    @State private var name = ""
    @State private var modelID = ""
    @State private var executablePath = ""
    @State private var parameters = ""
    @State private var envText = ""
    
    // Shortcut configuration fields
    @State private var cmdSelected = true
    @State private var optSelected = true
    @State private var ctrlSelected = false
    @State private var shiftSelected = false
    @State private var selectedKey = "Space"
    
    // Status text for testing
    @State private var testStatusText = ""
    @State private var testStatusColor: Color = .white
    
    // Appearance
    @AppStorage("AppColorScheme") private var appColorScheme: Int = 0
    @AppStorage("HideMenuBarIcon") private var hideMenuBarIcon: Bool = false
    
    @StateObject private var permissionManager = PermissionManager.shared
    

    
    public init(connection: AgentConnection, onSave: @escaping () -> Void, onClose: @escaping () -> Void) {
        self.connection = connection
        self.onSave = onSave
        self.onClose = onClose
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            TabView {
                // Tab 1: Agent Configuration
                Form {
                    Section(header: Text("Local Agent Configuration (ACP)")) {
                        TextField("Agent Name:", text: $name)
                        TextField("Model ID:", text: $modelID)
                        TextField("Executable Path:", text: $executablePath)
                        TextField("Command Parameters:", text: $parameters)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Environment Variables (KEY=VALUE):")
                                .foregroundColor(.secondary)
                            TextEditor(text: $envText)
                                .font(.system(.body, design: .monospaced))
                                .frame(height: 80)
                                .padding(4)
                                .background(Color(NSColor.textBackgroundColor))
                                .cornerRadius(6)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                                )
                        }
                        .padding(.top, 4)
                    }
                    
                    Section {
                        HStack {
                            Button("Test Connection", action: testConnection)
                            
                            if !testStatusText.isEmpty {
                                Text(testStatusText)
                                    .foregroundColor(testStatusColor)
                                    .font(.callout)
                            }
                        }
                    }
                }
                .formStyle(.grouped)
                .tabItem {
                    Label("Agent", systemImage: "cpu")
                }
                
                // Tab 2: Hotkeys
                Form {
                    Section(header: Text("Global Summon Hotkey")) {
                        HStack(spacing: 16) {
                            Toggle("⌘ Cmd", isOn: $cmdSelected)
                            Toggle("⌥ Option", isOn: $optSelected)
                            Toggle("⌃ Control", isOn: $ctrlSelected)
                            Toggle("⇧ Shift", isOn: $shiftSelected)
                        }
                        
                        Picker("Trigger Key:", selection: $selectedKey) {
                            ForEach(Array(carbonKeyCodes.keys).sorted(), id: \.self) { key in
                                Text(key).tag(key)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(maxWidth: 250)
                    }
                }
                .formStyle(.grouped)
                .tabItem {
                    Label("Hotkeys", systemImage: "keyboard")
                }
                // Tab 3: Appearance
                Form {
                    Section(header: Text("Application Appearance")) {
                        Picker("Color Scheme:", selection: $appColorScheme) {
                            Text("System (Auto)").tag(0)
                            Text("Light").tag(1)
                            Text("Dark").tag(2)
                        }
                        .pickerStyle(.segmented)
                        .onChange(of: appColorScheme) {
                            updateGlobalAppearance()
                        }
                        
                        Text("Changes the overall theme of Easy Agent, including window title bars and glass effects.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.top, 4)
                    }
                    
                    Section(header: Text("Menu Bar")) {
                        Toggle("Hide menu bar icon", isOn: $hideMenuBarIcon)
                        
                        if hideMenuBarIcon {
                            HStack(spacing: 6) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.orange)
                                    .font(.caption)
                                Text("Menu bar icon is hidden. Use your hotkey or relaunch the app to access Settings.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.top, 2)
                        } else {
                            Text("When hidden, Easy Agent only appears via your configured hotkey.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .formStyle(.grouped)
                .tabItem {
                    Label("Appearance", systemImage: "paintpalette")
                }
                
                // Tab 4: Permissions
                Form {
                    Section(header: Text("System Access Permissions")) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("To write files and execute local developer tools, Easy Agent requires appropriate permissions.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.bottom, 6)
                        
                        // Desktop Access
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Desktop Folder Access")
                                    .font(.body)
                                    .fontWeight(.medium)
                                Text("Allows writing files to your Desktop.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            if permissionManager.hasDesktopAccess {
                                HStack(spacing: 4) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                    Text("Granted")
                                        .font(.subheadline)
                                        .foregroundColor(.green)
                                }
                            } else {
                                Button("Request Access") {
                                    permissionManager.requestDesktopAccess()
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                        .padding(.vertical, 4)
                        
                        // Full Disk Access
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Full Disk Access")
                                    .font(.body)
                                    .fontWeight(.medium)
                                Text("Allows execution of CLI tools and scripts.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            if permissionManager.hasFullDiskAccess {
                                HStack(spacing: 4) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                    Text("Granted")
                                        .font(.subheadline)
                                        .foregroundColor(.green)
                                }
                            } else {
                                Button("Grant in Settings...") {
                                    permissionManager.openSystemSettingsForFullDiskAccess()
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    
                    Section {
                        Button("Refresh Status") {
                            permissionManager.checkAllPermissions()
                        }
                    }
                }
                .formStyle(.grouped)
                .tabItem {
                    Label("Permissions", systemImage: "shield.righthalf.filled")
                }
                
                // Tab 5: About
                Form {
                    Section(header: Text("Easy Agent")) {
                        HStack(spacing: 12) {
                            Image(systemName: "cpu")
                                .font(.system(size: 32, weight: .bold))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [Color.cyan, Color.purple],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Easy Agent")
                                    .font(.system(size: 16, weight: .bold, design: .rounded))
                                if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
                                    Text("Version \(version)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                        
                        Text("A lightweight macOS menu-bar app for running local AI agents via the Agent Communication Protocol (ACP).")
                            .font(.callout)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    
                    Section(header: Text("Open Source")) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Easy Agent is open source and welcomes contributions and forks!")
                                .font(.callout)
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                            
                            Link(destination: URL(string: "https://github.com/JunxiBao/EasyAgent")!) {
                                HStack(spacing: 6) {
                                    Image(systemName: "link")
                                    Text("github.com/JunxiBao/EasyAgent")
                                        .underline()
                                }
                                .font(.callout)
                            }
                            
                            Text("Fork it, build on it, and make it your own. PRs are welcome!")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                    
                    Section(header: Text("License")) {
                        Text("Released under the MIT License.")
                            .font(.callout)
                            .foregroundColor(.secondary)
                    }
                }
                .formStyle(.grouped)
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
            }
            .padding(.top, 10)
            
            Divider()
            
            // Persistent Bottom Bar for Action Buttons
            HStack {
                Spacer()
                
                Button("Cancel", role: .cancel, action: onClose)
                    .keyboardShortcut(.cancelAction)
                
                Button("Save Settings", action: saveSettings)
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))
        }
        .frame(width: 680, height: 500)
        .onAppear(perform: loadSettings)
    }
    
    private func loadSettings() {
        let defaults = UserDefaults.standard
        name = defaults.string(forKey: "AgentName") ?? "Hermes Local"
        modelID = defaults.string(forKey: "AgentModelID") ?? "hermes-3"
        executablePath = defaults.string(forKey: "AgentExecutablePath") ?? ""
        parameters = defaults.string(forKey: "AgentParameters") ?? "acp"
        envText = defaults.string(forKey: "AgentEnvText") ?? ""
        
        cmdSelected = defaults.object(forKey: "ShortcutCmd") == nil ? true : defaults.bool(forKey: "ShortcutCmd")
        optSelected = defaults.object(forKey: "ShortcutOpt") == nil ? true : defaults.bool(forKey: "ShortcutOpt")
        ctrlSelected = defaults.bool(forKey: "ShortcutCtrl")
        shiftSelected = defaults.bool(forKey: "ShortcutShift")
        selectedKey = defaults.string(forKey: "ShortcutKey") ?? "Space"
    }
    
    private func testConnection() {
        testStatusText = "Testing..."
        testStatusColor = .orange
        
        let config = buildConfig()
        let testConnection = AgentConnection()
        
        testConnection.connect(config: config)
        
        Task { @MainActor in
            var checks = 0
            while checks <= 6 {
                // Sleep for 500ms
                try? await Task.sleep(nanoseconds: 500_000_000)
                checks += 1
                
                if testConnection.status == .connected {
                    testStatusText = "Connected successfully!"
                    testStatusColor = .green
                    testConnection.disconnect()
                    return
                } else if case .error(let err) = testConnection.status {
                    testStatusText = "Failed: \(err)"
                    testStatusColor = .red
                    testConnection.disconnect()
                    return
                }
            }
            testStatusText = "Timeout: process launched but didn't respond."
            testStatusColor = .orange
            testConnection.disconnect()
        }
    }
    
    private func saveSettings() {
        let defaults = UserDefaults.standard
        defaults.set(name, forKey: "AgentName")
        defaults.set(modelID, forKey: "AgentModelID")
        defaults.set(executablePath, forKey: "AgentExecutablePath")
        defaults.set(parameters, forKey: "AgentParameters")
        defaults.set(envText, forKey: "AgentEnvText")
        
        defaults.set(cmdSelected, forKey: "ShortcutCmd")
        defaults.set(optSelected, forKey: "ShortcutOpt")
        defaults.set(ctrlSelected, forKey: "ShortcutCtrl")
        defaults.set(shiftSelected, forKey: "ShortcutShift")
        defaults.set(selectedKey, forKey: "ShortcutKey")
        
        onSave()
    }
    
    private func buildConfig() -> AgentConfig {
        var env: [String: String] = [:]
        let lines = envText.components(separatedBy: .newlines)
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { continue }
            let parts = trimmed.split(separator: "=", maxSplits: 1)
            if parts.count == 2 {
                let key = String(parts[0]).trimmingCharacters(in: .whitespacesAndNewlines)
                let val = String(parts[1]).trimmingCharacters(in: .whitespacesAndNewlines)
                env[key] = val
            }
        }
        
        return AgentConfig(
            name: name,
            modelID: modelID,
            executablePath: executablePath,
            parameters: parameters,
            envVariables: env
        )
    }
    
    private func updateGlobalAppearance() {
        switch appColorScheme {
        case 1: NSApp.appearance = NSAppearance(named: .aqua)
        case 2: NSApp.appearance = NSAppearance(named: .darkAqua)
        default: NSApp.appearance = nil
        }
    }
}
