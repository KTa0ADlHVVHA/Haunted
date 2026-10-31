extends CharacterBody2D


# ============================================================
# NODES
# ============================================================

@onready var sprite: Sprite2D = $Sprite2D
@onready var follower_sprite: Sprite2D = $Sprite2D2
@onready var interaction_ray: ShapeCast2D = $ShapeCast2D

@onready var save_icon = $"Pause Menu/Save"
@onready var load_icon = $"Pause Menu/Load"
@onready var options_icon = $"Pause Menu/Options"
@onready var items_icon = $"Pause Menu/Items"

@onready var pause_overlay = $ColorRect


# ============================================================
# MOVEMENT
# ============================================================

# Normal movement speed.
@export var walk_speed: float = 110.0

# Holding Shift uses your original speed.
@export var run_speed: float = 150.0

@export var acceleration: float = 1200.0
@export var friction: float = 1400.0

@export var walk_fps: float = 8.0


# ============================================================
# CORNER ASSIST
# ============================================================

@export var corner_assist_enabled: bool = true

@export var corner_assist_distance: float = 6.0

@export var corner_assist_nudge: float = 1.0

@export var collision_safe_margin: float = 0.01

const CORNER_TEST_MARGIN: float = 0.001


# ============================================================
# PLAYER STATE
# ============================================================

var anim_timer: float = 0.0

var facing_dir: Vector2 = Vector2.DOWN

var last_dir: Vector2 = Vector2.ZERO


# ============================================================
# PAUSE MENU
# ============================================================

var is_paused: bool = false

var icon_index: int = 0

var save_menu_open: bool = false

var _original_saturation: float = 1.0


# ============================================================
# FOLLOWER
# ============================================================

@export var dad_follow_distance: float = 17.0

@export var dad_follow_delay: int = 6

@export var dad_follow_smooth: float = 1000.0

@export var follower_dir_change_threshold: float = 2.0

@export var follower_min_move_to_animate: float = 0.5


var follower_last_dir: Vector2 = Vector2.DOWN

var follower_prev_pos: Vector2 = Vector2.ZERO

var follower_anim_timer: float = 0.0


var _position_history: Array[Vector2] = []


const MAX_HISTORY: int = 240


# ============================================================
# READY
# ============================================================

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING

	safe_margin = collision_safe_margin


	interaction_ray.enabled = true


	_hide_all_icons()


	if (
		pause_overlay
		and pause_overlay.material
	):
		_original_saturation = (
			pause_overlay.material.get_shader_parameter(
				"saturation"
			)
		)


	if pause_overlay:
		pause_overlay.visible = false


	is_paused = false

	save_menu_open = false


	# --------------------------------------------------------
	# LOAD PENDING SAVE DATA
	# --------------------------------------------------------

	if SaveManager.has_pending_load():

		var load_data: Dictionary = (
			SaveManager.consume_pending_load()
		)


		var position_data = load_data.get(
			"player_position",
			null
		)


		if typeof(position_data) == TYPE_DICTIONARY:

			global_position = (
				SaveManager.deserialize_vector2(
					position_data,
					global_position
				)
			)


		var facing_data = load_data.get(
			"player_facing",
			null
		)


		if typeof(facing_data) == TYPE_DICTIONARY:

			facing_dir = (
				SaveManager.deserialize_vector2(
					facing_data,
					facing_dir
				)
			)


	# --------------------------------------------------------
	# INITIAL VISUAL STATE
	# --------------------------------------------------------

	sprite.frame = get_anim_offset(
		facing_dir
	)


	update_interaction_ray()


	_position_history.clear()

	_position_history.push_front(
		global_position
	)


	sync_follower_sprite(
		0.0
	)


# ============================================================
# INPUT
# ============================================================

