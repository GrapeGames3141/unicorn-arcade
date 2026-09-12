extends Node

# The full integration test remains the exhaustive visual regression runner.  These
# four themed scenes keep its important live-scene contracts below one minute each.
@export var suite := "number"

const WORD_SCENE = preload("res://scenes/games/word_game.tscn")
const CASH_SCENE = preload("res://scenes/games/cash_counter.tscn")
const COIN_SCENE = preload("res://scenes/games/coin_count.tscn")
const RHYME_SCENE = preload("res://scenes/games/rhyme_rally.tscn")
const MATH_SWIPE_SCENE = preload("res://scenes/games/math_swipe.tscn")
const JUMP_SCENE = preload("res://scenes/games/unicorn_jump.tscn")
const SLIDING_SCENE = preload("res://scenes/games/sliding_window.tscn")
const MATHTRIS_SCENE = preload("res://scenes/games/mathtris.tscn")
const GALAXY_SCENE = preload("res://scenes/games/galaxy_unicorn.tscn")
const COMET_SCENE = preload("res://scenes/games/comet_math_rescue.tscn")
const COMET_SCRIPT = preload("res://scripts/games/comet_math_rescue.gd")
const Rules = preload("res://scripts/games/gameplay_rules.gd")
const MARKET_SCENE = preload("res://scenes/meta/marketplace.tscn")
const ALLEY_SCENE = preload("res://scenes/meta/unicorn_alley.tscn")
const ROOM_SCENE = preload("res://scenes/meta/room_editor.tscn")
const MAIN_SCENE = preload("res://scenes/main.tscn")
const WORD_GAME_IDS := ["unicorn_blast", "sentence_sprout", "missing_magic", "sight_spark", "prefix_potion", "vowel_vines", "letter_lift", "syllable_stamp", "caption_quest", "opposite_orbit", "scramble_spell", "odd_one_out", "size_line_up", "chain_link"]

var failures: Array[String] = []
var checks := 0


func _ready() -> void:
	_run.call_deferred()


func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)


func _mount(scene: PackedScene) -> Node:
	var instance := scene.instantiate()
	add_child(instance)
	await get_tree().process_frame
	return instance


func _unmount(instance: Node) -> void:
	remove_child(instance)
	instance.free()


func _run() -> void:
	if not SaveService.begin_test_session():
		push_error("Bounded suites require an isolated save session")
		get_tree().quit(1)
		return
	AppState.data = SaveService.create_profile("Bounded Suite")
	AppState._has_unsaved_changes = false
	AppState.data["rooms"]["sparkle"] = [{"instance_id": "room_companion_sparkle", "item_id": "companion_sparkle", "x": 50.0, "y": 61.0, "rotation": 0, "scale": 1.0, "z_index": 1}]
	match suite:
		"word": await _word_suite()
		"number": await _number_suite()
		"meta": await _meta_suite()
		"shell": await _shell_suite()
		_: _check(false, "unknown bounded suite %s" % suite)
	SaveService.end_test_session()
	if failures.is_empty():
		print("BOUNDED_RUNTIME_%s_OK: %d checks" % [suite.to_upper(), checks])
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error("%s: %s" % [suite, failure])
		get_tree().quit(1)


func _word_suite() -> void:
	for game_id in WORD_GAME_IDS:
		AppState.selected_game_id = game_id
		var game: Node = await _mount(WORD_SCENE)
		_check(game.game_id == game_id, "%s selects its requested React mode" % game_id)
		_check(game.active and game.target_rounds > 0, "%s starts a playable positive-round session" % game_id)
		_check(game.has_method("can_show_hint") and (game.call("can_show_hint") or game.hint_visible), "%s exposes either an available or already-visible active-state hint" % game_id)
		_check(game.find_children("*", "Button", true, false).size() >= 3, "%s retains game actions rather than a static card" % game_id)
		_unmount(game)


