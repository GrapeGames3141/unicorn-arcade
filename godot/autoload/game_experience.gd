extends Node

const StorybookUI = preload("res://scripts/ui/storybook_ui.gd")
const LevelRunController = preload("res://scripts/games/level_run_controller.gd")
const TutorialCatalog = preload("res://scripts/tutorial_catalog.gd")
const ProgressRingScene = preload("res://scripts/ui/progress_ring.gd")
const GameExperienceChromePresenter = preload("res://scripts/ui/game_experience_chrome_presenter.gd")
const GameExperienceTutorialPresenter = preload("res://scripts/ui/game_experience_tutorial_presenter.gd")
const GameExperienceOutcomePresenter = preload("res://scripts/ui/game_experience_outcome_presenter.gd")

var attached_scene: Node
var attached_controller: ArcadeGameController
var attached_game_id := ""
var chrome_presenter := GameExperienceChromePresenter.new()
var tutorial_presenter := GameExperienceTutorialPresenter.new()
var outcome_presenter := GameExperienceOutcomePresenter.new()
var objective_primary: Label
var objective_detail: Label
var coin_button: Button
var ability_button: Button
var hint_button: Button
var inactivity_seconds := 0.0
var last_level := -1
var update_accumulator := 0.0
var was_active := false
var outcome_overlay: Control
var sparkle_retry_overlay: Control
var persistence_warning_layer: CanvasLayer
var persistence_warning_banner: PanelContainer
var _application_paused := false
var _focus_lost := false


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_PAUSED: _application_paused = true
		NOTIFICATION_APPLICATION_RESUMED: _application_paused = false
		NOTIFICATION_WM_WINDOW_FOCUS_OUT: _focus_lost = true
		NOTIFICATION_WM_WINDOW_FOCUS_IN: _focus_lost = false
		_: return
	_sync_application_pause()


func _sync_application_pause() -> void:
	if is_instance_valid(attached_controller):
		attached_controller.set_pause_reason(&"application", _application_paused or _focus_lost)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	AppState.coins_changed.connect(_update_coin_button)
	AppState.save_failed.connect(_show_persistence_warning)
	AppState.save_recovered.connect(_clear_persistence_warning)
	if AppState.has_unsaved_changes():
		_show_persistence_warning("Latest progress is kept in memory. Saving will retry automatically.")


func _show_persistence_warning(message: String) -> void:
	if not is_instance_valid(persistence_warning_layer):
		persistence_warning_layer = CanvasLayer.new()
		persistence_warning_layer.name = "PersistenceWarningLayer"
		persistence_warning_layer.layer = 120
		add_child(persistence_warning_layer)
		persistence_warning_banner = PanelContainer.new()
		persistence_warning_banner.name = "PersistenceWarningBanner"
		persistence_warning_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
		persistence_warning_banner.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
		persistence_warning_banner.offset_left = 14
		persistence_warning_banner.offset_right = -14
		persistence_warning_banner.offset_top = 10
		persistence_warning_banner.offset_bottom = 82
		persistence_warning_banner.add_theme_stylebox_override("panel", StorybookUI.plaque_style(Color("5b2438f2"), Color("ffd166"), 16))
		persistence_warning_layer.add_child(persistence_warning_banner)
		var label := Label.new()
		label.name = "PersistenceWarningText"
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 17)
		label.add_theme_color_override("font_color", Color("fff3d6"))
		persistence_warning_banner.add_child(label)
	var warning_text := persistence_warning_banner.get_node_or_null("PersistenceWarningText") as Label
	if is_instance_valid(warning_text):
		warning_text.text = "SAVE PAUSED — %s\nWe'll retry automatically; avoid closing the app until saving recovers." % message


func _clear_persistence_warning() -> void:
	if is_instance_valid(persistence_warning_layer):
		persistence_warning_layer.queue_free()
	persistence_warning_layer = null
	persistence_warning_banner = null


func _input(_event: InputEvent) -> void:
	inactivity_seconds = 0.0


