class_name RoomItemPreview3D
extends SubViewportContainer

const RoomAuthoredFurnitureLoader = preload("res://scripts/meta/room_authored_furniture_loader.gd")
const RoomProceduralFurnitureBuilder = preload("res://scripts/meta/room_procedural_furniture_builder.gd")
const RoomCompanionPreviewBuilder = preload("res://scripts/meta/room_companion_preview_builder.gd")
const RoomPreviewViewportScene = preload("res://scripts/meta/room_preview_viewport.gd")
const CompanionAssets = preload("res://scripts/meta/companion_asset_catalog.gd")


var item_id := ""
var category := "cozy"
var mesh_count := 0
var uses_character_model := false
var source_model_id := ""
var animate_character := true
var presentation_context := "room"
var uses_authored_furniture_model := false
var source_furniture_model_id := ""
var display_rotation_root: Node3D
var preview_viewport
var display_yaw_degrees := 0.0
var companion_builder: RoomCompanionPreviewBuilder
var loading_portrait: TextureRect
var model_ready := false
var _furniture_loader: RoomAuthoredFurnitureLoader
var _furniture_model: Node3D
var _loading_furniture_art: TextureRect


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and not animate_character and preview_viewport != null:
		# Stretching recreates the SubViewport target. Static previews only render
		# once, so resize must explicitly arm one fresh frame.
		preview_viewport.request_redraw()


func setup(definition: Dictionary) -> void:
	item_id = str(definition.get("id", definition.get("item_id", "decor")))
	category = str(definition.get("category", "cozy"))
	uses_character_model = item_id.begins_with("companion_") or category == "companions"
	animate_character = uses_character_model and bool(definition.get("animate", true))
	presentation_context = str(definition.get("presentation", "room" if animate_character else "marketplace"))
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_viewport()


func _exit_tree() -> void:
	if companion_builder != null:
		companion_builder.cancel()
	if _furniture_loader != null:
		_furniture_loader.cancel()
	if preview_viewport != null:
		preview_viewport.shutdown()


func _build_viewport() -> void:
	preview_viewport = RoomPreviewViewportScene.new()
	var viewport_size := Vector2i(448, 320) if uses_character_model else Vector2i(192, 192)
	var update_mode := SubViewport.UPDATE_ALWAYS if animate_character else SubViewport.UPDATE_ONCE
	preview_viewport.mount(self, viewport_size, update_mode, display_yaw_degrees)
	var stage: Node3D = preview_viewport.stage
	display_rotation_root = preview_viewport.display_rotation_root
	if uses_character_model:
		_build_companion(stage)
	else:
		_build_furniture(stage)
	preview_viewport.add_lighting()


func set_display_yaw(degrees: float) -> void:
	display_yaw_degrees = fposmod(degrees, 360.0)
	if preview_viewport != null:
		preview_viewport.set_yaw(display_yaw_degrees, not animate_character)


func set_motion_state(walking: bool) -> void:
	if companion_builder != null:
		companion_builder.set_motion_state(walking)


func _build_companion(stage: Node3D) -> void:
	if companion_builder != null:
		companion_builder.cancel()
	companion_builder = RoomCompanionPreviewBuilder.new()
	loading_portrait = TextureRect.new()
	loading_portrait.name = "CompanionLoadingPortrait"
	loading_portrait.texture = load(CompanionAssets.thumbnail_path(item_id.trim_prefix("companion_"))) as Texture2D
	loading_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	loading_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	loading_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	loading_portrait.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(loading_portrait)
	source_model_id = companion_builder.build(self, display_rotation_root, preview_viewport, item_id, animate_character, presentation_context, _on_companion_mesh_count)


func _on_companion_mesh_count(count: int) -> void:
	mesh_count = count
	model_ready = true
	if is_instance_valid(loading_portrait):
		loading_portrait.queue_free()
	loading_portrait = null
	# Static companion models are loaded asynchronously. Their viewport may
	# already have spent its one frame before the model joins the scene.
	if preview_viewport != null:
		if animate_character:
			preview_viewport.viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		else:
			preview_viewport.request_redraw()


func _build_furniture(stage: Node3D) -> void:
	var model := Node3D.new()
	model.name = "FurnitureModel"
	model.rotation_degrees.y = -18.0
	display_rotation_root.add_child(model)
	_add_shadow(model)
	_furniture_model = model
	_furniture_loader = RoomAuthoredFurnitureLoader.new()
	if _furniture_loader.request(item_id, model, _on_furniture_loaded):
		var path := "res://assets/store/decor_thumbnails/%s.png" % item_id
		if ResourceLoader.exists(path):
			_loading_furniture_art = TextureRect.new()
			_loading_furniture_art.name = "FurnitureLoadingThumbnail"
			_loading_furniture_art.texture = load(path) as Texture2D
			_loading_furniture_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			_loading_furniture_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			_loading_furniture_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_loading_furniture_art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			add_child(_loading_furniture_art)
	else:
		_on_furniture_loaded({"built": false, "source_model_id": ""})
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 2.85
	stage.add_child(camera)
	camera.look_at_from_position(Vector3(3.7, 2.75, 4.8), Vector3(0.0, 0.62, 0.0), Vector3.UP)
	camera.current = true


func _on_furniture_loaded(result: Dictionary) -> void:
	uses_authored_furniture_model = bool(result.get("built", false))
	source_furniture_model_id = str(result.get("source_model_id", ""))
	if not uses_authored_furniture_model:
		RoomProceduralFurnitureBuilder.new().build(_furniture_model, item_id, category)
	mesh_count = _count_meshes(_furniture_model)
	model_ready = true
	if is_instance_valid(_loading_furniture_art):
		_loading_furniture_art.queue_free()
	_loading_furniture_art = null
	# Rotation may change during the load; the display root already holds the
	# latest yaw. Render that yaw now rather than retaining the empty first frame.
	if preview_viewport != null:
		preview_viewport.request_redraw()


func _add_shadow(parent: Node3D) -> void:
	var shadow := _cylinder(parent, "ContactShadow", 0.92, 0.92, 0.025, Vector3(0, 0.015, 0), Color(0.04, 0.03, 0.12, 0.2))
	shadow.scale.z = 0.58


func _cylinder(parent: Node3D, node_name: String, top_radius: float, bottom_radius: float, height: float, location: Vector3, color: Color, emission := false) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top_radius
	mesh.bottom_radius = bottom_radius
	mesh.height = height
	mesh.radial_segments = 24
	mesh.material = _material(color, emission)
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.position = location
	parent.add_child(instance)
	return instance


func _material(color: Color, emission := false) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.72
	if color.a < 0.99:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if emission:
		material.emission_enabled = true
		material.emission = Color(color.r, color.g, color.b)
		material.emission_energy_multiplier = 0.55
	return material


func _count_meshes(node: Node) -> int:
	var count := 1 if node is MeshInstance3D else 0
	for child in node.get_children():
		count += _count_meshes(child)
	return count
