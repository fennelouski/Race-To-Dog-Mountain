import SwiftUI
import WatchKit

@main struct MountainWatchApp: App {
    var body: some Scene { WindowGroup { WatchMountain() } }
}

private struct WatchMountain: View {
    @AppStorage("computerLevel") private var level = ComputerDifficulty.level6.rawValue
    @State private var match = WatchMatch.restore()
    private var difficulty: ComputerDifficulty { ComputerDifficulty(rawValue: level) ?? .level6 }

    var body: some View {
        NavigationStack {
            if let match {
                WatchGame(match: match) {
                    UserDefaults.standard.removeObject(forKey: WatchMatch.saveKey)
                    self.match = nil
                }.id(match.id)
            } else {
                TabView {
                    ScrollView {
                        VStack(spacing: 12) {
                            Image(systemName: "mountain.2.fill").font(.system(size: 42)).accessibilityLabel("Race to Dog Mountain").accessibilityAddTraits(.isHeader)
                            Button {
                                let next = WatchMatch(size: 4, difficulty: difficulty, computers: [false, true])
                                next.save(); match = next
                            } label: { Image(systemName: "play.fill").font(.title2).frame(maxWidth: .infinity) }
                                .buttonStyle(WatchButton(prominent: true)).accessibilityIdentifier("start-game").accessibilityLabel("Play")
                        }.padding(.horizontal, 8)
                    }.background {
                        MountainScenery(active: false).overlay(MountainStyle.ink.opacity(0.65)).ignoresSafeArea()
                    }
                    WatchSettings()
                }.tabViewStyle(.verticalPage)

            }
        }.foregroundStyle(MountainStyle.cream).tint(MountainStyle.gold).preferredColorScheme(.dark)
    }
}

private struct WatchSettings: View {
    @AppStorage("computerLevel") private var level = ComputerDifficulty.level6.rawValue
    var onHome: (() -> Void)?
    private var difficulty: ComputerDifficulty { ComputerDifficulty(rawValue: level) ?? .level6 }
    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                Image(systemName: "slider.horizontal.3").font(.title3).accessibilityLabel("Settings").accessibilityAddTraits(.isHeader)
                NavigationLink { WatchRivals(level: $level) } label: {
                    HStack { Image(systemName: "speedometer"); WatchPortrait(difficulty: difficulty, size: 28); Text("\(difficulty.rawValue + 1)").monospacedDigit() }
                }.buttonStyle(WatchButton()).accessibilityLabel("Difficulty \(difficulty.rawValue + 1), \(difficulty.name)").accessibilityHint("Applies to the next game")
                if let onHome { Button(action: onHome) { Image(systemName: "xmark").frame(maxWidth: .infinity) }.buttonStyle(WatchButton()).accessibilityLabel("End game") }
            }.padding(.horizontal, 8).padding(.bottom, 18)
        }.background(MountainStyle.ink)
    }
}

private struct WatchRivals: View {
    @Binding var level: Int
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        List(ComputerDifficulty.allCases) { rival in
            Button {
                level = rival.rawValue
                UserDefaults.standard.removeObject(forKey: "watchSkill.v1")
                dismiss()
            } label: {
                HStack(spacing: 8) {
                    WatchPortrait(difficulty: rival, size: 28)
                    Text("\(rival.rawValue + 1)").monospacedDigit()
                    if level == rival.rawValue { Image(systemName: "checkmark").accessibilityLabel("Selected") }
                }.frame(minHeight: 44)
            }.accessibilityLabel("Difficulty \(rival.rawValue + 1), \(rival.name)\(level == rival.rawValue ? ", selected" : "")")
        }
    }
}

private struct WatchGame: View {
    let onLeave: () -> Void
    @State private var match: WatchMatch
    @State private var replaying = false
    @State private var page = 0
    @State private var confirmExit = false
    @Environment(\.scenePhase) private var phase
    @Environment(\.isLuminanceReduced) private var dimmed
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(match: WatchMatch, onLeave: @escaping () -> Void) {
        // The saved or newly created match seeds this screen once.
        _match = State(initialValue: match)
        self.onLeave = onLeave
    }
    private var active: Bool { phase == .active && !dimmed }
    private var paused: Bool { replaying || page != 0 || confirmExit }
    private func name(_ player: Int) -> String {
        match.computers[player] ? match.difficulty.name : match.computers.contains(true) ? "You" : "Player \(player + 1)"
    }

