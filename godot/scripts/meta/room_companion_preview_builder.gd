class_name RoomCompanionPreviewBuilder
extends RefCounted

const CompanionAssets = preload("res://scripts/meta/companion_asset_catalog.gd")
const UnicornIdleAnimatorScene = preload("res://scripts/meta/unicorn_idle_animator.gd")
const CHARACTER_SCALE_MULTIPLIER := 3.0
const ANIMATED_CAMERA_SIZE := 6.80
const STATIC_CAMERA_SIZE := 6.80
const HERO_CAMERA_SIZE := 6.60
const BACKGROUND_CAMERA_SIZE := 8.40
const GAME_HUD_CAMERA_SIZE := 8.80
const ANIMATION_FRAME_LIFT := Vector3(0.0, 1.10, 0.0)
const STATIC_FRAME_LIFT := Vector3(0.0, 1.10, 0.0)
const HERO_FRAME_LIFT := Vector3(0.0, 1.10, 0.0)
const BACKGROUND_FRAME_LIFT := Vector3(0.0, 0.92, 0.0)
const SIDE_CAMERA_POSITION := Vector3(-8.40, 3.18, 0.90)
const SIDE_CAMERA_TARGET := Vector3(0.0, 1.72, -0.15)

var host: SubViewportContainer
var display_rotation_root: Node3D
var viewport_owner
var item_id := ""
var animate := true
var presentation := "room"
var mesh_count_callback: Callable
var _request_generation := 0
var _idle_animator: UnicornIdleAnimator
var _motion_requested := false
var _requested_walking := false


func build(request_host: SubViewportContainer, rotation_root: Node3D, owner, requested_item_id: String, requested_animate: bool, requested_presentation: String, on_mesh_count: Callable) -> String:
	host = request_host
	display_rotation_root = rotation_root
	viewport_owner = owner
	item_id = requested_item_id
	animate = requested_animate
	presentation = requested_presentation
	mesh_count_callback = on_mesh_count
	var companion_id := CompanionAssets.normalized_id(item_id.trim_prefix("companion_"))
	var travel_root := Node3D.new()
	travel_root.name = "CompanionTravelRoot"
	display_rotation_root.add_child(travel_root)
	if animate:
		_idle_animator = UnicornIdleAnimatorScene.new()
		_idle_animator.name = "IdleAnimator"
		host.add_child(_idle_animator)
	var generation := _request_generation + 1
	_request_generation = generation
	var model_path := CompanionAssets.model_path(companion_id)
	RuntimeAssetLoader.load_packed_scene(model_path, _finish_model_load.bind(generation, weakref(travel_root), companion_id))
	_add_companion_shadow(travel_root)
	_add_camera()
	return companion_id


func _finish_model_load(packed_scene: PackedScene, generation: int, target: WeakRef, companion_id: String) -> void:
	var travel_root := target.get_ref() as Node3D
	if generation != _request_generation or not is_instance_valid(travel_root) or not is_instance_valid(host) or host.is_queued_for_deletion() or packed_scene == null:
		return
	_instantiate_companion(packed_scene, companion_id, travel_root)


func cancel() -> void:
	_request_generation += 1


func set_motion_state(walking: bool) -> void:
	_motion_requested = true
	_requested_walking = walking
	if is_instance_valid(_idle_animator):
		_idle_animator.set_motion_state(walking)


func _add_camera() -> void:
	var camera_size := STATIC_CAMERA_SIZE
	if not animate:
		camera_size = GAME_HUD_CAMERA_SIZE if presentation == "game_hud" else STATIC_CAMERA_SIZE
	elif presentation == "hero":
		camera_size = HERO_CAMERA_SIZE
	elif presentation == "meadow_background":
		camera_size = BACKGROUND_CAMERA_SIZE
	else:
		camera_size = ANIMATED_CAMERA_SIZE
	var frame_lift := STATIC_FRAME_LIFT
	if animate:
		if presentation == "hero":
			frame_lift = HERO_FRAME_LIFT
		elif presentation == "meadow_background":
			frame_lift = BACKGROUND_FRAME_LIFT
		else:
			frame_lift = ANIMATION_FRAME_LIFT
	viewport_owner.add_camera(camera_size, SIDE_CAMERA_POSITION + frame_lift, SIDE_CAMERA_TARGET + frame_lift)


func _instantiate_companion(packed_scene: PackedScene, companion_id: String, travel_root: Node3D) -> void:
	var model := packed_scene.instantiate() as Node3D
	if model == null:
		return
	model.name = "LiveUnicornModel"
	model.position.y = -0.25
	model.scale = Vector3.ONE * CompanionAssets.scale_for(companion_id) * CHARACTER_SCALE_MULTIPLIER
	travel_root.add_child(model)
	if mesh_count_callback.is_valid():
		mesh_count_callback.call(_count_meshes(model))
	if animate:
		if is_instance_valid(_idle_animator):
			var roam_radius := 1.15
			if presentation == "meadow_background":
				roam_radius = 1.65
			elif presentation == "hero":
				roam_radius = 0.85
			_idle_animator.setup(travel_root, {"seed": "%s:%s" % [companion_id, presentation], "roam_radius": roam_radius})
			if _motion_requested:
				_idle_animator.set_motion_state(_requested_walking)
	else:
		_pose_companion(model)


func _pose_companion(model: Node) -> void:
	var animation_player := _find_animation_player(model)
	if animation_player == null:
		return
	var fallback := StringName()
	for animation_name in animation_player.get_animation_list():
		var simple_name := String(animation_name).get_file().get_basename().to_lower()
		if simple_name == "walk":
			fallback = animation_name
		if simple_name == "idle":
			animation_player.play(animation_name)
			animation_player.seek(0.0, true)
			animation_player.pause()
			_reset_skeleton_poses(model)
			return
	if fallback != &"":
		animation_player.play(fallback)
		animation_player.seek(0.0, true)
		animation_player.pause()
	_reset_skeleton_poses(model)


func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for child in node.get_children():
		var found := _find_animation_player(child)
		if found != null:
			return found
	return null


func _reset_skeleton_poses(node: Node) -> void:
	if node is Skeleton3D:
		(node as Skeleton3D).reset_bone_poses()
	for child in node.get_children():
		_reset_skeleton_poses(child)


func _add_companion_shadow(stage: Node3D) -> void:
	var shadow_mesh := CylinderMesh.new()
	shadow_mesh.top_radius = 0.88
	shadow_mesh.bottom_radius = 0.88
	shadow_mesh.height = 0.025
	shadow_mesh.material = _material(Color(0.12, 0.10, 0.24, 0.20), false)
	var shadow := MeshInstance3D.new()
	shadow.name = "MeadowContactShadow"
	shadow.mesh = shadow_mesh
	shadow.position = Vector3(0.0, 0.02, -0.05)
	shadow.scale.z = 0.58
	stage.add_child(shadow)


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
