import Foundation

@MainActor
public class HistoryManager: ObservableObject {
    public static let shared = HistoryManager()
    
    @Published public var sessions: [ChatSession] = []
    
    private let fileManager = FileManager.default
    private var persistWorkItem: DispatchWorkItem?
    private static let persistQueue = DispatchQueue(label: "com.easyagent.history", qos: .utility)
    private var historyDirectory: URL {
        let urls = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        return urls[0].appendingPathComponent("EasyAgent/History", isDirectory: true)
    }
    
    private var historyFileURL: URL {
        return historyDirectory.appendingPathComponent("sessions.json")
    }
    
    private init() {
        loadSessions()
    }
    
    public func loadSessions() {
        do {
            if !fileManager.fileExists(atPath: historyDirectory.path) {
                try fileManager.createDirectory(at: historyDirectory, withIntermediateDirectories: true, attributes: nil)
            }
            
            guard fileManager.fileExists(atPath: historyFileURL.path) else { return }
            let data = try Data(contentsOf: historyFileURL)
            let decoder = JSONDecoder()
            var loaded = try decoder.decode([ChatSession].self, from: data)
            loaded.sort { $0.updatedAt > $1.updatedAt }
            self.sessions = loaded
        } catch {
            print("Failed to load history: \(error)")
        }
    }
    
    public func saveSession(id: UUID, messages: [Message]) {
        guard !messages.isEmpty else { return }
        
        // Find existing session or create new
        var title = "New Chat"
        if let firstUserMsg = messages.first(where: { $0.sender == .user }) {
            title = String(firstUserMsg.text.prefix(30))
            if firstUserMsg.text.count > 30 { title += "..." }
        }
        
        if let index = sessions.firstIndex(where: { $0.id == id }) {
            sessions[index].messages = messages
            sessions[index].title = title
            sessions[index].updatedAt = Date()
        } else {
            let newSession = ChatSession(id: id, title: title, messages: messages, updatedAt: Date())
            sessions.insert(newSession, at: 0)
        }
        
        sessions.sort { $0.updatedAt > $1.updatedAt }
        debouncedPersist()
    }
    
    public func deleteSession(id: UUID) {
        sessions.removeAll { $0.id == id }
        persist()
    }
    
    /// Debounce disk writes so rapid calls (e.g. streaming chunks) don't each trigger JSON encode + file write.
    private func debouncedPersist() {
        persistWorkItem?.cancel()
        let item = DispatchWorkItem { [weak self] in
            Task { @MainActor in
                self?.persist()
            }
        }
        persistWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: item)
    }
    
    private func persist() {
        let dir = historyDirectory
        let fileURL = historyFileURL
        let sessionsSnapshot = sessions
        Self.persistQueue.async {
            do {
                if !FileManager.default.fileExists(atPath: dir.path) {
                    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true, attributes: nil)
                }
                let encoder = JSONEncoder()
                encoder.outputFormatting = .prettyPrinted
                let data = try encoder.encode(sessionsSnapshot)
                try data.write(to: fileURL, options: .atomic)
            } catch {
                print("Failed to save history: \(error)")
            }
        }
    }
}
