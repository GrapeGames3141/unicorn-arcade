extends SceneTree

const RewardServiceScript = preload("res://autoload/reward_service.gd")
const GameRegistryScript = preload("res://autoload/game_registry.gd")
const SaveServiceScript = preload("res://autoload/save_service.gd")
const WordRules = preload("res://scripts/games/word_game_rules.gd")
const GameplayRules = preload("res://scripts/games/gameplay_rules.gd")
const MetaCatalog = preload("res://scripts/meta_catalog.gd")
const RoomRules = preload("res://scripts/room_rules.gd")
const TutorialCatalog = preload("res://scripts/tutorial_catalog.gd")
const CompanionAbilityScript = preload("res://autoload/companion_ability_service.gd")
const CompanionAssets = preload("res://scripts/meta/companion_asset_catalog.gd")
const ProfileComponents = preload("res://scripts/ui/profile_view_components.gd")
const AdRecoveryPolicy = preload("res://scripts/platform/ad_banner_recovery_policy.gd")
const WordRoundCatalog = preload("res://scripts/games/word_round_catalog.gd")
const UNICORN_IMPORTS := {
	"sparkle": {"path": "res://assets/characters/unicorns/unicorn_sparkle_v1.glb"},
	"rainbow": {"path": "res://assets/characters/unicorns/unicorn_rainbow_v1.glb"},
	"star": {"path": "res://assets/characters/unicorns/unicorn_star_v1.glb"},
	"cloud": {"path": "res://assets/characters/unicorns/unicorn_cloud_v1.glb"},
	"dream": {"path": "res://assets/characters/unicorns/unicorn_dreamer_v1.glb"},
	"mystic": {"path": "res://assets/characters/unicorns/unicorn_mystic_v1.glb"},
}

var failures: Array[String] = []
var check_count := 0


