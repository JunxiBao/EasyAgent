# EasyAgent

EasyAgent is a lightweight, high-performance macOS client designed to run and interact with local AI Agents. Running as a Menu Bar Extra (status item), it stays active in the background and can be instantly summoned using a configurable global shortcut (default: `Option + Space`) to show a floating, semi-transparent chat panel. It communicates with local agents via Standard Input/Output (stdin/stdout) using JSON-RPC.

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
        │   └── HistoryManager.swift    # Persistent local storage for conversation histories
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
    "clientInfo": { "name": "EasyAgent", "version": "1.0.0" }
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

## 📋 System Requirements

- **Platform**: macOS 15.0 (Sequoia) or higher.
- **Tools**: Xcode 16.0+ or Swift toolchain 6.0+.
- **Environment**: Python 3.x installed locally (only required for running `mock_agent.py` tests).

## 📄 License

This project is licensed under the MIT License. See the LICENSE file for details.
