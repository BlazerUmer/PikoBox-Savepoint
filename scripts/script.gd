extends CharacterBody2D

#speed per size: smaller = faster (8 px is the fastest).
const SMALL_SIZE := 8
const MEDIUM_SIZE := 24
const LARGE_SIZE := 40
const SPEEDS := {SMALL_SIZE: 400.0, MEDIUM_SIZE: 300.0, LARGE_SIZE: 200.0}
const SIZE_NUMBERS := {SMALL_SIZE: 1, MEDIUM_SIZE: 2, LARGE_SIZE: 3}   # what the HUD shows
const JUMP_VELOCITY = -400.0               #jump strength at the medium (default) size
const BASE_SIZE := 8
const GROW_LIFT := 1.0                     #px the player is lifted when growing, so it never sinks into a box
const JUMP_REFERENCE_SIZE := 24.0
const DEFAULT_BOX_SIZE := Vector2(16.0, 16.0) # dimensions the box scene was authored at
@export_group("Box Settings")
@export_enum("16:16", "24:24", "32:32", "48:48", "60:60") var box_size_px: int = 16   #pick this level's box size in the Inspector
var box_size: Vector2 = Vector2(16.0, 16.0)
@export var box_jump_bonus: float = 2.8   #extra jump strength for every pixel the box is bigger than 16

@export_enum("8:8", "24:24", "40:40") var start_size: int = 24   #default starting size (must match the sizes above)
@export var box_scene: PackedScene
@export var max_boxes: int = 3
@export var push_force: float = 40.0
@export var box_spawn_lift: float = 0.0

@export_group("Jump Feel")
@export var coyote_time: float = 0.1          #seconds after leaving the ground you can still jump
@export var jump_buffer_time: float = 0.1     #seconds before landing a jump press is remembered

@export_group("Sprite")
@export var sprite_faces_right: bool = true   #art is flipped
@export var outline_color: Color = Color("#17141c")
@export var outline_below_size: float = 16.0  #outline shows while the sprite is smaller than this (size 1 = 8)
@export var outline_thickness: float = 1.0    #in pixels

@export_group("Level limits")
@export var allowed_sizes: Array[int] = [8, 24, 40]
@export var max_size_switches: int = 0
@export var can_place_boxes: bool = true
@export var box_limit: int = 0
@export_enum("Sizes only", "Sizes and boxes") var hud_content: String = "Sizes only"

@export var size_change_speed: float = 12.0
@export var max_resize_push: int = 10     #how many px the player may be nudged to make room when growing

@export_group("HUD")
@export var hud_font: Font
@export var hud_font_size: int = 7
@export var hud_margin: Vector2 = Vector2(10.0, 8.0)
@export var show_points: bool = true            #POINTS line
@export var show_collected: bool = true         #COLLECTED line (only appears in levels that have collectibles)
@export var show_current_size: bool = true      #CURRENT SIZE line
@export var show_size_changes: bool = true      #SIZE CHANGES line
#the BOXES line is still controlled by "Hud Content" in the Level limits group

@export_group("Feedback Colors")
@export var denied_color: Color = Color("#000000")       #Black: resize denied
@export var resize_color: Color = Color("#9b5de5")       #Purple: successful resize
@export var no_boxes_color: Color = Color("#ff2d2d")     #Red: out of boxes
@export var box_denied_color: Color = Color("#d95a00")   #Dark orange: can't place box

var flash_material: ShaderMaterial
var flash_tween: Tween
var outline_material: ShaderMaterial
var outline_sprites: Array[Sprite2D] = []
var outline_dirs: Array[Vector2] = []
var visual_size: float
var sprite_base_position: Vector2
var push_offset: Vector2 = Vector2.ZERO    #visual catch-up after being nudged out of a wall
var size_switches_used: int = 0
var boxes_placed: int = 0
var points_label: Label
var collected_label: Label
var current_size_label: Label
var sizes_label: Label
var boxes_label: Label

var current_size: int
var facing: int = 1                        #left right logic
var coyote_timer: float = 0.0
var jump_buffer_timer: float = 0.0
var held_boxes: Array = []                 #boxes we're standing on, frozen so we can't squash them