func _init() -> void:
	var rewards = RewardServiceScript.new()
	var registry = GameRegistryScript.new()
	var saves = SaveServiceScript.new()
	_check(not bool(ProjectSettings.get_setting("application/config/auto_accept_quit", true)) and not bool(ProjectSettings.get_setting("application/config/quit_on_go_back", true)), "Android Back is configured to emit route notifications instead of quitting")
	_check(rewards.level_reward(1) == 15, "level 1 reward is 15")
	_check(rewards.level_reward(10) == 60, "level 10 reward is 60")
	_check(rewards.hint_cost(1) == 0, "level 1 hints are free")
	_check(rewards.hint_cost(2) == 5, "paid hint cost is 5")
	_check(registry.all_games().size() == 26, "registry contains 26 games")
	_check(registry.games_in_category("Number").size() == 7, "number category contains 7 games")
	_check(registry.games_in_category("Word").size() == 10, "word category contains 10 games")
	_check(registry.games_in_category("Mystery").size() == 6, "mystery category contains 6 games")
	_check(registry.games_in_category("Arcade").size() == 3, "arcade category contains 3 games")
	_check(registry.playable_games().size() == 26, "all 26 games are playable")
	_check(registry.playable_count("Number") == 7, "all seven number games are playable")
	_check(registry.playable_count("Word") == 10, "all ten word games are playable")
	_check(registry.playable_count("Mystery") == 6, "all six mystery games are playable")
	_check(registry.playable_count("Arcade") == 3, "all three arcade games are playable")
	_check(ResourceLoader.exists("res://scenes/games/comet_math_rescue.tscn"), "Comet Math Rescue scene is present")
	var registered_ids: Array = registry.all_games().map(func(game: Dictionary): return game["id"])
	_check(TutorialCatalog.covers_all(registered_ids), "all 26 games provide three guided tutorial levels")
	_check(CompanionAbilityScript.ABILITIES.size() == 6, "all six unicorns have exactly one universal companion ability")
	_check(is_equal_approx(ProfileComponents.category_progress([{"id":"a"},{"id":"b"}], func(id: String) -> int: return 21 if id == "a" else 1), 0.5) and ProfileComponents.category_runs([{"id":"a"}], func(_id: String) -> Dictionary: return {"completed":[1,2]} ) == 2, "profile component aggregates explicit level and progress callbacks")
	var penny_texture := load("res://assets/games/currency/penny.png") as Texture2D
	_check(ProfileComponents.stat("4", "RUNS") is PanelContainer and ProfileComponents.money_stat(12, "COINS", penny_texture) is PanelContainer, "profile component builders return reusable panel controls")
	_check(AdRecoveryPolicy.is_stale(true, false, -3463, 4538, 8000) and not AdRecoveryPolicy.is_stale(true, false, 4538, 4538, 8000) and AdRecoveryPolicy.needs_recovery(false, true, false, 0, 0, 8000), "ad recovery policy handles negative early-start timestamps and missing views")
	_check(WordRoundCatalog.word_for_round(["a","b"], 1, 2) == "b" and WordRoundCatalog.vowel_for_round(["a","e"], 1, 2) == "e", "word round catalog preserves modular round selection")
	var sequence_round := WordRoundCatalog.sequence_round({"items": ["sun", "moon", "star"]}, "items")
	_check(sequence_round["sequence"] == ["sun", "moon", "star"] and sequence_round["pool"].size() == 3 and "sun" in sequence_round["pool"] and "moon" in sequence_round["pool"] and "star" in sequence_round["pool"], "word sequence preparation preserves source order and creates a complete shuffled pool")
	var vowel_rng := RandomNumberGenerator.new()
	vowel_rng.seed = 4
	var vowel_round := WordRoundCatalog.vowel_round({"vowel_words": {"a": ["ant"], "e": ["eel"], "i": ["ink"], "o": ["owl"]}}, ["a", "e", "i", "o"], 0, 0, vowel_rng)
	_check(vowel_round["vowel"] == "a" and "ant" in vowel_round["choices"] and vowel_round["choices"].size() == 4 and "eel" in vowel_round["choices"] and "ink" in vowel_round["choices"] and "owl" in vowel_round["choices"], "vowel preparation builds four unique choices including the selected vowel word")
	_check(CompanionAssets.MODEL_PATHS.size() == 6 and CompanionAssets.MODEL_PATHS.values().all(func(path: String) -> bool: return path.begins_with("res://assets/characters/unicorns/") and path.ends_with(".glb")), "companion catalog retains six lazy GLB paths without eager PackedScene constants")
	_check(CompanionAssets.THUMBNAIL_PATHS.size() == 6 and CompanionAssets.THUMBNAIL_PATHS.values().all(func(path: String) -> bool: return ResourceLoader.exists(path)), "static companion chrome has checked-in thumbnail paths")
	_check(_validate_companion_texture_imports(), "companion texture imports use 2K mipmapped VRAM settings with normal-map handling")
	_check(_validate_game_controller_contract(), "every distinct registered game scene implements ArcadeGameController")
	_check(CompanionAbilityScript.ABILITIES["rainbow"]["description"] == "Gives a chance at bonus coins.", "bonus coin power uses child-friendly copy")
	_check(CompanionAbilityScript.ABILITIES.values().all(func(ability: Dictionary) -> bool: return not str(ability["description"]).contains("%") and not str(ability["description"]).contains("seconds")), "companion power descriptions avoid percentages and timing jargon")
	_check(GameplayRules.math_swipe_target(1) == 3 and GameplayRules.math_swipe_target(10) == 8, "Math Swipe target formula matches React")
	_check(GameplayRules.jump_path_length(3) == 20, "Unicorn Jump path length matches React")
	_check(GameplayRules.jump_max(2) == 3 and GameplayRules.jump_max(3) == 4 and GameplayRules.jump_max(6) == 6, "Unicorn Jump bands match React")
	_check(GameplayRules.jump_negative_max(14) == 0 and GameplayRules.jump_negative_max(15) == 2 and GameplayRules.jump_negative_max(25) == 5, "Unicorn Jump trick bands match React")
	_check(GameplayRules.sliding_length(5) == 15 and GameplayRules.sliding_length(6) == 20, "Sliding Window track length matches React")
	_check(GameplayRules.sliding_bounds(6) == Vector2i(-100, 100), "Sliding Window late number range matches React")
	_check(GameplayRules.sliding_window(1) == 3 and GameplayRules.sliding_window(6) == 5, "Sliding Window size formula matches React")
	_check(GameplayRules.rival_move_ms(1) == 2500 and GameplayRules.rival_move_ms(20) == 1000, "Sliding Window rival speed floor matches React")
	_check(GameplayRules.galaxy_target(1) == 10 and GameplayRules.galaxy_target(5) == 20, "Galaxy target formula matches React")
	_check(GameplayRules.galaxy_fire_ms(20) == 120 and GameplayRules.galaxy_spawn_ms(20) == 600, "Galaxy timing floors match React")
	_check(is_equal_approx(GameplayRules.galaxy_enemy_speed_scale(1), 0.16), "Galaxy enemies begin at a deliberately gentle early-game pace")
	_check(
		GameplayRules.galaxy_enemy_speed_scale(5) > GameplayRules.galaxy_enemy_speed_scale(1)
		and GameplayRules.galaxy_enemy_speed_scale(12) > GameplayRules.galaxy_enemy_speed_scale(5)
		and is_equal_approx(GameplayRules.galaxy_enemy_speed_scale(21), 1.0),
		"Galaxy enemy speed rises gradually by level and reaches its safe cap"
	)
	_check(is_equal_approx(GameplayRules.galaxy_fall_frame_factor(), 36.0), "Galaxy fall factor stays below the old React dive pace")
	_check(GameplayRules.mathtris_drop_ms(1) == 950 and GameplayRules.mathtris_drop_ms(50, 99, 99) == 90, "Mathtris drop curve and floor match React")
	_check(GameplayRules.mathtris_concurrent(0, 1) == 1 and GameplayRules.mathtris_concurrent(70, 1) == 3 and GameplayRules.mathtris_concurrent(150, 12) == 5, "Mathtris concurrency curve matches React")
	_check(GameplayRules.mathtris_allowed(10) == ["1", "2", "+", "="], "Mathtris basics token set matches React")
	_check("3" in GameplayRules.mathtris_allowed(11) and "4" in GameplayRules.mathtris_allowed(13) and "5" in GameplayRules.mathtris_allowed(16), "Mathtris digit unlocks match React")
	_check("-" not in GameplayRules.mathtris_allowed(23) and "-" in GameplayRules.mathtris_allowed(24), "Mathtris subtraction unlock matches React")
	_check(GameplayRules.equation_valid(["1", "+", "1", "=", "2"]), "Mathtris accepts forward equations")
	_check(GameplayRules.equation_valid(["2", "=", "1", "+", "1"]), "Mathtris accepts reverse equations")
	_check(not GameplayRules.equation_valid(["2", "+", "2", "=", "5"]), "Mathtris rejects invalid equations")
	_check(MetaCatalog.companions().size() == 6, "all six companion definitions were extracted")
	_check(MetaCatalog.furniture().size() == 107, "all 107 decor definitions were extracted")
	_check(MetaCatalog.categories().size() == 15, "all decor category filters were extracted")
	_check(MetaCatalog.filtered_furniture("beds", "").size() == 6, "decor category filtering matches the catalog")
	_check(RoomRules.sell_refund(151) == 75, "decor resale refunds floor at fifty percent")
	_check(RoomRules.snap(51.0, true) == 48.0 and RoomRules.snap(51.0, false) == 51.0, "room grid snapping uses eight-percent steps")
	var normalized := RoomRules.normalized({"instanceId": "legacy", "itemId": "lamp", "zIndex": 3})
	_check(normalized["x"] == 50.0 and normalized["rotation"] == 0, "room placements receive stable defaults")
	var reordered := RoomRules.reorder([{"instance_id": "a", "z_index": 1}, {"instance_id": "b", "z_index": 2}], "a", "front")
	_check(reordered[1]["instance_id"] == "a", "room layer ordering swaps adjacent z positions")
	var defaults: Dictionary = saves.default_state()
	var new_profile: Dictionary = saves.default_profile()
	_check(new_profile["player"]["coins"] == 1000, "new players start with 1000 coins")
	_check(new_profile["owned_companions"] == ["sparkle"], "new players own Sparkle")
	_check(new_profile["inventory"].get("companion_sparkle", 0) == 1, "Sparkle includes one placeable room gift")
	_check(new_profile["settings"]["reduced_motion"] == false, "reduced motion defaults off")
	_check(defaults["version"] == 5 and defaults["users"].is_empty(), "save v5 starts as a named-profile envelope")
	var migrated: Dictionary = saves.call("_migrate", {"version": 3, "player": {"name": "Learner", "coins": 25, "equipped_companion": "sparkle"}, "progress": {"unicorn_jump": {"max_level": 4, "completed": []}}})
	_check(migrated["version"] == 5 and migrated["users"].has("learner") and migrated["users"]["learner"]["profile"]["player"]["coins"] == 25, "save migration preserves the v4-compatible player profile in v5")
	var react_migrated: Dictionary = saves.call("_normalize_profile", {"coins": 77, "ownedUnicorns": ["sparkle", "rainbow"], "equippedUnicorn": "rainbow", "furniture": {"inventory": {"lamp": 2}, "placements": {"rainbow": [{"instanceId": "r1", "itemId": "lamp", "zIndex": 4}]}}})
	# React payloads are imported user-by-user by the bridge; this also verifies the
	# shared profile normalizer accepts its aliases without silently dropping rooms.
	var react_profile: Dictionary = saves.call("_normalize_profile", react_migrated)
	_check(react_profile["rooms"].get("rainbow", [])[0]["instance_id"] == "r1" and react_profile["player"]["equipped_companion"] == "rainbow" and "rainbow" in react_profile["owned_companions"], "actual React seed aliases normalize rooms and unicorn ownership")
	saves._envelope = {"version": 5, "last_user": "learner", "users": {"learner": {"display_name": "Learner", "profile": new_profile}}}
	saves._active_key = ""
	_check(not saves.save_state(saves.default_profile()) and saves._envelope["users"].has("learner"), "signed-out state cannot overwrite an existing profile")
	_check(ResourceLoader.exists("res://assets/games/currency/penny.png") and ResourceLoader.exists("res://assets/games/currency/one_hundred_dollar.png"), "real US coin and bill learning art is packaged")
	_check(_validate_unicorn_imports(), "all six updated textured unicorn GLBs expose their production rig and only the Walk animation")
	_check(WordRules.target_for_level(1) == 4, "word target formula starts at four rounds")
	_check(WordRules.target_for_level(5) == 9, "word target formula scales at level five")
	_check(WordRules.target_for_level(20) == 12, "word target formula caps at twelve")
	_check(WordRules.caption_target(20) == 4, "Caption Quest caps at four scenes")
	_check(WordRules.odd_one_out_target(3) == 6, "Odd One Out caps at six cases")
	_check(WordRules.selection_window(20, 1) == Vector2i(0, 4), "difficulty window begins with four easy records")
	_check(WordRules.selection_window(20, 10) == Vector2i(6, 15), "difficulty window slides with level and round")
	_check(WordRules.words_for_level(3).size() == 30, "easy word pool is active through level three")
	_check(WordRules.words_for_level(4).size() == 32, "medium word pool begins at level four")
	_check(WordRules.words_for_level(9).size() == 27, "hard word pool begins at level nine")
	_check(WordRules.words_for_level(15).size() == 21, "expert word pool begins at level fifteen")
	_check(WordRules.sight_flash_ms(1) == 2120, "Sight Spark level-one flash duration matches React")
	_check(WordRules.sight_flash_ms(18) == 800, "Sight Spark flash duration floors at 800 ms")
	_check(is_equal_approx(WordRules.blast_speed(1), 0.083) and WordRules.blast_speed(12) > WordRules.blast_speed(1), "Unicorn Blast begins with a gentler fall curve while retaining progression")
	_check(WordRules.blast_spawn_ms(1) == 2680, "Unicorn Blast spawn formula matches level one")
	_check(WordRules.blast_spawn_ms(20) == 1400, "Unicorn Blast spawn interval floors at 1400 ms")
	_check(WordRules.is_chain_link("cat", "top"), "Chain Link accepts the last-to-first letter rule")
	_check(not WordRules.is_chain_link("cat", "dog"), "Chain Link rejects a mismatched first letter")
	var word_data := WordRules.data()
	_check(word_data.get("sentence_build", []).size() == 20, "all Sentence Sprout records were extracted")
	_check(word_data.get("missing_word", []).size() == 18, "all Missing Magic records were extracted")
	_check(word_data.get("prefix_mix", []).size() == 18, "all Prefix Potion records were extracted")
	_check(word_data.get("caption_scenes", []).size() == 14, "all Caption Quest records were extracted")
	_check(word_data.get("opposite_challenges", []).size() == 22, "all Opposite Orbit records were extracted")
	_check(word_data.get("scramble_puzzles", []).size() == 27, "all Scramble Spell records were extracted")
	_check(word_data.get("odd_one_out", []).size() == 14, "all Odd One Out records were extracted")
	_check(word_data.get("size_lineups", []).size() == 16, "all Size Line-Up records were extracted")
	_check(word_data.get("chain_links", []).size() == 17, "all Chain Link records were extracted")
	_check(WordRules.cash_target_bounds(1) == Vector2i(1, 20), "Cash Counter early target band matches React")
	_check(WordRules.cash_target_bounds(4) == Vector2i(20, 99), "Cash Counter middle target band matches React")
	_check(WordRules.cash_target_bounds(9) == Vector2i(100, 999), "Cash Counter late target band matches React")
	rewards.free()
	registry.free()
	saves.free()
	if failures.is_empty():
		print("GODOT_PARITY_TESTS_OK: %d checks passed" % check_count)
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _check(condition: bool, message: String) -> void:
	check_count += 1
	if not condition:
		failures.append(message)


