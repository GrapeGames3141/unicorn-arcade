# Unicorn Arcade — bugs and polish backlog

Reviewed September 11, 2026, against commit `4a68b13`.

This is an actionable review of the **23 games registered in the Godot arcade**, the shared interface, rooms, and 3D assets. The older React version is outside this review's primary scope.

Evidence comes from current source, direct inspection of the six shipped unicorn GLBs, and saved visual previews. **This was not a live playtest.** The prescribed Windows Godot installation and `cmd.exe` are absent from this Linux workspace, so the project wrapper could not be used for runtime verification. Saved screenshots may predate current UI changes. Items below distinguish source findings, visual observations, and checks still needing reproduction.

Priorities: **P1** = address in the next quality pass; **P2** = improve before a polished release; **P3** = later enrichment. Checkboxes mean work remains open, not that a bug has been reproduced on a device.

## Implementation progress — September 11, 2026

The first gameplay pass implements **B01–B05**. Their original findings remain below for context. Checked implementation tasks still need the separate physical-device checks at the end of this document.

- **Shared pause:** Help/tutorials, profile, leave confirmation, focus loss, and app backgrounding pause the game subtree and its timers/input. Nested dialogs keep the game paused until all pause reasons clear. Run timing and Mathtris difficulty/slow effects use active play time. Reduced-motion Unicorn Jump landings also respect pause. Navigation with an open dialog avoids querying a detached scene.
- **Math Swipe:** Taps and short/long swipes use one pointer gesture; keyboard button activation works. Accepted answers lock immediately, and stale deferred question changes are discarded. Wrong answers explain the complete equation.
- **Mathtris:** Top-out now finishes an endless run, saves score/highest stage/personal best, and awards **one coin per 100 points, capped at 250 before companion bonuses**. Empty runs earn no coins. Duplicate top-out calls cannot duplicate results or rewards. PLAY AGAIN starts at stage 1; the profile shows BEST and run count. Cascades update the stage after all points are counted.
- **Verification:** The added [`runtime_polish_integration.gd`](../godot/tests/runtime_polish_integration.gd) covers modal nesting, application pause, timer preservation, scene teardown, reduced-motion jumps, input dispatch, duplicate submissions, cascade progression, and serialized save/profile round-trips. It runs in an isolated in-memory save session and is included in the CI manifest. The bounded suites now also use isolated save sessions because Mathtris top-out writes results.
- **Results:** All **83 focused regression checks** pass without script/runtime errors. Parse smoke loads 98 app scripts. The existing gameplay-correctness, three level-run, outcome, profile, Galaxy pause, bounded number/word, parity-rule, main-shell, dead-code, and ad-layout checks pass their assertions. The parity-rule and first level-run runners still emit resource-cleanup diagnostics at process exit; those are not claimed as clean-shutdown passes. Full CI and physical-device validation have not been run in this pass.
- **Environment:** Implementation testing uses installed Linux Godot **4.7.1.stable.official.a13da4feb**, matching the prescribed Windows engine version. Logs and disposable Linux test data are under git-ignored `.tools/`. This is automated headless testing, not a physical-device or rendered art approval.
- **Still open:** B06/B07, all 3D model tasks, the broader design improvements, and physical-device verification. No 3D meshes or textures have been modified in this pass.

### Second pass — companion loading and presentation

