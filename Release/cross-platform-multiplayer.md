# Cross-platform multiplayer readiness

Source work on 2 October 2026 starts from `06e0703e5cd44f9419057edfe6125bf208c83137`. This record covers the multiplayer changes in the accompanying local commit. It is not a release or proof of live Game Center delivery.

## Implemented behavior

iPhone, iPad, Mac and Vision Pro use the existing two-player Game Center turn-based matches and version-1 `MountainChallenge` transcript. Game Center retains the board between sessions. Turn events refresh the board while players are online, so the same match supports playing together or returning later. The app keeps several independent matches in its inbox. It does not introduce a separate real-time service.

The Watch friend inbox uses WatchConnectivity through the paired iPhone. The phone derives the actor from its authenticated Game Center player, reloads the requested match and current participant, validates the exact prior transcript and legal tile, then saves the turn or result to Game Center. The Watch displays the resulting canonical snapshot. It never applies a move optimistically. A cached inbox remains readable when the phone is unreachable; sending a move requires the phone connection. Invitations and rematches start on the other platforms. Local Watch computer games remain independent and phone-free.

This bridge preserves existing `teamPlayerID` identities. The installed watchOS 26.5 GameKit headers mark `teamPlayerID`, `gamePlayerID` and native matchmaker controllers unavailable on watchOS, although turn-based match APIs themselves exist there. No deprecated player-ID or alias substitution is used.

Snapshots are validated, account-scoped and sequenced across phone launches. Application context delivers ordinary inboxes; large inboxes use a WatchConnectivity file rather than dropping games. The phone persists the latest 64 successful move receipts by request UUID and account. Older/replayed commands still face the authoritative transcript-count check. Replies must match the outstanding request ID; older snapshots cannot replace newer ones or open another game.

The native service registers each listener once, coalesces overlapping refreshes and merges loaded boards with the latest known history at publication. Opening, committing or rematching also preserves known progress before publishing. Transient failures keep the last valid board. Unreadable boards disable moves. Departed or declined participants are shown as ended races with a reason rather than a playable blank board. Dismissing a native game cancels pending navigation, while an already requested move may still be saved to its own match.

The iOS AppDelegate activates the one shared relay before a scene exists. Activation does not authenticate Game Center. After a cold background launch, a Watch request may need the user to open the paired iPhone app and complete the existing native sign-in. Background authentication and hardware delivery have not been verified.

## Local verification

The existing `bash Tools/ReleaseChecks/run.sh` passes the actual Classic rules, computer-turn gates, Watch local saves, social transcript validation and independent local saves. Its extended social check covers authoritative Watch move application, stale/duplicate command rejection, reply IDs, multi-game inbox and receipt reload in an isolated defaults suite, older snapshot rejection, unreadable-board retention and completed-outcome retention. That social check removes its own defaults domain; the runner removes its temporary executables. It does not instantiate Game Center or exercise a network.

Native builds use the existing project and schemes, Debug configuration, a generic device destination, two jobs and `CODE_SIGNING_ALLOWED=NO`:

```sh
xcodebuild -project 'Race to Dog Mountain.xcodeproj' -scheme 'Race to Dog Mountain' -configuration Debug -destination 'generic/platform=iOS' -derivedDataPath /tmp/RaceMultiplayerIOSDD -jobs 2 CODE_SIGNING_ALLOWED=NO build
xcodebuild -project 'Race to Dog Mountain.xcodeproj' -scheme 'Race to Dog Mountain Watch' -configuration Debug -destination 'generic/platform=watchOS' -derivedDataPath /tmp/RaceMultiplayerWatchDD -jobs 2 CODE_SIGNING_ALLOWED=NO build
xcodebuild -project 'Race to Dog Mountain.xcodeproj' -scheme 'Race to Dog Mountain Mac' -configuration Debug -destination 'generic/platform=macOS' -derivedDataPath /tmp/RaceMultiplayerMacDD -jobs 2 CODE_SIGNING_ALLOWED=NO build
xcodebuild -project 'Race to Dog Mountain.xcodeproj' -scheme 'Race to Dog Mountain Vision' -configuration Debug -destination 'generic/platform=visionOS' -derivedDataPath /tmp/RaceMultiplayerVisionDD -jobs 2 CODE_SIGNING_ALLOWED=NO build
```

Final results are:

| Check | Result | Log |
| --- | --- | --- |
| Existing rules, turn, Watch and extended social checks | PASS, exit 0 | `/tmp/race-multiplayer-check.log` |
| iOS, including embedded Watch and Messages targets | PASS, exit 0 | `/tmp/race-multiplayer-ios-build.log` |
| Standalone Watch scheme | PASS, exit 0 | `/tmp/race-multiplayer-watch-build.log` |
| macOS | PASS, exit 0 | `/tmp/race-multiplayer-mac-build.log` |
| visionOS | PASS, exit 0 | `/tmp/race-multiplayer-vision-build.log` |

The final service SHA-256 is `b669225781eac298342ea5f0dfc22f21956be5c5b850ec506010731633eaa483`, shared protocol `4d0ce38ef8eb64490cb79a77bb29927c633943231088b2e25ce269bd22d8f406`, and relay `88be85ce4d76ee839af546908f7636bed527eb3265fd9e688e6774ecadefb46b`. The original rules, local Watch model and gallery manifest are unchanged. These are compiler/rule checks, not signed-distribution, account, layout or delivery verification. No app was launched, Simulator was controlled, invitation was sent, account was changed, or App Store setting was edited in this pass.

## App Store and device verification still required

The last recorded App Store state is the 1 October [2.1 (8) submission record](submission-2.1-8.md), not a fresh account query. It records Mac and Vision compatibility with each other, iOS compatibility with only iOS, an unresolved iOS entitlement-validation conflict and missing required Messages gallery evidence. Those external blockers remain unverified. Existing main/Mac/Vision Game Center entitlements and bundle IDs are retained. Watch uses its existing companion bundle relationship and WatchConnectivity, with no new direct Watch Game Center identity.

Before claiming released cross-platform multiplayer, verify the same signed revision across the platform compatibility table and the real two-account service. Exercise simultaneous independent races, online turn events, interruption/relaunch, stale turns, repeat UUID delivery, lost acknowledgements, sign-out/account changes, declined invitations, departures and rematches. Verify the Watch relay on a physical paired phone/Watch, including offline read-only behavior, large-inbox delivery and the cold authentication limitation. Confirm a late response never navigates or overwrites another selected game. No new server, account configuration or release action was performed here.

The existing `Marketing/Social/manifest.json` and native source captures are preserved. They document older real phone, tablet, Mac, Vision and Watch images; the Watch image shows local play. They do not prove the new Watch inbox or relay. New native captures, a gallery review and upload verification are required for a release that advertises the new Watch behavior. No UI pixels were fabricated or replaced.

Apple references: [turn-based matches and passing turns](https://developer.apple.com/documentation/gamekit/starting-turn-based-matches-and-passing-turns-between-players), [creating turn-based games](https://developer.apple.com/documentation/GameKit/creating-turn-based-games).
