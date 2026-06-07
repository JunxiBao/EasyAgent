import Foundation
import AppKit

@MainActor
public class PermissionManager: ObservableObject {
    public static let shared = PermissionManager()
    
    @Published public var hasDesktopAccess: Bool = false
    @Published public var hasFullDiskAccess: Bool = false
    
    private init() {
        checkAllPermissions()
    }
    
    public func checkAllPermissions() {
        self.hasDesktopAccess = checkDesktopAccess()
        self.hasFullDiskAccess = checkFullDiskAccess()
    }
    
    private func checkDesktopAccess() -> Bool {
        let desktopURL = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first!
        do {
            _ = try FileManager.default.contentsOfDirectory(at: desktopURL, includingPropertiesForKeys: nil)
            return true
        } catch {
            return false
        }
    }
    
    private func checkFullDiskAccess() -> Bool {
        let path = "/Library/Preferences/com.apple.TimeMachine.plist"
        return FileManager.default.isReadableFile(atPath: path)
    }
    
    public func requestDesktopAccess() {
        let desktopURL = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first!
        do {
            _ = try FileManager.default.contentsOfDirectory(at: desktopURL, includingPropertiesForKeys: nil)
        } catch {
            // Ignore error, it will reflect in status check
        }
        checkAllPermissions()
    }
    
    public func openSystemSettingsForFullDiskAccess() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") {
            NSWorkspace.shared.open(url)
        } else if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security") {
            NSWorkspace.shared.open(url)
        }
    }
}
