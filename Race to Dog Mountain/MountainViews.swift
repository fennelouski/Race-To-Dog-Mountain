import SwiftUI

@objc(DMModernSceneDelegate)
final class MountainSceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let scene = scene as? UIWindowScene else { return }
        let window = UIWindow(windowScene: scene)
        window.rootViewController = UIHostingController(rootView: MountainHome())
        window.makeKeyAndVisible()
        self.window = window
    }
}

private struct MountainHome: View {
    @AppStorage("player1Name") private var firstName = "Player 1"
    @AppStorage("player2Name") private var secondName = "Player 2"
    @AppStorage("player1AI") private var firstAI = false
    @AppStorage("player2AI") private var secondAI = true
    @AppStorage("complexity") private var size = 6
    @AppStorage("isPlusGame") private var plusMode = false
    @State private var playing = false
    @State private var history = [0, 0]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        Image(systemName: "mountain.2.fill").font(.system(size: 52)).foregroundStyle(.teal)
                        Text("Every number is a move.").font(.title.bold())
                        Text("Plan your route and finish with the highest score.").foregroundStyle(.secondary)
                    }.padding(.vertical, 14)
                }
                Section("Players") {
                    TextField("First player", text: $firstName)
                    Toggle("Computer plays first player", isOn: $firstAI)
                    TextField("Second player", text: $secondName)
                    Toggle("Computer plays second player", isOn: $secondAI)
                }
                Section("Head to head") {
                    LabeledContent(clean(firstName, fallback: "Player 1"), value: "\(history[0]) \(history[0] == 1 ? "win" : "wins")")
                    LabeledContent(clean(secondName, fallback: "Player 2"), value: "\(history[1]) \(history[1] == 1 ? "win" : "wins")")
                }
                Section("Your game") {
                    Picker("Mode", selection: $plusMode) { Text("Classic").tag(false); Text("Plus").tag(true) }
                    Stepper("Board: \(size) × \(size)", value: $size, in: 4...14)
                    Text(plusMode ? "Choose a tile in your color. Its value adds to your score, and neighboring tiles change sides." : "The first player chooses from the highlighted row, the second from the highlighted column. Each move sets the next player's path.")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                Section {
                    Button { playing = true } label: {
                        Label("Start game", systemImage: "play.fill").font(.headline).frame(maxWidth: .infinity).padding(.vertical, 8)
                    }.buttonStyle(.borderedProminent)
                }
                Section("Privacy") {
                    Link("Privacy Policy", destination: URL(string: "https://nathanfennel.com/race-to-dog-mountain/privacy.html")!)
                }
            }
            .navigationTitle("Dog Mountain")
            .fullScreenCover(isPresented: $playing, onDismiss: refreshHistory) {
                MountainGameView(size: size, plus: plusMode, names: [clean(firstName, fallback: "Player 1"), clean(secondName, fallback: "Player 2")], computers: [firstAI, secondAI])
            }
            .onAppear { size = min(max(size, 4), 14); refreshHistory() }
            .onChange(of: firstName) { _, _ in refreshHistory() }
            .onChange(of: secondName) { _, _ in refreshHistory() }
        }.tint(.teal)
    }
    private func refreshHistory() {
        let names = [clean(firstName, fallback: "Player 1"), clean(secondName, fallback: "Player 2")]
        history = [0, 1].map { UserDefaults.standard.integer(forKey: "\(names[$0])vvv\(names[1 - $0])") }
    }
    private func clean(_ name: String, fallback: String) -> String {
        let result = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return result.isEmpty ? fallback : result
    }
}

