import Foundation

public enum AI {
    private static let order = [3, 2, 4, 1, 5, 0, 6]
    public static func chooseMove(board: Board, disc: Disc, difficulty: Difficulty) -> Int? {
        guard board.winningCells(for: .red).isEmpty, board.winningCells(for: .yellow).isEmpty else { return nil }
        let valid = order.filter { board.validColumns.contains($0) }
        guard !valid.isEmpty else { return nil }
        if difficulty == .easy { return valid.randomElement() }
        for column in valid {
            var next = board; next.drop(disc, in: column)
            if !next.winningCells(for: disc).isEmpty { return column }
        }
        for column in valid {
            var next = board; next.drop(disc.opponent, in: column)
            if !next.winningCells(for: disc.opponent).isEmpty { return column }
        }
        var best = valid[0], bestScore = Int.min
        for column in valid {
            if Task.isCancelled { return nil }
            var next = board; next.drop(disc, in: column)
            let score = search(next, turn: disc.opponent, root: disc,
                               depth: difficulty == .hard ? 6 : 1, alpha: -1_000_000, beta: 1_000_000)
            if score > bestScore { bestScore = score; best = column }
        }
        return best
    }

    private static func search(_ board: Board, turn: Disc, root: Disc, depth: Int, alpha: Int, beta: Int) -> Int {
        if !board.winningCells(for: root).isEmpty { return 100_000 + depth }
        if !board.winningCells(for: root.opponent).isEmpty { return -100_000 - depth }
        if board.isFull { return 0 }
        if depth == 0 || Task.isCancelled { return evaluate(board, root) }
        var a = alpha, b = beta
        var best = turn == root ? -1_000_000 : 1_000_000
        for column in order where board.validColumns.contains(column) {
            var next = board; next.drop(turn, in: column)
            let value = search(next, turn: turn.opponent, root: root, depth: depth - 1, alpha: a, beta: b)
            if turn == root { best = max(best, value); a = max(a, best) }
            else { best = min(best, value); b = min(b, best) }
            if a >= b { break }
        }
        return best
    }

    private static func evaluate(_ board: Board, _ root: Disc) -> Int {
        var score = (0..<6).reduce(0) { $0 + (board[$1, 3] == root ? 6 : board[$1, 3] == root.opponent ? -6 : 0) }
        for row in 0..<6 {
            for column in 0..<7 {
                for (dr, dc) in [(0, 1), (1, 0), (1, 1), (1, -1)] {
                    guard (0..<6).contains(row + 3 * dr), (0..<7).contains(column + 3 * dc) else { continue }
                    let cells = (0..<4).map { board[row + $0 * dr, column + $0 * dc] }
                    let own = cells.filter { $0 == root }.count
                    let other = cells.filter { $0 == root.opponent }.count
                    if other == 0 { score += [0, 1, 12, 90, 10000][own] }
                    if own == 0 { score -= [0, 1, 15, 110, 10000][other] }
                }
            }
        }
        return score
    }
}