- **B07, companion portion implemented:** Home's six unicorns and animated room/game previews now use the shared threaded loader. Room/game previews display the existing portrait while loading and retain it if loading fails. Cached callbacks remain deferred; weak references and cancellation prevent late loads from populating departed pages. Furniture loading and device profiling remain open.
- **Animation rendering fixed:** A loaded animated companion previously triggered `request_redraw()`, switching its viewport from continuous rendering to a single frame. Animated companions now retain `UPDATE_ALWAYS`; static previews still render on demand. Movement requested before the model arrives is applied after loading.
- **Reduced motion:** Companion animators stop optional roaming and walking when the setting is enabled, including in Home. Turning the setting off restores either automatic roaming or the explicitly requested motion. Retired meadow viewports stop processing as well as rendering.
- **Contact shadows:** Meadow shadow meshes now have a dark translucent material and do not cast a second shadow; previously they used the default opaque material. This material change still needs rendered/device review.
- **Verification:** The added [`runtime_companion_polish_integration.gd`](../godot/tests/runtime_companion_polish_integration.gd) passes **20 checks**, including cold/warm loads, pending motion, fallback portraits, cancellation, continuous rendering, reduced motion, and late arrivals in inactive scenes. It is included in CI. Existing Home and room tests now wait for asynchronous models rather than assuming immediate instantiation; the meta and refactor suites pass their assertions. The refactor runner emits cleanup diagnostics at exit. One parallel Home headless run emitted a dummy-renderer texture error; an isolated rerun passed without diagnostics, so real-renderer/device validation remains necessary.
- **Cloud geometry still open:** Blender and mesh-simplification tooling are absent from this workspace. Cloud has not been decimated, and none of the six character GLBs or textures have been changed. A01/A02 still require mesh editing and visual validation.

### Third pass — furniture loading — September 12, 2026

- **B07 loading implementation complete:** Room furniture previews now request model sheets through the shared threaded loader. Items from the same sheet share a load, show an existing catalog thumbnail while waiting, and preserve rotations chosen during loading. Canceled previews ignore late callbacks; failed loads use procedural fallback geometry. The synchronous builder remains available for offline callers.
- **Static rendering:** Furniture renders on demand, including when callers omit the animation option. Loading, resizing, and rotation request fresh frames.
- **Preview capture:** The decor cache and thumbnail generator wait for model readiness before capturing, with a bounded timeout. This prevents capturing the initial shadow-only viewport while the model is still loading. Rendered capture still needs visual verification; asset thumbnails have not been regenerated.
- **Verification:** The new furniture regression suite passes **15 checks**. The companion suite passes **20 checks**, the original six furniture models pass, and the complete catalog verifies **107 authored models**. Catalog runners now use scenes so autoloads are available and are included in CI alongside the furniture suite. Existing meta and refactor checks pass their assertions; the refactor runner retains its previously observed exit-cleanup diagnostics.
- **Still open:** B06 audio, character/furniture mesh and texture improvements, rendered review, and device measurements. Threaded resource loading does not remove main-thread scene instantiation cost; no frame-time or memory improvement is claimed without profiling.

## Start here

1. Fix pause behavior, Mathtris progression, and Math Swipe input.
2. Reduce Cloud's unusually dense mesh and investigate cold character-loading stalls.
3. Repair unicorn leg deformation and unify character/furniture lighting with the rooms.
4. Improve teaching feedback and distinguish the word games visually.
5. Run the device checklist at the end before considering these items complete.

## Bugs and implementation gaps

### B01 — P1: Gameplay continues behind dialogs

- [x] Introduce shared pause/resume behavior for tutorials, profile, leave-run confirmation, and application interruptions.
- **Source finding:** [`game_experience.gd`](../godot/autoload/game_experience.gd), `_show_leave_run_modal()` and `_show_profile_overlay()`, create overlays without pausing the game. The leave dialog even says “STORYBOOK PAUSE.” `_maybe_show_tutorial()` only pauses Galaxy Unicorn. Sliding Window, Mathtris, Comet Math Rescue, and Unicorn Blast continue updating while active; Sight Spark's flash timer can also expire during its tutorial.
- **Effect:** A player can lose time, miss a word, or lose a run while reading. Global `_input()` handlers also need modal guards; an overlay's mouse filter alone is not a complete input lock.
- **Verify/fix completion:** Open each dialog for ten seconds in every timed game. Rival position, falling objects, lives, and answer state must remain unchanged. Resume once, with a brief countdown where useful. Exclude paused time from [`LevelRunController.elapsed_ms()`](../godot/scripts/games/level_run_controller.gd) and any wall-clock difficulty calculations.

