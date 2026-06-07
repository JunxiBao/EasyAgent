import Carbon
import Cocoa

@MainActor
public class HotkeyManager {
    public static let shared = HotkeyManager()
    
    nonisolated(unsafe) private var hotKeyRef: EventHotKeyRef?
    private var onTriggerHandler: (() -> Void)?
    nonisolated(unsafe) private var eventHandlerRef: EventHandlerRef?
    
    private init() {
        setupEventHandler()
    }
    
    private func setupEventHandler() {
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        
        // Use a C-convention closure for HIToolbox event handling.
        // It does not capture any variables, so it can be bridged to a C function pointer.
        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            { (nextHandler, theEvent, userData) -> OSStatus in
                if let userData = userData {
                    DispatchQueue.main.async {
                        let manager = Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue()
                        manager.onTriggerHandler?()
                    }
                }
                return noErr
            },
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &eventHandlerRef
        )
        
        if status != noErr {
            print("Failed to install application event handler for hotkeys: \(status)")
        }
    }
    
    public func register(keyCode: UInt32, carbonModifiers: UInt32, onTrigger: @escaping () -> Void) {
        unregister()
        
        self.onTriggerHandler = onTrigger
        
        // We use a signature of "EAgt" (Easy Agent)
        let signature = OSType(1162101076) // 'EAgt' in UInt32
        let hotKeyID = EventHotKeyID(signature: signature, id: 1)
        
        let status = RegisterEventHotKey(
            keyCode,
            carbonModifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
        
        if status != noErr {
            print("Failed to register event hotkey: \(status)")
        } else {
            print("Successfully registered hotkey: code \(keyCode), modifiers \(carbonModifiers)")
        }
    }
    
    public func unregister() {
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
            hotKeyRef = nil
        }
        onTriggerHandler = nil
    }
    
    deinit {
        // Accessing refs directly from deinit
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
        }
        if let handlerRef = eventHandlerRef {
            RemoveEventHandler(handlerRef)
        }
    }
}
