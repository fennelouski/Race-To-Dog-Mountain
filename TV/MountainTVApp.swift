import SwiftUI

@main struct MountainTVApp: App {
    var body: some Scene { WindowGroup { MountainTVHome() } }
}

private struct TVSave: Codable {
    var game: MountainGame
    var history: [MountainGame]
    var difficulty: Int
    var local: Bool
}

private struct MountainTVHome: View {
    @Environment(\.scenePhase) private var phase
    @State private var game = MountainGame(size: 6)
    @State private var history: [MountainGame] = []
    @State private var difficulty = 5
    @State private var size = 6
    @State private var local = false
    @State private var playing = false
    @State private var settings = false
    @State private var help = false
    @State private var leave = false
    @State private var replay = false
    @State private var replayStep = 0
    @FocusState private var focusedTile: Int?
    private let defaults = MountainExperience.defaults
    private var rival: ComputerDifficulty { ComputerDifficulty(rawValue: difficulty) ?? .level6 }
    private var shown: MountainGame {
        replay && history.indices.contains(replayStep) ? history[replayStep] : game
    }
    private var showcase: Int? {
#if DEBUG
        let args = ProcessInfo.processInfo.arguments
        if MountainExperience.isQAActive, let i = args.firstIndex(of: "-MountainShowcase"), args.indices.contains(i + 1) { return Int(args[i + 1]) }
#endif
        return nil
    }
    var body: some View {
        ZStack {
            MountainScenery(active: phase == .active, lush: true).ignoresSafeArea()
            Color.black.opacity(0.35).ignoresSafeArea()
            if playing { board } else { landing }
        }
        .foregroundStyle(MountainStyle.cream).tint(MountainStyle.gold).preferredColorScheme(.dark)
        .onAppear(perform: restore)
        .onChange(of: phase) { _, value in if value != .active { persist() } }
        .task(id: "\(game.moves)-\(playing)-\(phase)-\(replay)-\(leave)") {
            guard playing, phase == .active, !leave, !replay, !local, !game.isOver, game.turn == 1, showcase == nil else { return }
            let snapshot = game
            let level = rival
            do { try await Task.sleep(for: .seconds(0.7)) } catch { return }
            let move = await Task.detached { snapshot.computerMove(difficulty: level) }.value
            guard !Task.isCancelled, game.moves == snapshot.moves, let move else { return }
            makeMove(move)
        }
        .sheet(isPresented: $settings) { configuration.padding(70) }
        .sheet(isPresented: $help) { guide.padding(80) }
        .confirmationDialog("Leave Game", isPresented: $leave) {
            Button("Leave Game") { persist(); playing = false }
            Button("Cancel", role: .cancel) {}
        }
        .onExitCommand(perform: playing ? { if replay { replay = false } else { leave = true } } : nil)
    }
    private var landing: some View {
        VStack(spacing: 30) {
            MountainVineTitle(grow: 1, frame: CGRect(x: 0, y: 0, width: 680, height: 270)).frame(width: 680, height: 270).accessibilityLabel("Tally Tangle")
            Text("Every choice changes the possibilities.").font(.title2)
            HStack(spacing: 32) {
                Button("Play") { start() }
                if defaults.data(forKey: "tv.game.v1") != nil { Button("Continue") { playing = true; focusLegal() } }
                Button("Player") { settings = true }
                Button("How to play") { help = true }
            }.buttonStyle(.borderedProminent)
            Text(local ? String(localized: "Pass & Play") : rival.displayName).font(.headline).foregroundStyle(MountainStyle.mint)
        }
    }
    private var board: some View {
        HStack(alignment: .center, spacing: 65) {
            VStack(alignment: .leading, spacing: 28) {
                Text(verbatim: "Tally\nTangle").font(MountainStyle.display(60))
                score(0); score(1)
                if shown.isOver { Text("Game over").font(.title2) }
                else { Text(shown.turn == 0 ? String(localized: "Follow the gold row") : String(localized: "Now try the mint column")).font(.headline) }
                VStack(alignment: .leading, spacing: 18) {
                    if !history.isEmpty {
                        Button(replay ? String(localized: "Done") : String(localized: "Replay")) { replay.toggle(); replayStep = 0 }
                        if replay {
                            HStack {
                                Button { replayStep = max(0, replayStep - 1) } label: { Image(systemName: "backward.end.fill") }.accessibilityLabel("Previous step")
                                Button { replayStep = min(history.count, replayStep + 1) } label: { Image(systemName: "forward.end.fill") }.accessibilityLabel("Next completed step")
                            }
                        }
                    }
                    Button("New Game") { start() }
                    Button("Home") { persist(); playing = false }
                }.buttonStyle(.bordered)
            }.frame(width: 410, alignment: .leading)
            GeometryReader { proxy in
                let side = min(proxy.size.width, proxy.size.height)
                let cell = (side - CGFloat(shown.size - 1) * 10) / CGFloat(shown.size)
                LazyVGrid(columns: Array(repeating: GridItem(.fixed(cell), spacing: 10), count: shown.size), spacing: 10) {
                    ForEach(shown.tiles) { tile in
                        Button { makeMove(tile.id) } label: {
                            Text(tile.value == 0 ? "" : tile.value.formatted(.number))
                                .font(.system(size: min(40, cell * 0.36), weight: .bold, design: .rounded))
                                .foregroundStyle(shown.canPlay(tile.id) ? MountainStyle.ink : MountainStyle.cream.opacity(0.65))
                                .frame(width: cell, height: cell)
                                .background(shown.canPlay(tile.id) ? (shown.turn == 0 ? MountainStyle.gold : MountainStyle.mint) : MountainStyle.ink.opacity(0.65), in: RoundedRectangle(cornerRadius: 14))
                        }
                        .buttonStyle(.card).focused($focusedTile, equals: tile.id)
                        .disabled(replay || !game.canPlay(tile.id) || (!local && game.turn == 1))
                        .accessibilityLabel(Text(verbatim: String(format: String(localized: "Row %lld, column %lld, %lld points"), locale: .current, Int64(tile.id / shown.size + 1), Int64(tile.id % shown.size + 1), Int64(tile.value))))
                    }
                }.frame(width: side, height: side)
            }.frame(width: 780, height: 780)
        }.padding(60)
    }
    private func score(_ seat: Int) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(seat == 0 ? String(localized: "Player 1") : local ? String(localized: "Player 2") : rival.displayName).font(.headline)
            Text(shown.scores[seat], format: .number).font(.system(size: 64, weight: .bold, design: .serif))
        }.foregroundStyle(seat == 0 ? MountainStyle.gold : MountainStyle.mint)
    }
    private var configuration: some View {
        VStack(spacing: 25) {
            Text("Player").font(.largeTitle)
            Toggle("Pass & Play", isOn: $local)
            Picker("Computer player", selection: $difficulty) { ForEach(ComputerDifficulty.allCases) { level in Text(verbatim: level.displayName).tag(level.rawValue) } }
            Picker("Board size", selection: $size) { ForEach(4...14, id: \.self) { n in Text(verbatim: "\(n.formatted(.number)) × \(n.formatted(.number))").tag(n) } }
            Button("Done") { defaults.set(size, forKey: "tv.size"); defaults.set(difficulty, forKey: "tv.difficulty"); defaults.set(local, forKey: "tv.local"); settings = false }
        }
    }
    private var guide: some View {
        VStack(alignment: .leading, spacing: 30) {
            Text("How to play").font(.largeTitle)
            Text("Pick a gold number. Notice which column you leave.")
            Text("Your choice set this column. Tap a mint number.")
            Text("When the next player has no moves, the higher score wins.")
            Button("Done") { help = false }
        }.frame(maxWidth: 1100)
    }
    private func start() {
        game = MountainGame(size: size); history = []; replay = false; playing = true; persist(); focusLegal()
    }
    private func makeMove(_ id: Int) {
        guard !replay, game.canPlay(id) else { return }
        history.append(game); game.play(id); persist(); focusLegal()
    }
    private func focusLegal() { focusedTile = game.legalMoves.first }
    private func persist() {
        guard showcase == nil, playing || defaults.data(forKey: "tv.game.v1") != nil, let data = try? JSONEncoder().encode(TVSave(game: game, history: history, difficulty: difficulty, local: local)) else { return }
        defaults.set(data, forKey: "tv.game.v1")
    }
    private func restore() {
        size = min(14, max(4, defaults.integer(forKey: "tv.size") == 0 ? 6 : defaults.integer(forKey: "tv.size")))
        difficulty = min(17, max(0, defaults.object(forKey: "tv.difficulty") as? Int ?? 5)); local = defaults.bool(forKey: "tv.local")
        if let n = showcase { stage(n); return }
        if let data = defaults.data(forKey: "tv.game.v1") {
            if let saved = try? JSONDecoder().decode(TVSave.self, from: data), saved.game.isValid,
               saved.history.count == saved.game.moves, saved.history.allSatisfy(\.isValid) {
                game = saved.game; history = saved.history; difficulty = min(17, max(0, saved.difficulty)); local = saved.local
            } else {
                defaults.set(data, forKey: "tv.unreadable.game.v1")
            }
        }
    }
    private func stage(_ number: Int) {
        guard number > 1 else { return }
        if number == 2 || number == 18 { difficulty = number % 18; size = number == 2 ? 4 : 8; settings = true; return }
        if number == 3 { help = true; return }
        size = [4,5,6,7,8][number % 5]; difficulty = number % 18; local = number % 7 == 0
        var rng = TVSeed(state: UInt64(number + 101))
        game = MountainGame(size: size, values: Array(1...(size * size)).shuffled(using: &rng), startingLine: number % size)
        history = []
        let count = [13,14,15,16,17,30].contains(number) ? size * size : number % (size * 2) + 2
        for _ in 0..<count {
            guard let move = game.computerMove(difficulty: .level6, roll: 0.4, using: &rng) else { break }
            history.append(game); game.play(move)
        }
        playing = true; replay = number == 24; replayStep = max(0, history.count - 1)
    }
}
private struct TVSeed: RandomNumberGenerator {
    var state: UInt64
    mutating func next() -> UInt64 { state = state &* 6364136223846793005 &+ 1442695040888963407; return state }
}
