# Unicorn Arcade Godot port

This folder is the Godot 4 parity implementation. The React/Capacitor source remains in the repository as the executable behavior reference until all 22 games and metagame systems pass parity.

## Checkpoint 01

- Portrait-first responsive shell with the original dark arcade palette and pastel cyan/pink/yellow accents.
- Versioned JSON persistence with a v1 migration path.
- Exact shared economy rules: new player starts with 1,000 coins, Sparkle owned, reward `10 + level*5`, level 1 hints free, other hints cost 5.
- Registry for all 22 games.
- Playable Coin Count port with exact target bands, denominations, exact-win, and overshoot-fail behavior.
- Playable Rhyme Rally port with the original 24 challenge records, level target formula, difficulty-window selection, and one-wrong-answer failure.
- Imported `sparkle_v1.glb` with named body/head/horn/tail/leg pivots.

That first Sparkle asset was the directional graybox. It was superseded by the six authored, rigged, textured companion packages described in the authored-companions checkpoint below.

## Checkpoint 02

- Persistent login, home, category dashboard, game lists, and profile/settings navigation.
- Progress summaries for every registered game and a live Sparkle GLB companion viewport on the home screen.
- Playable Cash Counter with the original bill set, target bands, hint rule, exact-win behavior, and overshoot failure.
- All ten word games and all five word-mystery games are now playable. Their source datasets are mechanically extracted from the React implementation into `data/word_games.json`.
- Shared implementations preserve the original difficulty window, round target formula, Caption Quest/Odd One Out caps and lives, Sight Spark timing, Chain Link validation, ordered-tap failures, keyboard rules, and Unicorn Blast speed/spawn formulas.
- Seventeen of the 22 registered games are playable. Unicorn Jump, Sliding Window, Math Swipe, Mathtris, and Galaxy Unicorn remain.

## Checkpoint 03

- All 22 registered games are playable in Godot.
- Unicorn Jump preserves exact indexed jumps, level-scaled path generation, late negative trick jumps, scrolling, and zoom controls.
- Sliding Window preserves value bands, window growth, maximum selection, rival timing, and immediate failure rules.
- Math Swipe preserves all four difficulty bands, random missing positions, two-card answers, tap/swipe acceptance, and one-error failure.
- Galaxy Unicorn is a live drag-and-auto-fire game with the original kill targets, spawn/fire curves, enemy health/speeds, fifth-level bosses, lives, pickups, and escape/collision penalties.
- Mathtris is a live 8x14 falling-block board with the original token unlocks, time/level/drop speed ramp, concurrent waves, fixed-block swaps, five-cell equation detection, gravity, score/level rules, top-out, and all six companion power behaviors.
- The five new portrait layouts have rendered review captures under `previews/alpha_v0_3/`.

## Checkpoint 04

- Companion marketplace with all six original prices, ownership, equipping, and placeable house gifts.
- Decor marketplace with the mechanically extracted 107-item catalog, all 15 category filters, search, inventory counts, purchases, and unused-item resale at a floored 50% refund.
- Unicorn Alley with six owned/locked houses and per-room decoration counts.
- Persistent room editor with a shared furniture bag, drag placement, optional 8% grid snapping, 45-degree rotation, resizing, front/back layer swaps, item removal, and confirmed room reset.
- Save schema v3 normalizes both snake-case Godot placements and legacy React camel-case placement fields while preserving the existing v2 save path.
- Metagame portrait review captures live under `previews/alpha_v0_4/`.

## Checkpoint 04.1 mobile hotfix

- Galaxy Unicorn now consumes Android screen-touch and screen-drag input before the full-screen Control can swallow it.
- Room furniture dragging is captured globally from press through release, so items keep following the finger after it leaves the original button bounds.
- Tall phones use an expanding viewport instead of a fixed 9:16 letterbox.
- Sparkle's home preview uses a correctly proportioned render target and a Godot Y-up, eye-level camera instead of the prior underside view.
- Runtime coverage includes synthetic Android drags for Galaxy Unicorn and room placement; tall-phone captures live under `previews/hotfix_v0_4_1/`.

## Checkpoint 04.2 phone follow-up

- The companion presentation band is vertically centered in the space between the identity header and Home actions.
- Galaxy Unicorn retains its original bolt speed and cadence while adding a persistent rainbow trail and swept collision, preventing one-frame-only bolts and tall-screen tunneling.
- Home now labels the Alley action as `VIEW HOUSES • UNICORN ALLEY`, and the Alley runtime gate verifies all six selectable house entries.
- Tall-phone review captures live under `previews/hotfix_v0_4_2/`.

## Checkpoint 04.3 framing follow-up

- The centered Home camera now includes safe space above the horn and below the hooves at 574x1280.
- The Home metagame action is restored to its original `UNICORN ALLEY` label.
- The selected phone review frame lives under `previews/hotfix_v0_4_3/`.

## Checkpoint 05 environment art