func _process(delta: float) -> void:
	var scene := AdBarService.content_scene()
	if not is_instance_valid(scene):
		scene = get_tree().current_scene
	if scene != attached_scene:
		attached_scene = scene
		attached_controller = null
		attached_game_id = ""
		objective_primary = null
		objective_detail = null
		coin_button = null
		ability_button = null
		hint_button = null
		last_level = -1
		was_active = false
		outcome_overlay = null
		sparkle_retry_overlay = null
		inactivity_seconds = 0.0
		# Keep AdMob banner attached when leaving main.tscn for a game scene.
		AdBarService.sync_for_player(AppState.player_name())
		if _is_game_scene(scene):
			_attach_scene.call_deferred(scene)
		return
	if attached_game_id.is_empty() or not is_instance_valid(scene):
		return
	if is_instance_valid(attached_controller) and attached_controller.gameplay_paused:
		inactivity_seconds = 0.0
		return
	inactivity_seconds += delta
	update_accumulator += delta
	if update_accumulator >= 0.15:
		update_accumulator = 0.0
		_update_runtime_ui()
	if not is_instance_valid(attached_controller):
		_poll_legacy_run_activity(scene)
	var current_level := int(attached_controller.runtime_snapshot().get("level", 1)) if is_instance_valid(attached_controller) else _scene_int(scene, "level", 1)
	if current_level != last_level:
		last_level = current_level
		CompanionAbilityService.begin_level(attached_game_id, current_level)
		_update_ability_button()
		_maybe_show_tutorial.call_deferred(false)
	if inactivity_seconds >= 8.0 and CompanionAbilityService.consume_dream_nudge():
		inactivity_seconds = 0.0
		_show_assist(false)


func _is_game_scene(scene: Node) -> bool:
	return is_instance_valid(scene) and str(scene.scene_file_path).begins_with("res://scenes/games/")


func _attach_scene(scene: Node) -> void:
	if scene != AdBarService.content_scene() or not is_instance_valid(scene):
		return
	attached_game_id = AppState.selected_game_id
	attached_controller = scene as ArcadeGameController
	_sync_application_pause()
	if is_instance_valid(attached_controller):
		if not attached_controller.runtime_state_changed.is_connected(_on_runtime_state_changed):
			attached_controller.runtime_state_changed.connect(_on_runtime_state_changed)
		if not attached_controller.run_activity_changed.is_connected(_on_run_activity_changed):
			attached_controller.run_activity_changed.connect(_on_run_activity_changed)
	if attached_game_id.is_empty():
		attached_game_id = _fallback_game_id(str(scene.scene_file_path))
	var game := GameRegistry.get_game(attached_game_id)
	if game.is_empty():
		return
	var layout: VBoxContainer = null
	if attached_game_id == "galaxy_unicorn":
		layout = VBoxContainer.new()
		layout.name = "GalaxyStandardGameHeaderOverlay"
		layout.set_anchors_preset(Control.PRESET_TOP_WIDE)
		layout.offset_left = 14
		layout.offset_right = -14
		layout.offset_top = 14
		layout.z_index = 900
		scene.add_child(layout)
	else:
		layout = _find_primary_layout(scene)
	if layout == null:
		layout = VBoxContainer.new()
		layout.name = "GameExperienceOverlayLayout"
		layout.set_anchors_preset(Control.PRESET_TOP_WIDE)
		layout.offset_left = 14
		layout.offset_right = -14
		layout.offset_top = 14
		layout.z_index = 900
		scene.add_child(layout)
	layout.alignment = BoxContainer.ALIGNMENT_BEGIN
	_apply_storybook_atmosphere(scene)
	_hide_legacy_chrome(layout, str(game["title"]))
	_hide_embedded_hint_controls(scene)
	_configure_comet_chrome(scene)
	var header := _build_header(str(game["title"]))
	layout.add_child(header)
	layout.move_child(header, 0)
	var plaque := _build_objective_plaque()
	layout.add_child(plaque)
	layout.move_child(plaque, 1)
	_restyle_controls(scene)
	_polish_game_labels(scene)
	_hide_game_scrollbars(scene)
	last_level = int(attached_controller.runtime_snapshot().get("level", 1)) if is_instance_valid(attached_controller) else _scene_int(scene, "level", 1)
	CompanionAbilityService.begin_level(attached_game_id, last_level)
	was_active = bool(attached_controller.runtime_snapshot().get("active", true)) if is_instance_valid(attached_controller) else true
	_update_runtime_ui()
	_update_ability_button()
	_maybe_show_tutorial.call_deferred(false)


func _on_runtime_state_changed(snapshot: Dictionary) -> void:
	if is_instance_valid(objective_primary):
		objective_primary.text = str(snapshot.get("objective_primary", "YOUR MISSION"))
	if is_instance_valid(objective_detail):
		objective_detail.text = str(snapshot.get("objective_detail", "Complete the enchanted challenge."))
	if is_instance_valid(hint_button):
		hint_button.disabled = not bool(snapshot.get("hint_available", false))


