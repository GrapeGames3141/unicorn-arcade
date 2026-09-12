extends Node

## Serializes static decor rendering.  A room can have many texture-backed
## buttons, but there is never more than one transient decor SubViewport.
const PreviewScene = preload("res://scripts/meta/room_item_preview_3d.gd")
const THUMBNAIL_DIRECTORY := "res://assets/store/decor_thumbnails/"
signal preview_ready(key: String, texture: Texture2D)

var _textures: Dictionary = {}
var _thumbnail_fallbacks: Dictionary = {}
var _queue: Array[Dictionary] = []
var _waiters: Dictionary = {}
var _rendering := false
var _active_key := ""
var _host: Control


func request(definition: Dictionary, yaw_degrees: float, callback: Callable) -> void:
	var key := cache_key(definition, yaw_degrees)
	if _textures.has(key):
		callback.call_deferred(_textures[key] as Texture2D)
		return
	var callbacks: Array = _waiters.get(key, [])
	callbacks.append(callback)
	_waiters[key] = callbacks
	if _active_key == key or _queue.any(func(entry: Dictionary) -> bool: return str(entry.get("key", "")) == key):
		return
	if _rendering and not _queue.is_empty() and str(_queue.front().get("key", "")) == key:
		return
	_queue.append({"key": key, "definition": definition.duplicate(true), "yaw": yaw_degrees})
	if not _rendering:
		call_deferred("_render_next")


func cache_key(definition: Dictionary, yaw_degrees: float) -> String:
	return "%s:%d" % [str(definition.get("id", definition.get("item_id", "decor"))), int(round(fposmod(yaw_degrees, 360.0) / 45.0)) * 45]


func cached_texture(definition: Dictionary, yaw_degrees: float) -> Texture2D:
	return _textures.get(cache_key(definition, yaw_degrees)) as Texture2D


func is_thumbnail_fallback(definition: Dictionary, yaw_degrees: float) -> bool:
	return bool(_thumbnail_fallbacks.get(cache_key(definition, yaw_degrees), false))


func active_viewport_count() -> int:
	return 1 if _rendering else 0


func _thumbnail_fallback(definition: Dictionary) -> Texture2D:
	var item_id := str(definition.get("id", definition.get("item_id", "")))
	var thumbnail := load("%s%s.png" % [THUMBNAIL_DIRECTORY, item_id]) as Texture2D
	if thumbnail == null:
		return null
	var image := thumbnail.get_image()
	if image != null and not image.is_empty() and image.get_used_rect().has_area():
		return ImageTexture.create_from_image(image)
	return thumbnail


func _has_visible_pixels(image: Image) -> bool:
	return image != null and not image.is_empty() and image.get_used_rect().has_area()


func _render_next() -> void:
	if _queue.is_empty():
		_rendering = false
		return
	_rendering = true
	var request_data: Dictionary = _queue.pop_front()
	_active_key = str(request_data.get("key", ""))
	if not is_instance_valid(_host):
		_host = Control.new()
		_host.name = "DecorPreviewCacheRenderer"
		# Keep the SubViewportContainer in the visible canvas so Godot submits its
		# render target. Negative draw order keeps this transient renderer behind
		# normal UI without relying on an offscreen position that can be culled.
		_host.position = Vector2.ZERO
		_host.size = Vector2(192, 192)
		_host.z_index = -100
		_host.show_behind_parent = true
		_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
		get_tree().root.add_child(_host)
	var preview := PreviewScene.new()
	preview.size = Vector2(192, 192)
	_host.add_child(preview)
	preview.setup(request_data.definition.merged({"animate": false, "presentation": "cache"}, true))
	preview.set_display_yaw(float(request_data.yaw))
	var viewport := preview.get_node_or_null("SubViewport") as SubViewport
	if is_instance_valid(viewport):
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var texture: Texture2D = null
	var used_thumbnail_fallback := false
	if DisplayServer.get_name() == "headless":
		texture = _thumbnail_fallback(request_data.definition)
		used_thumbnail_fallback = true
	elif is_instance_valid(viewport):
		# The initial render may contain only the contact shadow. Wait for asset
		# completion before reading pixels, with a bounded fallback on slow loads.
		var deadline := Time.get_ticks_msec() + 10000
		while not preview.model_ready and Time.get_ticks_msec() < deadline:
			await get_tree().process_frame
		if preview.model_ready:
			viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
			for frame in 12:
				await get_tree().process_frame
				await RenderingServer.frame_post_draw
				var image := viewport.get_texture().get_image()
				if _has_visible_pixels(image):
					texture = ImageTexture.create_from_image(image)
					break
	if texture == null:
		# A bounded readback can remain transparent before the preview is drawn.
		# Keep its thumbnail visible rather than caching a blank texture.
		texture = _thumbnail_fallback(request_data.definition)
		used_thumbnail_fallback = true
	if texture != null:
		_textures[request_data.key] = texture
		_thumbnail_fallbacks[request_data.key] = used_thumbnail_fallback
		preview_ready.emit(request_data.key, texture)
	var callbacks: Array = _waiters.get(request_data.key, [])
	_waiters.erase(request_data.key)
	for callback in callbacks:
		if callback is Callable and (callback as Callable).is_valid():
			(callback as Callable).call_deferred(texture)
	preview.queue_free()
	_active_key = ""
	call_deferred("_render_next")
