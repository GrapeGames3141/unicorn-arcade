extends Node

const RoomEditor = preload("res://scripts/meta/room_editor.gd")
const FurnitureBagOverlay = preload("res://scripts/meta/furniture_bag_overlay.gd")
const RoomItemPreview3D = preload("res://scripts/meta/room_item_preview_3d.gd")
const RoomPreviewViewport = preload("res://scripts/meta/room_preview_viewport.gd")
const RoomAuthoredFurnitureLoader = preload("res://scripts/meta/room_authored_furniture_loader.gd")
const RoomProceduralFurnitureBuilder = preload("res://scripts/meta/room_procedural_furniture_builder.gd")
const GameExperienceChromePresenter = preload("res://scripts/ui/game_experience_chrome_presenter.gd")
const GameExperienceTutorialPresenter = preload("res://scripts/ui/game_experience_tutorial_presenter.gd")
const GameExperienceOutcomePresenter = preload("res://scripts/ui/game_experience_outcome_presenter.gd")
const WordGameModeStrategy = preload("res://scripts/games/word_game_mode_strategy.gd")
const WordChoiceStrategy = preload("res://scripts/games/word_choice_strategy.gd")
const WordSequenceStrategy = preload("res://scripts/games/word_sequence_strategy.gd")
const WordTypedEntryStrategy = preload("res://scripts/games/word_typed_entry_strategy.gd")
const WordFallingStrategy = preload("res://scripts/games/word_falling_strategy.gd")
const WordRules = preload("res://scripts/games/word_game_rules.gd")
const RhymeScene = preload("res://scenes/games/rhyme_rally.tscn")
const GalaxyScene = preload("res://scenes/games/galaxy_unicorn.tscn")
const EquationGenerator = preload("res://scripts/games/equation_generator.gd")
const MathSwipe = preload("res://scripts/games/math_swipe.gd")
const CometMathRescue = preload("res://scripts/games/comet_math_rescue.gd")
const MoneyCounterBase = preload("res://scripts/games/money_counter_base.gd")

class TutorialPauseProbe extends ArcadeGameController:
	var level := 1

var failures: Array[String] = []

func _ready() -> void:
	_run.call_deferred()

func _check(value: bool, message: String) -> void:
	if not value: failures.append(message)


func _has_visible_pixels(texture: Texture2D) -> bool:
	if texture == null:
		return false
	var image := texture.get_image()
	return image != null and not image.is_empty() and image.get_used_rect().has_area()


func _room_item(items: Array, instance_id: String) -> Dictionary:
	for item in items:
		if str(item.get("instance_id", "")) == instance_id:
			return item
	return {}