func _number_suite() -> void:
	var cash: Node = await _mount(CASH_SCENE)
	cash.target = 20; cash.total = 0; cash.call("_add_bill", 5)
	_check(cash.total == 5 and cash.active and cash.call("can_show_hint"), "Cash Counter accepts bills and has a live hint")
	_unmount(cash)
	var coin: Node = await _mount(COIN_SCENE)
	_check(coin.coin_buttons.size() == 4 and coin.target > 0 and coin.call("can_show_hint"), "Coin Count has four illustrated active choices")
	_unmount(coin)
	var rhyme: Node = await _mount(RHYME_SCENE)
	_check(not rhyme.challenge.is_empty() and rhyme.target_rounds > 0 and rhyme.call("can_show_hint"), "Rhyme Rally starts a solvable active challenge")
	_unmount(rhyme)
	var swipe: Node = await _mount(MATH_SWIPE_SCENE)
	_check(swipe.active and swipe.cards.size() == 2 and swipe.call("can_show_hint"), "Math Swipe starts two answer cards with a hint")
	_unmount(swipe)
	var jump: Node = await _mount(JUMP_SCENE)
	_check(jump.active and jump.node_buttons.size() == jump.level_data.size() + 1 and jump.call("can_show_hint"), "Unicorn Jump keeps its full unlabeled landing trail")
	jump.call("_show_hint")
	_check(jump.fx_layer.get_node_or_null("CountedLandingArc") != null, "Unicorn Jump hint draws a counted landing arc")
	_check(jump.node_buttons.all(func(stone: TextureButton) -> bool: return (stone.get_node("JumpValue") as Label).text.is_empty()), "Unicorn Jump hint leaves every landing stone unlabeled")
	_unmount(jump)
	var sliding: Node = await _mount(SLIDING_SCENE)
	_check(sliding.active and sliding.window_size == 3 and sliding.call("can_show_hint"), "Sliding Window starts its three-value race with a hint")
	_unmount(sliding)
	var mathtris: Node = await _mount(MATHTRIS_SCENE)
	_check(mathtris.active and mathtris.board.size() == 14 and not mathtris.falling.is_empty(), "Mathtris starts a live eight-by-fourteen falling board")
	_mathtris_power_contract(mathtris)
	_unmount(mathtris)
	var galaxy: Node = await _mount(GALAXY_SCENE)
	_check(galaxy.active and galaxy.target_kills == 10 and galaxy.lives == 3, "Galaxy Unicorn starts its ten-target three-life wave")
	_unmount(galaxy)
	await _comet_math_rescue_suite()


