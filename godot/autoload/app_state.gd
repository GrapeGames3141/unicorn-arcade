extends Node

const MetaCatalog = preload("res://scripts/meta_catalog.gd")
const RoomRules = preload("res://scripts/room_rules.gd")

signal state_changed
signal coins_changed(coins: int)
signal save_failed(message: String)
signal save_recovered

var data: Dictionary = {}
var selected_game_id := ""
var selected_category := "Number"
var shell_view := "home"
var active_room_companion := "sparkle"
var _has_unsaved_changes := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	data = SaveService.load_state()


func _notification(what: int) -> void:
	if (what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT) and _has_unsaved_changes and SaveService.has_active_profile():
		flush_pending_save()


func has_unsaved_changes() -> bool:
	return _has_unsaved_changes


func flush_pending_save() -> bool:
	if not _has_unsaved_changes:
		return true
	if not SaveService.has_active_profile():
		return false
	if not SaveService.save_state(data):
		save_failed.emit(SaveService.last_error)
		return false
	_has_unsaved_changes = false
	save_recovered.emit()
	return true


func profile_names() -> Array[String]:
	return SaveService.profile_names()


func select_profile(display_name: String) -> bool:
	if _has_unsaved_changes and not flush_pending_save():
		return false
	var selected := SaveService.select_profile(display_name)
	if selected.is_empty():
		return false
	data = selected
	shell_view = "home"
	state_changed.emit()
	coins_changed.emit(coins())
	return true


func coins() -> int:
	return int(data.get("player", {}).get("coins", 1000))


func owned_companions() -> Array:
	return data.get("owned_companions", ["sparkle"])


func equipped_companion() -> String:
	return str(data.get("player", {}).get("equipped_companion", "sparkle"))


func player_name() -> String:
	return str(data.get("player", {}).get("name", ""))


func set_player_name(value: String) -> void:
	var requested := value.strip_edges()
	if player_name().is_empty():
		if _has_unsaved_changes and not flush_pending_save():
			return
		var created := SaveService.create_profile(requested)
		if not created.is_empty():
			data = created
			state_changed.emit()
			coins_changed.emit(coins())
			return
	data["player"]["name"] = requested
	_save_and_emit()


func logout() -> bool:
	# Signing out must not erase the selected profile's display name or progress.
	if _has_unsaved_changes and not flush_pending_save():
		return false
	if not SaveService.deactivate_profile():
		push_error("Unicorn Arcade logout save failed: %s" % SaveService.last_error)
		return false
	data = SaveService.default_profile()
	shell_view = "home"
	state_changed.emit()
	coins_changed.emit(coins())
	return true


func current_level(game_id: String) -> int:
	var record: Dictionary = data.get("progress", {}).get(game_id, {})
	return maxi(1, int(record.get("max_level", 1)))


func progress_for_game(game_id: String) -> Dictionary:
	return data.get("progress", {}).get(game_id, {}).duplicate(true)


func completed_run_count() -> int:
	var count := 0
	for record in data.get("progress", {}).values():
		count += record.get("completed", []).size()
	return count


func select_game(game_id: String, category: String) -> void:
	selected_game_id = game_id
	selected_category = category
	shell_view = "category"


func set_shell_destination(view: String, category := "") -> void:
	shell_view = view
	if not category.is_empty():
		selected_category = category


func setting(key: String, fallback = false):
	return data.get("settings", {}).get(key, fallback)


func set_setting(key: String, value) -> void:
	data["settings"][key] = value
	_save_and_emit()


func tutorial_complete(game_id: String, level: int) -> bool:
	return level in data.get("tutorials", {}).get(game_id, [])


func mark_tutorial_complete(game_id: String, level: int) -> void:
	var tutorials: Dictionary = data.get("tutorials", {})
	var completed: Array = tutorials.get(game_id, [])
	if level not in completed:
		completed.append(level)
		completed.sort()
		tutorials[game_id] = completed
		data["tutorials"] = tutorials
		_save_and_emit()


func reset_tutorials() -> void:
	data["tutorials"] = {}
	_save_and_emit()


func spend_hint(level: int) -> bool:
	if CompanionAbilityService.consume_free_hint():
		return true
	var cost := RewardService.hint_cost(level)
	if coins() < cost:
		return false
	data["player"]["coins"] = coins() - cost
	_save_and_emit()
	return true


func buy_companion(companion_id: String) -> bool:
	var definition := MetaCatalog.companion(companion_id)
	if definition.is_empty() or companion_id in owned_companions():
		return false
	var price := int(definition.get("price", 0))
	if coins() < price:
		return false
	data["player"]["coins"] = coins() - price
	data["owned_companions"].append(companion_id)
	data["inventory"]["companion_%s" % companion_id] = 1
	_save_and_emit()
	return true


func equip_companion(companion_id: String) -> bool:
	if companion_id not in owned_companions():
		return false
	data["player"]["equipped_companion"] = companion_id
	_save_and_emit()
	return true


