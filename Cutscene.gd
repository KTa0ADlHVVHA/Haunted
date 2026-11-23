extends Node


# ============================================================
# PLAYER
# ============================================================

@export var player: CharacterBody2D


# ============================================================
# WAYPOINTS
# ============================================================

@export var waypoints: Array[Marker2D] = []


# ============================================================
# SETTINGS
# ============================================================

@export var auto_start: bool = true

# Delay before the cutscene begins.
@export var start_delay: float = 0.5

# Movement speed during the cutscene.
@export var walk_speed: float = 90.0

# How close Plum needs to get to a waypoint.
@export var waypoint_distance: float = 2.0

# Optional pause at each waypoint.
@export var waypoint_pause: float = 0.0

# Direction Plum faces when the cutscene finishes.
@export var ending_direction: Vector2 = Vector2.UP


# ============================================================
# STARTING DIRECTION
# ============================================================

enum FacingDirection {
	DOWN,
	RIGHT,
	LEFT,
	UP
}


# Turn this on if you want Plum to face a specific
# direction at the start of this cutscene.
@export var force_starting_facing: bool = false


# Shows named options in the Inspector:
# Down / Right / Left / Up
@export var starting_facing: FacingDirection = FacingDirection.DOWN


# Optional pause after Plum turns but before she starts walking.
@export var starting_facing_pause: float = 0.0


# ============================================================
# PERSISTENCE
# ============================================================

# If enabled, this cutscene only plays once per playthrough.
@export var play_once: bool = true


# Remembers where Plum was standing in this room when leaving.
@export var remember_room_position: bool = true


# ============================================================
# STATE
# ============================================================

var cutscene_active: bool = false

var cutscene_finished: bool = false

var current_waypoint: int = 0

var waiting_at_waypoint: bool = false


var player_collisions: Array[CollisionShape2D] = []


var _room_path: String = ""


signal finished


# ============================================================
# READY
# ============================================================

func _ready() -> void:

	_room_path = GameState.get_room_path_for_node(
		self
	)


	# --------------------------------------------------------
	# RESTORE PREVIOUS POSITION
	# --------------------------------------------------------

	_restore_previous_room_position()


	# --------------------------------------------------------
	# CUTSCENE ALREADY PLAYED
	# --------------------------------------------------------

	if (
		play_once
		and GameState.was_event_seen(
			GameState.get_event_id(self)
		)
	):

		cutscene_finished = true

		return


	# --------------------------------------------------------
	# AUTO START
	# --------------------------------------------------------

	if not auto_start:
		return


	await get_tree().process_frame


	if not is_inside_tree():
		return


	_find_player_collisions()


	_start_after_delay()


# ============================================================
# EXIT TREE
# ============================================================

func _exit_tree() -> void:

	if not remember_room_position:
		return


	if GameState.loading_from_save:
		return


	if not is_instance_valid(
		player
	):
		return


	GameState.remember_room_position(
		_room_path,
		player.global_position,
		player.facing_dir
	)


# ============================================================
# ROOM POSITION MEMORY
# ============================================================

func _restore_previous_room_position() -> void:

	if not remember_room_position:
		return


	if player == null:
		return


	if _room_path.is_empty():
		return


	if (
		GameState.skip_room_restore_path
		== _room_path
	):

		return


	var saved: Dictionary = (
		GameState.get_remembered_room_position(
			_room_path
		)
	)


	if saved.is_empty():
		return


	player.global_position = Vector2(
		float(
			saved.get(
				"x",
				player.global_position.x
			)
		),
		float(
			saved.get(
				"y",
				player.global_position.y
			)
		)
	)


	player.facing_dir = Vector2(
		float(
			saved.get(
				"facing_x",
				player.facing_dir.x
			)
		),
		float(
			saved.get(
				"facing_y",
				player.facing_dir.y
			)
		)
	)


	player.velocity = Vector2.ZERO

	player.anim_timer = 0.0


	var player_sprite: Sprite2D = (
		player.get_node_or_null(
			"Sprite2D"
		) as Sprite2D
	)


	if player_sprite != null:

		player_sprite.frame = (
			player.get_anim_offset(
				player.facing_dir
			)
		)


	var previous_steps = (
		player.get(
			"_position_history"
		)
	)


	if previous_steps is Array:

		previous_steps.clear()

		previous_steps.push_front(
			player.global_position
		)


	player.update_interaction_ray()

	player.sync_follower_sprite(
		0.0
	)


