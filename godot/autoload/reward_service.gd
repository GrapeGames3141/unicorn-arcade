extends Node

const BASE_LEVEL_REWARD := 10
const REWARD_PER_LEVEL := 5
const PAID_HINT_COST := 5


func level_reward(level: int) -> int:
	return BASE_LEVEL_REWARD + maxi(level, 1) * REWARD_PER_LEVEL


func hint_cost(level: int) -> int:
	return 0 if level <= 1 else PAID_HINT_COST


func endless_reward(score: int) -> int:
	# One coin per 100 earned points, capped before companion bonuses.
	return mini(250, maxi(0, score) / 100)
