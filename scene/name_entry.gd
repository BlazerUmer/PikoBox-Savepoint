class_name LoginScreen
extends Control
#login / Name Entry screen with Offline Mode and Pixelify Font support.


static var force_show: bool = false

signal name_confirmed(player_name: String)
signal logged_in_offline()

@export var font: Font                               
@export var font_size: int = 8
@export var title: String = "LOGIN"

# UI Theme Palette (Pixel Card UI Style)
@export var frame_border_color: Color = Color("2b222c") #dark outer frame border
@export var panel_bg_color: Color = Color("fdfbf7")     #light cream panel background
@export var title_color: Color = Color("2b222c")        #dark title text
@export var button_bg_color: Color = Color("ce8074")     #terracotta/salmon primary button
@export var button_hover_color: Color = Color("b86d62")
@export var secondary_button_bg: Color = Color("7a6e7d") #muted slate purple for offline button
@export var secondary_button_hover: Color = Color("635865")
@export var button_text_color: Color = Color("fdfbf7")   #light button label text
@export var input_bg_color: Color = Color("ffffff")     #white input background
@export var error_color: Color = Color("c0392b")

@export var next_scene: String = "res://scene/main screen.tscn"
@export var skip_if_named: bool = false

var profile: Node
var line: LineEdit
var error_label: Label
var _busy: bool = false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	profile = get_node_or_null("/root/PlayerProfile")

	#auto-load Pixelify font if located in fonts folder and not explicitly set in Inspector
	if font == null and ResourceLoader.exists("res://fonts/PixelifySans-Regular.ttf"):
		font = load("res://fonts/PixelifySans-Regular.ttf")

	if not force_show and skip_if_named and profile and profile.has_method("has_name") and profile.has_name():
		_finish.call_deferred()
		return

	force_show = false
	_build_ui()


func _build_ui() -> void:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	#main framed panel container
	var panel := PanelContainer.new()
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = panel_bg_color
	panel_style.border_color = frame_border_color
	panel_style.set_border_width_all(5)
	panel_style.content_margin_left = 20
	panel_style.content_margin_top = 16
	panel_style.content_margin_right = 20
	panel_style.content_margin_bottom = 16
	panel.add_theme_stylebox_override("panel", panel_style)
	center.add_child(panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	column.custom_minimum_size = Vector2(160.0, 0.0)
	panel.add_child(column)

	#title Label
	var title_label := Label.new()
	title_label.text = title
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_style_text(title_label, title_color)
	column.add_child(title_label)

	#name Input LineEdit
	line = LineEdit.new()
	if profile and "MAX_LEN" in profile and "MIN_LEN" in profile:
		line.max_length = profile.MAX_LEN
		line.placeholder_text = "%d-%d characters" % [profile.MIN_LEN, profile.MAX_LEN]
	else:
		line.placeholder_text = "Enter name..."

	line.alignment = HORIZONTAL_ALIGNMENT_CENTER
	if profile and "display_name" in profile:
		line.text = profile.display_name
	line.text_submitted.connect(_on_text_submitted)
	_style_line_edit(line)
	column.add_child(line)

	#error Label
	error_label = Label.new()
	error_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	error_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_style_text(error_label, error_color)
	column.add_child(error_label)

	#primary Action: Confirm / Login Button
	var confirm := Button.new()
	confirm.text = "Confirm"
	confirm.pressed.connect(_confirm)
	_style_button(confirm, button_bg_color, button_hover_color)
	column.add_child(confirm)

	#secondary Action: Continue Offline Button
	var offline_btn := Button.new()
	offline_btn.text = "Continue Offline"
	offline_btn.pressed.connect(_on_offline_pressed)
	_style_button(offline_btn, secondary_button_bg, secondary_button_hover)
	column.add_child(offline_btn)

	line.grab_focus.call_deferred()


func _style_text(node: Control, color: Color) -> void:
	node.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	node.add_theme_font_size_override("font_size", font_size)
	if font:
		node.add_theme_font_override("font", font)
	node.add_theme_color_override("font_color", color)


func _style_button(btn: Button, bg_col: Color, hover_col: Color) -> void:
	btn.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.add_theme_font_size_override("font_size", font_size)
	if font:
		btn.add_theme_font_override("font", font)

	btn.add_theme_color_override("font_color", button_text_color)
	btn.add_theme_color_override("font_hover_color", button_text_color)
	btn.add_theme_color_override("font_pressed_color", button_text_color)
	btn.add_theme_color_override("font_focus_color", button_text_color)

	var normal_style := StyleBoxFlat.new()
	normal_style.bg_color = bg_col
	normal_style.set_corner_radius_all(3)
	normal_style.content_margin_left = 12
	normal_style.content_margin_right = 12
	normal_style.content_margin_top = 4
	normal_style.content_margin_bottom = 4

	var hover_style := normal_style.duplicate() as StyleBoxFlat
	hover_style.bg_color = hover_col

	btn.add_theme_stylebox_override("normal", normal_style)
	btn.add_theme_stylebox_override("hover", hover_style)
	btn.add_theme_stylebox_override("pressed", hover_style)
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())