func _on_run_activity_changed(active: bool) -> void:
	_handle_run_activity_transition(active)


func _poll_legacy_run_activity(scene: Node) -> void:
	if not _has_property(scene, "active"):
		return
	_handle_run_activity_transition(bool(scene.get("active")))


func _handle_run_activity_transition(active: bool) -> void:
	if was_active and not active:
		var snapshot := attached_controller.runtime_snapshot() if is_instance_valid(attached_controller) else {}
		var retry_available := int(snapshot.get("outcome", LevelRunController.Outcome.IDLE)) == LevelRunController.Outcome.FAILURE if is_instance_valid(attached_controller) else _is_retry_failure()
		var outcome_message := str(snapshot.get("outcome_message", "")) if is_instance_valid(attached_controller) else _outcome_message()
		if retry_available and CompanionAbilityService.consume_checkpoint_retry():
			_show_sparkle_retry_notice.call_deferred(outcome_message)
		else:
			_show_game_outcome.call_deferred()
	was_active = active


func _fallback_game_id(path: String) -> String:
	var filename := path.get_file().get_basename()
	if filename == "word_game":
		return "unicorn_blast"
	return filename


func _find_primary_layout(node: Node) -> VBoxContainer:
	return chrome_presenter.find_primary_layout(node)


func _apply_storybook_atmosphere(scene: Node) -> void:
	chrome_presenter.apply_storybook_atmosphere(scene)


func _hide_legacy_chrome(layout: VBoxContainer, title: String) -> void:
	chrome_presenter.hide_legacy_chrome(layout, title)


func _contains_navigation(node: Node) -> bool:
	return chrome_presenter.contains_navigation(node)


func _build_header(title: String) -> PanelContainer:
	var chrome := chrome_presenter.build_header(title, AppState.coins(), _request_leave.bind(false), _request_leave.bind(true), _show_profile_overlay)
	coin_button = chrome["coin_button"] as Button
	return chrome["panel"] as PanelContainer


func _header_button(text: String, tooltip: String) -> Button:
	return chrome_presenter.header_button(text, tooltip)


func _companion_thumbnail(companion_id: String, minimum_size: Vector2) -> TextureRect:
	return chrome_presenter.companion_thumbnail(companion_id, minimum_size)


func _build_objective_plaque() -> PanelContainer:
	var chrome := chrome_presenter.build_objective_plaque(AppState.equipped_companion(), _ability_pressed, _ordinary_hint_pressed, _maybe_show_tutorial.bind(true))
	objective_primary = chrome["objective_primary"] as Label
	objective_detail = chrome["objective_detail"] as Label
	ability_button = chrome["ability_button"] as Button
	hint_button = chrome["hint_button"] as Button
	return chrome["panel"] as PanelContainer


func _update_runtime_ui() -> void:
	if not is_instance_valid(attached_scene) or not is_instance_valid(objective_primary):
		return
	if is_instance_valid(attached_controller):
		_on_runtime_state_changed(attached_controller.runtime_snapshot())
		_update_coin_button(AppState.coins())
		return
	var objective := _objective_for_scene()
	objective_primary.text = str(objective.get("primary", "YOUR MISSION"))
	objective_detail.text = str(objective.get("detail", "Follow the enchanted objective."))
	_update_coin_button(AppState.coins())


