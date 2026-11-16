import Foundation

/// What the player can change in Settings. Kept in UserDefaults.
struct Settings: Equatable {
    var volume = 0.7
    var haptics = true
    var screenShake = true
    var debugOverlay = false

    private static let defaults = UserDefaults.standard

    static func load() -> Settings {
        var s = Settings()
        if defaults.object(forKey: "settings.volume") != nil { s.volume = defaults.double(forKey: "settings.volume") }
        if defaults.object(forKey: "settings.haptics") != nil { s.haptics = defaults.bool(forKey: "settings.haptics") }
        if defaults.object(forKey: "settings.shake") != nil { s.screenShake = defaults.bool(forKey: "settings.shake") }
        s.debugOverlay = defaults.bool(forKey: "settings.debug")
        return s
    }

    func save() {
        Self.defaults.set(volume, forKey: "settings.volume")
        Self.defaults.set(haptics, forKey: "settings.haptics")
        Self.defaults.set(screenShake, forKey: "settings.shake")
        Self.defaults.set(debugOverlay, forKey: "settings.debug")
    }
}
