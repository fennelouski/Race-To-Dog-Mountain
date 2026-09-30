# Race to Dog Mountain release

## Apple Watch edition, 2026-09-30

The `Race to Dog Mountain Watch` scheme builds an independent native watchOS 10+ game. Classic starts with a 4 × 4 board, human first and computer player 2. All sixteen human rivals, adaptive accuracy and replay reuse the existing game. Watch play is fixed at 4 × 4; only rival difficulty is configurable. Native vertical pages separate moves, board, score/replay and settings. A thin gold/mint/remaining-points bar sits in a separate footer below the moves, away from the native clock. Exact totals have their own page. Controls use icons, portraits and numbers, with descriptive VoiceOver labels; only exit confirmation displays explanatory text. Large legal-number buttons and Crown scrolling suit wrist play. Every move is saved locally. Computer turns pause while inactive or dimmed, and on any page except Moves, during replay and during exit confirmation. The home backdrop is static and the game uses plain pine.

Run `./script/build_watch_and_run.sh` or Codex **Run Apple Watch** to rebuild, install and open the watch simulator. The script preserves saved matches. Debug simulator and unsigned watchOS device Release builds passed. Production rules, computer lifecycle, persistence, replay and adaptation checks run with `bash Tools/ReleaseChecks/run.sh`. iOS, macOS and visionOS regression builds passed after the shared scenery extraction.

The independent visual finish review returned `ship` for the supplied 40 mm and 42 mm captures and source. Native simulator captures and verification are recorded in `/Users/nathan/Documents/GitHub/app-store-audit/2026-09-30-race-watchos/`. Physical Watch battery, haptic comfort, VoiceOver and accessibility text sizes remain hardware/runtime checks. The device build is unsigned; this work does not constitute a watch App Store upload or submission. No phone sync, complications or widgets are included.

## Native visionOS build — 2026-09-30

The `Race to Dog Mountain Vision` scheme builds a native SwiftUI app for visionOS 2 and later. Its floating alpine window opens with the invitation and named human rival beside Play. The wide game centers a larger board between both scores, with subtle depth and native hover feedback. Compact windows use vertical scrolling. The three-layer Vision Pro icon matches the pine, cream, amber and mint palette. Classic rules, sixteen difficulty levels, human-first defaults, adaptive accuracy and paused computer replay use the existing game.

Run `./script/build_vision_and_run.sh` or Codex **Run Vision Pro** to rebuild, install and open the app in an available Vision Pro simulator. Debug simulator and unsigned arm64 device Release builds passed, as did the production game checks and iOS/macOS regression builds. The app was installed and launched in the visionOS 26.5 simulator, and the native home was captured. The reviewer scored the home/source corrections separately; live visionOS gameplay, replay, compact layout, large text, gaze/pinch comfort and physical-headset performance remain unverified. Shared Simulator focus and synthetic input prevented a reliable live gameplay check.

The device build at `build/vision/Build/Products/Release-xros/Race to Dog Mountain Vision.app` is unsigned (`CODE_SIGNING_ALLOWED=NO`); this is not a headset installation or App Store submission. Build logs, native capture and receipt are in `/Users/nathan/Documents/GitHub/app-store-audit/2026-09-30-race-visionos/`.

## Native macOS build — 2026-09-30

The separate `Race to Dog Mountain Mac` scheme builds a native SwiftUI application for macOS 14 and later. It reuses the Classic game, sixteen rivals, portraits, animated scenery and icon. At desktop widths the score and replay controls sit beside the board; narrower windows scroll. Native commands provide New Game (⌘N), Replay (⌘R), player options (⌘,), and Leave Game (⇧⌘W); Escape also opens the leave confirmation.

Run `./script/build_and_run.sh` or the Codex **Run** action to rebuild and launch Debug. A universal Apple Silicon/Intel Release app is at `build/mac/Build/Products/Release/Race to Dog Mountain Mac.app`. Both Mac configurations and the iOS simulator build passed; production game checks passed. Native checks verified human-first play, computer response, replay, menu shortcuts, player settings and compact-window scrolling. Strict signature verification passed. This build is signed locally, without notarization or Mac App Store submission. Receipt, build logs and native captures are in `/Users/nathan/Documents/GitHub/app-store-audit/2026-09-30-race-macos/`.

## Version 2.1, build 7 — 2026-09-30

The alpine redesign now has 16 human computer rivals with named difficulty levels, illustrated portraits, profile-specific motion and optional dialogue (off by default). The computer defaults to player 2; the lone human starts. Computer-only opening turns wait for Play. Replay keeps a snapshot of the last computer move and pauses live play. Completed human-versus-computer results adjust accuracy slightly, capped at two steps; changed player roles and demonstrations do not adjust it. Manual difficulty changes reset the adjustment.

The new opaque 1024-pixel mountain icon feeds every supported iOS device class and compatible iOS installs. Matching legacy icon exports were refreshed. Exact icon and portrait generation prompts are recorded beside this release. Six App Store compositions in `Release/Marketing/` combine a generated alpine backdrop, exact typeset captions and unchanged native screenshots from version 2.1 build 7. Their capture hashes, copy and output dimensions are in `manifest.json`.

Verification: Debug simulator build and Release archive succeeded; strict signature verification passed. `bash Tools/ReleaseChecks/run.sh` passes Classic legality, all 16 AI levels, human starts, score conservation, replay isolation, bounded win/loss adaptation, explicit Play gates and cancellation on exit/replay/inactive/dismissal. Current native phone 6.9-inch and iPad 13-inch captures verify home, human move/computer response and replay. Earlier native checks also exercised all 16 selections, dialogue and computer-only Play. Independent visual review returned `ship` for current default-size native screens, portraits and icon. The marketing reviewer scored its one typesetting correction resolved. Current rendered large Dynamic Type, VoiceOver and physical-device performance remain outside that review.

