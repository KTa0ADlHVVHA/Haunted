extends Node


# ============================================================
# OPENING CUTSCENE
# ============================================================
#
# Plum walks through a list of Marker2D waypoints.
#
# During the cutscene:
# - Player controls are disabled
# - Plum's CollisionShape2D nodes are found automatically
# - Plum's collisions are temporarily disabled
# - Existing walk animation is reused
# - Vincent follows using the existing follower system
#
# After the final waypoint:
# - Plum stops
# - Collision comes back
# - Player control comes back
# ============================================================


# ============================================================
# PLAYER
# ============================================================

@export var player: CharacterBody2D


# ============================================================
# WAYPOINTS
# ============================================================

# Add Marker2Ds in the order Plum should visit them.
#
# Example:
#
# 0 -> Point1
# 1 -> Point2
# 2 -> Point3
# 3 -> HouseEntrance
#
@export var waypoints: Array[Marker2D] = []


# ============================================================
# SETTINGS
# ============================================================

@export var auto_start: bool = true


# Delay before the opening walk starts.
@export var start_delay: float = 0.5


# Movement speed during the cutscene.
@export var walk_speed: float = 90.0


# How close Plum needs to get to a waypoint.
@export var waypoint_distance: float = 2.0


# Optional pause at each waypoint.
#
# 0.0 = immediately continue walking.
@export var waypoint_pause: float = 0.0


# Direction Plum faces when the whole cutscene finishes.
@export var ending_direction: Vector2 = Vector2.UP


# ============================================================
# STATE
# ============================================================

var cutscene_active: bool = false

var cutscene_finished: bool = false

var current_waypoint: int = 0

var waiting_at_waypoint: bool = false


# Every CollisionShape2D found inside Plum's scene.
var player_collisions: Array[CollisionShape2D] = []


signal finished


# ============================================================
# READY
# ============================================================

func _ready() -> void:
	if not auto_start:
		return


	# Give Plum's instanced scene time to fully enter the tree.
	await get_tree().process_frame


	# Automatically find collision shapes inside Plum.
	_find_player_collisions()


	_start_after_delay()


# ============================================================
# FIND PLAYER COLLISIONS
# ============================================================

func _find_player_collisions() -> void:
	player_collisions.clear()


	if player == null:
		return


	# Searches recursively through Plum's entire instanced scene.
	#
	# owned = false is important because some nodes may belong
	# to the original instanced Character scene rather than the
	# current Outside scene.
	var found_nodes: Array[Node] = player.find_children(
		"*",
		"CollisionShape2D",
		true,
		false
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
			"OpeningCutscene couldn't find any CollisionShape2D inside Plum."
		)


# ============================================================
# COLLISION CONTROL
# ============================================================

func _disable_player_collisions() -> void:
	# Search again in case something was added after _ready().
	if player_collisions.is_empty():
		_find_player_collisions()


	for collision: CollisionShape2D in player_collisions:
		if is_instance_valid(collision):

			collision.set_deferred(
				"disabled",
				true
			)


func _enable_player_collisions() -> void:
	for collision: CollisionShape2D in player_collisions:
		if is_instance_valid(collision):

			collision.set_deferred(
				"disabled",
				false
			)


# ============================================================
# START DELAY
# ============================================================

func _start_after_delay() -> void:
	if start_delay > 0.0:

		await get_tree().create_timer(
			start_delay
		).timeout


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


	if player == null:
		push_warning(
			"OpeningCutscene has no player assigned."
		)
		return


	if waypoints.is_empty():
		push_warning(
			"OpeningCutscene has no waypoints assigned."
		)
		return


	current_waypoint = 0

	cutscene_active = true

	waiting_at_waypoint = false


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
	# DISABLE PLUM'S COLLISION
	# ========================================================

	_disable_player_collisions()


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


	# --------------------------------------------------------
	# FINISHED ALL WAYPOINTS
	# --------------------------------------------------------

	if current_waypoint >= waypoints.size():

		_finish_cutscene()

		return


	# --------------------------------------------------------
	# CURRENT WAYPOINT
	# --------------------------------------------------------

	var target: Marker2D = (
		waypoints[
			current_waypoint
		]
	)


	if target == null:

		current_waypoint += 1

		return


	# --------------------------------------------------------
	# TARGET INFORMATION
	# --------------------------------------------------------

	var to_target: Vector2 = (
		target.global_position
		- player.global_position
	)


	var distance: float = (
		to_target.length()
	)


	# --------------------------------------------------------
	# REACHED WAYPOINT
	# --------------------------------------------------------

	if distance <= waypoint_distance:

		_reach_waypoint(
			target
		)

		return


	# --------------------------------------------------------
	# MOVEMENT DIRECTION
	# --------------------------------------------------------

	var movement_direction: Vector2 = (
		to_target.normalized()
	)


	var animation_direction: Vector2 = (
		_get_cardinal_direction(
			movement_direction
		)
	)


	# --------------------------------------------------------
	# MOVE PLUM
	# --------------------------------------------------------

	# Direct movement is intentional here.
	#
	# Her normal collisions are disabled during this sequence,
	# so she can pass through scenery that would usually block
	# her.
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


	# --------------------------------------------------------
	# FACING
	# --------------------------------------------------------

	player.facing_dir = (
		animation_direction
	)


	player.update_interaction_ray()


	# --------------------------------------------------------
	# WALK ANIMATION
	# --------------------------------------------------------

	player.update_animation(
		delta,
		animation_direction,
		true
	)


	# --------------------------------------------------------
	# VINCENT
	# --------------------------------------------------------

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


	# --------------------------------------------------------
	# FINAL WAYPOINT
	# --------------------------------------------------------

	if current_waypoint >= waypoints.size():

		_finish_cutscene()

		return


	# --------------------------------------------------------
	# OPTIONAL PAUSE
	# --------------------------------------------------------

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

	if absf(direction.x) > absf(direction.y):

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


	# ========================================================
	# STOP PLUM
	# ========================================================

	player.velocity = Vector2.ZERO

	player.anim_timer = 0.0


	player.facing_dir = (
		ending_direction
	)


	var player_sprite: Sprite2D = (
		player.get_node(
			"Sprite2D"
		)
	)


	player_sprite.frame = (
		player.get_anim_offset(
			ending_direction
		)
	)


	player.update_interaction_ray()


	player.sync_follower_sprite(
		0.0
	)


	# ========================================================
	# RESTORE COLLISION
	# ========================================================

	_enable_player_collisions()


	# ========================================================
	# RETURN CONTROL
	# ========================================================

	player.set_physics_process(
		true
	)


	player.set_process_input(
		true
	)


	finished.emit()
