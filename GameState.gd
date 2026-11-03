extends Node

#scoring(per level, max 300 by default):
#collectible   100 points for grabbing the level's collectible (in the attempt you finish)
#time bonus    up to 100. Full marks at or under the level's PAR time, fading to 0 at par * SLOW_MULTIPLIER (4x right now)
#attempt bonus up to 100. Full marks on the first attempt, minus 20 for each extra attempt
#best score per level is saved to user://scores.cfg so it survives closing the game.

signal stats_changed
signal level_finished(summary: Dictionary)

const SAVE_PATH := "user://scores.cfg"    #separate from your progress autoload's progress.cfg on purpose

const MAX_TIME_BONUS := 100
const MAX_ATTEMPT_BONUS := 100
const ATTEMPT_PENALTY := 20               #points lost for every attempt after the first
const SLOW_MULTIPLIER := 4.0          #time bonus reaches 0 at par * this

#time where u get max points
const DEFAULT_PAR_TIME := 30.0
const PAR_TIMES := {
	"level_1": 6.0,
	"level_2": 23.0,
	"level_3": 20.0,
	"level_4": 15.0,
	"level_5": 25.0,
}

#the levels that count toward the total score (scene file names without ".tscn").
const LEVEL_IDS := ["level_1", "level_2", "level_3", "level_4", "level_5"]

var points: int = 0
var collected: int = 0
var total_collectibles: int = 0
var ui_font: Font                         #set by the player so popups use the same pixel font

var level_id: String = ""
var _finished: bool = false
var _last_summary: Dictionary = {}
var _cfg := ConfigFile.new()

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_cfg.load(SAVE_PATH)                  #fine if the file doesn't exist yet

#call at the start of every level (the player does this automatically).
func start_level() -> void:
	points = 0
	collected = 0
	_finished = false
	_last_summary = {}
	level_id = _current_level_id()
	total_collectibles = get_tree().get_nodes_in_group("collectibles").size()
	stats_changed.emit()

#a collectible was picked up.
func collect(value: int) -> void:
	collected += 1
	points += value
	stats_changed.emit()

#Any other source of points (enemies, bonuses, ...).
#for some more planned features
func add_points(amount: int) -> void:
	points += amount
	stats_changed.emit()

#returns a summary you can show on a win screen:
#{ level, points, collectible_points, time_bonus, attempt_bonus, bonus, time, attempts,
#par_time, collected, total, all_collected, best_points, new_best }
func finish_level() -> Dictionary:
	if _finished:
		return _last_summary                #reaching the flag twice doesn't count twice
	_finished = true

	var time_taken := -1.0
	var attempts := 0
	var stats := get_node_or_null("/root/GameStats")
	if stats:
		time_taken = stats.done_time
		attempts = stats.done_attempts

	var collectible_points := points
	var par := _par_time(level_id)
	var time_bonus := _time_bonus(time_taken, par)
	var attempt_bonus := _attempt_bonus(attempts)
	points += time_bonus + attempt_bonus

	var previous_best := get_best_points(level_id)
	var new_best := points > previous_best
	if new_best:
		_cfg.set_value(level_id, "best_points", points)
		_cfg.set_value(level_id, "best_collected", collected)
		_cfg.save(SAVE_PATH)

	_last_summary = {
		"level": level_id,
		"points": points,
		"collectible_points": collectible_points,
		"time_bonus": time_bonus,
		"attempt_bonus": attempt_bonus,
		"bonus": time_bonus + attempt_bonus,
		"time": time_taken,
		"attempts": attempts,
		"par_time": par,
		"collected": collected,
		"total": total_collectibles,
		"all_collected": total_collectibles > 0 and collected >= total_collectibles,
		"best_points": maxi(points, previous_best),
		"new_best": new_best,
	}
	stats_changed.emit()
	level_finished.emit(_last_summary)
	return _last_summary

func get_best_points(id: String = "") -> int:
	if id == "":
		id = level_id
	return int(_cfg.get_value(id, "best_points", 0))

#sum of your best score on every level. A better run on a level replaces that level's old best,
#so the total only ever goes up. This is the number the online leaderboard will rank by.
func get_total_score() -> int:
	var total := 0
	for id in LEVEL_IDS:
		total += get_best_points(id)
	return total

func _par_time(id: String) -> float:
	return float(PAR_TIMES.get(id, DEFAULT_PAR_TIME))

#full bonus at or under par, linearly down to 0 at par * SLOW_MULTIPLIER.
func _time_bonus(time_taken: float, par: float) -> int:
	if time_taken < 0.0:
		return 0                            #no timing info (GameStats missing)
	var slowest := par * SLOW_MULTIPLIER
	if time_taken <= par:
		return MAX_TIME_BONUS
	if time_taken >= slowest:
		return 0
	return int(round(MAX_TIME_BONUS * (slowest - time_taken) / (slowest - par)))

#full bonus on attempt 1, minus ATTEMPT_PENALTY for each extra attempt (never below 0).
func _attempt_bonus(attempts: int) -> int:
	if attempts <= 0:
		return 0
	return maxi(MAX_ATTEMPT_BONUS - (attempts - 1) * ATTEMPT_PENALTY, 0)

func _current_level_id() -> String:
	var scene := get_tree().current_scene
	if scene == null or scene.scene_file_path == "":
		return "unknown"
	return scene.scene_file_path.get_file().get_basename()
