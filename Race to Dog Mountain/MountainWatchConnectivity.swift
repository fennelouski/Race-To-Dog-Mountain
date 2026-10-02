#if os(iOS) || os(watchOS)
import Foundation
import Observation
import WatchConnectivity
#if os(iOS)
import GameKit

// AppDelegate activates the relay before a scene exists. Home observes this same service.
@objc(MountainPhoneCoordinator) @MainActor public final class MountainPhoneCoordinator: NSObject {
    static let shared = MountainPhoneCoordinator()
    let friends = MountainFriends()
    private var bridge: MountainPhoneBridge?

    private override init() {
        super.init()
        bridge = MountainPhoneBridge(friends: friends)
    }
    @objc public static func activate() { _ = shared }
}

// Game Center remains authoritative. WatchConnectivity only carries requests and saved snapshots.
@MainActor final class MountainPhoneBridge: NSObject, WCSessionDelegate {
    private let friends: MountainFriends
    private let defaults: UserDefaults
    private var inbox: MountainFriendInbox?
    private var receipts: [MountainWatchReceipt]
    private var publishedSequence: UInt64 = 0

    init(friends: MountainFriends, defaults: UserDefaults = .standard) {
        self.friends = friends; self.defaults = defaults
        inbox = defaults.data(forKey: "watchFriendInbox.v1").flatMap { try? MountainFriendInbox.decode($0) }
        receipts = defaults.data(forKey: "watchMoveReceipts.v1").flatMap { data in
            data.count <= 4_194_304 ? try? JSONDecoder().decode([MountainWatchReceipt].self, from: data) : nil
        } ?? []
        receipts = Array(receipts.filter { $0.move.isValid }.suffix(64))
        super.init()
        friends.inboxChanged = { [weak self] in self?.publish() }
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }
    private func snapshot() -> MountainFriendInbox {
        // A cold GameKit instance isn't proof of sign-out. Keep the last saved inbox until auth resolves.
        if !friends.authenticationResolved, let inbox { return inbox }
        let local = GKLocalPlayer.local
        let player = local.isAuthenticated && friends.authenticated ? local.teamPlayerID : nil
        let matches = player == nil ? [] : friends.matches
        if let inbox, inbox.player == player, inbox.matches == matches { return inbox }
        let prior = max(inbox?.sequence ?? 0, defaults.object(forKey: "watchInboxSequence.v1") as? UInt64 ?? 0)
        let next = MountainFriendInbox(version: 1, sequence: prior + 1, player: player, matches: matches, updated: Date())
        defaults.set(next.sequence, forKey: "watchInboxSequence.v1")
        if let data = try? next.encoded() { defaults.set(data, forKey: "watchFriendInbox.v1") }
        inbox = next
        return next
    }
    private func publish(force: Bool = false) {
        let current = snapshot()
        guard force || publishedSequence != current.sequence else { return }
        guard WCSession.isSupported(), WCSession.default.activationState == .activated,
              WCSession.default.isPaired, WCSession.default.isWatchAppInstalled,
              let data = try? current.encoded() else { return }
        do {
            if data.count <= 55_000 {
                try WCSession.default.updateApplicationContext(["mountainInbox": data])
            } else {
                // A large multi-game inbox uses a file, rather than silently dropping games.
                let url = FileManager.default.temporaryDirectory.appendingPathComponent("mountain-inbox-\(UUID()).json")
                try data.write(to: url, options: .atomic)
                WCSession.default.transferFile(url, metadata: ["mountainInbox": true])
            }
            publishedSequence = current.sequence
        } catch { /* A reachable Watch can explicitly refresh; its existing snapshot stays intact. */ }
    }
    private func handle(_ data: Data) async -> Data {
        var requestID = UUID()
        var accepted = false
        var failure: String?
        do {
            let request = try MountainWatchRequest.decode(data)
            requestID = request.id
            if let move = request.move {
                guard GKLocalPlayer.local.isAuthenticated else { throw MountainMatchError.unavailable }
                let player = GKLocalPlayer.local.teamPlayerID
                if let receipt = receipts.first(where: { $0.move.id == request.id && $0.player == player }) {
                    guard receipt.move == move else { throw MountainMatchError.invalidData }
                } else {
                    _ = try await friends.commit(move)
                    receipts.append(MountainWatchReceipt(player: player, move: move))
                    receipts = Array(receipts.suffix(64))
                    defaults.set(try JSONEncoder().encode(receipts), forKey: "watchMoveReceipts.v1")
                }
                accepted = true
            }
            if let id = request.matchID { try await friends.loadForWatch(id) }
            await friends.refresh()
            if !friends.authenticated && !accepted { failure = "Open Race on your paired iPhone and sign in to Game Center." }
        } catch { failure = String(error.localizedDescription.prefix(1_024)) }
        let current = snapshot()
        publish(force: true)
        let inline = (try? current.encoded().count) ?? Int.max
        let reply = MountainWatchReply(requestID: requestID, accepted: accepted, sequence: current.sequence,
                                      inbox: inline <= 55_000 ? current : nil, error: failure)
        return (try? JSONEncoder().encode(reply)) ?? Data()
    }
    nonisolated func session(_ session: WCSession, activationDidCompleteWith state: WCSessionActivationState, error: Error?) {
        Task { @MainActor in publish() }
    }
    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}
    nonisolated func sessionDidDeactivate(_ session: WCSession) { session.activate() }
    nonisolated func session(_ session: WCSession, didReceiveMessageData messageData: Data, replyHandler: @escaping (Data) -> Void) {
        Task { @MainActor in replyHandler(await handle(messageData)) }
    }
    nonisolated func session(_ session: WCSession, didFinish fileTransfer: WCSessionFileTransfer, error: Error?) {
        if fileTransfer.file.metadata?["mountainInbox"] as? Bool == true {
            try? FileManager.default.removeItem(at: fileTransfer.file.fileURL)
        }
    }
}
#else
@MainActor @Observable final class MountainWatchFriends: NSObject, WCSessionDelegate {
    private(set) var inbox: MountainFriendInbox?
    private(set) var reachable = false
    private(set) var sending = false
    private(set) var awaitingSnapshot = false
    var error: String?
    private let defaults: UserDefaults
    private var pending: MountainWatchRequest?
    private var awaitedSequence: UInt64 = 0
    private var activated = false

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        inbox = defaults.data(forKey: "watchFriendInbox.v1").flatMap { try? MountainFriendInbox.decode($0) }
        super.init()
    }
    var active: [FriendRace] {
        (inbox?.matches ?? []).filter { !$0.ended }.sorted { $0.yourTurn != $1.yourTurn ? $0.yourTurn : $0.updated > $1.updated }
    }
    var finished: [FriendRace] { (inbox?.matches ?? []).filter(\.ended).sorted { $0.updated > $1.updated } }
    var canMove: Bool { reachable && inbox?.player != nil && !sending && !awaitingSnapshot }

    func activate() {
        guard !activated, WCSession.isSupported() else { return }
        activated = true
        WCSession.default.delegate = self
        WCSession.default.activate()
    }
    func refresh() { send(MountainWatchRequest(version: 1, id: UUID(), move: nil)) }
    func open(_ id: String) { send(MountainWatchRequest(version: 1, id: UUID(), move: nil, matchID: id)) }
    func play(_ tile: Int, in race: FriendRace) {
        guard canMove, race.yourTurn, !race.ended, race.problem == nil, let previous = race.challenge else { return }
        let id = UUID()
        send(MountainWatchRequest(version: 1, id: id,
                                 move: MountainMoveRequest(id: id, matchID: race.id, previous: previous, tile: tile)))
    }
    private func send(_ request: MountainWatchRequest) {
        guard !sending else { return }
        reachable = WCSession.default.activationState == .activated && WCSession.default.isReachable
        guard reachable else { error = "Connect to your paired iPhone to refresh or send a move."; return }
        guard let data = try? JSONEncoder().encode(request) else { return }
        pending = request; sending = true; error = nil
        WCSession.default.sendMessageData(data, replyHandler: { [weak self] data in
            Task { @MainActor in self?.receiveReply(data, for: request) }
        }, errorHandler: { [weak self] failure in
            Task { @MainActor in
                guard let self, self.pending?.id == request.id else { return }
                self.pending = nil; self.sending = false
                self.error = "Couldn't confirm the move or refresh. Refresh before trying again. \(failure.localizedDescription)"
            }
        })
    }
    private func receiveReply(_ data: Data, for request: MountainWatchRequest) {
        guard pending?.id == request.id else { return }
        pending = nil; sending = false
        guard data.count <= 60_000, let reply = try? JSONDecoder().decode(MountainWatchReply.self, from: data),
              reply.acknowledges(request) else { error = "Couldn't confirm the response. Refresh to try again."; return }
        if let snapshot = reply.inbox { receive(snapshot) }
        awaitedSequence = reply.sequence
        awaitingSnapshot = (inbox?.sequence ?? 0) < reply.sequence
        error = reply.error
        // Accepted moves are displayed only when the canonical phone snapshot arrives.
        if request.move != nil && !reply.accepted && error == nil { error = "The move wasn't saved. Refresh to try again." }
    }
    private func receive(_ next: MountainFriendInbox) {
        guard next.replaces(inbox) else { return }
        inbox = next
        if let data = try? next.encoded() { defaults.set(data, forKey: "watchFriendInbox.v1") }
        if next.sequence >= awaitedSequence { awaitingSnapshot = false }
    }
    nonisolated func session(_ session: WCSession, activationDidCompleteWith state: WCSessionActivationState, error: Error?) {
        let data = session.receivedApplicationContext["mountainInbox"] as? Data
        let connected = session.isReachable
        Task { @MainActor in
            reachable = connected
            if let data, let next = try? MountainFriendInbox.decode(data) { receive(next) }
            if connected { refresh() }
        }
    }
    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        let connected = session.isReachable
        Task { @MainActor in reachable = connected; if connected { refresh() } }
    }
    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        guard let data = applicationContext["mountainInbox"] as? Data, let next = try? MountainFriendInbox.decode(data) else { return }
        Task { @MainActor in receive(next) }
    }
    nonisolated func session(_ session: WCSession, didReceive file: WCSessionFile) {
        // Copy/decode before the delegate returns: WatchConnectivity owns the temporary file.
        guard file.metadata?["mountainInbox"] as? Bool == true,
              let size = try? file.fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize, size <= 4_194_304,
              let data = try? Data(contentsOf: file.fileURL), let next = try? MountainFriendInbox.decode(data) else { return }
        Task { @MainActor in receive(next) }
    }
}
#endif
#endif
