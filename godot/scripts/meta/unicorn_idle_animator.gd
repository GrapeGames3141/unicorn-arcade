class_name UnicornIdleAnimator
extends Node

const MIN_IDLE_SECONDS := 1.8
const MAX_IDLE_SECONDS := 4.5
const DEFAULT_ROAM_RADIUS := 1.15
const MIN_WALK_DISTANCE := 0.48
const WALK_SPEED := 0.62
const WALK_TURN_SECONDS := 0.28

var model: Node3D
var animation_player: AnimationPlayer
var timer: Timer
var available_animations: Array[StringName] = []
var walk_animation := StringName()
var idle_animation := StringName()
var active_action := StringName()
var last_animation_name := ""
var next_delay_seconds := 0.0
var rng := RandomNumberGenerator.new()
var walk_tween: Tween
var home_position := Vector3.ZERO
var home_rotation_y := 0.0
var roam_radius := DEFAULT_ROAM_RADIUS
var roam_radius_x := DEFAULT_ROAM_RADIUS
var roam_radius_z := DEFAULT_ROAM_RADIUS
var min_idle_seconds := MIN_IDLE_SECONDS
var max_idle_seconds := MAX_IDLE_SECONDS
var walk_speed := WALK_SPEED
var roam_2d := false
var last_destination := Vector3.ZERO
var _reduced_motion := false
var _motion_override := -1


func setup(target: Node3D, options: Dictionary = {}) -> void:
	model = target
	_reduced_motion = bool(AppState.setting("reduced_motion", false))
	if not AppState.state_changed.is_connected(_sync_motion_preference):
		AppState.state_changed.connect(_sync_motion_preference)
	home_position = model.position
	home_rotation_y = model.rotation.y
	roam_radius = maxf(MIN_WALK_DISTANCE, float(options.get("roam_radius", DEFAULT_ROAM_RADIUS)))
	roam_radius_x = maxf(MIN_WALK_DISTANCE, float(options.get("roam_radius_x", roam_radius)))
	roam_radius_z = maxf(MIN_WALK_DISTANCE, float(options.get("roam_radius_z", roam_radius)))
	min_idle_seconds = float(options.get("min_idle_seconds", MIN_IDLE_SECONDS))
	max_idle_seconds = maxf(min_idle_seconds, float(options.get("max_idle_seconds", MAX_IDLE_SECONDS)))
	walk_speed = maxf(0.15, float(options.get("walk_speed", WALK_SPEED)))
	roam_2d = bool(options.get("roam_2d", false))
	var roaming_seed := str(options.get("seed", target.name))
	# A stable seed gives every unicorn its own route without changing its
	# behavior every time a page is rebuilt.
	rng.seed = hash(roaming_seed)
	animation_player = _find_animation_player(model)
	timer = Timer.new()
	timer.name = "WalkTimer"
	timer.one_shot = true
	timer.timeout.connect(_start_walk)
	add_child(timer)
	if not is_instance_valid(animation_player):
		push_warning("Unicorn model %s has no AnimationPlayer." % model.name)
		return
	_collect_animations()
	walk_animation = _resolve_animation("walk")
	if walk_animation == &"":
		push_warning("Unicorn model %s has no Walk animation." % model.name)
		return
	var animation := animation_player.get_animation(walk_animation)
	if animation != null:
		animation.loop_mode = Animation.LOOP_LINEAR
	_pose_standing()
	_schedule_next()


func animation_names() -> PackedStringArray:
	var names := PackedStringArray()
	for animation_name in available_animations:
		names.append(_simple_name(animation_name))
	return names


func play_random_animation_now() -> void:
	if is_instance_valid(timer):
		timer.stop()
	_start_walk()


func play_animation_now(requested: String) -> bool:
	if _reduced_motion or requested.to_lower() != "walk" or walk_animation == &"":
		return false
	if is_instance_valid(timer):
		timer.stop()
	_start_walk()
	return true


func set_motion_state(walking: bool) -> void:
	_motion_override = 1 if walking else 0
	if not is_instance_valid(animation_player) or walk_animation == &"":
		return
	if is_instance_valid(timer):
		timer.stop()
		timer.autostart = false
	_cancel_walk_journey()
	if walking and not _reduced_motion:
		active_action = walk_animation
		last_animation_name = "walk"
		animation_player.play(walk_animation, 0.12)
	else:
		active_action = &""
		_pose_standing()


func _sync_motion_preference() -> void:
	var reduced := bool(AppState.setting("reduced_motion", false))
	if reduced == _reduced_motion:
		return
	_reduced_motion = reduced
	if not is_instance_valid(animation_player):
		return
	if is_instance_valid(timer):
		timer.stop()
		# Setup can precede entering the tree; cancel that pending start too.
		timer.autostart = false
	_cancel_walk_journey()
	active_action = &""
	_pose_standing()
	if not _reduced_motion:
		if _motion_override >= 0:
			set_motion_state(_motion_override == 1)
		else:
			_schedule_next()