### B02 — P1: Mathtris has no persistent run result or reward path

- [x] Give Mathtris an explicit endless-game result contract: save best score, runs played, highest stage, and an appropriate coin reward once per run.
- **Source finding:** [`mathtris.gd`](../godot/scripts/games/mathtris.gd) always begins at level 1, changes its local level from score, and ends through `level_run.fail()`. It never calls `complete_level()` or `level_run.complete()`, and does not otherwise save the score. The common progress/reward write lives in [`AppState.complete_level()`](../godot/autoload/app_state.gd).
- **Effect:** Playing Mathtris does not contribute completed progress or coins through the normal arcade system, and the final score disappears after the session. An endless mode should present a finished run and personal best rather than treat every ending as an ordinary failed level.
- **Verify/fix completion:** Score points, top out, reopen the game/profile, and confirm the result persists. Retry and repeated outcome-button taps must not award the same run twice. Preserve starting at stage 1 if that is the intended endless rule.

### B03 — P2: Mathtris level can lag behind cascade score

- [x] Calculate the difficulty level after all cascade points have been added.
- **Source finding:** `_clear_matches()` in [`mathtris.gd`](../godot/scripts/games/mathtris.gd) sets `level = score / 700 + 1` before the cascade loop, then adds cascade points without updating the level again.
- **Verify/fix completion:** Trigger a cascade that crosses a 700-point boundary; the displayed stage and next drop's difficulty should immediately agree with the final score.

### B04 — P1: Math Swipe ignores ordinary short swipes and keyboard activation

- [x] Replace the gap in gesture acceptance with a clear tap/drag/cancel policy and connect accessible button activation.
- **Source finding:** `_card_input()` in [`math_swipe.gd`](../godot/scripts/games/math_swipe.gd) accepts movement only when it is **less than 5 or greater than 80 pixels**. A 5–80 pixel gesture does nothing despite the instruction “Swipe in any direction, or tap.” Cards connect `gui_input` to mouse/touch handling but have no `pressed` callback or keyboard submission branch.
- **Verify/fix completion:** Test a tap and 10, 40, 80, and 100 pixel gestures; valid selections should behave predictably. Focus a card and activate it with Enter/Space. Each accepted gesture must submit exactly one answer.

### B05 — P1 investigation: Math Swipe can process the same answer during a pending round change

- [x] Lock the current question immediately after accepting an answer, and ignore stale input until the next question is ready.
- **Source risk, runtime reproduction needed:** `_submit()` schedules `_new_problem.call_deferred()` after a correct non-final answer while leaving `active` and both cards enabled. Another submission before that deferred call can increment `completed` for the same question. The handler also accepts both mouse and touch event families.
- **Verify/fix completion:** Exercise rapid taps, two fingers, and touch with mouse emulation. A question may increment progress only once, and a queued refresh must not re-enable cards after the run ends.

### B06 — P2: Music and sound settings have no gameplay audio implementation

- [ ] Implement music/effect playback and connect both settings, or hide the controls until they do something.
- **Source finding:** [`profile_view.gd`](../godot/scripts/ui/profile_view.gd) exposes Music and Sound effects, and SaveService persists them. No audio-player implementation or `AudioStream` usage was found in the reviewed Godot scripts/scenes; no `.mp3`, `.wav`, or `.ogg` files were found under `godot/assets`.
- **Verify/fix completion:** Add restrained selection, correct-answer, mistake, reward, and room-placement sounds. Toggle each setting, navigate between scenes, and restart; the setting must persist and affect the correct audio category.

### B07 — P1 performance investigation: Animated character loads can block the main thread

