extends Label

@export_multiline var text_format: String = "Best time: {best}\nBest score: {best_points}\nAttempts: {attempts}"
@export var font_size: int = 12          #make this smaller to shrink the text, bigger to grow it
@export var line_gap: int = 1.0       # xtra space between lines in px (0 = tight)

#other values i can use in text format:
#{time} this run's time      {total} total time over all attempts    {points} this run's score
#{collectible_points}  {time_bonus}  {attempt_bonus}  {collected}  {collectibles_total}  {par}

func _ready() -> void:
	add_theme_font_size_override("font_size", font_size)
	add_theme_constant_override("line_spacing", line_gap)

	var stats := get_node_or_null("/root/GameStats")
	if stats == null:
		text = "(GameStats autoload is missing)"
		return

	var score := {}
	var gs := get_node_or_null("/root/GameState")
	if gs:
		score = gs.finish_level()

	text = text_format.format({
		"attempts": stats.done_attempts,
		"time": stats.format_time(stats.done_time),
		"total": stats.format_time(stats.done_total_time),
		"best": stats.format_time(stats.done_best_time),
		"points": score.get("points", 0),
		"collectible_points": score.get("collectible_points", 0),
		"time_bonus": score.get("time_bonus", 0),
		"attempt_bonus": score.get("attempt_bonus", 0),
		"bonus": score.get("bonus", 0),
		"collected": score.get("collected", 0),
		"collectibles_total": score.get("total", 0),
		"par": stats.format_time(score.get("par_time", 0.0)),
		"best_points": score.get("best_points", 0),
	})
