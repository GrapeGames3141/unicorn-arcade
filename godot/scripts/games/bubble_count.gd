extends ArcadeGameController

## Bubble Count: numbered bubbles drift around the meadow sky. Pop them from the
## smallest number to the biggest. Later levels skip-count by 2s, 5s, and 10s.
const StorybookUI = preload("res://scripts/ui/storybook_ui.gd")
const START_LIVES := 3
const BUBBLE_COLORS := [Color("58d6e8"), Color("f26fa7"), Color("ffd166"), Color("b79cff"), Color("62e6a7"), Color("ff9f5a")]

var game_id := "bubble_count"
var level := 1
var active := false
var failed := false
var started_ms := 0
var lives := START_LIVES
var bubbles: Array[Dictionary] = []
var order: Array[int] = []
var next_index := 0
var hint_value := -1
var pops: Array[Dictionary] = []
var rng := RandomNumberGenerator.new()
var play_area: Control
var progress_label: Label
var message_label: Label


static func bubble_total(for_level: int) -> int:
	return clampi(4 + for_level, 5, 12)


static func step_for_level(for_level: int) -> int:
	if for_level <= 3:
		return 1
	if for_level <= 6:
		return 2
	if for_level <= 9:
		return 5
	return 10


static func speed_for_level(for_level: int) -> float:
	return minf(96.0, 22.0 + 7.0 * for_level)


static func values_for_level(for_level: int, random: RandomNumberGenerator) -> Array[int]:
	var step := step_for_level(for_level)
	# From level 3 the count may begin part-way along the number line.
	var first := step * (1 if for_level < 3 else random.randi_range(1, 4))
	var values: Array[int] = []
	for index in bubble_total(for_level):
		values.append(first + step * index)
	return values


func _ready() -> void:
	rng.randomize()
	level = AppState.current_level(game_id)
	_build_ui()
	_start_level()


func set_random_seed(seed_value: int) -> void:
	rng.seed = seed_value


func _start_level() -> void:
	_start_level_with_lifecycle(true)


func _start_level_with_lifecycle(begin_run: bool) -> void:
	if begin_run:
		level_run.begin(game_id, level)
	else:
		level = level_run.level
	active = level_run.active
	failed = false
	started_ms = level_run.started_ms
	lives = START_LIVES
	next_index = 0
	hint_value = -1
	pops.clear()
	order = values_for_level(level, rng)
	_spawn_bubbles()
	message_label.text = "Pop the bubbles from smallest to biggest!"
	_refresh_progress()


func _play_size() -> Vector2:
	var area := play_area.size
	return Vector2(maxf(area.x, 320.0), maxf(area.y, 360.0))


func _spawn_bubbles() -> void:
	bubbles.clear()
	var area := _play_size()
	var radius := clampf(minf(area.x, area.y) / (2.7 + order.size() * 0.26), 44.0, 76.0)
	var speed := speed_for_level(level) * (0.5 if bool(AppState.setting("reduced_motion", false)) else 1.0)
	var columns := 3 if order.size() <= 9 else 4
	var rows := int(ceil(order.size() / float(columns)))
	var slots: Array[int] = []
	for index in columns * rows:
		slots.append(index)
	for index in order.size():
		var slot: int = slots.pop_at(rng.randi_range(0, slots.size() - 1))
		var cell := Vector2(area.x / columns, area.y / rows)
		var center := Vector2((slot % columns + 0.5) * cell.x, (int(slot / float(columns)) + 0.5) * cell.y)
		var angle := rng.randf_range(0.0, TAU)
		bubbles.append({
			"value": order[index],
			"position": center,
			"velocity": Vector2(cos(angle), sin(angle)) * speed * rng.randf_range(0.7, 1.15),
			"radius": radius,
			"color": BUBBLE_COLORS[index % BUBBLE_COLORS.size()],
			"popped": false,
			"shake": 0.0,
		})
	play_area.queue_redraw()


