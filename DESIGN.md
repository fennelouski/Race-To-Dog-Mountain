---
name: Race to Dog Mountain
description: An alpine poster for a local number strategy game.
colors:
  pine-ink: "rgb(2.5% 12% 17%)"
  warm-cream: "rgb(100% 95% 82%)"
  trail-gold: "rgb(100% 73% 28%)"
  column-mint: "rgb(42% 88% 81%)"
  sky-teal: "rgb(8% 32% 36%)"
  distant-mist: "rgb(32% 57% 53%)"
  far-ridge: "rgb(22% 49% 48%)"
  near-ridge: "rgb(10% 32% 36%)"
typography:
  display:
    fontFamily: "Georgia-Bold, Georgia, serif"
    fontSize: "52px"
    fontWeight: 700
    letterSpacing: "-2px"
  vision-display:
    fontFamily: "Georgia-Bold, Georgia, serif"
    fontSize: "64px"
    fontWeight: 700
    letterSpacing: "-2px"
  vision-rival:
    fontFamily: "Georgia-Bold, Georgia, serif"
    fontSize: "36px"
    fontWeight: 700
  score:
    fontFamily: "Georgia-Bold, Georgia, serif"
    fontSize: "40px"
    fontWeight: 700
  title:
    fontFamily: "system-ui, sans-serif"
    fontSize: "22px"
    fontWeight: 700
  body:
    fontFamily: "system-ui, sans-serif"
    fontSize: "17px"
    fontWeight: 400
  label:
    fontFamily: "system-ui, sans-serif"
    fontSize: "15px"
    fontWeight: 600
  watch-points:
    fontFamily: "system-ui, sans-serif"
    fontWeight: 700
  watch-caption:
    fontFamily: "system-ui, sans-serif"
    fontWeight: 400
  watch-board-number:
    fontFamily: "system-ui, sans-serif"
    fontWeight: 700
  watch-control:
    fontFamily: "system-ui, sans-serif"
    fontWeight: 600
rounded:
  field-tile: "12px"
  button-score: "16px"
  board: "20px"
  vision-window: "32px"
  watch-cell: "5px"
spacing:
  grid: "6px"
  small: "12px"
  medium: "16px"
  section: "24px"
  page: "28px"
  wide-page: "48px"
  vision-page: "32px"
  vision-home-gap: "64px"
  watch-gap: "8px"
  watch-board-gap: "3px"
components:
  button-primary:
    backgroundColor: "{colors.trail-gold}"
    textColor: "{colors.pine-ink}"
    rounded: "{rounded.button-score}"
    padding: "18px 22px"
  button-secondary:
    backgroundColor: "rgb(100% 95% 82% / 0.1)"
    textColor: "{colors.warm-cream}"
    rounded: "{rounded.button-score}"
    padding: "18px 22px"
  player-input:
    backgroundColor: "rgb(100% 95% 82% / 0.08)"
    textColor: "{colors.warm-cream}"
    rounded: "{rounded.field-tile}"
    padding: "16px"
  number-tile:
    backgroundColor: "{colors.warm-cream}"
    textColor: "{colors.pine-ink}"
    rounded: "{rounded.field-tile}"
  board:
    backgroundColor: "rgb(2.5% 12% 17% / 0.7)"
    rounded: "{rounded.board}"
    padding: "12px"
  vision-window:
    rounded: "{rounded.vision-window}"
    width: "1180px"
    height: "820px"
  vision-window-minimum:
    width: "760px"
    height: "660px"
  vision-home:
    width: "1140px"
    padding: "{spacing.wide-page}"
  vision-invitation:
    typography: "{typography.vision-display}"
    width: "460px"
  vision-launch:
    width: "340px"
  vision-rival:
    typography: "{typography.vision-rival}"
    size: "132px"
  vision-button-primary:
    backgroundColor: "{colors.trail-gold}"
    textColor: "{colors.pine-ink}"
    rounded: "{rounded.button-score}"
    padding: "18px 22px"
    height: "60px"
  vision-button-secondary:
    backgroundColor: "rgb(100% 95% 82% / 0.1)"
    textColor: "{colors.warm-cream}"
    rounded: "{rounded.button-score}"
    padding: "18px 22px"
    height: "60px"
  vision-header-control:
    size: "60px"
  vision-tile-minimum:
    size: "60px"
  vision-tile-maximum:
    size: "92px"
  vision-game:
    width: "1268px"
    padding: "{spacing.vision-page}"
  vision-board:
    backgroundColor: "rgb(2.5% 12% 17% / 0.7)"
    rounded: "{rounded.board}"
    padding: "{spacing.small}"
    width: "740px"
  vision-score-pane:
    width: "180px"
  vision-icon-layer:
    size: "1024px"
  watch-button-primary:
    backgroundColor: "{colors.trail-gold}"
    textColor: "{colors.pine-ink}"
    typography: "{typography.watch-control}"
    rounded: "{rounded.field-tile}"
    padding: "8px 10px"
    height: "44px"
  watch-button-secondary:
    backgroundColor: "rgb(100% 95% 82% / 0.1)"
    textColor: "{colors.warm-cream}"
    typography: "{typography.watch-control}"
    rounded: "{rounded.field-tile}"
    padding: "8px 10px"
    height: "44px"
  watch-move:
    backgroundColor: "{colors.trail-gold}"
    textColor: "{colors.pine-ink}"
    typography: "{typography.watch-points}"
    rounded: "{rounded.field-tile}"
    padding: "8px 10px"
    height: "44px"
  watch-board-cell:
    backgroundColor: "{colors.warm-cream}"
    textColor: "{colors.pine-ink}"
    typography: "{typography.watch-board-number}"
    rounded: "{rounded.watch-cell}"
    size: "30px"
  watch-points-bar:
    backgroundColor: "rgb(100% 95% 82% / 0.4)"
    height: "4px"
  watch-portrait:
    size: "24px"
  watch-rival-portrait:
    size: "28px"
  watch-home-emblem:
    size: "42px"
