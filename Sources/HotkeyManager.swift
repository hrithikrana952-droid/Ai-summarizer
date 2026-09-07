import Cocoa
import Carbon

class HotkeyManager {
    var onToggleRecording: (() -> Void)?
    
    private var hotKeyRef: EventHotKeyRef?
    
    init() {
        registerHotkey()
    }
    
    private func registerHotkey() {
        var hotKeyID = EventHotKeyID()
        hotKeyID.signature = OSType(fourCharCode: "recr")
        hotKeyID.id = 1
        
        // Option (⌥) + Shift (⇧) + F (KeyCode 3)
        let modifiers = UInt32(optionKey | shiftKey)
        let keyCode = UInt32(kVK_ANSI_F)
        
        var eventType = EventTypeSpec()
        eventType.eventClass = OSType(kEventClassKeyboard)
        eventType.eventKind = OSType(kEventHotKeyPressed)
        
        let ptr = Unmanaged.passUnretained(self).toOpaque()
        
        InstallEventHandler(GetApplicationEventTarget(), { (nextHandler, theEvent, userData) -> OSStatus in
            let mySelf = Unmanaged<HotkeyManager>.fromOpaque(userData!).takeUnretainedValue()
            
            var hotKeyID = EventHotKeyID()
            GetEventParameter(theEvent,
                              EventParamName(kEventParamDirectObject),
                              EventParamType(typeEventHotKeyID),
                              nil,
                              MemoryLayout<EventHotKeyID>.size,
                              nil,
                              &hotKeyID)
            
            if hotKeyID.id == 1 {
                DispatchQueue.main.async {
                    mySelf.onToggleRecording?()
                }
            }
            
            return noErr
        }, 1, &eventType, ptr, nil)
        
        RegisterEventHotKey(keyCode,
                            modifiers,
                            hotKeyID,
                            GetApplicationEventTarget(),
                            0,
                            &hotKeyRef)
    }
}

extension String {
    func fourCharCode() -> OSType {
        var result: OSType = 0
        for char in self.utf8 {
            result = (result << 8) + OSType(char)
        }
        return result
    }
}

extension OSType {
    init(fourCharCode string: String) {
        self = string.fourCharCode()
    }
}
