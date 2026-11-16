extends ArcadeGameController

const Rules = preload("res://scripts/games/gameplay_rules.gd")
const StorybookUI = preload("res://scripts/ui/storybook_ui.gd")
const RoomItemPreviewScene = preload("res://scripts/meta/room_item_preview_3d.gd")
const EquationGenerator = preload("res://scripts/games/equation_generator.gd")

const LANES := 3
const START_Y := 220.0

var level := 1
var target_rescues := 0
var rescues := 0
var score := 0
var lives := 3
var active := false
var selected_lane := 1
var correct_lane := 0
var current_problem: Dictionary = {}
var wave_elapsed_ms := 0.0
var decision_ms := 0.0
var wave_resolved := false
var feedback_ms := 0.0
var hint_ms := 0.0
var started_ms := 0
var rng := RandomNumberGenerator.new()
var lane_buttons: Array[Button] = []
var equation_label: Label
var meter_label: Label
var status_label: Label
var action_button: Button
var fire_button: Button
var player_preview: RoomItemPreview3D
var bolt_lane := -1
var bolt_ms := 0.0
var _lane_geometry_size := Vector2(-1, -1)
var _lane_geometry_rebuild_count := 0


func _ready() -> void:
	rng.randomize()
	mouse_filter = Control.MOUSE_FILTER_STOP
	level = AppState.current_level("comet_math_rescue")
	_build_ui()
	_start_level(level)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and lane_buttons.size() == LANES:
		_update_comet_positions()


static func generate_problem(for_level: int, generator: RandomNumberGenerator) -> Dictionary:
	var core := EquationGenerator.comet_math_rescue_core(for_level, generator)
	var operation := str(core["operation"])
	var left := int(core["left"])
	var right := int(core["right"])
	var answer := int(core["answer"])
	var answers: Array[int] = [answer]
	var step := maxi(1, mini(8, 1 + for_level / 3))
	for offset in [-2, -1, 1, 2, 3]:
		var distractor := maxi(0, answer + offset * step)
		if distractor != answer and not distractor in answers:
			answers.append(distractor)
		if answers.size() == LANES:
			break
	while answers.size() < LANES:
		var fallback := answer + answers.size() * step + 1
		if not fallback in answers:
			answers.append(fallback)
	# Do not use Array.shuffle(): it draws from Godot's global RNG and would make
	# a supplied seeded generator only partly deterministic.
	for index in range(answers.size() - 1, 0, -1):
		var swap_index := generator.randi_range(0, index)
		var swap := answers[index]
		answers[index] = answers[swap_index]
		answers[swap_index] = swap
	return {"left": left, "right": right, "operation": operation, "answer": answer, "answers": answers, "correct_index": answers.find(answer)}


static func display_operation(operation: String) -> String:
	return "×" if operation == "x" else ("÷" if operation == "/" else operation)


func _process(delta: float) -> void:
	super(delta)
	if not active:
		return
	var ms := delta * 1000.0 * CompanionAbilityService.time_scale()
	if feedback_ms > 0.0:
		feedback_ms -= ms
		bolt_ms = maxf(0.0, bolt_ms - ms)
		if feedback_ms <= 0.0 and active:
			_spawn_wave()
		queue_redraw()
		return
	wave_elapsed_ms += ms
	hint_ms = maxf(0.0, hint_ms - ms)
	bolt_ms = maxf(0.0, bolt_ms - ms)
	_update_comet_positions()
	if wave_elapsed_ms >= decision_ms:
		_resolve_timeout()
	queue_redraw()


func _input(event: InputEvent) -> void:
	if not active or wave_resolved:
		return
	if event is InputEventScreenTouch and event.pressed:
		if not _is_playable_aim_position(event.position):
			return
		_select_lane(_lane_for_x(event.position.x - get_global_rect().position.x))
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		if not _is_playable_aim_position(event.position):
			return
		_select_lane(_lane_for_x(event.position.x - get_global_rect().position.x))
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if _is_playable_aim_position(event.position):
			_select_lane(_lane_for_x(event.position.x - get_global_rect().position.x))
	elif event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		if _is_playable_aim_position(event.position):
			_select_lane(_lane_for_x(event.position.x - get_global_rect().position.x))