func _comet_math_rescue_suite() -> void:
	var deterministic := RandomNumberGenerator.new()
	deterministic.seed = 1337
	var addition: Dictionary = COMET_SCRIPT.generate_problem(1, deterministic)
	var subtraction: Dictionary = COMET_SCRIPT.generate_problem(4, deterministic)
	var multiplication: Dictionary = COMET_SCRIPT.generate_problem(7, deterministic)
	var division: Dictionary = COMET_SCRIPT.generate_problem(10, deterministic)
	var mixed: Dictionary = COMET_SCRIPT.generate_problem(15, deterministic)
	var same_seed_a := RandomNumberGenerator.new()
	var same_seed_b := RandomNumberGenerator.new()
	same_seed_a.seed = 90210
	same_seed_b.seed = 90210
	_check(COMET_SCRIPT.generate_problem(15, same_seed_a) == COMET_SCRIPT.generate_problem(15, same_seed_b), "Comet Math Rescue seeded generation includes deterministic answer order and correct lane")
	var signatures := {}
	for seed in [2, 11, 29, 47, 83]:
		var varied := RandomNumberGenerator.new()
		varied.seed = seed
		var problem := COMET_SCRIPT.generate_problem(15, varied)
		signatures["%s:%s:%s" % [problem["operation"], problem["answer"], problem["correct_index"]]] = true
	_check(signatures.size() >= 3, "Comet Math Rescue selected seeds produce diverse mixed problems and lanes")
	_check(addition["operation"] == "+" and subtraction["operation"] == "-" and multiplication["operation"] == "x", "Comet Math Rescue progression selects addition, subtraction, then multiplication bands")
	_check(division["operation"] in ["+", "-", "x", "/"] and int(division["left"]) >= 0 and int(division["right"]) >= 0, "Comet Math Rescue high-level generator remains nonnegative")
	var exact_division := COMET_SCRIPT.generate_problem(10, _rng_for_comet_division())
	_check(exact_division["operation"] == "/" and int(exact_division["left"]) % int(exact_division["right"]) == 0, "Comet Math Rescue division problems always have exact whole-number answers")
	var answer_set := {}
	for answer in addition["answers"]:
		answer_set[int(answer)] = true
	_check((addition["answers"] as Array).size() == 3 and answer_set.size() == 3 and int(addition["answers"][addition["correct_index"]]) == int(addition["answer"]), "Comet Math Rescue answers are unique with a randomized correct lane")
	_check(mixed["operation"] in ["+", "-", "x", "/"], "Comet Math Rescue level ten-plus mixes prior operations")
	var comet: Node = await _mount(COMET_SCENE)
	comet.size = Vector2(720, 1280)
	comet.call("_update_comet_positions")
	var previous_game_id := GameExperience.attached_game_id
	var previous_scene := GameExperience.attached_scene
	GameExperience.attached_game_id = "comet_math_rescue"
	GameExperience.attached_scene = comet
	var objective: Dictionary = GameExperience.call("_objective_for_scene")
	GameExperience.call("_configure_comet_chrome", comet)
	_check(objective["primary"] == "%d %s %d = ?" % [int(comet.current_problem["left"]), COMET_SCRIPT.display_operation(str(comet.current_problem["operation"])), int(comet.current_problem["right"])] and not comet.equation_label.visible and not comet.meter_label.visible, "Comet shared chrome owns the live equation and hides covered duplicate labels")
	GameExperience.attached_game_id = previous_game_id
	GameExperience.attached_scene = previous_scene
	_check(COMET_SCRIPT.display_operation("x") == "×" and COMET_SCRIPT.display_operation("/") == "÷" and comet.equation_label.get_theme_color("font_color") == Color("fff5e9"), "Comet equation displays child-friendly multiplication and division symbols with high contrast")
	var drag := InputEventScreenDrag.new(); drag.position = Vector2(650, 700)
	comet.call("_input", drag)
	_check(comet.selected_lane == 2, "Comet Math Rescue touch dragging snaps the equipped unicorn to a lane")
	comet.call("_show_hint")
	_check(comet.hint_ms > 0.0 and not comet.wave_resolved and comet.rescues == 0, "Comet Math Rescue hint highlights without resolving the wave")
	comet.selected_lane = comet.correct_lane
	var score_before: int = comet.score
	_check(comet.call("_resolve_wave") and comet.rescues == 1 and comet.score > score_before, "Comet Math Rescue selected correct lane resolves once and raises Rescue")
	_check(not comet.call("_resolve_wave") and comet.rescues == 1, "Comet Math Rescue locks a resolved wave against duplicate collisions")
	comet.call("_start_level", 1)
	comet.selected_lane = (comet.correct_lane + 1) % 3
	var shields_before: int = comet.lives
	_check(not comet.call("_resolve_wave") and comet.lives == shields_before - 1 and comet.rescues == 0, "Comet Math Rescue wrong lane loses one shield without Rescue")
	comet.call("_start_level", 1)
	_check(comet.call("_mystic_rescue") and comet.selected_lane == comet.correct_lane and comet.rescues == 1, "Mystic safely resolves the current correct comet lane")
	comet.call("_start_level", 1)
	comet.lives = 1; comet.selected_lane = (comet.correct_lane + 1) % 3; comet.call("_resolve_wave")
	_check(comet.can_retry_failure(), "Comet Math Rescue exposes explicit Retry after shield failure")
	comet.retry_failure()
	_check(comet.active and comet.lives == 3 and comet.rescues == 0, "Comet Math Rescue retry restores the mission state")
	comet.target_rescues = 1; comet.rescues = 1
	_check(comet.rescues >= comet.target_rescues and Rules.comet_correct_score(1, 1.0) == 165, "Comet Math Rescue mission target and documented score formula are ready for normal AppState completion")
	_check(comet.lane_buttons.all(func(button: Button) -> bool: return button.custom_minimum_size.y >= 48.0 and button.get_theme_font_size("font_size") >= 19), "Comet Math Rescue lanes meet touch-target and readable-label minimums")
	_unmount(comet)


func _rng_for_comet_division() -> RandomNumberGenerator:
	# This seed selects the division branch in the deterministic level-ten mixed band.
	var generator := RandomNumberGenerator.new()
	for seed in range(1, 500):
		generator.seed = seed
		var probe := COMET_SCRIPT.generate_problem(10, generator)
		if probe["operation"] == "/":
			generator.seed = seed
			return generator
	return generator