func _run() -> void:
	_test_storybook_palette_contract()
	_test_word_choice_strategy()
	_test_word_sequence_strategy()
	_test_word_typed_entry_strategy()
	_test_word_falling_strategy()
	await _test_owned_rng_contracts()
	_test_equation_generator()
	_test_money_counter_base()
	var tutorial_presenter := GameExperienceTutorialPresenter.new()
	var tutorial_source: String = FileAccess.get_file_as_string("res://scripts/ui/game_experience_tutorial_presenter.gd")
	_check(tutorial_presenter is RefCounted and not tutorial_source.contains("\nvar ") and not tutorial_source.contains("AppState") and not tutorial_source.contains("GameExperience.") and not tutorial_source.contains("TutorialCatalog") and not tutorial_source.contains("attached_scene") and not tutorial_source.contains("CompanionAbilityService"), "tutorial presenter is a stateless RefCounted that does not own game, tutorial catalog, or gameplay state")
	var tutorial_overlay := Control.new()
	tutorial_overlay.set_meta("lessons", ["FIRST STEP", "SECOND STEP", "THIRD STEP"])
	tutorial_overlay.set_meta("step", 0)
	tutorial_overlay.set_meta("tutorial_level", 2)
	var tutorial_card := PanelContainer.new()
	tutorial_overlay.add_child(tutorial_card)
	tutorial_presenter.build(tutorial_card, tutorial_overlay, 2, ["FIRST STEP", "SECOND STEP", "THIRD STEP"], func(_overlay: Control) -> void: pass)
	var tutorial_heading := tutorial_overlay.find_child("TutorialHeading", true, false) as Label
	var tutorial_lesson := tutorial_overlay.find_child("TutorialLesson", true, false) as Label
	var tutorial_next := tutorial_overlay.find_child("TutorialNext", true, false) as Button
	_check(is_instance_valid(tutorial_heading) and tutorial_heading.text == "GUIDED LEVEL 2  •  STEP 1 OF 3" and is_instance_valid(tutorial_lesson) and tutorial_lesson.text == "FIRST STEP" and is_instance_valid(tutorial_next) and tutorial_next.text == "SHOW ME THE NEXT STEP", "tutorial presenter builds the exact heading, lesson, and next-button contract")
	var first_advance_complete := tutorial_presenter.advance(tutorial_overlay)
	_check(not first_advance_complete and int(tutorial_overlay.get_meta("step")) == 1 and tutorial_heading.text == "GUIDED LEVEL 2  •  STEP 2 OF 3" and tutorial_lesson.text == "SECOND STEP" and tutorial_next.text == "SHOW ME THE NEXT STEP", "tutorial presenter advances the step copy without consuming the overlay")
	var second_advance_complete := tutorial_presenter.advance(tutorial_overlay)
	_check(not second_advance_complete and int(tutorial_overlay.get_meta("step")) == 2 and tutorial_heading.text == "GUIDED LEVEL 2  •  STEP 3 OF 3" and tutorial_lesson.text == "THIRD STEP" and tutorial_next.text == "LET ME PLAY", "tutorial presenter preserves the final-step button transition")
	_check(tutorial_presenter.advance(tutorial_overlay), "tutorial presenter returns completion only after all tutorial steps are consumed")
	tutorial_overlay.free()
	var saved_tutorial_scene := GameExperience.attached_scene
	var saved_tutorial_controller := GameExperience.attached_controller
	var saved_tutorial_game_id := GameExperience.attached_game_id
	var saved_tutorials: Dictionary = AppState.data.get("tutorials", {}).duplicate(true)
	var tutorial_host := Control.new()
	add_child(tutorial_host)
	GameExperience.attached_scene = tutorial_host
	GameExperience.attached_controller = null
	GameExperience.attached_game_id = "coin_count"
	GameExperience._maybe_show_tutorial(true)
	var host_tutorial := tutorial_host.get_node_or_null("GuidedTutorialOverlay") as Control
	_check(is_instance_valid(host_tutorial) and str(host_tutorial.get_meta("game_id")) == "coin_count" and int(host_tutorial.get_meta("tutorial_level")) == 1 and host_tutorial.find_child("TutorialHeading", true, false) != null and host_tutorial.find_child("TutorialLesson", true, false) != null and host_tutorial.find_child("TutorialNext", true, false) != null, "GameExperience tutorial wrapper retains overlay metadata and presenter node contracts")
	GameExperience._advance_tutorial(host_tutorial)
	_check(int(host_tutorial.get_meta("step")) == 1 and (host_tutorial.find_child("TutorialHeading", true, false) as Label).text == "GUIDED LEVEL 1  •  STEP 2 OF 3", "GameExperience tutorial advance wrapper delegates presentation while retaining host metadata")
	var galaxy_probe := TutorialPauseProbe.new()
	add_child(galaxy_probe)
	GameExperience.attached_scene = galaxy_probe
	GameExperience.attached_controller = galaxy_probe
	GameExperience.attached_game_id = "galaxy_unicorn"
	GameExperience._maybe_show_tutorial(true)
	var galaxy_tutorial := galaxy_probe.get_node_or_null("GuidedTutorialOverlay") as Control
	_check(is_instance_valid(galaxy_tutorial) and galaxy_probe.gameplay_paused and not galaxy_probe.can_process(), "GameExperience pauses Galaxy gameplay when mounting its tutorial overlay")
	galaxy_tutorial.queue_free()
	await get_tree().process_frame
	_check(not galaxy_probe.gameplay_paused and galaxy_probe.can_process(), "GameExperience unpauses Galaxy gameplay when its tutorial overlay exits")
	GameExperience.attached_scene = saved_tutorial_scene
	GameExperience.attached_controller = saved_tutorial_controller
	GameExperience.attached_game_id = saved_tutorial_game_id
	AppState.data["tutorials"] = saved_tutorials
	tutorial_host.free()
	galaxy_probe.free()
	var outcome_presenter := GameExperienceOutcomePresenter.new()
	var outcome_source: String = FileAccess.get_file_as_string("res://scripts/ui/game_experience_outcome_presenter.gd")
	_check(outcome_presenter is RefCounted and not outcome_source.contains("\nvar ") and not outcome_source.contains("AppState") and not outcome_source.contains("GameExperience.") and not outcome_source.contains("LevelRunController") and not outcome_source.contains("ArcadeGameController") and not outcome_source.contains("attached_scene") and not outcome_source.contains("CompanionAbilityService"), "outcome presenter is a stateless RefCounted with only visual dependencies")
	var outcome_host := Control.new()
	add_child(outcome_host)
	var success_presentation := outcome_presenter.build_game_outcome(outcome_host, false, "A new adventure is ready.")
	var success_overlay := success_presentation.get("overlay") as Control
	var success_primary := success_presentation.get("primary") as Button
	var success_category := success_presentation.get("category") as Button
	_check(is_instance_valid(success_overlay) and success_overlay.name == "GameOutcomeOverlay" and success_overlay.z_index == 1500 and is_equal_approx(success_overlay.anchor_right, 1.0) and is_instance_valid(success_primary) and success_primary.name == "GameOutcomePrimaryAction" and success_primary.text == "KEEP GOING" and is_instance_valid(success_category) and success_category.name == "GameOutcomeReturnToCategory" and success_category.text == "RETURN TO CATEGORY" and (success_overlay.find_child("GameOutcomeMessage", true, false) as Label).text == "A new adventure is ready.", "outcome presenter returns the exact success overlay and action-node contract")
	var failure_host := Control.new()
	add_child(failure_host)
	var failure_presentation := outcome_presenter.build_game_outcome(failure_host, true, "Try once more.")
	var failure_overlay := failure_presentation.get("overlay") as Control
	var failure_primary := failure_presentation.get("primary") as Button
	_check(is_instance_valid(failure_overlay) and failure_primary.text == "TRY AGAIN" and (failure_overlay.find_child("GameOutcomeMessage", true, false) as Label).text == "Try once more.", "outcome presenter preserves the failure copy and retry action contract")
	var sparkle_host := Control.new()
	add_child(sparkle_host)
	var sparkle_presentation := outcome_presenter.build_sparkle_retry(sparkle_host, "A comet reached the meadow.")
	var sparkle_overlay := sparkle_presentation.get("overlay") as Control
	var sparkle_continue := sparkle_presentation.get("continue_button") as Button
	_check(is_instance_valid(sparkle_overlay) and sparkle_overlay.name == "SecondSparkleRetryOverlay" and sparkle_overlay.z_index == 1550 and sparkle_overlay.find_child("SecondSparkleRetryCard", true, false) != null and (sparkle_overlay.find_child("SecondSparkleFailureReason", true, false) as Label).text == "A comet reached the meadow." and is_instance_valid(sparkle_continue) and sparkle_continue.name == "SecondSparkleContinue" and sparkle_continue.text == "CONTINUE", "outcome presenter returns the exact Second Sparkle overlay and continue-node contract")
	var saved_outcome_scene := GameExperience.attached_scene
	var saved_outcome_controller := GameExperience.attached_controller
	var saved_outcome_game_id := GameExperience.attached_game_id
	var saved_outcome_overlay := GameExperience.outcome_overlay
	var saved_sparkle_overlay := GameExperience.sparkle_retry_overlay
	var wrapper_outcome_host := Control.new()
	add_child(wrapper_outcome_host)
	GameExperience.attached_scene = wrapper_outcome_host
	GameExperience.attached_controller = null
	GameExperience.attached_game_id = "coin_count"
	GameExperience.outcome_overlay = null
	GameExperience.sparkle_retry_overlay = null
	GameExperience._show_game_outcome()
	var wrapper_outcome := wrapper_outcome_host.get_node_or_null("GameOutcomeOverlay") as Control
	GameExperience._show_game_outcome()
	_check(is_instance_valid(wrapper_outcome) and GameExperience.outcome_overlay == wrapper_outcome and wrapper_outcome_host.find_children("GameOutcomeOverlay", "Control", true, false).size() == 1, "GameExperience outcome wrapper assigns its overlay field and guards against duplicate overlays")
	if is_instance_valid(wrapper_outcome):
		wrapper_outcome.queue_free()
	await get_tree().process_frame
	_check(GameExperience.outcome_overlay == null, "GameExperience clears its outcome overlay field after presentation exit")
	GameExperience.attached_scene = wrapper_outcome_host
	GameExperience.attached_controller = null
	GameExperience.attached_game_id = "coin_count"
	GameExperience._show_sparkle_retry_notice("A comet reached the meadow.")
	var wrapper_sparkle := wrapper_outcome_host.get_node_or_null("SecondSparkleRetryOverlay") as Control
	GameExperience._show_sparkle_retry_notice("A comet reached the meadow.")
	_check(is_instance_valid(wrapper_sparkle) and GameExperience.sparkle_retry_overlay == wrapper_sparkle and wrapper_outcome_host.find_children("SecondSparkleRetryOverlay", "Control", true, false).size() == 1, "GameExperience Second Sparkle wrapper assigns its overlay field and guards against duplicates")
	if is_instance_valid(wrapper_sparkle):
		wrapper_sparkle.queue_free()
	await get_tree().process_frame
	_check(GameExperience.sparkle_retry_overlay == null, "GameExperience clears its Second Sparkle overlay field after presentation exit")
	GameExperience.attached_scene = saved_outcome_scene
	GameExperience.attached_controller = saved_outcome_controller
	GameExperience.attached_game_id = saved_outcome_game_id
	GameExperience.outcome_overlay = saved_outcome_overlay
	GameExperience.sparkle_retry_overlay = saved_sparkle_overlay
	outcome_host.free()
	failure_host.free()
	sparkle_host.free()
	wrapper_outcome_host.free()
	var chrome_presenter := GameExperienceChromePresenter.new()
	var presenter_source: String = FileAccess.get_file_as_string("res://scripts/ui/game_experience_chrome_presenter.gd")
	_check(chrome_presenter is RefCounted and not presenter_source.contains("\nvar ") and not presenter_source.contains("AppState") and not presenter_source.contains("CompanionAbilityService"), "chrome presenter is a stateless RefCounted that receives presentation inputs instead of owning game state")
	var chrome_host := Control.new()
	add_child(chrome_host)
	chrome_presenter.apply_storybook_atmosphere(chrome_host)
	chrome_presenter.apply_storybook_atmosphere(chrome_host)
	_check(chrome_host.find_children("StorybookAtmosphere", "Control", true, false).size() == 1, "chrome presenter adds its storybook atmosphere idempotently")
	var presenter_header := chrome_presenter.build_header("Coin Count", 75, func() -> void: pass, func() -> void: pass, func() -> void: pass)
	var presenter_header_panel := presenter_header.get("panel") as PanelContainer
	var presenter_coin_button := presenter_header.get("coin_button") as Button
	_check(is_instance_valid(presenter_header_panel) and presenter_header_panel.name == "StandardGameHeader" and is_instance_valid(presenter_coin_button) and presenter_coin_button.name == "GameHeaderCoins" and presenter_coin_button.get_parent().get_parent() == presenter_header_panel and presenter_coin_button.text == " 75", "chrome presenter returns the exact header panel and coin button contract")
	var presenter_objective := chrome_presenter.build_objective_plaque("sparkle", func() -> void: pass, func() -> void: pass, func() -> void: pass)
	var presenter_objective_panel := presenter_objective.get("panel") as PanelContainer
	var presenter_primary := presenter_objective.get("objective_primary") as Label
	var presenter_detail := presenter_objective.get("objective_detail") as Label
	var presenter_ability := presenter_objective.get("ability_button") as Button
	var presenter_hint := presenter_objective.get("hint_button") as Button
	_check(is_instance_valid(presenter_objective_panel) and presenter_objective_panel.name == "GameObjectivePlaque" and is_instance_valid(presenter_primary) and presenter_primary.name == "ObjectivePrimary" and is_instance_valid(presenter_detail) and presenter_detail.name == "ObjectiveDetail" and is_instance_valid(presenter_ability) and presenter_ability.name == "CompanionAbility" and is_instance_valid(presenter_hint) and presenter_hint.name == "OrdinaryHint", "chrome presenter returns the exact objective labels and action button contract")
	var comet_scene := Control.new()
	var comet_equation := Label.new()
	comet_equation.name = "CometEquationBanner"
	comet_scene.add_child(comet_equation)
	var comet_meter := Label.new()
	comet_meter.name = "CometRescueMeter"
	comet_scene.add_child(comet_meter)
	chrome_presenter.configure_comet_chrome(comet_scene, "comet_math_rescue")
	_check(not comet_equation.visible and not comet_meter.visible, "chrome presenter hides duplicate Comet chrome only for the Comet game")
	var saved_attached_game_id := GameExperience.attached_game_id
	var saved_objective_primary := GameExperience.objective_primary
	var saved_objective_detail := GameExperience.objective_detail
	var saved_coin_button := GameExperience.coin_button
	var saved_ability_button := GameExperience.ability_button
	var saved_hint_button := GameExperience.hint_button
	var wrapper_header := GameExperience._build_header("Coin Count")
	var wrapper_objective := GameExperience._build_objective_plaque()
	chrome_host.add_child(wrapper_header)
	chrome_host.add_child(wrapper_objective)
	GameExperience.attached_game_id = "comet_math_rescue"
	GameExperience._configure_comet_chrome(comet_scene)
	_check(GameExperience.coin_button == wrapper_header.find_child("GameHeaderCoins", true, false) and GameExperience.objective_primary == wrapper_objective.find_child("ObjectivePrimary", true, false) and GameExperience.objective_detail == wrapper_objective.find_child("ObjectiveDetail", true, false) and GameExperience.ability_button == wrapper_objective.find_child("CompanionAbility", true, false) and GameExperience.hint_button == wrapper_objective.find_child("OrdinaryHint", true, false) and not comet_equation.visible and not comet_meter.visible, "GameExperience compatibility wrappers preserve public chrome fields and delegate Comet hiding")
	GameExperience.attached_game_id = saved_attached_game_id
	GameExperience.objective_primary = saved_objective_primary
	GameExperience.objective_detail = saved_objective_detail
	GameExperience.coin_button = saved_coin_button
	GameExperience.ability_button = saved_ability_button
	GameExperience.hint_button = saved_hint_button
	chrome_host.free()
	comet_scene.free()
	var procedural_rug_parent := Node3D.new()
	RoomProceduralFurnitureBuilder.new().build(procedural_rug_parent, "missing_procedural_rug", "rugs")
	var rug_mesh_count := 0
	for child in procedural_rug_parent.get_children():
		if child is MeshInstance3D and child.get_parent() == procedural_rug_parent:
			rug_mesh_count += 1
	_check(procedural_rug_parent.get_node_or_null("Rug") != null and rug_mesh_count == 4, "procedural builder creates the generic rug plus three direct inlay meshes")
	procedural_rug_parent.free()
	var procedural_chair_parent := Node3D.new()
	RoomProceduralFurnitureBuilder.new().build(procedural_chair_parent, "missing_procedural_chair", "unknown")
	var chair_mesh_count := 0
	for child in procedural_chair_parent.get_children():
		if child is MeshInstance3D and child.get_parent() == procedural_chair_parent:
			chair_mesh_count += 1
	_check(procedural_chair_parent.get_node_or_null("Seat") != null and procedural_chair_parent.get_node_or_null("Back") != null and chair_mesh_count == 6, "procedural builder falls back to a chair with direct Seat, Back, and four leg meshes")
	procedural_chair_parent.free()
	var authored_parent := Node3D.new()
	var authored_lamp := RoomAuthoredFurnitureLoader.build("lamp", authored_parent)
	var authored_missing := RoomAuthoredFurnitureLoader.build("missing_loader_id", authored_parent)
	_check(bool(authored_lamp.get("built", false)) and authored_lamp.get("source_model_id", "") == "store1:lamp" and authored_parent.get_node_or_null("AuthoredFurniture_lamp") != null and not bool(authored_missing.get("built", true)) and authored_parent.get_child_count() == 1, "authored furniture loader builds lamp and safely rejects missing ids")
	authored_parent.free()
	var received: Array = []
	var path := "res://scenes/games/coin_count.tscn"
	RuntimeAssetLoader.load_packed_scene(path, func(scene: PackedScene) -> void: received.append(scene))
	RuntimeAssetLoader.load_packed_scene(path, func(scene: PackedScene) -> void: received.append(scene))
	for frame in 120:
		await get_tree().process_frame
	_check(received.size() == 2 and received[0] != null and received[0] == received[1], "loader coalesces duplicate successful requests")
	var cached_scene := load("res://scenes/games/sliding_window.tscn") as PackedScene
	RuntimeAssetLoader.cache_packed_scene("res://scenes/games/sliding_window.tscn", cached_scene)
	_check(RuntimeAssetLoader.cached_packed_scene("res://scenes/games/sliding_window.tscn") == cached_scene, "loader accepts synchronous character loads into its shared scene cache")
	var missing: Array = []
	RuntimeAssetLoader.load_packed_scene("res://missing/refactor-test.tscn", func(scene: PackedScene) -> void: missing.append(scene))
	for frame in 3:
		await get_tree().process_frame
	_check(missing.size() == 1 and missing[0] == null and not RuntimeAssetLoader.is_processing(), "loader reports a missing path and idles")
	var definition := {"id":"rug", "category":"rugs"}
	var yaw := 45.0
	var rotation_preview := RoomItemPreview3D.new()
	rotation_preview.setup(definition.merged({"animate": false, "presentation": "cache"}, true))
	rotation_preview.set_display_yaw(0.0)
	var rotation_root := rotation_preview.display_rotation_root
	var rotation_owner = rotation_preview.preview_viewport
	var rotation_viewport := rotation_preview.get_node_or_null("SubViewport") as SubViewport
	var rotation_stage := rotation_viewport.get_node_or_null("PreviewStage") as Node3D if is_instance_valid(rotation_viewport) else null
	var zero_yaw_is_upright := is_instance_valid(rotation_root) and is_zero_approx(rotation_root.rotation_degrees.x) and is_zero_approx(rotation_root.rotation_degrees.y) and is_zero_approx(rotation_root.rotation_degrees.z)
	rotation_preview.set_display_yaw(yaw)
	_check(rotation_owner is RoomPreviewViewport and is_instance_valid(rotation_viewport) and rotation_viewport.size == Vector2i(192, 192) and rotation_viewport.own_world_3d and rotation_viewport.transparent_bg and rotation_viewport.render_target_update_mode == SubViewport.UPDATE_ONCE and rotation_preview.find_children("*", "SubViewport", true, false).size() == 1 and rotation_preview.find_children("PreviewStage", "Node3D", true, false).size() == 1 and rotation_preview.find_children("DisplayRotationRoot", "Node3D", true, false).size() == 1 and rotation_owner.viewport == rotation_viewport and rotation_owner.stage == rotation_stage and rotation_owner.display_rotation_root == rotation_root and rotation_stage.get_parent() == rotation_viewport and rotation_root.get_parent() == rotation_stage and zero_yaw_is_upright and is_equal_approx(rotation_root.rotation_degrees.y, yaw) and is_zero_approx(rotation_root.rotation_degrees.x) and is_zero_approx(rotation_root.rotation_degrees.z), "RoomPreviewViewport owns the exact furniture viewport/stage/rotation-root chain")
	rotation_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	rotation_preview.set_display_yaw(90.0)
	_check(rotation_viewport.render_target_update_mode == SubViewport.UPDATE_ONCE, "static furniture yaw requests one redraw after a disabled viewport")
	add_child(rotation_preview)
	await get_tree().process_frame
	rotation_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	rotation_preview.size += Vector2.ONE
	_check(rotation_viewport.render_target_update_mode == SubViewport.UPDATE_ONCE, "resizing a static preview re-arms its one-shot render target")
	var static_companion := RoomItemPreview3D.new()
	static_companion.setup({"id": "companion_sparkle", "category": "companions", "animate": false, "presentation": "game_hud"})
	var companion_viewport := static_companion.get_node_or_null("SubViewport") as SubViewport
	var companion_stage := static_companion.preview_viewport.stage as Node3D
	var companion_cameras := companion_stage.find_children("*", "Camera3D", false, false) if is_instance_valid(companion_stage) else []
	var companion_camera := companion_cameras[0] as Camera3D if companion_cameras.size() == 1 else null
	_check(static_companion.companion_builder != null and static_companion.source_model_id == "sparkle" and static_companion.preview_viewport is RoomPreviewViewport and is_instance_valid(companion_viewport) and companion_viewport.size == Vector2i(448, 320) and companion_viewport.render_target_update_mode == SubViewport.UPDATE_ONCE and companion_cameras.size() == 1 and is_instance_valid(companion_camera) and companion_camera.projection == Camera3D.PROJECTION_ORTHOGONAL and is_equal_approx(companion_camera.size, 8.80) and companion_camera.position.is_equal_approx(Vector3(-8.40, 4.28, 0.90)) and companion_camera.current and companion_stage.find_child("CompanionTravelRoot", true, false) != null and companion_stage.find_child("MeadowContactShadow", true, false) != null, "static companion builder owns the source, travel root, shadow, and HUD camera contract")
	static_companion.preview_viewport.shutdown()
	_check(companion_viewport.render_target_update_mode == SubViewport.UPDATE_DISABLED, "RoomPreviewViewport shutdown disables its render target")
	for _frame in 120:
		if static_companion.find_child("LiveUnicornModel", true, false) != null and not RuntimeAssetLoader.is_processing():
			break
		await get_tree().process_frame
	_check(static_companion.find_child("LiveUnicornModel", true, false) != null and static_companion.mesh_count > 0, "static companion async model instantiation updates facade mesh_count")
	var animated_companion := RoomItemPreview3D.new()
	animated_companion.setup({"id": "companion_sparkle", "category": "companions", "animate": true, "presentation": "room"})
	for _frame in 120:
		if animated_companion.find_child("LiveUnicornModel", true, false) != null:
			break
		await get_tree().process_frame
	var animated_idle := animated_companion.get_node_or_null("IdleAnimator")
	animated_companion.set_motion_state(true)
	_check(animated_companion.companion_builder != null and animated_companion.find_child("LiveUnicornModel", true, false) != null and animated_companion.mesh_count > 0 and is_instance_valid(animated_idle) and animated_idle.get_parent() == animated_companion and String(animated_idle.get("active_action")) != "", "animated companion builder mounts the host-owned animator and facade motion reaches its walk action")
	animated_companion.free()
	await get_tree().process_frame
	static_companion.free()
	rotation_preview.free()
	_check(DecorPreviewCache.cache_key(definition, 0.0) != DecorPreviewCache.cache_key(definition, yaw), "decor cache keeps 0 and 45 degree renders in distinct yaw keys")
	var transparent_readback := Image.create(2, 2, false, Image.FORMAT_RGBA8)
	_check(not bool(DecorPreviewCache.call("_has_visible_pixels", transparent_readback)), "decor cache rejects a fully transparent viewport readback")
	var textures: Array = []
	DecorPreviewCache.request(definition, yaw, func(texture: Texture2D) -> void: textures.append(texture))
	DecorPreviewCache.request(definition, yaw, func(texture: Texture2D) -> void: textures.append(texture))
	_check(DecorPreviewCache.active_viewport_count() <= 1, "decor cache has at most one transient viewport")
	for frame in 40:
		await get_tree().process_frame
	for frame in 3:
		await get_tree().process_frame
	_check(textures.size() == 2 and textures[0] is ImageTexture and _has_visible_pixels(textures[0]) and textures[0] == textures[1] and DecorPreviewCache.is_thumbnail_fallback(definition, yaw), "Fluffy Rug cache coalesces active duplicates into a visible thumbnail fallback ImageTexture")
	var bag_preview := FurnitureBagOverlay.new()
	var placeholder := bag_preview.call("_decor_thumbnail", "rug") as Texture2D
	_check(_has_visible_pixels(placeholder), "furniture bag assigns the Fluffy Rug thumbnail while its 3D preview is pending")
	var preview_parent := Button.new()
	preview_parent.size = Vector2(100, 100)
	preview_parent.rotation_degrees = 0.0
	var preview := TextureRect.new()
	preview.name = "CachedDecorPreview"
	preview.size = preview_parent.size
	preview_parent.add_child(preview)
	bag_preview.call("_refresh_cached_decor_preview", preview_parent, definition, yaw)
	_check(preview.texture == textures[0] and is_zero_approx(preview.rotation_degrees) and is_zero_approx(preview_parent.rotation_degrees), "furniture bag keeps both the fallback Fluffy Rug texture and its button upright")
	preview_parent.free()
	bag_preview.free()
	var saved_bag_inventory: Dictionary = AppState.data.get("inventory", {}).duplicate(true)
	AppState.data["inventory"]["lamp"] = 1
	AppState.data["inventory"]["rug"] = 1
	var bag_overlay := FurnitureBagOverlay.new()
	bag_overlay.setup("sparkle")
	add_child(bag_overlay)
	await get_tree().process_frame
	var bag_sheet := bag_overlay.get_node_or_null("FurnitureBagSheet") as PanelContainer
	var bag_category_chips: Array[Node] = bag_overlay.category_scroll.find_children("*", "Button", true, false)
	var bag_category_chip := bag_category_chips[0] as Button if not bag_category_chips.is_empty() else null
	var bag_item := bag_overlay.grid.get_child(0) as Button if bag_overlay.grid.get_child_count() > 0 else null
	_check(bag_overlay.name == "FurnitureBagOverlay" and is_instance_valid(bag_sheet) and is_equal_approx(bag_sheet.anchor_top, 0.34) and is_equal_approx(bag_sheet.anchor_bottom, 1.0) and bag_overlay.grid.name == "BagGrid" and bag_overlay.grid.columns == 3, "FurnitureBagOverlay owns the named bottom-sheet layout and three-column catalog grid")
	_check(bag_overlay.category_scroll.name == "FurnitureBagCategoryScroll" and bag_overlay.catalog_scroll.name == "FurnitureBagScroll" and bag_overlay.category_scroll.horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_AUTO and bag_overlay.category_scroll.vertical_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED and bag_overlay.catalog_scroll.horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED and bag_overlay.catalog_scroll.vertical_scroll_mode == ScrollContainer.SCROLL_MODE_AUTO and is_instance_valid(bag_overlay.category_scroll.get_h_scroll_bar()) and is_instance_valid(bag_overlay.catalog_scroll.get_v_scroll_bar()), "FurnitureBagOverlay delegates category and catalog movement to native horizontal and vertical ScrollContainers")
	_check(is_equal_approx(bag_overlay.category_scroll.scroll_deadzone, 12.0) and is_equal_approx(bag_overlay.catalog_scroll.scroll_deadzone, 12.0) and is_equal_approx(bag_overlay.category_tap_guard.deadzone, 12.0) and is_equal_approx(bag_overlay.catalog_tap_guard.deadzone, 12.0) and not bag_overlay.catalog_scroll.follow_focus and bag_overlay.grid.mouse_filter == Control.MOUSE_FILTER_PASS and is_instance_valid(bag_category_chip) and bag_category_chip.mouse_filter == Control.MOUSE_FILTER_PASS and is_instance_valid(bag_item) and bag_item.mouse_filter == Control.MOUSE_FILTER_PASS, "FurnitureBagOverlay keeps deadzones, focus behavior, and pass-through mouse filters on its native scrolling surfaces")
	var selected_bag_items: Array[String] = []
	var closed_bag_events: Array = []
	bag_overlay.item_selected.connect(func(item_id: String) -> void: selected_bag_items.append(item_id))
	bag_overlay.closed.connect(func() -> void: closed_bag_events.append(true))
	bag_overlay.call("_select_item", "lamp")
	var category_press := InputEventScreenTouch.new()
	category_press.index = 21
	category_press.pressed = true
	bag_overlay.call("_on_bag_category_scroll_gui_input", category_press)
	var category_drag := InputEventScreenDrag.new()
	category_drag.index = 21
	category_drag.relative = Vector2(-32, 1)
	bag_overlay.call("_on_bag_category_scroll_gui_input", category_drag)
	var category_release := InputEventScreenTouch.new()
	category_release.index = 21
	category_release.pressed = false
	bag_overlay.call("_on_bag_category_scroll_gui_input", category_release)
	bag_overlay.call("_set_bag_category", "beds")
	var catalog_press := InputEventScreenTouch.new()
	catalog_press.index = 22
	catalog_press.pressed = true
	bag_overlay.call("_on_bag_catalog_scroll_gui_input", catalog_press)
	var catalog_drag := InputEventScreenDrag.new()
	catalog_drag.index = 22
	catalog_drag.relative = Vector2(1, -32)
	bag_overlay.call("_on_bag_catalog_scroll_gui_input", catalog_drag)
	var catalog_release := InputEventScreenTouch.new()
	catalog_release.index = 22
	catalog_release.pressed = false
	bag_overlay.call("_on_bag_catalog_scroll_gui_input", catalog_release)
	bag_overlay.call("_select_item", "rug")
	_check(selected_bag_items == ["lamp"] and bag_overlay.category == "all" and bag_overlay.category_tap_guard.is_action_suppressed() and bag_overlay.catalog_tap_guard.is_action_suppressed(), "FurnitureBagOverlay suppresses immediate category and item actions after real touch drags")
	bag_overlay.category_tap_guard.clear_suppression()
	bag_overlay.catalog_tap_guard.clear_suppression()
	bag_overlay.call("_set_bag_category", "lighting")
	await get_tree().process_frame
	_check(bag_overlay.category == "lighting" and is_instance_valid(bag_overlay.grid) and bag_overlay.grid.get_parent() == bag_overlay.catalog_scroll and bag_overlay.find_children("FurnitureBagCategoryScroll", "ScrollContainer", true, false).size() == 1 and bag_overlay.find_children("FurnitureBagScroll", "ScrollContainer", true, false).size() == 1, "FurnitureBagOverlay rebuilds a coherent single-scroll category view after changing categories")
	bag_overlay.close()
	bag_overlay.close()
	await get_tree().process_frame
	_check(closed_bag_events.size() == 1 and not is_instance_valid(bag_overlay), "FurnitureBagOverlay emits its closed signal exactly once and releases itself")
	AppState.data["inventory"] = saved_bag_inventory
	var lifecycle_host := Control.new()
	add_child(lifecycle_host)
	var lifecycle_editor := RoomEditor.new()
	lifecycle_editor.room_canvas = lifecycle_host
	var first_item := {"instance_id": "live_rug_a", "item_id": "rug", "rotation": 0.0, "scale": 1.0, "z_index": 1}
	var second_item := {"instance_id": "live_rug_b", "item_id": "rug", "rotation": 45.0, "scale": 1.1, "z_index": 2}
	# The hidden companion home anchor sits behind placed decor in saved data, but
	# it must never affect visible decor ordering controls.
	var hidden_companion_anchor := {"instance_id": "room_companion_sparkle", "item_id": "companion_sparkle", "rotation": 0.0, "scale": 1.0, "z_index": 0}
	lifecycle_editor.local_items = [hidden_companion_anchor, first_item, second_item]
	lifecycle_editor.call("_create_item_button", first_item)
	lifecycle_editor.call("_create_item_button", second_item)
	for _frame in 4:
		await get_tree().process_frame
	var first_button := lifecycle_editor.item_buttons.get("live_rug_a") as Button
	var second_button := lifecycle_editor.item_buttons.get("live_rug_b") as Button
	var first_cached := first_button.get_node_or_null("CachedDecorPreview") as TextureRect
	var first_live := first_button.get_node_or_null("RoomItemPreview3D") as RoomItemPreview3D
	var first_root := first_live.display_rotation_root if is_instance_valid(first_live) else null
	var first_authored_rug := first_live.find_child("AuthoredFurniture_rug", true, false) if is_instance_valid(first_live) else null
	var second_live := second_button.get_node_or_null("RoomItemPreview3D") as RoomItemPreview3D
	var first_viewport := first_live.get_node_or_null("SubViewport") as SubViewport if is_instance_valid(first_live) else null
	_check(is_instance_valid(first_live) and is_instance_valid(second_live) and first_cached == null and first_live.animate_character == false and first_live.uses_authored_furniture_model and first_live.source_furniture_model_id == "store1:rug" and is_instance_valid(first_authored_rug) and is_instance_valid(first_viewport) and first_viewport.render_target_update_mode == SubViewport.UPDATE_ONCE, "visible room decor uses static authored 3D previews without CachedDecorPreview snapshots")
	first_live.set_display_yaw(45.0)
	_check(is_equal_approx(first_root.rotation_degrees.y, 45.0) and is_zero_approx(first_root.rotation_degrees.x) and is_zero_approx(first_root.rotation_degrees.z) and first_viewport.render_target_update_mode == SubViewport.UPDATE_ONCE and is_zero_approx(first_button.rotation_degrees), "static room decor redraws once after a yaw update while its button remains upright")
	var original_live := first_live
	first_button.custom_minimum_size = Vector2(140, 140)
	first_button.size = first_button.custom_minimum_size
	_check(first_button.get_node_or_null("RoomItemPreview3D") == original_live and is_zero_approx(first_live.anchor_left) and is_zero_approx(first_live.anchor_top) and is_equal_approx(first_live.anchor_right, 1.0) and is_equal_approx(first_live.anchor_bottom, 1.0), "room scale changes keep the same full-rect live preview node")
	lifecycle_editor.selected_id = "live_rug_a"
	lifecycle_editor.call("_show_selection_toolbar")
	var backmost_toolbar := lifecycle_editor.selection_toolbar as HBoxContainer
	var backmost_back := backmost_toolbar.get_child(4) as Button
	var backmost_front := backmost_toolbar.get_child(5) as Button
	lifecycle_editor.selected_id = "live_rug_b"
	lifecycle_editor.call("_show_selection_toolbar")
	var frontmost_toolbar := lifecycle_editor.selection_toolbar as HBoxContainer
	var frontmost_back := frontmost_toolbar.get_child(4) as Button
	var frontmost_front := frontmost_toolbar.get_child(5) as Button
	_check(backmost_back.disabled and not backmost_front.disabled and not frontmost_back.disabled and frontmost_front.disabled, "layer controls stop at the visible decor boundaries and ignore the hidden companion anchor")
	# Exercise the actual action path against a controlled room state, then put
	# AppState back exactly as it was so this regression never changes a profile.
	var saved_rooms: Dictionary = AppState.data.get("rooms", {}).duplicate(true)
	var saved_save_envelope: Dictionary = SaveService._envelope.duplicate(true)
	var saved_active_key: String = SaveService._active_key
	var saved_test_in_memory: bool = SaveService._test_in_memory
	var test_profile_key := "runtime_refactor"
	SaveService._test_in_memory = true
	SaveService._envelope = SaveService.default_state()
	SaveService._envelope["last_user"] = test_profile_key
	SaveService._envelope["users"][test_profile_key] = {"display_name": test_profile_key, "profile": AppState.data.duplicate(true)}
	SaveService._active_key = test_profile_key
	var action_rooms := saved_rooms.duplicate(true)
	action_rooms[lifecycle_editor.companion_id] = [hidden_companion_anchor.duplicate(true), first_item.duplicate(true), second_item.duplicate(true)]
	AppState.data["rooms"] = action_rooms
	lifecycle_editor.local_items = AppState.room_items(lifecycle_editor.companion_id)
	lifecycle_editor.selected_id = "live_rug_a"
	lifecycle_editor.call("_refresh_room_items")
	for step in 8:
		lifecycle_editor.call("_selection_action", "LARGER")
	await get_tree().process_frame
	var enlarged_local := _room_item(lifecycle_editor.local_items, "live_rug_a")
	var enlarged_saved := _room_item(AppState.room_items(lifecycle_editor.companion_id), "live_rug_a")
	var base_size: Vector2 = lifecycle_editor.call("_item_base_size", "rug")
	var larger_toolbar := lifecycle_editor.selection_toolbar as HBoxContainer
	var larger_button := larger_toolbar.get_child(3) as Button
	_check(is_equal_approx(float(enlarged_local.get("scale", 0.0)), 1.8) and is_equal_approx(float(enlarged_saved.get("scale", 0.0)), 1.8) and first_button.get_node_or_null("RoomItemPreview3D") == original_live and first_button.size.is_equal_approx(base_size * 1.8) and first_live.size.is_equal_approx(first_button.size) and larger_button.disabled, "LARGER updates AppState and the existing full-rect live preview while disabling at the maximum scale")
	for step in 13:
		lifecycle_editor.call("_selection_action", "SMALLER")
	await get_tree().process_frame
	var reduced_local := _room_item(lifecycle_editor.local_items, "live_rug_a")
	var reduced_saved := _room_item(AppState.room_items(lifecycle_editor.companion_id), "live_rug_a")
	var smaller_toolbar := lifecycle_editor.selection_toolbar as HBoxContainer
	var smaller_button := smaller_toolbar.get_child(2) as Button
	_check(is_equal_approx(float(reduced_local.get("scale", 0.0)), 0.5) and is_equal_approx(float(reduced_saved.get("scale", 0.0)), 0.5) and first_button.get_node_or_null("RoomItemPreview3D") == original_live and first_button.size.is_equal_approx(base_size * 0.5) and first_live.size.is_equal_approx(first_button.size) and smaller_button.disabled, "SMALLER updates AppState and the existing full-rect live preview while disabling at the minimum scale")
	for step in 5:
		lifecycle_editor.call("_selection_action", "LARGER")
	lifecycle_editor.call("_selection_action", "FRONT")
	var front_local := _room_item(lifecycle_editor.local_items, "live_rug_a")
	var front_neighbor := _room_item(lifecycle_editor.local_items, "live_rug_b")
	var front_saved := _room_item(AppState.room_items(lifecycle_editor.companion_id), "live_rug_a")
	var front_toolbar := lifecycle_editor.selection_toolbar as HBoxContainer
	_check(int(front_local.get("z_index", 0)) == 2 and int(front_neighbor.get("z_index", 0)) == 1 and int(front_saved.get("z_index", 0)) == 2 and first_button.z_index == 2 and second_button.z_index == 1 and first_button.get_node_or_null("RoomItemPreview3D") == original_live and (front_toolbar.get_child(5) as Button).disabled, "FRONT swaps only visible decor z-order through AppState and refreshes the front boundary")
	lifecycle_editor.call("_selection_action", "BACK")
	var restored_local := _room_item(lifecycle_editor.local_items, "live_rug_a")
	var restored_neighbor := _room_item(lifecycle_editor.local_items, "live_rug_b")
	var restored_saved := _room_item(AppState.room_items(lifecycle_editor.companion_id), "live_rug_a")
	var restored_toolbar := lifecycle_editor.selection_toolbar as HBoxContainer
	_check(int(restored_local.get("z_index", 0)) == 1 and int(restored_neighbor.get("z_index", 0)) == 2 and int(restored_saved.get("z_index", 0)) == 1 and first_button.z_index == 1 and second_button.z_index == 2 and first_button.get_node_or_null("RoomItemPreview3D") == original_live and (restored_toolbar.get_child(4) as Button).disabled, "BACK restores visible decor z-order through AppState and refreshes the back boundary")
	AppState.data["rooms"] = saved_rooms
	SaveService._envelope = saved_save_envelope
	SaveService._active_key = saved_active_key
	SaveService._test_in_memory = saved_test_in_memory
	lifecycle_host.queue_free()
	lifecycle_editor.free()
	if failures.is_empty():
		print("RUNTIME_REFACTOR_INTEGRATION_OK")
		get_tree().quit(0)
	else:
		for failure in failures: push_error(failure)
		get_tree().quit(1)