func _start_level(for_level: int) -> void:
	_start_level_with_lifecycle(for_level, true)


func _start_level_with_lifecycle(for_level: int, begin_run: bool) -> void:
	if begin_run:
		level_run.begin("comet_math_rescue", maxi(1, for_level))
		level = level_run.level
	else:
		level = level_run.level
	target_rescues = Rules.comet_target(level)
	rescues = 0
	score = 0
	lives = 3
	selected_lane = 1
	started_ms = level_run.started_ms
	active = level_run.active
	action_button.hide()
	status_label.text = "Aim at a lane, then FIRE RAINBOW to check that comet."
	fire_button.show()
	fire_button.disabled = false
	_spawn_wave()


func _spawn_wave() -> void:
	if not active:
		return
	current_problem = generate_problem(level, rng)
	correct_lane = int(current_problem["correct_index"])
	wave_elapsed_ms = 0.0
	decision_ms = Rules.comet_decision_ms(level)
	wave_resolved = false
	fire_button.show()
	fire_button.disabled = false
	feedback_ms = 0.0
	bolt_lane = -1
	equation_label.text = "%d %s %d = ?" % [int(current_problem["left"]), display_operation(str(current_problem["operation"])), int(current_problem["right"])]
	for lane in LANES:
		lane_buttons[lane].text = str((current_problem["answers"] as Array)[lane])
		lane_buttons[lane].tooltip_text = "Comet lane %d, answer %s" % [lane + 1, lane_buttons[lane].text]
		lane_buttons[lane].disabled = false
	_update_comet_positions()
	_update_hud()


func _select_lane(lane: int) -> void:
	if not active or wave_resolved:
		return
	selected_lane = clampi(lane, 0, LANES - 1)
	status_label.text = "Rainbow sight locked on lane %d." % (selected_lane + 1)
	_update_comet_positions()


func _resolve_wave(force_correct := false) -> bool:
	if not active or wave_resolved or current_problem.is_empty():
		return false
	wave_resolved = true
	fire_button.disabled = true
	fire_button.hide()
	for button in lane_buttons:
		button.disabled = true
	if force_correct:
		selected_lane = correct_lane
	bolt_lane = selected_lane
	bolt_ms = 520.0
	var correct := selected_lane == correct_lane
	if correct:
		var remaining := clampf(1.0 - wave_elapsed_ms / maxf(1.0, decision_ms), 0.0, 1.0)
		var gained := Rules.comet_correct_score(level, remaining)
		score += gained
		rescues += 1
		AudioService.play(&"correct")
		status_label.text = "Correct! Rescue star gained: +%d score." % gained
	else:
		lives -= 1
		AudioService.play(&"wrong")
		status_label.text = "Not this comet. Shield lost — %d shield hearts left." % lives
	_finish_wave()
	return correct


func _finish_wave(timed_out := false) -> void:
	if lives <= 0:
		level_run.fail("Time ran out. Three comets slipped through. Retry this rescue mission." if timed_out else "Three comets slipped through. Retry this rescue mission.")
		active = level_run.active
		action_button.text = "Retry"
		action_button.show()
		status_label.text = "Time ran out. Three comets slipped through. Retry this rescue mission." if timed_out else "Three comets slipped through. Retry this rescue mission."
	elif rescues >= target_rescues:
		var reward := level_run.complete()
		active = level_run.active
		action_button.text = "Next Mission"
		action_button.show()
		status_label.text = "Rescue complete! +%d coins" % reward
	else:
		feedback_ms = 650.0 if not AppState.setting("reduced_motion", false) else 1.0
	_update_hud()
	queue_redraw()