func _objective_for_scene() -> Dictionary:
	if attached_game_id == "comet_math_rescue":
		var problem: Dictionary = attached_scene.get("current_problem") if _has_property(attached_scene, "current_problem") else {}
		var operation := str(problem.get("operation", "+"))
		var visible_operation := "×" if operation == "x" else ("÷" if operation == "/" else operation)
		return {"primary": "%d %s %d = ?" % [int(problem.get("left", 0)), visible_operation, int(problem.get("right", 0))], "detail": "SHIELDS %d - RESCUE %d/%d - SCORE %d" % [_scene_int(attached_scene, "lives", 3), _scene_int(attached_scene, "rescues", 0), _scene_int(attached_scene, "target_rescues", 0), _scene_int(attached_scene, "score", 0)]}
	match attached_game_id:
		"unicorn_jump":
			var data = attached_scene.get("level_data")
			var index := _scene_int(attached_scene, "current_index", 0)
			if data is Array and index < data.size():
				var value := int(data[index])
				return {"primary": "%s  %d" % ["JUMP FORWARD" if value >= 0 else "JUMP BACK", absi(value)], "detail": "COUNT EXACTLY %d STONES • TAP THE LANDING" % absi(value)}
			return {"primary": "TRAIL COMPLETE!", "detail": "You reached the rainbow finish."}
		"coin_count":
			return {"primary": "MAKE %s" % _format_cents(_scene_int(attached_scene, "target", 0)), "detail": "BUILD THE EXACT TOTAL WITH REAL US COINS"}
		"cash_counter":
			return {"primary": "MAKE $%d" % _scene_int(attached_scene, "target", 0), "detail": "BUILD THE EXACT TOTAL WITH REAL US BILLS"}
		"mathtris":
			return {"primary": "MAKE A TRUE EQUATION", "detail": "FIVE TILES ACROSS OR DOWN • SWIPE NEIGHBORS"}
		"galaxy_unicorn":
			return {"primary": "RAINBOW DEFENSE", "detail": "LEVEL %d • LIVES %d • %d/%d ENEMIES • SCORE %d" % [_scene_int(attached_scene, "level", 1), _scene_int(attached_scene, "lives", 3), _scene_int(attached_scene, "kills", 0), _scene_int(attached_scene, "target_kills", 0), _scene_int(attached_scene, "score", 0)]}
	var game := GameRegistry.get_game(attached_game_id)
	var title := str(game.get("title", "Mission")).to_upper()
	var lesson: Array[String] = TutorialCatalog.lessons(attached_game_id, _scene_int(attached_scene, "level", 1))
	return {"primary": title, "detail": lesson[0] if not lesson.is_empty() else "Complete the enchanted challenge."}


func _scene_int(scene: Node, property: String, fallback: int) -> int:
	if not _has_property(scene, property):
		return fallback
	return int(scene.get(property))


func _has_property(object: Object, property: String) -> bool:
	for definition in object.get_property_list():
		if str(definition.get("name", "")) == property:
			return true
	return false


func _format_cents(cents: int) -> String:
	return chrome_presenter.format_cents(cents)


func _update_coin_button(coins: int) -> void:
	chrome_presenter.update_coin_button(coin_button, coins)


func _update_ability_button() -> void:
	chrome_presenter.update_ability_button(ability_button, CompanionAbilityService.definition(), CompanionAbilityService.is_available())


func _ability_pressed() -> void:
	var definition := CompanionAbilityService.definition()
	if is_instance_valid(attached_controller) and CompanionAbilityService.is_available():
		if attached_controller.request_companion_action(CompanionAbilityService.companion_id()):
			CompanionAbilityService.consume_active_power()
			_update_ability_button()
			return
		if attached_game_id == "mathtris":
			_show_notice("Power charging", "Clear 3 true equations to charge your unicorn power.")
			return
	if CompanionAbilityService.companion_id() == "mystic" and CompanionAbilityService.is_available():
		_show_assist(true)
	else:
		_show_notice(str(definition.get("name", "Companion Power")), str(definition.get("description", "This power works automatically.")))


func _ordinary_hint_pressed() -> void:
	if not is_instance_valid(attached_controller):
		_show_notice("Hint", "Keep trying — look for the next safe choice.")
		return
	if not attached_controller.can_show_hint():
		_show_notice("Hint", "A hint is not available right now.")
		return
	var level := int(attached_controller.runtime_snapshot().get("level", 1))
	if not AppState.spend_hint(level):
		_show_notice("Hint", "You need 5 coins for another hint.")
		return
	attached_controller.request_hint()


func _hide_embedded_hint_controls(node: Node) -> void:
	chrome_presenter.hide_embedded_hint_controls(node)


func _configure_comet_chrome(scene: Node) -> void:
	chrome_presenter.configure_comet_chrome(scene, attached_game_id)


