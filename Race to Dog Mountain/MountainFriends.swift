import SwiftUI
import GameKit
#if os(macOS)
import AppKit
typealias MountainController = NSViewController
#else
import UIKit
typealias MountainController = UIViewController
#endif

struct MountainGameCenterSheet: Identifiable {
    let id = UUID()
    let controller: MountainController
}

@MainActor @Observable final class MountainFriends: NSObject, GKLocalPlayerListener, GKTurnBasedMatchmakerViewControllerDelegate {
    var matches: [FriendRace] = []
    var opened: FriendRace? {
        didSet { if opened == nil { pendingOpen = nil; navigationGeneration &+= 1 } }
    }
    var presentation: MountainGameCenterSheet?
    var error: String?
    private(set) var authenticated = false
    private(set) var authenticationResolved = false
    private(set) var loading = false
    private(set) var sending = false
    private var signingIn = false
    private var wantsMatch = false
    private var requestedSize = 6
    private var registeredPlayer: String?
    private var refreshAgain = false
    private var pendingOpen: String?
    private var navigationGeneration: UInt64 = 0
    private let defaults: UserDefaults
    private var cachedInbox: MountainFriendInbox?
#if os(iOS)
    @ObservationIgnored var inboxChanged: (() -> Void)?
#endif

    init(defaults: UserDefaults = MountainExperience.defaults) {
        self.defaults = defaults
        cachedInbox = defaults.data(forKey: "friendRaces.v1").flatMap { try? MountainFriendInbox.decode($0) }
        requestedSize = min(14, max(4, defaults.object(forKey: "complexity") as? Int ?? 6))
        super.init()
    }

    var active: [FriendRace] { matches.filter { !$0.ended }.sorted { $0.yourTurn != $1.yourTurn ? $0.yourTurn : $0.updated > $1.updated } }
    var finished: [FriendRace] { matches.filter(\.ended).sorted { $0.updated > $1.updated } }

