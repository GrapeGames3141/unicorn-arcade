extends Node

const LevelRunController := preload("res://scripts/games/level_run_controller.gd")
var failures: Array[String] = []
var previous_data: Dictionary


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	SaveService.begin_test_session()
	previous_data = AppState.data.duplicate(true)
	AppState.data = SaveService.default_profile("Audio Test")
	for id in AudioService.SFX_PATHS:
		_check(ResourceLoader.exists(AudioService.SFX_PATHS[id]) and load(AudioService.SFX_PATHS[id]) is AudioStream, "%s effect stream is importable" % id)
	var music := AudioService.get_node_or_null("Music") as AudioStreamPlayer
	_check(is_instance_valid(music) and music.stream is AudioStreamOggVorbis and (music.stream as AudioStreamOggVorbis).loop, "music stream is a looping Ogg track")
	_check(music.volume_db < AudioService.SFX_VOLUME_DB, "music sits underneath sound effects")

	AppState.data["settings"]["sound"] = true
	AppState.data["settings"]["music"] = true
	AudioService.sync_settings()
	_check(music.playing, "music plays while the Music setting is on")
	await get_tree().create_timer(0.1).timeout
	_check(AudioService.play(&"correct"), "an effect plays while Sound effects is on")
	_check(not AudioService.play(&"correct"), "an identical effect inside the repeat guard collapses to one voice")
	_check(not AudioService.play(&"missing_effect"), "unknown effect ids are ignored")

	AppState.data["settings"]["sound"] = false
	AppState.data["settings"]["music"] = false
	AudioService.sync_settings()
	await get_tree().create_timer(0.1).timeout
	_check(not music.playing, "turning Music off stops the track")
	_check(not AudioService.play(&"win"), "turning Sound effects off silences effects")

	AppState.data["settings"]["sound"] = true
	var button := Button.new()
	add_child(button)
	_check(button.pressed.is_connected(AudioService._on_button_pressed), "every button added to the tree gets the tap sound")
	var run := LevelRunController.new()
	run.begin("coin_count", 1)
	await get_tree().create_timer(0.1).timeout
	run.fail("test failure")
	_check(Time.get_ticks_msec() - int(AudioService._last_played_ms.get(&"lose", -9999)) < 500, "a failed run plays the try-again sound")

	AppState.data = previous_data
	SaveService.end_test_session()
	AudioService.sync_settings()
	if failures.is_empty():
		print("AUDIO_SERVICE_TEST_OK: 12 checks")
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error(failure)
		print("AUDIO_SERVICE_TEST_FAILED: %d" % failures.size())
		get_tree().quit(1)