func _collect_animations() -> void:
	available_animations.clear()
	for animation_name in animation_player.get_animation_list():
		if _simple_name(animation_name) != "reset":
			available_animations.append(animation_name)


func _start_walk() -> void:
	if _reduced_motion or not is_instance_valid(animation_player) or walk_animation == &"":
		return
	_cancel_walk_journey()
	active_action = walk_animation
	last_animation_name = "walk"
	animation_player.play(walk_animation, 0.18)
	_start_walk_journey()


func _start_walk_journey() -> void:
	if not is_instance_valid(model):
		return
	if not roam_2d:
		_start_floor_lane_journey()
		return
	var current_offset := Vector2(model.position.x - home_position.x, model.position.z - home_position.z)
	var destination_offset := Vector2(rng.randf_range(-roam_radius_x, roam_radius_x), rng.randf_range(-roam_radius_z, roam_radius_z))
	var attempts := 0
	while destination_offset.distance_to(current_offset) < MIN_WALK_DISTANCE and attempts < 6:
		destination_offset = Vector2(rng.randf_range(-roam_radius_x, roam_radius_x), rng.randf_range(-roam_radius_z, roam_radius_z))
		attempts += 1
	if destination_offset.distance_to(current_offset) < MIN_WALK_DISTANCE:
		destination_offset = Vector2(-roam_radius_x if current_offset.x > 0.0 else roam_radius_x, -roam_radius_z if current_offset.y > 0.0 else roam_radius_z)
	var direction := destination_offset - current_offset
	var destination := Vector3(home_position.x + destination_offset.x, home_position.y, home_position.z + destination_offset.y)
	last_destination = destination
	# The model's yaw follows its X/Z travel vector; Y remains exactly on its
	# own floor/home plane throughout a meadow walk.
	var facing_rotation := home_rotation_y + atan2(direction.x, direction.y)
	var walk_seconds := maxf(0.65, direction.length() / walk_speed)
	walk_tween = create_tween()
	walk_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	walk_tween.tween_property(model, "rotation:y", facing_rotation, WALK_TURN_SECONDS)
	walk_tween.set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN_OUT)
	walk_tween.tween_property(model, "position", destination, walk_seconds)
	walk_tween.tween_callback(_finish_walk_journey)


func _start_floor_lane_journey() -> void:
	# Other previews retain their established one-axis floor lane. Meadow opts
	# into the 2D branch above; this keeps Room Editor's separate roaming intact.
	var current_offset := model.position.z - home_position.z
	var destination_offset := rng.randf_range(-roam_radius, roam_radius)
	var attempts := 0
	while absf(destination_offset - current_offset) < MIN_WALK_DISTANCE and attempts < 6:
		destination_offset = rng.randf_range(-roam_radius, roam_radius)
		attempts += 1
	if absf(destination_offset - current_offset) < MIN_WALK_DISTANCE:
		destination_offset = -roam_radius if current_offset > 0.0 else roam_radius
	var direction := signf(destination_offset - current_offset)
	var destination := home_position + Vector3(0.0, 0.0, destination_offset)
	last_destination = destination
	var facing_rotation := home_rotation_y if direction > 0.0 else home_rotation_y + PI
	var walk_seconds := maxf(0.65, absf(destination_offset - current_offset) / walk_speed)
	walk_tween = create_tween()
	walk_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	walk_tween.tween_property(model, "rotation:y", facing_rotation, WALK_TURN_SECONDS)
	walk_tween.set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN_OUT)
	walk_tween.tween_property(model, "position", destination, walk_seconds)
	walk_tween.tween_callback(_finish_walk_journey)


func _finish_walk_journey() -> void:
	walk_tween = null
	active_action = &""
	_pose_standing()
	_schedule_next()


func _cancel_walk_journey() -> void:
	if walk_tween != null and walk_tween.is_valid():
		walk_tween.kill()
	walk_tween = null


func _pose_standing() -> void:
	if not is_instance_valid(animation_player) or walk_animation == &"":
		return
	animation_player.play(walk_animation)
	animation_player.seek(0.0, true)
	animation_player.pause()
	_reset_skeleton_poses(model)


func _schedule_next() -> void:
	if _reduced_motion or not is_instance_valid(timer):
		return
	next_delay_seconds = rng.randf_range(min_idle_seconds, max_idle_seconds)
	timer.wait_time = next_delay_seconds
	if timer.is_inside_tree():
		timer.start()
	else:
		timer.autostart = true


func _resolve_animation(requested: String) -> StringName:
	for animation_name in available_animations:
		if _simple_name(animation_name) == requested.to_lower():
			return animation_name
	return &""


func _simple_name(animation_name: StringName) -> String:
	return String(animation_name).get_file().get_basename().to_lower()


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