    var body: some View {
        TabView(selection: $page) {
            VStack(spacing: 6) {
                ScrollView {
                    VStack(spacing: 8) {
                    if match.game.isOver {
                        Button { page = 2 } label: { Image(systemName: "trophy.fill").font(.title2).frame(maxWidth: .infinity) }.buttonStyle(WatchButton(prominent: true)).accessibilityLabel("See final score")
                    } else {
                        HStack(spacing: 6) {
                            Image(systemName: match.game.turn == 0 ? "arrow.left.and.right" : "arrow.up.and.down")
                            Text("\(match.game.turn == 0 ? match.game.row + 1 : match.game.column + 1)").monospacedDigit()
                        }.font(.caption).foregroundStyle(MountainStyle.player(match.game.turn))
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel("\(match.computers[match.game.turn] ? "\(name(match.game.turn))'s" : "Your") \(match.game.turn == 0 ? "row \(match.game.row + 1)" : "column \(match.game.column + 1)")")
                        if match.waitingForStart {
                            Button { match.startComputer(); match.save() } label: { Image(systemName: "play.fill").frame(maxWidth: .infinity) }.buttonStyle(WatchButton(prominent: true)).accessibilityLabel("Play computer")
                        } else if match.computers[match.game.turn] {
                            HStack { WatchPortrait(difficulty: match.difficulty, size: 24); ProgressView().tint(MountainStyle.mint) }.accessibilityElement(children: .ignore).accessibilityLabel("\(match.difficulty.name) is choosing")
                        } else {
                            moves
                        }
                    }
                    }.padding(.horizontal, 8).padding(.top, 6).padding(.bottom, 4)
                }
                WatchPointsBar(game: match.game, rival: match.difficulty.name).padding(.horizontal, 8).padding(.bottom, 8)
            }.tag(0)
            ScrollView { WatchBoard(game: match.game).padding(.bottom, 18) }.tag(1)
            ScrollView {
                VStack(spacing: 8) {
                    Image(systemName: "chart.bar.fill").font(.title3).accessibilityLabel("Score").accessibilityAddTraits(.isHeader)
                    HStack(spacing: 8) { score(0); score(1) }
                    HStack { Image(systemName: "square.grid.3x3.fill"); Text("\(match.game.tiles.reduce(0) { $0 + $1.value })").monospacedDigit() }.font(.caption).accessibilityElement(children: .ignore).accessibilityLabel("\(match.game.tiles.reduce(0) { $0 + $1.value }) points left on the board")
                    if match.game.isOver {
                        Image(systemName: match.game.scores[0] == match.game.scores[1] ? "equal" : "crown.fill").foregroundStyle(MountainStyle.player(match.game.scores[0] > match.game.scores[1] ? 0 : 1)).accessibilityLabel(match.game.scores[0] == match.game.scores[1] ? "A tie" : "\(name(match.game.scores[0] > match.game.scores[1] ? 0 : 1)) wins")
                        Button { restart() } label: { Image(systemName: "arrow.counterclockwise").frame(maxWidth: .infinity) }.buttonStyle(WatchButton(prominent: true)).accessibilityLabel("Play again")
                    }
                    Button { replaying = true } label: { Image(systemName: "play.rectangle").frame(maxWidth: .infinity) }
                        .buttonStyle(WatchButton()).disabled(match.replay == nil).opacity(match.replay == nil ? 0.5 : 1)
                        .accessibilityIdentifier("replay-computer").accessibilityLabel("Replay computer move").accessibilityHint(match.replay == nil ? "Ready after the computer moves" : "Watch the last move again")
                }.padding(.horizontal, 8).padding(.bottom, 18)
            }.tag(2)
            WatchSettings(onHome: {
                if match.game.isOver { onLeave() } else { confirmExit = true }
            }).tag(3)
        }.tabViewStyle(.verticalPage).background(MountainStyle.ink)
        .onChange(of: match.game.isOver) { _, over in if over { page = 2 } }
        .confirmationDialog("End this game?", isPresented: $confirmExit, titleVisibility: .visible) {
            Button("End game", role: .destructive, action: onLeave)
        } message: { Text("Your unfinished game will be discarded.") }
        .sheet(isPresented: $replaying) {
            if let replay = match.replay {
                NavigationStack {
                    WatchReplay(replay: replay)
                        .toolbar { ToolbarItem(placement: .cancellationAction) { Button { replaying = false } label: { Image(systemName: "xmark") }.accessibilityLabel("Close replay") } }
                }
            }
        }

        .task(id: "\(match.id)-\(match.game.moves)-\(phase)-\(dimmed)-\(paused)-\(match.computerStarted)") {
            guard match.canComputerMove(active: active, paused: paused) else { return }
            do { try await Task.sleep(for: .milliseconds(700)) } catch { return }
            let snapshot = match
            let tile = await Task.detached(priority: .userInitiated) { snapshot.game.computerMove(difficulty: snapshot.difficulty, adjustment: snapshot.adjustment) }.value
            guard !Task.isCancelled, match.id == snapshot.id, match.game.moves == snapshot.game.moves,
                  match.canComputerMove(active: active, paused: paused), let tile else { return }
            play(tile, computer: true)
        }
    }
    private func restart() {
        let level = UserDefaults.standard.object(forKey: "computerLevel") as? Int ?? ComputerDifficulty.level6.rawValue
        match = WatchMatch(size: 4, difficulty: ComputerDifficulty(rawValue: level) ?? .level6, computers: [false, true])
        match.save(); page = 0
    }
    private var moves: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
            ForEach(match.game.legalMoves, id: \.self) { tile in
                Button { play(tile) } label: {
                    Text("\(match.game.tiles[tile].value)").font(.title3.bold()).monospacedDigit().frame(maxWidth: .infinity)
                }.buttonStyle(WatchButton(tileColor: MountainStyle.player(match.game.turn)))
                    .accessibilityLabel("\(match.game.tiles[tile].value) points, row \(tile / match.game.size + 1), column \(tile % match.game.size + 1)")
                    .accessibilityHint("Sets the next player's \(match.game.turn == 0 ? "column" : "row")")
                    .accessibilityIdentifier("tile-\(tile)")
            }
        }
    }
    private func play(_ tile: Int, computer: Bool = false) {
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) {
            if match.play(tile, computer: computer) { WKInterfaceDevice.current().play(match.game.isOver ? .success : .click) }
        }
    }
    private func score(_ player: Int) -> some View {
        VStack(spacing: 2) {
            if match.computers[player] { WatchPortrait(difficulty: match.difficulty, size: 24) } else { Image(systemName: "person.fill").frame(height: 24) }
            Text("\(match.game.scores[player])").font(.title3.bold()).monospacedDigit()
        }.frame(maxWidth: .infinity).foregroundStyle(MountainStyle.player(player))
            .accessibilityElement(children: .ignore).accessibilityLabel("\(name(player)), \(player == 0 ? "row" : "column") player, \(match.game.scores[player]) points")
    }
}

