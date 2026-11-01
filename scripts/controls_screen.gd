class_name ControlsScreen
extends CanvasLayer
#fullscreen control scene with scrollbar

signal closed
const CONTROLS_TEXT:="""CONTROLS:

A/D or arrow keys - move
SPACE/W - jump
1 - Size down
2 - Default size (can spawn boxes)
3 - Size up
E - Place box (disabled in level 1)
ESC - Pause menu

Points System:

1- The faster you complete a level and the less attempts and the 
 more stars you take the more points/score you get.

2- Max possible score for a level is 300.

3- The stars have 100 points per level.(50 each for level 3. 100 total)

4- Attempts total score is 100. You get 100 only if 1 attempt is used.

5- Time score is 100 max.The faster you are the more points you 
 get with max being 100.

6- You can view your best time in best times tab.

7- Leaderboards tab shows everyones best score.

TIPS:

1- The bigger the size, the higher the jump.
 The smaller the size, the faster the speed.

2- Activate the switch to get the purple platform to move.
 To activate the switch just touch it.

3- Black Flash: Not enough space to resize.
 Purple Flash: Resized.
 Red Flash: Out of boxes.
 Orange Flash: Can't place a box due to space being blocked.

4- Boxes only spawn at size 2, and won't spawn if something is 
 blocking your path.

5- Be mindful of box and resize limits!

 Use boxes and Resizing to reach the end!!

       Goodluck!!!"""

const SCROLL_STEP := 24
var font_size: int = 8
var close_on_escape: bool = true     #pause menu turns this off because it handles Esc itself
var _scroll: ScrollContainer
var _back: Button
#font: font for the text
func setup(font: Font = null, button_template: Button = null) -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS     #works while the game is paused
	layer = 100
	var root := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#3b363c")
	style.border_color = Color("#3b363c")
	style.set_border_width_all(2)
	root.add_theme_stylebox_override("panel", style)
	add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)   #whole screen
	var margin := MarginContainer.new()
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 16)
	root.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	margin.add_child(column)
	#scrollable text area (takes all the space above the Back button)
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_ALWAYS
	column.add_child(_scroll)
	_style_scrollbar(_scroll.get_v_scroll_bar())
	var label := Label.new()
	label.text = CONTROLS_TEXT
	label.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_constant_override("line_spacing", 0)
	if font:
		label.add_theme_font_override("font", font)
	_scroll.add_child(label)
	#back button, always visible at the bottom
	if button_template:
		_back = button_template.duplicate(0) as Button   #0 = copy the look only
	else:
		_back = Button.new()
		if font:
			_back.add_theme_font_override("font", font)
	_back.name = "back button"
	_back.text = "Back"
	_back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_back.pressed.connect(close)
	column.add_child(_back)
	hide()

func _style_scrollbar(bar: VScrollBar) -> void:
	bar.custom_minimum_size.x = 12
	var track := StyleBoxFlat.new()
	track.bg_color = Color("#2a262b")
	var grab := StyleBoxFlat.new()
	grab.bg_color = Color("#c98a84")
	var grab_hi := StyleBoxFlat.new()
	grab_hi.bg_color = Color("#e0a8a2")
	bar.add_theme_stylebox_override("scroll", track)
	bar.add_theme_stylebox_override("scroll_focus", track)
	bar.add_theme_stylebox_override("grabber", grab)
	bar.add_theme_stylebox_override("grabber_highlight", grab_hi)
	bar.add_theme_stylebox_override("grabber_pressed", grab_hi)

func open() -> void:
	_scroll.scroll_vertical = 0
	show()

func close() -> void:
	hide()
	closed.emit()

#arrow keys scroll the text (mouse wheel and dragging the bar work automatically)
func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_down", true):
		_scroll.scroll_vertical += SCROLL_STEP
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_up", true):
		_scroll.scroll_vertical -= SCROLL_STEP
		get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if visible and close_on_escape and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