---

# Design System: Race to Dog Mountain

## Overview

**Creative North Star: "The Alpine Travel Poster"**

A cream serif title sits above geometric mountain ridges and an amber sun. Deep pine sky, drifting cloud lines, stars and a dotted climbing trail make the opening scene recognizable before any controls appear. The number board carries the same colors into play.

Classic is the only game. The home screen offers local and friend play immediately; player configuration stays behind a secondary action. Rules and player settings use a quiet pine background with the same typography and palette. Results remain inside the mountain scene.

The native visionOS adaptation keeps the alpine scene inside one bounded floating window. Its invitation and named rival lead directly to Play. Glass surrounds the illustrated game; controls use native hover feedback and shallow depth offsets.

The native watchOS adaptation keeps the alpine palette and human rivals in short, icon-led pages. System type, SF Symbols and numerals carry ordinary screens; full spoken labels retain their meaning. The scenery is static on home, and play uses plain pine behind large move buttons.

**Key Characteristics:**
- Layered angular ridges, a circular sun and a winding dotted trail.
- Cream Georgia display type with readable system text for controls.
- Gold rows and mint columns, each also identified by words and arrows.
- Background motion isolated from game state and controls.
- Illustrated human hiker rivals with named levels and small portrait reactions.

- Native wrist controls use system text roles, icons and numerals with descriptive accessibility labels.

Implementation sources: `Race to Dog Mountain/MountainViews.swift` for home and local game views, `Race to Dog Mountain/MountainBoard.swift` for the extracted shared board, buttons and platform view helpers, `Race to Dog Mountain/MountainSocialViews.swift` for friend boards and inbox rows, `Messages/MessagesViewController.swift` for the Messages host and board bubble, `Race to Dog Mountain/MountainScenery.swift` for the shared palette and scenery, and `Watch/MountainWatchApp.swift` for wrist controls. Frontmatter lengths translate native points into CSS pixels for portable previews; SwiftUI Dynamic Type remains the runtime authority. Color percentages preserve the source's normalized RGB values.

## Colors

The palette combines a dark pine world with warm cream, amber gold and cool mint.

### Primary
- Trail gold lights the sun, primary actions, the row player and the winding trail.

### Secondary
- Column mint identifies the column player, their score and their legal moves.
- Sky teal and distant mist form the sky gradient. Far ridge and near ridge separate mountain layers.

### Neutral
- Pine ink anchors backgrounds, board backing and dark text on filled tiles.
- Warm cream carries text and unused number tiles. Lower opacity cream supplies secondary controls, cloud lines, stars and used-cell marks.

