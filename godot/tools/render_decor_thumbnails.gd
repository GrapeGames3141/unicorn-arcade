extends Control

const Catalog = preload("res://scripts/meta_catalog.gd")
const RoomItemPreviewScene = preload("res://scripts/meta/room_item_preview_3d.gd")
const OUTPUT_DIR := "res://assets/store/decor_thumbnails"


func _ready() -> void:
	_generate.call_deferred()


func _generate() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var generated := 0
	var failures: Array[String] = []
	for definition in Catalog.furniture():
		var item_id := str(definition["id"])
		var preview := RoomItemPreviewScene.new()
		preview.custom_minimum_size = Vector2(256, 256)
		preview.size = Vector2(256, 256)
		preview.setup(definition)
		add_child(preview)
		var deadline := Time.get_ticks_msec() + 10000
		while not preview.model_ready and Time.get_ticks_msec() < deadline:
			await get_tree().process_frame
		if not preview.model_ready:
			failures.append(item_id)
			remove_child(preview)
			preview.queue_free()
			continue
		await get_tree().process_frame
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
		await get_tree().process_frame
		await get_tree().process_frame
		var viewport := preview.find_child("*", true, false) as SubViewport
		var viewports: Array[Node] = preview.find_children("*", "SubViewport", true, false)
		if not viewports.is_empty():
			viewport = viewports[0] as SubViewport
		if viewport == null or viewport.get_texture() == null:
			failures.append(item_id)
		else:
			var image := viewport.get_texture().get_image()
			if image == null or image.is_empty():
				failures.append(item_id)
			else:
				image.resize(256, 256, Image.INTERPOLATE_LANCZOS)
				var error := image.save_png(ProjectSettings.globalize_path("%s/%s.png" % [OUTPUT_DIR, item_id]))
				if error == OK:
					generated += 1
				else:
					failures.append(item_id)
		remove_child(preview)
		preview.queue_free()
		await get_tree().process_frame
	print("DECOR_THUMBNAILS generated=%d failed=%d" % [generated, failures.size()])
	if not failures.is_empty():
		push_error("Failed decor thumbnails: %s" % ", ".join(failures))
	get_tree().quit(0 if failures.is_empty() else 1)
