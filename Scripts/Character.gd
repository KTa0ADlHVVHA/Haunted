extends CharacterBody2D

@onready var sprite := $Sprite2D
@onready var interaction_ray := $ShapeCast2D

# Pause menu icons
@onready var save_icon := $"Pause Menu/Save"
@onready var load_icon := $"Pause Menu/Load"
@onready var options_icon := $"Pause Menu/Options"
@onready var items_icon := $"Pause Menu/Items"

# Pause overlay (ColorRect with SCREEN_TEXTURE shader)
@onready var pause_overlay :=  $ColorRect

@export var speed := 150.0
@export var acceleration := 1200.0
@export var friction := 1400.0
@export var walk_fps := 8.0

var anim_timer := 0.0
var facing_dir := Vector2.DOWN
var last_dir := Vector2.ZERO
var is_paused := false

# Icon selection state
var icon_index := 0 # 0=Save,1=Load,2=Options,3=Items

# Store original saturation to restore after unpause
var _original_saturation := 1.0


func _ready():
	interaction_ray.enabled = true
	process_mode = Node.PROCESS_MODE_ALWAYS
	_hide_all_icons()
	
	if pause_overlay and pause_overlay.material:
		_original_saturation = pause_overlay.material.get_shader_parameter("saturation")


func _input(event):
	# Block pausing during dialogue
	if GameState.in_dialogue:
		return

	# Toggle pause menu
	if event.is_action_pressed("cancel"):
		toggle_pause()
		return

	# Pause menu navigation & activation
	if is_paused:
		if event.is_action_pressed("right") or event.is_action_pressed("down"):
			rotate_icons(1)
		elif event.is_action_pressed("left") or event.is_action_pressed("up"):
			rotate_icons(-1)
		elif event.is_action_pressed("interact"):
			activate_icon()
		return

	# Normal movement input
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


func toggle_pause():
	is_paused = !is_paused
	if is_paused:
		# Stop player movement and reset animation
		velocity = Vector2.ZERO
		anim_timer = 0.0
		sprite.frame = get_anim_offset(facing_dir)
		icon_index = 0
		update_icon_visibility()

		# Show overlay and halve current saturation
		if pause_overlay:
			pause_overlay.visible = true
			if pause_overlay.material:
				var current_sat = pause_overlay.material.get_shader_parameter("saturation")
				pause_overlay.material.set_shader_parameter("saturation", current_sat * 0.5)

		get_tree().paused = true
	else:
		# Hide menu icons and restore overlay
		_hide_all_icons()
		if pause_overlay:
			if pause_overlay.material:
				pause_overlay.material.set_shader_parameter("saturation", _original_saturation)
			pause_overlay.visible = false

		get_tree().paused = false


func rotate_icons(dir: int):
	icon_index = wrapi(icon_index + dir, 0, 4)
	update_icon_visibility()


func update_icon_visibility():
	save_icon.visible = (icon_index == 0)
	load_icon.visible = (icon_index == 1)
	options_icon.visible = (icon_index == 2)
	items_icon.visible = (icon_index == 3)


func _hide_all_icons():
	save_icon.visible = false
	load_icon.visible = false
	options_icon.visible = false
	items_icon.visible = false


func activate_icon():
	match icon_index:
		0:
			print("Save selected")
		1:
			print("Load selected")
		2:
			print("Options selected")
		3:
			print("Items selected")


func _physics_process(delta):
	# Update menu icons to follow player
	if is_paused:
		save_icon.position = position
		load_icon.position = position
		options_icon.position = position
		items_icon.position = position
		return

	# Dialogue overrides movement
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
	interaction_ray.force_shapecast_update()
	if interaction_ray.is_colliding():
		var target: Object = interaction_ray.get_collider(0)  # 0 = first collider
		if target and target.has_method("interact"):
			target.interact(self)
