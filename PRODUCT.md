# Race to Dog Mountain

<!-- impeccable:product-schema 1 -->

## Platform

ios, macos, visionos, watchos

## Product purpose

A two-player number strategy game for solo practice, pass-and-play and asynchronous races with friends. Players alternate selecting numbers from a highlighted row or column. Each selection sets the opponent's next line. The higher total wins when no legal moves remain.

The native visionOS edition supports visionOS 2 and later. It shares the Classic game and rivals, with a resizable floating window, spatial depth, larger indirect-selection targets, native hover feedback and a layered icon. A wide game window places the board between both scores; compact windows scroll vertically. No immersive environment or room permissions are required.

The independent watchOS edition supports watchOS 10 and later. Local play is a simple wrist game: fixed 4 × 4 Classic, human first against computer player 2, large legal-number choices and separate swipe pages for the read-only board, score/replay and settings. A thin three-part points bar sits below the moves, away from the clock. One difficulty selector retains all sixteen rivals. Local play saves after every move and resumes after interruption without a phone; its computer game stays local.

The Watch friend inbox connects through the paired iPhone to the same Game Center races played on iPhone, iPad, Mac and Vision Pro. Each race has its own saved board, legal-number choices and scores. The phone authenticates the player and validates and saves the turn before the Watch shows it. The inbox remains readable offline, but refreshing or sending a move requires the paired phone. Friend invitations and rematches start on the other platforms. This preserves existing friend-game identities because modern Game Center player IDs are unavailable on watchOS.

## Capabilities and constraints

Classic is the only game, as explicitly requested. Keep human/computer players, board sizes from 4 to 14, randomized starts in computer games on iPhone/iPad/Mac/Vision, local player names, and existing head-to-head win history. No network or account is needed to play. The existing SwiftUI app targets iOS 17 and supports portrait-only iPhone and adaptive iPad layouts. A native macOS target supports macOS 14 and later, reusing the game, views and assets with desktop layout, menus and keyboard commands.

Computer defaults to player 2. Sixteen selectable levels each have a human name, portrait, motion and optional phrases. Chat starts off. Adaptive difficulty starts at the easiest rival and adjusts between completed games using bounded AIMD toward a rolling 60–70% human win band. Learning is local and separate per named human, board size and seat, with manual difficulty and reset controls; no human win rate is guaranteed. Replay shows the last computer move while pausing live play. Computer-only games require Play before moving.

Friend play on iOS/iPadOS, macOS and visionOS uses native Game Center turn-based matches. The opening screen contains only the app name, a large Play button and Help, Friends and Settings buttons. The Friends hub lists concurrent friend games and separately saved local games, with matches needing a move first and finished games in a disclosure. Received turn events update games while both players are online, and Game Center retains turns when they leave. Account-scoped last-known boards survive a temporary refresh failure. The Watch uses the paired-phone relay described above. Game Center requires sign-in, provisioning and service configuration; local play remains account-free. Cross-platform delivery and the paired-phone relay still need live two-account and physical-device verification; see `Release/cross-platform-multiplayer.md`.

The iOS app embeds a Messages extension for two-person conversations. Each independent 4 × 4 race carries a validated move transcript in its message. Players choose one number, prepare the board bubble and explicitly tap the native Send control. Group conversations are excluded. Live message delivery and participant mapping require two-device verification.

Compact boards through a configurable 7 × 7 threshold fit the available width; larger compact boards scroll, while roomier boards fit the available width and height. Fitted cells can be smaller than 44 points and use smaller text; VoiceOver exposes complete values. Dynamic Type accessibility sizes retain vertical scrolling.

Human score profiles allow a display name/icon without changing saved player identity. Results open in a sheet with rematch, return, and sharing. New games preserve validated actual move history for replay GIF export; old saves with no transcript export their actual final board as PNG. Animations and haptics can be disabled independently. System Reduce Motion overrides animation settings, and the status bar is hidden by default with an opt-in toggle.

Connected iOS displays consume read-only snapshots from the single active game controller. The external board uses a wide board-and-scores composition, independent safe-area layout, and no gameplay/AI authority. iPhone remains the portrait controller. Reconnection retains the primary game; legacy external-scene configuration and iOS 27 scene accessories cover their respective OS versions. Hardware AirPlay/cable validation remains separate from source and simulator UI verification.

## Brand commitments

The user requests a rich, colorful, creative interface, animations including background motion, and an interesting opening screen rather than settings. Keep the Race to Dog Mountain name. Launch should lead directly to Play; player configuration is secondary.

## Accessibility

Apply the workspace's Dynamic Type, Reduce Motion, contrast, VoiceOver, safe area, and minimum touch-target guidance.

## Open decisions

Audience age and specific visual references were not supplied. This redesign uses the game's existing local play workflow and mountain identity without adding product claims.