@onready var sprite: Sprite2D = $MainCharac
@onready var collision: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	box_size = Vector2(box_size_px, box_size_px)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST  #redundant ik
	sprite_base_position = sprite.position
	_setup_flash()
	_setup_outline()
	_setup_counter_hud()
	current_size = start_size
	visual_size = float(current_size)
	_apply_size(current_size)
	_update_visual()
	_update_counter_hud()
	_connect_game_state()
	call_deferred("_start_level")      #deferred so every collectible has registered itself first

#still works in a scene/project where it hasn't been added.
func _gs() -> Node:
	return get_node_or_null("/root/GameState")

func _connect_game_state() -> void:
	var gs := _gs()
	if gs and not gs.stats_changed.is_connected(_update_counter_hud):
		gs.stats_changed.connect(_update_counter_hud)

func _start_level() -> void:
	var gs := _gs()
	if gs:
		gs.start_level()

func _setup_counter_hud() -> void:
	var layer := CanvasLayer.new()
	layer.name = "PlayerCounterHUD"
	layer.layer = 10
	add_child(layer)
#hud code

	var column := VBoxContainer.new()
	column.name = "CounterColumn"
	column.add_theme_constant_override("separation", 0)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(column)
	column.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	column.grow_vertical = Control.GROW_DIRECTION_BEGIN
	column.offset_left = hud_margin.x
	column.offset_right = hud_margin.x
	column.offset_bottom = -hud_margin.y
	column.offset_top = -hud_margin.y

	var font := _get_hud_font()
	var gs := _gs()
	if gs:
		gs.ui_font = font               #collectible popups reuse the same pixel font
		
	points_label = _make_hud_label("PointsLabel", font)
	points_label.visible = show_points
	column.add_child(points_label)
	collected_label = _make_hud_label("CollectedLabel", font)
	collected_label.visible = show_collected
	column.add_child(collected_label)
	current_size_label = _make_hud_label("CurrentSizeLabel", font)
	current_size_label.visible = show_current_size
	column.add_child(current_size_label)
	sizes_label = _make_hud_label("SizesLeftLabel", font)
	sizes_label.visible = show_size_changes
	column.add_child(sizes_label)
	boxes_label = _make_hud_label("BoxesLeftLabel", font)
	boxes_label.visible = hud_content == "Sizes and boxes"
	column.add_child(boxes_label)
	_update_counter_hud()

func _get_hud_font() -> Font:
	var font: Font = hud_font
	if font == null:
		var found := _find_font_file("res://", 0)
		if found != "":
			font = load(found) as Font
	if font == null:
		push_warning("HUD font not found. Drag the PixelifySans .ttf into Hud Font on the player.")
		return null

	if font is FontFile:
		var file := font as FontFile
		file.antialiasing = TextServer.FONT_ANTIALIASING_NONE
		file.hinting = TextServer.HINTING_NONE
		file.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	return font

func _find_font_file(dir_path: String, depth: int) -> String:
	if depth > 6:
		return ""
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return ""
	var fallback := ""
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if dir.current_is_dir():
			if not entry.begins_with(".") and entry != "addons":
				var sub := _find_font_file(dir_path.path_join(entry), depth + 1)
				if sub != "":
					dir.list_dir_end()
					return sub
		else:
			var clean := entry.trim_suffix(".import").trim_suffix(".remap")   #also works in exported games
			if clean.begins_with("PixelifySans") and (clean.ends_with(".ttf") or clean.ends_with(".otf")):
				if clean.contains("Regular"):
					dir.list_dir_end()
					return dir_path.path_join(clean)
				if fallback == "":
					fallback = dir_path.path_join(clean)
		entry = dir.get_next()
	dir.list_dir_end()
	return fallback

func _make_hud_label(label_name: String, font: Font) -> Label:
	var label := Label.new()
	label.name = label_name
	label.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST  #redundant again ik
	label.add_theme_color_override("font_color", Color.BLACK)
	label.add_theme_font_size_override("font_size", hud_font_size)
	if font:
		label.add_theme_font_override("font", font)
	return label

