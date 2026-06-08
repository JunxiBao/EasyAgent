# EasyAgent

**Official Website:** [https://junxibao.com/EasyAgent/](https://junxibao.com/EasyAgent/)

EasyAgent is a lightweight, high-performance macOS client designed to run and interact with local AI Agents. Running as a Menu Bar Extra (status item), it stays active in the background and can be instantly summoned using a configurable global shortcut (default: `Option + Space`) to show a floating, semi-transparent chat panel. It communicates with local agents via Standard Input/Output (stdin/stdout) using JSON-RPC.

![EasyAgent Demo](./demo.gif)

---

## ✨ Key Features

- 📂 **Menu Bar Integration & Hotkey Summon**: Runs unobtrusively in the menu bar. Summon or hide the chat panel instantly using custom modifier/key combinations.
- ⚡ **Zero-Buffered Streaming Response**: Bypasses standard I/O buffer blocking (enforcing `PYTHONUNBUFFERED=1` and `NSUnbufferedIO=YES`) to ensure that Agent responses stream onto the screen character-by-character in real-time.
- 🤝 **ACP Protocol Support**: Built-in support for the Agent Communication Protocol (ACP), managing JSON-RPC 2.0 initialization, session handshakes, and turn control.
- 🛡️ **Interactive Permission Requests**: When an agent requests local tool execution or shell commands (via `session/request_permission`), EasyAgent displays an elegant, interactive approval card inside the chat stream so the user can review and allow/deny the action.
- 📜 **Persistent Session History**: Sidebar list supporting multiple independent chat sessions, local data persistence, and history management (clearing, loading, deleting).
- 🎨 **Rich Formatting & Syntax Highlighting**: Renders Markdown text beautifully using `swift-markdown-ui` and applies real-time syntax highlighting to code blocks using `Highlightr` (powered by highlight.js).
- 🌓 **Appearance Themes**: Fully supports macOS Light and Dark modes with explicit overrides (System / Light / Dark) in settings.

---

## 🛠️ Project Structure

```text
EasyAgent/
├── Package.swift           # Swift Package Manager configuration & dependencies
├── Info.plist              # macOS App Bundle metadata and permissions
├── build.sh                # One-click script for compiling, packaging, and icon conversion
├── mock_agent.py           # A Python-based mock ACP agent for development and testing
├── AppIcon.iconset/        # Raw application icon images
└── Sources/
    └── EasyAgent/
        ├── Main.swift                  # App entry point, lifecycle, and hotkey registration
        ├── HotkeyManager.swift         # Carbon APIs wrapper for registering global hotkeys
        ├── MainWindowController.swift  # Floating panel display, toggle, and sizing animations
        ├── AgentConnection.swift       # Core process controller for pipe I/O and JSON-RPC dispatching
        ├── Models/
        │   ├── AgentConfig.swift       # Agent details, env variables, arguments, and hotkey models
        │   ├── Message.swift           # Chat messages (supporting text, system events, and approval requests)
        │   ├── ChatSession.swift       # Session configuration
        │   ├── HistoryManager.swift    # Persistent local storage for conversation histories
        │   └── PermissionManager.swift # State manager for runtime tool/command execution permissions
        └── Views/
            ├── MainWindowView.swift    # Main chat panel view (message stream, input, sidebar toggle)
            ├── HistorySidebarView.swift# Sidebar UI for switching and deleting past sessions
            ├── SettingsWindowView.swift # Preferences panel (Agent configurations, hotkeys, appearance)
            └── HighlightrCodeSyntaxHighlighter.swift # Custom Markdown code syntax highlighter integration
```

---

## 🔌 Communication Protocol (ACP)

EasyAgent talks to local agent processes over Standard I/O using **JSON-RPC 2.0**. The communication flow works as follows:

### 1. Handshake (`initialize`)
Upon connecting to the agent process, the client sends an `initialize` request:
```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "initialize",
  "params": {
    "protocolVersion": "2024-11-05",
    "clientCapabilities": {},
    "clientInfo": { "name": "EasyAgent", "version": "1.3.2" }
  }
}
```
The Agent should reply with its supported protocol version and capabilities:
```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "result": {
    "protocolVersion": "2024-11-05",
    "capabilities": {}
  }
}
```

### 2. Session Setup (`session/new`)
The client initializes a workspace session:
```json
{
  "jsonrpc": "2.0",
  "id": 2,
  "method": "session/new",
  "params": {
    "cwd": "/Users/username/Desktop",
    "mcpServers": []
  }
}
```
The Agent responds with a unique session ID:
```json
{
  "jsonrpc": "2.0",
  "id": 2,
  "result": {
    "sessionId": "session-unique-uuid"
  }
}
```

### 3. Messaging (`session/prompt` & `session/update`)
When the user sends a message, it is wrapped in a `session/prompt` request:
```json
{
  "jsonrpc": "2.0",
  "id": 3,
  "method": "session/prompt",
  "params": {
    "sessionId": "session-unique-uuid",
    "content": [{ "type": "text", "text": "Hello, write a python hello world script." }]
  }
}
```
The Agent streams back chunks of the text using `session/update` notifications:
```json
{
  "jsonrpc": "2.0",
  "method": "session/update",
  "params": {
    "sessionId": "session-unique-uuid",
    "update": {
      "sessionUpdate": "agent_message_chunk",
      "content": { "type": "text", "text": "Sure! " }
    }
  }
}
```
Once completion is reached, the Agent resolves the `session/prompt` request:
```json
{
  "jsonrpc": "2.0",
  "id": 3,
  "result": {
    "stopReason": "end_turn"
  }
}
```

### 4. Authorizing Agent Actions (`session/request_permission`)
If the agent needs to invoke tools (e.g., execute shell commands or edit files), it can request permissions from the user by sending a JSON-RPC request to the client:
```json
{
  "jsonrpc": "2.0",
  "id": 10,
  "method": "session/request_permission",
  "params": {
    "toolCall": {
      "title": "Agent wants to run command: `rm -rf ./tmp`"
    },
    "options": [
      { "kind": "approve", "name": "Approve", "optionId": "allow" },
      { "kind": "reject", "name": "Reject & Block", "optionId": "deny" }
    ]
  }
}
```
The client renders an interactive prompt card. Once the user clicks an option, the decision is sent back to the Agent:
```json
{
  "jsonrpc": "2.0",
  "id": 10,
  "result": {
    "optionId": "allow"
  }
}
```

---

## 🤖 Verified Agents

The following agents have been tested and verified to work seamlessly with EasyAgent:

- **Hermes Agent**: Fully supports standard JSON-RPC communication and interactive permission requests.

---

## 🚀 Getting Started

### 1. Build and Package
The root directory includes a script `build.sh` that compiles the app in Release mode, builds the asset icon files, and packages everything into an App Bundle:
```bash
chmod +x build.sh
./build.sh
```
Once the build is complete, you will find `EasyAgent.app` generated directly on your **Desktop (`~/Desktop/EasyAgent.app`)**.

### 2. Configure with Mock Agent
For easy integration and testing, a python script `mock_agent.py` is included:
1. Double-click to launch `EasyAgent.app` from your Desktop.
2. Click the CPU icon in the macOS Menu Bar and select **Settings...**.
3. Under the **Agent** tab, configure the following:
   - **Agent Name**: `MockAgent`
   - **Model ID**: `mock-model`
   - **Executable Path**: The absolute path to your python3 interpreter (run `which python3` in terminal to find it, e.g., `/usr/bin/python3`).
   - **Command Parameters**: The absolute path to `mock_agent.py` in your clone directory (e.g., `/Users/yourusername/Desktop/EasyAgent/mock_agent.py`).
4. Click **Test Connection**. It should display `Connected successfully!` in green text.
5. Click **Save Settings**.

### 3. Summon and Chat
1. Press `⌥ + Space` (Option + Space) or select **Show Chat Panel** from the menu bar status item.
2. Send a prompt to watch the simulated streaming response character by character.
3. Head to the **Hotkeys** tab in Settings to change the summon shortcuts anytime.

---

## 🛠️ Secondary Development Guide

If you wish to modify or extend EasyAgent, here is a step-by-step guide to get started:

### 1. Development Environment Setup
- **IDE**: We recommend using **Xcode 16+** or **Cursor / VS Code** with the Swift extension.
- **Project Type**: This is a standard **Swift Package Manager (SPM)** project.
  - To open in Xcode: Run `xed .` in the terminal or double-click `Package.swift`. Xcode will automatically resolve dependencies (`swift-markdown-ui` and `Highlightr`).
  - To open in VS Code: Just open the folder. The Swift extension will parse the `Package.swift` package definition.

### 2. Running in Development Mode
During development, you can run the executable directly from your terminal or IDE:
```bash
# Compile and run EasyAgent in debug mode
swift run
```
If you run it from Xcode, select the `EasyAgent` executable scheme and hit **Cmd + R** to compile and run with the interactive debugger attached.

### 3. Key Areas of Interest

#### Adding Custom JSON-RPC Methods or Extending ACP Protocol
EasyAgent handles process management and JSON-RPC dispatching inside:
- [AgentConnection.swift](Sources/EasyAgent/AgentConnection.swift)
  - Customize standard I/O pipes, process environment overrides (`PYTHONUNBUFFERED`, `NSUnbufferedIO`), and protocol handshakes.
  - Look at `handleIncomingLine(_:)` and `sendRequest(...)` to add or handle new JSON-RPC methods/updates.

#### Modifying the UI / Theme
UI components are built using SwiftUI:
- [MainWindowView.swift](Sources/EasyAgent/Views/MainWindowView.swift): Renders the main chat feed, input bar, custom status indicators, and permission approval cards.
- [SettingsWindowView.swift](Sources/EasyAgent/Views/SettingsWindowView.swift): Controls the preferences tabs (Agent configs, Hotkeys, Appearance, Permissions).

#### Customizing Global Hotkeys
System summoning via shortcut is implemented in:
- [HotkeyManager.swift](Sources/EasyAgent/HotkeyManager.swift): Handles registering global hotkeys via Carbon APIs, translating modifiers (`Command`, `Option`, `Control`, `Shift`) and key codes.

#### Changing Local Storage / Conversation History
State saving and history persistence are managed in:
- [HistoryManager.swift](Sources/EasyAgent/Models/HistoryManager.swift): Serializes chat threads to local JSON files under the `~/Library/Application Support/EasyAgent/History/` folder.

### 4. Testing Protocols with the Mock Agent
You can edit [mock_agent.py](mock_agent.py) to simulate different backend behaviors:
- Add fake tool execution logs or custom interactive approval cards to test UI layouts.
- Emulate API latency, networking errors, or multi-line responses.

### 5. Custom Packaging & Signing
Once you've made your changes, package your application:
```bash
./build.sh
```
The script will build, convert icons, perform **ad-hoc code signing** (necessary for macOS LaunchServices to recognize resources/icons correctly), and touch the final `.app` bundle to refresh Finder caches.

---

## 📋 System Requirements

- **Platform**: macOS 15.0 (Sequoia) or higher.
- **Tools**: Xcode 16.0+ or Swift toolchain 6.0+.
- **Environment**: Python 3.x installed locally (only required for running `mock_agent.py` tests).

## 📄 License

This project is licensed under the MIT License. See the LICENSE file for details.