func _show_assist(mystic: bool) -> void:
	if not is_instance_valid(attached_scene):
		return
	if mystic and not _can_apply_mystic():
		_show_notice("Mystic Move", "No safe move is ready yet.")
		return
	if mystic and not CompanionAbilityService.consume_mystic_move():
		return
	match attached_game_id:
		"unicorn_jump":
			var data: Array = attached_scene.get("level_data")
			var index := _scene_int(attached_scene, "current_index", 0)
			if index < data.size():
				var expected := index + int(data[index])
				if mystic:
					attached_scene.call("_choose_node", expected)
				else:
					_highlight_jump_stone(expected)
		"mathtris":
			if attached_scene.has_method("_activate_mystic_ability"):
				attached_scene.call("_activate_mystic_ability")
		"cash_counter":
			var remaining := _scene_int(attached_scene, "target", 0) - _scene_int(attached_scene, "total", 0)
			for bill in [100, 50, 20, 10, 5, 1]:
				if bill <= remaining:
					attached_scene.call("_add_bill", bill)
					break
		"coin_count":
			var remaining := _scene_int(attached_scene, "target", 0) - _scene_int(attached_scene, "total", 0)
			for coin in [25, 10, 5, 1]:
				if coin <= remaining:
					attached_scene.call("_add_coin", coin)
					break
		"galaxy_unicorn":
			if attached_scene.has_method("_mystic_blast"):
				attached_scene.call("_mystic_blast")
		"comet_math_rescue":
			if attached_scene.has_method("_mystic_rescue"):
				attached_scene.call("_mystic_rescue")
		_:
			CompanionAbilityService.arm_assist_hint()
			if attached_scene.has_method("_show_hint"):
				attached_scene.call("_show_hint")
	_update_ability_button()


func _can_apply_mystic() -> bool:
	return attached_game_id in ["unicorn_jump", "mathtris", "cash_counter", "coin_count", "galaxy_unicorn", "comet_math_rescue"] or attached_scene.has_method("_show_hint")


func _is_retry_failure() -> bool:
	if is_instance_valid(attached_controller):
		return int(attached_controller.runtime_snapshot().get("outcome", LevelRunController.Outcome.IDLE)) == LevelRunController.Outcome.FAILURE
	if not is_instance_valid(attached_scene):
		return false
	if attached_scene.has_method("can_retry_failure"):
		return bool(attached_scene.call("can_retry_failure"))
	if _has_property(attached_scene, "action_button"):
		var action = attached_scene.get("action_button")
		if action is Button:
			var copy := str((action as Button).text).to_upper()
			return "RETRY" in copy or "PLAY AGAIN" in copy
	if _has_property(attached_scene, "retry_button"):
		var retry = attached_scene.get("retry_button")
		if retry is Button:
			return "RETRY" in str((retry as Button).text).to_upper()
	return false


func _outcome_action_button() -> Button:
	if is_instance_valid(attached_controller):
		return null
	if not is_instance_valid(attached_scene):
		return null
	for property in ["action_button", "retry_button"]:
		if _has_property(attached_scene, property):
			var candidate = attached_scene.get(property)
			if candidate is Button and is_instance_valid(candidate):
				return candidate
	for button in attached_scene.find_children("*", "Button", true, false):
		var copy := str((button as Button).text).to_upper()
		if "RETRY" in copy or "NEXT" in copy or "PLAY AGAIN" in copy:
			return button as Button
	return null


func _outcome_message() -> String:
	if is_instance_valid(attached_controller):
		return str(attached_controller.runtime_snapshot().get("outcome_message", "Your next adventure is ready."))
	for property in ["message_label", "status_label"]:
		if _has_property(attached_scene, property):
			var label = attached_scene.get(property)
			if label is Label and not str((label as Label).text).is_empty():
				return (label as Label).text
	return "Your next adventure is ready."


func _show_game_outcome() -> void:
	if not is_instance_valid(attached_scene) or is_instance_valid(outcome_overlay) or is_instance_valid(sparkle_retry_overlay) or _scene_has_dialog("GameOutcomeOverlay") or _scene_has_dialog("SecondSparkleRetryOverlay"):
		return
	var controller := attached_controller if is_instance_valid(attached_controller) else null
	var snapshot := controller.runtime_snapshot() if is_instance_valid(controller) else {}
	var legacy := _outcome_action_button() if not is_instance_valid(controller) else null
	var retry := int(snapshot.get("outcome", LevelRunController.Outcome.IDLE)) == LevelRunController.Outcome.FAILURE if is_instance_valid(controller) else _is_retry_failure()
	if is_instance_valid(controller):
		controller.conceal_progression_action()
	elif is_instance_valid(legacy):
		legacy.hide()
	var presentation := outcome_presenter.build_game_outcome(attached_scene as Control, retry, str(snapshot.get("outcome_message", "")) if is_instance_valid(controller) else _outcome_message(), attached_game_id == "mathtris")
	var overlay := presentation["overlay"] as Control
	outcome_overlay = overlay
	var primary := presentation["primary"] as Button
	primary.pressed.connect(func() -> void:
		if is_instance_valid(controller):
			controller.trigger_progression_action()
		elif is_instance_valid(legacy):
			legacy.pressed.emit()
		if is_instance_valid(overlay):
			overlay.queue_free()
	)
	var category := presentation["category"] as Button
	category.pressed.connect(func() -> void:
		if is_instance_valid(overlay):
			overlay.queue_free()
		_leave_game(false)
	)
	overlay.tree_exited.connect(func() -> void:
		if outcome_overlay == overlay:
			outcome_overlay = null
	)


