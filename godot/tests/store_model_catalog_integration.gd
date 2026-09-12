extends Node

const PreviewScene = preload("res://scripts/meta/room_item_preview_3d.gd")
const Catalog = preload("res://scripts/meta_catalog.gd")
const MODEL_CATALOG_PATH := "res://data/store_model_catalog.json"


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: Array[String] = []
	var file := FileAccess.open(MODEL_CATALOG_PATH, FileAccess.READ)
	if file == null:
		push_error("Could not open the store model catalog")
		get_tree().quit(1)
		return
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Store model catalog is not valid JSON")
		get_tree().quit(1)
		return
	var items: Dictionary = parsed.get("items", {})
	if items.size() != 107:
		failures.append("Expected 107 authored store items, found %d" % items.size())
	var scenes: Dictionary = {}
	for item_id in items:
		var definition: Dictionary = items[item_id]
		var scene_path := str(definition.get("scene", ""))
		var packed_scene: PackedScene = scenes.get(scene_path)
		if packed_scene == null:
			packed_scene = load(scene_path) as PackedScene
			if packed_scene != null:
				scenes[scene_path] = packed_scene
		if packed_scene == null:
			failures.append("%s could not load %s" % [item_id, scene_path])
			continue
		var source_root := packed_scene.instantiate()
		if source_root.find_child(str(definition.get("node", item_id)), true, false) == null:
			failures.append("%s is missing its named source node" % item_id)
		source_root.free()
		var catalog_definition := Catalog.furniture_item(str(item_id))
		if catalog_definition.is_empty():
			failures.append("%s is absent from the gameplay catalog" % item_id)
			continue
		var preview := PreviewScene.new()
		add_child(preview)
		preview.setup(catalog_definition)
		await get_tree().process_frame
		var deadline := Time.get_ticks_msec() + 10000
		while not preview.model_ready and Time.get_ticks_msec() < deadline:
			await get_tree().process_frame
		if not preview.uses_authored_furniture_model:
			failures.append("%s did not select its authored runtime model" % item_id)
		if preview.find_child("AuthoredFurniture_%s" % item_id, true, false) == null:
			failures.append("%s did not expose its authored runtime node" % item_id)
		if preview.mesh_count < 2:
			failures.append("%s did not render model geometry plus its shadow" % item_id)
		preview.free()
	var missing: Array = parsed.get("missing_procedural_fallbacks", [])
	for item_id in missing:
		var preview := PreviewScene.new()
		add_child(preview)
		preview.setup(Catalog.furniture_item(str(item_id)))
		await get_tree().process_frame
		if preview.uses_authored_furniture_model:
			failures.append("%s should still use its procedural fallback" % item_id)
		preview.free()
	if failures.is_empty():
		print("STORE_MODEL_CATALOG_PASS: 107 authored models loaded; no procedural catalog fallbacks remain")
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error(failure)
		get_tree().quit(1)
