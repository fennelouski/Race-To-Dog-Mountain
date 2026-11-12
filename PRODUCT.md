# Tally Tangle

<!-- impeccable:product-schema 1 -->

## Platform

ios, macos, visionos, watchos

## Product purpose

A two-player number strategy game for solo practice, pass-and-play and asynchronous races with friends. Players alternate selecting numbers from a highlighted row or column. Each selection sets the opponent's next line. The higher total wins when no legal moves remain.

The native visionOS edition supports visionOS 2 and later. It shares the Classic game and rivals, with a resizable floating window, spatial depth, larger indirect-selection targets, native hover feedback and a layered icon. A wide game window places the board between both scores; compact windows scroll vertically. No immersive environment or room permissions are required.

The independent watchOS edition supports watchOS 10 and later. Local play is a simple wrist game: fixed 4 × 4 Classic, human first against computer player 2, large legal-number choices and separate swipe pages for the read-only board, score/replay and settings. A thin three-part points bar sits below the moves, away from the clock. One difficulty selector retains all eighteen rivals. Local play saves after every move and resumes after interruption without a phone; its computer game stays local.

The Watch friend inbox connects through the paired iPhone to the same Game Center races played on iPhone, iPad, Mac and Vision Pro. Each race has its own saved board, legal-number choices and scores. The phone authenticates the player and validates and saves the turn before the Watch shows it. The inbox remains readable offline, but refreshing or sending a move requires the paired phone. Friend invitations and rematches start on the other platforms. This preserves existing friend-game identities because modern Game Center player IDs are unavailable on watchOS.

## Capabilities and constraints

Classic is the only game, as explicitly requested. Keep human/computer players, board sizes from 4 to 14, randomized starts in computer games on iPhone/iPad/Mac/Vision, local player names, and existing head-to-head win history. No network or account is needed to play. The existing SwiftUI app targets iOS 17 and supports portrait-only iPhone and adaptive iPad layouts. A native macOS target supports macOS 14 and later, reusing the game, views and assets with desktop layout, menus and keyboard commands.

Computer defaults to player 2. Eighteen selectable levels each have a human name, motion and optional phrases; names run alphabetically from easiest (Amara) to hardest (Zuri), and painted portraits stay with their names (Rosa and Wren show a lettered leaf badge until they have paintings). Above level 1 a rival never ends the game on a loss when another move keeps it going, and the search scores a finished game as a decisive win or loss. When the computer plays itself each seat has its own rival; if both seats pick the same rival, player 1 shows that rival's lettered leaf badge instead of the painting. Chat starts off. Adaptive difficulty starts at the easiest rival and adjusts between completed games using bounded AIMD toward a rolling 60–70% human win band. Learning is local and separate per named human, board size and seat, with manual difficulty and reset controls; no human win rate is guaranteed. A labelled button under the board replays the last computer move while pausing live play. Computer-only games require Play before moving.

Friend play on iOS/iPadOS, macOS and visionOS uses native Game Center turn-based matches. The opening screen hand-letters the app name in vines: separate vines grow in from the top and sides of the screen, each reaching one letter and writing it in script (both T crossbars grow in from the left edge; the right arm of the y in Tally and the tail of the e in Tangle grow in from the right edge), with a slimmer twining vine, curling tendrils, leaves, berries and blossoms; side vines draw back into their letters once written while the top ones stay hanging. Tapping or clicking a letter sends a wave along its vine, flutters its leaves, ripples nearby letters and scatters leaves and petals (off under Reduce Motion or Animation None) (the title unwinds when a game opens and regrows on return). It also has a dense canopy of swaying vines with blossoms and fireflies, a large round Play button (the word Play only) and a row of four labelled buttons: Invite (Game Center friend picker), History, Help and Settings. No instructional text. History lists local games by type with in-progress games first and finished games below, each finished game showing a thumbnail of who took each square. Opening one shows the replay board, and Rematch on this board replays the identical starting board with the same players, Pass & Play, or any computer rival. The Friends hub lists concurrent friend games and separately saved local games, with matches needing a move first and finished games in a disclosure. Received turn events update games while both players are online, and Game Center retains turns when they leave. Account-scoped last-known boards survive a temporary refresh failure. The Watch uses the paired-phone relay described above. Friend games can use automatic moves (on by default for new games, set in Settings; either player can change it on their own turn): each turn is sent with a 12-hour Game Center timeout that hands the turn back, and the waiting player's device then takes the largest number on the absent player's line for them, deterministically, before continuing. This keeps games moving while rewarding players who move themselves. Messages games have no timeout. Game Center requires sign-in, provisioning and service configuration; local play remains account-free. Cross-platform delivery and the paired-phone relay still need live two-account and physical-device verification; see `Release/cross-platform-multiplayer.md`.

