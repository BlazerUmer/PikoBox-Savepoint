extends Control

const SHEET := preload("res://jame gam/btn8_spritesheet.png")
const LEVEL_PATH := "res://scene/level_%d.tscn"
const TEXT_COLOR := Color("2d2730")

@export var level_count := 5
@export var button_size := Vector2(24, 24)
@export var move_up := 30.0   #how far up the buttons sit from dead center (bigger = higher)
@export var leaderboard_nodes: Array[Control] = []   # drag the Leaderboard tab/button here; hidden when offline

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_apply_offline_mode()

	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE  
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.offset_top = 0
	center.offset_bottom = -move_up * 2.0   #shrinking from the bottom moves the middle up

	var grid := GridContainer.new()
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grid.columns = level_count
	grid.add_theme_constant_override("h_separation", 8)
	center.add_child(grid)

	for i in range(1, level_count + 1):
		var b := Button.new()
		b.custom_minimum_size = button_size
		b.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		b.add_theme_stylebox_override("normal", _style(0))
		b.add_theme_stylebox_override("hover", _style(1))
		b.add_theme_stylebox_override("pressed", _style(2))
		b.add_theme_stylebox_override("disabled", _style(3))
		b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		b.add_theme_font_size_override("font_size", 8)
		for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			b.add_theme_color_override(c, TEXT_COLOR)
		if i <= Progress.unlocked_levels:
			b.text = str(i)
			b.pressed.connect(_on_level_pressed.bind(i))
		else:
			b.text = ""
			b.disabled = true
		grid.add_child(b)

func _apply_offline_mode() -> void:
	var profile := get_node_or_null("/root/PlayerProfile")
	var offline: bool = profile != null and "is_offline" in profile and profile.is_offline
	for n in leaderboard_nodes:
		if n != null:
			n.visible = not offline

func _style(frame: int) -> StyleBoxTexture:
	var s := StyleBoxTexture.new()
	s.texture = SHEET
	s.region_rect = Rect2(frame * 8, 0, 8, 8)
	return s

func _on_level_pressed(n: int) -> void:
	var path := LEVEL_PATH % n
	if ResourceLoader.exists(path):
		get_tree().change_scene_to_file(path)
	else:
		push_warning("Level %d doesn't exist yet: %s" % [n, path])