- Login and Home now use a newly generated magical-meadow background behind the live companion model.
- Login includes the live Sparkle preview rather than presenting only text and form controls.
- Unicorn Alley restores the original illustrated street as an interactive map with six positioned house hotspots.
- Every companion room restores its original themed background while retaining Godot drag, grid, rotation, scale, and layer persistence.
- Real-render phone review captures live under `previews/meta_art_v0_5/`.
- Furniture object sprites and contextual editing controls remain an explicit visual-parity follow-up.

## Checkpoint 06 production rooms

- All six companion rooms now use newly authored, cohesive production environment plates with clear furniture-placement floors.
- Placed decor uses original transparent item illustrations instead of placeholder word buttons or icon glyphs.
- Selecting decor opens the original six-action contextual toolbar directly beside the item.
- The furniture bag is restored as a modal bottom sheet with horizontally scrolling categories and a three-column visual item grid.
- Room previews can target a specific house with `--companion-id=<sparkle|rainbow|star|cloud|dream|mystic>`.
- Room decor is rendered as original transparent item artwork rather than emoji or text glyphs.
- Galaxy Unicorn now starts enemies at 25% of their late-game movement rate and scales smoothly to a capped 135% by level 20.
- A global safe-area layer keeps controls below phone notches, camera cutouts, and system UI on every scene.
- Unicorn Alley now uses a newly authored unified pastel street with six destination-themed doors and door-shaped hit targets placed directly over them.
- Phone-sized review captures live under `previews/production_rooms_v0_6/`.

## Checkpoint 09.2 authored companions

- Sparkle, Rainbow, Star, Cloud, Dreamer, and Mystic now use distinct production GLBs with embedded rigs, textures, and four authored clips each.
- Home and room companions idle continuously, then choose a random walk, rear-up, or signature action every 10 to 30 seconds.
- Walk actions turn the unicorn, travel across the available stage, pivot back, return to the exact starting transform, and resume idle.
- Marketplace companion cards deliberately hold a static authored pose so the catalog stays calm and easy to browse.
- Phone-frame QA covers all six home presentations, all six themed rooms, and the complete static Marketplace catalog.

## Checkpoint 09.3 animation-safe framing

- Animated companion cameras reserve extra space above horns and below hooves while keeping the Marketplace's static catalog framing unchanged.
- The frame is shifted upward without changing its viewing angle, protecting the elevated rear-up pose while retaining ground clearance.
- Room companion placement viewports are larger so the safer camera does not make the in-room unicorn feel undersized.
- Rear-up QA samples cover all six home companions plus the smaller room presentation.

## Checkpoint 09.4 updated walk-only companions

- Replaces all six companion GLBs with the supplied higher-detail textured Sparkle, Rainbow, Star, Cloud, Dream, and Mystic models.
- Retargets the verified 24 fps four-beat Walk to each model's own 38- to 45-bone anatomical chains.
- Each runtime GLB deliberately contains only `Walk`; idle, rear-up, and signature clips are deferred to a later animation pass.
- Home and room companions hold the first Walk pose between journeys, then walk out and back every 10 to 30 seconds.
- Matched three-quarter and exact side review sheets cover frames 1, 7, 13, and 19 for every variant, including tail-to-hind-leg clearance.

## Checkpoint 09.5 companion presentation correction

- Corrects the new models' opposite visual-forward axis so both legs of the room journey move head-first.
- Applies an explicit 3x display-scale multiplier to all six companion models.
- Expands and lifts the static Marketplace camera so enlarged horns, hooves, tails, and wings remain visible.
- Retains real-render phone captures for the enlarged room and six-card Marketplace presentations.

## Checkpoint 09.6 neutral presentation and safe framing

- Home now uses its own padded orthographic camera instead of inheriting the tighter animated room framing.
- Home and Marketplace hold each rig's authored neutral rest pose rather than freezing Walk frame 1, removing the asymmetric gait stance that made the front legs look distorted.
- Static and hero cameras retain visible clearance around horns, ears, hooves, tails, and Mystic's wings while preserving the uniform 3x model scale.
- Runtime checks verify the camera padding and that each stretched SubViewport keeps the same aspect ratio as its on-screen rectangle.
- NVIDIA Compatibility-renderer phone captures live under `previews/unicorn_camera_fit_v1/`.

## Checkpoint 09.7 meadow ensemble and profile presentation

- The equipped companion moves lower and closer in the Home meadow as the clear foreground hero.
- Every other owned companion appears at a smaller perspective scale across the distant meadow and uses the existing timed Walk behavior to mill around.
- Home, rooms, and Marketplace now use an opposite-facing profile camera that reads the horse silhouette and leg spacing more clearly.
- Room companion canvases expand from 210x150 to 252x180 while their orthographic camera widens proportionally, preserving apparent size with real horn and hoof clearance.
- Softer warm key, lavender fill, and reduced ambient energy retain texture detail without the prior frontal washout.
- Pixel-matched GPU review captures live under `previews/meadow_presentation_v1/`.

