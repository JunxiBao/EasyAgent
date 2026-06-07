import Foundation

/// Shared Carbon key code mapping used by both Settings and Main hotkey registration
public let carbonKeyCodes: [String: UInt32] = [
    "Space": 49, "Enter": 36, "Tab": 48,
    "A": 0, "B": 11, "C": 8, "D": 2, "E": 14, "F": 3, "G": 5, "H": 4,
    "I": 34, "J": 38, "K": 40, "L": 37, "M": 46, "N": 45, "O": 31, "P": 35,
    "Q": 12, "R": 15, "S": 1, "T": 17, "U": 32, "V": 9, "W": 13, "X": 7,
    "Y": 16, "Z": 6,
    "0": 29, "1": 18, "2": 19, "3": 20, "4": 21, "5": 23, "6": 22, "7": 26,
    "8": 28, "9": 25
]

public struct AgentConfig {
    let name: String
    let modelID: String
    let executablePath: String
    let parameters: String
    let envVariables: [String: String]
    
    var parsedArguments: [String] {
        parameters.components(separatedBy: " ").filter { !$0.isEmpty }
    }
    
    /// Build an AgentConfig from the current UserDefaults
    static func fromDefaults() -> AgentConfig {
        let defaults = UserDefaults.standard
        let name = defaults.string(forKey: "AgentName") ?? "Hermes Local"
        let modelID = defaults.string(forKey: "AgentModelID") ?? "hermes-3"
        let executablePath = defaults.string(forKey: "AgentExecutablePath") ?? ""
        let parameters = defaults.string(forKey: "AgentParameters") ?? "acp"
        let envText = defaults.string(forKey: "AgentEnvText") ?? ""
        
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
}