private struct MountainGameView: View {
    let names: [String]
    @State private var computers: [Bool]
    @State private var game: MountainGame
    @State private var recorded = false
    @State private var confirmExit = false
    @State private var foregroundNonce = 0
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(size: Int, plus: Bool, names: [String], computers: [Bool]) {
        self.names = names
        // A new presentation owns a new game and its computer-player settings.
        _game = State(initialValue: MountainGame(size: size, plusMode: plus))
        _computers = State(initialValue: computers)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                HStack(spacing: 12) { score(player: 0); score(player: 1) }.padding(.horizontal)
                Text(game.isOver ? result : "\(names[game.turn])'s turn")
                    .font(.title2.bold()).multilineTextAlignment(.center)
                if !game.isOver {
                    Text(computers[game.turn] ? "Computer is choosing…" : (game.plusMode ? "Choose a highlighted tile in your color." : "Choose a number in the highlighted \(game.turn == 0 ? "row" : "column")."))
                        .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center).padding(.horizontal)
                }
                GeometryReader { geometry in
                    let width = max(44, min(70, (geometry.size.width - 32 - CGFloat(game.size - 1) * 6) / CGFloat(game.size)))
                    ScrollView([.horizontal, .vertical]) {
                        LazyVGrid(columns: Array(repeating: GridItem(.fixed(width), spacing: 6), count: game.size), spacing: 6) {
                            ForEach(game.tiles) { tile in
                                Button { move(tile.id) } label: {
                                    Text(tile.value == 0 ? "·" : "\(tile.value)").font(.title3.bold()).monospacedDigit()
                                        .frame(width: width, height: width)
                                        .foregroundStyle(game.canPlay(tile.id) ? .white : .primary)
                                        .background(game.canPlay(tile.id) ? playerColor(game.turn) : Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 10))
                                        .overlay { if game.plusMode && tile.value > 0 { RoundedRectangle(cornerRadius: 10).stroke(playerColor(tile.owner), lineWidth: 2) } }
                                }
                                .buttonStyle(.plain)
                                .disabled(!game.canPlay(tile.id) || computers[game.turn] || game.isOver)
                                .accessibilityLabel("Row \(tile.id / game.size + 1), column \(tile.id % game.size + 1), \(tile.value == 0 ? "used" : String(tile.value))")
                                .accessibilityValue(game.plusMode && tile.value > 0 ? "Belongs to \(names[tile.owner])" : "")
                            }
                        }.padding(16).frame(minWidth: geometry.size.width)
                    }
                }
                if game.isOver {
                    Button("Back to game setup") { dismiss() }.buttonStyle(.borderedProminent).padding(.bottom)
                }
            }
            .padding(.top).background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle(game.plusMode ? "Plus" : "Classic").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) { Button("Close") { if game.isOver { dismiss() } else { confirmExit = true } } }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu("Players", systemImage: "person.2") {
                        Toggle("Computer: \(names[0])", isOn: $computers[0])
                        Toggle("Computer: \(names[1])", isOn: $computers[1])
                    }
                }
            }
            .confirmationDialog("Leave this game?", isPresented: $confirmExit, titleVisibility: .visible) {
                Button("Leave game", role: .destructive) { dismiss() }
            } message: { Text("This unfinished game will not count toward your wins.") }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in foregroundNonce += 1 }
            .task(id: "\(game.moves)-\(computers)-\(confirmExit)-\(foregroundNonce)") {
                guard UIApplication.shared.applicationState != .background, !confirmExit, !game.isOver, computers[game.turn] else { return }
                do { try await Task.sleep(for: .milliseconds(550)) } catch { return }
                guard !Task.isCancelled, !confirmExit, UIApplication.shared.applicationState != .background else { return }
                if let next = game.computerMove() { move(next) }
            }
            .onChange(of: game.isOver) { _, over in if over { recordWin() } }
        }.tint(.teal)
    }
    private func playerColor(_ player: Int) -> Color { player == 0 ? .teal : .indigo }
    private var result: String {
        game.scores[0] == game.scores[1] ? "A tie!" : "\(names[game.scores[0] > game.scores[1] ? 0 : 1]) wins"
    }
    private func score(player: Int) -> some View {
        VStack(spacing: 4) {
            Text(names[player]).font(.headline).lineLimit(2)
            Text("\(game.scores[player])").font(.largeTitle.bold()).monospacedDigit()
            Text("points").font(.caption)
        }.frame(maxWidth: .infinity).padding(12).foregroundStyle(playerColor(player))
            .background(.background, in: RoundedRectangle(cornerRadius: 16))
            .accessibilityElement(children: .combine)
    }
    private func move(_ id: Int) {
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.18)) { _ = game.play(id) }
    }
    private func recordWin() {
        guard !recorded else { return }
        recorded = true
        guard game.scores[0] != game.scores[1] else { return }
        let winner = game.scores[0] > game.scores[1] ? 0 : 1
        let key = "\(names[winner])vvv\(names[1 - winner])"
        UserDefaults.standard.set(UserDefaults.standard.integer(forKey: key) + 1, forKey: key)
    }
}