func _test_storybook_palette_contract() -> void:
	var removed_aliases := {
		"res://scripts/games/cash_counter.gd": ["const CYAN := Color(\"58d6e8\")"],
		"res://scripts/games/word_game.gd": ["const CYAN := Color(\"58d6e8\")"],
		"res://scripts/main.gd": ["const CYAN := Color(\"58d6e8\")"],
		"res://scripts/meta/marketplace.gd": [
			"const GOLD := Color(\"e1ae4f\")",
			"const CREAM := Color(\"fff3d6\")",
			"const MUTED := Color(\"c9d3ef\")",
			"const CYAN := Color(\"58d6e8\")",
		],
		"res://scripts/meta/room_editor.gd": ["const CYAN := Color(\"58d6e8\")"],
		"res://scripts/meta/unicorn_alley.gd": ["const CYAN := Color(\"58d6e8\")"],
		"res://scripts/ui/game_catalog_view.gd": ["const CYAN := Color(\"58d6e8\")"],
		"res://scripts/ui/profile_view.gd": ["const CYAN := Color(\"58d6e8\")"],
		"res://scripts/ui/arcade_pictogram.gd": [
			"const NAVY := Color(\"17254d\")",
			"const CREAM := Color(\"fff3d6\")",
			"const GOLD := Color(\"f4d37f\")",
			"const CYAN := Color(\"58d6e8\")",
		],
		"res://scripts/games/coin_choice_button.gd": ["const CREAM := Color(\"fff3d6\")"],
	}
	for path in removed_aliases:
		var source := FileAccess.get_file_as_string(path)
		for alias in removed_aliases[path]:
			_check(not source.contains(alias), "%s removes exact local Storybook palette alias %s" % [path, alias])
	var shared_references := {
		"res://scripts/games/cash_counter.gd": ["StorybookUI.CYAN", "StorybookUI.CREAM", "StorybookUI.GOLD"],
		"res://scripts/games/coin_count.gd": ["StorybookUI.CYAN", "StorybookUI.CREAM"],
		"res://scripts/games/word_game.gd": ["StorybookUI.CYAN", "StorybookUI.CREAM", "StorybookUI.GOLD"],
		"res://scripts/games/galaxy_unicorn.gd": ["StorybookUI.NAVY", "StorybookUI.CREAM"],
		"res://scripts/games/mathtris.gd": ["StorybookUI.CREAM", "StorybookUI.GOLD"],
		"res://scripts/games/math_swipe.gd": ["StorybookUI.CREAM"],
		"res://scripts/games/rhyme_rally.gd": ["StorybookUI.CREAM"],
		"res://scripts/games/sliding_window.gd": ["StorybookUI.CREAM", "StorybookUI.GOLD_BRIGHT"],
		"res://scripts/games/unicorn_jump.gd": ["StorybookUI.CREAM"],
		"res://scripts/meta/marketplace.gd": ["StorybookUI.CYAN", "StorybookUI.CREAM", "StorybookUI.GOLD", "StorybookUI.MUTED"],
		"res://scripts/meta/room_editor.gd": ["StorybookUI.CYAN"],
		"res://scripts/ui/game_catalog_view.gd": ["StorybookUI.CYAN"],
		"res://scripts/ui/profile_view.gd": ["StorybookUI.NAVY", "StorybookUI.CYAN", "StorybookUI.CREAM", "StorybookUI.GOLD_BRIGHT", "StorybookUI.MUTED"],
		"res://scripts/ui/arcade_pictogram.gd": ["StorybookUI.NAVY", "StorybookUI.CYAN", "StorybookUI.CREAM", "StorybookUI.GOLD_BRIGHT"],
		"res://scripts/ui/game_experience_chrome_presenter.gd": ["StorybookUI.NAVY", "StorybookUI.CREAM", "StorybookUI.GOLD"],
		"res://scripts/ui/game_experience_outcome_presenter.gd": ["StorybookUI.CREAM", "StorybookUI.GOLD_BRIGHT"],
		"res://scripts/ui/unicorn_header.gd": ["StorybookUI.NAVY"],
		"res://scripts/games/coin_choice_button.gd": ["StorybookUI.CYAN", "StorybookUI.CREAM"],
	}
	var exact_palette_literals := [
		"Color(\"17254d\")",
		"Color(\"58d6e8\")",
		"Color(\"e1ae4f\")",
		"Color(\"f4d37f\")",
		"Color(\"fff3d6\")",
		"Color(\"c9d3ef\")",
	]
	for path in shared_references:
		var source := FileAccess.get_file_as_string(path)
		_check(shared_references[path].all(func(token: String) -> bool: return source.contains(token)), "%s sources every exact presentation color from StorybookUI" % path)
		_check(exact_palette_literals.all(func(literal: String) -> bool: return not source.contains(literal)), "%s does not redeclare an exact Storybook palette literal" % path)
	var cash_source := FileAccess.get_file_as_string("res://scripts/games/cash_counter.gd")
	var word_source := FileAccess.get_file_as_string("res://scripts/games/word_game.gd")
	var main_source := FileAccess.get_file_as_string("res://scripts/main.gd")
	var room_source := FileAccess.get_file_as_string("res://scripts/meta/room_editor.gd")
	var alley_source := FileAccess.get_file_as_string("res://scripts/meta/unicorn_alley.gd")
	var catalog_source := FileAccess.get_file_as_string("res://scripts/ui/game_catalog_view.gd")
	var profile_source := FileAccess.get_file_as_string("res://scripts/ui/profile_view.gd")
	var pictogram_source := FileAccess.get_file_as_string("res://scripts/ui/arcade_pictogram.gd")
	var header_source := FileAccess.get_file_as_string("res://scripts/ui/unicorn_header.gd")
	_check(cash_source.contains("const NAVY := Color(\"08112f\")") and word_source.contains("const NAVY := Color(\"08112f\")") and main_source.contains("const NAVY := Color(\"08112f\")") and room_source.contains("const NAVY := Color(\"08112f\")"), "the distinct 08112f game/meta background navy remains intentionally local")
	_check(alley_source.contains("const NAVY := Color(\"07142c\")"), "the distinct 07142c Unicorn Alley background navy remains intentionally local")
	_check(word_source.contains("const PINK := Color(\"f26fa7\")") and main_source.contains("const PINK := Color(\"f26fa7\")") and room_source.contains("const PINK := Color(\"f26fa7\")") and alley_source.contains("const PINK := Color(\"f26fa7\")") and catalog_source.contains("const PINK := Color(\"f26fa7\")") and profile_source.contains("const PINK := Color(\"f26fa7\")") and pictogram_source.contains("const PINK := Color(\"f26fa7\")"), "the distinct f26fa7 category accent remains intentionally local")
	_check(main_source.contains("const MUTED := Color(\"aab7e8\")") and room_source.contains("const MUTED := Color(\"aab7e8\")") and alley_source.contains("const MUTED := Color(\"aab7e8\")"), "the distinct aab7e8 secondary text color remains intentionally local")
	_check(header_source.contains("const CURRENCY_STAR := Color(\"ffd166\")"), "the intentionally brighter ffd166 currency star remains separate from StorybookUI.GOLD")


