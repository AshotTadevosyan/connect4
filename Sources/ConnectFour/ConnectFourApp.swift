import SwiftUI
import ConnectFourCore

@MainActor final class GameModel: ObservableObject {
    @Published var game = Game()
    @Published var scores: Scores
    @Published var mode: GameMode { didSet { preferences.mode = mode; scores = preferences.scores(for: mode); restart() } }
    @Published var difficulty: Difficulty { didSet { preferences.difficulty = difficulty; restart() } }
    @Published var thinking = false
    @Published var dropping: Cell?
    private let preferences = Preferences()
    private var worker: Task<Int?, Never>?
    private var sequence: Task<Void, Never>?
    private var generation = UUID()

    init() {
        mode = preferences.mode
        difficulty = preferences.difficulty
        scores = preferences.scores(for: preferences.mode)
    }
    var acceptsInput: Bool { game.outcome == .playing && !thinking && dropping == nil && (mode == .local || game.turn == .red) }
    var status: String {
        switch game.outcome {
        case .won(let disc): return "\(name(disc)) wins!"
        case .draw: return "A perfect standoff."
        case .playing: return thinking ? "Computer is thinking…" : "\(name(game.turn))’s turn"
        }
    }
    func name(_ disc: Disc) -> String { disc == .red ? (mode == .computer ? "You" : "Red") : (mode == .computer ? "Computer" : "Yellow") }
    func restart() {
        generation = UUID(); worker?.cancel(); sequence?.cancel()
        thinking = false; dropping = nil; game.restart()
    }
    func resetScores() { scores = Scores(); preferences.save(scores, for: mode) }
    func play(_ column: Int) {
        guard acceptsInput else { return }
        place(column)
    }
    private func place(_ column: Int) {
        guard let cell = game.play(column: column) else { return }
        dropping = cell
        if game.outcome != .playing { scores.record(game.outcome); preferences.save(scores, for: mode) }
        let token = generation
        sequence = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 380_000_000)
            guard let self, !Task.isCancelled, token == self.generation else { return }
            self.dropping = nil
            if self.game.outcome == .playing && self.mode == .computer && self.game.turn == .yellow { self.startComputer() }
        }
    }
    private func startComputer() {
        thinking = true
        let board = game.board, level = difficulty, token = generation
        let task = Task.detached(priority: .userInitiated) { AI.chooseMove(board: board, disc: .yellow, difficulty: level) }
        worker = task
        sequence = Task { [weak self] in
            let column = await task.value
            guard let self, !Task.isCancelled, token == self.generation, self.game.outcome == .playing, self.game.turn == .yellow else { return }
            self.thinking = false
            if let column { self.place(column) }
        }
    }
}

@main struct ConnectFourApp: App {
    @StateObject private var model = GameModel()
    var body: some Scene {
        WindowGroup("Connect Four") {
            ContentView(model: model)
                .frame(minWidth: 780, idealWidth: 920, minHeight: 710, idealHeight: 780)
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Game") { model.restart() }.keyboardShortcut("n")
            }
        }
    }
}