func _resolve_timeout() -> bool:
	if not active or wave_resolved or current_problem.is_empty():
		return false
	wave_resolved = true
	fire_button.disabled = true
	fire_button.hide()
	for button in lane_buttons:
		button.disabled = true
	# A timeout is a miss, not an implicit shot at the highlighted lane.
	bolt_lane = -1
	bolt_ms = 0.0
	lives -= 1
	status_label.text = "Time ran out. That comet slipped past."
	_finish_wave(true)
	return false


func _mystic_rescue() -> bool:
	if not active or wave_resolved:
		return false
	return _resolve_wave(true)


func can_show_hint() -> bool:
	return active and not wave_resolved and not current_problem.is_empty()


func _show_hint() -> void:
	if not can_show_hint():
		return
	hint_ms = 1500.0
	status_label.text = "Hint: the glowing comet solves the equation. Choose lane %d." % (correct_lane + 1)
	_update_comet_positions()


func can_retry_failure() -> bool:
	return level_run.can_retry()


func retry_failure() -> void:
	if can_retry_failure():
		_start_level_with_lifecycle(level_run.retry(), false)


func _advance_level() -> void:
	match level_run.outcome:
		LevelRunController.Outcome.SUCCESS, LevelRunController.Outcome.FAILURE:
			_start_level_with_lifecycle(level_run.retry(), false)


func _lane_for_x(x: float) -> int:
	return clampi(int(floor(x / maxf(1.0, size.x / LANES))), 0, LANES - 1)


func _is_playable_aim_position(screen_position: Vector2) -> bool:
	var game_rect := get_global_rect()
	if not game_rect.has_point(screen_position) or screen_position.y < game_rect.position.y + 165.0:
		return false
	# The equation/header is above the lane field, and the status/action chrome
	# must never silently retarget the unicorn when the player taps FIRE.
	if is_instance_valid(status_label) and status_label.get_global_rect().has_point(screen_position):
		return false
	var action_bar := get_node_or_null("CometActionBar") as Control
	return not is_instance_valid(action_bar) or not action_bar.get_global_rect().has_point(screen_position)


func _update_hud() -> void:
	meter_label.text = "RESCUE %d / %d     SHIELDS %d     SCORE %d" % [rescues, target_rescues, lives, score]


func _update_comet_positions() -> void:
	var progress := clampf(wave_elapsed_ms / maxf(1.0, decision_ms), 0.0, 1.0)
	var y := START_Y + progress * maxf(180.0, size.y * 0.46)
	if not _lane_geometry_size.is_equal_approx(size):
		_lane_geometry_size = size
		_lane_geometry_rebuild_count += 1
		for lane in LANES:
			var lane_button := lane_buttons[lane]
			lane_button.size = Vector2(maxf(112.0, size.x / LANES - 20.0), 76.0)
			lane_button.position.x = (lane + 0.5) * size.x / LANES - lane_button.size.x * 0.5
	for lane in LANES:
		var button := lane_buttons[lane]
		button.position.y = y
		var selected := lane == selected_lane
		var hinted := hint_ms > 0.0 and lane == correct_lane
		button.modulate = Color("fff2a8") if hinted else (Color("ffffff") if selected else Color("d9e9ff"))
		button.scale = Vector2.ONE * (1.08 if hinted else (1.04 if selected else 1.0))
	if is_instance_valid(player_preview):
		player_preview.position = Vector2((selected_lane + 0.5) * size.x / LANES - player_preview.size.x * 0.5, size.y - 172.0)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("110a32"))
	for lane in range(1, LANES):
		var x := lane * size.x / LANES
		draw_line(Vector2(x, 165), Vector2(x, size.y - 115), Color("6f68ac", 0.58), 5.0)
		draw_line(Vector2(x + 5, 165), Vector2(x + 5, size.y - 115), Color("55d6e8", 0.24), 2.0)
	for lane in LANES:
		var x := (lane + 0.5) * size.x / LANES
		draw_string(ThemeDB.fallback_font, Vector2(x - 32, 188), "LANE %d" % (lane + 1), HORIZONTAL_ALIGNMENT_CENTER, 64, 16, Color("c8c5f5"))
	for lane in LANES:
		if lane >= lane_buttons.size():
			continue
		var comet_center := lane_buttons[lane].position + lane_buttons[lane].size * 0.5
		draw_line(comet_center + Vector2(-46, 30), comet_center + Vector2(-12, 9), Color("c17cf2", 0.62), 14.0)
		draw_line(comet_center + Vector2(-46, 30), comet_center + Vector2(-12, 9), Color("ffe172", 0.82), 4.0)
		draw_circle(comet_center, 47.0, Color("69d8ef", 0.36))
		draw_arc(comet_center, 42.0, 0.15, TAU - 0.15, 18, Color("e9fbff", 0.75), 3.0)
	if bolt_ms > 0.0 and bolt_lane >= 0:
		var x := (bolt_lane + 0.5) * size.x / LANES
		var alpha := bolt_ms / 520.0
		draw_line(Vector2(x, size.y - 138), Vector2(x, START_Y + size.y * 0.46), Color(0.37, 0.91, 1.0, alpha), 14.0)
		draw_line(Vector2(x, size.y - 138), Vector2(x, START_Y + size.y * 0.46), Color("ffe172", alpha), 5.0)


