extends ArcadeGameController

const Rules = preload("res://scripts/games/gameplay_rules.gd")
const StorybookUI = preload("res://scripts/ui/storybook_ui.gd")
const COLS := 8
const ROWS := 14

var board: Array[Array] = []
var falling: Array[Dictionary] = []
var cells: Array[Button] = []
var selected := Vector2i(-1, -1)
var score := 0
var level := 1
var drops_placed := 0
var active := false
var fall_accumulator := 0.0
var started_ms := 0
var last_spawn_col := -1
var hud_label: Label
var message_label: Label
var next_label: Label
var action_button: Button
var rng := RandomNumberGenerator.new()
var swipe_cell := Vector2i(-1, -1)
var swipe_start := Vector2.ZERO
var swipe_consumed := false
var equation_charge := 0
var slow_until_ms := 0
var _test_force_seed_failure := false
var _tile_style_cache := {}


func _ready() -> void:
	rng.randomize()
	_build_ui()
	_start_game()


func _process(delta: float) -> void:
	super(delta)
	if not active:
		return
	fall_accumulator += delta * 1000.0 * CompanionAbilityService.time_scale()
	var elapsed := level_run.elapsed_ms() / 1000
	var interval := Rules.mathtris_drop_ms(level, drops_placed, elapsed) * (2 if level_run.elapsed_ms() < slow_until_ms else 1)
	if fall_accumulator >= interval:
		fall_accumulator = 0.0
		_step_falling()


func _input(event: InputEvent) -> void:
	if not active:
		return
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			swipe_cell = _cell_at(touch.position)
			swipe_start = touch.position
			swipe_consumed = false
		else:
			swipe_cell = Vector2i(-1, -1)
	elif event is InputEventScreenDrag and swipe_cell.x >= 0 and not swipe_consumed:
		var drag := event as InputEventScreenDrag
		var delta := drag.position - swipe_start
		if delta.length() >= 30.0:
			var direction := Vector2i(signi(roundi(delta.x)), 0) if absf(delta.x) > absf(delta.y) else Vector2i(0, signi(roundi(delta.y)))
			_try_swap(swipe_cell, swipe_cell + direction)
			swipe_consumed = true
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.button_index == MOUSE_BUTTON_LEFT:
			if mouse.pressed:
				swipe_cell = _cell_at(mouse.position)
				swipe_start = mouse.position
				swipe_consumed = false
			else:
				swipe_cell = Vector2i(-1, -1)
	elif event is InputEventMouseMotion and swipe_cell.x >= 0 and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and not swipe_consumed:
		var motion := event as InputEventMouseMotion
		var delta := motion.position - swipe_start
		if delta.length() >= 30.0:
			var direction := Vector2i(signi(roundi(delta.x)), 0) if absf(delta.x) > absf(delta.y) else Vector2i(0, signi(roundi(delta.y)))
			_try_swap(swipe_cell, swipe_cell + direction)
			swipe_consumed = true


func _unhandled_key_input(event: InputEvent) -> void:
	if not active or not event is InputEventKey or not (event as InputEventKey).pressed:
		return
	match (event as InputEventKey).keycode:
		KEY_LEFT: _nudge(Vector2i.LEFT)
		KEY_RIGHT: _nudge(Vector2i.RIGHT)
		KEY_DOWN: _nudge(Vector2i.DOWN)


func _start_game() -> void:
	_start_game_with_lifecycle(true)


func _start_game_with_lifecycle(begin_run: bool) -> void:
	if begin_run:
		level_run.begin("mathtris", 1)
	score = 0
	level = 1
	drops_placed = 0
	fall_accumulator = 0.0
	started_ms = level_run.started_ms
	last_spawn_col = -1
	selected = Vector2i(-1, -1)
	equation_charge = 0
	slow_until_ms = 0
	board = _make_board()
	_seed_bottom_pile()
	falling.clear()
	active = level_run.active
	action_button.hide()
	message_label.text = "Make true five-tile equations. Swipe neighboring settled tiles to swap."
	_spawn_wave()
	_refresh()


func _make_board() -> Array[Array]:
	var result: Array[Array] = []
	for row in ROWS:
		var line: Array[String] = []
		line.resize(COLS)
		line.fill("")
		result.append(line)
	return result


