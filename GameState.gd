extends Node
#tracks points 
#100 for collectibles attempts and time
signal stats_changed
#best score is saved
signal level_finished(summary:Dictionary)

const SAVE_PATH:="user://scores.cfg"
const MAX_TIME_BONUS:=100
const MAX_ATTEMPT_BONUS:=100
const ATTEMPT_PENALTY:=20
const SLOW_MULTIPLER=3.0

#par times
const DEFAULT_PAR_TIME:=30
const PAR_TIMES:={
	"level_1":5.0,
	"level_2":30.0,
	"level_3":20.0,
	"level_4":7.0,
	"level_5":30.0,
}

var points:int=0
var collected:int=0
var total_collectibles:int=0
var ui_font:Font
var level_id:String=""
var _finished:bool=false
var _last_summary:Dictionary={}
var _cfg:=ConfigFile.new()

func _ready()->void:
	process_mode=Node.PROCESS_MODE_ALWAYS
	_cfg.load(SAVE_PATH)

func start_level() -> void:
	points = 0
	collected = 0
	_finished = false
	_last_summary = {}
	level_id = _current_level_id()
	total_collectibles = get_tree().get_nodes_in_group("collectibles").size()
	stats_changed.emit()
	
func collect(value:int)->void:
	collected+=1
	points+=value
	stats_changed.emit()
	
func add_points(amount:int)->void:
	points+=amount
	stats_changed.emit()
	
func finish_level() -> Dictionary:
	if _finished:
		return _last_summary              
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
	var previous_best:=get_best_points(level_id)
	var new_best:=points > previous_best
	if new_best:
		_cfg.set_value(level_id,"best_points",points)
		_cfg.set_value(level_id,"best_collected",collected)
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
		if id="":
			id=level_id
		return int(_cfg.get_value(id,"best_points",0))
	
	func _par_time(id: String) -> float:
	return float(PAR_TIMES.get(id, DEFAULT_PAR_TIME))
	
	#full bonus at or under the par time
	func _time_bonus(time_taken: float, par: float) -> int:
	if time_taken < 0.0:
		return 0                            # no timing info (GameStats missing)
	var slowest := par * SLOW_MULTIPLIER
	if time_taken <= par:
		return MAX_TIME_BONUS
	if time_taken >= slowest:
		return 0
	return int(round(MAX_TIME_BONUS * (slowest - time_taken) / (slowest - par)))
	
	func _attempt_bonus(attempts: int) -> int:
	if attempts <= 0:
		return 0
	return maxi(MAX_ATTEMPT_BONUS - (attempts - 1) * ATTEMPT_PENALTY, 0)
 
 
func _current_level_id() -> String:
	var scene := get_tree().current_scene
	if scene == null or scene.scene_file_path == "":
		return "unknown"
	return scene.scene_file_path.get_file().get_basename()
	
	
	
