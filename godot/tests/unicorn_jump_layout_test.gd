extends Node

const JumpScene = preload("res://scenes/games/unicorn_jump.tscn")
const CompanionAssets = preload("res://scripts/meta/companion_asset_catalog.gd")

var failures: Array[String] = []


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var jump = JumpScene.instantiate()
	get_tree().root.add_child(jump)
	var portrait = jump.companion_preview.loading_portrait
	_check(is_instance_valid(portrait) and portrait.texture != null and portrait.texture.resource_path == CompanionAssets.thumbnail_path(AppState.equipped_companion()), "the starting stone immediately shows the equipped companion portrait while its model loads")
	await get_tree().process_frame
	await get_tree().process_frame

	var landing: int = jump.level_data[0]
	_check(jump.node_buttons[0].global_position.y < jump.node_buttons[-1].global_position.y, "forward progress runs from the top of the trail downward")
	_check(jump.node_buttons[landing].global_position.y > jump.node_buttons[0].global_position.y, "the first forward jump lands lower on the path")
	_check(jump.find_child("TrailTopClearance", true, false) != null, "the trail keeps the unicorn clear of its top clipping edge")
	_check(jump.world_viewport != null and jump.world_viewport is Control, "Unicorn Jump uses a pan/pinch game camera instead of a scrollbar")
	_check(jump.find_child("GameWorldViewport", true, false) != null, "the playfield is a clipped GameWorldViewport")
	_check(not (jump.world_viewport is ScrollContainer), "the playfield does not expose a ScrollContainer scrollbar")
	var view_rect: Rect2 = jump.world_viewport.get_global_rect()
	var first_five_centers_visible := true
	for index in range(mini(5, jump.node_buttons.size())):
		first_five_centers_visible = first_five_centers_visible and view_rect.has_point(jump.node_buttons[index].get_global_rect().get_center())
	_check(jump.world_viewport.zoom < 1.0 and first_five_centers_visible, "the initial camera frames the current stone and four forward stones while keeping pinch zoom available")
	_check(not jump.world_viewport.pan.is_equal_approx(Vector2.ZERO), "the startup camera applies its initial focus instead of leaving the trail at zero pan")
	# Threaded model loading can take longer than two frames on a cold CI worker.
	# Keep the geometry/rendering assertions, but wait for the readiness contract.
	var model_deadline := Time.get_ticks_msec() + 10000
	while not jump.companion_preview.model_ready and Time.get_ticks_msec() < model_deadline:
		await get_tree().create_timer(0.01).timeout
	_check(jump.companion_preview.model_ready and jump.companion_preview.animate_character and jump.companion_preview.mesh_count > 0 and jump.companion_preview.find_child("LiveUnicornModel", true, false) != null and jump.companion_preview.preview_viewport.viewport.render_target_update_mode == SubViewport.UPDATE_ALWAYS, "the current stone displays the loaded equipped unicorn through the live renderer within ten seconds")
	_check(jump.companion_preview.loading_portrait == null, "the loaded unicorn replaces its loading portrait")
	_check(jump.find_children("ActiveCompanionOnStone", "", true, false).size() == 1 and jump.companion_preview.get_parent() == jump.world_viewport.world and jump.companion_preview.size == jump.COMPANION_DISPLAY_SIZE and jump.companion_preview.position.is_equal_approx(jump._companion_world_position(0)), "one full-size unicorn is positioned in trail-world coordinates on the starting stone")
	if _supports_render_readback():
		await RenderingServer.frame_post_draw
		_check(_non_transparent_pixels(jump.companion_preview.preview_viewport.viewport) > 0, "the unicorn preview contains rendered pixels before the first input")
	var first_preview = jump.companion_preview
	var first_global_size: Vector2 = first_preview.get_global_rect().size
	jump._choose_node(landing)
	await get_tree().create_timer(1.2).timeout
	if _supports_render_readback():
		await RenderingServer.frame_post_draw
	_check(jump.current_index == landing and jump.companion_preview == first_preview and jump.find_child("JumpingCompanion", true, false) == null, "the same unicorn preview moves through the complete jump")
	_check(jump.companion_preview.position.is_equal_approx(jump._companion_world_position(landing)) and jump.companion_preview.get_global_rect().size.is_equal_approx(first_global_size), "the unicorn lands centered without changing its rendered size")
	if _supports_render_readback():
		_check(_non_transparent_pixels(jump.companion_preview.preview_viewport.viewport) > 0, "the unicorn preview still contains rendered pixels after landing")
	# Leave the scene exactly as the following dialog-layout checks expect it.
	jump.current_index = 0
	jump.visited.clear()
	jump.visited.append(0)
	jump._update_path()
	await get_tree().process_frame

	var experience = get_tree().root.get_node("GameExperience")
	var previous_scene = experience.attached_scene
	var previous_game_id: String = experience.attached_game_id
	var was_processing: bool = experience.is_processing()
	experience.set_process(false)
	experience.attached_scene = jump
	experience.attached_game_id = "unicorn_jump"
	var objective_plaque := experience.call("_build_objective_plaque") as PanelContainer
	var hud_mascot := objective_plaque.find_child("EquippedCompanionMascot", true, false) as TextureRect
	var expected_thumbnail_path := CompanionAssets.thumbnail_path(AppState.equipped_companion())
	_check(is_instance_valid(hud_mascot) and hud_mascot.custom_minimum_size.x >= 96.0 and hud_mascot.texture != null and hud_mascot.texture.resource_path == expected_thumbnail_path, "the shared objective HUD uses the equipped companion thumbnail at its isolated padded size")
	objective_plaque.queue_free()
	experience.call("_show_notice", "Lucky Rainbow", "Gives a chance at bonus coins.")
	await get_tree().process_frame
	await get_tree().process_frame

	var notice := jump.find_child("CompanionAbilityNotice", true, false) as Control
	_check(notice != null, "the companion dialog opens inside Unicorn Jump")
	if notice != null:
		_check(notice.get_parent() == jump.world_viewport.get_parent() and notice.get_index() < jump.world_viewport.get_index(), "the companion dialog reserves space above the trail")
		var notice_rect := notice.get_global_rect()
		_check(not notice_rect.intersects(jump.node_buttons[0].get_global_rect()), "the dialog does not cover the unicorn's current stone")
		_check(not notice_rect.intersects(jump.node_buttons[landing].get_global_rect()), "the dialog does not cover the upcoming landing stone")
		notice.queue_free()

	experience.call("_request_leave", false)
	await get_tree().process_frame
	var leave_overlay := jump.find_child("LeaveRunOverlay", true, false) as Control
	var leave_copy := jump.find_child("LeaveRunCopy", true, false) as Label
	var leave_button := jump.find_child("LeaveRunConfirm", true, false) as Button
	var keep_button := jump.find_child("LeaveRunCancel", true, false) as Button
	_check(is_instance_valid(leave_overlay) and is_instance_valid(leave_copy) and leave_copy.get_theme_font_size("font_size") >= 23 and is_instance_valid(leave_button) and leave_button.text == "LEAVE RUN" and is_instance_valid(keep_button) and keep_button.text == "KEEP PLAYING", "leaving an active run uses the readable in-game storybook modal and styled choices")
	_check(jump.find_children("*", "ConfirmationDialog", true, false).is_empty(), "leave confirmation never opens a system ConfirmationDialog")
	if is_instance_valid(keep_button):
		keep_button.emit_signal("pressed")

	experience.attached_scene = previous_scene
	experience.attached_game_id = previous_game_id
	experience.set_process(was_processing)
	jump.queue_free()
	await get_tree().process_frame

	if failures.is_empty():
		print("UNICORN JUMP LAYOUT TESTS PASSED")
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error(failure)
		get_tree().quit(1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _supports_render_readback() -> bool:
	# The dummy renderer used by `godot --headless` never emits frame_post_draw;
	# waiting for it would hang CI. Desktop/device runs retain pixel assertions.
	return DisplayServer.get_name() != "headless"


func _non_transparent_pixels(viewport: SubViewport) -> int:
	if not is_instance_valid(viewport):
		return 0
	var image := viewport.get_texture().get_image()
	if image == null or image.is_empty():
		return 0
	if image.get_format() != Image.FORMAT_RGBA8:
		image.convert(Image.FORMAT_RGBA8)
	var data := image.get_data()
	var visible := 0
	for offset in range(3, data.size(), 4):
		if data[offset] > 0:
			visible += 1
	return visible