- [x] Use the existing asynchronous asset loader consistently and show a lightweight placeholder while loading.
- **Progress:** Implemented for Home companions, room/game companion previews, and furniture previews in the second and third passes above.
- [ ] Measure cold-load frame stalls and memory on a lower-end device, including main-thread scene instantiation.
- **Source finding:** [`room_companion_preview_builder.gd`](../godot/scripts/meta/room_companion_preview_builder.gd), `build()`, uses synchronous `ResourceLoader.load()` on a cache miss for animated companions; static companions use the asynchronous path. [`room_authored_furniture_loader.gd`](../godot/scripts/meta/room_authored_furniture_loader.gd) also synchronously loads and retains furniture scenes.
- **Measured context:** Character GLBs range from approximately 34 to 64 MB on disk. This makes cold loads a concrete profiling target, although actual stall duration and runtime memory have not been measured here.
- **Verify/fix completion:** Profile the first visit to Home, a room, and a game using each companion, plus first placement from each furniture sheet. Record frame stalls and memory on a lower-end Android device; loading must keep navigation responsive.

## Improvements for every arcade game

These are **design/polish tasks**, except where they refer to a source finding above. Sources are the [game controllers](../godot/scripts/games), [shared word-game strategies](../godot/scripts/games/word_game.gd), and [word content](../godot/data/word_games.json).

| Game | Priority | Improvement / issue to address | Completion check |
| --- | --- | --- | --- |
| Unicorn Jump | P2 | Teach whether the current stone counts, make backward jumps unmistakable, and keep the current stone plus valid landing readable when the camera moves. | Complete forward and backward trails on a narrow screen; pan/zoom must not accidentally choose a stone. |
| Sliding Window | P1 | Fix B01. Review finish fairness: the rival wins as soon as it enters the final window, but the player must also answer that final window. Explain “maximum” with a visual example. | Decide and document equal finish rules; test tied maximum values and both racers reaching the last window. |
| Coin Count | P2 | Show selected coins in a counting tray, denomination names, and remaining cents. Add undo in a practice mode; retain strict overshoot failure for a challenge mode if desired. | Children can explain the total and correct one mistaken coin without restarting practice. |
| Cash Counter | P2 | Show bill counts and the running sum; introduce “pay for an item” and change-making lessons after basic totals. Early overshoots need an explanation. | Values stay readable with large bills and three-digit totals; valid combinations all work. |
| Math Swipe | P1 | Fix B04/B05; add clear card movement/selection feedback and show the completed equation after a mistake. | Tap, swipe, touch, and keyboard each submit once; feedback explains the arithmetic. |
| Mathtris | P1 | Fix B01–B03. Teach a legal five-tile equation with a playable example, distinguish falling/settled/selected tiles, and briefly highlight an equation before clearing it. | A new player can make a swap and understand why an equation clears; small-screen board text remains legible. |
| Unicorn Blast | P1 | Fix B01; check the virtual keyboard against the falling-word play area. Add target emphasis, readable hit feedback, and a beginner speed option. | The keyboard never hides the deadline/cannon or the word being typed; a missed word clearly explains the lost heart. |
| Rhyme Rally | P2 | Add optional recorded word pronunciation and feedback about matching sounds, rather than relying only on written options. | Review every rhyme by sound, including accent-sensitive examples; audio can be replayed without affecting progress. |
| Sentence Sprout | P2 | Add capitalization/punctuation and a sentence readback. Review whether alternative grammatical orders should be accepted; the strategy currently expects one exact sequence. | Content review records accepted orders, and an incorrect choice explains the intended sentence. |
| Missing Magic | P2 | Give blanks enough sentence context; explain why the chosen word fits. Expand beyond the current 18 entries. | Each prompt has one intended answer or explicitly accepts alternatives; no ambiguous failure. |
| Sight Spark | P1 | Fix tutorial/flash timing in B01, and offer adjustable flash duration. First-level hints currently retain the word after the flash: label that as practice. | A new player actually sees the word before recall starts; keyboard opening does not obscure input. |
| Prefix Potion | P2 | Explain how a prefix changes meaning. Some distractors are themselves real words, so “brew a real word” should explicitly mean using the displayed prefix and root. | Feedback distinguishes the requested construction from other valid words. |
| Vowel Vines | P2 | Keep instructions consistent about matching the printed first letter versus its sound; make the vine grow with progress. | Content and tutorial agree on the learning objective; each option is legible and unambiguous. |
| Letter Lift | P2 | Decide whether this is copying or recall: beyond the first level, `_render_letter_lift()` still reveals the next letter. Handle deletion and multi-character keyboard/IME input deliberately. | One-letter typing, backspace, paste, and mobile composition have predictable behavior; difficulty matches the stated objective. |
| Syllable Stamp | P2 | Add optional spoken syllables and a clap/tap rhythm. The current hyphenated word already displays its segmentation; consider a separate challenge without that scaffold. | Review syllable splits by pronunciation and make practice versus challenge explicit. |
| Caption Quest | P2 | Replace emoji-only scene prompts with consistent illustrations and add short explanations. | The intended action is visually clear across platforms; a wrong answer explains the relevant scene detail. |
| Opposite Orbit | P2 | Put ambiguous words in short contexts and animate the correct pair together. | Every antonym choice matches the intended meaning, especially words with multiple senses. |
| Scramble Spell | P2 | Make the clue prominent, add undo in practice, and support duplicate letters as distinct selectable tiles. | Repeated letters can be used exactly as often as supplied, and the clue distinguishes plausible anagrams. |
| Odd One Out | P2 | Reveal the category rule after an answer and replace inconsistent emoji with authored pictures. | Content review confirms one intended outsider under the stated rule. |
| Size Line-Up | P2 | Say “shortest word” or “fewest letters,” visually count letters, and define how future equal-length words are handled. | Order depends on letter count, not object size or rendered text width. Current 16 entries passed the static length-order/tie check. |
| Chain Link | P2 | Build a visible chain across successive choices instead of isolated questions; connect the final and initial letters visually. | All offered words satisfying the last-letter rule are accepted, and the chain reads clearly. |
| Galaxy Unicorn | P1 | Extend pause protection beyond its tutorial (B01); improve enemy/pickup silhouettes, damage feedback, and boss arrival warnings. | Players can distinguish threats, pickups, and invulnerability without color alone; overlay taps do not steer the player. |
| Comet Math Rescue | P1 | Fix B01; clarify that choosing a lane selects an answer and show the resolved equation. Add a practice pace. | Every correct answer is reachable; timeout, wrong answer, and rescue feedback are distinct. |

