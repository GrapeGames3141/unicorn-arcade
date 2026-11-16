extends Node

## Shared sound effects and the looping music-box track. Honors the Music and
## Sound effects switches on the Profile page. All streams are synthesized by
## tools/build_audio.py.
const SFX_PATHS := {
	&"tap": "res://assets/audio/tap.wav",
	&"correct": "res://assets/audio/correct.wav",
	&"wrong": "res://assets/audio/wrong.wav",
	&"coin": "res://assets/audio/coin.wav",
	&"pop": "res://assets/audio/pop.wav",
	&"win": "res://assets/audio/win.wav",
	&"lose": "res://assets/audio/lose.wav",
}
const MUSIC_PATH := "res://assets/audio/music_meadow_loop.ogg"
const SFX_VOICES := 6
const MUSIC_VOLUME_DB := -17.0
const SFX_VOLUME_DB := -5.0
## A burst of identical effects (rapid blasts, cascades) collapses to one voice.
const REPEAT_GUARD_MS := 70

var _streams: Dictionary = {}
var _voices: Array[AudioStreamPlayer] = []
var _next_voice := 0
var _music: AudioStreamPlayer
var _last_played_ms: Dictionary = {}
var _last_coins := -1
var _quiet_tap_until_ms := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for id in SFX_PATHS:
		var stream := load(SFX_PATHS[id]) as AudioStream
		if stream != null:
			_streams[id] = stream
	for index in SFX_VOICES:
		var voice := AudioStreamPlayer.new()
		voice.name = "SfxVoice%d" % index
		voice.volume_db = SFX_VOLUME_DB
		add_child(voice)
		_voices.append(voice)
	_music = AudioStreamPlayer.new()
	_music.name = "Music"
	_music.volume_db = MUSIC_VOLUME_DB
	var track := load(MUSIC_PATH) as AudioStream
	if track is AudioStreamOggVorbis:
		(track as AudioStreamOggVorbis).loop = true
	_music.stream = track
	add_child(_music)
	get_tree().node_added.connect(_on_node_added)
	AppState.state_changed.connect(sync_settings)
	AppState.coins_changed.connect(_on_coins_changed)
	_last_coins = AppState.coins()
	sync_settings()


func _notification(what: int) -> void:
	# Never keep playing behind the lock screen or another app.
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		if is_instance_valid(_music):
			_music.stream_paused = true
	elif what == NOTIFICATION_APPLICATION_RESUMED or what == NOTIFICATION_APPLICATION_FOCUS_IN:
		if is_instance_valid(_music):
			_music.stream_paused = false


func sound_enabled() -> bool:
	return bool(AppState.setting("sound", true))


func music_enabled() -> bool:
	return bool(AppState.setting("music", true))


func sync_settings() -> void:
	if not is_instance_valid(_music) or _music.stream == null:
		return
	if music_enabled():
		if not _music.playing:
			_music.play()
	elif _music.playing:
		_music.stop()


func play(id: StringName) -> bool:
	if not sound_enabled() or not _streams.has(id):
		return false
	var now := Time.get_ticks_msec()
	if now - int(_last_played_ms.get(id, -REPEAT_GUARD_MS)) < REPEAT_GUARD_MS:
		return false
	_last_played_ms[id] = now
	if id != &"tap":
		# A result sound replaces the tap that caused it instead of stacking.
		_quiet_tap_until_ms = now + 120
	var voice := _voices[_next_voice]
	_next_voice = (_next_voice + 1) % _voices.size()
	voice.stream = _streams[id]
	voice.play()
	return true


func _on_node_added(node: Node) -> void:
	if node is BaseButton and not node.pressed.is_connected(_on_button_pressed):
		node.pressed.connect(_on_button_pressed)


func _on_button_pressed() -> void:
	# Deferred so an answer's own chime (played during the press) wins.
	_play_tap.call_deferred()


func _play_tap() -> void:
	if Time.get_ticks_msec() >= _quiet_tap_until_ms:
		play(&"tap")


func _on_coins_changed(coins: int) -> void:
	# The level-complete fanfare already celebrates its own coin reward.
	var after_fanfare := Time.get_ticks_msec() - int(_last_played_ms.get(&"win", -1000)) < 400
	if _last_coins >= 0 and coins != _last_coins and not after_fanfare:
		play(&"coin")
	_last_coins = coins
