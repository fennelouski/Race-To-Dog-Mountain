# Race to Dog Mountain release

Apple ID 971329310, bundle `com.nathanfennel.RacetoDogMountain`, team EJLR2RPSV2. Prepared iOS version 2.0 build 4 supersedes the uncommitted build 2 archive. Build 3 remains preserved as earlier source/archive evidence.

The SwiftUI setup and board preserve Classic row/column and Plus neighbor-flip rules, human/computer choices, board sizes and the existing `playerNamevvvotherName` win-history keys. Both modes keep a random first player. Used tiles cannot score again. Computer turns pause when inactive. Board cells have spoken row, column, value and Plus ownership; Reduce Motion disables move animation. Quitting no longer initializes an unused legacy Core Data store. Existing files and preferences remain intact.

Run `bash Tools/ReleaseChecks/run.sh` for production-model checks of legal/illegal/repeated moves, score conservation and complete computer games in both modes. These checks do not verify native visuals or touch controls.

Still required: actual phone/iPad setup and both-mode games, interrupted turns, win-history relaunch, VoiceOver, large text and dark mode; current screenshots; authenticated Apple distribution export/upload, processing and build selection; final review contact, metadata and submission. Verify Waiting for Review or In Review before reporting submission.

Native releases are outside the parent workspace AWS/Vercel policy. Apply that policy to any future website or API deployment.

Build 4 adds the canonical Privacy Policy link at Home > Privacy > Privacy Policy. All app behavior, storage, bundle/team and entitlements remain unchanged. Previous build 3 archives and source evidence are retained; they do not prove build 4 runtime, screenshots, upload or submission. Build 4 requires its own compile/archive verification and actual link-navigation check.