## 3D models and scene presentation

### A01 — P1: Bring Cloud into the same mesh budget as the other unicorns

- [ ] Retopologize or carefully simplify Cloud, preserving the face, silhouette, and joint deformation; rebake details as needed.
- **Measured from GLB index accessors:** Cloud contains **273,186 triangles** versus **10,259–10,354** for the other five companions—approximately **26 times as many**. This is source mesh complexity, not a measured frame-time result or a count of imported Godot LODs.

| Character | Source triangles | GLB size, decimal MB | Embedded animation clips |
| --- | ---: | ---: | --- |
| Sparkle | 10,354 | 37.37 | Walk |
| Rainbow | 10,354 | 36.92 | Walk |
| Star | 10,354 | 40.52 | Walk |
| Cloud | 273,186 | 34.06 | Walk |
| Dreamer | 10,354 | 41.03 | Walk |
| Mystic | 10,259 | 64.07 | Walk |

Source: [`godot/assets/characters/unicorns/`](../godot/assets/characters/unicorns/), the six models referenced by [`CompanionAssetCatalog`](../godot/scripts/meta/companion_asset_catalog.gd). All six already contain a skin/rig; “add a rig from scratch” would be an outdated recommendation.

### A02 — P1: Repair character deformation before adding surface detail

- [ ] Clean up shoulder/hip topology and skin weights, especially where a raised leg joins the body. Check elbows, hocks, and hoof contact throughout the whole walk.
- **Visual evidence:** The saved [Sparkle walk contact sheet](../previews/unicorn_walk_only_v1/review_sparkle.png) shows pinched, angular folds around the moving upper legs, particularly frames 13 and 19. This is a saved-render observation, not a new capture of the current build.
- [ ] Review all six models from front, side, rear, and three-quarter angles under neutral light; check mane/tail intersections, facial symmetry, horn attachment, and wing joins where present.
- **Completion:** No collapsing joints or visible tears through a full cycle. Review the actual phone-size render as well as a large turntable; preserve the established character designs.