func _process(delta: float) -> void:
	super._process(delta)
	if bubbles.is_empty():
		return
	var area := _play_size()
	if active and not gameplay_paused:
		for bubble in bubbles:
			if bool(bubble["popped"]):
				continue
			var radius: float = bubble["radius"]
			var position: Vector2 = bubble["position"] + bubble["velocity"] * delta
			var velocity: Vector2 = bubble["velocity"]
			if position.x < radius or position.x > area.x - radius:
				velocity.x = -velocity.x
				position.x = clampf(position.x, radius, area.x - radius)
			if position.y < radius or position.y > area.y - radius:
				velocity.y = -velocity.y
				position.y = clampf(position.y, radius, area.y - radius)
			bubble["position"] = position
			bubble["velocity"] = velocity
			bubble["shake"] = maxf(0.0, float(bubble["shake"]) - delta)
		_separate_bubbles()
	for pop in pops:
		pop["age"] = float(pop["age"]) + delta
	pops = pops.filter(func(pop: Dictionary) -> bool: return float(pop["age"]) < 0.35)
	play_area.queue_redraw()


## Bubbles bounce off each other so numbers never hide behind one another.
func _separate_bubbles() -> void:
	for first_index in bubbles.size():
		var first := bubbles[first_index]
		if bool(first["popped"]):
			continue
		for second_index in range(first_index + 1, bubbles.size()):
			var second := bubbles[second_index]
			if bool(second["popped"]):
				continue
			var offset: Vector2 = second["position"] - first["position"]
			var reach := float(first["radius"]) + float(second["radius"])
			var distance := offset.length()
			if distance >= reach:
				continue
			var normal := offset / distance if distance > 0.01 else Vector2.RIGHT
			var push := (reach - distance) * 0.5
			first["position"] = first["position"] - normal * push
			second["position"] = second["position"] + normal * push
			var first_speed := (first["velocity"] as Vector2).dot(normal)
			var second_speed := (second["velocity"] as Vector2).dot(normal)
			if first_speed - second_speed > 0.0:
				first["velocity"] = first["velocity"] + normal * (second_speed - first_speed)
				second["velocity"] = second["velocity"] + normal * (first_speed - second_speed)


func _play_area_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		tap_at(event.position)
		play_area.accept_event()


func tap_at(point: Vector2) -> void:
	if not active or gameplay_paused:
		return
	# Later bubbles draw on top, so search from the front.
	for index in range(bubbles.size() - 1, -1, -1):
		var bubble := bubbles[index]
		if bool(bubble["popped"]):
			continue
		if point.distance_to(bubble["position"]) <= float(bubble["radius"]) + 6.0:
			pop_value(int(bubble["value"]))
			return


func pop_value(value: int) -> void:
	if not active or next_index >= order.size():
		return
	var bubble: Dictionary = {}
	for candidate in bubbles:
		if int(candidate["value"]) == value and not bool(candidate["popped"]):
			bubble = candidate
			break
	if bubble.is_empty():
		return
	if value == order[next_index]:
		bubble["popped"] = true
		pops.append({"position": bubble["position"], "radius": bubble["radius"], "color": bubble["color"], "age": 0.0})
		next_index += 1
		hint_value = -1
		if next_index >= order.size():
			var reward := level_run.complete()
			active = level_run.active
			message_label.text = "All popped in order! +%d coins" % reward
			level += 1
		else:
			AudioService.play(&"pop")
			message_label.text = "Pop! Next find %d." % order[next_index]
	else:
		lives -= 1
		bubble["shake"] = 0.35
		if lives <= 0:
			level_run.fail("Out of hearts. Count up slowly from the smallest number.")
			active = level_run.active
			failed = level_run.outcome == LevelRunController.Outcome.FAILURE
			message_label.text = "Out of hearts. Count up slowly from the smallest number."
		else:
			AudioService.play(&"wrong")
			message_label.text = "%d is not next. Look for a smaller number." % value
	_refresh_progress()
	play_area.queue_redraw()