struct ContentView: View {
    @ObservedObject var model: GameModel
    @Environment(\.colorScheme) private var scheme
    @StateObject private var interaction = InteractionState()
    private let ink = Color(red: 0.12, green: 0.20, blue: 0.30)
    var body: some View {
        ZStack {
            (scheme == .dark ? Color(red: 0.075, green: 0.10, blue: 0.15) : Color(red: 0.95, green: 0.95, blue: 0.92)).ignoresSafeArea()
            VStack(spacing: 22) {
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("THE CLASSIC CONNECTION GAME").font(.system(size: 10, weight: .bold, design: .rounded)).tracking(2).foregroundStyle(.secondary)
                        Text("Connect Four").font(.system(size: 34, weight: .bold, design: .rounded))
                    }
                    Spacer()
                    HStack(spacing: 6) { Circle().fill(Color.coral); Circle().fill(Color.gold) }.frame(width: 42, height: 18)
                }
                HStack(spacing: 26) {
                    VStack(alignment: .leading, spacing: 7) {
                        label("GAME MODE")
                        Picker("Game mode", selection: $model.mode) { ForEach(GameMode.allCases, id: \.self) { Text($0.rawValue).tag($0) } }.pickerStyle(.segmented).frame(width: 280)
                    }
                    VStack(alignment: .leading, spacing: 7) {
                        label("DIFFICULTY")
                        Picker("Difficulty", selection: $model.difficulty) { ForEach(Difficulty.allCases, id: \.self) { Text($0.rawValue).tag($0) } }.pickerStyle(.segmented).frame(width: 240).disabled(model.mode == .local)
                    }
                    Spacer(minLength: 0)
                }
                HStack(alignment: .top, spacing: 26) {
                    VStack(spacing: 8) {
                        HStack(spacing: 0) {
                            ForEach(0..<7) { column in
                                Image(systemName: "arrow.down").font(.system(size: 17, weight: .bold))
                                    .foregroundStyle(discColor(model.game.turn))
                                    .opacity(interaction.hovered == column && model.acceptsInput && model.game.board.validColumns.contains(column) ? 1 : 0.13)
                                    .frame(maxWidth: .infinity)
                            }
                        }.padding(.horizontal, 13).frame(height: 25)
                        board
                        Text("FOUR IN A ROW. ANY DIRECTION.").font(.system(size: 9, weight: .semibold, design: .rounded)).tracking(1.8).foregroundStyle(.secondary).padding(.top, 10)
                    }
                    VStack(alignment: .leading, spacing: 20) {
                        VStack(alignment: .leading, spacing: 10) {
                            label(model.game.outcome == .playing ? "LET’S PLAY" : "ROUND COMPLETE")
                            HStack(spacing: 8) {
                                if model.thinking { ProgressView().controlSize(.small) }
                                else { Circle().fill(discColor(model.game.turn)).frame(width: 11, height: 11) }
                                Text(model.status).font(.system(size: 19, weight: .bold, design: .rounded)).fixedSize(horizontal: false, vertical: true)
                            }
                            Text(model.game.outcome == .playing ? "Choose a column to drop your disc." : "Start a new round and make your next connection.").font(.system(size: 12)).foregroundStyle(.secondary).lineSpacing(4)
                        }.frame(minHeight: 100, alignment: .topLeading)
                        Divider()
                        label("SCOREBOARD")
                        scoreRow(model.name(.red), value: model.scores.red, color: .coral)
                        scoreRow(model.name(.yellow), value: model.scores.yellow, color: .gold)
                        scoreRow("Draws", value: model.scores.draws, color: .secondary)
                        Button(action: model.restart) {
                            Label("New Game", systemImage: "arrow.clockwise").font(.system(size: 13, weight: .semibold)).frame(maxWidth: .infinity).padding(.vertical, 10)
                        }.buttonStyle(.borderedProminent).tint(Color(red: 0.18, green: 0.38, blue: 0.49)).keyboardShortcut("n", modifiers: .command)
                        Button("Reset scores", action: model.resetScores).buttonStyle(.plain).font(.system(size: 11)).foregroundStyle(.secondary).frame(maxWidth: .infinity)
                    }.padding(20).frame(width: 220).background(.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 20)).padding(.top, 33)
                }
                Spacer(minLength: 0)
                HStack {
                    Label("Made for a little friendly rivalry", systemImage: "sparkles")
                    Spacer()
                    Text("⌘ N  New game  ·  1–7  Drop disc")
                }.font(.system(size: 10)).foregroundStyle(.secondary)
            }.padding(.horizontal, 32).padding(.top, 32).padding(.bottom, 20)
        }
    }
    private var board: some View {
        GeometryReader { geometry in
            let size = (geometry.size.width - 26) / 7
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 22).fill(LinearGradient(colors: [Color(red: 0.19, green: 0.36, blue: 0.48), ink], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .shadow(color: .black.opacity(0.18), radius: 14, y: 9)
                HStack(spacing: 0) {
                    ForEach(0..<7) { column in
                        Button { model.play(column) } label: {
                            VStack(spacing: 0) {
                                ForEach(0..<6) { visualRow in
                                    let row = 5 - visualRow
                                    let cell = Cell(row: row, column: column)
                                    ZStack {
                                        Circle().fill(Color.black.opacity(0.30))
                                            .overlay(Circle().stroke(.white.opacity(0.09), lineWidth: 1))
                                        if let disc = model.game.board[row, column] {
                                            DiscView(color: discColor(disc), winning: model.game.winningCells.contains(cell), animate: model.dropping == cell, distance: CGFloat(visualRow + 1) * size)
                                        }
                                    }
                                    .padding(5)
                                    .frame(width: size, height: size)
                                }
                            }
                            .frame(width: size, height: size * 6)
                            .background(Color.white.opacity(interaction.hovered == column && model.acceptsInput ? 0.06 : 0))
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .onHover { interaction.hovered = $0 ? column : (interaction.hovered == column ? nil : interaction.hovered) }
                        .keyboardShortcut(KeyEquivalent(Character(String(column + 1))), modifiers: [])
                        .disabled(!model.acceptsInput || !model.game.board.validColumns.contains(column))
                        .accessibilityLabel("Drop disc in column \(column + 1)")
                        .accessibilityValue((0..<6).map { model.game.board[$0, column].map { $0 == .red ? "red" : "yellow" } ?? "empty" }.joined(separator: ", "))
                    }
                }
                .padding(13)
            }.clipped().clipShape(RoundedRectangle(cornerRadius: 22))
        }.aspectRatio(7.0 / 6.0, contentMode: .fit)
    }
    private func label(_ text: String) -> some View { Text(text).font(.system(size: 9, weight: .bold)).tracking(1.6).foregroundStyle(.secondary) }
    private func discColor(_ disc: Disc) -> Color { disc == .red ? .coral : .gold }
    private func scoreRow(_ title: String, value: Int, color: Color) -> some View {
        HStack { Circle().fill(color).frame(width: 9, height: 9); Text(title).font(.system(size: 13)); Spacer(); Text("\(value)").font(.system(size: 22, weight: .semibold, design: .rounded)).monospacedDigit() }
    }
}

