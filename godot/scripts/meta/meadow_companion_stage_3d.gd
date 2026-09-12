class_name MeadowCompanionStage3D
extends Node

const CompanionAssets = preload("res://scripts/meta/companion_asset_catalog.gd")
const IdleAnimator = preload("res://scripts/meta/unicorn_idle_animator.gd")
const HERO_POSITION := Vector3(-5.8, -2.6, 0.95)
const HERO_SCALE_MULTIPLIER := 3.8
const HERO_SHADOW_RADIUS := 0.84

var viewport: SubViewport
var _generation := 0
var _active := true


func setup(equipped_id: String, companion_ids: Array) -> void:
	_generation += 1
	viewport = SubViewport.new()
	viewport.name = "MeadowSharedViewport"
	viewport.size = Vector2i(720, 420)
	viewport.own_world_3d = true
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	var stage := Node3D.new()
	stage.name = "MeadowSharedStage"
	viewport.add_child(stage)
	var camera := Camera3D.new()
	camera.name = "MeadowSharedCamera"
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 13.0
	stage.add_child(camera)
	camera.look_at_from_position(Vector3(-12.0, 6.0, 3.0), Vector3(0.0, 1.4, 0.0), Vector3.UP)
	_add_lights(stage)
	var positions := [Vector3(-0.8, 0.0, -3.0), Vector3(-0.8, 0.0, 3.4), Vector3(3.1, 0.0, -6.9), Vector3(3.3, 0.0, -0.1), Vector3(3.5, 0.0, 5.9)]
	var background_index := 0
	for raw_id in companion_ids:
		var id := str(raw_id)
		var front := id == equipped_id
		var position: Vector3 = HERO_POSITION if front else positions[background_index]
		if not front:
			background_index += 1
		_add_companion(stage, id, position, front, "hero" if front else ("mid" if background_index <= 2 else "rear"), background_index)


func create_display() -> TextureRect:
	var display := TextureRect.new()
	display.name = "MeadowCompanionDisplay"
	display.texture = viewport.get_texture()
	display.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	display.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	display.mouse_filter = Control.MOUSE_FILTER_IGNORE
	display.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return display


func _add_companion(stage: Node3D, id: String, position: Vector3, hero: bool, formation_row: String, formation_slot: int) -> void:
	var root := Node3D.new()
	root.name = "MeadowTravelRoot_%s" % id
	root.position = position
	root.set_meta("source_model_id", id)
	root.set_meta("hero", hero)
	root.set_meta("formation_row", formation_row)
	root.set_meta("formation_slot", formation_slot)
	var behavior := _behavior_options(id, hero, formation_slot)
	root.set_meta("roam_behavior_signature", "%s|%.2f|%.2f|%.2f|%.2f|%.2f" % [id, behavior["walk_speed"], behavior["roam_radius_x"], behavior["roam_radius_z"], behavior["min_idle_seconds"], behavior["max_idle_seconds"]])
	stage.add_child(root)
	RuntimeAssetLoader.load_packed_scene(CompanionAssets.model_path(id), _finish_companion_load.bind(weakref(root), id, hero, behavior, _generation))


func _finish_companion_load(packed_scene: PackedScene, target: WeakRef, id: String, hero: bool, behavior: Dictionary, generation: int) -> void:
	var root := target.get_ref() as Node3D
	if generation != _generation or not is_instance_valid(root):
		return
	if packed_scene == null:
		return
	var model := packed_scene.instantiate() as Node3D
	if model == null:
		return
	model.name = "LiveUnicornModel_%s" % id
	model.scale = Vector3.ONE * CompanionAssets.scale_for(id) * (HERO_SCALE_MULTIPLIER if hero else 1.7)
	model.position.y = -0.25
	root.add_child(model)
	var shadow := MeshInstance3D.new()
	shadow.name = "MeadowContactShadow"
	var mesh := CylinderMesh.new()
	mesh.top_radius = HERO_SHADOW_RADIUS if hero else 0.42
	mesh.bottom_radius = mesh.top_radius
	mesh.height = 0.02
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.12, 0.10, 0.24, 0.20)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh.material = material
	shadow.mesh = mesh
	shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	shadow.position = Vector3(0.0, 0.02, -0.06)
	shadow.scale.z = 0.55
	root.add_child(shadow)
	var animator := IdleAnimator.new()
	animator.name = "IdleAnimator"
	root.get_parent().add_child(animator)
	animator.setup(root, behavior)
	animator.process_mode = Node.PROCESS_MODE_INHERIT if _active else Node.PROCESS_MODE_DISABLED


func _behavior_options(id: String, hero: bool, formation_slot: int) -> Dictionary:
	# Stable per-unicorn options prevent shared routes and make all six walkers
	# feel individually alive after a page rebuild.
	var index := clampi(formation_slot, 0, 5)
	var base := 0.42 if hero else 0.55
	return {
		"seed": "meadow:%s" % id,
		"roam_2d": true,
		"roam_radius_x": base + 0.06 * index,
		"roam_radius_z": base + 0.05 * ((index + formation_slot) % 6),
		"walk_speed": 0.46 + 0.055 * ((index + 2) % 6),
		"min_idle_seconds": 1.3 + 0.16 * index,
		"max_idle_seconds": 3.0 + 0.22 * ((index + formation_slot) % 6),
	}


func _add_lights(stage: Node3D) -> void:
	var key := DirectionalLight3D.new()
	key.name = "MeadowSharedKeyLight"
	key.rotation_degrees = Vector3(-52.0, -28.0, 0.0)
	key.light_energy = 1.2
	stage.add_child(key)
	var fill := OmniLight3D.new()
	fill.name = "MeadowSharedFillLight"
	fill.position = Vector3(-2.0, 5.0, 4.0)
	fill.light_energy = 0.7
	fill.omni_range = 18.0
	stage.add_child(fill)


func set_active(active: bool) -> void:
	_active = active
	if is_instance_valid(viewport):
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if active else SubViewport.UPDATE_DISABLED
		viewport.process_mode = Node.PROCESS_MODE_INHERIT if active else Node.PROCESS_MODE_DISABLED
	for animator in find_children("*", "UnicornIdleAnimator", true, false):
		animator.process_mode = Node.PROCESS_MODE_INHERIT if active else Node.PROCESS_MODE_DISABLED


func _exit_tree() -> void:
	_generation += 1
	if is_instance_valid(viewport):
		viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