func _seed_bottom_pile() -> void:
	var fill_rows := mini(ROWS - 3, 5 + mini(2, level / 12))
	for attempt in 60:
		board = _make_board()
		var allowed := Rules.mathtris_allowed(level)
		for row in range(ROWS - fill_rows, ROWS):
			for col in COLS:
				board[row][col] = allowed[rng.randi_range(0, allowed.size() - 1)]
		if not _test_force_seed_failure and _find_matches().is_empty():
			return
	_seed_match_free_fallback(fill_rows)


func _seed_match_free_fallback(fill_rows: int) -> void:
	board = _make_board()
	var safe_token := "1"
	for token in Rules.mathtris_allowed(level):
		if str(token).is_valid_int():
			safe_token = str(token)
			break
	# A pile containing one numeric token cannot form a five-tile equation.
	for row in range(ROWS - fill_rows, ROWS):
		for col in COLS:
			board[row][col] = safe_token


func _spawn_wave() -> void:
	if not active:
		return
	var elapsed := level_run.elapsed_ms() / 1000
	var wanted := Rules.mathtris_concurrent(elapsed, level)
	var open: Array[int] = []
	for col in COLS:
		if board[0][col] == "" and not _falling_at(0, col):
			open.append(col)
	if open.is_empty():
		_game_over()
		return
	for count in mini(wanted, open.size()):
		var choices := open.filter(func(col: int) -> bool: return col != last_spawn_col)
		if choices.is_empty():
			choices = open
		var col: int = choices[rng.randi_range(0, choices.size() - 1)]
		open.erase(col)
		last_spawn_col = col
		falling.append({"row": 0, "col": col, "value": _next_token()})
	_refresh()


func _next_token() -> String:
	var bag: Array[String] = []
	for token in Rules.mathtris_allowed(level):
		var copies := 2 if token in ["+", "=", "-"] else (3 if int(token) <= 5 else 1)
		for copy in copies:
			bag.append(token)
	return bag[rng.randi_range(0, bag.size() - 1)]


func _step_falling() -> void:
	if falling.is_empty():
		_spawn_wave()
		return
	var settled_cells: Array[Vector2i] = []
	falling.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["row"]) > int(b["row"]))
	for piece in falling.duplicate():
		var row := int(piece["row"])
		var col := int(piece["col"])
		if row + 1 >= ROWS or board[row + 1][col] != "" or _falling_at(row + 1, col, piece):
			# The value and its decorated tile settle together; no separate spawn box remains.
			board[row][col] = str(piece["value"])
			settled_cells.append(Vector2i(col, row))
			falling.erase(piece)
			drops_placed += 1
		else:
			piece["row"] = row + 1
	if not settled_cells.is_empty():
		var matches := _find_matches(settled_cells)
		if not matches.is_empty():
			_clear_matches(matches, 100, true)
	if active and falling.is_empty():
		_spawn_wave()
	_refresh()


func _nudge(direction: Vector2i) -> void:
	if not active or falling.is_empty():
		return
	var piece: Dictionary = falling.back()
	var target := Vector2i(int(piece["col"]), int(piece["row"])) + direction
	if target.x < 0 or target.x >= COLS or target.y < 0 or target.y >= ROWS:
		return
	if board[target.y][target.x] != "" or _falling_at(target.y, target.x, piece):
		return
	if direction.y > 0:
		piece["row"] = target.y
	else:
		piece["col"] = target.x
	_refresh()


func _cell_pressed(row: int, col: int) -> void:
	if not active or board[row][col] == "":
		return
	var here := Vector2i(col, row)
	if selected.x < 0:
		selected = here
		message_label.text = "Tap a neighbor, or slide this tile one space."
		_refresh()
		return
	if selected == here:
		selected = Vector2i(-1, -1)
		_refresh()
		return
	if not _try_swap(selected, here):
		selected = here
		_refresh()


func _try_swap(first: Vector2i, second: Vector2i) -> bool:
	if first.x < 0 or second.x < 0 or first.x >= COLS or second.x >= COLS or first.y < 0 or second.y < 0 or first.y >= ROWS or second.y >= ROWS:
		return false
	if abs(first.x - second.x) + abs(first.y - second.y) != 1:
		return false
	if board[first.y][first.x] == "" or board[second.y][second.x] == "":
		return false
	var value: String = board[first.y][first.x]
	board[first.y][first.x] = board[second.y][second.x]
	board[second.y][second.x] = value
	selected = Vector2i(-1, -1)
	_play_slide_swap(first, second, value, board[first.y][first.x])
	var matches := _find_matches([first, second])
	if matches.is_empty():
		message_label.text = "Tiles slid. No true equation yet."
	else:
		_clear_matches(matches, 150, true)
	_refresh()
	return true


