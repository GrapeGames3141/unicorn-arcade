extends Node

const Rules = preload("res://scripts/games/word_game_rules.gd")
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
const ALLEY_SCENE = preload("res://scenes/meta/unicorn_alley.tscn")
const ROOM_SCENE = preload("res://scenes/meta/room_editor.tscn")

const WORD_GAME_IDS := [
	"unicorn_blast", "sentence_sprout", "missing_magic", "sight_spark",
	"prefix_potion", "vowel_vines", "letter_lift", "syllable_stamp",
	"caption_quest", "opposite_orbit", "scramble_spell", "odd_one_out",
	"size_line_up", "chain_link",
]

var failures: Array[String] = []
var check_count := 0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var pre_test_data := AppState.data.duplicate(true)
	var test_session_started := SaveService.begin_test_session()
	var test_profile := SaveService.create_profile("Runtime Integration")
	if not test_session_started or test_profile.is_empty() or not SaveService.has_active_profile():
		push_error("runtime integration could not create its isolated active save profile")
		SaveService.end_test_session()
		get_tree().quit(1)
		return
	_check(true, "runtime integration owns an isolated active save profile")
	AppState.data = test_profile
	var original_game := AppState.selected_game_id
	var original_category := AppState.selected_category
	for game_id in WORD_GAME_IDS:
		AppState.selected_game_id = game_id
		var game = WORD_SCENE.instantiate()
		add_child(game)
		await get_tree().process_frame
		_check(_ui_is_accessible(game), "%s meets readable text, contrast, and touch-target minimums" % game_id)
		_check(_storybook_action_count(game) >= 3, "%s uses the shared storybook treatment for back, hint, and retry actions" % game_id)
		_check(game.game_id == game_id, "%s selects the requested shared-game mode" % game_id)
		_check(game.active, "%s begins in an active play state" % game_id)
		_check(game.target_rounds > 0, "%s has a positive round target" % game_id)
		_exercise_first_move(game_id, game)
		await _release_scene(game)
	var cash = CASH_SCENE.instantiate()
	add_child(cash)
	await get_tree().process_frame
	_check(_ui_is_accessible(cash), "Cash Counter meets readable text, contrast, and touch-target minimums")
	_check(_storybook_action_count(cash) >= 3, "Cash Counter styles back, hint, and retry with the shared storybook action treatment")
	_check(cash.active, "Cash Counter begins in an active play state")
	cash.target = 20
	cash.total = 0
	cash.call("_add_bill", 5)
	_check(cash.total == 5 and cash.active, "Cash Counter accepts a non-overshooting bill")
	await _release_scene(cash)
	var coin_count = COIN_SCENE.instantiate()
	add_child(coin_count)
	await get_tree().process_frame
	_check(coin_count.target > 0, "Coin Count begins with a positive target")
	_check(_ui_is_accessible(coin_count), "Coin Count meets readable text, contrast, and touch-target minimums")
	_check(_storybook_action_count(coin_count) >= 2, "Coin Count styles retry and navigation with the shared storybook action treatment")
	_check(coin_count.coin_buttons.size() == 4 and coin_count.coin_buttons.all(func(button: Button) -> bool: return button is CoinChoiceButton), "Coin Count uses four illustrated denomination coins instead of text boxes")
	_check(coin_count.coin_buttons[0].custom_minimum_size.y >= 170.0 and coin_count.coin_buttons[0].tooltip_text.contains("worth"), "illustrated coins retain large accessible tap targets and denomination descriptions")
	var official_coin := coin_count.coin_buttons[0].find_child("OfficialCoinPortrait", true, false) as TextureRect
	_check(is_instance_valid(official_coin) and official_coin.texture != null and not coin_count.coin_buttons[0].has_method("_draw_coin_face"), "Coin Count presents only the official coin portrait, while retaining accessible labels and focus treatment")
	var coin_portraits_clear_text := true
	for button in coin_count.coin_buttons:
		var portrait := button.find_child("OfficialCoinPortrait", true, false) as TextureRect
		coin_portraits_clear_text = coin_portraits_clear_text and is_instance_valid(portrait) and is_equal_approx(portrait.offset_bottom, CoinChoiceButton.PORTRAIT_BOTTOM_Y) and portrait.get_rect().end.y <= CoinChoiceButton.PORTRAIT_BOTTOM_Y and CoinChoiceButton.DENOMINATION_BASELINE_Y - portrait.get_rect().end.y >= 24.0
	_check(coin_portraits_clear_text, "Coin Count bounds every denomination portrait above the 140-pixel text baseline, including the quarter")
	await _release_scene(coin_count)
	var rhyme = RHYME_SCENE.instantiate()
	add_child(rhyme)
	await get_tree().process_frame
	_check(rhyme.target_rounds > 0 and not rhyme.challenge.is_empty(), "Rhyme Rally begins with a playable challenge")
	_check(_ui_is_accessible(rhyme), "Rhyme Rally meets readable text, contrast, and touch-target minimums")
	_check(_storybook_action_count(rhyme) >= 2, "Rhyme Rally styles retry and navigation with the shared storybook action treatment")
	await _release_scene(rhyme)
	var math_swipe = MATH_SWIPE_SCENE.instantiate()
	add_child(math_swipe)
	await get_tree().process_frame
	_check(_ui_is_accessible(math_swipe), "Math Swipe meets readable text, contrast, and touch-target minimums")
	_check(_storybook_action_count(math_swipe) >= 2, "Math Swipe styles retry/next and navigation with the shared storybook action treatment")
	_check(math_swipe.active and math_swipe.cards.size() == 2, "Math Swipe launches with two answer cards")
	var correct_card: Button
	for card in math_swipe.cards:
		if bool(card.get_meta("correct")):
			correct_card = card
			break
	math_swipe.call("_submit", correct_card)
	_check(math_swipe.completed == 1, "Math Swipe accepts the correct card")
	await _release_scene(math_swipe)
	var jump = JUMP_SCENE.instantiate()
	add_child(jump)
	await get_tree().process_frame
	_check(_ui_is_accessible(jump), "Unicorn Jump meets readable text, contrast, and touch-target minimums")
	_check(_storybook_action_count(jump) >= 2, "Unicorn Jump styles retry/next and navigation without obsolete zoom buttons")
	_check(jump.active and jump.level_data.size() == 10, "Unicorn Jump launches its level-one ten-node trail")
	_check(jump.node_buttons.size() == 11 and jump.node_buttons.all(func(button: TextureButton) -> bool: return button.texture_normal != null), "Unicorn Jump builds the full trail from authored stepping-stone art")
	_check(jump.find_children("TrailConnector*", "Line2D", true, false).size() == 10, "Unicorn Jump restores the original connected winding path")
	var trail_companion = jump.find_child("ActiveCompanionOnStone", true, false)
	_check(is_instance_valid(trail_companion) and trail_companion.source_model_id == AppState.equipped_companion(), "the equipped 3D companion stands on the current stepping stone")
	_check((jump.node_buttons[0].get_node("JumpValue") as Label).text.is_empty() and jump.find_children("*Zoom*", "Button", true, false).is_empty(), "landing stones stay unlabeled and zoom buttons are removed for pinch zoom")
	_check(jump.node_buttons.size() == jump.level_data.size() + 1, "every intermediate wrong landing remains visible between the current stone and later correct destinations")
	var jump_viewport_rect: Rect2 = jump.world_viewport.get_global_rect()
	var first_five_centers_visible := true
	for index in range(mini(5, jump.node_buttons.size())):
		first_five_centers_visible = first_five_centers_visible and jump_viewport_rect.has_point(jump.node_buttons[index].get_global_rect().get_center())
	_check(jump.world_viewport.zoom < 1.0 and first_five_centers_visible, "Unicorn Jump starts zoomed out enough to view the current stone and four forward stones when the viewport permits")
	var landing: int = jump.level_data[0]
	_check(jump.node_buttons[landing].self_modulate == Color.WHITE, "Unicorn Jump does not reveal the counted landing with a highlight")
	AppState.data["settings"]["reduced_motion"] = false
	jump.call("_choose_node", landing)
	await get_tree().create_timer(1.15).timeout
	_check(jump.current_index == landing and jump.active, "Unicorn Jump accepts the exact indexed landing")
	_check(is_instance_valid(trail_companion) and trail_companion == jump.companion_preview and trail_companion.get_parent() == jump.world_viewport.world and trail_companion.position.is_equal_approx(jump._companion_world_position(landing)) and trail_companion.size == jump.COMPANION_DISPLAY_SIZE, "the same full-size companion lands in trail-world coordinates on the newly reached stone")
	_check(jump.fx_layer.burst_amount > 0.0 and jump.find_child("JumpingCompanion", true, false) == null, "Unicorn Jump leaves a rainbow tail-puff landing burst after its animated arc")
	jump.call("_choose_node", jump.current_index)
	GameExperience.attached_scene = jump
	GameExperience.attached_game_id = "unicorn_jump"
	_check(not jump.active and jump.can_retry_failure() and GameExperience.call("_is_retry_failure"), "Unicorn Jump loss is classified as a shared retry failure")
	await _release_scene(jump)
	var sliding = SLIDING_SCENE.instantiate()
	add_child(sliding)
	await get_tree().process_frame
	_check(_ui_is_accessible(sliding), "Sliding Window meets readable text, contrast, and touch-target minimums")
	_check(_storybook_action_count(sliding) >= 3, "Sliding Window styles hint, retry/next, and navigation with the shared storybook action treatment")
	_check(sliding.active and sliding.window_size == 3, "Sliding Window launches its level-one race")
	var max_index := 0
	for index in sliding.window_size:
		if sliding.level_data[index] > sliding.level_data[max_index]:
			max_index = index
	sliding.call("_choose", max_index)
	_check(sliding.window_pos == 1 and sliding.active, "Sliding Window advances after selecting the maximum")
	await _release_scene(sliding)
	var mathtris = MATHTRIS_SCENE.instantiate()
	add_child(mathtris)
	await get_tree().process_frame
	_check(_ui_is_accessible(mathtris), "Mathtris meets readable text, contrast, and touch-target minimums")
	_check(_storybook_action_count(mathtris) >= 4, "Mathtris styles power, hint, retry, and navigation with the shared storybook action treatment")
	_check(mathtris.active and mathtris.board.size() == 14 and mathtris.board[0].size() == 8, "Mathtris launches an 8 by 14 live board")
	_check(not mathtris.falling.is_empty(), "Mathtris launches an initial falling wave")
	mathtris.board = mathtris.call("_make_board")
	for col in 5:
		mathtris.board[3][col] = ["1", "+", "1", "=", "2"][col]
	var match_anchors: Array[Vector2i] = [Vector2i(0, 3)]
	var anchored_matches: Array = mathtris.call("_find_matches", match_anchors)
	_check(anchored_matches.size() == 1 and anchored_matches[0]["orientation"] == "horizontal", "Mathtris reports exact true-equation cells and orientation")
	mathtris.board[10][0] = "4"
	mathtris.board[10][1] = "5"
	mathtris.call("_try_swap", Vector2i(0, 10), Vector2i(1, 10))
	_check(mathtris.board[3][0] == "1", "an unrelated valid equation is not cleared by a different swap")
	mathtris.board = mathtris.call("_make_board")
	for col in 5:
		mathtris.board[9][col] = ["1", "+", "2", "3", "="][col]
	mathtris.call("_try_swap", Vector2i(3, 9), Vector2i(4, 9))
	_check(mathtris.board[9].slice(0, 5).all(func(value: String) -> bool: return value == ""), "an adjacent slide clears only the true equation it creates")
	mathtris.board = mathtris.call("_make_board")
	for col in 5:
		mathtris.board[3][col] = ["1", "+", "1", "=", "2"][col]
	for col in 5:
		mathtris.board[11][col] = ["2", "+", "2", "=", "4"][col]
	var bottom_anchors: Array[Vector2i] = [Vector2i(0, 11)]
	var bottom_match: Array = mathtris.call("_find_matches", bottom_anchors)
	mathtris.call("_clear_matches", bottom_match, 100, true)
	_check(mathtris.board[3][0] == "" and mathtris.call("_find_equations").is_empty(), "Mathtris cascade clears a true equation only after its tiles fall into the cascade anchors")
	mathtris.board = mathtris.call("_make_board")
	var falling_fixture: Array[Dictionary] = [{"row": 0, "col": 2, "value": "3"}]
	mathtris.falling = falling_fixture
	mathtris.call("_refresh")
	var falling_cell: Button = mathtris.cells[2]
	var falling_style := falling_cell.get_theme_stylebox("disabled") as StyleBoxFlat
	_check(falling_cell.text == "3" and falling_style != null and falling_style.bg_color.a > 0.9, "falling Mathtris values move with their complete decorated tile")
	mathtris.falling.clear()
	for col in 8:
		mathtris.board[0][col] = "1"
	mathtris.active = true
	mathtris.call("_spawn_wave")
	_check(not mathtris.active and mathtris.falling.is_empty(), "a blocked Mathtris spawn tops out without an orphan box")
	_mathtris_companion_power_contract(mathtris)
	await _release_scene(mathtris)
	var galaxy = GALAXY_SCENE.instantiate()
	add_child(galaxy)
	await get_tree().process_frame
	_check(_ui_is_accessible(galaxy), "Galaxy Unicorn meets readable text, contrast, and touch-target minimums")
	_check(_storybook_action_count(galaxy) >= 2, "Galaxy Unicorn styles retry/next and Arcade navigation with the shared storybook action treatment")
	_check(galaxy.active and galaxy.target_kills == 10 and galaxy.lives == 3, "Galaxy Unicorn launches with the React target and lives")
	var galaxy_safe_band := galaxy.find_child("GalaxyBottomSafeBand", true, false) as PanelContainer
	var galaxy_actions := galaxy.find_child("GalaxyBottomSafeActions", true, false) as HBoxContainer
	_check(is_instance_valid(galaxy_safe_band) and galaxy_safe_band.get_parent() == galaxy and is_instance_valid(galaxy_actions) and galaxy_actions.get_parent().get_parent() == galaxy_safe_band, "Galaxy message and retry/next actions live in an explicit bottom-safe band inside the game viewport")
	_check(is_equal_approx(galaxy.player_x, 0.5), "Galaxy Unicorn centers the player for its opening wave")
	galaxy.call("_spawn_enemy", false)
	_check(float(galaxy.enemies[0]["speed"]) <= 0.00009, "Galaxy Unicorn's opening enemies use the gentle level-one speed curve")
	_check(str(galaxy.enemies[0]["kind"]) in ["storm_cloud", "shadow_star", "enchanted_comet", "cursed_moon"], "Galaxy Unicorn spawns magical celestial threats instead of unrelated placeholder objects")
	galaxy.enemies.clear()
	galaxy.size = Vector2(720, 1280)
	await get_tree().process_frame
	_check(galaxy_safe_band.get_global_rect().end.y <= galaxy.get_global_rect().end.y and galaxy_safe_band.get_global_rect().position.y >= galaxy.get_global_rect().position.y, "Galaxy's bottom-safe action band stays within the render viewport above the native ad sibling")
	var galaxy_drag := InputEventScreenDrag.new()
	galaxy_drag.position = Vector2(576, 900)
	galaxy.call("_input", galaxy_drag)
	_check(is_equal_approx(galaxy.player_x, 0.8), "Galaxy Unicorn responds to Android screen dragging")
	var paused_spawn_timer: float = galaxy.spawn_timer
	var paused_enemy_count: int = galaxy.enemies.size()
	galaxy.call("set_gameplay_paused", true)
	galaxy.call("_process", 1.0)
	_check(is_equal_approx(galaxy.spawn_timer, paused_spawn_timer) and galaxy.enemies.size() == paused_enemy_count, "Galaxy tutorial pause freezes spawning and simulation")
	galaxy.call("set_gameplay_paused", false)
	galaxy.call("_process", 0.016)
	_check(galaxy.fire_cooldown > 0.0 and galaxy.bolt_flashes.size() > 0, "Galaxy Unicorn auto-fires a visible rainbow bolt")
	_check(galaxy.call("_segment_hits_circle", Vector2(576, 1000), Vector2(576, 300), Vector2(576, 650), 26.0), "Galaxy Unicorn fast bolts use swept collision instead of tunneling through targets")
	await _release_scene(galaxy)
	var comet = COMET_SCENE.instantiate()
	add_child(comet)
	await get_tree().process_frame
	comet.size = Vector2(720, 1280)
	comet.call("_update_comet_positions")
	await get_tree().process_frame
	_check(comet.active and comet.lane_buttons.size() == 3 and comet.target_rescues > 0, "Comet Math Rescue launches a three-lane Rescue mission")
	_check(_ui_is_accessible(comet), "Comet Math Rescue meets readable text, contrast, and touch-target minimums")
	_check(is_instance_valid(comet.fire_button) and comet.fire_button.visible, "Comet Math Rescue presents a dedicated FIRE RAINBOW action")
	var side_lane: int = (comet.correct_lane + 1) % 3
	comet.call("_select_lane", side_lane)
	var fire_touch := InputEventScreenTouch.new()
	fire_touch.pressed = true
	fire_touch.position = comet.fire_button.get_global_rect().get_center()
	comet.call("_input", fire_touch)
	_check(comet.selected_lane == side_lane, "touching FIRE RAINBOW does not retarget the aimed comet lane")
	comet.fire_button.pressed.emit()
	_check(comet.wave_resolved and comet.bolt_lane == side_lane, "FIRE RAINBOW fires the rainbow through the previously aimed unicorn lane")
	comet.call("_start_level", 1)
	comet.call("_select_lane", comet.correct_lane)
	_check(not comet.wave_resolved and comet.rescues == 0, "Comet lane aiming alone does not resolve the wave")
	comet.fire_button.pressed.emit()
	_check(comet.wave_resolved and comet.rescues == 1, "FIRE RAINBOW resolves the aimed lane immediately")
	comet.call("_start_level", 1)
	comet.call("_show_hint")
	_check(comet.hint_ms > 0.0 and not comet.wave_resolved, "Comet Math Rescue hint highlights without resolving its wave")
	comet.selected_lane = comet.correct_lane
	_check(comet.call("_resolve_wave") and comet.rescues == 1 and comet.score > 0, "Comet Math Rescue resolves only the selected correct lane")
	GameExperience.attached_scene = comet
	GameExperience.attached_game_id = "comet_math_rescue"
	comet.call("_start_level", 1)
	comet.lives = 1
	comet.selected_lane = (comet.correct_lane + 1) % 3
	comet.call("_resolve_wave")
	GameExperience.call("_show_game_outcome")
	await get_tree().process_frame
	var failure_overlay := comet.find_child("GameOutcomeOverlay", true, false) as Control
	var failure_primary := failure_overlay.find_child("GameOutcomePrimaryAction", true, false) as Button if is_instance_valid(failure_overlay) else null
	_check(is_instance_valid(failure_overlay) and failure_primary.text == "TRY AGAIN" and not comet.action_button.visible, "shared outcome failure overlay replaces the legacy retry button")
	if is_instance_valid(failure_primary): failure_primary.pressed.emit()
	await get_tree().process_frame
	_check(comet.active, "shared outcome primary action drives the legacy retry signal")
	comet.target_rescues = 1
	comet.selected_lane = comet.correct_lane
	comet.call("_resolve_wave")
	GameExperience.call("_show_game_outcome")
	await get_tree().process_frame
	var success_overlay := comet.find_child("GameOutcomeOverlay", true, false) as Control
	var success_primary := success_overlay.find_child("GameOutcomePrimaryAction", true, false) as Button if is_instance_valid(success_overlay) else null
	_check(is_instance_valid(success_overlay) and success_primary.text == "KEEP GOING" and not comet.action_button.visible, "shared outcome success overlay supplies a keep-going primary action")
	if is_instance_valid(success_primary): success_primary.pressed.emit()
	GameExperience.outcome_overlay = null
	await _release_scene(comet)
	var alley = ALLEY_SCENE.instantiate()
	add_child(alley)
	await get_tree().process_frame
	_check(_ui_is_accessible(alley), "Unicorn Alley meets readable text, contrast, and touch-target minimums")
	_check(is_instance_valid(alley.message_label) and alley.house_buttons.size() == 6, "Unicorn Alley launches all six selectable houses")
	_check(alley.map_rect.texture.resource_path.ends_with("unicorn_alley_production_v1.png"), "Unicorn Alley uses the new unified six-door pastel map")
	var door_button: Button = alley.house_buttons.get("sparkle")
	_check(door_button.custom_minimum_size.y > door_button.custom_minimum_size.x, "Alley house targets use tall door-shaped controls")
	_check(door_button.text.is_empty() and door_button.has_node("DoorStateArt"), "Alley doors use environmental light cues without floating label shapes")
	await _release_scene(alley)
	AppState.active_room_companion = "sparkle"
	var room = ROOM_SCENE.instantiate()
	add_child(room)
	await get_tree().process_frame
	await get_tree().process_frame
	_check(_ui_is_accessible(room), "room editor meets readable text, contrast, and touch-target minimums")
	_check(room.companion_id == "sparkle" and is_instance_valid(room.room_canvas), "Sparkle's room editor launches")
	_check(room.grid_snap, "room editor starts with eight-percent grid snapping enabled")
	var room_stage := room.room_canvas.get_parent() as Control
	_check(is_instance_valid(room.bag_button) and room.bag_button.get_parent() == room_stage and room.bag_button.icon != null and room.bag_button.expand_icon and room.bag_button.get_theme_constant("icon_max_width") >= 44 and room.bag_button.custom_minimum_size.x >= 118.0 and room.bag_button.custom_minimum_size.y >= 76.0 and is_equal_approx(room.bag_button.anchor_right, 1.0) and is_equal_approx(room.bag_button.anchor_bottom, 1.0) and is_equal_approx(room.bag_button.offset_right, -24.0) and is_equal_approx(room.bag_button.offset_bottom, -24.0), "room BAG button is a large illustrated room-stage action with explicit 24-pixel bottom-right insets")
	var roaming_actor = room.roaming_actor
	var room_bounds := Rect2(Vector2.ZERO, room.room_canvas.size)
	_check(is_instance_valid(roaming_actor) and room_bounds.encloses(Rect2(roaming_actor.position, roaming_actor.size)) and is_equal_approx(room.roam_target.y, roaming_actor.position.y) and roaming_actor.pivot_offset.is_equal_approx(roaming_actor.size * 0.5), "room companion initializes after the fitted canvas, fully inside its floor lane with a centered mirror pivot")
	if is_instance_valid(roaming_actor):
		room.roam_target = room.call("_safe_roam_target")
		var floor_y: float = roaming_actor.position.y
		for _step in 6:
			room.call("_process", 0.25)
		_check(is_equal_approx(room.roam_target.y, floor_y) and is_equal_approx(roaming_actor.position.y, floor_y) and room_bounds.encloses(Rect2(roaming_actor.position, roaming_actor.size)), "room companion walking changes horizontal position only and stays inside the room canvas")
		var stage := room.room_canvas.get_parent() as Control
		room.call("_fit_room_canvas", stage, room.room_canvas.size / 0.5)
		var resized_bounds := Rect2(Vector2.ZERO, room.room_canvas.size)
		_check(is_equal_approx(roaming_actor.position.y, room.roam_target.y) and resized_bounds.encloses(Rect2(roaming_actor.position, roaming_actor.size)), "room companion preserves its floor baseline and bounds after canvas reflow")
		var right_start := Vector2(maxf(0.0, roaming_actor.position.x - 24.0), roaming_actor.position.y)
		roaming_actor.position = right_start
		room.roam_target = right_start + Vector2(18.0, 0.0)
		room.roam_pause = 1.0
		room.call("_process", 0.1)
		_check(roaming_actor.scale.x > 0.0, "room companion keeps its unmirrored screen-right preview while walking right")
		var left_start := Vector2(minf(room.room_canvas.size.x - roaming_actor.size.x, roaming_actor.position.x + 24.0), roaming_actor.position.y)
		roaming_actor.position = left_start
		room.roam_target = left_start - Vector2(18.0, 0.0)
		room.roam_pause = 1.0
		room.call("_process", 0.1)
		_check(roaming_actor.scale.x < 0.0 and roaming_actor.pivot_offset.is_equal_approx(roaming_actor.size * 0.5), "room companion mirrors leftward travel around its centered pivot")
	_check(room.call("_item_base_size", "companion_sparkle") == Vector2(252, 180), "room companions use an expanded transparent canvas for horn and hoof clearance")
	var companion_preview = room.roaming_actor
	_check(is_instance_valid(companion_preview) and companion_preview.uses_character_model and companion_preview.source_model_id == "sparkle" and companion_preview.mesh_count >= 1, "rooms automatically present the updated companion-specific GLB")
	var live_unicorn_model = companion_preview.find_child("LiveUnicornModel", true, false) if is_instance_valid(companion_preview) else null
	_check(is_instance_valid(live_unicorn_model) and is_equal_approx(live_unicorn_model.scale.x, 3.84), "room unicorn presentation applies the requested three-times display scale")
	var companion_cameras: Array[Node] = companion_preview.find_children("*", "Camera3D", true, false) if is_instance_valid(companion_preview) else []
	var companion_camera = companion_cameras[0] if not companion_cameras.is_empty() else null
	_check(is_instance_valid(companion_camera) and companion_camera.size >= 6.8 and companion_camera.position.x < -8.0 and absf(companion_camera.position.z) < 2.0, "animated room companions use padded opposite-facing side-view framing")
	var idle_animator = companion_preview.find_child("IdleAnimator", true, false) if is_instance_valid(companion_preview) else null
	var moving_shadow = companion_preview.find_child("MeadowContactShadow", true, false) if is_instance_valid(companion_preview) else null
	_check(is_instance_valid(idle_animator) and is_instance_valid(moving_shadow) and moving_shadow.get_parent() == idle_animator.model, "the companion and its contact shadow share one travel root")
	_check(is_instance_valid(idle_animator) and idle_animator.animation_names() == PackedStringArray(["walk"]), "live unicorn previews expose only the Walk animation")
	_check(is_instance_valid(idle_animator) and is_instance_valid(idle_animator.timer) and not idle_animator.timer.is_stopped() and idle_animator.timer.wait_time >= 1.8 and idle_animator.timer.wait_time <= 4.5, "live unicorn previews alternate short natural pauses with roaming")
	_check(is_instance_valid(idle_animator) and _skeletons_are_in_rest_pose(idle_animator.model), "unicorns use their neutral rig pose while standing instead of freezing a gait-contact frame")
	if is_instance_valid(idle_animator):
		idle_animator.play_random_animation_now()
	_check(is_instance_valid(idle_animator) and idle_animator.last_animation_name == "walk", "Sparkle can immediately exercise its embedded Walk animation")
	if is_instance_valid(idle_animator):
		var walk_home_position: Vector3 = idle_animator.model.position
		_check(idle_animator.play_animation_now("walk"), "authored walk clip can be selected deterministically")
		idle_animator.walk_tween.custom_step(0.65)
		_check(idle_animator.model.position.distance_to(walk_home_position) > 0.1 and is_equal_approx(idle_animator.model.position.x, walk_home_position.x), "walking unicorn travels visibly across the side-view meadow instead of walking toward the camera")
		var walk_displacement: Vector3 = idle_animator.model.position - walk_home_position
		var visual_forward: Vector3 = (idle_animator.model.basis * Vector3.BACK).normalized()
		_check(visual_forward.dot(walk_displacement.normalized()) > 0.9, "walking unicorn faces its direction of travel instead of moving backward")
		idle_animator.walk_tween.custom_step(10.0)
		_check(not idle_animator.model.position.is_equal_approx(walk_home_position) and absf(idle_animator.model.position.z - walk_home_position.z) > 0.4 and is_equal_approx(idle_animator.model.position.x, walk_home_position.x), "walking unicorn reaches a new visible side-to-side meadow position without snapping home")
		_check(idle_animator.animation_player.assigned_animation == idle_animator.walk_animation and not idle_animator.timer.is_stopped(), "walking route returns to its standing Walk pose and schedules the next route")
	await _release_scene(room)
	var profile_before_room_flow := AppState.data.duplicate(true)
	AppState.data = SaveService.default_profile()
	AppState.data["player"]["name"] = "Runtime Test"
	_check(AppState.buy_companion("rainbow") and AppState.coins() == 500, "companion adoption deducts the exact catalog price")
	_check(AppState.equip_companion("rainbow") and AppState.equipped_companion() == "rainbow", "owned companions can be equipped")
	_check(AppState.buy_furniture("lamp") and AppState.coins() == 350, "decor purchase adds one catalog item")
	var placement := {"instance_id": "test_lamp", "item_id": "lamp", "x": 48.0, "y": 48.0, "rotation": 0, "scale": 1.0, "z_index": 1}
	_check(AppState.place_room_item("rainbow", placement) and AppState.available_count("lamp") == 0, "room placement consumes one available inventory item")
	_check(not AppState.sell_furniture("lamp"), "placed decor cannot be sold")
	AppState.active_room_companion = "rainbow"
	var touch_room = ROOM_SCENE.instantiate()
	add_child(touch_room)
	await get_tree().process_frame
	var lamp_button: Button = touch_room.item_buttons.get("test_lamp")
	touch_room.call("_begin_item_drag", "test_lamp")
	var lamp_preview = lamp_button.get_node_or_null("RoomItemPreview3D") if is_instance_valid(lamp_button) else null
	_check(lamp_button.text.is_empty() and lamp_button.tooltip_text == "Lava Lamp" and is_instance_valid(lamp_preview) and lamp_preview.mesh_count > 0 and not lamp_preview.uses_character_model, "room decor uses a modeled 3D object instead of an icon glyph")
	_check(is_instance_valid(touch_room.selection_toolbar) and touch_room.selection_toolbar.get_child_count() == 6, "selecting decor opens the original six-action contextual toolbar")
	touch_room.call("_move_dragged", "test_lamp", Vector2(touch_room.room_canvas.size.x * 0.82, touch_room.room_canvas.size.y * 0.66), lamp_button)
	_check(touch_room.call("_finish_item_drag"), "room item drag completion commits without a synthetic touch release")
	var moved_items := AppState.room_items("rainbow")
	var moved_lamp := moved_items.filter(func(item: Dictionary) -> bool: return str(item.get("instance_id", "")) == "test_lamp")
	_check(moved_lamp.size() == 1 and is_equal_approx(float(moved_lamp[0]["x"]), 80.0) and is_equal_approx(float(moved_lamp[0]["y"]), 64.0), "room decor follows and commits an Android drag outside its button")
	touch_room.call("_selection_action", "ROTATE")
	var lamp_display_root := lamp_preview.find_child("DisplayRotationRoot", true, false) as Node3D
	_check(is_zero_approx(lamp_button.rotation_degrees) and is_instance_valid(lamp_display_root) and is_zero_approx(lamp_display_root.rotation_degrees.x) and is_equal_approx(lamp_display_root.rotation_degrees.y, 45.0) and is_zero_approx(lamp_display_root.rotation_degrees.z), "room rotate updates the selected live 3D model around world up without tilting its upright interaction target")
	for _frame in 3:
		await get_tree().process_frame
	var blank_room_press := InputEventScreenTouch.new()
	blank_room_press.pressed = true
	touch_room.call("_room_canvas_input", blank_room_press)
	await get_tree().process_frame
	var unselected_normal := lamp_button.get_theme_stylebox("normal") as StyleBoxFlat
	var unselected_hover := lamp_button.get_theme_stylebox("hover") as StyleBoxFlat
	var lamp_cached := lamp_button.get_node_or_null("CachedDecorPreview") as TextureRect
	_check(touch_room.selected_id.is_empty() and not is_instance_valid(touch_room.selection_toolbar) and not is_instance_valid(lamp_button.get_node_or_null("RoomItemPreview3D")) and is_instance_valid(lamp_cached) and lamp_cached.visible and lamp_cached.texture != null, "tapping empty room space freezes the selected model into a visible cached snapshot and closes its controls")
	_check(is_instance_valid(unselected_normal) and is_zero_approx(unselected_normal.bg_color.a) and unselected_normal.border_width_left == 0 and is_instance_valid(unselected_hover) and is_zero_approx(unselected_hover.bg_color.a) and unselected_hover.border_width_left == 0, "unselected room items have no transparent or hover interaction boxes")
	AppState.data["inventory"]["rug"] = 1
	var rug_placement := {"instance_id": "test_rug", "item_id": "rug", "x": 28.0, "y": 62.0, "rotation": 0, "scale": 1.0, "z_index": 2}
	_check(AppState.place_room_item("rainbow", rug_placement), "runtime room fixture can place a second decor item for selection switching")
	touch_room.call("_build_editor")
	await get_tree().process_frame
	lamp_button = touch_room.item_buttons.get("test_lamp")
	var rug_button: Button = touch_room.item_buttons.get("test_rug")
	touch_room.call("_begin_item_drag", "test_lamp")
	var reselected_lamp = lamp_button.get_node_or_null("RoomItemPreview3D") if is_instance_valid(lamp_button) else null
	touch_room.call("_begin_item_drag", "test_rug")
	await get_tree().process_frame
	var selected_rug = rug_button.get_node_or_null("RoomItemPreview3D") if is_instance_valid(rug_button) else null
	_check(is_instance_valid(reselected_lamp) and not is_instance_valid(lamp_button.get_node_or_null("RoomItemPreview3D")) and is_instance_valid(selected_rug) and is_zero_approx(lamp_button.rotation_degrees) and is_zero_approx(rug_button.rotation_degrees), "switching decor selection frees the previous live preview and never leaves more than one upright decor viewport")
	touch_room.call("_clear_selection")
	await get_tree().process_frame
	touch_room.call("_begin_item_drag", "test_lamp")
	var restored_lamp = lamp_button.get_node_or_null("RoomItemPreview3D") if is_instance_valid(lamp_button) else null
	var restored_root := restored_lamp.find_child("DisplayRotationRoot", true, false) as Node3D if is_instance_valid(restored_lamp) else null
	_check(is_instance_valid(restored_lamp) and is_instance_valid(restored_root) and is_equal_approx(restored_root.rotation_degrees.y, 45.0), "reselecting decor restores its saved live 3D yaw")
	touch_room.call("_clear_selection")
	touch_room.call("_show_bag")
	await get_tree().process_frame
	var empty_bag_message := touch_room.bag_overlay.grid.find_child("EmptyBagMessage", true, false) as Label
	_check(is_instance_valid(touch_room.bag_overlay) and touch_room.bag_overlay.grid.columns == 1 and is_instance_valid(empty_bag_message) and empty_bag_message.custom_minimum_size.x >= 600.0, "empty furniture bag uses one full-width message instead of a one-character column")
	_check(not touch_room.bag_button.visible and not touch_room.status_label.visible, "open furniture bag hides the underlying floating button and room status")
	_check(_ui_is_accessible(touch_room.bag_overlay), "Furniture Bag meets readable text, contrast, and touch-target minimums")
	touch_room.bag_overlay.grid.custom_minimum_size.y = touch_room.bag_overlay.catalog_scroll.size.y + 400.0
	await get_tree().process_frame
	var bag_category_chips: Array[Node] = touch_room.bag_overlay.category_scroll.find_children("*", "Button", true, false)
	var bag_category_chip: Button = bag_category_chips[0] as Button if not bag_category_chips.is_empty() else null
	var bag_category_bar: HScrollBar = touch_room.bag_overlay.category_scroll.get_h_scroll_bar()
	var bag_catalog_bar: VScrollBar = touch_room.bag_overlay.catalog_scroll.get_v_scroll_bar()
	_check(is_instance_valid(bag_category_chip) and bag_category_chip.mouse_filter == Control.MOUSE_FILTER_PASS and touch_room.bag_overlay.grid.mouse_filter == Control.MOUSE_FILTER_PASS, "room bag category chips and catalog items pass drag input through to their native ScrollContainers")
	_check(is_instance_valid(bag_category_bar) and bag_category_bar.max_value > bag_category_bar.page and is_instance_valid(bag_catalog_bar) and bag_catalog_bar.max_value > bag_catalog_bar.page, "room bag exposes real native horizontal category and vertical catalog scroll ranges")
	var bag_category_press := InputEventScreenTouch.new()
	bag_category_press.index = 12
	bag_category_press.pressed = true
	touch_room.bag_overlay.call("_on_bag_category_scroll_gui_input", bag_category_press)
	var bag_category_drag := InputEventScreenDrag.new()
	bag_category_drag.index = 12
	bag_category_drag.relative = Vector2(-96, 2)
	touch_room.bag_overlay.call("_on_bag_category_scroll_gui_input", bag_category_drag)
	_check(touch_room.bag_overlay.category_tap_guard.is_dragging() and touch_room.bag_overlay.category_tap_guard.touch_index == 12 and touch_room.bag_overlay.category_tap_guard.dominant_axis == "horizontal", "room bag category guard locks to the chip touch index and dominant axis without global input interception")
	var bag_category_offset_before: int = touch_room.bag_overlay.category_scroll.scroll_horizontal
	touch_room.bag_overlay.call("_on_bag_category_scroll_gui_input", bag_category_drag)
	_check(touch_room.bag_overlay.category_scroll.scroll_horizontal == bag_category_offset_before, "room bag category gesture observer never mutates the native horizontal offset")
	touch_room.bag_overlay.category_scroll.set_deferred("scroll_horizontal", mini(80, int(bag_category_bar.max_value - bag_category_bar.page)))
	await get_tree().process_frame
	_check(touch_room.bag_overlay.category_scroll.scroll_horizontal > 0, "room bag native category ScrollContainer advances after the local drag boundary yields a frame")
	var bag_category_release := InputEventScreenTouch.new()
	bag_category_release.index = 12
	bag_category_release.pressed = false
	touch_room.bag_overlay.call("_on_bag_category_scroll_gui_input", bag_category_release)
	_check(touch_room.bag_overlay.category_tap_guard.touch_index == -1 and touch_room.bag_overlay.category_tap_guard.is_action_suppressed(), "room bag category release clears guard touch state and suppresses its immediate action")
	touch_room.bag_overlay.call("_set_bag_category", "beds")
	_check(touch_room.bag_overlay.category == "all", "room bag category chip actions are suppressed immediately after a horizontal swipe")
	var bag_catalog_press := InputEventScreenTouch.new()
	bag_catalog_press.index = 13
	bag_catalog_press.pressed = true
	touch_room.bag_overlay.call("_on_bag_catalog_scroll_gui_input", bag_catalog_press)
	var bag_catalog_drag := InputEventScreenDrag.new()
	bag_catalog_drag.index = 13
	bag_catalog_drag.relative = Vector2(2, -96)
	touch_room.bag_overlay.call("_on_bag_catalog_scroll_gui_input", bag_catalog_drag)
	_check(touch_room.bag_overlay.catalog_tap_guard.is_dragging() and touch_room.bag_overlay.catalog_tap_guard.touch_index == 13 and touch_room.bag_overlay.catalog_tap_guard.dominant_axis == "vertical", "room bag catalog guard observes a vertical drag without mutating scroll during input")
	var bag_catalog_offset_before: int = touch_room.bag_overlay.catalog_scroll.scroll_vertical
	touch_room.bag_overlay.call("_on_bag_catalog_scroll_gui_input", bag_catalog_drag)
	_check(touch_room.bag_overlay.catalog_scroll.scroll_vertical == bag_catalog_offset_before, "room bag catalog gesture observer never writes the native vertical offset")
	touch_room.bag_overlay.catalog_scroll.set_deferred("scroll_vertical", mini(120, int(bag_catalog_bar.max_value - bag_catalog_bar.page)))
	await get_tree().process_frame
	_check(touch_room.bag_overlay.catalog_scroll.scroll_vertical > 0, "room bag native catalog ScrollContainer advances after the local drag boundary yields a frame")
	var bag_catalog_release := InputEventScreenTouch.new()
	bag_catalog_release.index = 13
	bag_catalog_release.pressed = false
	touch_room.bag_overlay.call("_on_bag_catalog_scroll_gui_input", bag_catalog_release)
	_check(touch_room.bag_overlay.catalog_tap_guard.touch_index == -1 and touch_room.bag_overlay.catalog_tap_guard.is_action_suppressed(), "room bag catalog release clears guard touch state before ScrollContainer scroll-ended timing")
	_check(not touch_room.bag_overlay.has_method("_apply_bag_category_scroll_drag") and not touch_room.bag_overlay.has_method("_apply_bag_catalog_scroll_drag") and not touch_room.has_method("_mark_root_input_handled"), "room bag no longer uses root viewport input handling or custom scroll mutation")
	AppState.data["inventory"]["lamp"] = 1
	touch_room.bag_overlay.call("_select_item", "lamp")
	_check(AppState.available_count("lamp") == 1 and touch_room.selected_id.is_empty(), "room bag item placement is suppressed immediately after a vertical swipe")
	AppState.data["inventory"]["lamp"] = 0
	touch_room.call("_close_bag")
	await _release_scene(touch_room)
	_check(AppState.remove_room_item("rainbow", "test_lamp") and AppState.available_count("lamp") == 1, "removed decor returns to the shared bag")
	_check(AppState.sell_furniture("lamp") and AppState.coins() == 425, "unused decor sells for the floored fifty-percent refund")
	AppState.data = profile_before_room_flow
	SaveService.save_state(AppState.data)
	# Main-shell and login lifecycle coverage lives in runtime_main_shell_integration.
	# Preserve the core suite's isolated-save cleanup below.
	AppState.data = pre_test_data
	AppState.selected_game_id = original_game
	AppState.selected_category = original_category
	SaveService.end_test_session()
	if failures.is_empty():
		print("GODOT_RUNTIME_INTEGRATION_OK: %d checks passed" % check_count)
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error(failure)
		get_tree().quit(1)


