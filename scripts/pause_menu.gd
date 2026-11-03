extends CanvasLayer

const LEVEL_SELECT := "res://scene/Levelselection.tscn"
const MAIN_MENU := "res://scene/main screen.tscn"
@onready var menu_box: Control = $CenterContainer
@onready var buttons: VBoxContainer = $CenterContainer/VBoxContainer
@onready var resume_btn: Button = $"CenterContainer/VBoxContainer/resume button"
@onready var select_btn: Button = $"CenterContainer/VBoxContainer/level select button2"
@onready var menu_btn: Button = $"CenterContainer/VBoxContainer/main menu button3"
var controls_screen: ControlsScreen

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	hide()
	resume_btn.pressed.connect(resume)
	select_btn.pressed.connect(_go.bind(LEVEL_SELECT))
	menu_btn.pressed.connect(_go.bind(MAIN_MENU))
	_wire_try_again()
	_build_controls_button()
	_build_controls_screen()

#try again hookup
func _wire_try_again() -> void:
	for child in buttons.get_children():
		if child is Button and child.text.to_lower().contains("try"):
			if child.pressed.get_connections().is_empty():
				child.pressed.connect(_retry)

func _build_controls_button() -> void:
	var btn := resume_btn.duplicate(0) as Button 
	btn.name = "controls button"
	btn.text = "Controls"
	buttons.add_child(btn)
	buttons.move_child(btn, resume_btn.get_index() + 1)
	btn.pressed.connect(show_controls)

func _build_controls_screen() -> void:
	controls_screen = ControlsScreen.new()
	controls_screen.close_on_escape = false        #this script handles Esc itself
	controls_screen.setup(resume_btn.get_theme_font("font"), resume_btn)
	controls_screen.closed.connect(hide_controls)
	add_child(controls_screen)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		var tree := get_tree()
		if tree == null:
			return
		if tree.paused:
			if controls_screen.visible:
				controls_screen.close()  #P/Esc closes the controls screen first
			else:
				resume()
		else:
			pause()
		get_viewport().set_input_as_handled()

func show_controls() -> void:
	menu_box.hide()
	controls_screen.open()

func hide_controls() -> void:
	if controls_screen.visible:
		controls_screen.hide()
	menu_box.show()

func pause() -> void:
	var tree := get_tree()
	if tree == null:
		return
	tree.paused = true
	show()

func resume() -> void:
	var tree := get_tree()
	if tree == null:
		return
	tree.paused = false
	hide_controls()
	hide()

func _retry() -> void:
	var tree := get_tree()
	if tree == null:
		return
	tree.paused = false
	tree.reload_current_scene()

func _go(path: String) -> void:
	var tree := get_tree()
	if tree == null:
		return

	tree.paused = false
	tree.change_scene_to_file(path)
#no idea why i didnt create a scene and just attack control to it
#wanted to challenge myself ig
