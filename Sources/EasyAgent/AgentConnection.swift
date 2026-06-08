import Foundation
import Combine

public struct AgentSlashCommand: Identifiable, Equatable {
    public let id = UUID()
    public let name: String
    public let description: String
    
    public init(name: String, description: String) {
        self.name = name
        self.description = description
    }
}

@MainActor
public class AgentConnection: ObservableObject {
    public enum Status: Equatable {
        case disconnected
        case connecting
        case connected
        case error(String)
        
        public var description: String {
            switch self {
            case .disconnected: return "Disconnected"
            case .connecting: return "Connecting..."
            case .connected: return "Connected"
            case .error(let err): return "Error: \(err)"
            }
        }
    }
    
    @Published public var status: Status = .disconnected
    @Published public var messages: [Message] = []
    @Published public var isResponding: Bool = false
    @Published public var activeSessionId: UUID = UUID()
    @Published public var availableCommands: [AgentSlashCommand] = []
    
    private var process: Process?
    private var stdinPipe: Pipe?
    private var stdoutPipe: Pipe?
    private var stderrPipe: Pipe?
    
    // Manual buffering for stdout to bypass Swift's FileHandle.bytes 8KB blocking buffer
    private var stdoutBuffer: Data = Data()
    private var stderrBuffer: Data = Data()
    
    private var currentRequestId = 1
    private var pendingRequests: [Int: @MainActor (Result<[String: Any], Error>) -> Void] = [:]
    
    private var sessionId: String?
    
    public init() {}
    
    // Persistent logging to file for debugging agent communication
    private lazy var logFileURL: URL = {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("EasyAgent", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("agent.log")
    }()
    
    // Cache the formatter (creating one is expensive and log() is called per-chunk)
    nonisolated(unsafe) private static let logDateFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        return f
    }()
    
    // Background queue for log file I/O so it never blocks the main thread
    private static let logQueue = DispatchQueue(label: "com.easyagent.log", qos: .utility)
    
    private func log(_ message: String) {
        let timestamp = Self.logDateFormatter.string(from: Date())
        let line = "[\(timestamp)] \(message)\n"
        let url = logFileURL
        Self.logQueue.async {
            guard let data = line.data(using: .utf8) else { return }
            if let fh = try? FileHandle(forWritingTo: url) {
                fh.seekToEndOfFile()
                fh.write(data)
                try? fh.close()
            } else {
                try? data.write(to: url)
            }
        }
    }
    
    public func connect(config: AgentConfig) {
        disconnect()
        
        self.status = .connecting
        
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: config.executablePath)
        proc.arguments = config.parsedArguments
        
        // Setup environment variables
        var env = ProcessInfo.processInfo.environment
        for (key, val) in config.envVariables {
            env[key] = val
        }
        
        // CRITICAL FIX: Force unbuffered stdout for Python and other agents.
        // When processes run through Pipes instead of a TTY, they default to block-buffering (4KB-8KB).
        // This causes partial streams to get stuck in memory until the process is killed or buffer fills.
        env["PYTHONUNBUFFERED"] = "1"
        env["NSUnbufferedIO"] = "YES" // For Foundation-based agents
        
        proc.environment = env
        
        let inPipe = Pipe()
        let outPipe = Pipe()
        let errPipe = Pipe()
        
        proc.standardInput = inPipe
        proc.standardOutput = outPipe
        proc.standardError = errPipe
        
        self.process = proc
        self.stdinPipe = inPipe
        self.stdoutPipe = outPipe
        self.stderrPipe = errPipe
        
        do {
            try proc.run()
        } catch {
            self.status = .error("Failed to run agent process: \(error.localizedDescription)")
            return
        }
        