func _release_scene(scene: Node) -> void:
	if not is_instance_valid(scene):
		return
	if scene.has_method("prepare_for_scene_change"):
		var ready: Variant = scene.call("prepare_for_scene_change")
		if ready is Signal:
			await ready
	scene.queue_free()
	# Let SceneTree deliver exit notifications and let the renderer retire any
	# SubViewport resources before mounting the next scene.
	await get_tree().process_frame
	await get_tree().process_frame


func _exercise_first_move(game_id: String, game: Node) -> void:
	if game_id in ["sentence_sprout", "syllable_stamp", "scramble_spell", "size_line_up"]:
		var expected = game.sequence[0]
		var index: int = game.pool.find(expected)
		game.call("_choose_sequence", {"value": expected, "index": index})
		_check(game.picked.size() == 1, "%s accepts the first ordered item" % game_id)
		return
	if game_id == "letter_lift":
		var first_target: String = game.expected_word
		game.call("_handle_letter_input", first_target.left(1))
		_check(game.picked.size() == 1 and game.secondary_label.text == "TARGET: %s" % first_target.to_upper(), "Letter Lift accepts the next exact letter while retaining its complete target")
		for letter_index in range(1, first_target.length()):
			game.call("_handle_letter_input", first_target.left(letter_index + 1))
		_check(game.round_index == 1 and game.secondary_label.text == "TARGET: %s" % game.expected_word.to_upper(), "Letter Lift reveals the full new target after the first round instead of only one next letter")
		return
	if game_id == "sight_spark":
		game.call("_finish_sight_flash")
		game.call("_on_text_submitted", game.expected_word)
		_check(game.round_index == 1, "Sight Spark accepts the memorized word")
		return
	if game_id == "unicorn_blast":
		_check(not game.blast_words.is_empty(), "Unicorn Blast spawns an initial word")
		_check(game.play_area.custom_minimum_size.y >= 430 and is_instance_valid(game.cannon_assembly) and game.cannon_assembly.has_node("CannonCanvas/CannonRainbowBarrel") and game.cannon_assembly.has_node("CannonCanvas/CannonEquippedUnicornAmmo"), "Unicorn Blast has a tall field and an equipped-unicorn cannon assembly with a stable inner canvas")
		var word := str(game.blast_words[0]["text"])
		var target: Button = game.blast_words[0]["button"]
		game.call("_handle_blast_input", word)
		_check(game.round_index == 1 and game.blast_words.is_empty() and is_instance_valid(target) and target.disabled and game.pending_blast_targets.has(target) and not game.blast_projectiles.is_empty(), "Unicorn Blast removes a matched word from gameplay while preserving its hit visual for the projectile")
		return
	var answer := ""
	match game_id:
		"vowel_vines":
			for button in game.options.get_children():
				if str(button.text).left(1).to_lower() == str(game.current["vowel"]):
					answer = button.text
					break
		"odd_one_out":
			answer = str(game.current["odd"])
		"chain_link":
			for option in game.current["options"]:
				if Rules.is_chain_link(str(game.current["start"]), str(option)):
					answer = str(option)
					break
		_:
			answer = str(game.current.get("answer", ""))
	_check(not answer.is_empty(), "%s exposes a valid answer" % game_id)
	if game_id in ["caption_quest", "odd_one_out"]:
		var wrong := _find_wrong_choice(game_id, game, answer)
		game.call("_choose", wrong)
		_check(game.lives == 2 and game.active, "%s consumes one life without immediate failure" % game_id)
	game.call("_choose", answer)
	_check(game.round_index == 1, "%s accepts its exact correct choice" % game_id)


