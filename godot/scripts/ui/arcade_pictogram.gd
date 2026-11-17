class_name ArcadePictogram
extends Control

const StorybookUI = preload("res://scripts/ui/storybook_ui.gd")
const PINK := Color("f26fa7")

var icon_id := "number"
var accent := StorybookUI.CYAN
var style_rebuild_count := 0
var _tile_style: StyleBoxFlat
var _style_side := -1.0
var _style_accent := Color.TRANSPARENT


func setup(value: String, color: Color) -> void:
	icon_id = value
	accent = color
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(76, 76)
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


func _draw() -> void:
	var side := minf(size.x, size.y)
	var tile := Rect2((size.x - side) * 0.5 + 2, (size.y - side) * 0.5 + 2, side - 4, side - 4)
	draw_style_box(_style_for(side), tile)
	var scale_factor := side / 96.0
	draw_set_transform(size * 0.5, 0.0, Vector2(scale_factor, scale_factor))
	_draw_symbol()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _style_for(side: float) -> StyleBoxFlat:
	if _tile_style == null or not is_equal_approx(_style_side, side) or _style_accent != accent:
		if _tile_style == null:
			_tile_style = StyleBoxFlat.new()
		_tile_style.bg_color = Color(StorybookUI.NAVY, 0.94)
		_tile_style.border_color = Color(accent, 0.95)
		_tile_style.set_border_width_all(3)
		_tile_style.set_corner_radius_all(int(side * 0.24))
		_tile_style.shadow_color = Color(0.02, 0.03, 0.12, 0.48)
		_tile_style.shadow_size = 4
		_tile_style.shadow_offset = Vector2(0, 3)
		_style_side = side
		_style_accent = accent
		style_rebuild_count += 1
	return _tile_style


func _draw_symbol() -> void:
	match icon_id:
		"number": _calculator()
		"word": _book_letter()
		"mystery": _magnifier()
		"arcade": _rocket()
		"unicorn_jump": _jump_arc()
		"sliding_window": _sliders()
		"coin_count": _coins()
		"cash_counter": _cash()
		"math_swipe": _swipe_cards()
		"mathtris": _math_blocks()
		"unicorn_blast": _target_bolt()
		"rhyme_rally": _music()
		"sentence_sprout": _sprout()
		"missing_magic": _magic_wand()
		"sight_spark": _eye_spark()
		"prefix_potion": _potion()
		"vowel_vines": _vine_letter()
		"letter_lift": _ladder()
		"syllable_stamp": _stamp()
		"caption_quest": _caption()
		"opposite_orbit": _opposite()
		"scramble_spell": _scramble()
		"odd_one_out": _odd_one()
		"size_line_up": _size_bars()
		"chain_link": _links()
		"galaxy_unicorn": _galaxy_ship()
		"comet_math_rescue": _comet_math()
		"pattern_parade": _pattern()
		"memory_meadow": _memory_cards()
		"bubble_count": _bubbles()
		_: _spark(Vector2.ZERO, 18, accent)


func _calculator() -> void:
	draw_rect(Rect2(-23, -31, 46, 62), accent, true)
	draw_rect(Rect2(-16, -23, 32, 15), Color(StorybookUI.NAVY), true)
	for y in [-1, 11, 23]:
		for x in [-12, 0, 12]: draw_circle(Vector2(x, y), 3.2, Color(StorybookUI.NAVY))


func _book_letter() -> void:
	draw_rect(Rect2(-29, -25, 26, 50), accent, true)
	draw_rect(Rect2(3, -25, 26, 50), accent.lightened(0.12), true)
	draw_line(Vector2(0, -24), Vector2(0, 26), StorybookUI.GOLD_BRIGHT, 3, true)
	_glyph("T", Vector2(-22, 15), 32, StorybookUI.CREAM, 44)


func _magnifier() -> void:
	draw_arc(Vector2(-7, -7), 20, 0, TAU, 32, accent, 7, true)
	draw_line(Vector2(8, 8), Vector2(28, 28), accent, 9, true)
	draw_circle(Vector2(-13, -13), 4, StorybookUI.CREAM)


func _rocket() -> void:
	draw_colored_polygon(PackedVector2Array([Vector2(-10, 18), Vector2(0, -31), Vector2(10, 18)]), accent)
	draw_circle(Vector2(0, -8), 6, StorybookUI.CYAN)
	draw_colored_polygon(PackedVector2Array([Vector2(-10, 8), Vector2(-25, 25), Vector2(-8, 20)]), PINK)
	draw_colored_polygon(PackedVector2Array([Vector2(10, 8), Vector2(25, 25), Vector2(8, 20)]), PINK)
	draw_colored_polygon(PackedVector2Array([Vector2(-6, 20), Vector2(0, 34), Vector2(6, 20)]), StorybookUI.GOLD_BRIGHT)