Release archive and successful distribution upload are preserved outside this repo in `/Users/nathan/Documents/GitHub/app-store-audit/2026-09-30-race-2.1-build7/`. App Store Connect version 2.1 was created, Classic-only metadata saved, and build 7 uploaded successfully. Submitted September 30, 2026 at 19:13 Europe/Amsterdam. App Store Connect visibly confirms **Waiting for Review**, version **2.1 (7)**, submission `4147317b-6a51-4cfe-a521-dfead4c50bfc`. Receipt and final screenshot are `submission-receipt.json` and `waiting-for-review.png` in that audit directory. The existing automatic-release-after-approval setting was preserved.

## Current UI redesign, 2026-09-30

The current worktree launches into an alpine poster scene with direct Play, animated clouds/stars/trail, cream serif display lettering, and amber/mint rivalry colors. Player configuration and instructions are secondary sheets. The custom tile board animates score changes and turn highlights, gives move/result haptics, and offers a confetti result and immediate rematch. Classic is the only Swift game mode; the old Plus preference cannot select another mode. Existing names, board-size preferences and win-history keys remain in use.

Scenery updates only its Canvas at up to 30 fps, pauses while covered or inactive, and has a static Reduce Motion alternative. Large text changes the title composition and stacks score panels; large boards scroll rather than shrinking touch targets below 44 points. Computer turns require an active application and pause during exit confirmation.

Verification: Debug simulator build succeeded. `bash Tools/ReleaseChecks/run.sh` passes Classic legality, repeated/out-of-range moves, board limits, AI completion, score conservation, dialog cancellation, inactive/background pause, and dismissal checks. Native captures cover iPhone 17 opening at regular and largest accessibility text sizes, system light/dark appearance, and iPad Pro 11-inch opening and board. Native iPad interaction checks cover Play, a human move and computer response, in-game player controls, complete matches, result and rematch controls, persisted win display and board-size editing. The visual finish review returned `ship` for those supplied captures and source. Physical-device performance and VoiceOver operation were not verified.

Captures: `/Users/nathan/Documents/GitHub/app-store-audit/2026-09-30-race-ui/`. This is a local UI preview, not an App Store upload or submission. Previous archives below describe earlier revisions.

## Earlier release preparation

Apple ID 971329310, bundle `com.nathanfennel.RacetoDogMountain`, team EJLR2RPSV2. Prepared iOS version 2.0 build 5 fixes computer turns continuing behind the exit confirmation. Build 4 and earlier archives remain preserved as prior evidence.

The SwiftUI setup and board preserve Classic row/column and Plus neighbor-flip rules, human/computer choices, board sizes and the existing `playerNamevvvotherName` win-history keys. Both modes keep a random first player. Used tiles cannot score again. Computer turns pause when inactive or when the exit confirmation is open. Cancel resumes play. Board cells have spoken row, column, value and Plus ownership; Reduce Motion disables move animation. Quitting no longer initializes an unused legacy Core Data store. Existing files and preferences remain intact.

Run `bash Tools/ReleaseChecks/run.sh` for production-model checks of legal/illegal/repeated moves, score conservation and complete computer games in both modes. The runner also executes the actual computer-task body and identity with isolated state to verify dialog pause, Cancel resume and task cancellation. These checks do not verify native visuals or touch controls.

Still required: actual phone/iPad setup and both-mode games, interrupted turns, win-history relaunch, VoiceOver, large text and dark mode; current screenshots; authenticated Apple distribution export/upload, processing and build selection; current metadata verification and submission. The supplied review contact was already saved and visually verified in App Store Connect. Verify Waiting for Review or In Review before reporting submission.

Native releases are outside the parent workspace AWS/Vercel policy. Apply that policy to any future website or API deployment.

Build 4 adds the canonical Privacy Policy link at Home > Privacy > Privacy Policy. All app behavior, storage, bundle/team and entitlements remain unchanged. Previous build 3 archives and source evidence are retained; they do not prove build 4 runtime, screenshots, upload or submission. Build 4 compilation and strict archive verification passed; actual link navigation remains part of native QA. Build 5 passed Release archive and strict signature verification. Its actual native QA and screenshots remain pending before upload.


## Social play development preview · 30 September 2026

The full-size editions now have a multi-game lobby. New local games and pass-and-play games save independently, resume after relaunch and keep completed games in a disclosure. Game Center uses native two-player turn-based matches with invitations, refreshed authoritative moves and rematches. The iOS app embeds the `Dog Mountain Messages` extension: a fixed 4 × 4 board, one move per prepared bubble and an independent Messages session for every race. The player taps the native Send control. No custom server is required.

Run `bash Tools/ReleaseChecks/run.sh` for rules, computer turn gates, Watch persistence and validated social transcript/save checks. Shared schemes are `Race to Dog Mountain`, `Dog Mountain in Messages`, `Race to Dog Mountain Mac`, `Race to Dog Mountain Vision` and `Race to Dog Mountain Watch`. The `Dog Mountain in Messages` scheme uses the native Messages host; the main iOS scheme embeds the extension. Debug simulator and unsigned device Release builds compile the extension.

This is an unsubmitted development preview. Local concurrent games were exercised and survived relaunch. Live Game Center invitation, turn delivery, outcomes and cross-platform grouping still require service configuration, valid provisioning and two authenticated test accounts. Messages registered with the simulator, but opening its board/composer has not yet been verified. Before release, test both devices selecting old bubbles, alternating turns, cancelling a draft, finishing, rematching and keeping two races independent. Confirm the Messages-specific App Store icon requirements. Do not treat compilation or these checks as proof of live delivery. The Watch retains its simple solo game.
