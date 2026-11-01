extends CanvasLayer

@export_enum("Top center", "Top left", "Top right") var corner: int = 0
@export var font_size: int = 8
@export var margin: Vector2 = Vector2(10.0, 6.0)
@export var text_color: Color = Color.BLACK
@export var prefix: String = ""            #e.g. "TIME " iv i want word before number

var label: Label
var stats: Node
var gs: Node
var font_applied: bool = false

func _ready() -> void:
	layer = 9                                #under the pause menu and controls screen
	stats = get_node_or_null("/root/GameStats")
	gs = get_node_or_null("/root/GameState")

	label = Label.new()
	label.name = "TimerLabel"
	label.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", text_color)
	add_child(label)
	_place_label()
	_refresh()

func _place_label() -> void:
	match corner:
		0:   #top center
			label.set_anchors_preset(Control.PRESET_CENTER_TOP)
			label.grow_horizontal = Control.GROW_DIRECTION_BOTH
			label.offset_left = 0.0
			label.offset_right = 0.0
		1:   #top left
			label.set_anchors_preset(Control.PRESET_TOP_LEFT)
			label.grow_horizontal = Control.GROW_DIRECTION_END
			label.offset_left = margin.x
		2:   #top right
			label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
			label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
			label.offset_right = -margin.x
	label.offset_top = margin.y


func _process(_delta: float) -> void:
	#using same pixel font
	if not font_applied and gs and gs.ui_font:
		label.add_theme_font_override("font", gs.ui_font)
		font_applied = true
	_refresh()

func _refresh() -> void:
	if stats == null:
		label.text = prefix + "--:--"
		return
	label.text = prefix + stats.format_time(stats.attempt_time)
