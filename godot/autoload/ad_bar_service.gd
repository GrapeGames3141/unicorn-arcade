extends Node

## Bottom banner via Poing AdMob (Android). Config: res://config/admob.json (see admob.example.json).
## Games render into a persistent content viewport that sits above a separate ad slot.

const CONFIG_PATH := "res://config/admob.json"
const EXAMPLE_PATH := "res://config/admob.example.json"
const ChildAdsPolicy := preload("res://scripts/platform/child_ads_policy.gd")
const GOOGLE_TEST_BANNER_UNIT_ID := "ca-app-pub-3940256099942544/6300978111"
const CONTENT_TO_BANNER_GUTTER_LOGICAL_PIXELS := 24
const BANNER_REQUEST_STALE_MS := 8000
const SDK_INITIALIZATION_TIMEOUT_MS := 10000
const SDK_INITIALIZATION_RETRY_MS := 30000
var _config: Dictionary = {}
var _ad_view: AdView
var _sdk_initialized := false
var _sdk_initializing := false
var _sdk_init_started_ms := -1
var _sdk_last_attempt_ms := -1
var _sdk_init_generation := 0
var _banner_logical_height := 60.0
var _banner_requested := false
var _banner_loaded := false
var _banner_request_started_ms := 0
var _banner_restore_queued := false
var _reservation_active := false
var _app_layout: VBoxContainer
var _game_render_area: SubViewportContainer
var _app_content_viewport: SubViewport
var _ad_bar_area: Control
var _hosted_scene: Node
var _layout_sync_queued := false
var _shutting_down := false


func _ready() -> void:
	_reload_config()
	_connect_scene_tracking()
	call_deferred("_ensure_app_layout")
	call_deferred("_host_current_scene")
	if _platform_supports_ads() and ads_enabled():
		_initialize_mobile_ads()


func _exit_tree() -> void:
	# The root is already tearing down here.  `detach()` normally updates the
	# reservation, which would try to rebuild AppViewportLayout while root child
	# removal is in progress and can recurse through failed add_child calls.
	_shutting_down = true
	_invalidate_sdk_initialization()
	_banner_requested = false
	_reservation_active = false
	_layout_sync_queued = false
	_destroy_banner()
	_app_layout = null
	_game_render_area = null
	_app_content_viewport = null
	_ad_bar_area = null
	_hosted_scene = null


func _process(_delta: float) -> void:
	_expire_sdk_initialization()


func _reload_config() -> void:
	if FileAccess.file_exists(CONFIG_PATH):
		_config = _parse_json_file(CONFIG_PATH)
	elif OS.is_debug_build() and FileAccess.file_exists(EXAMPLE_PATH):
		# admob.json is deliberately gitignored. A debug APK must still exercise
		# the native-banner layout on a fresh checkout, but only with Google's
		# official test unit and never on the login/startup screen.
		_config = _parse_json_file(EXAMPLE_PATH)
		_config["ads_enabled"] = true
		_config["android_banner_unit_id"] = GOOGLE_TEST_BANNER_UNIT_ID
		_config["show_on_login"] = false
	else:
		_config = {}
	_banner_logical_height = float(_config.get("banner_height_dp", 60.0))