func _show_sparkle_retry_notice(failure_reason: String) -> void:
	if not is_instance_valid(attached_scene) or is_instance_valid(sparkle_retry_overlay) or is_instance_valid(outcome_overlay) or _scene_has_dialog("SecondSparkleRetryOverlay"):
		return
	var controller := attached_controller if is_instance_valid(attached_controller) else null
	var legacy := _outcome_action_button() if not is_instance_valid(controller) else null
	if is_instance_valid(controller):
		controller.conceal_progression_action()
	elif is_instance_valid(legacy):
		legacy.hide()
	var presentation := outcome_presenter.build_sparkle_retry(attached_scene as Control, failure_reason)
	var overlay := presentation["overlay"] as Control
	sparkle_retry_overlay = overlay
	var continue_button := presentation["continue_button"] as Button
	continue_button.pressed.connect(func() -> void:
		if is_instance_valid(overlay):
			overlay.queue_free()
		_restart_after_sparkle()
	)
	overlay.tree_exited.connect(func() -> void:
		if sparkle_retry_overlay == overlay:
			sparkle_retry_overlay = null
	)


func _restart_after_sparkle() -> void:
	if not is_instance_valid(attached_scene):
		return
	if is_instance_valid(attached_controller):
		attached_controller.request_retry()
	elif attached_scene.has_method("retry_failure"):
		attached_scene.call("retry_failure")
	else:
		match attached_game_id:
			"cash_counter", "coin_count": attached_scene.call("_start_round")
			"mathtris": attached_scene.call("_start_game")
			"rhyme_rally": attached_scene.call("_start_level")
			"galaxy_unicorn", "comet_math_rescue", "math_swipe", "sliding_window": attached_scene.call("_start_level", _scene_int(attached_scene, "level", 1))
			_:
				if attached_scene.has_method("_start_level"):
					attached_scene.call("_start_level")
	if _has_property(attached_scene, "message_label"):
		var message = attached_scene.get("message_label")
		if message is Label:
			(message as Label).text = "Second Sparkle restored this level — your retry was free!"
	was_active = true
	_update_ability_button()


func _highlight_jump_stone(index: int) -> void:
	var buttons = attached_scene.get("node_buttons")
	if buttons is Array and index >= 0 and index < buttons.size():
		var button: CanvasItem = buttons[index]
		var tween := button.create_tween()
		tween.set_loops(3)
		tween.tween_property(button, "modulate", Color("fff176"), 0.28)
		tween.tween_property(button, "modulate", Color.WHITE, 0.28)


func _request_leave(home: bool) -> void:
	if not is_instance_valid(attached_scene):
		return
	var active := bool(attached_controller.runtime_snapshot().get("active", false)) if is_instance_valid(attached_controller) else (_has_property(attached_scene, "active") and bool(attached_scene.get("active")))
	if active:
		_show_leave_run_modal(home)
	else:
		_leave_game(home)


func _show_leave_run_modal(home: bool) -> void:
	if not is_instance_valid(attached_scene) or _scene_has_dialog("LeaveRunOverlay"):
		return
	var overlay := _modal_backdrop("LeaveRunOverlay")
	attached_scene.add_child(overlay)
	var card := _modal_card(overlay, 0.10, 0.90, 0.30, 0.70)
	card.name = "LeaveRunCard"
	var stack := VBoxContainer.new()
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	stack.add_theme_constant_override("separation", 16)
	card.add_child(stack)
	var badge := Label.new()
	badge.text = "STORYBOOK PAUSE"
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	StorybookUI.apply_story_label(badge, Color("c45186"), 18, false)
	stack.add_child(badge)
	stack.add_child(_modal_title("LEAVE THIS RUN?"))
	var copy := Label.new()
	copy.name = "LeaveRunCopy"
	copy.text = "Your current level will be abandoned. You can begin a fresh run anytime."
	copy.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	copy.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	copy.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	copy.custom_minimum_size.y = 86
	StorybookUI.apply_story_label(copy, StorybookUI.INK, 23, false)
	stack.add_child(copy)
	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 12)
	stack.add_child(actions)
	var leave := Button.new()
	leave.name = "LeaveRunConfirm"
	leave.text = "LEAVE RUN"
	StorybookUI.apply_game_action(leave, 180)
	leave.pressed.connect(_leave_game.bind(home))
	actions.add_child(leave)
	var keep_playing := Button.new()
	keep_playing.name = "LeaveRunCancel"
	keep_playing.text = "KEEP PLAYING"
	StorybookUI.apply_game_action(keep_playing, 190)
	keep_playing.pressed.connect(overlay.queue_free)
	actions.add_child(keep_playing)


