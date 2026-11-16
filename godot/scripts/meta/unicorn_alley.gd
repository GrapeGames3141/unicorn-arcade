extends Control

const Catalog = preload("res://scripts/meta_catalog.gd")
const DoorStateArtScene = preload("res://scripts/meta/door_state_art.gd")
const UnicornHeader = preload("res://scripts/ui/unicorn_header.gd")

const NAVY := Color("07142c")
const PANEL := Color("14214a")
const PINK := Color("f26fa7")
const YELLOW := Color("ffd166")
const MUTED := Color("aab7e8")
const ALLEY_MAP = preload("res://assets/meta/environments/unicorn_alley_production_v1.png")
const HOUSE_POSITIONS := {
	"sparkle": Vector2(0.17, 0.22),
	"rainbow": Vector2(0.71, 0.235),
	"star": Vector2(0.20, 0.465),
	"cloud": Vector2(0.695, 0.49),
	"dream": Vector2(0.105, 0.705),
	"mystic": Vector2(0.86, 0.735),
}

var message_label: Label
var house_buttons := {}
var map_rect: TextureRect


func _ready() -> void:
	_build_ui()


func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = NAVY
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	StorybookUI.dress_dusk_backdrop(bg)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_bottom", 18)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(margin)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	margin.add_child(root)
	root.add_child(UnicornHeader.build("UNICORN ALLEY", "HOME", _go_home, _go_home, "SHOP", func() -> void: get_tree().change_scene_to_file("res://scenes/meta/marketplace.tscn")))
	var intro := Label.new()
	intro.text = "Every adopted companion has a house. Make each room their own."
	intro.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intro.add_theme_color_override("font_color", MUTED)
	root.add_child(intro)
	var stage := Control.new()
	stage.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stage.clip_contents = true
	root.add_child(stage)
	map_rect = TextureRect.new()
	map_rect.texture = ALLEY_MAP
	map_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	map_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	map_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(map_rect)
	for definition in Catalog.companions():
		var companion_id := str(definition["id"])
		var owned := companion_id in AppState.owned_companions()
		var house := Button.new()
		house.text = ""
		house.tooltip_text = "%s's house - %s" % [str(definition["name"]), "open" if owned else "locked"]
		house.custom_minimum_size = Vector2(82, 122)
		house.size = house.custom_minimum_size
		for state in ["normal", "hover", "pressed", "focus", "disabled"]:
			house.add_theme_stylebox_override(state, StyleBoxEmpty.new())
		house.pressed.connect(_house_pressed.bind(companion_id, owned))
		stage.add_child(house)
		var state_art := DoorStateArtScene.new()
		state_art.name = "DoorStateArt"
		state_art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		state_art.setup(owned, Color(str(definition["color"])))
		house.add_child(state_art)
		house_buttons[companion_id] = house
	stage.resized.connect(_layout_alley.bind(stage))
	_layout_alley.call_deferred(stage)
	message_label = Label.new()
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message_label.custom_minimum_size.y = 50
	message_label.add_theme_color_override("font_color", YELLOW)
	root.add_child(message_label)


func _layout_alley(stage: Control) -> void:
	if not is_instance_valid(map_rect) or stage.size.x < 1.0 or stage.size.y < 1.0:
		return
	var source_size := ALLEY_MAP.get_size()
	var fit_scale := minf(stage.size.x / source_size.x, stage.size.y / source_size.y)
	map_rect.size = source_size * fit_scale
	map_rect.position = Vector2((stage.size.x - map_rect.size.x) * 0.5, 14.0)
	for companion_id in house_buttons:
		var house := house_buttons[companion_id] as Button
		var normalized: Vector2 = HOUSE_POSITIONS.get(companion_id, Vector2(0.5, 0.5))
		house.position = map_rect.position + map_rect.size * normalized - house.size * 0.5


func _house_pressed(companion_id: String, owned: bool) -> void:
	if not owned:
		var definition := Catalog.companion(companion_id)
		message_label.text = "Adopt %s in the Marketplace to unlock this house." % definition.get("name", companion_id)
		return
	AppState.active_room_companion = companion_id
	get_tree().change_scene_to_file("res://scenes/meta/room_editor.tscn")


func _go_home() -> void:
	AppState.shell_view = "home"
	get_tree().change_scene_to_file("res://scenes/main.tscn")