func buy_furniture(item_id: String) -> bool:
	var definition := MetaCatalog.furniture_item(item_id)
	if definition.is_empty():
		return false
	var price := int(definition.get("price", 0))
	if coins() < price:
		return false
	data["player"]["coins"] = coins() - price
	data["inventory"][item_id] = int(data["inventory"].get(item_id, 0)) + 1
	_save_and_emit()
	return true


func sell_furniture(item_id: String) -> bool:
	if item_id.begins_with("companion_") or available_count(item_id) <= 0:
		return false
	var definition := MetaCatalog.furniture_item(item_id)
	if definition.is_empty():
		return false
	var remaining := int(data["inventory"].get(item_id, 0)) - 1
	if remaining <= 0:
		data["inventory"].erase(item_id)
	else:
		data["inventory"][item_id] = remaining
	data["player"]["coins"] = coins() + RoomRules.sell_refund(int(definition.get("price", 0)))
	_save_and_emit()
	return true


func placed_count(item_id: String) -> int:
	var count := 0
	for room_items in data.get("rooms", {}).values():
		for item in room_items:
			if str(item.get("item_id", "")) == item_id:
				count += 1
	return count


func available_count(item_id: String) -> int:
	return maxi(0, int(data.get("inventory", {}).get(item_id, 0)) - placed_count(item_id))


func room_items(companion_id: String) -> Array:
	return data.get("rooms", {}).get(companion_id, []).duplicate(true)


func place_room_item(companion_id: String, item: Dictionary) -> bool:
	var rooms: Dictionary = data.get("rooms", {})
	var items: Array = rooms.get(companion_id, [])
	var normalized := RoomRules.normalized(item, items.size())
	var existing := -1
	for index in items.size():
		if str(items[index].get("instance_id", "")) == str(normalized["instance_id"]):
			existing = index
			break
	if existing < 0 and available_count(str(normalized["item_id"])) <= 0:
		return false
	if existing >= 0:
		items[existing] = normalized
	else:
		items.append(normalized)
	rooms[companion_id] = items
	data["rooms"] = rooms
	_save_and_emit()
	return true


func remove_room_item(companion_id: String, instance_id: String) -> bool:
	var items := room_items(companion_id)
	var next := items.filter(func(item: Dictionary) -> bool: return str(item.get("instance_id", "")) != instance_id)
	if next.size() == items.size():
		return false
	data["rooms"][companion_id] = next
	_save_and_emit()
	return true


func reorder_room_item(companion_id: String, instance_id: String, direction: String) -> void:
	data["rooms"][companion_id] = RoomRules.reorder(room_items(companion_id), instance_id, direction)
	_save_and_emit()


func reset_room(companion_id: String) -> void:
	data["rooms"][companion_id] = []
	_save_and_emit()


func complete_level(game_id: String, level: int, elapsed_ms: int) -> int:
	var reward := RewardService.level_reward(level)
	var companion_bonus := CompanionAbilityService.reward_bonus(reward)
	reward += companion_bonus
	data["player"]["coins"] = coins() + reward
	var progress: Dictionary = data.get("progress", {})
	var record: Dictionary = progress.get(game_id, {"max_level": 1, "completed": []})
	var completed: Array = record.get("completed", [])
	completed.append({"level": level, "time": elapsed_ms, "date": Time.get_datetime_string_from_system(true)})
	record["completed"] = completed
	record["max_level"] = maxi(int(record.get("max_level", 1)), level + 1)
	progress[game_id] = record
	data["progress"] = progress
	_save_and_emit()
	return reward


func complete_endless_run(game_id: String, score: int, stage: int, elapsed_ms: int) -> int:
	var safe_score := maxi(0, score)
	var safe_stage := maxi(1, stage)
	# Pay for equations earned, never simply for starting and ending a run.
	var reward := mini(250, safe_score / 100)
	if reward > 0:
		reward += CompanionAbilityService.reward_bonus(reward)
	data["player"]["coins"] = coins() + reward
	var progress: Dictionary = data.get("progress", {})
	var record: Dictionary = progress.get(game_id, {})
	var completed: Array = record.get("completed", [])
	completed.append({"level": safe_stage, "score": safe_score, "time": elapsed_ms, "date": Time.get_datetime_string_from_system(true), "mode": "endless"})
	record["completed"] = completed
	record["best_score"] = maxi(int(record.get("best_score", 0)), safe_score)
	record["highest_stage"] = maxi(int(record.get("highest_stage", 1)), safe_stage)
	record["max_level"] = maxi(int(record.get("max_level", 1)), safe_stage)
	progress[game_id] = record
	data["progress"] = progress
	_save_and_emit()
	return reward


func _save_and_emit() -> bool:
	var was_dirty := _has_unsaved_changes
	var saved := SaveService.save_state(data)
	if not saved:
		_has_unsaved_changes = true
		push_error("Unicorn Arcade save failed: %s" % SaveService.last_error)
		save_failed.emit(SaveService.last_error)
	elif was_dirty:
		_has_unsaved_changes = false
		save_recovered.emit()
	state_changed.emit()
	coins_changed.emit(coins())
	return saved
