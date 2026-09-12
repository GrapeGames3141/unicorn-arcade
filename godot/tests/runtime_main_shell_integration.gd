extends Node

const MAIN_SCENE = preload("res://scenes/main.tscn")
const LoginView = preload("res://scripts/ui/login_view.gd")
const GameCatalogView = preload("res://scripts/ui/game_catalog_view.gd")

var failures: Array[String] = []
var check_count := 0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var pre_test_data := AppState.data.duplicate(true)
	var original_game := AppState.selected_game_id
	var original_category := AppState.selected_category
	var test_session_started := SaveService.begin_test_session()
	var test_profile := SaveService.create_profile("Main Shell Integration")
	if not test_session_started or test_profile.is_empty() or not SaveService.has_active_profile():
		push_error("main shell integration could not create its isolated active save profile")
		SaveService.end_test_session()
		get_tree().quit(1)
		return
	AppState.data = test_profile
	AppState.data["owned_companions"] = ["sparkle", "rainbow", "star", "cloud", "dream", "mystic"]
	AppState.data["player"]["equipped_companion"] = "mystic"
	AppState.shell_view = "home"
	var shell := MAIN_SCENE.instantiate()
	add_child(shell)
	await shell.page_build_complete
	await get_tree().process_frame
	await _wait_for_meadow_models(shell)
	_check(shell.get_child_count() >= 2, "navigation shell builds its full-screen page")
	_check(_ui_is_accessible(shell), "navigation shell meets readable text, contrast, and touch-target minimums")
	var meadow_stage := shell.find_child("MeadowCompanionStage3D", true, false)
	var meadow_stage_id := meadow_stage.get_instance_id() if is_instance_valid(meadow_stage) else 0
	var shared_viewports := []
	var shared_cameras := []
	var shared_lights := []
	var travel_roots := []
	var live_models := []
	var animators := []
	if is_instance_valid(meadow_stage):
		shared_viewports = meadow_stage.find_children("*", "SubViewport", true, false)
		shared_cameras = meadow_stage.find_children("*", "Camera3D", true, false)
		shared_lights = meadow_stage.find_children("*", "Light3D", true, false)
		travel_roots = meadow_stage.find_children("MeadowTravelRoot_*", "Node3D", true, false)
		live_models = meadow_stage.find_children("LiveUnicornModel_*", "Node3D", true, false)
		animators = meadow_stage.find_children("*", "UnicornIdleAnimator", true, false)
	var meadow_ids: Dictionary = {}
	var meadow_behaviors: Dictionary = {}
	var hero_root: Node3D = null
	for root in travel_roots:
		meadow_ids[str(root.get_meta("source_model_id", ""))] = true
		meadow_behaviors[str(root.get_meta("roam_behavior_signature", ""))] = true
		if bool(root.get_meta("hero", false)):
			hero_root = root
	_check(is_instance_valid(meadow_stage) and shared_viewports.size() == 1 and shared_cameras.size() == 1 and shared_lights.size() >= 2, "home meadow uses one shared SubViewport with one camera and shared lights")
	_check(travel_roots.size() == 6 and live_models.size() == 6 and animators.size() == 6 and meadow_ids.size() == 6, "home meadow keeps six distinct live GLBs with travel roots and Walk animators")
	_check(meadow_behaviors.size() == 6, "each meadow unicorn receives a unique stable roaming behavior signature")
	if not animators.is_empty():
		var sampled = animators[0]
		sampled.play_random_animation_now()
		_check(sampled.roam_2d and is_equal_approx(sampled.last_destination.y, sampled.home_position.y) and not is_equal_approx(sampled.last_destination.x, sampled.home_position.x), "meadow roaming samples a two-dimensional destination while preserving the home floor height")
	var mid_count := 0
	var rear_count := 0
	var background_z: Array[float] = []
	for root in travel_roots:
		if str(root.get_meta("formation_row", "")) == "mid": mid_count += 1
		if str(root.get_meta("formation_row", "")) == "rear": rear_count += 1
		if not bool(root.get_meta("hero", false)): background_z.append(root.position.z)
	background_z.sort()
	var lateral_safe := background_z.size() == 5
	for index in range(1, background_z.size()): lateral_safe = lateral_safe and background_z[index] - background_z[index - 1] >= 2.4
	_check(is_instance_valid(hero_root) and is_equal_approx(hero_root.position.x, -5.8) and is_equal_approx(hero_root.position.y, -2.6) and is_equal_approx(hero_root.position.z, 0.95) and is_equal_approx(hero_root.get_child(0).scale.x, 4.256) and mid_count == 2 and rear_count == 3 and lateral_safe, "equipped hero occupies the lower, enlarged camera-front placement while the two-mid/three-rear meadow formation stays separated")
	var centered_slot := shell.find_child("TrueCenterHeaderSlot", true, false) as Control
	var home_sign := shell.find_child("HomeTitleSign", true, false) as TextureRect
	var alley_sign_button := shell.find_child("UnicornAlleyStreetSignButton", true, false) as Button
	var welcome_text := shell.find_child("HomeWelcomeText", true, false) as Label
	var companion_summary := shell.find_child("HomeCompanionSummary", true, false) as Label
	var coin_balance := shell.find_child("CoinBalanceLabel", true, false) as Label
	var expected_center: float = shell.global_position.x + shell.size.x * 0.5
	var actual_center: float = centered_slot.global_position.x + centered_slot.size.x * 0.5 if is_instance_valid(centered_slot) else -1.0
	_check(is_instance_valid(centered_slot) and absf(actual_center - expected_center) <= 1.0, "navigation headers center titles on the physical screen independently of side controls")
	_check(is_instance_valid(home_sign) and home_sign.texture.resource_path.ends_with("title_sign_option3_compact_v1.png"), "home meadow uses the approved illustrated Unicorn Arcade sign")
	_check(is_instance_valid(alley_sign_button) and alley_sign_button.has_node("StreetSignArt") and alley_sign_button.text == "UNICORN ALLEY" and alley_sign_button.tooltip_text.is_empty(), "home uses an accessible illustrated Unicorn Alley street-sign action without a stray mobile tooltip")
	_check(is_instance_valid(welcome_text) and welcome_text.get_theme_font_size("font_size") >= 22 and welcome_text.get_theme_color("font_color") == StorybookUI.INK, "home welcome text is larger and dark enough to read against the meadow sky")
	_check(is_instance_valid(companion_summary) and companion_summary.get_theme_font_size("font_size") >= 21 and companion_summary.get_theme_color("font_color").get_luminance() < 0.30, "home companion summary is larger and uses high-contrast dark teal text")
	_check(is_instance_valid(coin_balance) and coin_balance.get_theme_font_size("font_size") >= 24 and coin_balance.get_theme_constant("outline_size") >= 3, "top star balance uses a larger outlined symbol and number")
	var profile_button := shell.find_child("ProfileButton", true, false) as Button
	var profile_button_found := is_instance_valid(profile_button)
	if profile_button_found:
		profile_button.emit_signal("pressed")
	await shell.profile_build_complete
	await get_tree().process_frame
	var profile_content := shell.find_child("ProfileContent", true, false)
	var profile_grid := shell.find_child("ProfileGameGrid", true, false)
	_check(profile_button_found and is_instance_valid(profile_content) and is_instance_valid(profile_grid) and profile_grid.get_child_count() == GameRegistry.all_games().size(), "profile button opens responsively and finishes its complete game history grid")
	_check(shell.find_child("ProfileLoading", true, false) == null, "profile loading state clears after incremental construction")
	_check(shell.find_child("MeadowCompanionStage3D", true, false) == null and shell.find_child("MeadowCompanionDisplay", true, false) == null, "profile retires the Home meadow renderer and display")
	var dashboard_build_signals: Array[bool] = []
	var dashboard_build_counter := func() -> void: dashboard_build_signals.append(true)
	shell.page_build_complete.connect(dashboard_build_counter)
	shell.call("_show_dashboard")
	await shell.page_build_complete
	await get_tree().process_frame
	shell.page_build_complete.disconnect(dashboard_build_counter)
	var dashboard_catalog := shell.find_child("GameCatalogView", true, false) as GameCatalogView
	var word_category := shell.find_child("CategoryCard_Word", true, false) as Button
	_check(is_instance_valid(dashboard_catalog) and dashboard_catalog.get_parent() == shell.page and dashboard_build_signals.size() == 1 and is_instance_valid(word_category) and shell.find_children("CategoryIcon", "ArcadePictogram", true, false).size() == 4, "GameCatalogView directly owns the dashboard and builds exactly once")
	_check(_ui_is_accessible(shell), "icon category dashboard meets readable text, contrast, and touch-target minimums")
	var category_build_signals: Array[bool] = []
	var category_build_counter := func() -> void: category_build_signals.append(true)
	shell.page_build_complete.connect(category_build_counter)
	if is_instance_valid(word_category):
		word_category.emit_signal("pressed")
	else:
		shell.call("_show_category", "Word")
	await shell.page_build_complete
	await get_tree().process_frame
	shell.page_build_complete.disconnect(category_build_counter)
	var category_catalog := shell.find_child("GameCatalogView", true, false) as GameCatalogView
	var category_content := shell.find_child("CategoryContent", true, false) as VBoxContainer
	var category_grid := shell.find_child("CategoryGameGrid", true, false) as GridContainer
	var category_scroll := shell.find_child("CategoryContentScroll", true, false) as ScrollContainer
	var word_icons := shell.find_children("GameIcon", "ArcadePictogram", true, false)
	var word_icon_ids: Dictionary = {}
	for word_icon in word_icons:
		word_icon_ids[word_icon.icon_id] = true
	_check(is_instance_valid(category_catalog) and category_catalog.get_parent() == shell.page and category_build_signals.size() == 1 and is_instance_valid(category_scroll) and category_scroll.horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED and category_scroll.vertical_scroll_mode == ScrollContainer.SCROLL_MODE_AUTO and not category_scroll.follow_focus and category_scroll.scroll_deadzone == 8 and category_scroll.get_child_count() > 0 and category_scroll.get_child(0) == category_content and is_instance_valid(category_grid) and word_icons.size() == 10 and word_icon_ids.size() == 10, "Word category button mounts compatible GameCatalogView scroll content with ten distinct pictograms")
	_check(_ui_is_accessible(shell), "icon game grid meets readable text, contrast, and touch-target minimums")
	shell.call("_show_home")
	await shell.page_build_complete
	await get_tree().process_frame
	var returned_meadow := shell.find_child("MeadowCompanionStage3D", true, false) as MeadowCompanionStage3D
	await _wait_for_meadow_models(shell)
	_check(is_instance_valid(returned_meadow) and returned_meadow.get_instance_id() != meadow_stage_id and returned_meadow.viewport.render_target_update_mode == SubViewport.UPDATE_ALWAYS and shell.find_child("MeadowCompanionDisplay", true, false) != null and returned_meadow.find_children("LiveUnicornModel_*", "Node3D", true, false).size() == 6 and returned_meadow.find_children("*", "UnicornIdleAnimator", true, false).size() == 6 and returned_meadow.find_children("*", "SubViewport", true, false).size() == 1, "returning home builds a fresh active six-unicorn renderer and display")
	await _release_shell(shell)
	AppState.data["player"]["name"] = ""
	var login_shell := MAIN_SCENE.instantiate()
	var login_page_build_signals: Array[bool] = []
	login_shell.page_build_complete.connect(func() -> void: login_page_build_signals.append(true))
	add_child(login_shell)
	await login_shell.page_build_complete
	await get_tree().process_frame
	var login_view := login_shell.find_child("LoginView", true, false) as LoginView
	var login_prompt := login_shell.find_child("PlayerNamePrompt", true, false) as Label
	var login_input := login_shell.find_child("PlayerNameInput", true, false) as LineEdit
	var login_enter := login_shell.find_child("LoginEnterButton", true, false) as Button
	_check(is_instance_valid(login_view) and is_instance_valid(login_view.get_parent()) and login_view.get_parent() == login_shell.page and is_instance_valid(login_prompt) and is_instance_valid(login_input) and not login_input.has_focus(), "LoginView owns the unfocused first-launch name form")
	_check(is_instance_valid(login_prompt) and is_instance_valid(login_input) and login_prompt.get_index() < login_input.get_index(), "the player-name instruction remains directly above its text field")
	_check(is_instance_valid(login_enter) and login_enter.disabled and login_page_build_signals.size() == 1, "login enter waits for nonblank input and builds exactly once")
	if is_instance_valid(login_input) and is_instance_valid(login_enter):
		login_input.text = "New Login Tester"
		login_input.emit_signal("text_changed", login_input.text)
		_check(not login_enter.disabled, "nonblank login input enables enter")
		login_enter.emit_signal("pressed")
		await login_shell.page_build_complete
		await get_tree().process_frame
	_check(AppState.player_name() == "New Login Tester" and AppState.shell_view == "home" and AdBarService.should_show_for_player_logged_in(AppState.player_name()), "new-name login reaches home with logged-in ad eligibility")
	await _release_shell(login_shell)
	AppState.data = pre_test_data
	AppState.selected_game_id = original_game
	AppState.selected_category = original_category
	SaveService.end_test_session()
	if failures.is_empty():
		print("GODOT_RUNTIME_MAIN_SHELL_INTEGRATION_OK: %d checks passed" % check_count)
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error(failure)
		get_tree().quit(1)


