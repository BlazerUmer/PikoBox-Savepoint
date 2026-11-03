extends Label
#Shows the online top players. Put this on a Label in your Leaderboard scene.
#Needs the OnlineLeaderboard and PlayerProfile autoloads.
#Top 3 are colored with the game's palette, 1st is a bit bigger.

@export var font: Font                       
@export var show_count: int = 5
@export var title: String = ""
@export var font_size: int = 8
@export var line_gap: int = 2
@export var first_place_extra_size: int = 2   #how much bigger the #1 row is (0 = same size)

const COLOR_TEXT := Color("2b222c")     #dark title color
const COLOR_FIRST := Color("c9695b")    #salmon (slightly deeper than the Start button for contrast)
const COLOR_SECOND := Color("8e6bbf")   #box purple
const COLOR_THIRD := Color("5f8fcc")    #water blue

var _list: VBoxContainer


func _ready() -> void:
	add_theme_font_size_override("font_size", font_size)
	add_theme_constant_override("line_spacing", line_gap)
	if font:
		add_theme_font_override("font", font)

	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", line_gap)
	_list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_list)

	var online := get_node_or_null("/root/OnlineLeaderboard")
	if online == null:
		text = "(OnlineLeaderboard autoload is missing)"
		return
	var profile := get_node_or_null("/root/PlayerProfile")
	var has_name: bool = profile != null and profile.has_name()

	text = "Loading..."

	#make sure this player's latest total is on the board before we read it
	if has_name:
		await online.submit_total_score()
		if not is_inside_tree():
			return

	var top: Dictionary = await online.fetch_top(show_count)
	if not is_inside_tree():
		return
	if not top["ok"]:
		text = "Couldn't load the leaderboard.\n" + str(top["message"])
		return

	text = ""   #the rows below replace the plain text

	if title != "":
		_add_row(title, COLOR_TEXT, font_size)
		_add_spacer()

	var rows: Array = top["rows"]
	if rows.is_empty():
		_add_row("No scores yet", COLOR_TEXT, font_size)
	for i in rows.size():
		var row: Dictionary = rows[i]
		var line_text := "%d. %s: %d" % [i + 1, str(row.get("name", "?")), int(row.get("total_score", 0))]
		var color := COLOR_TEXT
		var size := font_size
		match i:
			0:
				color = COLOR_FIRST
				size = font_size + first_place_extra_size
			1:
				color = COLOR_SECOND
			2:
				color = COLOR_THIRD
		_add_row(line_text, color, size)

	if has_name:
		var mine: Dictionary = await online.fetch_my_rank()
		if not is_inside_tree():
			return
		if mine["ok"] and int(mine["rank"]) > 0:
			_add_spacer()
			_add_row("YOUR RANK: #%d" % int(mine["rank"]), COLOR_TEXT, font_size)
	else:
		_add_spacer()
		_add_row("Pick a name to join the board.", COLOR_TEXT, font_size)


func _add_row(row_text: String, color: Color, size: int) -> void:
	var l := Label.new()
	l.text = row_text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if font:
		l.add_theme_font_override("font", font)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_list.add_child(l)


func _add_spacer() -> void:
	var s := Control.new()
	s.custom_minimum_size = Vector2(0, 4)
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_list.add_child(s)