func _validate_unicorn_imports() -> bool:
	var valid := true
	for companion_id in UNICORN_IMPORTS:
		var definition: Dictionary = UNICORN_IMPORTS[companion_id]
		var scene = load(str(definition["path"]))
		if scene == null or not scene is PackedScene:
			print("UNICORN_IMPORT_FAIL id=%s scene_load=false" % companion_id)
			valid = false
			continue
		var instance: Node = scene.instantiate()
		var skeleton := _find_skeleton(instance)
		var animation_player := _find_animation_player(instance)
		if skeleton == null or skeleton.get_bone_count() < 38 or animation_player == null:
			print("UNICORN_IMPORT_FAIL id=%s skeleton=%s bones=%d player=%s" % [companion_id, skeleton != null, skeleton.get_bone_count() if skeleton != null else 0, animation_player != null])
			instance.free()
			valid = false
			continue
		var animation_names := PackedStringArray()
		var animation_keys := {}
		for animation_name in animation_player.get_animation_list():
			var normalized_name := String(animation_name).get_file().get_basename().to_lower()
			animation_names.append(normalized_name)
			animation_keys[normalized_name] = animation_name
		var expected := ["walk"]
		var mesh_count := _count_meshes(instance)
		var textured_surfaces := _count_textured_surfaces(instance)
		print("UNICORN_IMPORT id=%s bones=%d meshes=%d textured=%d clips=%s" % [companion_id, skeleton.get_bone_count(), mesh_count, textured_surfaces, ",".join(animation_names)])
		for expected_name in expected:
			if expected_name not in animation_names:
				print("UNICORN_IMPORT_FAIL id=%s missing_clip=%s" % [companion_id, expected_name])
				valid = false
				continue
			animation_player.play(animation_keys[expected_name])
			animation_player.advance(0.1)
			if String(animation_player.current_animation).get_file().get_basename().to_lower() != expected_name:
				print("UNICORN_IMPORT_FAIL id=%s unplayable_clip=%s" % [companion_id, expected_name])
				valid = false
		if animation_names.size() != 1:
			print("UNICORN_IMPORT_FAIL id=%s expected_walk_only clips=%s" % [companion_id, ",".join(animation_names)])
			valid = false
		if mesh_count < 1 or textured_surfaces < 1:
			valid = false
		instance.free()
	return valid