# ============================================================
# FIND PLAYER COLLISIONS
# ============================================================

func _find_player_collisions() -> void:

	player_collisions.clear()


	if player == null:
		return


	var found_nodes: Array[Node] = (
		player.find_children(
			"*",
			"CollisionShape2D",
			true,
			false
		)
	)


	for node: Node in found_nodes:

		if node is CollisionShape2D:

			var collision: CollisionShape2D = (
				node as CollisionShape2D
			)


			player_collisions.append(
				collision
			)


	if player_collisions.is_empty():

		push_warning(
			"Cutscene couldn't find any CollisionShape2D inside Plum."
		)


# ============================================================
# COLLISION CONTROL
# ============================================================

func _disable_player_collisions() -> void:

	if player_collisions.is_empty():

		_find_player_collisions()


	for collision: CollisionShape2D in player_collisions:

		if is_instance_valid(
			collision
		):

			collision.set_deferred(
				"disabled",
				true
			)


func _enable_player_collisions() -> void:

	for collision: CollisionShape2D in player_collisions:

		if is_instance_valid(
			collision
		):

			collision.set_deferred(
				"disabled",
				false
			)


# ============================================================
# START DELAY
# ============================================================

# ============================================================
# START DELAY
# ============================================================

func _start_after_delay() -> void:

	if start_delay > 0.0:

		# IMPORTANT:
		# process_always = false
		#
		# This means the timer PAUSES when the game is paused.
		# So pressing X before a cutscene can no longer cause
		# the cutscene to start while the pause menu is open.
		await get_tree().create_timer(
			start_delay,
			false
		).timeout


	if not is_inside_tree():
		return


	# Extra safety:
	# Never begin a cutscene while the scene tree is paused.
	while get_tree().paused:

		await get_tree().process_frame


		if not is_inside_tree():
			return


	start_cutscene()


# ============================================================
# START CUTSCENE
# ============================================================

func start_cutscene() -> void:

	if cutscene_active:
		return


	if cutscene_finished:
		return


	if (
		play_once
		and GameState.was_event_seen(
			GameState.get_event_id(self)
		)
	):

		cutscene_finished = true

		return


	if player == null:

		push_warning(
			"Cutscene has no player assigned."
		)

		return


	if waypoints.is_empty():

		push_warning(
			"Cutscene has no waypoints assigned."
		)

		return


	current_waypoint = 0

	cutscene_active = true

	waiting_at_waypoint = false


	if play_once:

		GameState.mark_event_seen(
			GameState.get_event_id(self)
		)


	# ========================================================
	# DISABLE PLAYER CONTROL
	# ========================================================

	player.set_process_input(
		false
	)


	player.set_physics_process(
		false
	)


	player.velocity = Vector2.ZERO


	# ========================================================
	# FORCE STARTING DIRECTION
	# ========================================================

	if force_starting_facing:

		var start_direction: Vector2 = (
			_get_starting_direction()
		)


		player.facing_dir = (
			start_direction
		)


		player.anim_timer = 0.0


		var player_sprite: Sprite2D = (
			player.get_node_or_null(
				"Sprite2D"
			) as Sprite2D
		)


		if player_sprite != null:

			player_sprite.frame = (
				player.get_anim_offset(
					start_direction
				)
			)


		player.update_interaction_ray()


		player.sync_follower_sprite(
			0.0
		)


	# ========================================================
	# DISABLE COLLISIONS
	# ========================================================

	_disable_player_collisions()


	# ========================================================
	# OPTIONAL TURN PAUSE
	# ========================================================

	if (
		force_starting_facing
		and starting_facing_pause > 0.0
	):

		waiting_at_waypoint = true


		await get_tree().create_timer(
			starting_facing_pause
		).timeout


		if not is_inside_tree():
			return


		waiting_at_waypoint = false