func _input(event: InputEvent) -> void:
	if not is_inside_tree():
		return


	if GameState.in_dialogue:
		return


	# --------------------------------------------------------
	# PAUSE
	# --------------------------------------------------------

	if event.is_action_pressed(
		"cancel"
	):

		toggle_pause()

		return


	# --------------------------------------------------------
	# PAUSE MENU
	# --------------------------------------------------------

	if is_paused:

		if save_menu_open:
			return


		if (
			event.is_action_pressed("right")
			or event.is_action_pressed("down")
		):

			rotate_icons(
				1
			)


		elif (
			event.is_action_pressed("left")
			or event.is_action_pressed("up")
		):

			rotate_icons(
				-1
			)


		elif (
			event.is_action_pressed("interact")
			or event.is_action_pressed("ui_accept")
		):

			activate_icon()


		return


	# --------------------------------------------------------
	# DIRECTION PRIORITY
	# --------------------------------------------------------

	if event.is_action_pressed(
		"right"
	):

		last_dir = Vector2.RIGHT


	elif event.is_action_pressed(
		"left"
	):

		last_dir = Vector2.LEFT


	elif event.is_action_pressed(
		"down"
	):

		last_dir = Vector2.DOWN


	elif event.is_action_pressed(
		"up"
	):

		last_dir = Vector2.UP


	# --------------------------------------------------------
	# INTERACT
	# --------------------------------------------------------

	if (
		event.is_action_pressed("interact")
		or event.is_action_pressed("ui_accept")
	):

		try_interact()


# ============================================================
# PHYSICS / MOVEMENT
# ============================================================

func _physics_process(
	delta: float
) -> void:

	# --------------------------------------------------------
	# FOLLOWER VISIBILITY
	# --------------------------------------------------------

	follower_sprite.visible = (
		GameState.has_vincent
	)


	# --------------------------------------------------------
	# PAUSED
	# --------------------------------------------------------

	if is_paused:

		save_icon.position = position

		load_icon.position = position

		options_icon.position = position

		items_icon.position = position


		sync_follower_sprite(
			delta
		)


		return


	# --------------------------------------------------------
	# DIALOGUE
	# --------------------------------------------------------

	if GameState.in_dialogue:

		velocity = Vector2.ZERO

		anim_timer = 0.0


		sprite.frame = get_anim_offset(
			facing_dir
		)


		sync_follower_sprite(
			delta
		)


		move_and_slide()


		return


	# --------------------------------------------------------
	# GET MOVEMENT DIRECTION
	# --------------------------------------------------------

	var direction: Vector2 = Vector2.ZERO


	if (
		last_dir == Vector2.RIGHT
		and Input.is_action_pressed("right")
	):

		direction = Vector2.RIGHT


	elif (
		last_dir == Vector2.LEFT
		and Input.is_action_pressed("left")
	):

		direction = Vector2.LEFT


	elif (
		last_dir == Vector2.DOWN
		and Input.is_action_pressed("down")
	):

		direction = Vector2.DOWN


	elif (
		last_dir == Vector2.UP
		and Input.is_action_pressed("up")
	):

		direction = Vector2.UP


	else:

		if Input.is_action_pressed(
			"right"
		):

			direction = Vector2.RIGHT


		elif Input.is_action_pressed(
			"left"
		):

			direction = Vector2.LEFT


		elif Input.is_action_pressed(
			"down"
		):

			direction = Vector2.DOWN


		elif Input.is_action_pressed(
			"up"
		):

			direction = Vector2.UP


	# --------------------------------------------------------
	# FACING
	# --------------------------------------------------------

	if direction != Vector2.ZERO:

		if direction != facing_dir:

			anim_timer = 0.0

			sprite.frame = get_anim_offset(
				direction
			)


		facing_dir = direction


		update_interaction_ray()


	# --------------------------------------------------------
	# WALK / RUN
	# --------------------------------------------------------

	# Walk by default.
	var current_speed: float = walk_speed


	# Hold Shift to RUN.
	if Input.is_key_pressed(
		KEY_SHIFT
	):

		current_speed = run_speed


	# --------------------------------------------------------
	# VELOCITY
	# --------------------------------------------------------

	if direction != Vector2.ZERO:

		velocity = velocity.move_toward(
			direction * current_speed,
			acceleration * delta
		)


	else:

		velocity = velocity.move_toward(
			Vector2.ZERO,
			friction * delta
		)


	if velocity.length() < 5.0:

		velocity = Vector2.ZERO


	# --------------------------------------------------------
	# ANIMATION
	# --------------------------------------------------------

	update_animation(
		delta,
		facing_dir,
		direction != Vector2.ZERO
	)


	# --------------------------------------------------------
	# FOLLOWER
	# --------------------------------------------------------

	sync_follower_sprite(
		delta
	)


	# --------------------------------------------------------
	# CORNER ASSIST
	# --------------------------------------------------------

	if direction != Vector2.ZERO:

		_apply_corner_assist(
			direction,
			delta
		)


	# --------------------------------------------------------
	# MOVE
	# --------------------------------------------------------

	move_and_slide()