func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node as Skeleton3D
	for child in node.get_children():
		var found := _find_skeleton(child)
		if found != null:
			return found
	return null


func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for child in node.get_children():
		var found := _find_animation_player(child)
		if found != null:
			return found
	return null


func _count_textured_surfaces(node: Node) -> int:
	var count := 0
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		for surface in mesh_instance.mesh.get_surface_count():
			var material := mesh_instance.get_active_material(surface) as StandardMaterial3D
			if material != null and material.albedo_texture != null:
				count += 1
	for child in node.get_children():
		count += _count_textured_surfaces(child)
	return count


func _count_meshes(node: Node) -> int:
	var count := 1 if node is MeshInstance3D else 0
	for child in node.get_children():
		count += _count_meshes(child)
	return count


func _validate_companion_texture_imports() -> bool:
	var directory := DirAccess.open("res://assets/characters/unicorns")
	if directory == null:
		return false
	var valid := true
	var relevant_count := 0
	var normal_count := 0
	for filename in directory.get_files():
		if not filename.ends_with(".import") or not (filename.contains("base") or filename.contains("normal") or filename.contains("emissive") or filename.contains("emit") or filename.contains("roughness")):
			continue
		relevant_count += 1
		var file := FileAccess.open("res://assets/characters/unicorns/%s" % filename, FileAccess.READ)
		if file == null:
			return false
		var contents := file.get_as_text()
		file.close()
		if not contents.contains("compress/mode=2") or not contents.contains("mipmaps/generate=true") or not contents.contains("mipmaps/limit=-1") or not contents.contains("process/size_limit=2048"):
			valid = false
		if filename.contains("normal"):
			normal_count += 1
			if not contents.contains("compress/normal_map=1"):
				valid = false
	return valid and relevant_count == 24 and normal_count == 6