    func resume() async {
        guard !MountainExperience.isQAActive else { return }
        if checkAuthentication() { await refresh() }
        else if MountainExperience.defaults.bool(forKey: "usedGameCenter") { authenticate() }
    }
    func invite(size: Int) {
        guard !MountainExperience.isQAActive else { return }
        requestedSize = min(14, max(4, size)); wantsMatch = true
        if checkAuthentication() { showMatchmaker() }
        else { authenticate() }
    }
    func authenticate() {
        guard !MountainExperience.isQAActive else { return }
        guard !signingIn else { return }
        signingIn = true; error = nil
        GKLocalPlayer.local.authenticateHandler = { [weak self] controller, failure in
            Task { @MainActor in
                guard let self else { return }
                if let controller { self.presentation = MountainGameCenterSheet(controller: controller); return }
                self.signingIn = false
                self.authenticationResolved = true
                if self.checkAuthentication() {
                    MountainExperience.defaults.set(true, forKey: "usedGameCenter")
                    await self.refresh()
                    if self.wantsMatch { self.showMatchmaker() }
                } else {
                    self.wantsMatch = false; self.matches = []; self.opened = nil
                    self.error = "Sign in to Game Center in Settings, then choose Play a friend."
                }
            }
        }
    }
    func presentationDismissed() {
        if !GKLocalPlayer.local.isAuthenticated { signingIn = false; wantsMatch = false }
    }
    private func showMatchmaker(players: [GKPlayer]? = nil) {
        wantsMatch = false
        let request = GKMatchRequest(); request.minPlayers = 2; request.maxPlayers = 2
        request.recipients = players
        let controller = GKTurnBasedMatchmakerViewController(matchRequest: request)
        controller.turnBasedMatchmakerDelegate = self
        controller.showExistingMatches = false
        presentation = MountainGameCenterSheet(controller: controller)
    }
    @discardableResult private func checkAuthentication() -> Bool {
        guard !MountainExperience.isQAActive else { return false }
        let local = GKLocalPlayer.local
        let player = local.isAuthenticated ? local.teamPlayerID : nil
        if player != nil || registeredPlayer != nil { authenticationResolved = true }
        if registeredPlayer != player {
            if registeredPlayer != nil { local.unregisterListener(self) }
            matches = player != nil && cachedInbox?.player == player ? cachedInbox!.matches : []
            opened = nil; pendingOpen = nil
            registeredPlayer = player
            if player != nil { local.register(self) }
        }
        authenticated = player != nil
#if os(iOS)
        inboxChanged?()
#endif
        return authenticated
    }
    private func cacheMatches() {
        guard let player = registeredPlayer else { return }
        let next = MountainFriendInbox(version: 1, sequence: (cachedInbox?.sequence ?? 0) + 1,
                                       player: player, matches: matches, updated: Date())
        guard let data = try? next.encoded() else { return }
        defaults.set(data, forKey: "friendRaces.v1"); cachedInbox = next
    }
    func refresh() async {
        guard !MountainExperience.isQAActive else { return }
        guard checkAuthentication() else { return }
        if loading { refreshAgain = true; return }
        loading = true
        defer {
            loading = false
            if refreshAgain { refreshAgain = false; Task { await refresh() } }
        }
        repeat {
            refreshAgain = false
            let player = GKLocalPlayer.local.teamPlayerID
            do {
                let loaded = try await GKTurnBasedMatch.loadMatches()
                var result: [FriendRace] = []
                for match in loaded {
                    if match.participants.count != 2 { continue }
                    do {
                        let data = try await match.loadMatchData()
                        result.append(try summary(match, data: data).preservingProgress(from: matches.first { $0.id == match.matchID }))
                    } catch {
                        // Retain the last valid board, but never offer a move from unreadable data.
                        var unavailable = try matches.first { $0.id == match.matchID } ?? summary(match, data: nil)
                        unavailable.problem = "Couldn't load this game. Refresh to try again."
                        result.append(unavailable)
                    }
                }
                guard checkAuthentication(), GKLocalPlayer.local.teamPlayerID == player else { refreshAgain = authenticated; return }
                // A move may have completed during another match's await. Merge again at publication.
                result = result.map { race in
                    race.preservingProgress(from: matches.first { $0.id == race.id } ?? (opened?.id == race.id ? opened : nil))
                }
                matches = result; error = nil
                cacheMatches()
                if !sending, let id = opened?.id, let current = result.first(where: { $0.id == id }) { opened = current }
#if os(iOS)
                inboxChanged?()
#endif
            } catch { self.error = "Couldn't refresh friend games. \(error.localizedDescription)" }
        } while refreshAgain && authenticated
    }
    private func summary(_ match: GKTurnBasedMatch, data: Data?) throws -> FriendRace {
        let challenge = try data.flatMap { $0.isEmpty ? nil : try MountainChallenge.decode($0) }
        let local = GKLocalPlayer.local.teamPlayerID
        let ids = match.participants.compactMap { $0.player?.teamPlayerID }
        guard match.participants.count == 2, ids.contains(local) else { throw MountainMatchError.invalidData }
        let abandoned = match.participants.contains { $0.status == .done || $0.status == .declined }
        let ended = match.status == .ended || abandoned
        if let challenge {
            guard ids.contains(challenge.rowPlayer), challenge.columnPlayer == nil || ids.contains(challenge.columnPlayer!),
                  ids.contains(local) else { throw MountainMatchError.invalidData }
            if !ended, let current = match.currentParticipant?.player?.teamPlayerID {
                guard challenge.seat(for: current) == challenge.game.turn else { throw MountainMatchError.changedTurn }
            }
        }
        let opponent = match.participants.compactMap(\.player).first { $0.teamPlayerID != local }
        let row = challenge.flatMap { c in match.participants.compactMap(\.player).first { $0.teamPlayerID == c.rowPlayer } }
        let names = challenge == nil ? [GKLocalPlayer.local.displayName, opponent?.displayName ?? "Friend"] :
            [row?.displayName ?? "Friend", challenge!.rowPlayer == local ? opponent?.displayName ?? "Friend" : GKLocalPlayer.local.displayName]
        return FriendRace(id: match.matchID, title: opponent?.displayName ?? "Finding a friend", names: names,
                          challenge: challenge, yourTurn: !ended && match.currentParticipant?.player?.teamPlayerID == local,
                          ended: ended, updated: match.participants.compactMap(\.lastTurnDate).max() ?? match.creationDate,
                          problem: abandoned && match.status != .ended ? "A player left this game. Start a new friend game." : nil)
    }
    func open(_ id: String) async {
        guard checkAuthentication() else { error = "Sign in to Game Center to open friend games."; return }
        if sending { pendingOpen = id; return }
        let navigation = navigationGeneration
        sending = true; defer { finishOperation() }
        do {
            let player = GKLocalPlayer.local.teamPlayerID
            let race = try await loadRace(id)
            guard checkAuthentication(), GKLocalPlayer.local.teamPlayerID == player else { throw MountainMatchError.unavailable }
            let retained = remember(race)
            if navigationGeneration == navigation && pendingOpen == nil { opened = retained }
            error = nil; await refresh()
        } catch { self.error = error.localizedDescription }
    }
    private func loadRace(_ id: String) async throws -> FriendRace {
        let player = GKLocalPlayer.local.teamPlayerID
        var match = try await GKTurnBasedMatch.load(withID: id)
        guard GKLocalPlayer.local.isAuthenticated, GKLocalPlayer.local.teamPlayerID == player else { throw MountainMatchError.unavailable }
        if match.participants.first(where: { $0.player?.teamPlayerID == player })?.status == .invited {
            match = try await match.acceptInvite()
        }
        var data = try await match.loadMatchData()
        guard GKLocalPlayer.local.isAuthenticated, GKLocalPlayer.local.teamPlayerID == player else { throw MountainMatchError.unavailable }
        if data == nil || data!.isEmpty {
            if match.participants.contains(where: { $0.status == .done || $0.status == .declined }) { return try summary(match, data: data) }
            guard match.status != .ended, match.currentParticipant?.player?.teamPlayerID == player else { throw MountainMatchError.unavailable }
            data = try MountainChallenge(size: requestedSize, player: player).encoded()
            try await match.saveCurrentTurn(withMatch: data!)
        }
        return try summary(match, data: data)
    }
    private func finishOperation() {
        sending = false
        if let id = pendingOpen {
            pendingOpen = nil
            let navigation = navigationGeneration
            Task { if navigationGeneration == navigation { await open(id) } }
        } else { Task { await refresh() } }
    }
    @discardableResult private func remember(_ race: FriendRace) -> FriendRace {
        let retained = race.preservingProgress(from: matches.first { $0.id == race.id } ?? (opened?.id == race.id ? opened : nil))
        if let index = matches.firstIndex(where: { $0.id == retained.id }) { matches[index] = retained }
        else { matches.append(retained) }
        cacheMatches()
        return retained
    }
    func loadForWatch(_ id: String) async throws {
        guard checkAuthentication(), !sending else { throw MountainMatchError.unavailable }
        sending = true; defer { finishOperation() }
        let player = GKLocalPlayer.local.teamPlayerID
        let race = try await loadRace(id)
        guard checkAuthentication(), GKLocalPlayer.local.teamPlayerID == player else { throw MountainMatchError.unavailable }
        remember(race)
        await refresh()
    }
    func play(_ tile: Int) async {
        guard let race = opened, let previous = race.challenge, !sending else { return }
        do {
            _ = try await commit(MountainMoveRequest(id: UUID(), matchID: race.id, previous: previous, tile: tile))
        } catch { self.error = error.localizedDescription; await refresh() }
    }
    // Shared by the visible board and the paired Watch. The request never selects a UI game.
    @discardableResult func commit(_ request: MountainMoveRequest) async throws -> FriendRace {
        guard checkAuthentication(), !sending, request.isValid else { throw MountainMatchError.unavailable }
        let player = GKLocalPlayer.local.teamPlayerID
        sending = true; defer { finishOperation() }
        let match = try await GKTurnBasedMatch.load(withID: request.matchID)
        guard match.status != .ended, match.currentParticipant?.player?.teamPlayerID == GKLocalPlayer.local.teamPlayerID,
              let data = try await match.loadMatchData() else { throw MountainMatchError.changedTurn }
        let current = try summary(match, data: data)
        guard !current.ended else { throw MountainMatchError.unavailable }
        let next = try request.applying(to: MountainChallenge.decode(data), player: player)
        let encoded = try next.encoded()
        guard GKLocalPlayer.local.isAuthenticated, GKLocalPlayer.local.teamPlayerID == player else { throw MountainMatchError.unavailable }
        if next.game.isOver {
            for participant in match.participants {
                let seat = participant.player?.teamPlayerID == next.rowPlayer ? 0 : 1
                participant.matchOutcome = next.game.scores[0] == next.game.scores[1] ? .tied :
                    next.game.scores[seat] > next.game.scores[1 - seat] ? .won : .lost
            }
            try await match.endMatchInTurn(withMatch: encoded)
        } else {
            let others = match.participants.filter { $0.player?.teamPlayerID != GKLocalPlayer.local.teamPlayerID }
            guard others.count == 1 else { throw MountainMatchError.invalidData }
            try await match.endTurn(withNextParticipants: others, turnTimeout: GKTurnTimeoutNone, match: encoded)
        }
        guard checkAuthentication(), GKLocalPlayer.local.teamPlayerID == player else { throw MountainMatchError.unavailable }
        let saved = FriendRace(id: current.id, title: current.title, names: current.names, challenge: next,
                               yourTurn: false, ended: next.game.isOver, updated: Date())
        let retained = remember(saved)
        if opened?.id == retained.id { opened = retained }
        error = nil; await refresh()
        return retained
    }
    func rematch() async {
        guard checkAuthentication(), let race = opened, race.ended, race.problem == nil, !sending else { return }
        let navigation = navigationGeneration
        let player = GKLocalPlayer.local.teamPlayerID
        sending = true; defer { finishOperation() }
        do {
            let match = try await GKTurnBasedMatch.load(withID: race.id)
            guard GKLocalPlayer.local.isAuthenticated, GKLocalPlayer.local.teamPlayerID == player else { throw MountainMatchError.unavailable }
            let next = try await match.rematch()
            guard GKLocalPlayer.local.isAuthenticated, GKLocalPlayer.local.teamPlayerID == player else { throw MountainMatchError.unavailable }
            let new = try await loadRace(next.matchID)
            guard checkAuthentication(), GKLocalPlayer.local.teamPlayerID == player else { throw MountainMatchError.unavailable }
            let retained = remember(new)
            if navigationGeneration == navigation && opened?.id == race.id { opened = retained }
            await refresh()
        } catch { self.error = error.localizedDescription }
    }
    nonisolated func player(_ player: GKPlayer, receivedTurnEventFor match: GKTurnBasedMatch, didBecomeActive: Bool) {
        Task { @MainActor in
            if didBecomeActive { presentation = nil; await open(match.matchID) }
            else { await refresh() }
        }
    }
    nonisolated func player(_ player: GKPlayer, matchEnded match: GKTurnBasedMatch) {
        Task { @MainActor in await refresh() }
    }
    nonisolated func player(_ player: GKPlayer, didRequestMatchWithRecipients recipientPlayers: [GKPlayer]) {
        Task { @MainActor in showMatchmaker(players: recipientPlayers) }
    }
    nonisolated func turnBasedMatchmakerViewControllerWasCancelled(_ viewController: GKTurnBasedMatchmakerViewController) {
        Task { @MainActor in presentation = nil; await refresh() }
    }
    nonisolated func turnBasedMatchmakerViewController(_ viewController: GKTurnBasedMatchmakerViewController, didFailWithError failure: Error) {
        Task { @MainActor in presentation = nil; error = failure.localizedDescription }
    }
}

#if os(macOS)
struct MountainGameCenterPresenter: NSViewControllerRepresentable {
    let controller: NSViewController
    func makeNSViewController(context: Context) -> NSViewController { controller }
    func updateNSViewController(_ controller: NSViewController, context: Context) {}
}
#else
struct MountainGameCenterPresenter: UIViewControllerRepresentable {
    let controller: UIViewController
    func makeUIViewController(context: Context) -> UIViewController { controller }
    func updateUIViewController(_ controller: UIViewController, context: Context) {}
}
#endif
