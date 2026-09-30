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
rounded:
  field-tile: "12px"
  button-score: "16px"
  board: "20px"
spacing:
  grid: "6px"
  small: "12px"
  medium: "16px"
  section: "24px"
  page: "28px"
  wide-page: "48px"
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
---

# Design System: Race to Dog Mountain

## Overview

**Creative North Star: "The Alpine Travel Poster"**

A cream serif title sits above geometric mountain ridges and an amber sun. Deep pine sky, drifting cloud lines, stars and a dotted climbing trail make the opening scene recognizable before any controls appear. The number board carries the same colors into play.

Classic is the only game. The home screen offers Play immediately; player configuration stays behind a secondary action. Rules and player settings use a quiet pine background with the same typography and palette. Results remain inside the mountain scene.

**Key Characteristics:**
- Layered angular ridges, a circular sun and a winding dotted trail.
- Cream Georgia display type with readable system text for controls.
- Gold rows and mint columns, each also identified by words and arrows.
- Background motion isolated from game state and controls.
- Illustrated human hiker rivals with named levels and small portrait reactions.

Implementation source: `Race to Dog Mountain/MountainViews.swift`. Frontmatter lengths translate native points into CSS pixels for portable previews; SwiftUI Dynamic Type remains the runtime authority. Color percentages preserve the source's normalized RGB values.

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

## Typography

Georgia-Bold supplies the poster title, scores and result headings. System text handles instructions, controls and player labels. Scores and tile numbers use monospaced digits.

The home display uses the display token on phones, a larger 76-point base above 600 points of available width, and a 32-point base at accessibility text sizes. SwiftUI scales these custom fonts relative to large title. The home title alone uses tight tracking. Settings, rules and results use smaller Georgia headings with bases of 32, 36 and 30 points.

## Layout

The home scene fills the screen behind a scrollable leading-aligned composition. Its content is centered within a maximum width of 760 points. Horizontal padding grows from the page token to the wide-page token above 600 points. Safe-area content stays readable while scenery extends to every edge. Play appears before the board and player summary. Accessibility text sizes omit the decorative subtitle and shorten the spacer above Play.

Game content is centered within 792 points. The two player scores lead into a turn label and the square number grid. Scores sit side by side and stack at accessibility text sizes. The board uses the grid spacing token and a 12-point inset. Cells grow to 76 points and retain a Dynamic Type-scaled minimum of 44 points; large boards scroll horizontally instead of shrinking targets. Rules and settings center readable content within 620 points.

## Elevation & Depth

Depth comes chiefly from overlapping ridges and darker board backing. The sun has a soft gold halo. A dark overlay quiets the scenery during play. Primary buttons have a low black shadow, and filled tiles have a short shadow that separates them from the board. Score panels use player-colored translucent fills and an active underline.

The scenery alone redraws through Canvas and TimelineView at up to 30 frames per second. It pauses when covered or backgrounded. Reduce Motion freezes scenery and removes press springs and numeric score transitions. Winning adds gold and mint confetti; the calm alternative is static.

## Shapes

Mountains use angular paths, with a circular sun and curved dotted trail. Controls use comfortable rounded rectangles. Tiles stay square with the field-tile radius; buttons and score panels share the button-score radius. The board has the larger board radius. Game header actions use circular 48-point targets.

## Components

### Buttons

The gold primary button uses dark pine text and a minimum height of 56 points. Secondary buttons use translucent cream. Both have a short spring press to 96% scale. Tile buttons use their own style with a 90% press scale so disabled cells retain the intended cream fill and dark numbers.

### Inputs / Fields

Player names use cream text on a translucent rounded field with 16-point padding. The row or column label above each field carries the matching rivalry color and arrow. Native toggles and the board stepper preserve keyboard, accessibility and interaction conventions.

### Navigation

Home places a paw symbol opposite How to play. At accessibility text sizes, that action becomes an icon with its spoken label retained. Rules and settings open as native sheets with Done actions. Play opens a full-screen game with circular close and player controls. An unfinished game requires confirmation before leaving.

### Score panels

Each panel carries its player's name, Georgia score, directional arrow and turn label. The active player gets a stronger tinted fill and a bottom underline. Numeric transitions follow score changes unless Reduce Motion is enabled.

### Number board

Legal cells take the active player's color and a cream border. Other available cells stay cream. Used cells are faint, with a paw mark or the latest points gained. Direction labels and VoiceOver row/column announcements explain the highlighted line without relying on color alone.

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