func _mathtris_fixture(game: Node, cells_to_fill: Array[Vector2i]) -> void:
	game.board = game.call("_make_board")
	game.falling.clear(); game.active = true; game.equation_charge = 3; game.score = 0; game.level = 1; game.slow_until_ms = 0
	for cell in cells_to_fill:
		game.board[cell.y][cell.x] = "1"


func _mathtris_power_contract(game: Node) -> void:
	_mathtris_fixture(game, [])
	for col in 5: game.board[11][col] = ["1", "+", "1", "=", "2"][col]
	_check(game.call("apply_companion_power", "sparkle") and game.equation_charge == 0 and game.score == 400, "Sparkle clears exact hits for 80 points each without normal-match scoring")
	_mathtris_fixture(game, [Vector2i(0, 13)])
	_check(game.call("apply_companion_power", "rainbow") and game.board[13][0] == "", "Rainbow sweeps occupied bottom tiles")
	_mathtris_fixture(game, [Vector2i(3, 8), Vector2i(3, 10)])
	_check(game.call("apply_companion_power", "star") and game.board[8][3] == "", "Star clears the fullest occupied column")
	_mathtris_fixture(game, [])
	_check(game.call("apply_companion_power", "cloud") and game.slow_until_ms - game.level_run.elapsed_ms() >= 17990, "Cloud applies its eighteen-second slow using active play time")
	_mathtris_fixture(game, [])
	for col in 5: game.board[10][col] = ["1", "+", "1", "=", "3"][col]
	_check(game.call("apply_companion_power", "dream") and game.equation_charge == 0 and game.score == 600, "Dream repairs exact hits for 120 points each without normal-match scoring")
	_mathtris_fixture(game, [Vector2i(0, 10), Vector2i(7, 13)])
	_check(game.call("apply_companion_power", "mystic") and game.board[10][0] == "" and game.board[13][7] == "", "Mystic clears all settled tiles")
	for companion_id in ["sparkle", "rainbow", "star", "cloud", "dream", "mystic"]:
		_mathtris_fixture(game, [Vector2i(0, 13)])
		game.equation_charge = 2
		_check(not game.call("apply_companion_power", companion_id) and game.equation_charge == 2, "%s refuses to spend before three clears" % companion_id)
	for companion_id in ["rainbow", "star", "dream", "mystic"]:
		_mathtris_fixture(game, [])
		_check(not game.call("apply_companion_power", companion_id) and game.equation_charge == 3 and game.score == 0, "%s retains a charged power when its board context cannot use it" % companion_id)
	_mathtris_fixture(game, [])
	for col in 8: game.board[0][col] = "1"
	game.call("_spawn_wave")
	_check(not game.active, "Mathtris sparse blocked top-out is not incorrectly rescued")


