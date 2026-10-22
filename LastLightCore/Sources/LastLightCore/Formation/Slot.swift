public enum Column: Int, Sendable, CaseIterable {
    case front = 0, back = 1
}

/// One cell of a side's 2-column × 3-row formation.
public struct Slot: Hashable, Sendable, Comparable {
    public static let rows = 3

    public let column: Column
    public let row: Int

    public init?(column: Column, row: Int) {
        guard (0..<Slot.rows).contains(row) else { return nil }
        self.column = column
        self.row = row
    }

    /// Orthogonal neighbours only: same column one row apart, or same row in the other column.
    public func isAdjacent(to other: Slot) -> Bool {
        if column == other.column { return abs(row - other.row) == 1 }
        return row == other.row
    }

    /// Every slot, ordered column then row.
    public static let all: [Slot] = Column.allCases.flatMap { column in
        (0..<rows).map { Slot(column: column, row: $0)! }
    }

    public static func < (lhs: Slot, rhs: Slot) -> Bool {
        (lhs.column.rawValue, lhs.row) < (rhs.column.rawValue, rhs.row)
    }
}