func _find_matches(anchors: Array[Vector2i] = []) -> Array[Dictionary]:
	var matches: Array[Dictionary] = []
	for row in ROWS:
		for start_col in range(COLS - 4):
			var cells_for_match: Array[Vector2i] = []
			var tokens: Array[String] = []
			for offset in 5:
				cells_for_match.append(Vector2i(start_col + offset, row))
				tokens.append(board[row][start_col + offset])
			if not tokens.has("") and Rules.equation_valid(tokens) and _touches_anchor(cells_for_match, anchors):
				matches.append({"cells": cells_for_match, "tokens": tokens, "orientation": "horizontal", "start": Vector2i(start_col, row)})
	for col in COLS:
		for start_row in range(ROWS - 4):
			var cells_for_match: Array[Vector2i] = []
			var tokens: Array[String] = []
			for offset in 5:
				cells_for_match.append(Vector2i(col, start_row + offset))
				tokens.append(board[start_row + offset][col])
			if not tokens.has("") and Rules.equation_valid(tokens) and _touches_anchor(cells_for_match, anchors):
				matches.append({"cells": cells_for_match, "tokens": tokens, "orientation": "vertical", "start": Vector2i(col, start_row)})
	return matches


func _touches_anchor(match_cells: Array[Vector2i], anchors: Array[Vector2i]) -> bool:
	if anchors.is_empty():
		return true
	for anchor in anchors:
		if anchor in match_cells:
			return true
	return false


func _find_equations() -> Array[Vector2i]:
	return _hits_from_matches(_find_matches())


func _hits_from_matches(matches: Array[Dictionary]) -> Array[Vector2i]:
	var unique := {}
	for equation in matches:
		for cell in equation["cells"]:
			unique[cell] = true
	var hits: Array[Vector2i] = []
	hits.assign(unique.keys())
	return hits


func _clear_matches(matches: Array[Dictionary], points_per_cell: int, allow_cascade: bool) -> void:
	if matches.is_empty():
		return
	var hits := _hits_from_matches(matches)
	equation_charge = mini(3, equation_charge + matches.size())
	var shown_tokens: Array[String] = []
	shown_tokens.assign(matches[0]["tokens"])
	message_label.text = "%s — TRUE!" % " ".join(shown_tokens)
	for hit in hits:
		board[hit.y][hit.x] = ""
	score += hits.size() * points_per_cell
	var cascade_anchors := _apply_gravity()
	if allow_cascade:
		var cascade := _find_matches(cascade_anchors)
		var guard := 0
		while not cascade.is_empty() and guard < 8:
			guard += 1
			var cascade_hits := _hits_from_matches(cascade)
			for hit in cascade_hits:
				board[hit.y][hit.x] = ""
			score += cascade_hits.size() * 175
			cascade_anchors = _apply_gravity()
			cascade = _find_matches(cascade_anchors)
	level = score / 700 + 1


func _apply_gravity() -> Array[Vector2i]:
	var settled: Array[Vector2i] = []
	for col in COLS:
		var stack: Array[String] = []
		for row in ROWS:
			if board[row][col] != "":
				stack.append(board[row][col])
		for row in ROWS:
			board[row][col] = ""
		for index in stack.size():
			var target_row := ROWS - stack.size() + index
			board[target_row][col] = stack[index]
			settled.append(Vector2i(col, target_row))
	return settled


func _activate_mystic_ability() -> void:
	if not active:
		return
	var kit: Array[String] = ["1", "+", "1", "=", "2"]
	var best_row := 0
	var most_empty := -1
	for row in ROWS:
		var empty := 0
		for col in 5:
			empty += 1 if board[row][col] == "" else 0
		if empty > most_empty:
			most_empty = empty
			best_row = row
	for col in 5:
		board[best_row][col] = kit[col]
	var matches := _find_matches([Vector2i(0, best_row)])
	_clear_matches(matches, 120, true)
	message_label.text = "Mystic completed 1 + 1 = 2 — a real equation!"
	_refresh()