# ============================================================
# CORNER ASSIST
# ============================================================

func _apply_corner_assist(
	direction: Vector2,
	delta: float
) -> void:

	if not corner_assist_enabled:
		return


	if direction == Vector2.ZERO:
		return


	if velocity == Vector2.ZERO:
		return


	if corner_assist_distance <= 0.0:
		return


	var intended_motion: Vector2 = (
		velocity * delta
	)


	if intended_motion.length() <= 0.001:
		return


	if not test_move(
		global_transform,
		intended_motion,
		null,
		CORNER_TEST_MARGIN
	):

		return


	var perpendicular: Vector2 = Vector2(
		-direction.y,
		direction.x
	)


	var max_check: int = int(
		ceil(
			corner_assist_distance
		)
	)


	var assist_signs: Array[float] = [
		-1.0,
		1.0
	]


	for distance: int in range(
		1,
		max_check + 1
	):

		for sign_value: float in assist_signs:

			var test_offset: Vector2 = (
				perpendicular
				* float(distance)
				* sign_value
			)


			if test_move(
				global_transform,
				test_offset,
				null,
				CORNER_TEST_MARGIN
			):

				continue


			var shifted_transform: Transform2D = (
				global_transform
			)


			shifted_transform.origin += (
				test_offset
			)


			var forward_is_blocked: bool = (
				test_move(
					shifted_transform,
					intended_motion,
					null,
					CORNER_TEST_MARGIN
				)
			)


			if forward_is_blocked:
				continue


			var nudge_amount: float = minf(
				corner_assist_nudge,
				float(distance)
			)


			var nudge: Vector2 = (
				perpendicular
				* nudge_amount
				* sign_value
			)


			var nudge_is_blocked: bool = (
				test_move(
					global_transform,
					nudge,
					null,
					CORNER_TEST_MARGIN
				)
			)


			if not nudge_is_blocked:

				global_position += nudge


			return


# ============================================================
# PLAYER ANIMATION
# ============================================================

func get_anim_offset(
	dir: Vector2
) -> int:

	if dir.y > 0:

		return 0


	elif dir.x > 0:

		return 4


	elif dir.x < 0:

		return 8


	else:

		return 12


func update_animation(
	delta: float,
	facing: Vector2,
	is_moving: bool
) -> void:

	var offset: int = get_anim_offset(
		facing
	)


	if is_moving:

		anim_timer += delta


		if anim_timer >= (
			1.0 / walk_fps
		):

			anim_timer = 0.0


			var local_frame: int = (
				sprite.frame - offset
			)


			sprite.frame = (
				offset
				+ (
					(local_frame + 1)
					% 4
				)
			)


	else:

		anim_timer = 0.0

		sprite.frame = offset


# ============================================================
# FOLLOWER
# ============================================================

func sync_follower_sprite(
	delta: float = 0.0
) -> void:

	if not follower_sprite:
		return


	if not GameState.has_vincent:

		follower_sprite.visible = false

		return


	follower_sprite.visible = true


	follower_sprite.frame = sprite.frame


	var should_record: bool = (
		is_player_moving()
		or _position_history.is_empty()
	)


	if should_record:

		if (
			_position_history.is_empty()
			or global_position.distance_to(
				_position_history[0]
			) > 0.5
		):

			_position_history.push_front(
				global_position
			)


	if _position_history.size() > MAX_HISTORY:

		_position_history.resize(
			MAX_HISTORY
		)


	var target_pos: Vector2 = (
		follower_sprite.global_position
	)


	var found: bool = false


	if (
		dad_follow_distance > 0.0
		and not _position_history.is_empty()
	):

		for i: int in range(
			_position_history.size()
		):

			var history_position: Vector2 = (
				_position_history[i]
			)


			if (
				global_position.distance_to(
					history_position
				)
				>= dad_follow_distance
			):

				target_pos = (
					history_position
				)

				found = true

				break


	if not found:

		if (
			dad_follow_delay > 0
			and _position_history.size()
			>= dad_follow_delay
		):

			target_pos = (
				_position_history[
					dad_follow_delay - 1
				]
			)


		elif not _position_history.is_empty():

			target_pos = (
				_position_history[
					_position_history.size() - 1
				]
			)


	if (
		delta > 0.0
		and dad_follow_smooth > 0.0
	):

		follower_sprite.global_position = (
			follower_sprite.global_position.move_toward(
				target_pos,
				dad_follow_smooth * delta
			)
		)


	else:

		follower_sprite.global_position = (
			target_pos
		)