func _build_ui() -> void:
	equation_label = Label.new()
	equation_label.name = "CometEquationBanner"
	equation_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	equation_label.position.y = 112
	equation_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	equation_label.add_theme_font_size_override("font_size", 34)
	equation_label.add_theme_color_override("font_color", Color("fff5e9"))
	equation_label.add_theme_constant_override("outline_size", 4)
	equation_label.add_theme_color_override("font_outline_color", Color("271748"))
	add_child(equation_label)
	meter_label = Label.new()
	meter_label.name = "CometRescueMeter"
	meter_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	meter_label.position.y = 66
	meter_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	meter_label.add_theme_font_size_override("font_size", 20)
	meter_label.add_theme_color_override("font_color", Color("7fe7ef"))
	add_child(meter_label)
	for lane in LANES:
		var comet := Button.new()
		comet.name = "CometLane%d" % lane
		comet.custom_minimum_size = Vector2(112, 76)
		comet.add_theme_font_size_override("font_size", 30)
		StorybookUI.apply_button(comet, Color("496bd5"), false, 22)
		comet.pressed.connect(_select_lane.bind(lane))
		add_child(comet)
		lane_buttons.append(comet)
	player_preview = RoomItemPreviewScene.new()
	player_preview.name = "CometEquippedCompanion"
	player_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	player_preview.size = Vector2(150, 120)
	player_preview.setup({"id": "companion_%s" % AppState.equipped_companion(), "category": "companions", "animate": true, "presentation": "marketplace"})
	player_preview.z_index = 4
	add_child(player_preview)
	status_label = Label.new()
	status_label.name = "CometStatus"
	status_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	status_label.position.y = -104
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.add_theme_font_size_override("font_size", 19)
	status_label.add_theme_color_override("font_color", Color("fff0ac"))
	status_label.add_theme_constant_override("outline_size", 3)
	status_label.add_theme_color_override("font_outline_color", Color("1b1038"))
	add_child(status_label)
	var actions := HBoxContainer.new()
	actions.name = "CometActionBar"
	actions.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	actions.position.y = -58
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(actions)
	fire_button = Button.new()
	fire_button.name = "CometFireRainbowButton"
	fire_button.text = "FIRE RAINBOW"
	StorybookUI.apply_game_action(fire_button, 210)
	fire_button.pressed.connect(_resolve_wave)
	actions.add_child(fire_button)
	action_button = StorybookUI.progression_action_button("", 170, _advance_level)
	actions.add_child(action_button)
	var back := StorybookUI.category_back_button("Arcade", 150, return_to_category)
	actions.add_child(back)