func _parse_json_file(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	return parsed if parsed is Dictionary else {}


func config() -> Dictionary:
	return _config


func ads_enabled() -> bool:
	return bool(_config.get("ads_enabled", false)) and ChildAdsPolicy.permits_ads(_config)


func banner_height() -> float:
	if not _should_show_ads():
		return 0.0
	# The native anchored banner owns Android's navigation/safe-area placement.
	# Reserving that inset here as well leaves an extra blank strip above it.
	return _banner_logical_height


func should_show_for_player_logged_in(player_name: String) -> bool:
	if player_name.strip_edges().is_empty():
		return bool(_config.get("show_on_login", false))
	return true


## Prefer this from any scene. `host` is optional (kept for call-site compatibility).
func attach_to(_host: Control = null, player_name: String = "") -> void:
	sync_for_player(player_name)


func sync_for_player(player_name: String = "") -> void:
	if not should_show_for_player_logged_in(player_name) or not _should_show_ads():
		detach()
		return

	_set_reservation_active(true)
	if _sdk_initialized:
		_restore_banner_if_eligible()
	else:
		_initialize_mobile_ads()


func detach() -> void:
	_banner_requested = false
	_destroy_banner()
	_set_reservation_active(false)


func _should_show_ads() -> bool:
	return ads_enabled() and _platform_supports_ads()


func _platform_supports_ads() -> bool:
	var os_name := OS.get_name()
	return os_name == "Android" or os_name == "iOS"


func _banner_unit_id() -> String:
	return str(_config.get("android_banner_unit_id", "")).strip_edges()


func _initialize_mobile_ads(now_ms := -1) -> void:
	if now_ms < 0:
		now_ms = Time.get_ticks_msec()
	if _shutting_down:
		return
	if _sdk_initialized:
		_show_banner_if_attached()
		return
	if _sdk_initializing:
		_expire_sdk_initialization(now_ms)
	if _sdk_initializing or not _can_begin_sdk_initialization(now_ms):
		return
	_sdk_initializing = true
	_sdk_init_started_ms = now_ms
	_sdk_last_attempt_ms = now_ms
	_sdk_init_generation += 1
	var generation := _sdk_init_generation

	if not Engine.has_singleton("PoingGodotAdMob"):
		_sdk_initializing = false
		_sdk_init_started_ms = -1
		# Native plugin missing from APK/AAB (common when android/bin AARs were not exported).
		push_warning(
			"AdBarService: PoingGodotAdMob singleton missing — AdMob Android binaries were not packaged"
		)
		return

	if not ChildAdsPolicy.permits_ads(_config):
		_invalidate_sdk_initialization()
		push_warning("AdBarService: ads disabled because configuration conflicts with child-directed G policy")
		return

	var listener := OnInitializationCompleteListener.new()
	listener.on_initialization_complete = func(_status: InitializationStatus) -> void:
		_on_mobile_ads_initialized(generation)

	MobileAds.initialize(listener, ChildAdsPolicy.request_configuration())


func _can_begin_sdk_initialization(now_ms := -1) -> bool:
	if now_ms < 0:
		now_ms = Time.get_ticks_msec()
	return _sdk_last_attempt_ms < 0 or now_ms - _sdk_last_attempt_ms >= SDK_INITIALIZATION_RETRY_MS


func _expire_sdk_initialization(now_ms := -1) -> bool:
	if now_ms < 0:
		now_ms = Time.get_ticks_msec()
	if not _sdk_initializing or _sdk_init_started_ms < 0 or now_ms - _sdk_init_started_ms < SDK_INITIALIZATION_TIMEOUT_MS:
		return false
	_invalidate_sdk_initialization()
	push_warning("AdBarService: MobileAds initialization timed out; a later route or focus event may retry.")
	return true


func _invalidate_sdk_initialization() -> void:
	_sdk_init_generation += 1
	_sdk_initializing = false
	_sdk_init_started_ms = -1


func _on_mobile_ads_initialized(generation: int) -> bool:
	if _shutting_down or not _sdk_initializing or generation != _sdk_init_generation:
		return false
	_sdk_initializing = false
	_sdk_init_started_ms = -1
	_sdk_initialized = true
	print("AdBarService: MobileAds initialized")
	_show_banner_if_attached()
	return true


func _show_banner() -> void:
	if _shutting_down:
		return
	if _ad_view != null and _banner_loaded:
		_set_reservation_active(true)
		_ad_view.show()
		return
	if _ad_view != null:
		if not _banner_loaded and not _banner_request_is_stale():
			# A valid native AdView can spend several seconds loading. Keep that
			# request alive across a route/focus event instead of replacing it.
			return
		_destroy_banner()
	var unit_id := _banner_unit_id()
	if unit_id.is_empty():
		push_warning("AdBarService: android_banner_unit_id is missing in admob config")
		detach()
		return

	if not Engine.has_singleton("PoingGodotAdMobAdView"):
		detach()
		push_warning(
			"AdBarService: PoingGodotAdMobAdView missing — cannot show banner on this build"
		)
		return

	_destroy_banner()
	_banner_requested = true
	_banner_loaded = false
	_banner_request_started_ms = Time.get_ticks_msec()
	_set_reservation_active(true)

	var ad_size := AdSize.get_current_orientation_anchored_adaptive_banner_ad_size(AdSize.FULL_WIDTH)
	_ad_view = AdView.new(unit_id, ad_size, AdPosition.BOTTOM)

	var ad_listener := AdListener.new()
	ad_listener.on_ad_loaded = _on_banner_loaded
	ad_listener.on_ad_failed_to_load = func(error: LoadAdError) -> void:
		push_warning("AdBarService: banner failed: %s" % error.message)
		detach()

	_ad_view.ad_listener = ad_listener
	print("AdBarService: loading banner unit %s" % unit_id)
	_ad_view.load_ad(AdRequest.new())


func _on_banner_loaded() -> void:
	if _shutting_down or _ad_view == null:
		return
	# Loading creates the native view, but visibility is plugin/platform state.
	# Explicitly show it so a prior hidden or background-created banner cannot
	# remain invisible on Android.
	_ad_view.show()
	_banner_loaded = true
	_banner_request_started_ms = 0
	var px := float(_ad_view.get_height_in_pixels())
	if px > 0.0:
		_banner_logical_height = _pixels_to_viewport_y(px)
	_update_app_layout()
	print("AdBarService: banner loaded (height_px=%.0f)" % px)


func _show_banner_if_attached() -> void:
	if _shutting_down:
		return
	if (
		should_show_for_player_logged_in(AppState.player_name())
		and _should_show_ads()
	):
		_show_banner()


func _banner_needs_recovery() -> bool:
	return AdBannerRecoveryPolicy.needs_recovery(_ad_view != null, _banner_requested, _banner_loaded, _banner_request_started_ms, Time.get_ticks_msec(), BANNER_REQUEST_STALE_MS)


func _banner_request_is_stale(now_ms := -1) -> bool:
	# Sample a monotonic clock inside the function. Early startup can produce a
	# negative synthetic start time in tests, so elapsed arithmetic must not use
	# the start-time sign as a validity signal.
	if now_ms < 0:
		now_ms = Time.get_ticks_msec()
	return AdBannerRecoveryPolicy.is_stale(_banner_requested, _banner_loaded, _banner_request_started_ms, now_ms, BANNER_REQUEST_STALE_MS)


func _schedule_banner_restore() -> void:
	if _shutting_down or _banner_restore_queued:
		return
	if not _should_show_ads() or not should_show_for_player_logged_in(AppState.player_name()):
		return
	_banner_restore_queued = true
	call_deferred("_restore_banner_if_eligible")


func _restore_banner_if_eligible() -> void:
	_banner_restore_queued = false
	if _shutting_down or not _should_show_ads() or not should_show_for_player_logged_in(AppState.player_name()):
		return
	_set_reservation_active(true)
	if not _sdk_initialized:
		_initialize_mobile_ads()
		return
	if _ad_view != null and _banner_loaded:
		_ad_view.show()
		return
	if _ad_view != null and not _banner_request_is_stale():
		return
	# One recovery attempt per focus/route event. This recreates a native view
	# lost while backgrounded without a timer or recursive retry loop.
	if _banner_needs_recovery():
		_destroy_banner()
		_banner_requested = false
	_show_banner()


func _destroy_banner() -> void:
	if _ad_view != null:
		_ad_view.destroy()
	_ad_view = null
	_banner_loaded = false
	_banner_request_started_ms = 0


func _connect_scene_tracking() -> void:
	var tree := get_tree()
	if tree != null and not tree.scene_changed.is_connected(_on_scene_changed):
		tree.scene_changed.connect(_on_scene_changed)
	var viewport := get_viewport()
	if viewport != null and not viewport.size_changed.is_connected(_on_viewport_size_changed):
		viewport.size_changed.connect(_on_viewport_size_changed)
	var window := get_window()
	if window != null and not window.focus_entered.is_connected(_on_window_focus_entered):
		window.focus_entered.connect(_on_window_focus_entered)


func _on_scene_changed() -> void:
	if _shutting_down:
		return
	call_deferred("_host_current_scene")
	_schedule_banner_restore()


func _on_window_focus_entered() -> void:
	_schedule_banner_restore()


func _on_viewport_size_changed() -> void:
	if _shutting_down:
		return
	_update_app_layout()


func _set_reservation_active(value: bool) -> void:
	_reservation_active = value
	_update_app_layout()


func _reservation_height() -> float:
	# The sibling slot reserves only the measured adaptive-banner height.  Native
	# AdMob handles any device bottom inset inside its own placement.
	return _banner_logical_height if _reservation_active else 0.0


func _content_to_banner_gutter_height() -> int:
	return CONTENT_TO_BANNER_GUTTER_LOGICAL_PIXELS if _reservation_active else 0


func _ensure_app_layout() -> void:
	if not _can_manage_app_layout():
		return
	if _app_layout_is_live():
		return
	_discard_stale_app_layout()
	var tree := get_tree()
	if tree == null or tree.root == null or not tree.root.is_inside_tree() or tree.root.is_queued_for_deletion():
		return
	_app_layout = VBoxContainer.new()
	_app_layout.name = "AppViewportLayout"
	_app_layout.add_theme_constant_override("separation", 0)
	tree.root.add_child(_app_layout)
	# Anchors only resolve against an owning viewport after this node is parented.
	_app_layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_game_render_area = SubViewportContainer.new()
	_game_render_area.name = "GameRenderArea"
	_game_render_area.stretch = true
	_game_render_area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_game_render_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_game_render_area.mouse_filter = Control.MOUSE_FILTER_STOP
	_app_layout.add_child(_game_render_area)
	_app_content_viewport = SubViewport.new()
	_app_content_viewport.name = "AppContentViewport"
	_app_content_viewport.transparent_bg = false
	_app_content_viewport.handle_input_locally = false
	_game_render_area.add_child(_app_content_viewport)
	_ad_bar_area = Control.new()
	_ad_bar_area.name = "AdBarArea"
	_ad_bar_area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Keep this as a full-width sibling of GameRenderArea.  It is intentionally
	# not part of the content SubViewport, so app UI cannot render behind AdMob.
	_ad_bar_area.mouse_filter = Control.MOUSE_FILTER_STOP
	_app_layout.add_child(_ad_bar_area)
	_app_layout.minimum_size_changed.connect(_schedule_layout_sync)
	_app_layout.resized.connect(_schedule_layout_sync)
	_game_render_area.resized.connect(_schedule_layout_sync)
	_update_app_layout()


func _app_layout_is_live() -> bool:
	var tree := get_tree()
	if not _can_manage_app_layout() or tree == null or tree.root == null:
		return false
	if not is_instance_valid(_app_layout) or _app_layout.is_queued_for_deletion() or not _app_layout.is_inside_tree():
		return false
	if not is_instance_valid(_game_render_area) or _game_render_area.is_queued_for_deletion() or not _game_render_area.is_inside_tree():
		return false
	if not is_instance_valid(_app_content_viewport) or _app_content_viewport.is_queued_for_deletion() or not _app_content_viewport.is_inside_tree():
		return false
	if not is_instance_valid(_ad_bar_area) or _ad_bar_area.is_queued_for_deletion() or not _ad_bar_area.is_inside_tree():
		return false
	return _app_layout.get_parent() == tree.root and _game_render_area.get_parent() == _app_layout and _app_content_viewport.get_parent() == _game_render_area and _ad_bar_area.get_parent() == _app_layout


func _can_manage_app_layout() -> bool:
	return not _shutting_down and is_inside_tree()


func _discard_stale_app_layout() -> void:
	var stale_layout := _app_layout
	_app_layout = null
	_game_render_area = null
	_app_content_viewport = null
	_ad_bar_area = null
	_hosted_scene = null
	# During a scene replacement Godot can detach the old wrapper before its
	# queued deletion runs.  Never reuse that detached SubViewport: reparenting a
	# new scene into it leaves input dispatch pointing at a dead tree branch.
	if is_instance_valid(stale_layout) and not stale_layout.is_queued_for_deletion():
		stale_layout.queue_free()


func _update_app_layout() -> void:
	if not _can_manage_app_layout():
		return
	_ensure_app_layout()
	if not is_instance_valid(_app_layout) or not is_instance_valid(_ad_bar_area):
		return
	# The separation is deliberately outside both children: it keeps game content
	# clear of the native banner without inflating the measured banner reservation.
	_app_layout.add_theme_constant_override("separation", _content_to_banner_gutter_height())
	_ad_bar_area.custom_minimum_size.y = _reservation_height()
	# Keep this transparent layout child visible so VBoxContainer immediately
	# reallocates it to zero height when inactive instead of retaining its old rect.
	_ad_bar_area.visible = true
	_schedule_layout_sync()


func _schedule_layout_sync() -> void:
	if not _can_manage_app_layout() or _layout_sync_queued:
		return
	_layout_sync_queued = true
	call_deferred("_enforce_app_layout_bounds")


func _enforce_app_layout_bounds() -> void:
	_layout_sync_queued = false
	if not _can_manage_app_layout():
		return
	if not is_instance_valid(_app_layout) or not is_instance_valid(_game_render_area):
		return
	var tree := get_tree()
	if tree == null or tree.root == null:
		return
	var root_size := tree.root.get_visible_rect().size
	if root_size.x < 1.0 or root_size.y < 1.0:
		return
	_app_layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_app_layout.offset_left = 0.0
	_app_layout.offset_top = 0.0
	_app_layout.offset_right = 0.0
	_app_layout.offset_bottom = 0.0
	_app_layout.size = root_size
	_game_render_area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_game_render_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_app_layout.queue_sort()


func _host_current_scene() -> void:
	if not _can_manage_app_layout():
		return
	_ensure_app_layout()
	if not _app_layout_is_live():
		return
	var tree := get_tree()
	var scene := tree.current_scene if tree != null else null
	if not is_instance_valid(scene) or scene == _app_layout:
		return
	if scene.get_parent() == _app_content_viewport:
		_hosted_scene = scene
		return
	var previous_hosted_scene := _hosted_scene
	# SceneTree only permits a direct root child as current_scene.  Clear it
	# before moving the new direct-root route under the persistent SubViewport;
	# the service's content_scene() is the route source while it is hosted.
	tree.current_scene = null
	scene.reparent(_app_content_viewport)
	_hosted_scene = scene
	# A later change_scene_to_file() now creates a fresh direct-root route. Once
	# it arrives here, retire only the prior hosted route, never the wrapper.
	if is_instance_valid(previous_hosted_scene) and previous_hosted_scene != scene and previous_hosted_scene.get_parent() == _app_content_viewport:
		previous_hosted_scene.queue_free()
	if scene is Control:
		(scene as Control).set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func content_scene() -> Node:
	return _hosted_scene if is_instance_valid(_hosted_scene) else null


func _pixels_to_viewport_y(pixels: float) -> float:
	var window_h := float(DisplayServer.window_get_size().y)
	if window_h <= 0.0:
		return pixels
	var viewport_h := float(get_viewport().get_visible_rect().size.y)
	return pixels * (viewport_h / window_h)
