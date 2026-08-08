# Blocktopus

A Flutter block puzzle game. Drag shapes from a three slot tray onto an 8x8
grid; filling any complete row or column clears it.

The build specification is kept outside the repository. Section numbers quoted
in the code and in this file refer to it; this file covers how to run things.

## Run

```
flutter pub get
flutter run
```

Portrait only, Android and iOS. No network calls, no ads, no IAP.

## Layout

```
lib/
  app/          theme and routing
  models/       piece and shape library, level, save data
  game/         board_state, solver, game_controller, level_loader, audio
  screens/      splash, map, game, result, settings
  widgets/      board, tray, piece, boosters, goal banner, particles,
                combo text, mascot
tool/
  generate_levels.dart   offline level generator, never shipped
  generate_icon.dart     draws the launcher icon, never shipped
assets/
  levels/       15 chapter files of 100 levels each
  audio/        see assets/audio/README.md
```

`game/board_state.dart`, `game/solver.dart`, `models/piece.dart` and
`models/level.dart` have zero Flutter imports. They run inside the offline
generator and inside plain unit tests.

That purity is why the line clear animation lives entirely in
`widgets/line_flash.dart`. A completed line lights up in the colour of the
piece that closed it, holds for about 130ms, then breaks into particles as it
fades. The board has already cleared by then: `board_state.dart` clears
instantly and knows nothing about any of it, and the flash paints over cells
that are logically empty. Deferring the real clear would put an animation in
the middle of the undo snapshots and the solver, which is a much worse trade
than painting the same blocks for a quarter of a second.

Over the top of that, `widgets/combo_text.dart` floats the score and a streak
word. Section 10.3 starts the word ladder at streak 3 with `Nice`; `Combo` was
prepended at streak 2 on the owner's call, because two clears back to back is
the most common combo in the game and it had no callout at all. Section 3 caps
font weight at 600, so the words get their presence from a stroked outline and
a short scale overshoot rather than a heavier face.

## Levels

Levels are generated offline, validated by the solver, then curated. Nothing
ships that the solver could not solve inside its move limit.

```
dart run tool/generate_levels.dart                    # all 15 chapters
dart run tool/generate_levels.dart --chapters=1,2     # a subset
dart run tool/generate_levels.dart --candidates=45000 --keep=300
```

Options: `--chapters`, `--candidates`, `--keep` (candidates retained per chapter
before curation), `--nodes` (solver node budget), `--diffnodes` (budget per
first move when scoring difficulty), `--isolates`, `--seed`, `--out`.

Generation is parallel across isolates and takes hours at full budget. Each
chapter is written as soon as it finishes, so a run can be resumed chapter by
chapter.

## Audio

Every sound is synthesised offline from sine partials, filtered noise and
envelopes. Nothing is sampled or taken from another game.

```
dart run tool/generate_audio.dart
```

The generated files are committed, so a clean checkout builds a game with
sound. They are placeholders: good enough to play with, and meant to be
replaced by commissioned audio. See `assets/audio/README.md` for the two format
deviations and how to swap them out.

Settings carries a toggle and a 0-100% slider for effects and for music. The
toggle and the slider are separate on purpose: silencing music and setting it
to zero are different intents, and a player who switched music off should not
have to remember where they left the bar.

`AudioService` never permanently gives up on a sound after a single failure.
The audio backend fails transiently, and treating one caught exception as
"this sound is missing" silenced it for the whole session with no cure but
restarting the app. It now counts consecutive failures per sound, gives up
only after three, and clears every counter whenever a sound setting is
touched, so the settings screen is also the recovery path.

## Icon

```
dart run tool/generate_icon.dart
```

Rasterises the mascot head flat on `bg` and writes the Android mipmaps, the iOS
app icon set and `store/`. The mascot inside the app is always painted in code;
this only produces the launcher bitmap the platforms require.

## Tests

```
flutter test --exclude-tags slow               # unit, widget and golden tests
flutter test --tags slow                       # re-solves every shipped level
flutter test --update-goldens                  # after an intentional visual change
```

The exclusion is a command line flag rather than a `skip:` in `dart_test.yaml`,
because a `skip:` there fires even when the tag is asked for by name: the sweep
reported "All tests skipped" and exited 0, so CI went green having proved
nothing. The CI job now also counts what passed and fails if the sweep did not
really run.

| File | Covers |
|---|---|
| `board_state_test.dart` | placement, simultaneous clears, scoring, streak, game over |
| `game_flow_test.dart` | controller, boosters, save data, and a real drag on the real screen |
| `layout_test.dart` | every screen and state at 320x568 up to 430x932, plus large system fonts, so overflows fail the build |
| `particle_test.dart` | the 400 particle cap, decay, and the single painter |
| `line_flash_test.dart` | a completed line lights up, holds, then bursts; an undone one never bursts |
| `screen_golden_test.dart` | whole screens, plus the lit line and its callouts |
| `audio_assets_test.dart` | every sound in section 11.1 exists, all eight ladder rungs, size budgets |
| `audio_recovery_test.dart` | a transient audio failure recovers instead of silencing a sound for the session |
| `volume_settings_test.dart` | the volume sliders, their persistence, and old saves without them |
| `level_curve_test.dart` | difficulty rises, every 10th is a breather, bosses are tighter |
| `board_view_golden_test.dart` | the board empty, mid game, and with a ghost |
| `screen_golden_test.dart` | whole screens: game, tutorial, map, result, settings |
| `level_validity_test.dart` | re-proves all 1500 levels. Tagged `slow`, CI only |

## Releasing

Signing is read from `android/key.properties`, which is gitignored. Copy
`android/key.properties.example`, create a keystore, and fill it in. Without
that file the release build falls back to debug keys so `flutter run --release`
still works locally; that build cannot be published.

```
flutter build appbundle --release     # what Play wants
flutter build apk --release --split-per-abi
```

Release builds run R8 with `android/app/proguard-rules.pro`. Store copy, the
privacy policy and the Play data safety answers are in `store/`.

CI (`.github/workflows/ci.yml`) runs format, analyze and the fast tests on
every push; the level validity sweep and an app bundle build as separate jobs;
and fails the build if the arm64 release APK goes over the 40 MB budget.

## Before the first release

- The bundle id is `com.bloctopus.game`, set by the owner. Note the spelling:
  the app is Blocktopus, the id is bloctopus. Confirm this is intended before
  the first publish, because it can never be changed afterwards.
- Replace the generated placeholder audio with commissioned sound. See
  `assets/audio/README.md`.
- Confirm the name is free on Google Play, the App Store and as a domain.
- Capture store screenshots on a device, and draw the 1024x500 Play feature
  graphic. Everything else in `store/` is written.
- Play levels 1 to 30 by hand and fix the onboarding, per section 13 step 9.