func _test_word_choice_strategy() -> void:
	var base := WordGameModeStrategy.new()
	_check(base is RefCounted and base.family().is_empty() and not base.supports("missing_magic") and base.begin_round({}) == {"handled": false} and base.submit({}, "answer") == {"outcome": "ignored"} and base.hint({}).is_empty() and base.tick({}, 0.1).is_empty() and base.failure_reason({}) == "Try this level again.", "WordGameModeStrategy exposes the stateless safe defaults")
	var source := FileAccess.get_file_as_string("res://scripts/games/word_choice_strategy.gd")
	_check(not source.contains("AppState") and not source.contains("ArcadeGameController") and not source.contains("StorybookUI") and not source.contains("GameRegistry"), "choice strategy stays inside Rules and RoundCatalog data boundaries")
	var strategy := WordChoiceStrategy.new()
	var supported := ["missing_magic", "prefix_potion", "vowel_vines", "caption_quest", "opposite_orbit", "odd_one_out", "chain_link"]
	_check(strategy.family() == "choice" and supported.all(func(game_id: String) -> bool: return strategy.supports(game_id)) and not strategy.supports("sentence_sprout"), "choice strategy exposes exactly the migrated mode IDs")
	for game_id in supported:
		var rng := RandomNumberGenerator.new()
		rng.seed = 1337
		var round := strategy.begin_round({"game_id": game_id, "level": 1, "round_index": 0, "rng": rng, "hint_visible": false})
		var current: Dictionary = round.get("current", {})
		var options: Array = round.get("options", [])
		_check(bool(round.get("handled", false)) and bool(round.get("ok", false)) and not current.is_empty() and not str(round.get("instruction", "")).is_empty() and not options.is_empty(), "%s begins with a renderable choice contract" % game_id)
		if game_id == "odd_one_out":
			var odd_spec: Dictionary = options[0]
			_check(odd_spec.get("text", "").contains("\n") and not str(odd_spec.get("payload", "")).contains("\n"), "Odd One Out keeps display text separate from its selection payload")
		var current_before := current.duplicate(true)
		var options_before := options.duplicate(true)
		strategy.hint({"game_id": game_id, "current": current})
		strategy.hint({"game_id": game_id, "current": current})
		_check(current == current_before and options == options_before, "%s hint derives from current without repicking or reordering" % game_id)
		var correct_payload: Variant = _choice_correct_payload(game_id, current, options)
		var wrong_outcome := "lost_life" if game_id in ["caption_quest", "odd_one_out"] else "failure"
		_check(strategy.submit({"game_id": game_id, "current": current}, correct_payload).get("outcome") == "success" and strategy.submit({"game_id": game_id, "current": current}, "__wrong_choice__").get("outcome") == wrong_outcome, "%s returns success and its expected incorrect outcome" % game_id)
		_check(not strategy.failure_reason({"game_id": game_id}).is_empty(), "%s has a concrete failure reason" % game_id)
	var saved_cache := WordRules._cache.duplicate(true)
	WordRules._cache = {"vowel_words": {}}
	var empty_rng := RandomNumberGenerator.new()
	_check(not bool(strategy.begin_round({"game_id": "vowel_vines", "level": 1, "round_index": 0, "rng": empty_rng}).get("ok", true)), "Vowel Vines reports an invalid round when every vowel source is empty")
	WordRules._cache = saved_cache
	_check(strategy.failure_reason({"game_id": "caption_quest"}) == "Out of hearts—choose the best caption!" and strategy.failure_reason({"game_id": "chain_link"}) == "Pick a word beginning with the last letter!", "choice strategy preserves the exact failure copy")


