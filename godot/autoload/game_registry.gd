extends Node

const GAMES := [
	{"id": "unicorn_jump", "title": "Unicorn Jump", "category": "Number", "scene": "res://scenes/games/unicorn_jump.tscn"},
	{"id": "sliding_window", "title": "Sliding Window", "category": "Number", "scene": "res://scenes/games/sliding_window.tscn"},
	{"id": "coin_count", "title": "Coin Count", "category": "Number", "scene": "res://scenes/games/coin_count.tscn"},
	{"id": "cash_counter", "title": "Cash Counter", "category": "Number", "scene": "res://scenes/games/cash_counter.tscn"},
	{"id": "math_swipe", "title": "Math Swipe", "category": "Number", "scene": "res://scenes/games/math_swipe.tscn"},
	{"id": "mathtris", "title": "Mathtris", "category": "Number", "scene": "res://scenes/games/mathtris.tscn"},
	{"id": "pattern_parade", "title": "Pattern Parade", "category": "Number", "scene": "res://scenes/games/pattern_parade.tscn"},
	{"id": "unicorn_blast", "title": "Unicorn Blast", "category": "Word", "scene": "res://scenes/games/word_game.tscn"},
	{"id": "rhyme_rally", "title": "Rhyme Rally", "category": "Word", "scene": "res://scenes/games/rhyme_rally.tscn"},
	{"id": "sentence_sprout", "title": "Sentence Sprout", "category": "Word", "scene": "res://scenes/games/word_game.tscn"},
	{"id": "missing_magic", "title": "Missing Magic", "category": "Word", "scene": "res://scenes/games/word_game.tscn"},
	{"id": "sight_spark", "title": "Sight Spark", "category": "Word", "scene": "res://scenes/games/word_game.tscn"},
	{"id": "prefix_potion", "title": "Prefix Potion", "category": "Word", "scene": "res://scenes/games/word_game.tscn"},
	{"id": "vowel_vines", "title": "Vowel Vines", "category": "Word", "scene": "res://scenes/games/word_game.tscn"},
	{"id": "letter_lift", "title": "Letter Lift", "category": "Word", "scene": "res://scenes/games/word_game.tscn"},
	{"id": "syllable_stamp", "title": "Syllable Stamp", "category": "Word", "scene": "res://scenes/games/word_game.tscn"},
	{"id": "caption_quest", "title": "Caption Quest", "category": "Word", "scene": "res://scenes/games/word_game.tscn"},
	{"id": "opposite_orbit", "title": "Opposite Orbit", "category": "Mystery", "scene": "res://scenes/games/word_game.tscn"},
	{"id": "scramble_spell", "title": "Scramble Spell", "category": "Mystery", "scene": "res://scenes/games/word_game.tscn"},
	{"id": "odd_one_out", "title": "Odd One Out", "category": "Mystery", "scene": "res://scenes/games/word_game.tscn"},
	{"id": "size_line_up", "title": "Size Line-Up", "category": "Mystery", "scene": "res://scenes/games/word_game.tscn"},
	{"id": "chain_link", "title": "Chain Link", "category": "Mystery", "scene": "res://scenes/games/word_game.tscn"},
	{"id": "memory_meadow", "title": "Memory Meadow", "category": "Mystery", "scene": "res://scenes/games/memory_meadow.tscn"},
	{"id": "galaxy_unicorn", "title": "Galaxy Unicorn", "category": "Arcade", "scene": "res://scenes/games/galaxy_unicorn.tscn"},
	{"id": "comet_math_rescue", "title": "Comet Math Rescue", "category": "Arcade", "scene": "res://scenes/games/comet_math_rescue.tscn"},
	{"id": "bubble_count", "title": "Bubble Count", "category": "Arcade", "scene": "res://scenes/games/bubble_count.tscn"},
]


func all_games() -> Array:
	return GAMES.duplicate(true)


func get_game(game_id: String) -> Dictionary:
	for game in GAMES:
		if game["id"] == game_id:
			return game.duplicate(true)
	return {}


func games_in_category(category: String) -> Array:
	return GAMES.filter(func(game: Dictionary) -> bool: return game["category"] == category)


func playable_games() -> Array:
	return GAMES.filter(func(game: Dictionary) -> bool: return not str(game["scene"]).is_empty())


func playable_count(category := "") -> int:
	if category.is_empty():
		return playable_games().size()
	return games_in_category(category).filter(func(game: Dictionary) -> bool: return not str(game["scene"]).is_empty()).size()
