import SwiftUI
import GameKit
#if os(macOS)
import AppKit
typealias MountainController = NSViewController
#else
import UIKit
typealias MountainController = UIViewController
#endif

struct FriendRace: Identifiable {
    let id: String
    let title: String
    let names: [String]
    let challenge: MountainChallenge?
    let yourTurn: Bool
    let ended: Bool
    let updated: Date
}

struct MountainGameCenterSheet: Identifiable {
    let id = UUID()
    let controller: MountainController
}

@MainActor @Observable final class MountainFriends: NSObject, GKLocalPlayerListener, GKTurnBasedMatchmakerViewControllerDelegate {
    var matches: [FriendRace] = []
    var opened: FriendRace?
    var presentation: MountainGameCenterSheet?
    var error: String?
    private(set) var authenticated = false
    private(set) var loading = false
    private(set) var sending = false
    private var signingIn = false
    private var wantsMatch = false
    private var requestedSize = 6

    var active: [FriendRace] { matches.filter { !$0.ended }.sorted { $0.yourTurn != $1.yourTurn ? $0.yourTurn : $0.updated > $1.updated } }
    var finished: [FriendRace] { matches.filter(\.ended).sorted { $0.updated > $1.updated } }

    func resume() async {
        if GKLocalPlayer.local.isAuthenticated { authenticated = true; GKLocalPlayer.local.register(self); await refresh() }
        else if UserDefaults.standard.bool(forKey: "usedGameCenter") { authenticate() }
    }
    func invite(size: Int) {
        requestedSize = min(14, max(4, size)); wantsMatch = true
        if GKLocalPlayer.local.isAuthenticated { authenticated = true; GKLocalPlayer.local.register(self); showMatchmaker() }
        else { authenticate() }
    }
    func authenticate() {
        guard !signingIn else { return }
        signingIn = true; error = nil
        GKLocalPlayer.local.authenticateHandler = { [weak self] controller, failure in
            Task { @MainActor in
                guard let self else { return }
                if let controller { self.presentation = MountainGameCenterSheet(controller: controller); return }
                self.signingIn = false
                self.authenticated = GKLocalPlayer.local.isAuthenticated
                if self.authenticated {
                    UserDefaults.standard.set(true, forKey: "usedGameCenter")
                    GKLocalPlayer.local.register(self)
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
    func refresh() async {
        guard authenticated, !loading else { return }
        loading = true; defer { loading = false }
        do {
            let loaded = try await GKTurnBasedMatch.loadMatches()
            var result: [FriendRace] = []
            for match in loaded {
                if match.participants.count != 2 { continue }
                do {
                    let data = try await match.loadMatchData()
                    result.append(try summary(match, data: data))
                } catch {
                    // One unreadable match must not hide the other friends' games.
                    result.append(try summary(match, data: nil))
                }
            }
            matches = result; error = nil
        } catch { self.error = "Couldn't refresh friend games. \(error.localizedDescription)" }
    }
    private func summary(_ match: GKTurnBasedMatch, data: Data?) throws -> FriendRace {
        let challenge = try data.flatMap { $0.isEmpty ? nil : try MountainChallenge.decode($0) }
        let local = GKLocalPlayer.local.teamPlayerID
        if let challenge {
            let ids = match.participants.compactMap { $0.player?.teamPlayerID }
            guard ids.contains(challenge.rowPlayer), challenge.columnPlayer == nil || ids.contains(challenge.columnPlayer!),
                  ids.contains(local) else { throw MountainMatchError.invalidData }
            if match.status != .ended, let current = match.currentParticipant?.player?.teamPlayerID {
                guard challenge.seat(for: current) == challenge.game.turn else { throw MountainMatchError.changedTurn }
            }
        }
        let opponent = match.participants.compactMap(\.player).first { $0.teamPlayerID != local }
        let row = challenge.flatMap { c in match.participants.compactMap(\.player).first { $0.teamPlayerID == c.rowPlayer } }
        let names = challenge == nil ? [GKLocalPlayer.local.displayName, opponent?.displayName ?? "Friend"] :
            [row?.displayName ?? "Friend", challenge!.rowPlayer == local ? opponent?.displayName ?? "Friend" : GKLocalPlayer.local.displayName]
        return FriendRace(id: match.matchID, title: opponent?.displayName ?? "Finding a friend", names: names,
                          challenge: challenge, yourTurn: match.currentParticipant?.player?.teamPlayerID == local,
                          ended: match.status == .ended, updated: match.participants.compactMap(\.lastTurnDate).max() ?? match.creationDate)
    }
    func open(_ id: String) async {
        guard !sending else { return }
        sending = true; defer { sending = false }
        do {
            var match = try await GKTurnBasedMatch.load(withID: id)
            if match.participants.first(where: { $0.player?.teamPlayerID == GKLocalPlayer.local.teamPlayerID })?.status == .invited {
                match = try await match.acceptInvite()
            }
            var data = try await match.loadMatchData()
            if data == nil || data!.isEmpty {
                guard match.status != .ended, match.currentParticipant?.player?.teamPlayerID == GKLocalPlayer.local.teamPlayerID else { throw MountainMatchError.unavailable }
                data = try MountainChallenge(size: requestedSize, player: GKLocalPlayer.local.teamPlayerID).encoded()
                try await match.saveCurrentTurn(withMatch: data!)
            }
            opened = try summary(match, data: data)
            error = nil; await refresh()
        } catch { self.error = error.localizedDescription }
    }
    func play(_ tile: Int) async {
        guard let race = opened, let previous = race.challenge, !sending else { return }
        sending = true; defer { sending = false }
        do {
            let match = try await GKTurnBasedMatch.load(withID: race.id)
            guard match.status != .ended, match.currentParticipant?.player?.teamPlayerID == GKLocalPlayer.local.teamPlayerID,
                  let data = try await match.loadMatchData() else { throw MountainMatchError.changedTurn }
            var next = try MountainChallenge.decode(data)
            _ = try summary(match, data: data)
            guard next.continues(previous), next.moves.count == previous.moves.count,
                  next.play(tile, player: GKLocalPlayer.local.teamPlayerID) else { throw MountainMatchError.changedTurn }
            let encoded = try next.encoded()
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
            opened = FriendRace(id: race.id, title: race.title, names: race.names, challenge: next,
                                yourTurn: false, ended: next.game.isOver, updated: Date())
            error = nil; await refresh()
        } catch { self.error = error.localizedDescription }
    }
    func rematch() async {
        guard let race = opened, race.ended, !sending else { return }
        do {
            let match = try await GKTurnBasedMatch.load(withID: race.id)
            let next = try await match.rematch()
            await open(next.matchID)
        } catch { self.error = error.localizedDescription }
    }
    nonisolated func player(_ player: GKPlayer, receivedTurnEventFor match: GKTurnBasedMatch, didBecomeActive: Bool) {
        Task { @MainActor in
            if didBecomeActive { presentation = nil; await open(match.matchID) }
            else { await refresh(); if opened?.id == match.matchID { await open(match.matchID) } }
        }
    }
    nonisolated func player(_ player: GKPlayer, matchEnded match: GKTurnBasedMatch) {
        Task { @MainActor in await refresh(); if opened?.id == match.matchID { await open(match.matchID) } }
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