func _update_counter_hud() -> void:
	if points_label == null or collected_label == null \
			or current_size_label == null or sizes_label == null or boxes_label == null:
		return
	var gs := _gs()
	var pts: int = gs.points if gs else 0
	var got: int = gs.collected if gs else 0
	var total: int = gs.total_collectibles if gs else 0
	points_label.text = "POINTS: " + str(pts)
	collected_label.text = "COLLECTED: %d/%d" % [got, total]
	collected_label.visible = show_collected and total > 0      #also hidden in levels with no collectibles
	var sizes_remaining := "∞" if max_size_switches <= 0 else str(maxi(max_size_switches - size_switches_used, 0))
	var boxes_remaining := "∞" if box_limit <= 0 else str(maxi(box_limit - boxes_placed, 0))
	current_size_label.text = "CURRENT SIZE: " + str(SIZE_NUMBERS.get(current_size, current_size))
	sizes_label.text = "SIZE CHANGES: " + sizes_remaining
	boxes_label.text = "BOXES: " + boxes_remaining

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_1:
			set_character_size(SMALL_SIZE)
		elif event.keycode == KEY_2:
			set_character_size(MEDIUM_SIZE)
		elif event.keycode == KEY_3:
			set_character_size(LARGE_SIZE)
		elif event.keycode == KEY_E:
			place_box()

func set_character_size(new_size: int) -> void:
	if new_size == current_size:
		return
	if not allowed_sizes.has(new_size):
		print("[limit] size ", new_size, " is not allowed in this level")
		_flash_denied()
		return
	if max_size_switches > 0 and size_switches_used >= max_size_switches:
		print("[limit] no size switches left")
		_flash_denied()
		return

	var old_size := current_size
	var old_position := position
	var old_rect := _get_body_rect()     #hitbox before resizing (used for the swept path check)
	#keep the feet anchored, then apply the new size
	position.y -= (new_size - current_size) / 2.0
	if new_size > old_size:
		#no box clipping
		position.y -= GROW_LIFT
	current_size = new_size
	_apply_size(current_size)

	if new_size > old_size:
		var offset := _find_free_offset(old_rect, old_size)
		if offset.x == INF:
			#genuinely no room (tight corridor, roof + floor, etc.) -> deny
			position = old_position
			current_size = old_size
			_apply_size(current_size)
			print("[limit] no room to grow to ", new_size, " here")
			_flash_denied()
			return
		#sprite stays where it visually was and slides into the new spot
		push_offset -= offset

	size_switches_used += 1
	_update_counter_hud()
	_flash_color(resize_color)

func _find_free_offset(old_rect: Rect2, old_size: int) -> Vector2:
	var base := position
	var dirs := [
		Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT,
		Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)
	]
	if _real_hitbox_is_free(true):
		return Vector2.ZERO
	for d in range(1, max_resize_push + 1):
		for dir in dirs:
			var offset: Vector2 = dir * d
			position = base + offset
			if not _real_hitbox_is_free():
				continue
			#where the old hitbox's center would need to travel to get here
			var travel := (collision.global_position - old_rect.get_center())
			if _sweep_is_clear(old_rect.get_center(), travel, old_size):
				return offset
	position = base
	return Vector2(INF, INF)

func _sweep_is_clear(from_center: Vector2, motion: Vector2, size_px: int) -> bool:
	if motion.length() < 0.01:
		return true
	var shape := RectangleShape2D.new()
	var s := maxf(float(size_px) - 2.0, 1.0)   #slightly smaller so resting on the floor doesn't count
	shape.size = Vector2(s, s)
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0.0, from_center)
	query.motion = motion
	query.collision_mask = collision_mask
	query.exclude = [get_rid()]
	var res := get_world_2d().direct_space_state.cast_motion(query)
	if res.size() < 2:
		return true
	return res[0] >= 1.0

func _apply_size(px: int) -> void:

	var s := float(px) / BASE_SIZE
	collision.scale = Vector2(s, s)