func apply_companion_power(companion_id: String) -> bool:
	if not active or not can_use_companion_power():
		return false
	match companion_id:
		"sparkle":
			var matches := _find_matches()
			if matches.is_empty():
				var repair := _find_best_equation_fix(2)
				if repair.is_empty():
					repair = _most_filled_segment()
				if repair.is_empty():
					return false
				_apply_equation_kit(repair["cells"], repair["kit"])
				matches = _find_matches(repair["cells"])
			if matches.is_empty():
				return false
			_clear_power_hits(_hits_from_matches([matches[0]]), 80)
			message_label.text = "Sparkle cleared a true equation!"
		"rainbow":
			var swept := 0
			for col in COLS:
				if board[ROWS - 1][col] != "":
					board[ROWS - 1][col] = ""
					swept += 1
			if swept == 0:
				return false
			score += swept * 35
			_apply_gravity()
			message_label.text = "Rainbow swept the bottom row!"
		"star":
			var fullest := 0
			var count := -1
			for col in COLS:
				var occupied := 0
				for row in ROWS: occupied += 1 if board[row][col] != "" else 0
				if occupied > count: count = occupied; fullest = col
			if count <= 0:
				return false
			for row in ROWS: board[row][fullest] = ""
			score += count * 45
			_apply_gravity()
			message_label.text = "Star cleared the fullest column!"
		"cloud":
			slow_until_ms = level_run.elapsed_ms() + 18000
			score += 50
			message_label.text = "Cloud slowed falling tiles for 18 seconds!"
		"dream":
			var repair := _find_best_equation_fix(1)
			if repair.is_empty():
				return false
			_apply_equation_kit(repair["cells"], repair["kit"])
			var repaired := _find_matches(repair["cells"])
			if repaired.is_empty():
				return false
			_clear_power_hits(_hits_from_matches(repaired), 120)
			message_label.text = "Dream repaired a near-equation."
		"mystic":
			var cleared := 0
			for row in ROWS:
				for col in COLS:
					if board[row][col] != "":
						board[row][col] = ""
						cleared += 1
			if cleared == 0:
				return false
			score += 400 + cleared * 25
			_apply_gravity()
			message_label.text = "Mystic cleared the whole board!"
		_: return false
	equation_charge = 0
	_refresh()
	return true


func request_companion_action(companion_id: String) -> bool:
	return apply_companion_power(companion_id)


func _equation_kits() -> Array[Array]:
	var allowed: Array[String] = []
	for token in Rules.mathtris_allowed(level):
		if token.is_valid_int():
			allowed.append(token)
	var kits: Array[Array] = []
	for left in allowed:
		for operator in ["+", "-"]:
			if not operator in Rules.mathtris_allowed(level):
				continue
			for right in allowed:
				for result in allowed:
					var kit: Array[String] = [left, operator, right, "=", result]
					if Rules.equation_valid(kit):
						kits.append(kit)
	return kits


func _segments() -> Array[Array]:
	var result: Array[Array] = []
	for row in ROWS:
		for start_col in range(COLS - 4):
			var horizontal: Array[Vector2i] = []
			for offset in 5:
				horizontal.append(Vector2i(start_col + offset, row))
			result.append(horizontal)
	for col in COLS:
		for start_row in range(ROWS - 4):
			var vertical: Array[Vector2i] = []
			for offset in 5:
				vertical.append(Vector2i(col, start_row + offset))
			result.append(vertical)
	return result


func _find_best_equation_fix(max_wrong: int) -> Dictionary:
	var best: Dictionary = {}
	var best_score := -1
	for segment in _segments():
		for kit in _equation_kits():
			var wrong := 0
			var empty := 0
			var matches := 0
			for index in 5:
				var cell: Vector2i = segment[index]
				var value: String = board[cell.y][cell.x]
				if value == "":
					empty += 1
				elif value == kit[index]:
					matches += 1
				else:
					wrong += 1
			if wrong <= max_wrong and empty <= 2 and matches >= 2:
				var candidate_score := matches * 10 - wrong * 3 - empty
				if candidate_score > best_score:
					best_score = candidate_score
					best = {"cells": segment, "kit": kit}
	return best


