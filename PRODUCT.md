# Race to Dog Mountain

<!-- impeccable:product-schema 1 -->

## Platform

ios, macos, visionos, watchos

## Product purpose

A two-player number strategy game for solo practice, pass-and-play and asynchronous races with friends. Players alternate selecting numbers from a highlighted row or column. Each selection sets the opponent's next line. The higher total wins when no legal moves remain.

The native visionOS edition supports visionOS 2 and later. It shares the Classic game and rivals, with a resizable floating window, spatial depth, larger indirect-selection targets, native hover feedback and a layered icon. A wide game window places the board between both scores; compact windows scroll vertically. No immersive environment or room permissions are required.

The independent watchOS edition supports watchOS 10 and later. It is a simple wrist game: fixed 4 × 4 Classic, human first against computer player 2, large legal-number choices and separate swipe pages for the read-only board, score/replay and settings. A thin three-part points bar sits below the moves, away from the clock. Watch screens use icons, portraits and numbers; explanatory text is reserved for exit confirmation and accessibility labels. One difficulty selector retains all sixteen rivals. Board-size, role and chat options stay on the other platforms. It saves after every move and resumes after interruption. No phone is required; progress does not sync between devices.

## Capabilities and constraints

Classic is the only game, as explicitly requested. Keep human/computer players, board sizes from 4 to 14, human-first starts against the computer, local player names, and existing head-to-head win history. No network or account is needed to play. The existing SwiftUI app targets iOS 17 and supports iPhone and iPad. A native macOS target supports macOS 14 and later, reusing the game, views and assets with desktop layout, menus and keyboard commands.

Computer defaults to player 2. Sixteen selectable levels each have a human name, portrait, motion and optional phrases. Chat starts off. Results nudge computer accuracy within the selected level; replay shows the last computer move while pausing live play. Computer-only games require Play before moving.

Friend play on iOS/iPadOS, macOS and visionOS uses native Game Center turn-based matches. The opening screen lists concurrent friend games and separately saved local games, with matches needing a move first and finished games in a disclosure. Game Center requires sign-in, provisioning and service configuration; local play remains account-free. Cross-platform delivery needs live two-account verification.

The iOS app embeds a Messages extension for two-person conversations. Each independent 4 × 4 race carries a validated move transcript in its message. Players choose one number, prepare the board bubble and explicitly tap the native Send control. Group conversations are excluded. Live message delivery and participant mapping require two-device verification.

## Brand commitments

The user requests a rich, colorful, creative interface, animations including background motion, and an interesting opening screen rather than settings. Keep the Race to Dog Mountain name. Launch should lead directly to Play; player configuration is secondary.

## Accessibility

Apply the workspace's Dynamic Type, Reduce Motion, contrast, VoiceOver, safe area, and minimum touch-target guidance.

## Open decisions

Audience age and specific visual references were not supplied. This redesign uses the game's existing local play workflow and mountain identity without adding product claims.
