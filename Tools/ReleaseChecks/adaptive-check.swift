import Foundation

struct SeededRandom: RandomNumberGenerator {
    var state: UInt64
    mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state
    }
}

@main enum AdaptiveChecks {
    @MainActor static func main() throws {
        for computers in [[false, true], [true, false], [true, true]] {
            assert(MountainGame.randomStartingPlayer(computers: computers, coin: 0) == 0)
            assert(MountainGame.randomStartingPlayer(computers: computers, coin: 1) == 1)
        }
        assert(MountainGame.randomStartingPlayer(computers: [false, false], coin: 1) == 0)
        for coin in [0, 1] {
            let match = SavedMountainGame(size: 4, names: ["A", "B"], computers: [false, true], difficulty: .level1, adjustment: 0, startingPlayer: coin)
            assert(match.game.turn == coin && match.computerStarted)
        }
        let humanOnly = SavedMountainGame(size: 4, names: ["A", "B"], computers: [false, false], difficulty: .level1, adjustment: 0, startingPlayer: 1)
        assert(humanOnly.game.turn == 0)
        let profileData = MountainHumanProfile.updating(identity: "A", displayName: "New look", symbol: "leaf.fill", data: Data())!
        assert(MountainHumanProfile.read(identity: "A", data: profileData).displayName == "New look")
        assert(MountainHumanProfile.read(identity: "B", data: profileData).displayName == "B")
        assert(MountainHumanProfile.updating(identity: "A", displayName: "", symbol: "bad-symbol", data: profileData) == nil)
        for (points, maximum, expected) in [(-1, 16, 0.0), (0, 0, 0), (8, 16, 0.5), (32, 16, 1)] {
            assert(MountainMoveFeedback(id: 1, tile: 0, player: 0, points: points, maximum: maximum).intensity == expected)
        }
        var learning = MountainLearning()
        assert(learning.difficulty == .level1 && learning.skill == 0 && learning.winRate == nil)
        for _ in 0..<3 { learning.record(.win) }
        assert(learning.skill == 0, "Minimum evidence before increasing")
        learning.record(.win)
        assert(learning.skill == 0.25 && learning.difficulty == .level1)
        for _ in 0..<9 { learning.record(.win) }
        assert(learning.skill == 1 && learning.difficulty == .level2, "Slow easy-start ramp")
        for _ in 0..<500 { learning.record(.win); assert(learning.isValid) }
        assert(learning.skill == 15 && learning.difficulty == .level16)
        let summit = learning.skill
        for _ in 0..<6 { learning.record(.loss) }
        assert(learning.skill < summit * 0.70, "Faster multiplicative recovery")
        let recovered = learning.skill
        for _ in 0..<6 { learning.record(.win) }
        assert(learning.skill <= recovered + 0.5, "Recovery cannot spring straight back")
        for _ in 0..<500 { learning.record(.loss); assert(learning.isValid) }
        assert(learning.skill == 0 || learning.skill < 0.0001)
        var alternating = MountainLearning()
        for n in 0..<240 { alternating.record(n.isMultiple(of: 2) ? .win : .loss) }
        assert(alternating.skill == 0 && alternating.recent.count == 12)
        var tied = MountainLearning()
        for _ in 0..<30 { tied.record(.tie) }
        assert(tied.skill == 0 && tied.winRate == nil)
        var target = MountainLearning()
        for _ in 0..<30 { for outcome: MountainLearning.Outcome in [.win, .win, .loss] { target.record(outcome) } }
        let settledTarget = target.skill
        for _ in 0..<30 { for outcome: MountainLearning.Outcome in [.win, .win, .loss] { target.record(outcome) } }
        assert(target.skill == settledTarget && target.difficulty == .level1, "Dead band stops ramp after short warm-up around 67%")

        var clustered = MountainLearning()
        for _ in 0..<24 {
            for _ in 0..<8 { clustered.record(.win) }
            for _ in 0..<2 { clustered.record(.loss) }
        }
        assert(clustered.skill >= 8, "An 80% winner ramps despite clustered losses")
        let beforeStruggle = clustered.skill
        for _ in 0..<9 { clustered.record(.loss) }
        assert(clustered.skill < beforeStruggle * 0.70, "Genuine sustained struggle recovers faster")

        let suite = "dog-mountain-adaptive-check-" + UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = MountainLearningStore(defaults: defaults)
        let key = MountainLearningStore.key(name: "A", size: 6, seat: 0)
        let context = store.begin(key: key)
        for _ in 0..<13 { assert(store.record(.win, gameID: UUID(), context: context)) }
        let prior = store.learning(for: key).skill
        assert(prior == 1)
        let roundTrip = MountainLearningStore(defaults: defaults)
        assert(roundTrip.learning(for: key).skill == prior)
        let id = UUID()
        assert(store.record(.loss, gameID: id, context: context))
        assert(!store.record(.loss, gameID: id, context: context), "Crash/reopen cannot double-train")
        for other in [MountainLearningStore.key(name: "B", size: 6, seat: 0), MountainLearningStore.key(name: "A", size: 4, seat: 0), MountainLearningStore.key(name: "A", size: 6, seat: 1)] {
            assert(store.learning(for: other).skill == 0)
        }
        store.reset(key: key)
        assert(store.learning(for: key).skill == 0)
        assert(!store.record(.win, gameID: UUID(), context: context), "Reset rejects stale games")
        assert(store.begin(key: key).generation != context.generation)
        _ = store.begin(key: key)
        assert(store.learning(for: key).skill == 0, "Starting or abandoning games does not train")

        // Distinct scene stores cannot overwrite newer progress or resurrect a reset generation.
        let sceneA = MountainLearningStore(defaults: defaults)
        let sceneB = MountainLearningStore(defaults: defaults)
        let ctxA = sceneA.begin(key: key), ctxB = sceneB.begin(key: key)
        assert(ctxA.generation == ctxB.generation)
        for n in 0..<13 { assert((n.isMultiple(of: 2) ? sceneA : sceneB).record(.win, gameID: UUID(), context: ctxA)) }
        assert(sceneA.learning(for: key).skill == 1 && sceneB.learning(for: key).skill == 1)
        sceneA.reset(key: key)
        assert(!sceneB.record(.win, gameID: UUID(), context: ctxB))
        assert(sceneB.learning(for: key).skill == 0 && sceneB.begin(key: key).generation != ctxB.generation)
        defaults.set(Data("corrupt-learning".utf8), forKey: "mountainLearning.v1")
        let repaired = sceneA.begin(key: key)
        assert(defaults.data(forKey: "mountainLearning.v1.recovery") == Data("corrupt-learning".utf8))
        assert(sceneA.learning(for: key).skill == 0)

        let hub = MountainDisplayHub()
        let snapshot = MountainDisplaySnapshot.design
        hub.claim(owner: snapshot.owner); hub.publish(snapshot); hub.connected("screen1"); hub.disconnected("screen1")
        assert(hub.snapshot?.game.moves == snapshot.game.moves && hub.connections.isEmpty)
        hub.connected("screen2")
        hub.clear(owner: UUID())
        assert(hub.snapshot?.owner == snapshot.owner, "An unrelated display cannot clear the primary game")
        let stale = MountainDisplaySnapshot(owner: snapshot.owner, game: MountainGame(size: 6, values: Array(1...36), startingLine: 2), names: snapshot.names, symbols: snapshot.symbols, computers: snapshot.computers, difficulty: snapshot.difficulty, lastMove: nil, lastPoints: 0, paused: false)
        hub.publish(stale)
        assert(hub.snapshot?.game.moves == snapshot.game.moves, "Ignore stale snapshots for the same game")
        let replacement = MountainDisplaySnapshot(owner: UUID(), game: stale.game, names: snapshot.names, symbols: snapshot.symbols, computers: snapshot.computers, difficulty: snapshot.difficulty, lastMove: nil, lastPoints: 0, paused: false)
        hub.claim(owner: replacement.owner); hub.publish(replacement)
        hub.publish(snapshot); hub.clear(owner: snapshot.owner)
        assert(hub.snapshot?.owner == replacement.owner, "Retired teardown cannot reclaim or clear a new game")
        hub.clear(owner: replacement.owner)
        assert(hub.snapshot == nil && hub.activeOwner == nil)
        hub.publish(replacement)
        assert(hub.snapshot == nil, "A released owner cannot publish without a new claim")
        let libraryA = MountainLibrary(defaults: defaults), libraryB = MountainLibrary(defaults: defaults)
        var firstGame = SavedMountainGame(size: 4, names: ["A", "B"], computers: [false, false], difficulty: .level1, adjustment: 0)
        let secondGame = SavedMountainGame(size: 4, names: ["C", "D"], computers: [false, false], difficulty: .level1, adjustment: 0)
        libraryA.save(firstGame); libraryB.save(secondGame)
        let staleGame = firstGame
        firstGame.game.play(firstGame.game.legalMoves[0]); libraryA.save(firstGame); libraryB.save(staleGame)
        let freshLibrary = MountainLibrary(defaults: defaults)
        assert(freshLibrary.games.count == 2 && freshLibrary.games.first(where: { $0.id == firstGame.id })?.game.moves == 1, "Interleaved saves preserve both games and newer moves")

        var saved = SavedMountainGame(size: 4, names: ["A", "B"], computers: [false, true], difficulty: .level1, adjustment: 0)
        saved.learning = repaired
        let data = try JSONEncoder().encode(saved)
        let restored = try JSONDecoder().decode(SavedMountainGame.self, from: data)
        assert(restored.learning?.generation == repaired.generation && restored.difficulty == .level1 && restored.isValid)
        var legacy = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        legacy.removeValue(forKey: "learning")
        let old = try JSONDecoder().decode(SavedMountainGame.self, from: JSONSerialization.data(withJSONObject: legacy))
        assert(old.learning == nil && old.isValid, "Old saved games decode unchanged")

        // Same seed covers board shuffle, starting line and every AI alternative, so simulations repeat exactly.
        let first = simulate(seed: 404, player: .level1)
        assert(first == simulate(seed: 404, player: .level1))
        let moderate = simulate(seed: 405, player: .level6)
        let expert = simulate(seed: 406, player: .level16)
        print("PASS: easy start, 13-win first full level, +0.25 / 3-game cadence, ×0.65 recovery, bounds, ties, dead band, persistence, deduplication, reset generations, multiple windows, corrupt-data recovery, distinct players/boards/roles, legacy saves, reproducible legal simulations.")
        print("Synthetic 120-game runs (win %, final fractional level): beginner \(first), moderate \(moderate), expert \(expert). These bots do not establish a human win rate.")
    }
    static func simulate(seed: UInt64, player: ComputerDifficulty) -> [Double] {
        var random = SeededRandom(state: seed)
        var learning = MountainLearning()
        var wins = 0
        for _ in 0..<120 {
            let size = 4
            let values = Array(1...(size * size)).shuffled(using: &random)
            var game = MountainGame(size: size, values: values, startingLine: Int.random(in: 0..<size, using: &random))
            let fixedOpponent = learning.difficulty
            let initial = game.tiles.map(\.value)
            while !game.isOver {
                let profile = game.turn == 0 ? player : fixedOpponent
                let before = game.moves
                guard let choice = game.computerMove(difficulty: profile, using: &random) else { preconditionFailure() }
                assert(game.moves == before && game.canPlay(choice), "AI chooses legal moves without mutating rules")
                assert(game.play(choice) && game.isValid)
            }
            assert(initial.reduce(0,+) == game.scores.reduce(0,+) + game.tiles.map(\.value).reduce(0,+))
            let outcome: MountainLearning.Outcome = game.scores[0] == game.scores[1] ? .tie : game.scores[0] > game.scores[1] ? .win : .loss
            if outcome == .win { wins += 1 }
            learning.record(outcome); assert(learning.isValid)
        }
        return [Double(wins) / 1.2, learning.skill]
    }
}
