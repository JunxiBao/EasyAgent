import Foundation

public struct ApprovalOption: Codable, Hashable {
    public var kind: String
    public var name: String
    public var optionId: String
    
    public init(kind: String, name: String, optionId: String) {
        self.kind = kind
        self.name = name
        self.optionId = optionId
    }
}

public struct Message: Identifiable, Codable, Hashable {
    public enum Sender: String, Codable {
        case user
        case agent
        case system
    }
    
    public var id: UUID
    public var sender: Sender
    public var text: String
    public var timestamp: Date
    public var isStreaming: Bool
    
    // Approval properties
    public var approvalRequestId: Int?
    public var approvalOptions: [ApprovalOption]?
    public var approvalChoice: String?
    
    public init(id: UUID = UUID(), sender: Sender, text: String, timestamp: Date = Date(), isStreaming: Bool = false, approvalRequestId: Int? = nil, approvalOptions: [ApprovalOption]? = nil, approvalChoice: String? = nil) {
        self.id = id
        self.sender = sender
        self.text = text
        self.timestamp = timestamp
        self.isStreaming = isStreaming
        self.approvalRequestId = approvalRequestId
        self.approvalOptions = approvalOptions
        self.approvalChoice = approvalChoice
    }
}