func _wait_for_meadow_models(shell: Node) -> void:
	var deadline := Time.get_ticks_msec() + 10000
	while Time.get_ticks_msec() < deadline:
		var meadow := shell.find_child("MeadowCompanionStage3D", true, false)
		if meadow != null and meadow.find_children("LiveUnicornModel_*", "Node3D", true, false).size() == 6:
			return
		await get_tree().create_timer(0.01).timeout
	_check(false, "six meadow models complete their asynchronous loads")


func _release_shell(shell: Node) -> void:
	if not is_instance_valid(shell):
		return
	var ready: Variant = shell.call("prepare_for_scene_change")
	if ready is Signal:
		await ready
	shell.queue_free()
	for _frame in 3:
		await get_tree().process_frame


func _check(condition: bool, message: String) -> void:
	check_count += 1
	if not condition:
		failures.append(message)


func _ui_is_accessible(root: Node) -> bool:
	var issues: Array[String] = []
	_collect_ui_issues(root, issues)
	if not issues.is_empty():
		push_warning("UI accessibility issues: %s" % "; ".join(issues.slice(0, 8)))
	return issues.is_empty()


func _collect_ui_issues(node: Node, issues: Array[String]) -> void:
	if node is Control and (node as Control).is_visible_in_tree():
		var control := node as Control
		if control is Label and not (control as Label).text.strip_edges().is_empty():
			if control.get_theme_font_size("font_size") < 19:
				issues.append("small label %s" % control.name)
			if control.get_theme_constant("outline_size") < 2:
				issues.append("low-contrast label %s" % control.name)
		if control is BaseButton:
			if control.custom_minimum_size.y < 56.0 and not control.has_meta("compact_header_control"):
				issues.append("short touch target %s" % control.name)
			if control.get_theme_font_size("font_size") < 18:
				issues.append("small button text %s" % control.name)
		if control is LineEdit or control is TextEdit:
			if control.custom_minimum_size.y < 56.0 or control.get_theme_font_size("font_size") < 19:
				issues.append("small text input %s" % control.name)
	for child in node.get_children():
		_collect_ui_issues(child, issues)