func _jump_arc() -> void:
	for x in [-27, -9, 9, 27]: draw_circle(Vector2(x, 23 - absf(x) * 0.42), 6, accent)
	draw_arc(Vector2(0, 10), 30, PI, TAU, 24, StorybookUI.GOLD_BRIGHT, 4, true)
	_spark(Vector2(0, -22), 10, PINK)


func _sliders() -> void:
	for y in [-20, 0, 20]: draw_line(Vector2(-28, y), Vector2(28, y), Color(accent, 0.65), 5, true)
	for data in [[-10, -20], [12, 0], [-2, 20]]: draw_circle(Vector2(data[0], data[1]), 8, StorybookUI.GOLD_BRIGHT)


func _coins() -> void:
	for data in [[-16, 12, 17], [10, 2, 20], [-4, -17, 18]]:
		draw_circle(Vector2(data[0] + 2, data[1] + 3), data[2], Color(0.02, 0.03, 0.1, 0.5))
		draw_circle(Vector2(data[0], data[1]), data[2], StorybookUI.GOLD_BRIGHT)
		draw_arc(Vector2(data[0], data[1]), data[2] - 4, 0, TAU, 24, Color("c58b2e"), 2, true)
	_glyph("¢", Vector2(-24, 13), 24, StorybookUI.NAVY, 48)


func _cash() -> void:
	for offset in [Vector2(-5, 6), Vector2(0, 0)]:
		draw_rect(Rect2(-29 + offset.x, -18 + offset.y, 58, 36), accent, true)
		draw_rect(Rect2(-24 + offset.x, -13 + offset.y, 48, 26), Color(StorybookUI.NAVY), false, 3)
	draw_circle(Vector2.ZERO, 9, StorybookUI.GOLD_BRIGHT)
	_glyph("$", Vector2(-11, 8), 18, StorybookUI.NAVY, 22)


func _swipe_cards() -> void:
	draw_rect(Rect2(-29, -24, 27, 48), accent, true)
	draw_rect(Rect2(2, -24, 27, 48), PINK, true)
	draw_line(Vector2(-12, 33), Vector2(12, 33), StorybookUI.GOLD_BRIGHT, 5, true)
	draw_colored_polygon(PackedVector2Array([Vector2(12, 26), Vector2(25, 33), Vector2(12, 40)]), StorybookUI.GOLD_BRIGHT)


func _math_blocks() -> void:
	for data in [[-25, -23, "2"], [3, -23, "+"], [-25, 5, "3"], [3, 5, "="]]:
		draw_rect(Rect2(data[0], data[1], 23, 23), accent if data[2] in ["2", "3"] else PINK, true)
		_glyph(data[2], Vector2(data[0], data[1] + 18), 23, StorybookUI.NAVY, 17)


func _target_bolt() -> void:
	for radius in [28, 19, 10]: draw_arc(Vector2(-7, -2), radius, 0, TAU, 32, [StorybookUI.CREAM, PINK, StorybookUI.CREAM][int((28 - radius) / 9)], 6, true)
	draw_circle(Vector2(-7, -2), 5, accent)
	draw_colored_polygon(PackedVector2Array([Vector2(7, -31), Vector2(29, -12), Vector2(17, -9), Vector2(31, 12), Vector2(2, -2), Vector2(13, -7)]), StorybookUI.GOLD_BRIGHT)


func _music() -> void:
	draw_line(Vector2(-8, -25), Vector2(-8, 18), accent, 7, true)
	draw_line(Vector2(-8, -23), Vector2(25, -30), accent, 7, true)
	draw_line(Vector2(25, -28), Vector2(25, 10), accent, 7, true)
	draw_circle(Vector2(-19, 22), 12, StorybookUI.GOLD_BRIGHT)
	draw_circle(Vector2(14, 14), 12, StorybookUI.GOLD_BRIGHT)


func _sprout() -> void:
	draw_line(Vector2(0, 30), Vector2(0, -12), Color("5fd18a"), 7, true)
	var left := PackedVector2Array([Vector2(-2, -3), Vector2(-31, -24), Vector2(-29, 5), Vector2(-4, 12)])
	var right := PackedVector2Array([Vector2(2, -11), Vector2(31, -31), Vector2(29, -3), Vector2(4, 5)])
	draw_colored_polygon(left, Color("75d85d"))
	draw_colored_polygon(right, Color("a4df62"))


