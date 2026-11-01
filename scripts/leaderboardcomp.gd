extends Label
#shows fastest times for lvl
@export var level_path:String=""
@export var show_count: int=5
@export var title: String="TOP TIMES"

func _ready() -> void:
	var stats := get_node_or_null("/root/GameStats")
	if stats == null:
		text = "(GameStats autoload is missing)"
		return
		
	var times: Array = stats.get_top_times(level_path)
	var lines: Array[String] = [title]
	if times.is_empty():
		lines.append("No times yet")
	for i in mini(times.size(), show_count):
		var line := "%d. %s" % [i + 1, stats.format_time(times[i])]
		if level_path == "" and stats.last_rank == i + 1:
			line += "  < you"
		lines.append(line)
	text = "\n".join(lines)