func _test_word_falling_strategy() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/games/word_falling_strategy.gd")
	_check(not source.contains("AppState") and not source.contains("ArcadeGameController") and not source.contains("StorybookUI") and not source.contains("GameRegistry") and not source.contains("Companion") and not source.contains("Button"), "falling strategy stays model-only inside Rules/RNG boundaries")
	var strategy := WordFallingStrategy.new()
	_check(strategy.family() == "falling" and strategy.supports("unicorn_blast") and not strategy.supports("sight_spark") and strategy.begin_round({"game_id": "sight_spark"}) == {"handled": false}, "falling strategy exposes only Unicorn Blast with safe fallback")
	var saved_cache := WordRules._cache.duplicate(true)
	WordRules._cache = {"falling_words": {"easy": ["cloud"]}}
	var rng := RandomNumberGenerator.new()
	rng.seed = 24016
	var models := [{"text": "star", "x": 20.0, "y": 12.0}]
	var models_before := models.duplicate(true)
	var before_due := strategy.tick({"game_id": "unicorn_blast", "level": 1, "rng": rng, "spawn_elapsed": 2.669, "blast_models": models, "blast_source_exhausted": false}, 0.01)
	_check(not bool(before_due.get("spawn_due", true)) and (before_due.get("entries", []) as Array).size() == 1 and models == models_before, "falling tick preserves source models and does not spawn before the exact interval boundary")
	var due_rng := RandomNumberGenerator.new()
	due_rng.seed = 24016
	var due := strategy.tick({"game_id": "unicorn_blast", "level": 1, "rng": due_rng, "spawn_elapsed": 2.671, "blast_models": models, "blast_source_exhausted": false}, 0.01)
	var due_entries: Array = due.get("entries", [])
	var expected_step := WordRules.blast_speed(1) * 0.01 * 60.0
	_check(bool(due.get("spawn_due", false)) and bool(due.get("spawned", false)) and is_zero_approx(float(due.get("spawn_elapsed", -1.0))) and due_entries.size() == 2 and due_entries.all(func(entry: Dictionary) -> bool: return not entry.has("button")) and is_equal_approx(float(due_entries[0].get("y", 0.0)), 12.0 + expected_step) and is_equal_approx(float(due_entries[1].get("y", 0.0)), 8.0 + expected_step) and models == models_before, "due spawn is appended before movement so sanitized old and new models advance in the same tick without input mutation")
	var exhausted := strategy.tick({"game_id": "unicorn_blast", "level": 1, "rng": due_rng, "spawn_elapsed": 2.671, "blast_models": models, "blast_source_exhausted": true}, 0.01)
	_check(not bool(exhausted.get("spawn_due", true)) and is_equal_approx(float(exhausted.get("spawn_elapsed", 0.0)), 2.681), "source exhaustion disables future spawns without resetting accumulated elapsed time")
	WordRules._cache = {"falling_words": {"easy": []}}
	var empty := strategy.tick({"game_id": "unicorn_blast", "level": 1, "rng": due_rng, "spawn_elapsed": 2.671, "blast_models": models, "blast_source_exhausted": false}, 0.01)
	_check(bool(empty.get("spawn_due", false)) and bool(empty.get("source_empty", false)) and not bool(empty.get("spawned", true)) and is_zero_approx(float(empty.get("spawn_elapsed", -1.0))) and (empty.get("entries", []) as Array).size() == 1, "empty due source resets the interval, reports exhaustion, and still advances existing models")
	WordRules._cache = saved_cache
	var submit_models := [{"text": "star", "x": 20.0, "y": 30.0}, {"text": "moon", "x": 40.0, "y": 70.0}]
	var submit_before := submit_models.duplicate(true)
	var match_result := strategy.submit({"game_id": "unicorn_blast", "blast_models": submit_models}, "  MOON  ")
	var ignored_result := strategy.submit({"game_id": "unicorn_blast", "blast_models": submit_models}, "sun")
	var hint := strategy.hint({"game_id": "unicorn_blast", "blast_models": submit_models})
	var escaped := strategy.tick({"game_id": "unicorn_blast", "level": 1, "spawn_elapsed": 0.0, "blast_models": [{"text": "late", "x": 1.0, "y": 78.0}], "blast_source_exhausted": true}, 0.01)
	_check(match_result.get("outcome") == "success" and int(match_result.get("match_index", -1)) == 1 and ignored_result.get("outcome") == "ignored" and hint.get("message") == "Blast: moon" and escaped.get("escaped") == [0] and submit_models == submit_before, "falling submit normalizes input, hint selects max-y urgency, and escape uses the strict 78 boundary immutably")
	_check(strategy.failure_reason({"game_id": "unicorn_blast"}) == "Words reached your cannon!", "falling strategy preserves exact failure copy")


