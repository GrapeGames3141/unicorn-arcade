class_name RoomAuthoredFurnitureLoader
extends RefCounted

const STORE_MODEL_CATALOG_PATH := "res://data/store_model_catalog.json"

static var _store_model_catalog: Dictionary = {}
static var _store_scene_cache: Dictionary = {}
var _request_generation := 0


func request(item_id: String, parent: Node3D, callback: Callable) -> bool:
	_request_generation += 1
	var definition: Dictionary = _store_catalog_items().get(item_id, {})
	if definition.is_empty():
		return false
	var path := str(definition.get("scene", ""))
	RuntimeAssetLoader.load_packed_scene(path, _finish_request.bind(_request_generation, item_id, weakref(parent), definition, callback))
	return true


func cancel() -> void:
	_request_generation += 1


func _finish_request(scene: PackedScene, generation: int, item_id: String, target: WeakRef, definition: Dictionary, callback: Callable) -> void:
	var parent := target.get_ref() as Node3D
	if generation != _request_generation or not is_instance_valid(parent) or parent.is_queued_for_deletion() or not callback.is_valid():
		return
	callback.call(_build_from_scene(item_id, parent, definition, scene))


static func build(item_id: String, parent: Node3D) -> Dictionary:
	var definition: Dictionary = _store_catalog_items().get(item_id, {})
	if definition.is_empty():
		return {"built": false, "source_model_id": ""}
	var scene_path := str(definition.get("scene", ""))
	var packed_scene := _load_store_scene(scene_path)
	return _build_from_scene(item_id, parent, definition, packed_scene)


static func _build_from_scene(item_id: String, parent: Node3D, definition: Dictionary, packed_scene: PackedScene) -> Dictionary:
	if packed_scene == null:
		return {"built": false, "source_model_id": ""}
	var scene_path := str(definition.get("scene", ""))
	var source_root := packed_scene.instantiate() as Node3D
	var node_name := str(definition.get("node", item_id))
	var source_node := source_root.find_child(node_name, true, false) as Node3D if source_root != null else null
	if source_node == null:
		if source_root != null:
			source_root.free()
		return {"built": false, "source_model_id": ""}
	var source_parent := source_node.get_parent()
	if source_parent != null:
		source_parent.remove_child(source_node)
	source_node.owner = null
	parent.add_child(source_node)
	source_node.name = "AuthoredFurniture_%s" % item_id
	source_node.transform = Transform3D.IDENTITY
	source_node.scale = Vector3.ONE * float(definition.get("scale", 1.0))
	source_root.free()
	return {"built": true, "source_model_id": "%s:%s" % [scene_path.get_file().get_basename().trim_suffix("_mobile"), item_id]}


static func _store_catalog_items() -> Dictionary:
	if not _store_model_catalog.is_empty():
		return _store_model_catalog
	var file := FileAccess.open(STORE_MODEL_CATALOG_PATH, FileAccess.READ)
	if file == null:
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) == TYPE_DICTIONARY:
		_store_model_catalog = parsed.get("items", {})
	return _store_model_catalog


static func _load_store_scene(scene_path: String) -> PackedScene:
	if scene_path.is_empty():
		return null
	if _store_scene_cache.has(scene_path):
		return _store_scene_cache[scene_path] as PackedScene
	var packed_scene := load(scene_path) as PackedScene
	if packed_scene != null:
		_store_scene_cache[scene_path] = packed_scene
	return packed_scene
