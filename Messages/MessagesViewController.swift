import Messages
import SwiftUI

@MainActor @Observable final class MountainMessagesState {
    var challenge: MountainChallenge?
    var original: MountainChallenge?
    var player = ""
    var error: String?
    var staged = false
    var busy = false
    var expanded = false
    var twoPlayers = false
    var expand: (() -> Void)?
    var stage: ((MountainChallenge) -> Void)?
    var newRace: (() -> Void)?
    var canMove: Bool { challenge.map { !$0.game.isOver && $0.game.turn == $0.seat(for: player) && $0.moves.count == original?.moves.count && !staged && !busy } ?? false }
    var names: [String] { challenge?.rowPlayer == player ? ["You", "Friend"] : ["Friend", "You"] }
    func choose(_ tile: Int) {
        guard canMove, var next = challenge, next.play(tile, player: player) else { return }
        challenge = next
    }
}

final class MessagesViewController: MSMessagesAppViewController {
    private let state = MountainMessagesState()
    private var host: UIHostingController<MountainMessagesView>?
    private var session = MSSession()
    private var cacheKey = ""
    private var localIdentifier = ""

    override func viewDidLoad() {
        super.viewDidLoad()
        let controller = UIHostingController(rootView: MountainMessagesView(state: state))
        addChild(controller); view.addSubview(controller.view)
        controller.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            controller.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            controller.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            controller.view.topAnchor.constraint(equalTo: view.topAnchor),
            controller.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        controller.didMove(toParent: self); host = controller
        state.expand = { [weak self] in self?.requestPresentationStyle(.expanded) }
        state.stage = { [weak self] in self?.stage($0) }
        state.newRace = { [weak self] in self?.start() }
    }
    override func willBecomeActive(with conversation: MSConversation) { configure(conversation) }
    override func didSelect(_ message: MSMessage, conversation: MSConversation) { configure(conversation, message: message) }
    override func didTransition(to presentationStyle: MSMessagesAppPresentationStyle) { state.expanded = presentationStyle == .expanded }
    override func didReceive(_ message: MSMessage, conversation: MSConversation) { configure(conversation, message: message) }

    private func configure(_ conversation: MSConversation, message: MSMessage? = nil) {
        state.expanded = presentationStyle == .expanded
        localIdentifier = conversation.localParticipantIdentifier.uuidString
        state.twoPlayers = conversation.remoteParticipantIdentifiers.count == 1
        state.error = nil; state.busy = false; state.staged = false
        let incoming = message ?? conversation.selectedMessage
        guard state.twoPlayers else { state.challenge = nil; state.original = nil; return }
        guard let incoming else { start(); return }
        do {
            guard let url = incoming.url else { throw MountainMatchError.invalidData }
            var challenge = try MountainChallenge.decodeMessage(url)
            let players = [localIdentifier] + conversation.remoteParticipantIdentifiers.map(\.uuidString)
            guard players.contains(incoming.senderParticipantIdentifier.uuidString), challenge.rowPlayer == "messages-row",
                  challenge.columnPlayer == nil || challenge.columnPlayer == "messages-column",
                  let seat = challenge.messageSeat(senderIsLocal: incoming.senderParticipantIdentifier == conversation.localParticipantIdentifier) else { throw MountainMatchError.invalidData }
            state.player = seat == 0 ? "messages-row" : "messages-column"
            cacheKey = "messageRace.\(challenge.id).\(localIdentifier)"
            if let data = UserDefaults.standard.data(forKey: cacheKey), let cached = try? MountainChallenge.decode(data) {
                if cached.moves.count > challenge.moves.count {
                    guard cached.continues(challenge) else { throw MountainMatchError.invalidData }
                    challenge = cached
                } else { guard challenge.continues(cached) else { throw MountainMatchError.invalidData } }
            }
            UserDefaults.standard.set(try challenge.encoded(), forKey: cacheKey)
            state.challenge = challenge; state.original = challenge
            session = incoming.session ?? MSSession()
        } catch { state.challenge = nil; state.original = nil; state.error = error.localizedDescription }
    }
    private func start() {
        guard state.twoPlayers else { return }
        state.player = "messages-row"
        let challenge = MountainChallenge(size: 4, player: state.player)
        session = MSSession(); cacheKey = "messageRace.\(challenge.id).\(localIdentifier)"
        state.challenge = challenge; state.original = challenge; state.staged = false; state.error = nil
        requestPresentationStyle(.expanded)
    }
    private func stage(_ challenge: MountainChallenge) {
        guard !state.busy, !state.staged, let original = state.original,
              challenge.continues(original), challenge.moves.count == original.moves.count + 1,
              let conversation = activeConversation, conversation.remoteParticipantIdentifiers.count == 1 else { return }
        state.busy = true
        do {
            let message = MSMessage(session: session)
            let layout = MSMessageTemplateLayout()
            let card = MountainMessageCard(challenge: challenge)
            let renderer = ImageRenderer(content: card.frame(width: 600, height: 420))
            renderer.scale = 2
            layout.image = renderer.uiImage
            layout.caption = "Race to Dog Mountain"
            layout.subcaption = challenge.game.isOver ? "Finished · \(challenge.game.scores[0]) : \(challenge.game.scores[1])" : "Your move · \(challenge.game.scores[0]) : \(challenge.game.scores[1])"
            message.layout = layout; message.url = try challenge.messageURL()
            message.summaryText = challenge.game.isOver ? "The race is finished." : "Your turn on Dog Mountain."
            conversation.insert(message) { [weak self] failure in
                Task { @MainActor in
                    guard let self else { return }
                    self.state.busy = false
                    if let failure { self.state.error = failure.localizedDescription }
                    else { self.state.staged = true; self.requestPresentationStyle(.compact) }
                }
            }
        } catch { state.busy = false; state.error = error.localizedDescription }
    }
    override func didStartSending(_ message: MSMessage, conversation: MSConversation) {
        guard let url = message.url, let challenge = try? MountainChallenge.decodeMessage(url),
              let original = state.original, challenge.continues(original) else { return }
        UserDefaults.standard.set(try? challenge.encoded(), forKey: cacheKey)
        state.original = challenge; state.challenge = challenge; state.staged = false
    }
    override func didCancelSending(_ message: MSMessage, conversation: MSConversation) {
        state.challenge = state.original; state.staged = false; state.busy = false
    }
}

