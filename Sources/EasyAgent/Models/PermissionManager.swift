import Foundation
import AppKit

@MainActor
public class PermissionManager: ObservableObject {
    public static let shared = PermissionManager()

    @Published public var hasFullDiskAccess: Bool = false

    private init() {
        // Don't probe on init to avoid triggering system dialogs.
        // Status is updated only via checkAllPermissions() (manual refresh).
    }

    /// Silent status refresh — does NOT trigger any system permission dialogs.
    public func checkAllPermissions() {
        // Reading this TCC-protected plist is the standard silent probe for FDA.
        hasFullDiskAccess = FileManager.default.isReadableFile(
            atPath: "/Library/Preferences/com.apple.TimeMachine.plist"
        )
    }

    public func openSystemSettingsForFullDiskAccess() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") {
            NSWorkspace.shared.open(url)
        } else if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security") {
            NSWorkspace.shared.open(url)
        }
    }
}