func _process(delta: float) -> void:
	#slide the sprite from where it visually was into the nudged position
	if push_offset != Vector2.ZERO:
		push_offset = push_offset.lerp(Vector2.ZERO, 1.0 - exp(-size_change_speed * delta))
		if push_offset.length() < 0.05:
			push_offset = Vector2.ZERO

	#using lerp like someone recommended on slack
	if not is_equal_approx(visual_size, float(current_size)):
		if size_change_speed <= 0.0:
			visual_size = float(current_size)
		else:
			visual_size = lerpf(visual_size, float(current_size), 1.0 - exp(-size_change_speed * delta))
			if absf(visual_size - current_size) < 0.05:
				visual_size = float(current_size)
	_update_visual()

func _update_visual() -> void:
	var s := visual_size / BASE_SIZE
	sprite.scale = Vector2(s, s)
	sprite.position = sprite_base_position + Vector2(0.0, (current_size - visual_size) / 2.0) + push_offset
	#face the way you're walking, so you can tell where a box will be placed
	sprite.flip_h = (facing < 0) if sprite_faces_right else (facing > 0)
	_update_outline()


#dark outline in size 1
func _setup_outline() -> void:
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;
uniform vec4 outline_color : source_color = vec4(0.09, 0.08, 0.11, 1.0);
void fragment() {
	COLOR = vec4(outline_color.rgb, COLOR.a);
}
"""
	outline_material = ShaderMaterial.new()
	outline_material.shader = shader
	outline_material.set_shader_parameter("outline_color", outline_color)

	outline_dirs = [
		Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1),
		Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)
	]
	for i in outline_dirs.size():
		var o := Sprite2D.new()
		o.name = "Outline%d" % i
		o.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		o.material = outline_material
		o.visible = false
		add_child(o)
		move_child(o, sprite.get_index())    #drawn behind the main sprite
		outline_sprites.append(o)

func _update_outline() -> void:
	var show_outline := visual_size < outline_below_size
	for i in outline_sprites.size():
		var o := outline_sprites[i]
		o.visible = show_outline
		if not show_outline:
			continue
		#copy everything that affects how the sprite looks
		o.texture = sprite.texture
		o.hframes = sprite.hframes
		o.vframes = sprite.vframes
		o.frame = sprite.frame
		o.region_enabled = sprite.region_enabled
		o.region_rect = sprite.region_rect
		o.centered = sprite.centered
		o.offset = sprite.offset
		o.flip_h = sprite.flip_h
		o.flip_v = sprite.flip_v
		o.scale = sprite.scale
		o.position = sprite.position + outline_dirs[i] * outline_thickness

func _setup_flash() -> void:
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;
uniform vec4 flash_color : source_color = vec4(1.0);
uniform float amount : hint_range(0.0, 1.0) = 0.0;
void fragment() {
	COLOR = vec4(mix(COLOR.rgb, flash_color.rgb, amount), COLOR.a);
}
"""
	flash_material = ShaderMaterial.new()
	flash_material.shader = shader
	flash_material.set_shader_parameter("flash_color", denied_color)
	flash_material.set_shader_parameter("amount", 0.0)
	sprite.material = flash_material

func _flash_color(color: Color, duration: float = 0.35) -> void:
	#reusing sprite
	if flash_material == null:
		return
	if flash_tween:
		flash_tween.kill()
	flash_material.set_shader_parameter("flash_color", color)
	flash_tween = create_tween()
	flash_tween.tween_method(
		func(v: float) -> void: flash_material.set_shader_parameter("amount", v),
		1.0, 0.0, duration)

func _flash_denied() -> void:
	#Black glow when a resize is refused.
	_flash_color(denied_color)


func _get_jump_velocity() -> float:
	#Jump height grows in proportion to size (bigger = higher, smaller = lower),

	var extra_box_px := maxf(float(box_size_px) - DEFAULT_BOX_SIZE.x, 0.0)
	var base_jump := JUMP_VELOCITY - extra_box_px * box_jump_bonus   # more negative = higher
	return base_jump * sqrt(current_size / JUMP_REFERENCE_SIZE)


func _get_speed() -> float:
	return SPEEDS[current_size]
	