**The Rivalry Rule.** Gold always belongs to the row player; mint always belongs to the column player. Pair each color with its directional symbol and label.

On Watch, the remaining-points segment uses muted cream. Direction glyphs and spoken row/column labels accompany the player colors; ordinary screens omit the visible words.

## Typography

Georgia-Bold supplies the poster title, scores and result headings. System text handles instructions, controls and player labels. Scores and tile numbers use monospaced digits.

The home display uses the display token on phones, a larger 76-point base above 600 points of available width, and a 32-point base at accessibility text sizes. SwiftUI scales these custom fonts relative to large title. The home title alone uses tight tracking. Settings, rules and results use smaller Georgia headings with bases of 32, 36 and 30 points.

On iOS and macOS, an occupied inbox reduces the home title base to 36 points. This compact title and the accessibility-size title use minus one point of tracking; the empty home retains its display token tracking. Inbox names use system headline, status uses subheadline, and score totals use bold monospaced subheadline.

On visionOS, the invitation and rival name use the vision display and rival tokens. Both scale relative to large title through the shared Georgia font helper. The launch portrait uses the vision rival size token.

Watch keeps SwiftUI text roles rather than fixed font sizes: title3 bold for move points, scores and replay points; caption for direction and remaining points; caption2 bold for the read-only board; headline for button labels. Numbers use monospaced digits. The sidecar records these native roles; their frontmatter tokens intentionally omit a fixed size. Georgia remains the display face on the other platforms.

## Layout

The home scene fills the screen behind a scrollable leading-aligned composition. Its content is centered within a maximum width of 760 points. Horizontal padding grows from the page token to the wide-page token above 600 points. Safe-area content stays readable while scenery extends to every edge. Play appears before the board and player summary. Accessibility text sizes omit the decorative subtitle and shorten the spacer above Play.

Game content is centered within 792 points. The two player scores lead into a turn label and the square number grid. Scores sit side by side and stack at accessibility text sizes. The board uses the grid spacing token and a 12-point inset. Cells grow to 76 points and retain a Dynamic Type-scaled minimum of 44 points; large boards scroll horizontally instead of shrinking targets. Rules and settings center readable content within 620 points.

The visionOS plain window opens at the vision window dimensions and cannot shrink below the vision window minimum. Home uses the vision home maximum width and wide-page padding. A horizontal invitation and launch group uses the vision home gap; ViewThatFits switches it to a scrolling vertical stack when it cannot fit.

At the vision wide-game breakpoint, outside accessibility text sizes, the board sits between two vision score panes. Outer padding uses vision-page and gaps use section. The board budget is available width minus 472 points, capped by vision-board width. Compact windows and accessibility text sizes use the existing scrolling vertical game. Board cells keep the Dynamic Type-scaled vision tile minimum, grow to the vision tile maximum and use small spacing between cells. Larger boards scroll horizontally instead of reducing selection targets.

Watch uses native vertical pages inside NavigationStack, with Crown and swipe navigation. Home has Play and a separate Settings page. The game separates Moves, read-only Board, Score/replay and Settings. Scrollable content leaves the native clock clear. Moves use two flexible columns and the watch-gap spacing. A separate footer below the scroll area holds the thin points bar, with watch-gap horizontal and bottom padding. Compact board cells are read-only; the watch buttons keep their minimum height.

## Elevation & Depth

Depth comes chiefly from overlapping ridges and darker board backing. The sun has a soft gold halo. A dark overlay quiets the scenery during play. Primary buttons have a low black shadow, and filled tiles have a short shadow that separates them from the board. Score panels use player-colored translucent fills and an active underline.

iOS and macOS home place a half-opacity pine scrim over the scenery to protect the action and inbox text. Friend-game sheets use static scenery under a 0.65-opacity pine scrim. The interactive Messages board uses plain pine; its generated bubble uses static scenery with a 0.6-opacity pine scrim.

The scenery alone redraws through Canvas and TimelineView at up to 30 frames per second. It pauses when covered or backgrounded. Reduce Motion freezes scenery and removes press springs and numeric score transitions. Winning adds gold and mint confetti; the calm alternative is static.

visionOS clips the alpine scene to the vision window shape and applies native glass behind it. A half-opacity pine scrim protects home text contrast; play retains the shared darker scrim. The launch group sits 20 points forward. Wide game boards sit 12 points forward and score panes 24 points forward. These offsets describe implemented separation; headset comfort remains unverified.