### A03 — P2: Give the unicorns a small, expressive animation set

- [ ] Add a breathing/blinking idle, an attentive head turn, a celebration, and a gentle mistake reaction. Blend movement into standing and match stride to travel speed.
- **Source finding:** All six current GLBs contain only `Walk`; [`UnicornIdleAnimator`](../godot/scripts/meta/unicorn_idle_animator.gd) alternates walking with a standing pose.
- **Completion:** No foot sliding, sudden turn snaps, or pose pops. Reduced motion should suppress optional roaming and exaggerated reactions without hiding gameplay information.

### A04 — P2: Improve materials and lighting as one coordinated pass

- [ ] Separate coat, mane, hoof, horn, and eye material responses: soft matte coat, restrained mane highlights, crisp eye highlights, and controlled metallic horn details.
- [ ] Match the direction, color, exposure, and contact shadows of the 3D objects to each room's painted lighting. Establish consistent apparent scale and camera perspective.
- **Evidence:** [Mystic's saved room preview](../previews/meadow_presentation_v1/room_mystic_side.png) illustrates how bright small decor can appear detached from the detailed room background. Current [`RoomPreviewViewport`](../godot/scripts/meta/room_preview_viewport.gd) uses a common key/fill lighting setup across item previews.
- **Completion:** Characters and furniture look grounded in all six rooms; pale coats retain shading and metallic parts do not dominate. Recheck the current build before treating the older screenshot's layout as a current defect.

### A05 — P2: Clean up furniture silhouettes and construction details

- [ ] Straighten edges and align supports, drawers, trims, knobs, and decorative elements; clean noisy texture streaks and unintended dents while preserving the rounded toy-like style.
- **Visual evidence:** The [sheet 03 furniture preview](../previews/store_items/sheets/store_items_sheet_03/store_items_sheet_03_processed_contact.png) shows uneven drawer outlines and vertical texture streaking on the desk/nightstand; small pool-table details merge into soft shapes.
- [ ] Review items at all eight supported rotation angles, not just the catalog thumbnail. Confirm back/underside quality, floor pivots, object scale, and wall versus floor placement.
- **Completion:** Each item is recognizable at placement size, sits correctly in the room, and remains presentable when rotated.

### A06 — P2: Reduce asset cost without flattening the art

- [ ] Audit embedded texture dimensions, duplication, and channel use in the 34–64 MB character files; choose export texture sizes based on the largest actual screen presentation.
- [ ] Measure imported GPU memory, cold-load time, and draw calls separately from source file sizes. Add suitable LODs and verify Cloud's imported result after optimization.
- [ ] Review furniture scene caching and release unused previews/resources during long room-editing sessions.
- **Completion:** Record before/after device measurements and matched screenshots. Avoid judging quality solely by triangle count or declaring a memory improvement from a smaller GLB alone.

## Shared arcade and room polish

- [ ] **P2 — Teach through interaction.** Replace some three-page text tutorials with a safe first action, a highlighted target, and one short instruction. Replay help without restarting a run.
- [ ] **P2 — Explain mistakes.** Show the correct equation, counting step, word relation, or sorting rule before retry. Offer a forgiving practice mode alongside timed/strict challenges.
- [ ] **P2 — Give games distinct identities.** The word games share useful controller/UI code, but deserve different scene art, progress animation, and reward feedback: potion mixing, growing vines, sentence gardens, orbiting pairs, and a visible word chain.
- [ ] **P2 — Expand and curate word content.** Current catalog pools are small: 14 caption scenes, 14 odd-one-out puzzles, 16 syllable entries, 16 size lineups, and 18 each for missing-word and prefix games. Avoid immediate repeats and review difficulty by reading skill, not only entry position.
- [ ] **P2 — Make hints understandable.** Display cost before use, distinguish a clue from revealing the answer, and make companion assistance consistent. Check that ineffective/repeated hints do not unexpectedly consume coins.
- [ ] **P2 — Clarify progression.** Explain what profile rings count and how endless games differ from level games. Add best results and meaningful milestones; avoid making a capped ring imply all content is finished.
- [ ] **P2 — Audit narrow screens and keyboards.** Keep the mission, active play area, and primary controls visible with safe areas, ads, and the virtual keyboard present. Scale overly large headings and avoid redundant HUD text.
- [ ] **P2 — Complete accessibility behavior.** Verify keyboard focus, readable contrast, symbols/text alongside color, and reduced-motion coverage for meadow movement, camera motion, particle effects, and character previews.
- [ ] **P2 — Make the room editor easier to correct.** Add undo/redo and a preview before resetting a room. Keep placement tools close to the selection, clarify wall/floor attachment, and improve overlapping-item selection.
- [ ] **P2 — Make purchases tangible.** Show an accurate model preview, owned/placed/available quantities, insufficient-funds feedback, and an immediate route to place new furniture.
- [ ] **P3 — Add restrained rewards and atmosphere.** Small celebrations, room ambience, companion reactions, and occasional unlock milestones will make correct answers feel connected to the arcade world.
- [ ] **P2 — Refresh project documentation.** The main README still describes the React stack and says word games are “coming soon.” Add a current Godot run/build guide and the real game roster.

## Device verification checklist

These are **tests to perform**, not additional confirmed bugs.

- [ ] For all 23 games: fresh profile → tutorial → correct action → wrong action → hint → retry → next run/level → category → reopen and verify saved progress.
- [ ] Repeat timed-game flows while opening help/profile/leave dialogs, backgrounding the app, locking the screen, and resuming. Check both simulation and recorded elapsed time.
- [ ] Test touch, mouse, keyboard, fast repeated taps, long presses, two fingers, scrolling that begins on a button, and virtual keyboard composition/deletion.
- [ ] Check a narrow phone, a tall notched phone, a tablet, and desktop. Check ads loading, resizing, disappearing, and returning without covering controls.
- [ ] Buy/place/rotate/resize/layer/remove decor; leave and reopen the room. Compare all eight rotation angles after deselection, including rugs and wall items. Confirm inventory quantities and saves.
- [ ] Test cold character loads, a furnished room, repeated navigation, and a sustained play session on a lower-end device. Record frame time, peak memory, temperature/throttling symptoms, and load times.
- [ ] Check profile switching, a failed save, recovery from backup, and restart after earning/spending coins; never overwrite real user saves during testing.
- [ ] Use the existing [`godot/tests`](../godot/tests/) suites for lifecycle, persistence, gameplay, layout, and marketplace regressions, then add focused tests for the newly fixed bugs. Visual quality and real touch handling still need rendered/device checks.

## Relationship to earlier audits

[`Bug_Report_and_Refactor.md`](Bug_Report_and_Refactor.md) and the [older art-direction notes](art-direction/README.md) remain historical references. Do not reopen every item from them automatically: current source already restores Galaxy's pause field, re-arms static preview rendering on rotation, shares money-counter logic, and caches Mathtris tile styles. The current character files also already have rigs. This backlog is a new review, not a claim that all historical bugs remain present.