func _style_line_edit(input: LineEdit) -> void:
	input.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	input.add_theme_font_size_override("font_size", font_size)
	if font:
		input.add_theme_font_override("font", font)

	input.add_theme_color_override("font_color", title_color)
	input.add_theme_color_override("placeholder_color", title_color.darkened(0.4))

	var input_style := StyleBoxFlat.new()
	input_style.bg_color = input_bg_color
	input_style.border_color = frame_border_color
	input_style.set_border_width_all(1)
	input_style.set_corner_radius_all(2)
	input_style.content_margin_left = 6
	input_style.content_margin_right = 6
	input_style.content_margin_top = 3
	input_style.content_margin_bottom = 3

	input.add_theme_stylebox_override("normal", input_style)
	input.add_theme_stylebox_override("focus", input_style)


func _on_text_submitted(_text: String) -> void:
	_confirm()


func _confirm() -> void:
	if _busy:
		return
	if not NameFilter.is_clean(line.text):
		error_label.text = "That name isn't allowed. Pick another."
		return

	_busy = true
	error_label.text = "Checking..."

	#ask the server if the name is free. The check needs online mode, so lift
	#the offline flag for the call and restore it if the name is taken.
	var online := get_node_or_null("/root/OnlineLeaderboard")
	if online and online.has_method("name_available") and profile and "is_offline" in profile:
		var was_offline: bool = profile.is_offline
		profile.is_offline = false
		var check: Dictionary = await online.name_available(line.text)
		if not is_inside_tree():
			return
		if check["ok"] and not check["available"]:
			profile.is_offline = was_offline
			error_label.text = "That name is taken. Pick another."
			_busy = false
			return

	if profile and profile.has_method("try_set_name"):
		var error: String = profile.try_set_name(line.text)
		if error != "":
			error_label.text = error
			_busy = false
			return
	error_label.text = ""
	#a valid name means online mode (undoes an earlier offline choice this session)
	if profile and "is_offline" in profile:
		profile.is_offline = false
	_busy = false
	_finish()


func _on_offline_pressed() -> void:
	if _busy:
		return
	#flags the session as offline on the PlayerProfile autoload
	if profile and "is_offline" in profile:
		profile.is_offline = true
	if profile and profile.has_method("set_offline"):
		profile.set_offline()

	logged_in_offline.emit()
	_finish()


func _finish() -> void:
	if profile and "display_name" in profile:
		name_confirmed.emit(profile.display_name)

	if next_scene != "":
		var err := get_tree().change_scene_to_file(next_scene)
		if err != OK:
			push_error("Failed to load scene '%s'. Verify path in Inspector." % next_scene)
