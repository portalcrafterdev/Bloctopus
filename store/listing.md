# Store listing

Draft copy for Google Play and the App Store. Sentence case, no exclamation
marks, matching the mascot's voice: plain, warm, short.

**Nothing here may reference or compare against another game by name.**

## Names

- App name: **Blocktopus**
- Store title: **Blocktopus: Block Puzzle**
  (30 characters on Play. "Blocktopus: Block Puzzle" is 24.)
- Application id / bundle id: `com.bloctopus.game`
- Developer name: _to be confirmed_

## Short description (Play, 80 characters max)

> Drag blocks, fill rows and columns, clear them. 1500 levels, no timer.

68 characters.

## Full description (Play, 4000 characters max)

> Blocktopus is a block puzzle you can put down.
>
> Drag shapes onto an eight by eight grid. Fill a full row or a full column and
> it clears. Fill several at once and the board opens up under you.
>
> There is no timer and there are no lives. You play a level until you solve it
> or run out of room, and then you try again. Every one of the 1500 levels was
> checked by a solver before it shipped, so a level is never impossible and is
> never a matter of luck.
>
> Descend fifteen ocean chapters, from the tide pools down to the ink depths.
> Each one introduces a single new idea and gives you a hundred levels to get
> comfortable with it: move limits, jelly that clears when a line passes
> through it, stone that softens before it breaks, and blocked cells that never
> move at all.
>
> Three boosters when a board gets tight. Rewind takes back your last piece.
> Ink blast removes a single block. Reshuffle trades your whole tray for a new
> one.
>
> - 1500 levels across 15 chapters
> - No timer, no lives, no energy to wait for
> - Plays completely offline
> - No ads
> - One small octopus, watching you place every piece

## App Store subtitle (30 characters max)

> Block puzzle, 1500 levels

25 characters.

## Keywords (App Store, 100 characters)

> block,puzzle,blocks,grid,brain,offline,logic,relax,tile,fit,shape,drag,no wifi

## Category and rating

- Category: Games > Puzzle
- Content rating: everyone. No violence, no user content, no purchases, no ads.

## Assets

| Asset | Size | Status |
|---|---|---|
| App icon | 512x512 | `store/icon_512.png` |
| App icon (App Store) | 1024x1024 | `store/icon_1024.png` |
| Feature graphic (Play) | 1024x500 | **needed** |
| Phone screenshots | at least 2, 16:9 or 9:16 | **needed, capture on device** |
| Tablet screenshots | optional | not planned for v1 |

Screenshots worth taking, in order: a board mid-clear with particles flying,
the map showing a chapter banner, a three star result sheet, a jelly level from
chapter 5, and a boss level banner.

## Data safety and privacy

Blocktopus collects nothing. It makes no network calls at all. The only data it
stores is a single local save blob under `blocktopus_save_v1`, holding
progress, stars, booster counts and settings; it never leaves the device and is
removed when the app is uninstalled.

Play Data safety answers:

- Does your app collect or share any of the required user data types? **No**
- Is all of the user data collected by your app encrypted in transit? **Not
  applicable, no data is transmitted**
- Do you provide a way for users to request that their data is deleted?
  **Not applicable, uninstalling removes the local save**

A privacy policy URL is still required by Play even for an app that collects
nothing. `store/privacy.md` is the text to publish.
