extends CharacterBody2D

signal slot_selected(slot: int) # used by SaveMenu

@onready var sprite := $Sprite2D
@onready var interaction_ray := $ShapeCast2D

# Pause menu icons
@onready var save_icon := $"Pause Menu/Save"
@onready var load_icon := $"Pause Menu/Load"
@onready var options_icon := $"Pause Menu/Options"
@onready var items_icon := $"Pause Menu/Items"

@onready var pause_overlay := $ColorRect

@export var speed := 150.0
@export var acceleration := 1200.0
@export var friction := 1400.0
@export var walk_fps := 8.0

var anim_timer := 0.0
var facing_dir := Vector2.DOWN
var last_dir := Vector2.ZERO
var is_paused := false
var icon_index := 0
var _original_saturation := 1.0

# Currently selected save slot
var current_save_slot := 1

# Track if a menu is open
var save_menu_open := false


func _ready():
	interaction_ray.enabled = true
	process_mode = Node.PROCESS_MODE_ALWAYS
	_hide_all_icons()

	if pause_overlay and pause_overlay.material:
		_original_saturation = pause_overlay.material.get_shader_parameter("saturation")
		pause_overlay.visible = false

	is_paused = false
	save_menu_open = false

	# Reset dialogue state
	GameState.in_dialogue = false

	# Load current slot
	SaveManager.set_slot(current_save_slot)
	SaveManager.load_slot(current_save_slot)

	var pos_data = SaveManager.get_value("player_position", null)
	if typeof(pos_data) == TYPE_DICTIONARY:
		global_position = SaveManager.deserialize_vector2(pos_data, global_position)

	var face_data = SaveManager.get_value("player_facing", null)
	if typeof(face_data) == TYPE_DICTIONARY:
		facing_dir = SaveManager.deserialize_vector2(face_data, facing_dir)

	sprite.frame = get_anim_offset(facing_dir)
	update_interaction_ray()


# ------------------- INPUT -------------------
func _input(event):
	if GameState.in_dialogue or not is_inside_tree():
		return

	if event.is_action_pressed("cancel"):
		toggle_pause()
		return

	if is_paused:
		if save_menu_open:
			return
		if event.is_action_pressed("right") or event.is_action_pressed("down"):
			rotate_icons(1)
		elif event.is_action_pressed("left") or event.is_action_pressed("up"):
			rotate_icons(-1)
		elif event.is_action_pressed("interact"):
			activate_icon()
		return

	if event.is_action_pressed("right"):
		last_dir = Vector2.RIGHT
	elif event.is_action_pressed("left"):
		last_dir = Vector2.LEFT
	elif event.is_action_pressed("down"):
		last_dir = Vector2.DOWN
	elif event.is_action_pressed("up"):
		last_dir = Vector2.UP

	if event.is_action_pressed("interact"):
		try_interact()


# ------------------- PAUSE -------------------
func toggle_pause():
	if save_menu_open:
		return

	is_paused = !is_paused

	if is_paused:
		velocity = Vector2.ZERO
		anim_timer = 0.0
		sprite.frame = get_anim_offset(facing_dir)
		icon_index = 0
		update_icon_visibility()

		if pause_overlay:
			pause_overlay.visible = true
			if pause_overlay.material:
				var sat = pause_overlay.material.get_shader_parameter("saturation")
				pause_overlay.material.set_shader_parameter("saturation", sat * 0.5)

		_set_tree_paused(true)
	else:
		_hide_all_icons()
		if pause_overlay:
			if pause_overlay.material:
				pause_overlay.material.set_shader_parameter("saturation", _original_saturation)
			pause_overlay.visible = false

		_set_tree_paused(false)


func _set_tree_paused(p: bool):
	if is_inside_tree() and get_tree():
		get_tree().paused = p


func rotate_icons(dir: int):
	icon_index = wrapi(icon_index + dir, 0, 4)
	update_icon_visibility()


func update_icon_visibility():
	save_icon.visible = icon_index == 0
	load_icon.visible = icon_index == 1
	options_icon.visible = icon_index == 2
	items_icon.visible = icon_index == 3


func _hide_all_icons():
	save_icon.visible = false
	load_icon.visible = false
	options_icon.visible = false
	items_icon.visible = false


func activate_icon():
	match icon_index:
		0:
			open_save_menu()
		1:
			load_game()
		2:
			print("Options selected")
		3:
			print("Items selected")