func _leave_game(home: bool) -> void:
	AppState.set_shell_destination("home" if home else "category", "" if home else AppState.selected_category)
	get_tree().change_scene_to_file("res://scenes/main.tscn")


func _show_profile_overlay() -> void:
	if not is_instance_valid(attached_scene) or attached_scene.has_node("InGameProfileOverlay"):
		return
	var overlay := _modal_backdrop("InGameProfileOverlay")
	attached_scene.add_child(overlay)
	var card := _modal_card(overlay, 0.06, 0.94, 0.06, 0.94)
	var scroll := ScrollContainer.new()
	card.add_child(scroll)
	var stack := VBoxContainer.new()
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.add_theme_constant_override("separation", 12)
	scroll.add_child(stack)
	stack.add_child(_modal_title("PLAYER PROFILE"))
	var companion := MetaCatalog.companion(AppState.equipped_companion())
	var preview := _companion_thumbnail(AppState.equipped_companion(), Vector2(160, 140))
	stack.add_child(preview)
	var hero := Label.new()
	hero.text = "%s\n%s  •  %d COINS  •  %d RUNS" % [AppState.player_name().to_upper(), str(companion.get("name", "Sparkle")).to_upper(), AppState.coins(), AppState.completed_run_count()]
	hero.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hero.add_theme_font_size_override("font_size", 20)
	hero.add_theme_color_override("font_color", StorybookUI.INK)
	stack.add_child(hero)
	var ability := CompanionAbilityService.definition()
	var ability_card := Label.new()
	ability_card.text = "✦ %s — %s" % [ability.get("name", "Companion Power"), ability.get("description", "")]
	ability_card.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ability_card.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ability_card.add_theme_font_size_override("font_size", 18)
	ability_card.add_theme_color_override("font_color", Color("59375c"))
	stack.add_child(ability_card)
	var rings := HBoxContainer.new()
	rings.alignment = BoxContainer.ALIGNMENT_CENTER
	rings.add_theme_constant_override("separation", 6)
	stack.add_child(rings)
	for category in ["Number", "Word", "Mystery", "Arcade"]:
		var completed := 0
		var level_sum := 0.0
		var games := GameRegistry.games_in_category(category)
		for game in games:
			completed += AppState.progress_for_game(game["id"]).get("completed", []).size()
			level_sum += clampf(float(AppState.current_level(game["id"]) - 1) / 20.0, 0.0, 1.0)
		var ratio := 0.0 if games.is_empty() else level_sum / float(games.size())
		var ring := ProgressRingScene.new()
		ring.setup(ratio, category.to_upper(), "%d RUNS" % completed, Color("58d6e8") if category == "Number" else (Color("f26fa7") if category == "Word" else (Color("9b7bff") if category == "Mystery" else Color("ffd166"))))
		rings.add_child(ring)
	var tutorial_toggle := CheckButton.new()
	tutorial_toggle.text = "GUIDED FIRST LEVEL"
	tutorial_toggle.button_pressed = bool(AppState.setting("tutorials_enabled", true))
	tutorial_toggle.custom_minimum_size.y = 56
	tutorial_toggle.add_theme_font_size_override("font_size", 19)
	tutorial_toggle.toggled.connect(func(value: bool) -> void: AppState.set_setting("tutorials_enabled", value))
	stack.add_child(tutorial_toggle)
	var close := Button.new()
	close.text = "RESUME GAME"
	StorybookUI.apply_game_action(close, 220)
	close.pressed.connect(overlay.queue_free)
	stack.add_child(close)