func _magic_wand() -> void:
	draw_line(Vector2(-27, 27), Vector2(13, -13), accent, 10, true)
	_spark(Vector2(23, -23), 15, StorybookUI.GOLD_BRIGHT)
	_spark(Vector2(-18, -22), 7, PINK)
	_spark(Vector2(27, 13), 6, StorybookUI.CYAN)


func _eye_spark() -> void:
	draw_arc(Vector2.ZERO, 30, PI + 0.2, TAU - 0.2, 24, StorybookUI.CREAM, 5, true)
	draw_arc(Vector2.ZERO, 30, 0.2, PI - 0.2, 24, StorybookUI.CREAM, 5, true)
	draw_circle(Vector2.ZERO, 12, accent)
	draw_circle(Vector2.ZERO, 5, StorybookUI.NAVY)
	_spark(Vector2(26, -24), 9, StorybookUI.GOLD_BRIGHT)


func _potion() -> void:
	draw_rect(Rect2(-10, -31, 20, 15), StorybookUI.CREAM, true)
	draw_colored_polygon(PackedVector2Array([Vector2(-10, -16), Vector2(-29, 24), Vector2(-20, 32), Vector2(20, 32), Vector2(29, 24), Vector2(10, -16)]), accent)
	draw_line(Vector2(-22, 12), Vector2(22, 12), StorybookUI.CREAM, 4, true)
	for p in [Vector2(-12, 20), Vector2(5, 24), Vector2(15, 17)]: draw_circle(p, 4, StorybookUI.GOLD_BRIGHT)


func _vine_letter() -> void:
	_glyph("A", Vector2(-25, 22), 50, StorybookUI.CREAM, 48)
	draw_arc(Vector2(7, 0), 26, -PI * 0.7, PI * 0.55, 24, Color("64cf77"), 5, true)
	for p in [Vector2(18, -22), Vector2(28, 4)]: draw_circle(p, 8, Color("8ddb60"))


func _ladder() -> void:
	draw_line(Vector2(-18, -31), Vector2(-18, 32), accent, 7, true)
	draw_line(Vector2(18, -31), Vector2(18, 32), accent, 7, true)
	for y in [-22, -8, 6, 20]: draw_line(Vector2(-18, y), Vector2(18, y), StorybookUI.GOLD_BRIGHT, 5, true)


func _stamp() -> void:
	draw_rect(Rect2(-23, 8, 46, 20), accent, true)
	draw_rect(Rect2(-31, 27, 62, 8), StorybookUI.GOLD_BRIGHT, true)
	draw_line(Vector2(-14, 8), Vector2(-7, -18), StorybookUI.CREAM, 9, true)
	draw_line(Vector2(14, 8), Vector2(7, -18), StorybookUI.CREAM, 9, true)
	draw_rect(Rect2(-12, -29, 24, 14), PINK, true)


func _caption() -> void:
	draw_rect(Rect2(-31, -26, 62, 43), accent, true)
	draw_colored_polygon(PackedVector2Array([Vector2(-16, 17), Vector2(-8, 32), Vector2(2, 17)]), accent)
	draw_circle(Vector2(-13, -5), 7, StorybookUI.GOLD_BRIGHT)
	draw_colored_polygon(PackedVector2Array([Vector2(-28, 13), Vector2(-5, -5), Vector2(10, 8), Vector2(29, -13), Vector2(29, 15)]), Color("5b8fc9"))


func _opposite() -> void:
	draw_arc(Vector2.ZERO, 28, 0.25, PI - 0.25, 24, accent, 6, true)
	draw_arc(Vector2.ZERO, 28, PI + 0.25, TAU - 0.25, 24, PINK, 6, true)
	draw_colored_polygon(PackedVector2Array([Vector2(-27, -4), Vector2(-37, -15), Vector2(-20, -17)]), accent)
	draw_colored_polygon(PackedVector2Array([Vector2(27, 4), Vector2(37, 15), Vector2(20, 17)]), PINK)


func _scramble() -> void:
	for data in [[-30, -25, "C"], [4, -25, "A"], [-13, 6, "T"]]:
		draw_rect(Rect2(data[0], data[1], 27, 27), accent if data[2] != "A" else PINK, true)
		_glyph(data[2], Vector2(data[0], data[1] + 21), 27, StorybookUI.NAVY, 20)
	draw_line(Vector2(-25, 34), Vector2(25, 34), StorybookUI.GOLD_BRIGHT, 4, true)