## Checkpoint 10 lighter art, one look, and sound

- Companion and furniture textures are stored at 1024 px (512 px for emissive/roughness maps) and Cloud's mesh is reduced from 273k to 22k triangles, in line with the other companions. `assets/` drops from roughly 800 MB to 135 MB.
- Unused room plates, the old alley map, an unused jump stone, and stray root-level concept images are removed. The nickel and $100 art now match the other currency images in framing and resolution.
- Every menu, shop, alley, room, and game screen shares one dusk-meadow backdrop (`StorybookUI.dress_dusk_backdrop`), and backdrops bleed past the safe-area inset so no dark frame surrounds the artwork.
- Answer buttons keep their requested text size (the shared restyle previously forced 19 px), and word/rhyme answers are larger.
- `AudioService` adds synthesized sound effects and a looping music-box track, driven by the existing Music and Sound effects settings. Regenerate with `python3 tools/build_audio.py`.
- Android adaptive launcher icon layers keep the whole unicorn inside the launcher mask.
- Store screenshots under `store-listing/screenshots/` are re-rendered from this build.

## Run

```powershell
Godot_v4.7.1-stable_win64.exe --path "E:\AI Projects\games\guettler\unicorn\godot"
```

## Validate

First let the editor import assets, then run the headless checks:

```powershell
Godot_v4.7.1-stable_win64_console.exe --headless --editor --path "E:\AI Projects\games\guettler\unicorn\godot" --quit-after 180
Godot_v4.7.1-stable_win64_console.exe --headless --path "E:\AI Projects\games\guettler\unicorn\godot" --script res://tests/run_tests.gd
Godot_v4.7.1-stable_win64_console.exe --headless --path "E:\AI Projects\games\guettler\unicorn\godot" res://tests/runtime_integration.tscn --quit-after 120
```

Expected results: `GODOT_PARITY_TESTS_OK: 77 checks passed` and `GODOT_RUNTIME_INTEGRATION_OK: 167 checks passed`.

## Export the Android prototype

The checked-in `Android Alpha` preset produces a debug-signed, arm64-only APK:

```powershell
Godot_v4.7.1-stable_win64_console.exe --headless --path "E:\AI Projects\games\guettler\unicorn\godot" --export-debug "Android Alpha" "build/android/UnicornArcade-0.9.8-alpha-arm64.apk"
```

Upgrade-compatible debug builds must use the established Godot user-profile keystore. Verify the APK signer before delivery: its SHA-256 certificate digest must be `97dcac80c34ab36c9b1e0da8cef5dc87c14911ffdb26d30aa0bc039f1e8be42b`. A portable Godot installation can silently create a different debug keystore; that APK is valid as a fresh install but Android will reject it as an update to 0.5 and earlier.

This checkpoint exposes the complete 22-game registry plus the companion/decor marketplace, Unicorn Alley, and room editor. Production audio, wider physical-device QA, release signing/store packaging, final character refinement, and bespoke furniture sprites remain upcoming work.

## Kid-safe ad bar (AdMob)

- **Poing AdMob plugin** (`addons/admob`, enable in Project → Plugins). Android export requires **Use Gradle Build** (see `export_presets.cfg`).
- **Android binaries** (`addons/admob/android/bin/`, gitignored): install once via the AdMob Manager in the editor, or let CI download `android-template-v4.7.1.zip` from Poing releases before export. Without these AARs, device builds have no native AdMob plugin and the ad bar never appears.
- Manifest App ID: **Project → Project Settings → AdMob → Android App ID** (matches `android_app_id` in config).
- Runtime: autoload `AdBarService` (persistent overlay) + `scripts/main.gd` / `GameExperience` (no ads on login). Copy `config/admob.example.json` → `config/admob.json`, set `ads_enabled: true` and banner unit ID for device testing (test ID first).
- Production banner unit: `ca-app-pub-2846735043546429/2606475202` after QA. Play package: `com.grapegames.wlarcade`.

## CI / Play internal testing

Pushes to **`main`** (and `godot-port`) run [`.github/workflows/deploy-android.yml`](../.github/workflows/deploy-android.yml):

1. Downloads Poing AdMob Android AARs, writes `config/admob.json` (`ads_enabled: true`, Google **test** banner).
2. Builds a signed **AAB** and uploads to Play **internal** track (`com.grapegames.wlarcade`).
3. Publishes a **debug APK** as a GitHub Actions **artifact** (`UnicornArcade-debug-apk`) — download from the workflow run and sideload on your phone.

Uses the same secrets as before (`ANDROID_KEYSTORE_BASE64`, `KEY_ALIAS`, `KEYSTORE_PASSWORD`, `SERVICE_ACCOUNT_JSON`).

To install from Play instead of sideloading: add your Google account as an **internal tester** for the app in Play Console, then open the internal testing link after a green workflow run.