func _most_filled_segment() -> Dictionary:
	var best: Dictionary = {}
	var most_filled := -1
	var kits := _equation_kits()
	if kits.is_empty():
		return best
	for segment in _segments():
		var filled := 0
		for cell in segment:
			if board[cell.y][cell.x] != "":
				filled += 1
		if filled > most_filled:
			most_filled = filled
			best = {"cells": segment, "kit": kits[0]}
	return best


func _apply_equation_kit(segment: Array, kit: Array) -> void:
	for index in 5:
		var cell: Vector2i = segment[index]
		board[cell.y][cell.x] = str(kit[index])


func _clear_power_hits(hits: Array[Vector2i], points_per_hit: int) -> bool:
	if hits.is_empty():
		return false
	for hit in hits:
		board[hit.y][hit.x] = ""
	score += hits.size() * points_per_hit
	_apply_gravity()
	return true


func can_use_companion_power() -> bool:
	return active and equation_charge >= 3


func can_show_hint() -> bool:
	return active


func _show_hint() -> void:
	if not active:
		return
	var example := "1 + 1 = 2"
	if "3" in Rules.mathtris_allowed(level):
		example = "1 + 2 = 3"
	if "-" in Rules.mathtris_allowed(level):
		example = "4 - 1 = 3"
	message_label.text = "Build %s across or down. Swipe only one space." % example