func _find_wrong_choice(game_id: String, game: Node, answer: String) -> String:
	if game_id == "caption_quest":
		for option in game.current["options"]:
			if str(option) != answer:
				return str(option)
	else:
		for item in game.current["items"]:
			if str(item["label"]) != answer:
				return str(item["label"])
	return "__wrong__"


func _mathtris_fixture(game: Node, cells_to_fill: Array[Vector2i]) -> void:
	game.board = game.call("_make_board")
	game.falling.clear()
	game.active = true
	game.equation_charge = 3
	game.score = 0
	game.level = 1
	game.slow_until_ms = 0
	for cell in cells_to_fill:
		game.board[cell.y][cell.x] = "1"


func _mathtris_companion_power_contract(game: Node) -> void:
	# Every original power consumes a three-clear charge only after its real action succeeds.
	_mathtris_fixture(game, [])
	for col in 5:
		game.board[11][col] = ["1", "+", "1", "=", "2"][col]
	_check(game.call("apply_companion_power", "sparkle") and game.equation_charge == 0 and game.score == 400, "Mathtris Sparkle clears exact hits for 80 points each without normal-match scoring")
	_mathtris_fixture(game, [Vector2i(0, 13), Vector2i(1, 13)])
	_check(game.call("apply_companion_power", "rainbow") and game.board[13][0] == "" and game.equation_charge == 0, "Mathtris Rainbow clears the occupied bottom row after three clears")
	_mathtris_fixture(game, [Vector2i(3, 8), Vector2i(3, 10)])
	_check(game.call("apply_companion_power", "star") and game.board[8][3] == "" and game.equation_charge == 0, "Mathtris Star clears the fullest occupied column after three clears")
	_mathtris_fixture(game, [])
	_check(game.call("apply_companion_power", "cloud") and game.slow_until_ms - game.level_run.elapsed_ms() >= 17990 and game.equation_charge == 0, "Mathtris Cloud slows falling for eighteen seconds of active play after three clears")
	_mathtris_fixture(game, [])
	for col in 5:
		game.board[10][col] = ["1", "+", "1", "=", "3"][col]
	_check(game.call("apply_companion_power", "dream") and game.equation_charge == 0 and game.score == 600, "Mathtris Dream clears exact repaired hits for 120 points each without normal-match scoring")
	_mathtris_fixture(game, [Vector2i(0, 10), Vector2i(7, 13)])
	_check(game.call("apply_companion_power", "mystic") and game.call("_find_equations").is_empty() and game.equation_charge == 0, "Mathtris Mystic clears every settled tile after three clears")
	for companion_id in ["sparkle", "rainbow", "star", "cloud", "dream", "mystic"]:
		_mathtris_fixture(game, [Vector2i(0, 13)])
		game.equation_charge = 2
		var score_before: int = game.score
		_check(not game.call("apply_companion_power", companion_id) and game.equation_charge == 2 and game.score == score_before, "Mathtris %s cannot spend a power before three clears" % companion_id)
	for companion_id in ["rainbow", "star", "dream", "mystic"]:
		_mathtris_fixture(game, [])
		_check(not game.call("apply_companion_power", companion_id) and game.equation_charge == 3 and game.score == 0, "Mathtris %s keeps its charge when the board cannot use it" % companion_id)


