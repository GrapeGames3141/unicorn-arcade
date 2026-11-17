class_name ShapeTile
extends Control

## A code-drawn storybook tile: a bold shape, a number, or a face-down card
## back. Shared by Memory Meadow, Pattern Parade, and Bubble Count so new games
## need no image files.
const StorybookUI = preload("res://scripts/ui/storybook_ui.gd")
const SHAPES := ["star", "heart", "moon", "flower", "diamond", "circle", "triangle", "square"]
const SHAPE_COLORS := {
	"star": Color("ffd166"),
	"heart": Color("f26fa7"),
	"moon": Color("b79cff"),
	"flower": Color("ff9ecf"),
	"diamond": Color("58d6e8"),
	"circle": Color("62e6a7"),
	"triangle": Color("ff9f5a"),
	"square": Color("7fb2ff"),
}
const INK := Color("172143")

var shape := ""
var label := ""
var face_down := false
var tile_color := StorybookUI.CREAM
var highlighted := false


func show_shape(value: String) -> void:
	shape = value
	label = ""
	face_down = false
	queue_redraw()


func show_label(value: String) -> void:
	shape = ""
	label = value
	face_down = false
	queue_redraw()


func set_face_down(value: bool) -> void:
	face_down = value
	queue_redraw()


func set_highlighted(value: bool) -> void:
	highlighted = value
	queue_redraw()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


func _draw() -> void:
	var side := minf(size.x, size.y)
	var rect := Rect2((size - Vector2(side, side)) * 0.5, Vector2(side, side)).grow(-2.0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("3b2a7a") if face_down else tile_color
	style.border_color = StorybookUI.CYAN if highlighted else StorybookUI.GOLD
	style.set_border_width_all(5 if highlighted else 3)
	style.set_corner_radius_all(int(side * 0.18))
	draw_style_box(style, rect)
	var center := size * 0.5
	if face_down:
		# Card back: a soft sparkle so face-down cards still look magical.
		draw_shape(self, "star", center, side * 0.2, Color("8f7be0"), false)
		for offset in [Vector2(-0.27, -0.27), Vector2(0.27, 0.27), Vector2(0.27, -0.27), Vector2(-0.27, 0.27)]:
			draw_circle(center + offset * side, side * 0.035, Color("6a55c2"))
		return
	if not shape.is_empty():
		draw_shape(self, shape, center, side * 0.32, SHAPE_COLORS.get(shape, StorybookUI.CYAN))
	elif not label.is_empty():
		var font := ThemeDB.fallback_font
		var font_size := int(side * (0.5 if label.length() <= 2 else 0.36))
		var text_size := font.get_string_size(label, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
		draw_string(font, Vector2(center.x - text_size.x * 0.5, center.y + font_size * 0.36), label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, INK)


static func shape_points(shape_name: String, radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	match shape_name:
		"star":
			for index in 10:
				var angle := -PI * 0.5 + index * PI / 5.0
				points.append(Vector2(cos(angle), sin(angle)) * (radius * (1.12 if index % 2 == 0 else 0.5)))
		"heart":
			for index in 40:
				var t := TAU * index / 40.0
				points.append(Vector2(16.0 * pow(sin(t), 3), -(13.0 * cos(t) - 5.0 * cos(2 * t) - 2.0 * cos(3 * t) - cos(4 * t)) - 2.0) * (radius / 15.0))
		"moon":
			var gap := radius * 0.42
			var inner := radius * 0.82
			var cross := (gap * gap + radius * radius - inner * inner) / (2.0 * gap)
			var outer_angle := acos(clampf(cross / radius, -1.0, 1.0))
			var inner_angle := acos(clampf((cross - gap) / inner, -1.0, 1.0))
			for index in 25:
				var angle := lerpf(outer_angle, TAU - outer_angle, index / 24.0)
				points.append(Vector2(cos(angle), sin(angle)) * radius - Vector2(radius * 0.12, 0))
			for index in 19:
				var angle := lerpf(TAU - inner_angle, inner_angle, index / 18.0)
				points.append(Vector2(gap, 0) + Vector2(cos(angle), sin(angle)) * inner - Vector2(radius * 0.12, 0))
		"diamond":
			points = PackedVector2Array([Vector2(0, -radius * 1.15), Vector2(radius * 0.82, 0), Vector2(0, radius * 1.15), Vector2(-radius * 0.82, 0)])
		"triangle":
			points = PackedVector2Array([Vector2(0, -radius * 1.05), Vector2(radius * 1.05, radius * 0.85), Vector2(-radius * 1.05, radius * 0.85)])
		"square":
			var half := radius * 0.9
			points = PackedVector2Array([Vector2(-half, -half), Vector2(half, -half), Vector2(half, half), Vector2(-half, half)])
		_:
			for index in 32:
				var angle := TAU * index / 32.0
				points.append(Vector2(cos(angle), sin(angle)) * radius)
	return points


static func draw_shape(canvas: CanvasItem, shape_name: String, center: Vector2, radius: float, color: Color, outlined := true) -> void:
	if shape_name == "flower":
		for pass_index in (2 if outlined else 1):
			var grow := radius * 0.09 if outlined and pass_index == 0 else 0.0
			var fill := INK if outlined and pass_index == 0 else color
			for index in 5:
				var angle := -PI * 0.5 + TAU * index / 5.0
				canvas.draw_circle(center + Vector2(cos(angle), sin(angle)) * radius * 0.62, radius * 0.46 + grow, fill)
		canvas.draw_circle(center, radius * 0.36, INK if outlined else color.darkened(0.2))
		canvas.draw_circle(center, radius * 0.28, Color("ffe172"))
		return
	var points := shape_points(shape_name, radius)
	if outlined:
		canvas.draw_colored_polygon(_offset(points, center, 1.14), INK)
	canvas.draw_colored_polygon(_offset(points, center, 1.0), color)


static func _offset(points: PackedVector2Array, center: Vector2, scale_factor: float) -> PackedVector2Array:
	var moved := PackedVector2Array()
	for point in points:
		moved.append(center + point * scale_factor)
	return moved