The iOS app embeds a Messages extension for two-person conversations. Each independent 4 × 4 race carries a validated move transcript in its message. Players choose one number, prepare the board bubble and explicitly tap the native Send control. Group conversations are excluded. Live message delivery and participant mapping require two-device verification.

Compact boards through a configurable 7 × 7 threshold fit the available width; larger compact boards scroll, while roomier boards fit the available width and height. Fitted cells can be smaller than 44 points and use smaller text; VoiceOver exposes complete values. Dynamic Type accessibility sizes retain vertical scrolling.

Human score profiles allow a display name and an icon, emoji or imported photo without changing saved player identity. Fonsters are hidden until they are polished (the code remains); computer rivals always use their painted portraits. Switching players is only offered before the first move: vines grow over the board until it is hidden, the player cards slide to their new seats, the new board is dealt underneath and the vines recede. On Mac, arrow keys move a highlight along your line and Return or Space plays it; the menus offer New Game ⌘N, Replay ⌘R, Switch Players ⇧⌘S, History ⌘Y, Invite a Friend ⌘I, Settings ⌘,, Leave Game ⇧⌘W, How to Play ⌘? and Toggle Full Screen ⇧⌘F. At the end of a round the final points land on the score, then the game layout animates in place: a winner panel tallies both totals, a smaller final board replays who claimed each square (tap to replay), and Play again, Share and Home sit below, all on one screen without scrolling (accessibility text sizes may scroll). Haptics mark moves and the result. New games preserve validated actual move history for replay GIF export; old saves with no transcript export their actual final board as PNG. Settings uses labelled cards: player images, board size and fit limit, Animation (None, Fast, Natural, Relaxed; None replaces the old Reduced motion switch) and Haptics. Pressing anywhere plants a bud that blooms on release; pressed tiles tuck in with a ring. A picked number counts down and shrinks while its points fly to the score, and the last-move outline uses the mover's colour. System Reduce Motion overrides animation settings, and the status bar is hidden by default with an opt-in toggle.

Connected iOS displays consume read-only snapshots from the single active game controller. The external board uses a wide board-and-scores composition, independent safe-area layout, and no gameplay/AI authority. iPhone remains the portrait controller. Reconnection retains the primary game; legacy external-scene configuration and iOS 27 scene accessories cover their respective OS versions. Hardware AirPlay/cable validation remains separate from source and simulator UI verification.

## Notifications

Settings has a Notifications section: an optional daily reminder at a chosen time, an optional reminder one day after leaving an unfinished game (cancelled when any game opens), and a link to the system notification settings, where Game Center's friend-turn and invitation notifications are managed. Permission is requested only when a reminder is turned on.

## Localization

All user-facing text lives in `Race to Dog Mountain/Localizable.xcstrings`, shared by every target and translated into every iOS 26 UI language (50 locales; English variants fall back to en). Plural-sensitive counts use plural variations. "Tally Tangle", Game Center and URLs are marked do-not-translate. New UI strings must go through `Text("literal")` or `String(localized:)`; plain `String` literals shown to people are not localized.

## Brand commitments

The user requests a rich, colorful, creative interface, animations including background motion, and an interesting opening screen rather than settings. Keep the Tally Tangle name (renamed from Race to Dog Mountain on 2026-11-11). Theme everything with tangling vines and plants, never mountains. The game screen always has subtle motion and responds to touches. Launch should lead directly to Play; player configuration is secondary.

## Accessibility

Apply the workspace's Dynamic Type, Reduce Motion, contrast, VoiceOver, safe area, and minimum touch-target guidance.

## Open decisions

Audience age and specific visual references were not supplied. This redesign uses the game's existing local play workflow and vine identity without adding product claims.