func _test_owned_rng_contracts() -> void:
	var selection_equivalent := true
	for size in [1, 3, 4, 24]:
		for seed in range(-2, 41):
			var safe_seed := maxi(1, seed)
			var old_ceiling := mini(size, maxi(4, roundi(safe_seed * 1.5)))
			var old_floor := maxi(0, old_ceiling - maxi(5, roundi(old_ceiling * 0.6)))
			if WordRules.selection_window(size, seed) != Vector2i(old_floor, old_ceiling):
				selection_equivalent = false
	_check(selection_equivalent and WordRules.selection_window(0, 1) == Vector2i.ZERO and WordRules.selection_window(1, 1) == Vector2i(0, 1) and WordRules.selection_window(24, 100) == Vector2i(10, 24), "selection window matches the former Rhyme formula across level boundaries and clamps empty, tiny, and exhausted ranges")

	var rhyme_source := FileAccess.get_file_as_string("res://scripts/games/rhyme_rally.gd")
	var galaxy_source := FileAccess.get_file_as_string("res://scripts/games/galaxy_unicorn.gd")
	var rhyme_scrubbed := rhyme_source.replace("rng.randi_range(", "").replace("rng.randi(", "").replace("rng.randf_range(", "").replace("rng.randf(", "")
	var galaxy_scrubbed := galaxy_source.replace("rng.randi_range(", "").replace("rng.randi(", "").replace("rng.randf_range(", "").replace("rng.randf(", "")
	_check(not rhyme_scrubbed.contains("randi_range(") and not rhyme_scrubbed.contains("randi(") and not rhyme_scrubbed.contains("randf_range(") and not rhyme_scrubbed.contains("randf(") and not rhyme_source.contains(".shuffle(") and rhyme_source.count("rng.randomize()") == 1 and rhyme_source.count("rng.seed = seed") == 1, "Rhyme owns all random selection and Fisher-Yates state with one startup randomization and one test seed hook")
	_check(not galaxy_scrubbed.contains("randi_range(") and not galaxy_scrubbed.contains("randi(") and not galaxy_scrubbed.contains("randf_range(") and not galaxy_scrubbed.contains("randf(") and not galaxy_source.contains(".shuffle(") and galaxy_source.count("rng.randomize()") == 1 and galaxy_source.count("rng.seed = seed") == 1, "Galaxy owns enemy and pickup randomness with one startup randomization and one test seed hook")

	var rhyme_a = RhymeScene.instantiate()
	var rhyme_b = RhymeScene.instantiate()
	add_child(rhyme_a)
	add_child(rhyme_b)
	await get_tree().process_frame
	rhyme_a.set_process(false)
	rhyme_b.set_process(false)
	for rhyme in [rhyme_a, rhyme_b]:
		rhyme.level = 9
		rhyme.round_index = 4
		rhyme.set_random_seed(25025)
		rhyme.call("_show_round")
	var rhyme_order_a: Array = rhyme_a.option_buttons.map(func(button: Button) -> String: return button.text)
	var rhyme_order_b: Array = rhyme_b.option_buttons.map(func(button: Button) -> String: return button.text)
	_check(rhyme_a.challenge == rhyme_b.challenge and rhyme_order_a == rhyme_order_b, "equal Rhyme seeds reproduce both the selected challenge and Fisher-Yates option order")
	var rhyme_signatures := {}
	for seed in [3, 11, 29, 47, 83]:
		rhyme_a.set_random_seed(seed)
		rhyme_a.call("_show_round")
		var order: Array = rhyme_a.option_buttons.map(func(button: Button) -> String: return button.text)
		rhyme_signatures["%s:%s" % [rhyme_a.challenge.get("prompt", ""), ",".join(order)]] = true
	_check(rhyme_signatures.size() >= 2, "different Rhyme seeds produce diverse challenge and option signatures")

	var galaxy_a = GalaxyScene.instantiate()
	var galaxy_b = GalaxyScene.instantiate()
	add_child(galaxy_a)
	add_child(galaxy_b)
	await get_tree().process_frame
	for galaxy in [galaxy_a, galaxy_b]:
		galaxy.set_process(false)
		galaxy.size = Vector2(720.0, 1280.0)
		galaxy.level = 6
		galaxy.enemies.clear()
		galaxy.set_random_seed(25025)
		galaxy.call("_spawn_enemy", false)
	var enemy_a: Dictionary = galaxy_a.enemies[0]
	var enemy_b: Dictionary = galaxy_b.enemies[0]
	_check(enemy_a.get("kind") == enemy_b.get("kind") and enemy_a.get("position") == enemy_b.get("position") and is_equal_approx(float(enemy_a.get("phase", -1.0)), float(enemy_b.get("phase", -2.0))), "equal Galaxy seeds reproduce enemy template, position, and phase")
	galaxy_a.set_random_seed(811)
	galaxy_b.set_random_seed(811)
	var pickup_rolls_a: Array = []
	var pickup_rolls_b: Array = []
	for index in 64:
		pickup_rolls_a.append(galaxy_a.call("_roll_pickup", Vector2(index, 10.0)))
		pickup_rolls_b.append(galaxy_b.call("_roll_pickup", Vector2(index, 10.0)))
	_check(pickup_rolls_a == pickup_rolls_b and pickup_rolls_a.any(func(pickup: Dictionary) -> bool: return not pickup.is_empty()), "equal Galaxy seeds reproduce pickup drop and kind rolls, including successful drops")
	var galaxy_signatures := {}
	for seed in [3, 11, 29, 47, 83]:
		galaxy_a.enemies.clear()
		galaxy_a.set_random_seed(seed)
		galaxy_a.call("_spawn_enemy", false)
		var enemy: Dictionary = galaxy_a.enemies[0]
		galaxy_signatures["%s:%s:%s" % [enemy.get("kind", ""), enemy.get("position", Vector2.ZERO), enemy.get("phase", 0.0)]] = true
	_check(galaxy_signatures.size() >= 2, "different Galaxy seeds produce diverse enemy templates, positions, or phases")
	remove_child(rhyme_a)
	remove_child(rhyme_b)
	rhyme_a.free()
	rhyme_b.free()
	remove_child(galaxy_a)
	remove_child(galaxy_b)
	galaxy_a.free()
	galaxy_b.free()