private struct WatchPointsBar: View {
    let game: MountainGame
    let rival: String
    private var points: [Int] { game.scores + [game.tiles.reduce(0) { $0 + $1.value }] }
    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                ForEach(0..<3, id: \.self) { index in
                    Rectangle().fill(index == 2 ? MountainStyle.cream.opacity(0.4) : MountainStyle.player(index))
                        .frame(width: geometry.size.width * CGFloat(points[index]) / CGFloat(max(1, points.reduce(0, +))))
                }
            }.clipShape(Capsule())
        }.frame(height: 4)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("You \(points[0]) points, \(rival) \(points[1]) points, \(points[2]) points left on the board")
    }
}

private struct WatchBoard: View {
    let game: MountainGame
    var selected: Int?
    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: game.isOver ? "flag.checkered" : game.turn == 0 ? "arrow.left.and.right" : "arrow.up.and.down")
                if !game.isOver { Text("\(game.turn == 0 ? game.row + 1 : game.column + 1)").monospacedDigit() }
            }.font(.caption).foregroundStyle(MountainStyle.player(game.turn))
                .accessibilityElement(children: .ignore).accessibilityLabel(game.isOver ? "Final board" : "\(game.turn == 0 ? "Row \(game.row + 1)" : "Column \(game.column + 1)") highlighted")
            if game.size == 4 {
                grid
            } else {
                ScrollView(.horizontal) { grid }.frame(height: CGFloat(game.size * 33 + 5)).focusable(false)
            }
        }.background(MountainStyle.ink)
    }
    private var grid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.fixed(30), spacing: 3), count: game.size), spacing: 3) {
                    ForEach(game.tiles) { tile in
                        Text(tile.value == 0 ? "·" : "\(tile.value)").font(.caption2.bold()).monospacedDigit()
                            .frame(width: 30, height: 30).foregroundStyle(tile.value == 0 ? MountainStyle.cream : MountainStyle.ink)
                            .background(tile.value == 0 ? MountainStyle.cream.opacity(0.06) : game.canPlay(tile.id) ? MountainStyle.player(game.turn) : MountainStyle.cream, in: RoundedRectangle(cornerRadius: 5))
                            .overlay { if selected == tile.id { RoundedRectangle(cornerRadius: 5).strokeBorder(MountainStyle.gold, lineWidth: 3) } }
                            .accessibilityLabel("Row \(tile.id / game.size + 1), column \(tile.id % game.size + 1), \(tile.value == 0 ? "used" : "\(tile.value) points")\(game.canPlay(tile.id) ? ", available" : "")")
                    }
        }.padding(4)
    }
}

