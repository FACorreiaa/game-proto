import Foundation

/// What the player can change in Settings. Kept in UserDefaults.
struct Settings: Equatable {
    enum Difficulty: String, CaseIterable {
        case story, normal, hard

        var name: String {
            switch self {
            case .story: "Story"
            case .normal: "Normal"
            case .hard: "Hard"
            }
        }

        /// How much of an enemy's damage reaches a hero.
        var damageTaken: Double {
            switch self {
            case .story: 0.5
            case .normal: 1
            case .hard: 1.5
            }
        }
    }

    var volume = 0.7
    var haptics = true
    var screenShake = true
    var debugOverlay = false
    var difficulty = Difficulty.normal
    /// Test aid until the faction pick exists: which hero leads the levels.
    var lead = Lead.caelen

    enum Lead: String, CaseIterable {
        case caelen, seraphine, nimue

        var name: String { rawValue.capitalized }
    }

    private static let defaults = UserDefaults.standard

    static func load() -> Settings {
        var s = Settings()
        if defaults.object(forKey: "settings.volume") != nil { s.volume = defaults.double(forKey: "settings.volume") }
        if defaults.object(forKey: "settings.haptics") != nil { s.haptics = defaults.bool(forKey: "settings.haptics") }
        if defaults.object(forKey: "settings.shake") != nil { s.screenShake = defaults.bool(forKey: "settings.shake") }
        s.debugOverlay = defaults.bool(forKey: "settings.debug")
        s.difficulty = defaults.string(forKey: "settings.difficulty").flatMap(Difficulty.init(rawValue:)) ?? .normal
        s.lead = defaults.string(forKey: "settings.lead").flatMap(Lead.init(rawValue:)) ?? .caelen
        return s
    }

    func save() {
        Self.defaults.set(volume, forKey: "settings.volume")
        Self.defaults.set(haptics, forKey: "settings.haptics")
        Self.defaults.set(screenShake, forKey: "settings.shake")
        Self.defaults.set(debugOverlay, forKey: "settings.debug")
        Self.defaults.set(difficulty.rawValue, forKey: "settings.difficulty")
        Self.defaults.set(lead.rawValue, forKey: "settings.lead")
    }
}
