extends Label

@export var level_paths: Array[String] = [
	"res://scene/level_1.tscn",
	"res://scene/level_2.tscn",
	"res://scene/level_3.tscn",
	"res://scene/level_4.tscn",
	"res://scene/level_5.tscn",
]
@export var title: String = ""            #optional heading. Empty = no heading
@export var font_size: int = 12          #make this smaller to shrink the text, bigger to grow it
@export var line_gap: int = 2             #extra space between lines in px (0 = tight)


func _ready() -> void:
	add_theme_font_size_override("font_size", font_size)
	add_theme_constant_override("line_spacing", line_gap)
	var stats := get_node_or_null("/root/GameStats")
	var gs := get_node_or_null("/root/GameState")
	if stats == null:
		text = "(GameStats autoload is missing)"
		return
	var lines: Array[String] = []
	if title != "":
		lines.append(title)
		lines.append("")
	var number := 1
	for path in level_paths:
		var times: Array = stats.get_top_times(path)
		var best_time: String = stats.format_time(times[0]) if not times.is_empty() else "--"
		var score_text := "--"
		if gs:
			var id := path.get_file().get_basename()
			var score: int = gs.get_best_points(id)
			if score > 0:
				score_text = str(score)

		lines.append("LEVEL %d    %s    SCORE %s" % [number, best_time, score_text])
		number += 1
	text = "\n".join(lines)