#box placing
func place_box() -> void:
	print("[box] E pressed")

	if current_size != MEDIUM_SIZE:
		print("[box] STOP: only the ", MEDIUM_SIZE, " px size can place boxes")
		_flash_color(box_denied_color, 0.5)
		return
	if not can_place_boxes:
		print("[limit] boxes are turned off in this level")
		_flash_color(box_denied_color, 0.5)
		return
	if box_limit > 0 and boxes_placed >= box_limit:
		print("[limit] no boxes left")
		_flash_color(no_boxes_color, 0.5)
		return

	if box_scene == null:
		print("[box] STOP: box_scene is empty - assign box.tscn on the player in the Inspector.")
		_flash_color(box_denied_color, 0.5)
		return

	var body_rect := _get_body_rect()
	print("[box] player collision rect: ", body_rect)
	var spawn_x := body_rect.get_center().x + facing * (body_rect.size.x / 2.0 + box_size.x / 2.0 + 1.0)
	var base_y := body_rect.end.y - box_size.y / 2.0 - 1.0 - box_spawn_lift

	var pos := Vector2.ZERO
	var found := false
	for lift in [0.0, 2.0, 4.0, 8.0, 12.0, 16.0]:
		pos = Vector2(spawn_x, base_y - lift)
		if _can_place_box(pos):
			found = true
			break
	if not found:
		print("[box] STOP: no free spot in front of him (a wall is right there)")
		_flash_color(box_denied_color, 0.5)
		return

	var box := box_scene.instantiate() as Node2D
	_apply_box_size(box)
	get_parent().add_child(box)
	box.global_position = pos
	boxes_placed += 1
	_update_counter_hud()
	print("[box] placed at ", pos, " | size: ", box_size_px)

	#remove old boxes
	if max_boxes > 0:
		var boxes := get_tree().get_nodes_in_group("boxes")
		while boxes.size() > max_boxes:
			boxes[0].queue_free()
			boxes.remove_at(0)

func _get_body_rect() -> Rect2:
	var rect_shape := collision.shape as RectangleShape2D
	if rect_shape == null:
		return Rect2(global_position - Vector2(current_size, current_size) / 2.0,
			Vector2(current_size, current_size))
	var size := rect_shape.size * collision.global_scale.abs()
	return Rect2(collision.global_position - size / 2.0, size)

func _hits_in_rect(rect: Rect2) -> Array:
	const SHRINK := 0.25
	var test := RectangleShape2D.new()
	test.size = Vector2(maxf(rect.size.x - SHRINK * 2.0, 1.0), maxf(rect.size.y - SHRINK * 2.0, 1.0))
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = test
	query.transform = Transform2D(0.0, rect.get_center())
	query.collision_mask = collision_mask
	query.exclude = [get_rid()]
	return get_world_2d().direct_space_state.intersect_shape(query, 32)

func _hit_key(hit: Dictionary) -> String:
	var body_rid: RID = hit["rid"]
	return "%d_%d" % [body_rid.get_id(), int(hit["shape"])]

#true if the current (resized) hitbox overlaps nothing. Pass verbose = true to print blockers.
func _real_hitbox_is_free(verbose: bool = false) -> bool:
	var rect := _get_body_rect()
	var blocked := false
	for hit in _hits_in_rect(rect):
		blocked = true
		if verbose:
			print("[grow] blocked by: ", hit["collider"], " | new hitbox: ", rect,
				" | blocking shape: ", _blocker_bounds(hit))
	return not blocked

func _blocker_bounds(hit: Dictionary) -> String:
	var body_rid: RID = hit["rid"]
	var idx: int = hit["shape"]
	var shape_rid := PhysicsServer2D.body_get_shape(body_rid, idx)
	var xf: Transform2D = PhysicsServer2D.body_get_state(body_rid, PhysicsServer2D.BODY_STATE_TRANSFORM) \
		* PhysicsServer2D.body_get_shape_transform(body_rid, idx)
	var data = PhysicsServer2D.shape_get_data(shape_rid)
	var points := PackedVector2Array()
	if data is PackedVector2Array:
		points = data
	elif data is Vector2:
		var h: Vector2 = data
		points = PackedVector2Array([-h, Vector2(h.x, -h.y), h, Vector2(-h.x, h.y)])
	else:
		return "unknown shape"
	var bounds := Rect2(xf * points[0], Vector2.ZERO)
	for p in points:
		bounds = bounds.expand(xf * p)
	return str(bounds)