func _odd_one() -> void:
	for x in [-18, 18]:
		for y in [-18, 18]: draw_circle(Vector2(x, y), 10, PINK if x > 0 and y > 0 else accent)
	_spark(Vector2(31, 27), 7, StorybookUI.GOLD_BRIGHT)


func _size_bars() -> void:
	for data in [[-31, 13], [-11, 25], [9, 39]]: draw_rect(Rect2(data[0], 31 - data[1], 14, data[1]), Color.from_hsv(fmod(accent.h + data[0] * 0.003, 1.0), 0.55, 0.95), true)
	draw_line(Vector2(-35, 32), Vector2(35, 32), StorybookUI.GOLD_BRIGHT, 4, true)


func _links() -> void:
	draw_arc(Vector2(-13, 0), 20, -2.3, 2.3, 24, accent, 8, true)
	draw_arc(Vector2(13, 0), 20, PI - 2.3, PI + 2.3, 24, PINK, 8, true)
	draw_line(Vector2(-7, 0), Vector2(7, 0), StorybookUI.GOLD_BRIGHT, 6, true)


func _galaxy_ship() -> void:
	for p in [Vector2(-26, -22), Vector2(25, -25), Vector2(31, 10)]: _spark(p, 6, StorybookUI.GOLD_BRIGHT)
	draw_colored_polygon(PackedVector2Array([Vector2(0, -29), Vector2(-18, 17), Vector2(0, 10), Vector2(18, 17)]), accent)
	draw_circle(Vector2(0, -8), 7, Color("d9f5ff"))
	for offset in [-7, 0, 7]: draw_line(Vector2(offset, 16), Vector2(offset - 6, 34), [PINK, StorybookUI.GOLD_BRIGHT, StorybookUI.CYAN][int((offset + 7) / 7)], 4, true)


func _comet_math() -> void:
	draw_circle(Vector2(8, -7), 20, Color("72dff2"))
	draw_line(Vector2(-31, 28), Vector2(-4, 4), Color("d98af5"), 9, true)
	draw_line(Vector2(-33, 28), Vector2(-5, 2), StorybookUI.GOLD_BRIGHT, 3, true)
	_glyph("=", Vector2(7, 5), 18, Color("172143"), 24)


func _spark(center: Vector2, radius: float, color: Color) -> void:
	draw_colored_polygon(PackedVector2Array([
		center + Vector2(0, -radius), center + Vector2(radius * 0.28, -radius * 0.28),
		center + Vector2(radius, 0), center + Vector2(radius * 0.28, radius * 0.28),
		center + Vector2(0, radius), center + Vector2(-radius * 0.28, radius * 0.28),
		center + Vector2(-radius, 0), center + Vector2(-radius * 0.28, -radius * 0.28),
	]), color)


func _glyph(value: String, origin: Vector2, width: float, color: Color, font_size: int) -> void:
	draw_string(ThemeDB.fallback_font, origin, value, HORIZONTAL_ALIGNMENT_CENTER, width, font_size, color)


func _pattern() -> void:
	for index in 3:
		var center := Vector2(-26 + index * 26, -12)
		if index == 1:
			draw_rect(Rect2(center - Vector2(9, 9), Vector2(18, 18)), PINK, true)
		else:
			draw_circle(center, 10, accent)
	draw_circle(Vector2(-26, 16), 10, accent)
	draw_rect(Rect2(-9, 7, 18, 18), PINK, true)
	draw_arc(Vector2(26, 16), 10, 0, TAU, 24, StorybookUI.GOLD_BRIGHT, 4, true)


func _memory_cards() -> void:
	draw_rect(Rect2(-32, -22, 28, 40), Color(accent, 0.55), true)
	draw_rect(Rect2(-32, -22, 28, 40), StorybookUI.CREAM, false, 3)
	draw_rect(Rect2(2, -18, 30, 42), StorybookUI.CREAM, true)
	_spark(Vector2(17, 3), 11, PINK)
	_spark(Vector2(-18, -2), 7, StorybookUI.GOLD_BRIGHT)


func _bubbles() -> void:
	for bubble in [[Vector2(-15, 8), 19.0, accent], [Vector2(17, -10), 14.0, PINK], [Vector2(16, 22), 9.0, StorybookUI.GOLD_BRIGHT]]:
		draw_circle(bubble[0], bubble[1], Color(bubble[2], 0.35))
		draw_arc(bubble[0], bubble[1], 0, TAU, 28, bubble[2], 4, true)
		draw_arc(bubble[0], bubble[1] * 0.62, -2.5, -1.4, 8, StorybookUI.CREAM, 3, true)
