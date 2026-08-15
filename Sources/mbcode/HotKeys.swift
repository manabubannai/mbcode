import AppKit
import Carbon.HIToolbox

// グローバルホットキーの共通レジストリ。
// Carbonのイベントハンドラは1本だけ張り、hotkey ID でアクションに振り分ける。
enum HotKeys {
    private static var installed = false
    private static var actions: [UInt32: () -> Void] = [:]
    private static var refs: [UInt32: EventHotKeyRef?] = [:]

    static func register(id: UInt32, spec: String, action: @escaping () -> Void) {
        if !installed {
            var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                          eventKind: UInt32(kEventHotKeyPressed))
            InstallEventHandler(GetApplicationEventTarget(), { _, event, _ -> OSStatus in
                var hkID = EventHotKeyID()
                GetEventParameter(event, EventParamName(kEventParamDirectObject),
                                  EventParamType(typeEventHotKeyID), nil,
                                  MemoryLayout<EventHotKeyID>.size, nil, &hkID)
                let id = hkID.id
                DispatchQueue.main.async { HotKeys.actions[id]?() }
                return noErr
            }, 1, &eventType, nil, nil)
            installed = true
        }
        actions[id] = action
        let (keyCode, modifiers) = parse(spec)
        var ref: EventHotKeyRef?
        RegisterEventHotKey(keyCode, modifiers,
                            EventHotKeyID(signature: OSType(0x6D62_6364), id: id),
                            GetApplicationEventTarget(), 0, &ref)
        refs[id] = ref
    }

    // "option-space" のような文字列を (keyCode, modifiers) に変換
    static func parse(_ spec: String) -> (UInt32, UInt32) {
        let keyCodes: [String: Int] = [
            "space": kVK_Space, "grave": kVK_ANSI_Grave, "escape": kVK_Escape,
            "f12": kVK_F12, "f11": kVK_F11,
            "a": kVK_ANSI_A, "b": kVK_ANSI_B, "c": kVK_ANSI_C, "d": kVK_ANSI_D,
            "e": kVK_ANSI_E, "f": kVK_ANSI_F, "g": kVK_ANSI_G, "h": kVK_ANSI_H,
            "i": kVK_ANSI_I, "j": kVK_ANSI_J, "k": kVK_ANSI_K, "l": kVK_ANSI_L,
            "m": kVK_ANSI_M, "n": kVK_ANSI_N, "o": kVK_ANSI_O, "p": kVK_ANSI_P,
            "q": kVK_ANSI_Q, "r": kVK_ANSI_R, "s": kVK_ANSI_S, "t": kVK_ANSI_T,
            "u": kVK_ANSI_U, "v": kVK_ANSI_V, "w": kVK_ANSI_W, "x": kVK_ANSI_X,
            "y": kVK_ANSI_Y, "z": kVK_ANSI_Z,
        ]
        var mods: UInt32 = 0
        var key: UInt32 = UInt32(kVK_Space)
        for part in spec.lowercased().split(separator: "-").map(String.init) {
            switch part {
            case "command", "cmd": mods |= UInt32(cmdKey)
            case "option", "opt", "alt": mods |= UInt32(optionKey)
            case "control", "ctrl": mods |= UInt32(controlKey)
            case "shift": mods |= UInt32(shiftKey)
            default:
                if let code = keyCodes[part] { key = UInt32(code) }
            }
        }
        // Fキー以外の修飾キー無しは通常入力を乗っ取ってしまうので保険をかける
        if mods == 0 && key != UInt32(kVK_F12) && key != UInt32(kVK_F11) {
            mods = UInt32(optionKey)
        }
        return (key, mods)
    }
}
