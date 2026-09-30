# Summary

The captured home works as a floating Vision Pro game window. The title and rival form distinct groups, Play is obvious, and the established alpine palette survives the adaptation. One visible contrast collision and two small source corrections need attention. This is a native SwiftUI review; no HTML/CSS detector applies.

# Findings

- Material: Finn's cream name crosses the amber sun in `home.png`. Source palette contrast is 1.53:1, below the 3:1 large-text floor. Cream body text over the upper mountain is 4.31:1, just below 4.5:1. Add the existing ink treatment immediately above `MountainScenery` in `visionHome`. A 50% ink scrim yields 4.52:1 even over amber and preserves the palette without adding a panel. Recapture the result.
- Interaction: board targets correctly start at 60 points with 12-point gaps and native hover highlighting. `MountainButton` declares a 56-point minimum, although its headline and padding can make the actual button taller. Set its visionOS floor to 60. The game header's Close and Player controls explicitly use 48-point plain custom controls with no authored hover feedback. Give these visionOS controls 60-point targets and `mountainHover()`. Apple's [spatial-input guidance](https://developer.apple.com/videos/play/wwdc2023/10073/) requires sufficient eye-target area and hover feedback; size and surrounding spacing can together provide the target area.
- Source fit: the wide game row budgets 360 points for scores, 48 for gaps, 64 for outer padding, but subtracts only 464 when calculating board width. Its content budget exceeds the window by 8 points before the board cap. Change the subtraction to 472. Horizontal scrolling makes this a small sizing correction, not proof of a clipped render.
- Verification gap: live game, replay, compact window, large Dynamic Type and headset gaze/pinch comfort have no captured evidence. Do not certify them from the home screenshot or successful builds.

# Direction fidelity

The captured default home follows `direction.md`: invitation on the left, named human rival and portrait above Play on the right. The source preserves Classic rules, local play, sixteen rivals, human-first defaults, adaptive skill, paused replay and narrow-window reflow. Separate score and board depth offsets remain modest. No approved comp exists; fidelity is to the written direction and established pine, cream, amber and mint world.

# Craft floor

Home fit, spacing, hierarchy and discoverability pass in the supplied simulator capture. SF Symbols and native sheets suit the platform. Typography uses relative display sizing and semantic UI styles. Source includes tile labels and move hints, named icon-only actions, keyboard shortcuts, disabled replay feedback, Reduce Motion handling, and inactive/covered scenery pausing. Contrast requires the correction above. Depth offsets and custom hover behavior need device verification. The three 1024-square icon layers are valid RGBA assets: an opaque pine/sun background and transparent mountain/trail foreground layers. Their authored geometry fits the game; launcher parallax has not been captured. Simulator and unsigned-device builds, game logic checks, and iOS/Mac builds passed as reported by the implementer, not independently rerun in this review.

# Disposition

fix

Apply the small contrast, target/hover and board-budget corrections, then recapture home. Gameplay/replay/compact and hardware checks remain explicitly unverified; they do not justify rebuilding the design.
