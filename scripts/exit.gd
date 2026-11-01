extends Button

func _ready() -> void:
	if OS.has_feature("web"):
		hide()   #gonna export to browser so hiding the exit button
		return    #not needed but might as well
	pressed.connect(_on_pressed)

func _on_pressed() -> void:
	get_tree().quit()
