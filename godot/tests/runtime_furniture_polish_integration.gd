extends Node

const Preview = preload("res://scripts/meta/room_item_preview_3d.gd")
const Catalog = preload("res://scripts/meta_catalog.gd")
const Loader = preload("res://scripts/meta/room_authored_furniture_loader.gd")

var failures: Array[String] = []
var checks := 0


func _ready() -> void:
	_run.call_deferred()


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


func _preview(item_id: String) -> RoomItemPreview3D:
	var preview := Preview.new()
	add_child(preview)
	preview.setup(Catalog.furniture_item(item_id))
	return preview


func _wait_until_ready(preview: RoomItemPreview3D) -> bool:
	var deadline := Time.get_ticks_msec() + 10000
	while not preview.model_ready and Time.get_ticks_msec() < deadline:
		await get_tree().create_timer(0.01).timeout
	return preview.model_ready


func _run() -> void:
	GameExperience.set_process(false)
	var path := str(Loader._store_catalog_items()["lamp"]["scene"])
	RuntimeAssetLoader._cache.erase(path)
	var lamp := _preview("lamp")
	var rug := _preview("rug")
	_check(not lamp.model_ready and not rug.model_ready and lamp.find_child("AuthoredFurniture_lamp", true, false) == null, "Cold furniture setup does not instantiate the GLB synchronously")
	_check(RuntimeAssetLoader._pending.size() == 1 and RuntimeAssetLoader._waiters[path].size() == 2, "Items on the same sheet share one threaded load")
	_check(lamp.find_child("FurnitureLoadingThumbnail", true, false) != null, "Furniture displays its catalog thumbnail during loading")
	lamp.set_display_yaw(135.0)
	rug.set_display_yaw(270.0)
	_check(await _wait_until_ready(lamp) and await _wait_until_ready(rug), "Both authored models become ready")
	_check(lamp.uses_authored_furniture_model and lamp.source_furniture_model_id == "store1:lamp" and lamp.mesh_count >= 2, "Lamp resolves to authored geometry and its contact shadow")
	_check(rug.uses_authored_furniture_model and rug.source_furniture_model_id == "store1:rug", "A shared load preserves each item's identity")
	_check(is_equal_approx(lamp.display_rotation_root.rotation_degrees.y, 135.0) and is_equal_approx(rug.display_rotation_root.rotation_degrees.y, 270.0), "Models keep the yaw chosen while loading")
	_check(not lamp.animate_character and lamp.preview_viewport.viewport.render_target_update_mode != SubViewport.UPDATE_ALWAYS, "Furniture renders on demand even when animate is omitted")
	lamp.preview_viewport.shutdown()
	lamp.size += Vector2(10, 10)
	_check(lamp.preview_viewport.viewport.render_target_update_mode == SubViewport.UPDATE_ONCE, "Resizing loaded furniture requests a new frame")
	lamp.free()
	rug.free()
	await get_tree().process_frame
	var warm := _preview("chair")
	_check(not warm.model_ready, "Warm furniture requests defer instantiation safely")
	_check(await _wait_until_ready(warm), "Warm furniture eventually replaces its thumbnail")
	warm.free()
	var retired := _preview("plant")
	remove_child(retired)
	await get_tree().process_frame
	_check(not retired.model_ready and retired.find_child("AuthoredFurniture_plant", true, false) == null, "Late callbacks do not populate exited previews")
	retired.free()
	# A load failure must still produce usable fallback geometry.
	var cached := RuntimeAssetLoader.cached_packed_scene(path)
	RuntimeAssetLoader._cache[path] = null
	var fallback := _preview("lamp")
	_check(await _wait_until_ready(fallback), "Failed model loads complete with a fallback")
	_check(not fallback.uses_authored_furniture_model and fallback.mesh_count > 1, "Failure uses the procedural model instead of an empty viewport")
	fallback.free()
	RuntimeAssetLoader.cache_packed_scene(path, cached)
	var unmapped := Preview.new()
	add_child(unmapped)
	unmapped.setup({"id": "unknown_test_item", "category": "cozy"})
	_check(unmapped.model_ready and not unmapped.uses_authored_furniture_model and unmapped.mesh_count > 1, "Unmapped decor has an immediate procedural fallback")
	unmapped.free()
	await get_tree().process_frame
	if failures.is_empty():
		print("RUNTIME_FURNITURE_POLISH_INTEGRATION_OK: %d checks" % checks)
		get_tree().quit(0)
	else:
		push_error("Furniture polish failures: %s" % "; ".join(failures))
		get_tree().quit(1)
