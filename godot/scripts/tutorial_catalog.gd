class_name TutorialCatalog
extends RefCounted

# Each registered game owns three guided lessons. Every lesson is three short,
# readable steps so the runtime can present the same interaction pattern without
# reducing the games to a generic rules paragraph.
const LESSONS := {
	"unicorn_jump": [["Read the glowing jump number.", "Count that many stones in the arrow's direction.", "Tap only the exact landing stone."], ["Start counting after your current stone.", "Every landing reveals a new jump.", "Plan before tapping."], ["Nearby stones may be decoys.", "Only an exact count is safe.", "Your companion can help once per level."]],
	"sliding_window": [["Find the glowing number window.", "Compare only numbers inside it.", "Choose the largest value."], ["The window moves after an answer.", "Ignore numbers outside its frame.", "Win each comparison."], ["Windows grow and rivals get quicker.", "Scan left to right.", "Use your companion when needed."]],
	"coin_count": [["Look at each real US coin.", "Tap coins to add their values.", "Match the target exactly."], ["Penny 1¢, nickel 5¢, dime 10¢, quarter 25¢.", "Watch your running total.", "Going over ends the try."], ["Mix different denominations.", "Start with the largest useful coin.", "Use your companion for help."]],
	"cash_counter": [["Recognize each real US bill.", "Tap bills to build the target.", "Match the target exactly."], ["Read the portrait and denomination.", "Watch your running total.", "Do not go over."], ["Combine several denominations.", "Choose the largest bill that fits.", "Use your companion when needed."]],
	"math_swipe": [["Read the equation banner.", "Find the missing number.", "Swipe or tap the correct answer."], ["Check both sides of equals.", "Wrong answers cost the try.", "Solve each new equation."], ["Operations become harder.", "Estimate before choosing.", "Your companion can assist once."]],
	"mathtris": [["Move the falling tile left, right, or down.", "Build five tiles like 1 + 1 = 2.", "Only true equations clear."], ["Swipe one settled tile onto a neighbor.", "A swap checks equations touching those tiles.", "Invalid equations stay."], ["Clears may create a true cascade.", "Keep the spawn row open.", "Use your companion once per level."]],
	"unicorn_blast": [["Read a falling word.", "Type it before it reaches the cannon.", "Complete the spelling to blast it."], ["Prioritize the lowest word.", "Each escape costs a heart.", "Clear enough words to finish."], ["Words arrive faster later.", "Stay accurate before typing quickly.", "Use your companion for help."]],
	"rhyme_rally": [["Read the banner word.", "Choose the word that rhymes.", "Listen for matching ending sounds."], ["Rhymes may use different letters.", "Say each option aloud.", "Keep the rally moving."], ["Ignore words that only look similar.", "Match sound, not spelling.", "Use your companion once."]],
	"sentence_sprout": [["Read all word tiles.", "Tap the sentence's first word.", "Continue in grammatical order."], ["The sentence grows one tile at a time.", "Use capitals and punctuation.", "A wrong tile resets the try."], ["Read the whole sentence first.", "Plan the longer order.", "Your companion can reveal a step."]],
	"missing_magic": [["Read the sentence and magic blank.", "Try each option in the blank.", "Choose the word completing the meaning."], ["Check grammar and story sense.", "Only one fits both.", "Complete every prompt."], ["Use nearby context clues.", "Eliminate impossible choices.", "Your companion can help once."]],
	"sight_spark": [["Study the glowing word.", "Hold its spelling in memory.", "Type it after the spark fades."], ["Notice beginning, middle, and end.", "Hints reveal it again.", "Spell it exactly."], ["Viewing time gets shorter.", "Group letters into chunks.", "Your companion can help once."]],
	"prefix_potion": [["Read the prefix and root.", "Combine their meanings.", "Choose the real new word."], ["A prefix changes root meaning.", "Check the joined spelling.", "Brew the correct answer."], ["Explain the completed word.", "Eliminate nonsense combinations.", "Your companion can help once."]],
	"vowel_vines": [["Read the target vowel.", "Inspect each word's first letter.", "Choose a word beginning with it."], ["Say the first sound aloud.", "Ignore later vowels.", "Grow the vine."], ["Words become less familiar.", "Focus on the printed first letter.", "Your companion can highlight once."]],
	"letter_lift": [["Read the target word.", "Type its first letter.", "Continue one letter at a time."], ["The lift rises for correct letters.", "Check order before typing.", "A wrong letter ends the try."], ["Break longer words into chunks.", "Sound out each syllable.", "Your companion can reveal a step."]],
	"syllable_stamp": [["Read the whole word.", "Find its spoken parts.", "Tap the parts in order."], ["Say it slowly and clap each beat.", "Each beat is a syllable tile.", "Stamp the complete word."], ["Syllables can contain several letters.", "Follow sound, not length.", "Use your companion once."]],
	"caption_quest": [["Study the illustrated situation.", "Read every caption.", "Choose the best fit."], ["Check who, what, and where.", "Poor captions cost a heart.", "Use scene evidence."], ["The best caption is complete.", "Eliminate partly true choices.", "Your companion can help once."]],
	"opposite_orbit": [["Read the target word.", "Choose its opposite.", "Send the pair into orbit."], ["Use the word in a sentence.", "Replace it with each option.", "Choose reversed meaning."], ["Ignore merely related words.", "Check the exact meaning.", "Use your companion once."]],
	"scramble_spell": [["Read the picture or meaning hint.", "Find the first letter.", "Tap all letters in order."], ["Watch the word build.", "A wrong letter ends the try.", "Use the hint before guessing."], ["Longer words may repeat letters.", "Track the next tile.", "Your companion can reveal one step."]],
	"odd_one_out": [["Read the case-file theme.", "Compare every item.", "Choose what does not belong."], ["Name the rule most items share.", "Test each choice.", "Wrong choices cost a heart."], ["The difference may be subtle.", "Explain why it differs.", "Your companion can highlight once."]],
	"size_line_up": [["Read all words.", "Tap the shortest first.", "Continue shortest to longest."], ["Count letters, not font size.", "The line grows in order.", "A wrong length ends the try."], ["Count equal-looking words carefully.", "Plan the full order.", "Use your companion once."]],
	"chain_link": [["Read the starting word.", "Find its final letter.", "Choose a word starting with it."], ["The chosen word makes the next link.", "Check first and last letters.", "Keep the chain unbroken."], ["Long chains need attention.", "Say the connecting letter aloud.", "Your companion can help once."]],
	"galaxy_unicorn": [["Drag to move your equipped unicorn.", "Rainbow bolts fire automatically.", "Line up with enemies."], ["Avoid enemies reaching your unicorn.", "Collect useful pickups.", "Defeat the required number."], ["Bosses take several hits.", "Later levels speed up gradually.", "Use your companion once."]],
	"comet_math_rescue": [["Read the equation banner.", "Drag or tap a comet lane.", "Your rainbow bolt checks that lane."], ["Only the selected comet resolves each wave.", "Correct answers fill the Rescue meter.", "Wrong answers cost a shield heart."], ["Comets descend more quickly later.", "Division answers are always whole numbers.", "Mystic can safely rescue one wave."]],
	"pattern_parade": [["Look along the parade row.", "Say the pattern out loud.", "Tap what comes next."], ["Find the part that repeats.", "A wrong pick costs a heart.", "Keep the parade marching."], ["Some parades count with numbers.", "Work out how much each step adds.", "Use your companion if stuck."]],
	"memory_meadow": [["Tap a card to flip it.", "Flip a second card.", "Matching pictures stay face up."], ["Cards that differ turn back over.", "Remember where each picture hides.", "Each miss uses one peek."], ["Bigger meadows hide more pairs.", "Check new cards against ones you know.", "Use your companion to reveal a pair."]],
	"bubble_count": [["Find the smallest number.", "Tap that bubble to pop it.", "Pop the next number up."], ["Bubbles drift, so look carefully.", "A wrong pop costs a heart.", "Count up without skipping."], ["Later bubbles count by 2s, 5s, or 10s.", "Say each number as you pop.", "Use your companion to find the next one."]],
}


static func lessons(game_id: String, level: int) -> Array[String]:
	var game_lessons: Array = LESSONS.get(game_id, [])
	if game_lessons.is_empty():
		return ["Read the large objective banner.", "Try the highlighted action.", "Use ? to replay this tutorial."]
	var result: Array[String] = []
	result.assign(game_lessons[clampi(level - 1, 0, 2)])
	return result


static func covers_all(game_ids: Array) -> bool:
	for game_id in game_ids:
		if not LESSONS.has(str(game_id)) or (LESSONS[str(game_id)] as Array).size() != 3:
			return false
	return true
