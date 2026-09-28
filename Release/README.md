# Race to Dog Mountain release

Apple ID 971329310, bundle `com.nathanfennel.RacetoDogMountain`, team EJLR2RPSV2. Prepared iOS version 2.0 build 5 fixes computer turns continuing behind the exit confirmation. Build 4 and earlier archives remain preserved as prior evidence.

The SwiftUI setup and board preserve Classic row/column and Plus neighbor-flip rules, human/computer choices, board sizes and the existing `playerNamevvvotherName` win-history keys. Both modes keep a random first player. Used tiles cannot score again. Computer turns pause when inactive or when the exit confirmation is open. Cancel resumes play. Board cells have spoken row, column, value and Plus ownership; Reduce Motion disables move animation. Quitting no longer initializes an unused legacy Core Data store. Existing files and preferences remain intact.

Run `bash Tools/ReleaseChecks/run.sh` for production-model checks of legal/illegal/repeated moves, score conservation and complete computer games in both modes. The runner also executes the actual computer-task body and identity with isolated state to verify dialog pause, Cancel resume and task cancellation. These checks do not verify native visuals or touch controls.

Still required: actual phone/iPad setup and both-mode games, interrupted turns, win-history relaunch, VoiceOver, large text and dark mode; current screenshots; authenticated Apple distribution export/upload, processing and build selection; current metadata verification and submission. The supplied review contact was already saved and visually verified in App Store Connect. Verify Waiting for Review or In Review before reporting submission.

Native releases are outside the parent workspace AWS/Vercel policy. Apply that policy to any future website or API deployment.

Build 4 adds the canonical Privacy Policy link at Home > Privacy > Privacy Policy. All app behavior, storage, bundle/team and entitlements remain unchanged. Previous build 3 archives and source evidence are retained; they do not prove build 4 runtime, screenshots, upload or submission. Build 4 compilation and strict archive verification passed; actual link navigation remains part of native QA. Build 5 passed Release archive and strict signature verification. Its actual native QA and screenshots remain pending before upload.
