import Foundation
#if canImport(XCTest)
import XCTest
@testable import ConnectFourCore
#else
class XCTestCase {}
func XCTAssertEqual<T: Equatable>(_ a: T, _ b: T) { precondition(a == b, "Expected \(a) == \(b)") }
func XCTAssertNil<T>(_ value: T?) { precondition(value == nil) }
func XCTAssertNotNil<T>(_ value: T?) { precondition(value != nil) }
func XCTAssertTrue(_ value: Bool) { precondition(value) }
func XCTAssertFalse(_ value: Bool) { precondition(!value) }
#endif

final class GameTests: XCTestCase {
    func testHorizontalAndVerticalWins() {
        var horizontal = Game()
        [0,0,1,1,2,2,3].forEach { horizontal.play(column: $0) }
        XCTAssertEqual(horizontal.outcome, .won(.red))
        XCTAssertEqual(horizontal.winningCells.count, 4)
        XCTAssertNil(horizontal.play(column: 4))
        var vertical = Game()
        [0,1,0,1,0,1,0].forEach { vertical.play(column: $0) }
        XCTAssertEqual(vertical.outcome, .won(.red))
    }
    func testBothDiagonals() {
        for mirrored in [false, true] {
            var board = Board()
            for c in 0..<4 {
                let column = mirrored ? 6-c : c
                for _ in 0..<c { board.drop(.yellow, in: column) }
                board.drop(.red, in: column)
            }
            XCTAssertEqual(board.winningCells(for: .red).count, 4)
        }
    }
    func testGravityFullColumnsInvalidMovesAndTurns() {
        var game = Game()
        XCTAssertNil(game.play(column: -1)); XCTAssertNil(game.play(column: 7))
        XCTAssertEqual(game.turn, .red)
        for row in 0..<6 {
            XCTAssertEqual(game.play(column: 2), Cell(row: row, column: 2))
            XCTAssertEqual(game.turn, row % 2 == 0 ? .yellow : .red)
        }
        XCTAssertNil(game.play(column: 2))
        XCTAssertEqual(game.turn, .red)
        XCTAssertFalse(game.board.validColumns.contains(2))
    }
    func testDrawAndRestart() {
        var game = Game()
        let moves = [4,6,0,3,5,5,5,3,4,4,4,5,6,6,0,4,5,1,0,6,4,1,1,3,2,5,6,2,2,0,3,6,0,2,2,3,0,1,2,1,3,1]
        for column in moves { XCTAssertNotNil(game.play(column: column)) }
        XCTAssertEqual(game.outcome, .draw)
        XCTAssertNil(game.play(column: 0))
        game.restart()
        XCTAssertEqual(game.board.moveCount, 0)
        XCTAssertEqual(game.turn, .red)
        XCTAssertEqual(game.outcome, .playing)
        XCTAssertTrue(game.winningCells.isEmpty)
    }
    func testPersistenceAndScoreIsolation() {
        let suite = "ConnectFourTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = Preferences(defaults: defaults)
        var scores = Scores()
        scores.record(.won(.red)); scores.record(.won(.yellow)); scores.record(.draw); scores.record(.playing)
        store.save(scores, for: .computer); store.mode = .local; store.difficulty = .hard
        let reopened = Preferences(defaults: UserDefaults(suiteName: suite)!)
        XCTAssertEqual(reopened.scores(for: .computer), scores)
        XCTAssertEqual(reopened.scores(for: .local), Scores())
        XCTAssertEqual(reopened.mode, .local); XCTAssertEqual(reopened.difficulty, .hard)
        store.save(Scores(), for: .computer)
        XCTAssertEqual(reopened.scores(for: .computer), Scores())
    }
    func testAIWinsAndBlocks() {
        for difficulty in [Difficulty.medium, .hard] {
            for threat in [Disc.red, .yellow] {
                var board = Board()
                for column in 0..<3 { board.drop(threat, in: column) }
                XCTAssertEqual(AI.chooseMove(board: board, disc: .yellow, difficulty: difficulty), 3)
            }
            var board = Board()
            for _ in 0..<3 { board.drop(.red, in: 0); board.drop(.yellow, in: 6) }
            XCTAssertEqual(AI.chooseMove(board: board, disc: .yellow, difficulty: difficulty), 6)
        }
    }
    func testAILegalityAndTerminalBoard() {
        var board = Board()
        for i in 0..<6 { board.drop(i % 2 == 0 ? .red : .yellow, in: 3) }
        for difficulty in Difficulty.allCases {
            let move = AI.chooseMove(board: board, disc: .yellow, difficulty: difficulty)
            XCTAssertNotNil(move)
            XCTAssertTrue(board.validColumns.contains(move!))
        }
        for c in 0..<4 { board.drop(.red, in: c == 3 ? 4 : c) }
        var won = Board()
        for _ in 0..<4 { won.drop(.red, in: 0) }
        XCTAssertNil(AI.chooseMove(board: won, disc: .yellow, difficulty: .hard))
    }
}

#if !canImport(XCTest)
@main struct TestRunner {
    static func main() {
        let tests = GameTests()
        tests.testHorizontalAndVerticalWins()
        tests.testBothDiagonals()
        tests.testGravityFullColumnsInvalidMovesAndTurns()
        tests.testDrawAndRestart()
        tests.testPersistenceAndScoreIsolation()
        tests.testAIWinsAndBlocks()
        tests.testAILegalityAndTerminalBoard()
        print("PASS: all 7 test groups completed")
    }
}
#endif