func _meta_suite() -> void:
	var market: Node = await _mount(MARKET_SCENE)
	_check(market.catalog_ready and market.tab == "companions" and market._companion_cards.size() == 6, "Marketplace opens its fixed six-card companion catalog")
	_check(MetaCatalog.filtered_furniture("all", "").size() == 107 and MetaCatalog.furniture_item("bed_race").get("id", "") == "bed_race", "Marketplace catalog retains all 107 authored decor entries")
	market.call("_show_decor")
	var decor_cards := market.find_children("DecorCard_*", "Panel", true, false)
	_check(market.tab == "decor" and market._decor_cards.size() == 8 and decor_cards.size() == 8 and market.find_children("*", "ItemList", true, false).is_empty(), "Marketplace opens Decor with a bounded fixed pool and no nested vertical list")
	market.prepare_for_scene_change()
	market.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	_check(not is_instance_valid(market), "Marketplace releases its decor catalog after a queued teardown")
	var alley: Node = await _mount(ALLEY_SCENE)
	_check(alley.house_buttons.size() == 6, "Unicorn Alley exposes six companion homes")
	_unmount(alley)
	var room: Node = await _mount(ROOM_SCENE)
	await get_tree().process_frame
	var actor: Node = room.roaming_actor
	var load_deadline := Time.get_ticks_msec() + 10000
	while actor.find_child("LiveUnicornModel", true, false) == null and Time.get_ticks_msec() < load_deadline:
		await get_tree().create_timer(0.01).timeout
	_check(actor.find_child("LiveUnicornModel", true, false) != null, "room companion completes its asynchronous model load")
	var start: Vector2 = actor.position
	room.roam_target = start + Vector2(60, 0)
	room.roam_pause = 4.0
	room.call("_process", 0.5)
	var animator: Node = actor.find_child("IdleAnimator", true, false)
	_check(actor.position.distance_to(start) > 0.0 and is_instance_valid(animator) and str(animator.last_animation_name) == "walk", "room companion roams with its Walk state")
	room.roam_target = actor.position
	room.call("_process", 0.1)
	_check(str(animator.active_action).is_empty(), "room companion returns to its idle pose at a target")
	var safe_target: Vector2 = room.call("_safe_roam_target")
	_check(safe_target.x >= -1.0 and safe_target.y >= -1.0 and safe_target.x + actor.size.x <= room.room_canvas.size.x + 1.0 and safe_target.y + actor.size.y <= room.room_canvas.size.y + 1.0, "room roaming actor chooses targets within the room bounds")
	var old_actor: Node = room.roaming_actor
	var old_canvas: Control = room.room_canvas
	AppState.data["inventory"]["lamp"] = 1
	var room_item_count_before := AppState.room_items(room.companion_id).size()
	room.call("_show_bag")
	var opened_bag = room.bag_overlay
	opened_bag.call("_set_bag_category", "lighting")
	opened_bag.call("_select_item", "lamp")
	var placed_id: String = room.selected_id
	await get_tree().process_frame
	await get_tree().process_frame
	var rebuilt_actor: Node = room.roaming_actor
	var visible_actors: Array = room.room_canvas.find_children("RoamingRoomCompanion", "RoomItemPreview3D", true, false).filter(func(candidate: Node) -> bool: return (candidate as CanvasItem).visible)
	var selected_item: Dictionary = room.call("_local_item", placed_id)
	var companion_anchor := room.item_buttons.get("room_companion_sparkle") as Button
	_check(AppState.room_items(room.companion_id).size() == room_item_count_before + 1 and not placed_id.is_empty() and selected_item.get("item_id", "") == "lamp" and room.bag_category == "lighting" and room.bag_overlay == null and not is_instance_valid(opened_bag) and room.find_children("FurnitureBagOverlay", "FurnitureBagOverlay", true, false).is_empty(), "room bag overlay signal places lamp exactly once, selects it, preserves its category, and retires the stale overlay during the editor rebuild")
	room.call("_show_bag")
	_check(is_instance_valid(room.bag_overlay) and room.bag_overlay.category == "lighting", "rebuilt room editor opens a fresh furniture bag with its previous category")
	room.call("_close_bag")
	_check(is_instance_valid(rebuilt_actor) and rebuilt_actor != old_actor and rebuilt_actor.get_parent() == room.room_canvas and room.room_canvas != old_canvas and visible_actors.size() == 1, "bag placement rebuild retires the stale roaming actor and creates exactly one visible actor in the new canvas")
	_check(is_instance_valid(companion_anchor) and not companion_anchor.visible, "bag placement preserves the hidden saved companion anchor")
	_unmount(room)


func _shell_suite() -> void:
	var shell := Control.new()
	add_child(shell)
	var overlay := Control.new(); overlay.name = "InGameProfileOverlay"; shell.add_child(overlay)
	_check(RouteService.call("_dismiss_top_overlay", shell) and overlay.is_queued_for_deletion(), "Back dismisses a named overlay before navigation")
	AppState.set_shell_destination("dashboard")
	_check(AppState.shell_view == "dashboard", "dashboard route records a shell destination")
	AppState.set_shell_destination("category", "Word")
	_check(AppState.shell_view == "category" and AppState.selected_category == "Word", "category route records its selected category")
	AppState.set_shell_destination("profile")
	_check(AppState.shell_view == "profile", "profile route records its shell destination")
	_check(RouteService.platform_back_notifications_enabled(), "project Back settings keep Android Back on RouteService notifications")
	_check(RouteService.back_policy("res://scenes/games/mathtris.tscn", "category")["target"] == "category", "game Back returns to its category")
	_check(RouteService.back_policy("res://scenes/meta/room_editor.tscn", "home")["target"] == "alley", "room Back returns to Unicorn Alley")
	_check(RouteService.back_policy("res://scenes/main.tscn", "profile")["target"] == "profile", "shell Back follows profile to home")
	_check(RouteService.back_policy("res://unknown.tscn", "home")["kind"] == "quit", "only an unknown root route may exit")
	_unmount(shell)