func _test_equation_generator() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/games/equation_generator.gd")
	var math_source := FileAccess.get_file_as_string("res://scripts/games/math_swipe.gd")
	var comet_source := FileAccess.get_file_as_string("res://scripts/games/comet_math_rescue.gd")
	_check(not source.contains("AppState") and not source.contains("ArcadeGameController") and not source.contains("StorybookUI") and not source.contains("GameplayRules") and not source.contains("display") and not source.contains("correct_index") and not source.contains("answers"), "equation generator is a stateless arithmetic-only boundary without UI, lifecycle, or caller presentation fields")
	_check(math_source.contains("EquationGenerator.math_swipe_core(for_level, rng)") and math_source.contains("var missing := rng.randi_range(0, 2)") and math_source.contains("var wrong: int = correct"), "Math Swipe delegates only its arithmetic core and retains missing-slot and wrong-answer generation")
	_check(comet_source.contains("EquationGenerator.comet_math_rescue_core(for_level, generator)") and comet_source.contains("var answers: Array[int] = [answer]") and comet_source.contains("var swap_index := generator.randi_range(0, index)"), "Comet delegates only its arithmetic core and retains distractors, seeded shuffle, and lane selection")

	var math_swipe = MathSwipe.new()
	var callers_match_legacy := true
	for level in [1, 4, 7, 10, 15]:
		for seed in [1, 2, 3, 11, 29, 47, 83, 1337, 90210, 25026]:
			var expected_rng := RandomNumberGenerator.new()
			var actual_rng := RandomNumberGenerator.new()
			expected_rng.seed = seed
			actual_rng.seed = seed
			if math_swipe.generate_problem(level, actual_rng) != _legacy_math_swipe_problem(level, expected_rng):
				callers_match_legacy = false
			var expected_comet_rng := RandomNumberGenerator.new()
			var actual_comet_rng := RandomNumberGenerator.new()
			expected_comet_rng.seed = seed
			actual_comet_rng.seed = seed
			if CometMathRescue.generate_problem(level, actual_comet_rng) != _legacy_comet_problem(level, expected_comet_rng):
				callers_match_legacy = false
	_check(callers_match_legacy, "Math Swipe and Comet seeded public problem dictionaries exactly match their committed legacy generators across representative levels and seeds")
	math_swipe.free()

	var core_arithmetic_valid := true
	var exact_divisions := 0
	for level in [1, 4, 7, 10, 15]:
		for seed in range(1, 81):
			var math_rng := RandomNumberGenerator.new()
			math_rng.seed = seed
			var math_core := EquationGenerator.math_swipe_core(level, math_rng)
			if not _core_equation_is_valid(math_core):
				core_arithmetic_valid = false
			var comet_rng := RandomNumberGenerator.new()
			comet_rng.seed = seed
			var comet_core := EquationGenerator.comet_math_rescue_core(level, comet_rng)
			if not _core_equation_is_valid(comet_core):
				core_arithmetic_valid = false
			if comet_core.get("operation") == "/":
				exact_divisions += 1
				if int(comet_core.get("right", 0)) == 0 or int(comet_core.get("left", 0)) % int(comet_core.get("right", 1)) != 0:
					core_arithmetic_valid = false
	_check(core_arithmetic_valid and exact_divisions > 0, "equation cores return only valid arithmetic and Comet division remains exact across seeded mixed-operation coverage")


func _core_equation_is_valid(core: Dictionary) -> bool:
	if core.size() != 4 or not core.has_all(["left", "right", "operation", "answer"]):
		return false
	var left := int(core["left"])
	var right := int(core["right"])
	var answer := int(core["answer"])
	match str(core["operation"]):
		"+": return answer == left + right
		"-": return answer == left - right
		"x", "×": return answer == left * right
		"/": return right != 0 and left % right == 0 and answer == left / right
	return false


func _legacy_math_swipe_problem(for_level: int, rng: RandomNumberGenerator) -> Dictionary:
	var operation := "+"
	var num1 := 0
	var num2 := 0
	var answer := 0
	if for_level <= 3:
		num1 = rng.randi_range(1, 8)
		num2 = rng.randi_range(1, 8)
		answer = num1 + num2
	elif for_level <= 6:
		operation = "-"
		answer = rng.randi_range(1, 8)
		num2 = rng.randi_range(1, answer)
		num1 = answer + num2
	elif for_level <= 10:
		operation = "+" if rng.randf() > 0.5 else "-"
		if operation == "+":
			num1 = rng.randi_range(5, 19)
			num2 = rng.randi_range(5, 19)
			answer = num1 + num2
		else:
			answer = rng.randi_range(5, 19)
			num2 = rng.randi_range(1, answer)
			num1 = answer + num2
	else:
		var choice := rng.randf()
		if choice < 0.4:
			operation = "×"
			num1 = rng.randi_range(2, 11)
			num2 = rng.randi_range(2, 11)
			answer = num1 * num2
		elif choice < 0.7:
			num1 = rng.randi_range(10, 29)
			num2 = rng.randi_range(10, 29)
			answer = num1 + num2
		else:
			operation = "-"
			answer = rng.randi_range(10, 29)
			num2 = rng.randi_range(1, answer)
			num1 = answer + num2
	var missing := rng.randi_range(0, 2)
	var correct: int = [num1, num2, answer][missing]
	var display := "? %s %d = %d" % [operation, num2, answer]
	if missing == 1:
		display = "%d %s ? = %d" % [num1, operation, answer]
	elif missing == 2:
		display = "%d %s %d = ?" % [num1, operation, num2]
	var wrong: int = correct
	while wrong == correct or wrong < 0:
		var offset := rng.randi_range(-3, 3)
		wrong = correct + (1 if offset == 0 else offset)
	return {"display": display, "correct": correct, "wrong": wrong, "operation": operation}


func _legacy_comet_problem(for_level: int, generator: RandomNumberGenerator) -> Dictionary:
	var operation := "+"
	if for_level >= 10:
		operation = ["+", "-", "x", "/"][generator.randi_range(0, 3)]
	elif for_level >= 7:
		operation = "x"
	elif for_level >= 4:
		operation = "-"
	var left := 0
	var right := 0
	var answer := 0
	match operation:
		"+":
			left = generator.randi_range(1, 4 + mini(8, for_level))
			right = generator.randi_range(1, 4 + mini(8, for_level))
			answer = left + right
		"-":
			right = generator.randi_range(1, 3 + mini(7, for_level))
			left = right + generator.randi_range(0, 4 + mini(8, for_level))
			answer = left - right
		"x":
			left = generator.randi_range(2, 3 + mini(6, for_level / 2))
			right = generator.randi_range(2, 3 + mini(5, for_level / 2))
			answer = left * right
		"/":
			right = generator.randi_range(2, 3 + mini(6, for_level / 2))
			answer = generator.randi_range(2, 3 + mini(7, for_level / 2))
			left = right * answer
	var answers: Array[int] = [answer]
	var step := maxi(1, mini(8, 1 + for_level / 3))
	for offset in [-2, -1, 1, 2, 3]:
		var distractor := maxi(0, answer + offset * step)
		if distractor != answer and not distractor in answers:
			answers.append(distractor)
		if answers.size() == 3:
			break
	while answers.size() < 3:
		var fallback := answer + answers.size() * step + 1
		if not fallback in answers:
			answers.append(fallback)
	for index in range(answers.size() - 1, 0, -1):
		var swap_index := generator.randi_range(0, index)
		var swap := answers[index]
		answers[index] = answers[swap_index]
		answers[swap_index] = swap
	return {"left": left, "right": right, "operation": operation, "answer": answer, "answers": answers, "correct_index": answers.find(answer)}


