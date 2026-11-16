import Foundation

/// What the results screen shows after a level.
struct LevelResult: Equatable {
    let name: String
    /// Place in the lead's whole run, every chapter in order.
    let index: Int
    let chapterNumber: Int
    let chapterTitle: String
    /// The closing line when this level ends its chapter; nil otherwise.
    let ending: String?
    /// The run's first level of this chapter, for playing the chapter again.
    let chapterStart: Int
    /// The last level of the last chapter.
    let isFinal: Bool
    let seconds: Double
    let defeated: Int
    let downs: Int
    let found: Int
    let hidden: Int

    /// The last level of its chapter: its results screen closes the chapter.
    var isLast: Bool { ending != nil }

    var time: String {
        let total = Int(seconds.rounded())
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}