func _play_slide_swap(first: Vector2i, second: Vector2i, text_at_first: String, text_at_second: String) -> void:
	if AppState.setting("reduced_motion", false):
		return
	var button_a := cells[first.y * COLS + first.x]
	var button_b := cells[second.y * COLS + second.x]
	var delta := button_b.global_position - button_a.global_position
	var overlay_a := _swap_overlay(text_at_first, button_a.global_position, button_a.size)
	var overlay_b := _swap_overlay(text_at_second, button_b.global_position, button_b.size)
	add_child(overlay_a)
	add_child(overlay_b)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(overlay_a, "global_position", overlay_a.global_position + delta, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(overlay_b, "global_position", overlay_b.global_position - delta, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.finished.connect(func() -> void:
		overlay_a.queue_free()
		overlay_b.queue_free()
	)


func _swap_overlay(label_text: String, global_pos: Vector2, tile_size: Vector2) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.global_position = global_pos
	panel.size = tile_size
	panel.add_theme_stylebox_override("panel", _tile_style(label_text, false, false))
	var label := Label.new()
	label.text = label_text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.add_theme_font_size_override("font_size", 19)
	label.add_theme_color_override("font_color", Color("172143"))
	panel.add_child(label)
	return panel


func _falling_at(row: int, col: int, except: Dictionary = {}) -> bool:
	for piece in falling:
		if piece == except:
			continue
		if int(piece["row"]) == row and int(piece["col"]) == col:
			return true
	return false


func _cell_at(global_point: Vector2) -> Vector2i:
	for row in ROWS:
		for col in COLS:
			if cells[row * COLS + col].get_global_rect().has_point(global_point):
				return Vector2i(col, row)
	return Vector2i(-1, -1)


func _game_over() -> void:
	if not active:
		return
	var previous_best := int(AppState.progress_for_game("mathtris").get("best_score", 0))
	var reward := level_run.finish_endless(score, level)
	active = level_run.active
	falling.clear()
	message_label.text = "%s\nSCORE %d  •  BEST %d  •  STAGE %d\n+%d coins" % ["NEW PERSONAL BEST!" if score > previous_best else "Nice run!", score, maxi(previous_best, score), level, reward]
	action_button.text = "PLAY AGAIN"
	action_button.show()
	_refresh()


func can_retry_failure() -> bool:
	return level_run.can_retry()


func retry_failure() -> void:
	if can_retry_failure():
		level_run.retry()
		_start_game_with_lifecycle(false)


func _advance_game() -> void:
	if not level_run.active:
		level_run.retry()
		_start_game_with_lifecycle(false)


func _refresh() -> void:
	var falling_lookup := {}
	for piece in falling:
		falling_lookup[Vector2i(int(piece["col"]), int(piece["row"]))] = str(piece["value"])
	for row in ROWS:
		for col in COLS:
			var button := cells[row * COLS + col]
			var cell := Vector2i(col, row)
			var value: String = falling_lookup.get(cell, board[row][col])
			button.text = value
			button.disabled = value == "" or falling_lookup.has(cell)
			button.add_theme_stylebox_override("normal", _tile_style(value, falling_lookup.has(cell), selected == cell, row))
			button.add_theme_stylebox_override("disabled", _tile_style(value, falling_lookup.has(cell), false, row))
			button.add_theme_color_override("font_color", Color("172143"))
			button.add_theme_color_override("font_disabled_color", Color("172143") if value != "" else Color.TRANSPARENT)
	hud_label.text = "SCORE %d    •    LEVEL %d" % [score, level]
	next_label.text = "%d FALLING    •    %dms DROP" % [falling.size(), Rules.mathtris_drop_ms(level, drops_placed, level_run.elapsed_ms() / 1000)]


func _tile_style(value: String, is_falling: bool, is_selected: bool, row: int = -1) -> StyleBoxFlat:
	var filled := value != ""
	var empty_spawn := not filled and not is_falling and row == 0
	var cache_key := int(filled) | (int(is_falling) << 1) | (int(is_selected) << 2) | (int(empty_spawn) << 3)
	if _tile_style_cache.has(cache_key):
		return _tile_style_cache[cache_key] as StyleBoxFlat
	var style := StyleBoxFlat.new()
	style.bg_color = Color("fff1a8") if is_falling else (Color("ffd2ed") if filled else Color(0.34, 0.45, 0.72, 0.08 if empty_spawn else 0.14))
	style.border_color = Color("62dce9") if is_selected else (Color("f4c75b") if filled else Color(0.60, 0.70, 0.92, 0.0 if empty_spawn else 0.22))
	style.set_border_width_all(3 if is_selected else (0 if empty_spawn else 2))
	style.set_corner_radius_all(9)
	style.shadow_color = Color(0.08, 0.03, 0.20, 0.45)
	style.shadow_size = 3 if filled else 0
	_tile_style_cache[cache_key] = style
	return style


func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color("16143f")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 14)
	root.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_theme_constant_override("separation", 6)
	add_child(root)
	hud_label = Label.new()
	hud_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	StorybookUI.apply_story_label(hud_label, Color("66e5ff"), 25, true)
	root.add_child(hud_label)
	next_label = Label.new()
	next_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	StorybookUI.apply_story_label(next_label, StorybookUI.CREAM, 17, true)
	root.add_child(next_label)
	var grid_frame := PanelContainer.new()
	grid_frame.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	grid_frame.add_theme_stylebox_override("panel", StorybookUI.plaque_style(Color("221b58"), StorybookUI.GOLD, 16))
	root.add_child(grid_frame)
	var grid := GridContainer.new()
	grid.columns = COLS
	grid.add_theme_constant_override("h_separation", 3)
	grid.add_theme_constant_override("v_separation", 3)
	grid_frame.add_child(grid)
	for row in ROWS:
		for col in COLS:
			var cell := Button.new()
			cell.custom_minimum_size = Vector2(44, 29)
			cell.add_theme_font_size_override("font_size", 19)
			cell.pressed.connect(_cell_pressed.bind(row, col))
			cell.set_meta("mathtris_tile", true)
			grid.add_child(cell)
			cells.append(cell)
	var controls := HBoxContainer.new()
	controls.alignment = BoxContainer.ALIGNMENT_CENTER
	controls.add_theme_constant_override("separation", 8)
	root.add_child(controls)
	for definition in [{"label": "←", "direction": Vector2i.LEFT}, {"label": "↓", "direction": Vector2i.DOWN}, {"label": "→", "direction": Vector2i.RIGHT}]:
		var button := Button.new()
		button.text = definition["label"]
		StorybookUI.apply_game_action(button, 76)
		button.pressed.connect(_nudge.bind(definition["direction"]))
		controls.add_child(button)
	var hint := StorybookUI.hint_highlight_button("HINT", 110, _show_hint)
	controls.add_child(hint)
	message_label = Label.new()
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message_label.custom_minimum_size.y = 52
	message_label.add_theme_font_size_override("font_size", 18)
	message_label.add_theme_color_override("font_color", StorybookUI.CREAM)
	root.add_child(message_label)
	action_button = StorybookUI.progression_action_button("PLAY AGAIN", 180, _advance_game)
	root.add_child(action_button)