func _test_money_counter_base() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/games/money_counter_base.gd")
	var coin_source := FileAccess.get_file_as_string("res://scripts/games/coin_count.gd")
	var cash_source := FileAccess.get_file_as_string("res://scripts/games/cash_counter.gd")
	_check(not source.contains("StorybookUI") and not source.contains("Label") and not source.contains("Button") and not source.contains("Texture") and not source.contains("COINS") and not source.contains("BILLS") and not source.contains("AppState"), "money counter base owns state and decisions without UI, art, copy, or profile dependencies")
	_check(coin_source.begins_with("extends \"res://scripts/games/money_counter_base.gd\"") and cash_source.begins_with("extends \"res://scripts/games/money_counter_base.gd\"") and not coin_source.contains("\nvar level :=") and not cash_source.contains("\nvar level :="), "Coin Count and Cash Counter are presentation/configuration facades over the shared state fields")
	_check(coin_source.contains("func _add_coin(value: int)") and coin_source.contains("func _start_round_with_lifecycle(begin_run: bool)") and not coin_source.contains("static func target_bounds(for_level: int)") and cash_source.contains("func _add_bill(value: int)") and cash_source.contains("func _start_round_with_lifecycle(begin_run: bool)") and cash_source.contains("static func target_bounds(for_level: int)") and cash_source.contains("var bounds := target_bounds(level)"), "money facades preserve live helpers, remove Coin Count's dead bounds helper, and retain Cash Counter's used target bounds")
	var ignored := MoneyCounterBase.money_transition(false, 10, 20, 5)
	var progress := MoneyCounterBase.money_transition(true, 10, 20, 5)
	var exact := MoneyCounterBase.money_transition(true, 10, 20, 10)
	var overshoot := MoneyCounterBase.money_transition(true, 10, 20, 11)
	_check(ignored == {"outcome": "ignored", "total": 10} and progress == {"outcome": "progress", "total": 15} and exact == {"outcome": "exact", "total": 20} and overshoot == {"outcome": "overshoot", "total": 21}, "money transition is inactive-idempotent and distinguishes progress, exact completion, and overshoot")
	_check(MoneyCounterBase.best_fitting_denomination([25, 1, 10, 5], 12) == 10 and MoneyCounterBase.best_fitting_denomination([100, 20, 5, 50], 49) == 20 and MoneyCounterBase.best_fitting_denomination([5, 10], 3) == 0, "best-fitting denomination is order-independent and never exceeds the remaining amount")
	var counter := MoneyCounterBase.new()
	counter.configure_money_counter("coin_count", [1, 5, 10, 25])
	counter.target = 36
	counter.total = 12
	_check(counter.money_game_id == "coin_count" and counter.money_denominations == [1, 5, 10, 25] and counter.call("_best_fitting_denomination") == 10, "configured base retains game identity and derives its hint from shared counter state")
	counter.free()


func _choice_correct_payload(game_id: String, current: Dictionary, options: Array):
	match game_id:
		"missing_magic", "prefix_potion", "caption_quest", "opposite_orbit":
			return current.get("answer", "")
		"vowel_vines":
			for option in options:
				var payload := str(option.get("payload", ""))
				if payload.left(1).to_lower() == str(current.get("vowel", "")):
					return option.get("payload")
		"odd_one_out":
			return current.get("odd", "")
		"chain_link":
			for option in options:
				var payload := str(option.get("payload", ""))
				if WordRules.is_chain_link(str(current.get("start", "")), payload):
					return option.get("payload")
	return ""


func _test_word_sequence_strategy() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/games/word_sequence_strategy.gd")
	_check(not source.contains("AppState") and not source.contains("ArcadeGameController") and not source.contains("StorybookUI") and not source.contains("GameRegistry"), "sequence strategy stays inside Rules and RoundCatalog data boundaries")
	var strategy := WordSequenceStrategy.new()
	var supported := ["sentence_sprout", "syllable_stamp", "scramble_spell", "size_line_up"]
	_check(strategy.family() == "sequence" and supported.all(func(game_id: String) -> bool: return strategy.supports(game_id)) and not strategy.supports("missing_magic") and strategy.begin_round({"game_id": "missing_magic"}) == {"handled": false}, "sequence strategy exposes exactly the ordered-mode IDs and safe fallback")
	for game_id in supported:
		var rng := RandomNumberGenerator.new()
		rng.seed = 1337
		var round := strategy.begin_round({"game_id": game_id, "level": 1, "round_index": 0, "rng": rng})
		var current: Dictionary = round.get("current", {})
		var sequence: Array = round.get("sequence", [])
		var pool: Array = round.get("pool", [])
		_check(bool(round.get("handled", false)) and bool(round.get("ok", false)) and not current.is_empty() and not sequence.is_empty() and not pool.is_empty() and not str(round.get("phase", "")).is_empty() and not str(round.get("instruction", "")).is_empty(), "%s begins with a renderable ordered-round contract" % game_id)
		var context := {"game_id": game_id, "current": current, "sequence": sequence, "pool": pool, "picked": []}
		var sequence_before := sequence.duplicate(true)
		var pool_before := pool.duplicate(true)
		var first_value = sequence[0]
		var first_index := pool.find(first_value)
		var hint_a := strategy.hint(context)
		var hint_b := strategy.hint(context)
		_check(hint_a == hint_b and str(hint_a.get("next", "")) == str(first_value) and sequence == sequence_before and pool == pool_before, "%s hint reads only the current sequence and picks without reordering" % game_id)
		var failed := strategy.submit(context, {"value": "__wrong_sequence__", "index": -1})
		var continued := strategy.submit(context, {"value": first_value, "index": first_index})
		var expected_pool := pool.duplicate()
		if first_index >= 0:
			expected_pool.remove_at(first_index)
		_check(failed.get("outcome") == "failure" and continued.get("outcome") == ("success" if sequence.size() == 1 else "continue") and continued.get("picked") == [first_value] and continued.get("pool") == expected_pool and pool == pool_before, "%s submit returns immutable failure/continue state with exact index removal" % game_id)
		var final_value = sequence[sequence.size() - 1]
		var final_result := strategy.submit({"game_id": game_id, "sequence": sequence, "pool": [final_value], "picked": sequence.slice(0, sequence.size() - 1)}, {"value": final_value, "index": 0})
		_check(final_result.get("outcome") == "success" and final_result.get("picked") == sequence and (final_result.get("pool") as Array).is_empty(), "%s submit completes only after the final ordered item" % game_id)
	var saved_cache := WordRules._cache.duplicate(true)
	WordRules._cache = {"sentence_build": []}
	var empty_rng := RandomNumberGenerator.new()
	_check(not bool(strategy.begin_round({"game_id": "sentence_sprout", "level": 1, "round_index": 0, "rng": empty_rng}).get("ok", true)), "sequence strategy reports an invalid round when its source is empty")
	WordRules._cache = saved_cache
	_check(strategy.failure_reason({"game_id": "sentence_sprout"}) == "Tap words in the right order!" and strategy.failure_reason({"game_id": "size_line_up"}) == "Tap shortest word first, then longer ones!", "sequence strategy preserves the exact failure copy")


func _test_word_typed_entry_strategy() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/games/word_typed_entry_strategy.gd")
	_check(not source.contains("AppState") and not source.contains("ArcadeGameController") and not source.contains("StorybookUI") and not source.contains("GameRegistry"), "typed-entry strategy stays inside Rules and RoundCatalog data boundaries")
	var strategy := WordTypedEntryStrategy.new()
	_check(strategy.family() == "typed_entry" and strategy.supports("sight_spark") and strategy.supports("letter_lift") and not strategy.supports("sentence_sprout") and strategy.begin_round({"game_id": "sentence_sprout"}) == {"handled": false}, "typed-entry strategy exposes exactly the two typed mode IDs and safe fallback")
	for game_id in ["sight_spark", "letter_lift"]:
		var round := strategy.begin_round({"game_id": game_id, "level": 1, "round_index": 0})
		var expected_word := str(round.get("expected_word", ""))
		_check(bool(round.get("handled", false)) and bool(round.get("ok", false)) and not expected_word.is_empty() and not str(round.get("phase", "")).is_empty() and not str(round.get("instruction", "")).is_empty(), "%s begins with an expected word and typed presentation contract" % game_id)
		var hint_context := {"game_id": game_id, "expected_word": expected_word, "phase": round.get("phase", ""), "picked": []}
		_check(strategy.hint(hint_context) == strategy.hint(hint_context) and str(hint_context.get("expected_word", "")) == expected_word, "%s hint derives from current typed state without repicking" % game_id)
	var sight_round := strategy.begin_round({"game_id": "sight_spark", "level": 1, "round_index": 0})
	var sight_word := str(sight_round.get("expected_word", ""))
	var sight_transition := strategy.tick({"game_id": "sight_spark", "expected_word": sight_word, "phase": "flash", "hint_visible": false, "flash_expired": true}, 0.0)
	var sight_success := strategy.submit({"game_id": "sight_spark", "expected_word": sight_word, "phase": "type"}, ("  %s  " % sight_word).to_upper())
	var sight_failure := strategy.submit({"game_id": "sight_spark", "expected_word": sight_word, "phase": "type"}, "__wrong_word__")
	_check(sight_transition.get("phase") == "type" and sight_transition.get("prompt") == "?" and sight_success.get("outcome") == "success" and sight_failure.get("outcome") == "failure", "Sight Spark keeps flash transition plus whitespace/case-insensitive submitted-word outcomes")
	var letter_round := strategy.begin_round({"game_id": "letter_lift", "level": 1, "round_index": 0})
	var letter_word := str(letter_round.get("expected_word", ""))
	var first_letter := letter_word.substr(0, 1)
	var first_result := strategy.submit({"game_id": "letter_lift", "expected_word": letter_word, "picked": []}, first_letter.to_upper())
	var backspace_result := strategy.submit({"game_id": "letter_lift", "expected_word": letter_word, "picked": first_result.get("picked", [])}, "")
	var final_result := strategy.submit({"game_id": "letter_lift", "expected_word": letter_word, "picked": letter_word.split("", false).slice(0, letter_word.length() - 1)}, letter_word)
	_check(first_result.get("outcome") == "continue" and first_result.get("input") == first_letter and backspace_result.get("outcome") == "ignored" and backspace_result.get("input") == first_letter and final_result.get("outcome") == "success" and final_result.get("input") == letter_word, "Letter Lift preserves lowercase input normalization, backspace reset, and final-letter success")
	var saved_cache := WordRules._cache.duplicate(true)
	WordRules._cache = {"falling_words": {"easy": []}}
	_check(not bool(strategy.begin_round({"game_id": "sight_spark", "level": 1, "round_index": 0}).get("ok", true)), "typed-entry strategy reports an invalid round when its word source is empty")
	WordRules._cache = saved_cache
	_check(strategy.failure_reason({"game_id": "sight_spark"}) == "Spell the spark word from memory!" and strategy.failure_reason({"game_id": "letter_lift"}) == "Type each letter in order!", "typed-entry strategy preserves the exact failure copy")
