extends Button

const LOGIN_SCENE := "res://scene/login.tscn"  

func _ready() -> void:
	if not pressed.is_connected(_on_change_name_button_pressed):
		pressed.connect(_on_change_name_button_pressed)

func _on_change_name_button_pressed() -> void:
	if not ResourceLoader.exists(LOGIN_SCENE):
		push_warning("Login scene not found: %s" % LOGIN_SCENE)
		return
	LoginScreen.force_show = true
	get_tree().change_scene_to_file(LOGIN_SCENE)
