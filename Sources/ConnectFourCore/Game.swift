import Foundation

public enum Disc: Int, Codable, Sendable {
    case red = 1, yellow
    public var opponent: Disc { self == .red ? .yellow : .red }
}

public struct Cell: Hashable, Sendable {
    public let row: Int
    public let column: Int
    public init(row: Int, column: Int) { self.row = row; self.column = column }
}

public struct Board: Equatable, Sendable {
    public static let rows = 6
    public static let columns = 7
    private var cells = Array<Disc?>(repeating: nil, count: 42)
    public init() {}
    public subscript(_ row: Int, _ column: Int) -> Disc? { cells[row * 7 + column] }
    public var validColumns: [Int] { (0..<7).filter { self[5, $0] == nil } }
    public var isFull: Bool { validColumns.isEmpty }
    public var moveCount: Int { cells.compactMap { $0 }.count }

    @discardableResult public mutating func drop(_ disc: Disc, in column: Int) -> Cell? {
        guard (0..<7).contains(column), let row = (0..<6).first(where: { self[$0, column] == nil }) else { return nil }
        cells[row * 7 + column] = disc
        return Cell(row: row, column: column)
    }

    public func winningCells(for disc: Disc) -> [Cell] {
        for row in 0..<6 {
            for column in 0..<7 where self[row, column] == disc {
                for (dr, dc) in [(0, 1), (1, 0), (1, 1), (1, -1)] {
                    let line = (0..<4).map { Cell(row: row + $0 * dr, column: column + $0 * dc) }
                    if line.allSatisfy({ (0..<6).contains($0.row) && (0..<7).contains($0.column) && self[$0.row, $0.column] == disc }) { return line }
                }
            }
        }
        return []
    }
}

public enum Outcome: Equatable, Sendable { case playing, won(Disc), draw }

public struct Game: Sendable {
    public private(set) var board = Board()
    public private(set) var turn: Disc = .red
    public private(set) var outcome: Outcome = .playing
    public private(set) var winningCells: [Cell] = []
    public init() {}
    @discardableResult public mutating func play(column: Int) -> Cell? {
        guard outcome == .playing, let cell = board.drop(turn, in: column) else { return nil }
        winningCells = board.winningCells(for: turn)
        if !winningCells.isEmpty { outcome = .won(turn) }
        else if board.isFull { outcome = .draw }
        else { turn = turn.opponent }
        return cell
    }
    public mutating func restart() { self = Game() }
}

public enum GameMode: String, CaseIterable, Sendable { case computer = "Vs Computer", local = "Two Players" }
public enum Difficulty: String, CaseIterable, Sendable { case easy = "Easy", medium = "Medium", hard = "Hard" }

public struct Scores: Codable, Equatable, Sendable {
    public var red = 0
    public var yellow = 0
    public var draws = 0
    public init() {}
    public mutating func record(_ outcome: Outcome) {
        switch outcome {
        case .won(.red): red += 1
        case .won(.yellow): yellow += 1
        case .draw: draws += 1
        case .playing: break
        }
    }
}

public final class Preferences {
    private let defaults: UserDefaults
    public init(defaults: UserDefaults = .standard) { self.defaults = defaults }
    public var mode: GameMode {
        get { GameMode(rawValue: defaults.string(forKey: "mode") ?? "") ?? .computer }
        set { defaults.set(newValue.rawValue, forKey: "mode") }
    }
    public var difficulty: Difficulty {
        get { Difficulty(rawValue: defaults.string(forKey: "difficulty") ?? "") ?? .medium }
        set { defaults.set(newValue.rawValue, forKey: "difficulty") }
    }
    public func scores(for mode: GameMode) -> Scores {
        guard let data = defaults.data(forKey: "scores.\(mode.rawValue)"), let scores = try? JSONDecoder().decode(Scores.self, from: data) else { return Scores() }
        return scores
    }
    public func save(_ scores: Scores, for mode: GameMode) {
        defaults.set(try? JSONEncoder().encode(scores), forKey: "scores.\(mode.rawValue)")
    }
}