func _validate_game_controller_contract() -> bool:
	var checked_scenes := {}
	for game in GameRegistryScript.GAMES:
		var scene_path := str(game.get("scene", ""))
		if scene_path.is_empty() or checked_scenes.has(scene_path):
			continue
		checked_scenes[scene_path] = true
		var scene_file := FileAccess.open(scene_path, FileAccess.READ)
		if scene_file == null:
			return false
		var scene_contents := scene_file.get_as_text()
		scene_file.close()
		var path_prefix := "path=\"res://scripts/games/"
		var path_start := scene_contents.find(path_prefix)
		if path_start < 0:
			return false
		path_start += "path=\"".length()
		var path_end := scene_contents.find("\"", path_start)
		if path_end < 0:
			return false
		if not _script_extends_arcade_controller(scene_contents.substr(path_start, path_end - path_start)):
			return false
	return checked_scenes.size() == 13


func _script_extends_arcade_controller(script_path: String, visited := {}) -> bool:
	if visited.has(script_path):
		return false
	visited[script_path] = true
	var script_file := FileAccess.open(script_path, FileAccess.READ)
	if script_file == null:
		return false
	var source := script_file.get_as_text()
	script_file.close()
	var extends_line := ""
	for raw_line in source.split("\n"):
		var line := str(raw_line).strip_edges()
		if line.begins_with("extends "):
			extends_line = line
			break
	if extends_line == "extends ArcadeGameController":
		return true
	var quoted_prefix := "extends \""
	if not extends_line.begins_with(quoted_prefix):
		return false
	var parent_end := extends_line.find("\"", quoted_prefix.length())
	if parent_end < 0:
		return false
	return _script_extends_arcade_controller(extends_line.substr(quoted_prefix.length(), parent_end - quoted_prefix.length()), visited)
