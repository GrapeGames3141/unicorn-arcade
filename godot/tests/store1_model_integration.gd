extends Node

const PreviewScene = preload("res://scripts/meta/room_item_preview_3d.gd")
const Catalog = preload("res://scripts/meta_catalog.gd")

const EXPECTED := {
	"lamp": "AuthoredFurniture_lamp",
	"rug": "AuthoredFurniture_rug",
	"plant": "AuthoredFurniture_plant",
	"chair": "AuthoredFurniture_chair",
	"arcade": "AuthoredFurniture_arcade",
	"trophy": "AuthoredFurniture_trophy",
}


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: Array[String] = []
	for item_id in EXPECTED:
		var preview := PreviewScene.new()
		add_child(preview)
		preview.setup(Catalog.furniture_item(item_id))
		await get_tree().process_frame
		var deadline := Time.get_ticks_msec() + 10000
		while not preview.model_ready and Time.get_ticks_msec() < deadline:
			await get_tree().process_frame
		if not preview.uses_authored_furniture_model:
			failures.append("%s did not select the authored model" % item_id)
		if preview.source_furniture_model_id != "store1:%s" % item_id:
			failures.append("%s reported the wrong source model" % item_id)
		if preview.find_child(EXPECTED[item_id], true, false) == null:
			failures.append("%s did not expose its named runtime mesh" % item_id)
		if preview.mesh_count < 2:
			failures.append("%s did not render authored geometry plus its contact shadow" % item_id)
		preview.free()
	if failures.is_empty():
		print("STORE1_INTEGRATION_PASS: six authored catalog models loaded")
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error(failure)
		get_tree().quit(1)