        // Start stdout reading task (Bypassing Swift's bytes.lines buffering)
        let stdoutHandle = outPipe.fileHandleForReading
        stdoutHandle.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.stdoutBuffer.append(data)
                self.processStdoutBuffer()
            }
        }
        
        // Start stderr reading task
        let stderrHandle = errPipe.fileHandleForReading
        stderrHandle.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.stderrBuffer.append(data)
                self.processStderrBuffer()
            }
        }
        
        // Setup exit handler
        proc.terminationHandler = { [weak self] _ in
            DispatchQueue.main.async {
                self?.handleProcessExit()
            }
        }
        
        // Begin ACP handshake
        sendInitialize(modelID: config.modelID)
    }
    
    public func disconnect() {
        if let proc = process, proc.isRunning {
            proc.terminate()
        }
        
        stdoutPipe?.fileHandleForReading.readabilityHandler = nil
        stderrPipe?.fileHandleForReading.readabilityHandler = nil
        
        process = nil
        stdinPipe = nil
        stdoutPipe = nil
        stderrPipe = nil
        sessionId = nil
        pendingRequests.removeAll()
        availableCommands.removeAll()
        
        self.status = .disconnected
        self.isResponding = false
    }
    
    /// Cancel the current in-flight request without killing the agent process
    public func cancelCurrentRequest() {
        self.isResponding = false
        if let lastIdx = self.messages.indices.last, self.messages[lastIdx].sender == .agent {
            self.messages[lastIdx].isStreaming = false
            if self.messages[lastIdx].text.isEmpty {
                self.messages[lastIdx].text = "(Cancelled)"
            }
        }
        HistoryManager.shared.saveSession(id: self.activeSessionId, messages: self.messages)
    }
    
    private func handleProcessExit() {
        if status != .disconnected {
            // Fix #7: Clear isStreaming on any in-flight agent message
            if let lastIdx = self.messages.indices.last, self.messages[lastIdx].sender == .agent, self.messages[lastIdx].isStreaming {
                self.messages[lastIdx].isStreaming = false
                if self.messages[lastIdx].text.isEmpty {
                    self.messages[lastIdx].text = "(Agent process exited)"
                }
            }
            status = .error("Agent process exited unexpectedly.")
            disconnect()
        }
    }
    
    public func startNewSession() {
        activeSessionId = UUID()
        messages = []
        isResponding = false
    }
    
    public func loadSession(_ session: ChatSession) {
        activeSessionId = session.id
        messages = session.messages
        isResponding = false
    }
    
    private func sendLine(_ line: String) {
        guard let data = (line + "\n").data(using: .utf8),
              let stdin = stdinPipe?.fileHandleForWriting else { return }
        
        log("[OUT] \(line)")
        do {
            try stdin.write(contentsOf: data)
        } catch {
            log("[ERROR] Write failed: \(error)")
            // Fix #2: Surface the error to the user instead of silent failure
            self.status = .error("Lost connection to agent: \(error.localizedDescription)")
            self.isResponding = false
        }
    }
    
    private func sendRequest(method: String, params: [String: Any], completion: @escaping @MainActor (Result<[String: Any], Error>) -> Void) {
        let reqId = currentRequestId
        currentRequestId += 1
        pendingRequests[reqId] = completion
        
        let payload: [String: Any] = [
            "jsonrpc": "2.0",
            "id": reqId,
            "method": method,
            "params": params
        ]
        
        if let data = try? JSONSerialization.data(withJSONObject: payload, options: []),
           let line = String(data: data, encoding: .utf8) {
            sendLine(line)
        } else {
            completion(.failure(NSError(domain: "EasyAgent", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to serialize JSON-RPC request"])))
        }
    }
    
    private enum ProtocolVersion {
        case string(String)
        case integer(Int)
        
        var jsonValue: Any {
            switch self {
            case .string(let s): return s
            case .integer(let i): return i
            }
        }
    }
    
    private func sendInitialize(modelID: String, version: ProtocolVersion = .string("2024-11-05")) {
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.3.1"
        let params: [String: Any] = [
            "protocolVersion": version.jsonValue,
            "clientCapabilities": [String: Any](),
            "clientInfo": ["name": "EasyAgent", "version": appVersion]
        ]
        
        sendRequest(method: "initialize", params: params) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let res):
                print("Handshake successful: \(res)")
                self.sendSessionNew()
            case .failure(let error):
                if case .string(let s) = version, s == "2024-11-05" {
                    print("Handshake failed with version \(s), trying fallback version 1...")
                    self.sendInitialize(modelID: modelID, version: .integer(1))
                } else {
                    self.status = .error("Handshake failed: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func getSystemPrompt() -> String {
        let info = ProcessInfo.processInfo
        let osVersion = info.operatingSystemVersionString
        let userName = info.userName
        let homeDir = FileManager.default.homeDirectoryForCurrentUser.path
        let desktopDir = homeDir + "/Desktop"
        
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.timeStyle = .medium
        let dateString = formatter.string(from: Date())
        
        return """
        <system_instructions>
        You are a local AI agent running on the user's Mac via Easy Agent (an ACP-compatible agent runner).

        ## Current Environment
        - **OS**: macOS \(osVersion)
        - **Username**: \(userName)
        - **Home Directory**: \(homeDir)
        - **Working Directory**: \(desktopDir)
        - **Date / Time**: \(dateString)

        ## Capabilities
        You have direct access to the user's file system and can run shell commands, read/write files, and call local tools.
        For any sensitive or destructive operation (writing files outside the working directory, running scripts, deleting files, etc.),
        you MUST request user approval via the ACP `session/request_permission` mechanism before proceeding.

        ## Style
        - Be concise and direct. The user is a developer.
        - Prefer using the working directory (\(desktopDir)) as the default output location unless instructed otherwise.
        - When you encounter a permission error, suggest the user grant Full Disk Access in System Settings → Privacy & Security.
        </system_instructions>
        """
    }
    
    private func sendSessionNew() {
        let homeDir = FileManager.default.homeDirectoryForCurrentUser.path
        let desktopDir = homeDir + "/Desktop"
        
        let systemPrompt = getSystemPrompt()
        
        let params: [String: Any] = [
            "cwd": desktopDir,
            "mcpServers": [[String: Any]](),
            "system": systemPrompt
        ]
        
        sendRequest(method: "session/new", params: params) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let res):
                if let sessId = res["sessionId"] as? String {
                    self.sessionId = sessId
                    self.status = .connected
                    
                    // Automatically fetch MCP prompts to populate slash commands
                    self.fetchSlashCommands()
                } else {
                    self.status = .error("session/new did not return sessionId")
                }
            case .failure(let error):
                self.status = .error("session/new failed: \(error.localizedDescription)")
            }
        }
    }
    
    private func fetchSlashCommands() {
        sendRequest(method: "prompts/list", params: [:]) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let res):
                if let prompts = res["prompts"] as? [[String: Any]] {
                    var newCommands: [AgentSlashCommand] = []
                    for p in prompts {
                        if let name = p["name"] as? String {
                            let desc = p["description"] as? String ?? ""
                            let cmdName = name.hasPrefix("/") ? name : "/\(name)"
                            newCommands.append(AgentSlashCommand(name: cmdName, description: desc))
                        }
                    }
                    if !newCommands.isEmpty {
                        self.availableCommands.append(contentsOf: newCommands)
                    }
                }
            case .failure(let error):
                print("Failed to fetch prompts/list: \(error.localizedDescription)")
            }
        }
    }
    
    public func sendPrompt(_ text: String) {
        guard let sessionId = sessionId, status == .connected else { return }
        
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedText.isEmpty { return }
        
        self.messages.append(Message(sender: .user, text: trimmedText))
        self.messages.append(Message(sender: .agent, text: "", isStreaming: true))
        
        HistoryManager.shared.saveSession(id: activeSessionId, messages: messages)
        
        self.isResponding = true
        
        let isFirstPrompt = self.messages.filter { $0.sender == .user }.count == 1
        let isCommand = trimmedText.hasPrefix("/")
        let promptTextToSend = (isFirstPrompt && !isCommand) ? (getSystemPrompt() + "\n\nUser Request:\n" + trimmedText) : trimmedText
        
        let params: [String: Any] = [
            "sessionId": sessionId,
            "content": [
                ["type": "text", "text": promptTextToSend]
            ],
            "prompt": [
                ["type": "text", "text": promptTextToSend]
            ]
        ]
        
        sendRequest(method: "session/prompt", params: params) { [weak self] result in
            guard let self = self else { return }
            self.isResponding = false
            if let lastAgentIdx = self.messages.lastIndex(where: { $0.sender == .agent }) {
                self.messages[lastAgentIdx].isStreaming = false
            }
            
            switch result {
            case .success(let res):
                print("Prompt Turn complete: \(res)")
                HistoryManager.shared.saveSession(id: self.activeSessionId, messages: self.messages)
            case .failure(let error):
                self.messages.append(Message(sender: .system, text: "Error: \(error.localizedDescription)"))
                HistoryManager.shared.saveSession(id: self.activeSessionId, messages: self.messages)
            }
        }
    }
    
    private func processStdoutBuffer() {
        while let range = stdoutBuffer.firstRange(of: Data([0x0A])) { // \n
            let lineData = stdoutBuffer.subdata(in: 0..<range.lowerBound)
            stdoutBuffer.removeSubrange(0...range.upperBound - 1)
            
            if let line = String(data: lineData, encoding: .utf8) {
                handleIncomingLine(line)
            }
        }
    }
    
    private func processStderrBuffer() {
        while let range = stderrBuffer.firstRange(of: Data([0x0A])) {
            let lineData = stderrBuffer.subdata(in: 0..<range.lowerBound)
            stderrBuffer.removeSubrange(0...range.upperBound - 1)
            
            if let line = String(data: lineData, encoding: .utf8) {
                print("[Agent Stderr] \(line)")
            }
        }
    }
    
    private func handleIncomingLine(_ line: String) {
        log("[IN] \(line)")
        
        guard let data = line.data(using: .utf8),
              let json = (try? JSONSerialization.jsonObject(with: data, options: [])) as? [String: Any] else {
            return
        }
        
        // 1. Is it a request/notification from agent?
        if let method = json["method"] as? String {
            if method == "session/request_permission" {
                handleApprovalRequest(json)
                return
            } else if method == "session/update" {
                if let params = json["params"] as? [String: Any],
                   let update = params["update"] as? [String: Any] {
                    let kind = update["sessionUpdate"] as? String ?? update["kind"] as? String ?? ""
                    if kind == "agent_message_chunk" {
                        if let content = update["content"] as? [String: Any],
                           let text = content["text"] as? String {
                            // Find the last AGENT message (not just the last message,
                            // since approval cards insert .system messages after it)
                            if let lastAgentIdx = self.messages.lastIndex(where: { $0.sender == .agent }) {
                                self.messages[lastAgentIdx].text += text
                            }
                        }
                    } else if kind == "available_commands_update" {
                        if let cmds = update["availableCommands"] as? [[String: Any]] {
                            var newCommands: [AgentSlashCommand] = []
                            for cmd in cmds {
                                if let name = cmd["name"] as? String {
                                    let desc = cmd["description"] as? String ?? ""
                                    let cmdName = name.hasPrefix("/") ? name : "/\(name)"
                                    newCommands.append(AgentSlashCommand(name: cmdName, description: desc))
                                }
                            }
                            DispatchQueue.main.async {
                                self.availableCommands = newCommands
                            }
                        }
                    } else if kind == "turn_complete" || kind == "usage_update" || kind == "agent_message_done" || kind == "done" || kind == "error" || kind == "stop" || kind == "end" {
                        self.isResponding = false
                        if let lastAgentIdx = self.messages.lastIndex(where: { $0.sender == .agent }) {
                            self.messages[lastAgentIdx].isStreaming = false
                        }
                        HistoryManager.shared.saveSession(id: self.activeSessionId, messages: self.messages)
                    }
                }
            }
            
            // CRITICAL: If this is a JSON-RPC *request* (has an id) that we don't
            // explicitly handle, send back a default success response so the agent
            // doesn't hang waiting for a reply forever.
            if let reqId = json["id"] as? Int, method != "session/request_permission" {
                log("[AUTO-REPLY] Unhandled request: \(method) (id=\(reqId))")
                let response: [String: Any] = [
                    "jsonrpc": "2.0",
                    "id": reqId,
                    "result": [String: Any]()
                ]
                if let data = try? JSONSerialization.data(withJSONObject: response, options: []),
                   let line = String(data: data, encoding: .utf8) {
                    sendLine(line)
                }
            }
            return
        }
        
        // 1.5 Is it a notification from agent to register slash commands?
        if let method = json["method"] as? String, method == "agent/registerCommands" {
            if let params = json["params"] as? [String: Any],
               let cmds = params["commands"] as? [[String: Any]] {
                var newCommands: [AgentSlashCommand] = []
                for cmd in cmds {
                    if let name = cmd["name"] as? String,
                       let desc = cmd["description"] as? String {
                        newCommands.append(AgentSlashCommand(name: name, description: desc))
                    }
                }
                self.availableCommands = newCommands
            }
            return
        }
        
        // 2. Is it a response to a pending request?
        var responseId: Int?
        if let id = json["id"] as? Int {
            responseId = id
        } else if let idStr = json["id"] as? String {
            responseId = Int(idStr)
        }
        
        if let id = responseId {
            if let completion = pendingRequests.removeValue(forKey: id) {
                if let errorObj = json["error"] as? [String: Any],
                   let errMsg = errorObj["message"] as? String {
                    completion(.failure(NSError(domain: "EasyAgent", code: id, userInfo: [NSLocalizedDescriptionKey: errMsg])))
                } else if let resultObj = json["result"] as? [String: Any] {
                    completion(.success(resultObj))
                } else {
                    completion(.success([:]))
                }
            }
            return
        }
    }
    
    private func handleApprovalRequest(_ json: [String: Any]) {
        // Support both Int and String id types from JSON-RPC
        var requestId: Int?
        if let id = json["id"] as? Int {
            requestId = id
        } else if let idStr = json["id"] as? String {
            requestId = Int(idStr)
        }
        guard let id = requestId else { return }
        
        guard let params = json["params"] as? [String: Any],
              let toolCall = params["toolCall"] as? [String: Any],
              let title = toolCall["title"] as? String,
              let optionsArray = params["options"] as? [[String: Any]] else {
            // Fix #1: If the approval request format doesn't match, send back an
            // error response so the agent doesn't hang waiting forever.
            log("[ERROR] Approval request format mismatch for id=\(id), json=\(json)")
            let errorResponse: [String: Any] = [
                "jsonrpc": "2.0",
                "id": id,
                "error": ["code": -32600, "message": "Invalid approval request format"]
            ]
            if let data = try? JSONSerialization.data(withJSONObject: errorResponse, options: []),
               let line = String(data: data, encoding: .utf8) {
                sendLine(line)
            }
            return
        }
        
        var options: [ApprovalOption] = []
        for opt in optionsArray {
            if let kind = opt["kind"] as? String,
               let name = opt["name"] as? String,
               let optionId = opt["optionId"] as? String {
                options.append(ApprovalOption(kind: kind, name: name, optionId: optionId))
            }
        }
        
        let msg = Message(
            sender: .system,
            text: title,
            isStreaming: false,
            approvalRequestId: id,
            approvalOptions: options
        )
        self.messages.append(msg)
        HistoryManager.shared.saveSession(id: self.activeSessionId, messages: self.messages)
    }
    
    public func sendApprovalDecision(messageId: UUID, requestId: Int, optionId: String) {
        if let idx = self.messages.firstIndex(where: { $0.id == messageId }) {
            self.messages[idx].approvalChoice = optionId
            HistoryManager.shared.saveSession(id: self.activeSessionId, messages: self.messages)
        }
        
        let payload: [String: Any] = [
            "jsonrpc": "2.0",
            "id": requestId,
            "result": [
                "outcome": [
                    "outcome": "selected",
                    "optionId": optionId
                ]
            ]
        ]
        
        if let data = try? JSONSerialization.data(withJSONObject: payload, options: []),
           let line = String(data: data, encoding: .utf8) {
            sendLine(line)
        }
    }
    
    public func clearHistory() {
        // Delete current session from persistent history
        HistoryManager.shared.deleteSession(id: activeSessionId)
        // Clear in-memory messages and start a fresh session
        self.messages.removeAll()
        self.activeSessionId = UUID()
    }
}