# ============================================================
# STARTING DIRECTION
# ============================================================

func _get_starting_direction() -> Vector2:

	match starting_facing:

		FacingDirection.DOWN:
			return Vector2.DOWN


		FacingDirection.RIGHT:
			return Vector2.RIGHT


		FacingDirection.LEFT:
			return Vector2.LEFT


		FacingDirection.UP:
			return Vector2.UP


	return Vector2.DOWN


# ============================================================
# CUTSCENE MOVEMENT
# ============================================================

func _physics_process(
	delta: float
) -> void:

	if not cutscene_active:
		return


	if waiting_at_waypoint:
		return


	if player == null:
		return


	if current_waypoint >= waypoints.size():

		_finish_cutscene()

		return


	var target: Marker2D = (
		waypoints[
			current_waypoint
		]
	)


	if target == null:

		current_waypoint += 1

		return


	var to_target: Vector2 = (
		target.global_position
		- player.global_position
	)


	var distance: float = (
		to_target.length()
	)


	if distance <= waypoint_distance:

		_reach_waypoint(
			target
		)

		return


	var movement_direction: Vector2 = (
		to_target.normalized()
	)


	var animation_direction: Vector2 = (
		_get_cardinal_direction(
			movement_direction
		)
	)


	player.global_position = (
		player.global_position.move_toward(
			target.global_position,
			walk_speed * delta
		)
	)


	player.velocity = (
		movement_direction
		* walk_speed
	)


	player.facing_dir = (
		animation_direction
	)


	player.update_interaction_ray()


	player.update_animation(
		delta,
		animation_direction,
		true
	)


	player.sync_follower_sprite(
		delta
	)


# ============================================================
# REACHED WAYPOINT
# ============================================================

func _reach_waypoint(
	target: Marker2D
) -> void:

	player.global_position = (
		target.global_position
	)


	current_waypoint += 1


	if current_waypoint >= waypoints.size():

		_finish_cutscene()

		return


	if waypoint_pause > 0.0:

		waiting_at_waypoint = true


		player.velocity = Vector2.ZERO


		await get_tree().create_timer(
			waypoint_pause
		).timeout


		if not is_inside_tree():
			return


		waiting_at_waypoint = false


# ============================================================
# CARDINAL DIRECTION
# ============================================================

func _get_cardinal_direction(
	direction: Vector2
) -> Vector2:

	if absf(
		direction.x
	) > absf(
		direction.y
	):

		if direction.x > 0.0:

			return Vector2.RIGHT


		else:

			return Vector2.LEFT


	else:

		if direction.y > 0.0:

			return Vector2.DOWN


		else:

			return Vector2.UP


# ============================================================
# FINISH CUTSCENE
# ============================================================

func _finish_cutscene() -> void:

	if not cutscene_active:
		return


	cutscene_active = false

	cutscene_finished = true

	waiting_at_waypoint = false


	player.velocity = Vector2.ZERO

	player.anim_timer = 0.0


	player.facing_dir = (
		ending_direction
	)


	var player_sprite: Sprite2D = (
		player.get_node_or_null(
			"Sprite2D"
		) as Sprite2D
	)


	if player_sprite != null:

		player_sprite.frame = (
			player.get_anim_offset(
				ending_direction
			)
		)


	player.update_interaction_ray()


	player.sync_follower_sprite(
		0.0
	)


	_enable_player_collisions()


	player.set_physics_process(
		true
	)


	player.set_process_input(
		true
	)


	finished.emit()