struct DiscView: View {
    let color: Color
    let winning: Bool
    let animate: Bool
    let distance: CGFloat
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @StateObject private var animation = DiscAnimationState()
    var body: some View {
        Circle().fill(LinearGradient(colors: [color, color.opacity(0.82)], startPoint: .topLeading, endPoint: .bottomTrailing))
            .overlay(Circle().strokeBorder(.white.opacity(0.22), lineWidth: 3).padding(5))
            .overlay(Circle().strokeBorder(.white, lineWidth: winning ? 3 : 0).padding(2))
            .shadow(color: winning ? color.opacity(0.8) : .black.opacity(0.25), radius: winning ? 9 : 2, y: 2)
            .scaleEffect(winning && animation.pulse ? 0.90 : 1)
            .offset(y: animate && !animation.landed && !reduceMotion ? -distance : 0)
            .onAppear { withAnimation(reduceMotion ? nil : .spring(response: 0.36, dampingFraction: 0.72)) { animation.landed = true } }
            .onChange(of: winning) { value in
                if value && !reduceMotion { withAnimation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true)) { animation.pulse = true } }
            }
    }
}

extension Color {
    static let coral = Color(red: 0.98, green: 0.34, blue: 0.32)
    static let gold = Color(red: 1, green: 0.76, blue: 0.24)
}

final class InteractionState: ObservableObject { @Published var hovered: Int? }
final class DiscAnimationState: ObservableObject { @Published var landed = false; @Published var pulse = false }
