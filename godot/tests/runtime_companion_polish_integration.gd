extends Node

const Preview = preload("res://scripts/meta/room_item_preview_3d.gd")
const Meadow = preload("res://scripts/meta/meadow_companion_stage_3d.gd")
const Assets = preload("res://scripts/meta/companion_asset_catalog.gd")

var failures: Array[String] = []
var checks := 0


func _ready() -> void:
	_run.call_deferred()


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


func _wait_for_model(parent: Node, name_pattern := "LiveUnicornModel") -> bool:
	var deadline := Time.get_ticks_msec() + 10000
	while Time.get_ticks_msec() < deadline:
		if parent.find_child(name_pattern, true, false) != null:
			return true
		await get_tree().create_timer(0.01).timeout
	return false


func _run() -> void:
	GameExperience.set_process(false)
	if not SaveService.begin_test_session():
		get_tree().quit(1)
		return
	AppState.data = SaveService.create_profile("Companion Polish")
	AppState._has_unsaved_changes = false
	await _test_preview_loading()
	await _test_meadow_loading()
	SaveService.end_test_session()
	if failures.is_empty():
		print("RUNTIME_COMPANION_POLISH_INTEGRATION_OK: %d checks" % checks)
		get_tree().quit(0)
	else:
		push_error("Companion polish failures: %s" % "; ".join(failures))
		get_tree().quit(1)


func _test_preview_loading() -> void:
	var path := Assets.model_path("sparkle")
	RuntimeAssetLoader._cache.erase(path)
	var preview := Preview.new()
	preview.setup({"id": "companion_sparkle", "animate": true})
	add_child(preview)
	preview.set_motion_state(true)
	_check(preview.mesh_count == 0 and preview.loading_portrait.texture != null, "Cold previews show a portrait without synchronously instantiating the GLB")
	_check(RuntimeAssetLoader._pending.has(path), "Animated previews request the shared threaded loader")
	var loaded: bool = await _wait_for_model(preview)
	_check(loaded, "Cold animated companion eventually loads")
	if loaded:
		var animator := preview.get_node("IdleAnimator") as UnicornIdleAnimator
		_check(preview.loading_portrait == null and preview.mesh_count > 0, "The model replaces its loading portrait")
		_check(preview.preview_viewport.viewport.render_target_update_mode == SubViewport.UPDATE_ALWAYS, "Loaded animated previews retain continuous rendering")
		_check(animator.active_action != &"" and animator.animation_player.is_playing(), "Motion requested before the load is applied to the new model")
		AppState.set_setting("reduced_motion", true)
		_check(animator.active_action == &"" and not animator.animation_player.is_playing() and animator.timer.is_stopped(), "Reduced motion stops walking and optional roaming")
		var position := animator.model.position
		await get_tree().create_timer(0.05).timeout
		_check(animator.model.position == position, "Reduced-motion companions remain planted")
		AppState.set_setting("reduced_motion", false)
		_check(animator.animation_player.is_playing(), "Turning motion back on restores an explicitly requested walk")
	preview.free()
	await get_tree().process_frame
	var still := Preview.new()
	still.setup({"id": "companion_sparkle", "animate": false})
	add_child(still)
	_check(still.mesh_count == 0 and still.loading_portrait != null, "Warm cache hits also defer replacement safely")
	_check(await _wait_for_model(still), "Static companion resolves from cache")
	_check(still.preview_viewport.viewport.render_target_update_mode != SubViewport.UPDATE_ALWAYS, "Static portraits do not acquire a continuous viewport")
	still.free()
	await get_tree().process_frame
	var retired := Preview.new()
	retired.setup({"id": "companion_sparkle", "animate": true})
	add_child(retired)
	remove_child(retired)
	await get_tree().process_frame
	_check(retired.find_child("LiveUnicornModel", true, false) == null, "A queued model cannot populate an exited preview")
	retired.free()
	# Simulate a failed load callback: the portrait must remain useful.
	var cached := RuntimeAssetLoader.cached_packed_scene(path)
	RuntimeAssetLoader._cache[path] = null
	var fallback := Preview.new()
	fallback.setup({"id": "companion_sparkle", "animate": true})
	add_child(fallback)
	await get_tree().process_frame
	_check(fallback.mesh_count == 0 and is_instance_valid(fallback.loading_portrait) and fallback.loading_portrait.texture != null, "A failed model load retains the portrait")
	fallback.free()
	RuntimeAssetLoader.cache_packed_scene(path, cached)


func _test_meadow_loading() -> void:
	AppState.set_setting("reduced_motion", true)
	var meadow := Meadow.new()
	add_child(meadow)
	meadow.setup("sparkle", ["sparkle"])
	_check(meadow.find_child("LiveUnicornModel_sparkle", true, false) == null, "Meadow setup defers character loads so the shell can finish")
	meadow.set_active(false)
	_check(await _wait_for_model(meadow, "LiveUnicornModel_sparkle"), "Meadow model loads through the shared cache")
	var animator := meadow.find_child("IdleAnimator", true, false) as UnicornIdleAnimator
	_check(animator != null and not animator.can_process() and animator.timer.is_stopped(), "Late arrivals in a retired meadow stay inactive and respect reduced motion")
	var shadow := meadow.find_child("MeadowContactShadow", true, false) as MeshInstance3D
	var material := shadow.mesh.material as StandardMaterial3D if shadow != null else null
	_check(material != null and material.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA and material.albedo_color.a < 0.3, "Meadow contact shadows have a translucent material instead of default opaque white")
	meadow.set_active(true)
	AppState.set_setting("reduced_motion", false)
	_check(animator.can_process() and not animator.timer.is_stopped(), "Reactivating the meadow restores automatic roaming")
	meadow.free()
	await get_tree().process_frame
	var retired := Meadow.new()
	add_child(retired)
	retired.setup("sparkle", ["sparkle"])
	remove_child(retired)
	await get_tree().process_frame
	_check(retired.find_child("LiveUnicornModel_sparkle", true, false) == null, "A queued load cannot populate an exited meadow")
	retired.free()
