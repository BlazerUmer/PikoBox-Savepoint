extends Area2D
#placeholder diamond for testing

@export var points: int = 100
@export var bob_height: float = 2.0          #px the collectible floats up and down
@export var bob_speed: float = 3.0
@export var popup_color: Color = Color("#ffd84a")
@export_group("Placeholder (when there is no Sprite2D)")
@export var placeholder_color: Color = Color("#ffd84a")
@export var placeholder_outline: Color = Color("#17141c")
@export var placeholder_size: float = 8.0
 
var _collected: bool = false
var _time: float = 0.0
var _bob: float = 0.0
var _sprite: Sprite2D
var _sprite_base_y: float = 0.0

func _ready()->void:
	add_to_group("collectibles")
	_sprite=get_node_or_null("Sprite2D")as Sprite2D
	if _sprite:
		_sprite.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
		_sprite_base_y=_sprite.position.y
	_ensure_collision_shape()
	_time=randf()*TAU
	body_entered.connect(_on_body_entered)
	
func _ensure_collision_shape()->void:
	for child in get_children():
		if child is CollisionShape2D or child is CollisionPolygon2D:
		#did polygon for future upgradability
			return
	var shape_node:=CollisionShape2D.new()
	var rect:=RectangleShape2D.new()
	shape_node.shape=rect
	add_child(shape_node)
	
func _process(delta: float) -> void:
	if _collected:
		return
	_time += delta
	_bob = sin(_time * bob_speed) * bob_height
	if _sprite:
		_sprite.position.y = _sprite_base_y + _bob
	else:
		queue_redraw()

func _draw() -> void:
	if _sprite != null:
		return
	var h := placeholder_size / 2.0
	var c := Vector2(0.0, _bob)
	var diamond := PackedVector2Array([
		c + Vector2(0, -h), c + Vector2(h, 0), c + Vector2(0, h), c + Vector2(-h, 0)
	])
	draw_colored_polygon(diamond, placeholder_color)
	draw_polyline(PackedVector2Array([diamond[0], diamond[1], diamond[2], diamond[3], diamond[0]]),
		placeholder_outline, 1.0)
		
func _on_body_entered(body: Node) -> void:
	if _collected:
		return
	if not body.has_method("set_character_size"):    #only the player collects things
		return
	_collected = true
	set_deferred("monitoring", false)
	var gs := get_node_or_null("/root/GameState")
	if gs:
		gs.collect(points)
	_show_popup(gs.ui_font if gs else null)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(self, "scale", Vector2(1.5, 1.5), 0.15)
	tween.tween_property(self, "modulate:a", 0.0, 0.15)
	tween.chain().tween_callback(queue_free)
	
	#popup text
func _show_popup(font: Font) -> void:
	var host := get_parent()
	if host == null:
		return
	var label := Label.new()
	label.text = "+%d" % points
	label.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	label.z_index = 100
	label.add_theme_font_size_override("font_size", 7)
	label.add_theme_color_override("font_color", popup_color)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 2)
	if font:
		label.add_theme_font_override("font", font)
	host.add_child(label)
	label.global_position = global_position + Vector2(-8.0, -16.0)
 
	var tween := label.create_tween().set_parallel(true)
	tween.tween_property(label, "global_position:y", label.global_position.y - 12.0, 0.6)
	tween.tween_property(label, "modulate:a", 0.0, 0.6).set_delay(0.25)
	tween.chain().tween_callback(label.queue_free)
	
