import Foundation

public struct ChatSession: Identifiable, Codable, Hashable {
    public var id: UUID
    public var title: String
    public var messages: [Message]
    public var updatedAt: Date
    
    public init(id: UUID = UUID(), title: String = "New Chat", messages: [Message] = [], updatedAt: Date = Date()) {
        self.id = id
        self.title = title
        self.messages = messages
        self.updatedAt = updatedAt
    }
}