private struct WatchReplay: View {
    let replay: MountainReplay
    @State private var step = 0
    @State private var repeatCount = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                HStack {
                    WatchPortrait(difficulty: replay.difficulty, size: 24)
                    Image(systemName: step == 0 ? "backward.end.fill" : step == 1 ? "scope" : "checkmark")
                    Text("\(replay.before.tiles[replay.tileID].value)").font(.title3.bold()).monospacedDigit()
                }.accessibilityElement(children: .ignore).accessibilityLabel(step == 0 ? "Before the move" : step == 1 ? "\(replay.difficulty.name) chooses \(replay.before.tiles[replay.tileID].value)" : "\(replay.difficulty.name) earned \(replay.before.tiles[replay.tileID].value) points")
                Button { repeatCount += 1 } label: { Image(systemName: "arrow.counterclockwise").frame(maxWidth: .infinity) }.buttonStyle(WatchButton(prominent: true)).accessibilityLabel("Watch again")
                WatchBoard(game: step < 2 ? replay.before : replay.after, selected: step == 0 ? nil : replay.tileID)
            }.padding(.horizontal, 8).padding(.bottom, 8)
        }.background(MountainStyle.ink)
            .task(id: repeatCount) {
                step = 0
                do {
                    try await Task.sleep(for: .milliseconds(650))
                    withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) { step = 1 }
                    try await Task.sleep(for: .milliseconds(900))
                    withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) { step = 2 }
                } catch { return }
            }
    }
}

private struct WatchPortrait: View {
    let difficulty: ComputerDifficulty
    let size: CGFloat
    var body: some View {
        Image(difficulty.portrait).resizable().scaledToFill().frame(width: size, height: size).clipShape(Circle()).accessibilityHidden(true)
    }
}

private struct WatchButton: ButtonStyle {
    var prominent = false
    var tileColor: Color?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.headline).padding(.horizontal, 10).padding(.vertical, 8)
            .frame(maxWidth: .infinity, minHeight: 44)
            .foregroundStyle(prominent || tileColor != nil ? MountainStyle.ink : MountainStyle.cream)
            .background(tileColor ?? (prominent ? MountainStyle.gold : MountainStyle.cream.opacity(0.10)), in: RoundedRectangle(cornerRadius: 12))
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.96 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: configuration.isPressed)
    }
}
