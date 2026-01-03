extends CharacterBody2D

@onready var sprite := $Sprite2D
@onready var interaction_ray := $ShapeCast2D

@export var speed := 150.0
@export var acceleration := 1200.0
@export var friction := 1400.0
@export var walk_fps := 8.0

var anim_timer := 0.0
var facing_dir := Vector2.DOWN
var last_dir := Vector2.ZERO


func _ready():
	interaction_ray.enabled = true


func _input(event): 
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


func _physics_process(delta):
	
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

	update_animation(delta, facing_dir, velocity.length() > 0.01)

	if direction != Vector2.ZERO:
		velocity = velocity.move_toward(direction * speed, acceleration * delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)

	if velocity.length() < 5.0:
		velocity = Vector2.ZERO

	move_and_slide()


func get_anim_offset(dir: Vector2) -> int:
	if dir.y > 0:
		return 0      # DOWN
	elif dir.x > 0:
		return 4      # RIGHT
	elif dir.x < 0:
		return 8      # LEFT
	else:
		return 12     # UP


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
		var target: Object = interaction_ray.get_collider(0)

		if target and target.has_method("interact"):
			target.interact(self)
