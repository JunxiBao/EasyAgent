import Foundation
import AppKit

@MainActor
public class PermissionManager: ObservableObject {
    public static let shared = PermissionManager()

    @Published public var hasDesktopAccess: Bool = false
    @Published public var hasFullDiskAccess: Bool = false

    private init() {
        // Do NOT probe permissions here — contentsOfDirectory triggers the TCC
        // system dialog. Status will be updated only when the user explicitly
        // presses "Refresh Status" or "Request Access".
    }

    /// Silent status refresh. Does NOT trigger any system permission dialogs.
    public func checkAllPermissions() {
        // Full Disk Access: reading this plist is a safe, dialog-free probe.
        hasFullDiskAccess = FileManager.default.isReadableFile(
            atPath: "/Library/Preferences/com.apple.TimeMachine.plist"
        )

        // Desktop Access: only re-probe if we already have it confirmed,
        // otherwise leave the current state so we don't trigger a dialog.
        if hasDesktopAccess {
            hasDesktopAccess = checkDesktopSilent()
        }
    }

    /// Lightweight check using isReadableFile — returns false without a dialog
    /// when TCC blocks access, true when access was already granted.
    private func checkDesktopSilent() -> Bool {
        let desktopURL = FileManager.default.urls(
            for: .desktopDirectory, in: .userDomainMask
        ).first!
        // isReadableFile uses faccessat(2) which does not surface a TCC prompt.
        return FileManager.default.isReadableFile(atPath: desktopURL.path)
    }

    /// Actively requests Desktop access. This is the ONLY call that may show
    /// the macOS "Allow access to Desktop folder?" system dialog.
    /// Should only be triggered by an explicit user action (button tap).
    public func requestDesktopAccess() {
        let desktopURL = FileManager.default.urls(
            for: .desktopDirectory, in: .userDomainMask
        ).first!
        do {
            _ = try FileManager.default.contentsOfDirectory(
                at: desktopURL, includingPropertiesForKeys: nil
            )
            hasDesktopAccess = true
        } catch {
            hasDesktopAccess = false
        }
    }

    public func openSystemSettingsForFullDiskAccess() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") {
            NSWorkspace.shared.open(url)
        } else if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security") {
            NSWorkspace.shared.open(url)
        }
    }
}