# ============================================================
# INTERACTION
# ============================================================

func update_interaction_ray() -> void:

	interaction_ray.rotation = (
		facing_dir.angle()
		- PI / 2.0
	)


func try_interact() -> void:

	if not is_inside_tree():
		return


	if GameState.in_dialogue:
		return


	interaction_ray.force_shapecast_update()


	if not interaction_ray.is_colliding():
		return


	var target: Object = (
		interaction_ray.get_collider(
			0
		)
	)


	if (
		target
		and target.has_method(
			"interact"
		)
	):

		target.interact(
			self
		)


# ============================================================
# PAUSE
# ============================================================

func toggle_pause() -> void:

	if save_menu_open:
		return


	is_paused = not is_paused


	if is_paused:

		velocity = Vector2.ZERO

		anim_timer = 0.0


		sprite.frame = get_anim_offset(
			facing_dir
		)


		sync_follower_sprite(
			0.0
		)


		icon_index = 0


		update_icon_visibility()


		if pause_overlay:

			pause_overlay.visible = true


			if pause_overlay.material:

				pause_overlay.material.set_shader_parameter(
					"saturation",
					_original_saturation * 0.5
				)


		_set_tree_paused(
			true
		)


	else:

		_hide_all_icons()


		if pause_overlay:

			if pause_overlay.material:

				pause_overlay.material.set_shader_parameter(
					"saturation",
					_original_saturation
				)


			pause_overlay.visible = false


		_set_tree_paused(
			false
		)


func _set_tree_paused(
	value: bool
) -> void:

	if (
		is_inside_tree()
		and get_tree()
	):

		get_tree().paused = value


# ============================================================
# PAUSE ICONS
# ============================================================

func rotate_icons(
	direction: int
) -> void:

	icon_index = wrapi(
		icon_index + direction,
		0,
		4
	)


	update_icon_visibility()


func update_icon_visibility() -> void:

	save_icon.visible = (
		icon_index == 0
	)

	load_icon.visible = (
		icon_index == 1
	)

	options_icon.visible = (
		icon_index == 2
	)

	items_icon.visible = (
		icon_index == 3
	)


func _hide_all_icons() -> void:

	save_icon.visible = false

	load_icon.visible = false

	options_icon.visible = false

	items_icon.visible = false


func activate_icon() -> void:

	match icon_index:

		0:
			open_save_menu()


		1:
			open_save_menu()


		2:
			print(
				"Options selected"
			)


		3:
			print(
				"Items selected"
			)


# ============================================================
# SAVE MENU
# ============================================================

func open_save_menu() -> void:

	if save_menu_open:
		return


	save_menu_open = true

	is_paused = true


	_set_tree_paused(
		true
	)


	var menu_scene = preload(
		"res://Scenes/SaveMenu.tscn"
	).instantiate()


	add_child(
		menu_scene
	)


	if menu_scene.has_signal(
		"slot_selected"
	):

		menu_scene.slot_selected.connect(
			_on_save_slot_selected
		)


	menu_scene.tree_exited.connect(
		_on_save_menu_closed
	)


func _on_save_slot_selected(
	slot: int
) -> void:

	if not is_inside_tree():
		return


	var scene_path: String = ""


	if (
		get_tree()
		and get_tree().current_scene
	):

		scene_path = (
			get_tree().current_scene.scene_file_path
		)


	var save_data: Dictionary = {
		"save_version": 1,

		"scene_path": scene_path,

		"player_position":
			SaveManager.serialize_vector2(
				global_position
			),

		"player_facing":
			SaveManager.serialize_vector2(
				facing_dir
			),

		"playtime":
			GameState.total_playtime,

		"has_vincent":
			GameState.has_vincent
	}


	SaveManager.save_game(
		slot,
		save_data
	)


func _on_save_menu_closed() -> void:

	save_menu_open = false


	if not is_inside_tree():
		return


	if SaveManager.is_loading:
		return


	if is_paused:

		toggle_pause()


# ============================================================
# MOVEMENT HELPERS
# ============================================================

func is_player_moving() -> bool:

	return (
		velocity.length()
		> 1.0
	)