# ------------------- SAVE MENU -------------------
func open_save_menu():
	if save_menu_open:
		return
	save_menu_open = true
	is_paused = true
	_set_tree_paused(true)

	var menu_scene := preload("res://Scenes/SaveMenu.tscn").instantiate()
	add_child(menu_scene)
	menu_scene.connect("slot_selected", Callable(self, "_on_save_slot_selected"))
	menu_scene.connect("tree_exited", Callable(self, "_on_save_menu_closed"))


func _on_save_slot_selected(slot: int):
	current_save_slot = slot
	SaveManager.set_slot(slot)

	# Save player data to the chosen slot
	if is_inside_tree() and get_tree():
		SaveManager.set_value("scene_path", get_tree().current_scene.scene_file_path)
	SaveManager.set_value("player_position", SaveManager.serialize_vector2(global_position))
	SaveManager.set_value("player_facing", SaveManager.serialize_vector2(facing_dir))
	SaveManager.save()


func _on_save_menu_closed():
	save_menu_open = false
	if is_paused and is_inside_tree():
		toggle_pause()


# ------------------- LOAD -------------------
func load_game():
	SaveManager.set_slot(current_save_slot)
	SaveManager.load_slot(current_save_slot)
	var scene_path = SaveManager.get_value("scene_path", "")
	if scene_path != "":
		# Reset overlay & pause state before changing scene
		if pause_overlay:
			pause_overlay.visible = false
			if pause_overlay.material:
				pause_overlay.material.set_shader_parameter("saturation", _original_saturation)

		is_paused = false
		save_menu_open = false
		_set_tree_paused(false)

		if get_tree():
			get_tree().change_scene_to_file(scene_path)
			# no deferred or yield needed — new player `_ready()` resets state


# ------------------- PHYSICS / MOVEMENT -------------------
func _physics_process(delta):
	if is_paused:
		# Keep icons following the player
		save_icon.position = position
		load_icon.position = position
		options_icon.position = position
		items_icon.position = position
		return

	if GameState.in_dialogue:
		velocity = Vector2.ZERO
		anim_timer = 0.0
		sprite.frame = get_anim_offset(facing_dir)
		move_and_slide()
		return

	var direction := Vector2.ZERO

	if last_dir == Vector2.RIGHT and Input.is_action_pressed("right"):
		direction = Vector2.RIGHT
	elif last_dir == Vector2.LEFT and Input.is_action_pressed("left"):
		direction = Vector2.LEFT
	elif last_dir == Vector2.DOWN and Input.is_action_pressed("down"):
		direction = Vector2.DOWN
	elif last_dir == Vector2.UP and Input.is_action_pressed("up"):
		direction = Vector2.UP
	else:
		if Input.is_action_pressed("right"):
			direction = Vector2.RIGHT
		elif Input.is_action_pressed("left"):
			direction = Vector2.LEFT
		elif Input.is_action_pressed("down"):
			direction = Vector2.DOWN
		elif Input.is_action_pressed("up"):
			direction = Vector2.UP

	if direction != Vector2.ZERO:
		if direction != facing_dir:
			anim_timer = 0.0
			sprite.frame = get_anim_offset(direction)
		facing_dir = direction
		update_interaction_ray()

	update_animation(delta, facing_dir, direction != Vector2.ZERO)

	if direction != Vector2.ZERO:
		velocity = velocity.move_toward(direction * speed, acceleration * delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)

	if velocity.length() < 5.0:
		velocity = Vector2.ZERO

	move_and_slide()


# ------------------- ANIMATION -------------------
func get_anim_offset(dir: Vector2) -> int:
	if dir.y > 0:
		return 0
	elif dir.x > 0:
		return 4
	elif dir.x < 0:
		return 8
	else:
		return 12


func update_animation(delta: float, facing: Vector2, is_moving: bool):
	var offset := get_anim_offset(facing)
	if is_moving:
		anim_timer += delta
		if anim_timer >= 1.0 / walk_fps:
			anim_timer = 0.0
			var local_frame: int = sprite.frame - offset
			sprite.frame = offset + ((local_frame + 1) % 4)
	else:
		anim_timer = 0.0
		sprite.frame = offset


func update_interaction_ray():
	interaction_ray.rotation = facing_dir.angle() - PI / 2


func try_interact():
	if not is_inside_tree():
		return
	interaction_ray.force_shapecast_update()
	if interaction_ray.is_colliding():
		var target: Object = interaction_ray.get_collider(0)
		if target and target.has_method("interact"):
			target.interact(self)