Watch controls are flat, without custom shadows. Home uses inactive shared scenery under a pine scrim at 0.65 opacity; game pages use plain pine. Press feedback scales to 96% over a 0.15-second ease-out. Move and replay changes use a 0.2-second ease-out. Reduce Motion removes these custom animations and press scaling.

## Shapes

Mountains use angular paths, with a circular sun and curved dotted trail. Controls use comfortable rounded rectangles. Tiles stay square with the field-tile radius; buttons and score panels share the button-score radius. The board has the larger board radius. Game header actions use circular 48-point targets.

visionOS uses the vision window radius for clipping and its bounded glass background. Header actions use the vision header control size. Other platform shapes stay unchanged.

Watch buttons reuse the field-tile radius. The read-only board uses the smaller watch-cell radius and fixed square cells. Circular portraits use the watch portrait tokens. The points bar clips its three adjoining rectangles into a capsule.

## Components

### Buttons

The gold primary button uses dark pine text and a minimum height of 56 points. Secondary buttons use translucent cream. Both have a short spring press to 96% scale. Tile buttons use their own style with a 90% press scale so disabled cells retain the intended cream fill and dark numbers.

On visionOS, primary and secondary button heights are minimums from their vision tokens. Buttons and tiles receive native highlight hover through the shared helper; the hover hit shape is a rounded rectangle. Rules, player settings and replay remain native sheets.

### Inputs / Fields

Player names use cream text on a translucent rounded field with 16-point padding. The row or column label above each field carries the matching rivalry color and arrow. Native toggles and the board stepper preserve keyboard, accessibility and interaction conventions.

### Navigation

Home places a paw symbol opposite How to play. At accessibility text sizes, that action becomes an icon with its spoken label retained. Rules and settings open as native sheets with Done actions. Play opens a full-screen game with circular close and player controls. An unfinished game requires confirmation before leaving.

### Score panels

Each panel carries its player's name, Georgia score, directional arrow and turn label. The active player gets a stronger tinted fill and a bottom underline. Numeric transitions follow score changes unless Reduce Motion is enabled.

### Number board

Legal cells take the active player's color and a cream border. Other available cells stay cream. Used cells are faint, with a paw mark or the latest points gained. Direction labels and VoiceOver row/column announcements explain the highlighted line without relying on color alone.

### Friend games and inbox

The inbox reuses the alpine background and plain, full-width button rows. Each row has a 44-point symbol area, a leading name and written turn status, optional monospaced scores and a trailing chevron. The symbol is gold when a move is available and mint otherwise; the board retains its row/column color roles. Names and status wrap vertically, and the row combines its content for accessibility. Finished races sit inside a native disclosure.

Friend games open in native navigation sheets. Their shared board follows the existing tile sizes and horizontal scrolling rules. Gold and mint score panels reflow from two columns to a vertical stack through ViewThatFits. A written status and direction label identify whose move it is. Saving shows native progress and disables move selection. Game Center sign-in and invitations use Apple's UI. On visionOS, the native gold Pass & play capsule uses pine text.

### Messages board

The Messages extension reuses the shared challenge board and primary button. Expanded presentation shows the board; compact presentation shows a written turn status and Open board. Choosing a number reveals Add move to message and Undo choice. The staged move asks the player to tap native Send. The board bubble keeps the mountain artwork, cream Georgia title, score totals and player-colored legal tiles.

These rules describe implemented screens. Game Center delivery and cross-platform two-account play remain unverified. The Messages extension compiles and registers, but board/composer interaction, participant mapping and two-device delivery remain unverified. Lobby captures do not establish those behaviors or a release. Social review evidence is in `.impeccable/review/social`.

### Mountain scenery

One reusable Canvas draws the sky, cloud lines, ridges, sun, trail, stars and result confetti. It ignores hit testing and stays hidden from accessibility. Keep the animation timeline inside this view so game state and controls do not redraw with the sky.

### Opponents

Sixteen illustrated human hikers share the alpine palette and circular crop. Reuse `Opponent1` through `Opponent16` with the matching name and numeric level from `ComputerDifficulty`. Home and score panels use 48-point portraits, replay uses 64 points, and settings uses 80 points. A thin gold ring frames the portrait; the score panel's gold or mint still identifies the player's row or column.