func _draw_play_area() -> void:
	var font := ThemeDB.fallback_font
	for bubble in bubbles:
		if bool(bubble["popped"]):
			continue
		var radius: float = bubble["radius"]
		var shake := float(bubble["shake"])
		var center: Vector2 = bubble["position"] + Vector2(sin(shake * 60.0) * 7.0 * shake / 0.35, 0.0)
		var color: Color = bubble["color"]
		if int(bubble["value"]) == hint_value:
			play_area.draw_circle(center, radius + 9.0, Color(StorybookUI.GOLD_BRIGHT, 0.55))
		play_area.draw_circle(center, radius, Color(color, 0.42))
		play_area.draw_arc(center, radius, 0.0, TAU, 48, Color(color.lightened(0.35), 0.95), 4.0, true)
		play_area.draw_arc(center, radius * 0.72, -2.5, -1.35, 12, Color(1, 1, 1, 0.8), 5.0, true)
		var label := str(bubble["value"])
		var font_size := int(radius * (0.95 if label.length() <= 2 else 0.72))
		var text_size := font.get_string_size(label, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
		var origin := Vector2(center.x - text_size.x * 0.5, center.y + font_size * 0.36)
		play_area.draw_string_outline(font, origin, label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 8, Color("172143"))
		play_area.draw_string(font, origin, label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)
	for pop in pops:
		var progress := float(pop["age"]) / 0.35
		var ring_color := Color(pop["color"], 1.0 - progress)
		play_area.draw_arc(pop["position"], float(pop["radius"]) * (1.0 + progress * 0.7), 0.0, TAU, 40, ring_color, 5.0, true)
		for spark in 6:
			var angle := TAU * spark / 6.0
			play_area.draw_circle(pop["position"] + Vector2(cos(angle), sin(angle)) * float(pop["radius"]) * (0.8 + progress), 5.0 * (1.0 - progress), ring_color)


func _refresh_progress() -> void:
	progress_label.text = "LEVEL %d   •   POPPED %d / %d   •   ♥ %d" % [level_run.level, next_index, order.size(), maxi(0, lives)]


func build_objective_snapshot(_id: String, _level: int) -> Dictionary:
	var step := step_for_level(level_run.level)
	var detail := "COUNT UP BY ONES" if step == 1 else "SKIP-COUNT BY %dS" % step
	if next_index < order.size():
		return {"primary": "POP NUMBER %d" % order[next_index], "detail": "%s • %d HEARTS" % [detail, maxi(0, lives)]}
	return {"primary": "ALL POPPED!", "detail": detail}


func can_show_hint() -> bool:
	return active and not failed and next_index < order.size()


func _show_hint() -> void:
	if not can_show_hint():
		return
	hint_value = order[next_index]
	message_label.text = "The glowing bubble is next."
	play_area.queue_redraw()


func can_retry_failure() -> bool:
	return level_run.can_retry()


func retry_failure() -> void:
	if level_run.can_retry():
		level = level_run.retry()
		_start_level_with_lifecycle(false)


func _advance_level() -> void:
	if level_run.outcome == LevelRunController.Outcome.RUNNING:
		_start_level_with_lifecycle(true)
		return
	level = level_run.retry()
	_start_level_with_lifecycle(false)


func _build_ui() -> void:
	var background := ColorRect.new()
	background.color = Color("08112f")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_bottom", 24)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(margin)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 12)
	margin.add_child(layout)
	progress_label = Label.new()
	progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	StorybookUI.apply_story_label(progress_label, StorybookUI.CREAM, 20, true)
	layout.add_child(progress_label)
	var frame := PanelContainer.new()
	frame.name = "BubbleSky"
	frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	frame.add_theme_stylebox_override("panel", StorybookUI.plaque_style(Color(0.08, 0.07, 0.3, 0.55), StorybookUI.GOLD, 22))
	layout.add_child(frame)
	play_area = Control.new()
	play_area.name = "BubblePlayArea"
	play_area.clip_contents = true
	play_area.mouse_filter = Control.MOUSE_FILTER_STOP
	play_area.gui_input.connect(_play_area_input)
	play_area.draw.connect(_draw_play_area)
	play_area.resized.connect(func() -> void:
		if next_index == 0 and active:
			_spawn_bubbles()
	)
	frame.add_child(play_area)
	message_label = Label.new()
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	StorybookUI.apply_story_label(message_label, StorybookUI.GOLD_BRIGHT, 20, true)
	layout.add_child(message_label)
	var retry := StorybookUI.progression_action_button("Retry / Next", 170, _advance_level)
	retry.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	layout.add_child(retry)
	retry.hide()
