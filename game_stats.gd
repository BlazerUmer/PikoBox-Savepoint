extends Node

const SAVE_PATH := "user://times.json"   #separate from progress.cfg and scores.cfg
const MAX_ENTRIES := 5                    #how many times are kept per level
var current_level: String = ""        #path of the level being played
var attempts: int = 0                 #attempts on the current level (including this one)
var attempt_time: float = 0.0         #seconds spent on the current attempt
var total_time: float = 0.0           #seconds spent on this level across ALL attempts
var running: bool = false
var best_times: Dictionary = {}       #level path =fastest single attempt (seconds)
var last_was_best: bool = false
#leaderboard: level path -> the fastest times for that level, fastest first (saved to disk)
var top_times: Dictionary = {}
var last_rank: int = 0                #where the last completion placed (1 = best), 0 = didn't make the top list
#frozen results from the last completion, so labels can show them on the completion screen.
var done_attempts: int = 0
var done_time: float = 0.0
var done_total_time: float = 0.0
var done_best_time: float = 0.0

func _ready() -> void:
	_load_times()

func _process(delta: float) -> void:
	if running:
		attempt_time += delta
		total_time += delta

func start_level(level_path: String) -> void:
	if level_path != current_level:
		#a different level: start fresh.
		current_level = level_path
		attempts = 0
		total_time = 0.0
	attempts += 1
	attempt_time = 0.0
	running = true

func level_failed() -> void:
	running = false

func level_completed() -> void:
	running = false
	done_attempts = attempts
	done_time = attempt_time
	done_total_time = total_time
	var previous_best: float = best_times.get(current_level, INF)
	last_was_best = attempt_time < previous_best
	if last_was_best:
		best_times[current_level] = attempt_time
	done_best_time = best_times[current_level]
	_record_time(attempt_time)

func retry() -> void:
	if current_level.is_empty():
		push_warning("GameStats: no level to retry yet.")
		return
	get_tree().change_scene_to_file.call_deferred(current_level)

func format_time(seconds: float) -> String:
	var minutes := int(seconds / 60.0)
	var secs := fmod(seconds, 60.0)
	return "%d:%05.2f" % [minutes, secs]
#leadeboard
#fastest times for a level, fastest first. Empty path = the level you're playing.
func get_top_times(level_path: String = "") -> Array:
	if level_path == "":
		level_path = current_level
	return top_times.get(level_path, []).duplicate()

func _record_time(time: float) -> void:
	var list: Array = top_times.get(current_level, [])
	list.append(time)
	list.sort()
	last_rank = list.find(time) + 1
	if list.size() > MAX_ENTRIES:
		list.resize(MAX_ENTRIES)
	if last_rank > MAX_ENTRIES:
		last_rank = 0
	top_times[current_level] = list
	_save_times()

func _save_times() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("GameStats: couldn't save times to " + SAVE_PATH)
		return
	file.store_string(JSON.stringify({"top": top_times}))

func _load_times() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var data = JSON.parse_string(file.get_as_text())
	if not (data is Dictionary) or not (data.get("top") is Dictionary):
		return                           #first time doing this btw
	for path in data["top"]:
		var list: Array = []
		for t in data["top"][path]:
			list.append(float(t))
		list.sort()
		if list.is_empty():
			continue
		top_times[path] = list
		best_times[path] = list[0]        #best time survives restarted
