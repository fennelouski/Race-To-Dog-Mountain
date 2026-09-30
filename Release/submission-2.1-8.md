# App Store submission — 2.1 (8), 1 October 2026

macOS and visionOS were submitted and visibly reached **Waiting for Review**. iOS/iPadOS, including the independent Watch app and Messages extension, uploaded and processed successfully but remain **Prepare for Submission**.

| Platform | Build | Review submission | Status |
| --- | --- | --- | --- |
| macOS | 2.1 (8) | c4f92c4d-de5c-4c91-98aa-9c2dbfa4257b | Waiting for Review, 00:55 Europe/Amsterdam |
| visionOS | 2.1 (8) | e15aa5d7-7f40-4624-a436-813acd57522e | Waiting for Review, 00:56 Europe/Amsterdam |
| iOS/iPadOS, Watch, Messages | 2.1 (8) | Not submitted | Apple validation blocked Add for Review |

The prior iOS build 7 submission was removed to replace it with build 8. iOS 2.0 remains the distributed version. Review approval and public availability have not been confirmed. The existing automatic release after approval setting was retained.

## Remaining iOS blockers

Apple requires Messages screenshots for 6.5-inch iPhone and 13-inch iPad displays. The installed extension registers in both isolated iOS 18.5 and 26.5 simulators. Native Messages app-picker and Xcode extension-host attempts did not expose its game/composer reliably. No fabricated Messages screenshot was uploaded and no message was sent. Test the native host on an authenticated physical device, capture both display families, and verify alternating turns and independent sessions before resubmitting.

Apple also rejects the Game Center entitlement check. The actual distribution-signed payload has `com.apple.developer.game-center = true`, `get-task-allow = false`, and `beta-reports-active = true`. Apple's processed TestFlight metadata for iOS build 8 independently displays that same Game Center entitlement on the main executable. Refreshing the Game Center flag and reattaching build 8 did not clear validation. Resolve the conflicting App Store Connect validation before submitting iOS; do not remove friend play to bypass it. Mac and Vision list each other as compatible from 2.1. The iOS compatibility table still lists only iOS; cross-platform compatibility with iOS remains to be verified.

## Builds, media and verification

Application code comes from `f9fcc89e6398d0c6c14416f617c046edcd9917ab`. Build 8 adds reviewed distribution packaging: Watch embedded as an independently running companion, proper rectangular Messages icon assets, automatic Mac signing, and export-compliance declarations. The original archives were exported using the signed-in Xcode account and cloud-managed distribution signing. All three upload logs report success. Mac is universal arm64/x86_64 with App Sandbox; strict archive signatures passed. Mac upload emitted a nonblocking missing-dSYM warning, and dsymutil found no debug symbols. Symbols remain unavailable for that Mac build.

`bash Tools/ReleaseChecks/run.sh` passed shared rules, computer turn gates, Watch persistence, validated social transcripts and independent saves. Release simulator and all three signed archives built successfully. Live two-account Game Center delivery, Messages host/composer, physical Vision interaction and Watch hardware checks remain unverified and were disclosed in review notes.

`Marketing/Social/manifest.json` records actual native capture sources, hashes and output dimensions. The iPhone/iPad galleries now lead with the current social lobby beside existing gameplay/replay images. Mac and Vision each received one current screenshot. Watch received a real 416 × 496 gameplay screenshot; its required-screenshot validation cleared. Old screenshots and archives remain in prior release evidence.

Local audit evidence: `/Users/nathan/Documents/GitHub/app-store-audit/2026-10-01-race-all-platforms/`. This includes upload/build logs, three final archives, receipt.json, review-queue.png and ios-validation.png. No website or API deployment was performed; native releases are outside the AWS migration policy.
