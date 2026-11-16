import Foundation

/// What the results screen shows after a level.
struct LevelResult: Equatable {
    let name: String
    let index: Int
    /// The last level of the chapter: its results screen closes the chapter.
    let isLast: Bool
    let seconds: Double
    let defeated: Int
    let downs: Int
    let found: Int
    let hidden: Int

    var time: String {
        let total = Int(seconds.rounded())
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}