func _skeletons_are_in_rest_pose(node: Node) -> bool:
	var skeletons: Array[Node] = node.find_children("*", "Skeleton3D", true, false)
	if node is Skeleton3D:
		skeletons.push_front(node)
	if skeletons.is_empty():
		return false
	for skeleton_node in skeletons:
		var skeleton := skeleton_node as Skeleton3D
		for bone_index in skeleton.get_bone_count():
			if not skeleton.get_bone_pose(bone_index).is_equal_approx(skeleton.get_bone_rest(bone_index)):
				return false
	return true


func _storybook_action_count(root: Node) -> int:
	var count := 0
	for node in root.find_children("*", "Button", true, false):
		var button := node as Button
		if not button.has_meta("storybook_game_action"):
			continue
		var normal := button.get_theme_stylebox("normal") as StyleBoxFlat
		if is_instance_valid(normal) and normal.border_width_left >= 3 and button.custom_minimum_size.y >= 58.0 and button.get_theme_font_size("font_size") >= 19:
			count += 1
	return count


func _check(condition: bool, message: String) -> void:
	check_count += 1
	if not condition:
		failures.append(message)


func _ui_is_accessible(root: Node) -> bool:
	var issues: Array[String] = []
	_collect_ui_issues(root, issues)
	if not issues.is_empty():
		push_warning("UI accessibility issues: %s" % "; ".join(issues.slice(0, 8)))
	return issues.is_empty()


func _collect_ui_issues(node: Node, issues: Array[String]) -> void:
	if node is Control and (node as Control).is_visible_in_tree():
		var control := node as Control
		if control is Label and not (control as Label).text.strip_edges().is_empty():
			if control.get_theme_font_size("font_size") < 19:
				issues.append("small label %s" % control.name)
			if control.get_theme_constant("outline_size") < 2:
				issues.append("low-contrast label %s" % control.name)
		if control is BaseButton:
			var required_touch_height := 44.0 if control.has_meta("mathtris_tile") else 56.0
			if control.custom_minimum_size.y < required_touch_height:
				issues.append("short touch target %s" % control.name)
			if control.get_theme_font_size("font_size") < 18:
				issues.append("small button text %s" % control.name)
		if control is LineEdit or control is TextEdit:
			if control.custom_minimum_size.y < 56.0 or control.get_theme_font_size("font_size") < 19:
				issues.append("small text input %s" % control.name)
	for child in node.get_children():
		_collect_ui_issues(child, issues)