private struct MountainMessagesView: View {
    @Bindable var state: MountainMessagesState
    var body: some View {
        ZStack {
            MountainStyle.ink.ignoresSafeArea()
            if !state.twoPlayers {
                VStack(spacing: 16) {
                    Image(systemName: "person.2.fill").font(.largeTitle).foregroundStyle(MountainStyle.mint)
                    Text("Open a conversation with one friend to start a race.").multilineTextAlignment(.center)
                }.padding(24)
            } else if let challenge = state.challenge {
                VStack(spacing: 12) {
                    if state.expanded {
                        MountainChallengeBoard(challenge: challenge, names: state.names, canPlay: state.canMove, busy: state.busy, select: state.choose)
                    } else {
                        Text(state.staged ? "Tap Send to pass your move" : challenge.game.isOver ? "Race finished" : state.canMove ? "Your move" : "Waiting for your friend")
                            .font(.headline).padding(.top, 12)
                        Button { state.expand?() } label: { Label("Open board", systemImage: "square.grid.3x3.fill").frame(maxWidth: .infinity) }.buttonStyle(MountainButton(prominent: true))
                    }
                    if challenge.moves.count == (state.original?.moves.count ?? 0) + 1, !state.staged {
                        Button { state.stage?(challenge) } label: { Label("Add move to message", systemImage: "arrow.up.message.fill").frame(maxWidth: .infinity) }
                            .buttonStyle(MountainButton(prominent: true)).disabled(state.busy)
                        Button("Undo choice") { state.challenge = state.original }.frame(minHeight: 44).disabled(state.busy)
                    } else if challenge.game.isOver || (!state.canMove && !state.staged) {
                        Button("Start another race") { state.newRace?() }.frame(minHeight: 44)
                    }
                }.padding(.horizontal, 16).padding(.bottom, 12)
            } else {
                Button("Start a new race") { state.newRace?() }.buttonStyle(MountainButton(prominent: true))
            }
        }.foregroundStyle(MountainStyle.cream).tint(MountainStyle.gold).preferredColorScheme(.dark)
            .alert("Messages game", isPresented: Binding(get: { state.error != nil }, set: { if !$0 { state.error = nil } })) {
                Button("OK") { state.error = nil }
            } message: { Text(state.error ?? "") }
    }
}

private struct MountainMessageCard: View {
    let challenge: MountainChallenge
    var body: some View {
        ZStack {
            MountainScenery(active: false)
            MountainStyle.ink.opacity(0.6)
            HStack(spacing: 36) {
                VStack(alignment: .leading, spacing: 20) {
                    Image(systemName: "mountain.2.fill").font(.system(size: 48)).foregroundStyle(MountainStyle.gold)
                    Text("Dog\nMountain").font(.custom("Georgia-Bold", size: 44))
                    Text("\(challenge.game.scores[0]) : \(challenge.game.scores[1])").font(.title.bold()).monospacedDigit()
                }
                LazyVGrid(columns: Array(repeating: GridItem(.fixed(48), spacing: 6), count: challenge.size), spacing: 6) {
                    ForEach(challenge.game.tiles) { tile in
                        Text(tile.value == 0 ? "·" : "\(tile.value)").font(.title3.bold()).monospacedDigit()
                            .frame(width: 48, height: 48).foregroundStyle(MountainStyle.ink)
                            .background(tile.value == 0 ? MountainStyle.cream.opacity(0.15) : challenge.game.canPlay(tile.id) ? MountainStyle.player(challenge.game.turn) : MountainStyle.cream, in: RoundedRectangle(cornerRadius: 8))
                    }
                }
            }.padding(32)
        }.foregroundStyle(MountainStyle.cream)
    }
}