func _maybe_show_tutorial(force_replay: bool) -> void:
	if attached_game_id.is_empty() or not is_instance_valid(attached_scene) or _scene_has_dialog("GuidedTutorialOverlay"):
		return
	var raw_level := _scene_int(attached_scene, "level", 1)
	var tutorial_level := clampi(raw_level, 1, 3)
	if not force_replay:
		if not bool(AppState.setting("tutorials_enabled", true)) or raw_level != 1 or AppState.tutorial_complete(attached_game_id, tutorial_level):
			return
	var lessons: Array[String] = TutorialCatalog.lessons(attached_game_id, tutorial_level)
	var dialog := _create_game_dialog("GuidedTutorialOverlay", 0.07, 0.93, 0.20, 0.80)
	var overlay := dialog["owner"] as Control
	var card := dialog["card"] as PanelContainer
	overlay.set_meta("lessons", lessons)
	overlay.set_meta("step", 0)
	overlay.set_meta("game_id", attached_game_id)
	overlay.set_meta("tutorial_level", tutorial_level)
	tutorial_presenter.build(card, overlay, tutorial_level, lessons, _advance_tutorial)


func _advance_tutorial(overlay: Control) -> void:
	if tutorial_presenter.advance(overlay):
		AppState.mark_tutorial_complete(str(overlay.get_meta("game_id")), int(overlay.get_meta("tutorial_level")))
		overlay.queue_free()


func _show_notice(title: String, copy: String) -> void:
	if not is_instance_valid(attached_scene) or _scene_has_dialog("CompanionAbilityNotice"):
		return
	var dialog := _create_game_dialog("CompanionAbilityNotice", 0.10, 0.90, 0.30, 0.70)
	var overlay := dialog["owner"] as Control
	var card := dialog["card"] as PanelContainer
	card.name = "AbilityNoticeCard"
	var stack := VBoxContainer.new()
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	stack.add_theme_constant_override("separation", 20)
	card.add_child(stack)
	var badge := Label.new()
	badge.text = "UNICORN MAGIC"
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	StorybookUI.apply_story_label(badge, Color("c45186"), 18, false)
	stack.add_child(badge)
	stack.add_child(_modal_title(title.to_upper()))
	var message := Label.new()
	message.name = "AbilityNoticeCopy"
	message.text = copy
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message.size_flags_vertical = Control.SIZE_EXPAND_FILL
	message.custom_minimum_size.y = 100
	StorybookUI.apply_story_label(message, StorybookUI.INK, 25, false)
	stack.add_child(message)
	var close := Button.new()
	close.name = "AbilityNoticeClose"
	close.text = "GOT IT!"
	StorybookUI.apply_game_action(close, 220)
	close.pressed.connect(overlay.queue_free)
	stack.add_child(close)


func _scene_has_dialog(node_name: String) -> bool:
	return is_instance_valid(attached_scene) and attached_scene.find_child(node_name, true, false) != null


func _create_game_dialog(node_name: String, left: float, right: float, top: float, bottom: float) -> Dictionary:
	if attached_scene.has_method("_insert_non_obstructing_dialog"):
		var owner := MarginContainer.new()
		owner.name = node_name
		if is_instance_valid(attached_controller):
			attached_controller.pause_for_dialog(owner)
		owner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		owner.add_theme_constant_override("margin_left", 4)
		owner.add_theme_constant_override("margin_right", 4)
		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel", StorybookUI.plaque_style(Color("fff3d6"), StorybookUI.GOLD, 24))
		owner.add_child(card)
		attached_scene.call("_insert_non_obstructing_dialog", owner)
		return {"owner": owner, "card": card}
	var overlay := _modal_backdrop(node_name)
	attached_scene.add_child(overlay)
	return {"owner": overlay, "card": _modal_card(overlay, left, right, top, bottom)}


func _modal_backdrop(node_name: String) -> ColorRect:
	var overlay := ColorRect.new()
	overlay.name = node_name
	if is_instance_valid(attached_controller):
		attached_controller.pause_for_dialog(overlay)
	overlay.color = Color(0.02, 0.03, 0.10, 0.82)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.z_index = 1000
	return overlay


func _modal_card(parent: Control, left: float, right: float, top: float, bottom: float) -> PanelContainer:
	var card := PanelContainer.new()
	card.anchor_left = left
	card.anchor_right = right
	card.anchor_top = top
	card.anchor_bottom = bottom
	card.add_theme_stylebox_override("panel", StorybookUI.plaque_style(Color("fff3d6"), StorybookUI.GOLD, 24))
	parent.add_child(card)
	return card


func _modal_title(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 27)
	label.add_theme_color_override("font_color", Color("9c356d"))
	return label


func _restyle_controls(node: Node) -> void:
	chrome_presenter.restyle_controls(node)


func _polish_game_labels(node: Node) -> void:
	chrome_presenter.polish_game_labels(node)


func _hide_game_scrollbars(node: Node) -> void:
	chrome_presenter.hide_game_scrollbars(node)