Keep names and levels beside portraits so identity does not depend on artwork. Portraits are hidden from VoiceOver because the adjacent text supplies their identity. Thinking adds a small vertical bob only in an active scene. Move reactions use a brief scale and tilt with profile-specific timing; Reduce Motion keeps portraits still. The native menu picker and stepper select the opponent in Players & board. Optional phrases use italic system text and start off.

### Computer replay

The secondary Replay computer move action sits below the board. Before the first computer move it is disabled, with a text explanation. Replay opens a native sheet with a pine background, the rival's portrait, a Georgia heading and the existing number board. Content scrolls within the sheet, including on iPad.

Replay shows the board before the move, outlines the chosen tile in gold, then shows the used tile and resulting scores. The gold outline marks the replayed move; player colors continue to identify the active row or column. Row, column and points are also written in text. Live play pauses while the sheet is open. Play again repeats the snapshot; Done returns to the live game. Reduce Motion shows the completed move immediately.

### App icon

The canonical artwork is `Race to Dog Mountain/Images.xcassets/AppIcon.appiconset/AppIcon-1024.png`. Its central angular summit, large gold sun, teal ridges and cream snow echo the opening poster. A short trail of gold square tiles connects the mountain to the number game. Preserve the clear summit silhouette and full-bleed square composition when deriving smaller icons; the platform supplies the corner mask.

The native visionOS icon uses three layers in `Vision/VisionAssets.xcassets/VisionIcon.solidimagestack`, each at the vision icon layer size. Back carries the opaque pine field and gold sun; Middle carries the mountain and snow; Front carries the near ridge and square trail. The original geometry and embedded PNG provenance come from `Tools/generate-vision-icon.swift`. Keep these native depth layers separate from the existing iOS/macOS icon.

### Watch controls and pages

The home mountain emblem and Play symbol lead directly to a fixed 4 × 4 game, with the human first against computer player 2. Move buttons show points only; a direction glyph and line number identify the current row or column. Their spoken labels include value, row, column and the next player's line. The read-only board uses watch-board-gap spacing and a 4-point inset, with cream available cells, player-colored legal cells and cream at 0.06 opacity for used cells. Replay adds a 3-point gold outline around the chosen cell.

The footer bar divides earned human points, earned computer points and remaining board points proportionally. Score/replay stays on its own page, with a person symbol, rival portrait and numeric totals. Replay opens a native sheet with close and repeat controls; live computer play pauses outside Moves, during replay or exit confirmation, and while inactive or dimmed. Every move saves for local resume.

Settings has one difficulty selector. All sixteen human portraits appear with level numbers and a selected checkmark; full names remain in accessibility labels. Watch omits board-size, player-role, biography and chat controls. Ordinary screens use icons and numbers. The native unfinished-game confirmation retains the prose needed to explain discarded progress. Existing controls on other platforms stay unchanged.

Simulator captures at 40 mm and 42 mm show clock clearance, all four initial choices, the separate footer and the other pages. Physical Watch battery, haptic comfort, live VoiceOver and largest accessibility text remain unverified. Review evidence is in `.impeccable/review/watch/review.md`.

## Do's and Don'ts

### Do:
- Do reuse the mountain geometry, circular sun and dotted trail as the app's visual signature.
- Do keep gold tied to rows and mint tied to columns, with arrows and labels.
- Do preserve readable tiles, Dynamic Type, scroll access and 44-point minimum targets.
- Do pause scenery offscreen and in the background, and freeze it for Reduce Motion.

### Don't:
- Don't introduce another game mode; Classic is the game.
- Don't open the app into player settings.
- Don't replace the mountain world with stock list or form styling.
- Don't let scenery motion drive game state or interfere with reading the board.

## Native macOS

The native macOS 14+ target shares the alpine art, Classic game and rival profiles. Windows open at 1000 × 820 points, with a 620 × 660 minimum. At widths of at least 900 points, game scores and replay form a 260-point column beside the board; compact windows retain the scrolling vertical game. Native Game/File menus expose New Game (⌘N), Replay (⌘R), player options (⌘,) and Leave Game (⇧⌘W), with Escape confirming exit. Player and replay sheets have desktop sizing. Only the visible home or game supplies menu actions and accessibility controls.
