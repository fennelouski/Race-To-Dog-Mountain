import SwiftUI

struct MountainChallengeBoard: View {
    let challenge: MountainChallenge
    let names: [String]
    var canPlay: Bool
    var busy = false
    var select: (Int) -> Void
    @Environment(\.dynamicTypeSize) private var typeSize
    private var game: MountainGame { challenge.game }

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 24) {
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 16) { score(0); score(1) }
                        VStack(spacing: 12) { score(0); score(1) }
                    }
                    VStack(spacing: 8) {
                        Label(status, systemImage: game.isOver ? "flag.checkered" : canPlay ? "hand.point.up.left.fill" : "hourglass")
                            .font(.title2.bold()).multilineTextAlignment(.center)
                        if !game.isOver {
                            Label("\(names[game.turn])'s \(game.turn == 0 ? "row" : "column")", systemImage: game.turn == 0 ? "arrow.left.and.right" : "arrow.up.and.down")
                                .foregroundStyle(MountainStyle.player(game.turn)).font(.subheadline)
                        }
                    }.accessibilityElement(children: .combine)
                    if busy { ProgressView("Saving move…").tint(MountainStyle.gold) }
                    MountainBoard(game: game, availableWidth: min(geometry.size.width - 32, 700), interactive: canPlay && !busy, lastMove: challenge.moves.last, lastPoints: challenge.moves.last.map { challenge.values[$0] } ?? 0, select: select)
                    Text("Every choice sets your friend's next move.").font(.footnote).multilineTextAlignment(.center)
                }.padding(16).frame(maxWidth: 760).frame(maxWidth: .infinity)
            }
        }
    }
    private var status: String {
        if game.isOver { return game.scores[0] == game.scores[1] ? "An even climb" : "\(names[game.scores[0] > game.scores[1] ? 0 : 1]) wins!" }
        return busy ? "Passing the turn" : canPlay ? "Your move" : "Your friend's move"
    }
    private func score(_ player: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(names[player], systemImage: "person.fill").font(.headline).fixedSize(horizontal: false, vertical: true)
            Text("\(game.scores[player])").font(MountainStyle.display(36)).monospacedDigit()
        }.frame(maxWidth: .infinity, alignment: .leading).padding(16)
            .foregroundStyle(MountainStyle.player(player))
            .background(MountainStyle.player(player).opacity(0.12), in: RoundedRectangle(cornerRadius: 16))
            .accessibilityElement(children: .ignore).accessibilityLabel("\(names[player]), \(game.scores[player]) points")
    }
}

#if !DOGMOUNTAIN_MESSAGES
struct MountainFriendGame: View {
    @Bindable var friends: MountainFriends
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            ZStack {
                MountainScenery(active: false)
                MountainStyle.ink.opacity(0.65).ignoresSafeArea()
                if let race = friends.opened, let challenge = race.challenge {
                    VStack(spacing: 12) {
                        MountainChallengeBoard(challenge: challenge, names: race.names, canPlay: race.yourTurn && !race.ended,
                                               busy: friends.sending) { tile in Task { await friends.play(tile) } }
                        if race.ended {
                            Button { Task { await friends.rematch() } } label: { Label("Rematch", systemImage: "arrow.clockwise").frame(maxWidth: .infinity) }
                                .buttonStyle(MountainButton(prominent: true)).disabled(friends.sending).padding(.horizontal, 16).padding(.bottom, 16)
                        }
                    }
                }
            }
            .navigationTitle("Friend game").mountainInlineTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } }
                ToolbarItem(placement: .primaryAction) { Button { if let id = friends.opened?.id { Task { await friends.open(id) } } } label: { Image(systemName: "arrow.clockwise") }.disabled(friends.sending).accessibilityLabel("Refresh game") }
            }
            .alert("Game Center", isPresented: Binding(get: { friends.error != nil }, set: { if !$0 { friends.error = nil } })) {
                Button("OK") { friends.error = nil }
            } message: { Text(friends.error ?? "") }
        }.foregroundStyle(MountainStyle.cream).tint(MountainStyle.gold).preferredColorScheme(.dark)
    }
}

#endif

struct MountainMatchRow: View {
    let title: String
    let subtitle: String
    let scores: [Int]?
    let symbol: String
    var needsMove = false
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: symbol).font(.title2).foregroundStyle(needsMove ? MountainStyle.gold : MountainStyle.mint)
                    .frame(width: 44, height: 44).accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 5) {
                    Text(title).font(.headline).fixedSize(horizontal: false, vertical: true)
                    Text(subtitle).font(.subheadline).foregroundStyle(MountainStyle.cream.opacity(0.8)).fixedSize(horizontal: false, vertical: true)
                    if let scores { Text("\(scores[0]) : \(scores[1])").font(.subheadline.bold()).monospacedDigit() }
                }.frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "chevron.right").accessibilityHidden(true)
            }.padding(.vertical, 12)
        }.buttonStyle(.plain).mountainHover().accessibilityElement(children: .combine)
    }
}

#if os(iOS) && !DOGMOUNTAIN_MESSAGES
struct MountainMessagesHelp: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Image(systemName: "message.fill").font(.largeTitle).foregroundStyle(MountainStyle.mint).accessibilityHidden(true)
                    Text("Race in Messages").font(MountainStyle.display(36)).accessibilityAddTraits(.isHeader)
                    Text("Open a conversation with a friend. Tap + and choose Race to Dog Mountain from your Messages apps.")
                    Text("Pick your first number and add the board to your message. Your friend taps the board to take their turn.")
                    Text("Each new race has its own board in the conversation. You can keep several games going.")
                    Button { if let url = URL(string: "sms:") { UIApplication.shared.open(url) } } label: { Label("Open Messages", systemImage: "message.fill").frame(maxWidth: .infinity) }
                        .buttonStyle(MountainButton(prominent: true))
                }.padding(28).frame(maxWidth: 600).frame(maxWidth: .infinity)
            }.background(MountainStyle.ink)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } } }
        }.foregroundStyle(MountainStyle.cream).tint(MountainStyle.gold).preferredColorScheme(.dark)
    }
}
#endif
