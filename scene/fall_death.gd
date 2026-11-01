extends Area2D

@export_file("*.tscn") var death_scene_path: String = ""
@export var delete_fallen_boxes: bool = true
var _triggered := false

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	#the player is the CharacterBody2D.
	if body is CharacterBody2D:
		_kill_player()
	elif delete_fallen_boxes and body.is_in_group("boxes"):
		body.queue_free()

func _kill_player() -> void:
	if _triggered:
		return                    
	_triggered = true
	if death_scene_path.is_empty():
		push_warning("world_border: pick a Death Scene Path in the Inspector.")
		_triggered = false
		return
	var stats := get_node_or_null("/root/GameStats")
	if stats:
		stats.level_failed()        #stop the attempt timer
	#deffered cuz godot
	get_tree().change_scene_to_file.call_deferred(death_scene_path)