func _apply_box_size(box: Node) -> void:
	if "box_size_px" in box:
		box.set("box_size_px", box_size_px)
	elif box is Node2D:
		(box as Node2D).scale = Vector2(
			box_size.x / DEFAULT_BOX_SIZE.x,
			box_size.y / DEFAULT_BOX_SIZE.y
		)


func _can_place_box(pos: Vector2) -> bool:
	var shape := RectangleShape2D.new()
	shape.size = Vector2(maxf(box_size.x - 2.0, 1.0), maxf(box_size.y - 2.0, 1.0))
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0.0, pos)
	query.collision_mask = 1
	query.exclude = [get_rid()]
	var hits := get_world_2d().direct_space_state.intersect_shape(query, 4)
	for hit in hits:
		print("[box] blocked by: ", hit["collider"], " | box spot: ", pos, " | player at: ", global_position)
	return hits.is_empty()


#pushing boxes.didnt get to much with this

func _push_boxes() -> void:

	for i in get_slide_collision_count():
		var hit := get_slide_collision(i)
		var body := hit.get_collider() as RigidBody2D

		if body and absf(hit.get_normal().x) > 0.7:

			var strength := push_force * (current_size / float(MEDIUM_SIZE))
			body.apply_central_impulse(-hit.get_normal() * strength)

func _hold_boxes_under_feet() -> void:
	var under: Array = []
	if coyote_timer > 0.0:                   #on the ground (or just left it without jumping)
		under = _boxes_under_feet()

	for box in held_boxes.duplicate():
		if not is_instance_valid(box):
			held_boxes.erase(box)
		elif not under.has(box):
			box.freeze = false
			box.sleeping = false
			held_boxes.erase(box)

	for box in under:
		if not held_boxes.has(box):
			box.freeze_mode = RigidBody2D.FREEZE_MODE_STATIC
			box.freeze = true
			held_boxes.append(box)


func _boxes_under_feet() -> Array:
	var rect := _get_body_rect()
	var probe := RectangleShape2D.new()
	probe.size = Vector2(maxf(rect.size.x - 2.0, 1.0), 2.0)
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = probe
	query.transform = Transform2D(0.0, Vector2(rect.get_center().x, rect.end.y + 1.0))
	query.collision_mask = collision_mask
	query.exclude = [get_rid()]
	var found: Array = []
	for hit in get_world_2d().direct_space_state.intersect_shape(query, 8):
		var body := hit["collider"] as RigidBody2D
		if body and not found.has(body):
			found.append(body)
	return found


func _exit_tree() -> void:
	#never leave a box stuck frozen if the player is removed (restart, scene change)
	for box in held_boxes:
		if is_instance_valid(box):
			box.freeze = false


#movement

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta

	#coyote time: standing on the ground refills the window, leaving it drains it
	if is_on_floor():
		coyote_timer = coyote_time
	else:
		coyote_timer = maxf(coyote_timer - delta, 0.0)

	#jump buffer: remember a jump press for a short moment
	if Input.is_action_just_pressed("jump") or Input.is_action_just_pressed("ui_accept"):
		jump_buffer_timer = jump_buffer_time
	else:
		jump_buffer_timer = maxf(jump_buffer_timer - delta, 0.0)

	#jump if a press is buffered AND we're on the ground or still inside the coyote window
	if jump_buffer_timer > 0.0 and coyote_timer > 0.0:
		velocity.y = _get_jump_velocity()
		jump_buffer_timer = 0.0
		coyote_timer = 0.0     #no double jump

	var direction := clampf(
		Input.get_axis("left", "right") + Input.get_axis("ui_left", "ui_right"), -1.0, 1.0)
	if direction:
		facing = 1 if direction > 0 else -1
		velocity.x = direction * _get_speed()
	else:
		velocity.x = move_toward(velocity.x, 0, _get_speed())

	move_and_slide()
	_push_boxes()
	_hold_boxes_under_feet()
