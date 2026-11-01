extends Button
#attaching this to control button in main menu.

var screen: ControlsScreen

func _ready() -> void:
	pressed.connect(_on_pressed)
	
func _on_pressed() -> void:
	if screen==null:
		screen=ControlsScreen.new()
		screen.setup(get_theme_font("font"),self)
		var host: Node=get_tree().current_scene
		if host ==null:
			host=get_tree().root
		host.add_child(screen)
	screen.open()
