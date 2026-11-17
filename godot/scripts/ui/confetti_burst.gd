class_name ConfettiBurst
extends Control

## A short, code-drawn confetti shower for level-complete moments. It draws
## nothing when Reduced motion is on.
const COLORS := [Color("ffd166"), Color("f26fa7"), Color("58d6e8"), Color("b79cff"), Color("62e6a7"), Color("fff3d6")]
const PIECES := 70
const LIFETIME := 3.2

var pieces: Array[Dictionary] = []
var age := 0.0
var rng := RandomNumberGenerator.new()


func _init() -> void:
	name = "ConfettiBurst"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _ready() -> void:
	if bool(AppState.setting("reduced_motion", false)):
		set_process(false)
		return
	rng.randomize()
	var width := maxf(size.x, 360.0)
	for index in PIECES:
		pieces.append({
			"position": Vector2(rng.randf_range(0.0, width), rng.randf_range(-260.0, -10.0)),
			"velocity": Vector2(rng.randf_range(-70.0, 70.0), rng.randf_range(170.0, 380.0)),
			"spin": rng.randf_range(-7.0, 7.0),
			"angle": rng.randf_range(0.0, TAU),
			"size": rng.randf_range(9.0, 18.0),
			"color": COLORS[index % COLORS.size()],
			"star": index % 5 == 0,
		})


func _process(delta: float) -> void:
	age += delta
	if age >= LIFETIME:
		set_process(false)
		pieces.clear()
		queue_redraw()
		return
	for piece in pieces:
		piece["velocity"] = (piece["velocity"] as Vector2) + Vector2(0.0, 120.0) * delta
		piece["position"] = (piece["position"] as Vector2) + (piece["velocity"] as Vector2) * delta
		piece["angle"] = float(piece["angle"]) + float(piece["spin"]) * delta
	queue_redraw()


func _draw() -> void:
	var fade := clampf((LIFETIME - age) / 0.8, 0.0, 1.0)
	for piece in pieces:
		var color := Color(piece["color"], fade)
		var extent := float(piece["size"])
		draw_set_transform(piece["position"], float(piece["angle"]), Vector2.ONE)
		if bool(piece["star"]):
			ShapeTile.draw_shape(self, "star", Vector2.ZERO, extent * 0.7, color, false)
		else:
			draw_rect(Rect2(-extent * 0.5, -extent * 0.28, extent, extent * 0.56), color)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
