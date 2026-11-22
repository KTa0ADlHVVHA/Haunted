extends Area2D

## Starts dialogue when Plum walks into this area.
## A one-time trigger can stay completed even when the room reloads.


# ============================================================
# DIALOGUE
# ============================================================

@export var dialogue_resource: DialogueResource
@export var start_node: String = ""


# ============================================================
# CONDITION
# ============================================================

## Optional event that must have happened before this trigger works.
##
## Example:
## met_rosie
##
## Leave empty if there is no condition.
@export var required_event: String = ""


# ============================================================
# DIRECTION
# ============================================================

enum FacingDirection {
	DOWN,
	RIGHT,
	LEFT,
	UP
}


## Turn this on if Plum should face a specific direction
## before the dialogue begins.
@export var force_starting_facing: bool = false


## Direction Plum faces when the trigger activates.
@export var starting_facing: FacingDirection = FacingDirection.DOWN


## Optional pause after Plum turns before dialogue starts.
@export var starting_facing_pause: float = 0.0


# ============================================================
# SETTINGS
# ============================================================

@export var trigger_once: bool = true

@export var start_delay: float = 0.0


## Turn this off for a one-time trigger that SHOULD reset
## when the room is re-entered.
@export var remember_between_visits: bool = true


## If enabled, Plum must leave this Area2D and then
## enter it again before it can activate.
@export var require_exit_before_trigger: bool = false


# ============================================================
# STATE
# ============================================================

var has_triggered: bool = false

var starting_dialogue: bool = false

var trigger_armed: bool = true


# ============================================================
# READY
# ============================================================

func _ready() -> void:

	# --------------------------------------------------------
	# RESTORE ONE-TIME EVENT STATE
	# --------------------------------------------------------

	if trigger_once and remember_between_visits:

		has_triggered = GameState.was_event_seen(
			GameState.get_event_id(self)
		)


	# --------------------------------------------------------
	# REQUIRE PLAYER TO LEAVE FIRST
	# --------------------------------------------------------

	if require_exit_before_trigger:

		trigger_armed = false

	else:

		trigger_armed = true


	# --------------------------------------------------------
	# SIGNALS
	# --------------------------------------------------------

	body_entered.connect(
		_on_body_entered
	)


	body_exited.connect(
		_on_body_exited
	)


# ============================================================
# CHECK CONDITION
# ============================================================

func _condition_is_met() -> bool:

	var event_name: String = (
		required_event.strip_edges()
	)


	# Empty = no condition.
	if event_name.is_empty():
		return true


	return GameState.was_event_seen(
		event_name
	)


# ============================================================
# GET STARTING DIRECTION
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
# LOCK PLAYER
# ============================================================

func _lock_player(
	body: Node2D
) -> void:

	if body is CharacterBody2D:

		var character: CharacterBody2D = (
			body as CharacterBody2D
		)

		character.velocity = Vector2.ZERO


	# Stop Character.gd from immediately changing
	# the direction again.
	body.set_physics_process(
		false
	)


	body.set_process_input(
		false
	)


# ============================================================
# UNLOCK PLAYER
# ============================================================

func _unlock_player(
	body: Node2D
) -> void:

	if not is_instance_valid(body):
		return


	body.set_physics_process(
		true
	)


	body.set_process_input(
		true
	)


# ============================================================
# FORCE PLAYER FACING
# ============================================================

func _force_player_facing(
	body: Node2D
) -> void:

	var direction: Vector2 = (
		_get_starting_direction()
	)


	# --------------------------------------------------------
	# STOP MOVEMENT
	# --------------------------------------------------------

	if body is CharacterBody2D:

		var character: CharacterBody2D = (
			body as CharacterBody2D
		)

		character.velocity = Vector2.ZERO


	# --------------------------------------------------------
	# CHANGE FACING
	# --------------------------------------------------------

	body.set(
		"facing_dir",
		direction
	)


	body.set(
		"last_dir",
		Vector2.ZERO
	)


	body.set(
		"anim_timer",
		0.0
	)


	# --------------------------------------------------------
	# CHANGE SPRITE
	# --------------------------------------------------------

	var sprite: Sprite2D = (
		body.get_node_or_null(
			"Sprite2D"
		) as Sprite2D
	)


	if (
		sprite != null
		and body.has_method(
			"get_anim_offset"
		)
	):

		sprite.frame = body.call(
			"get_anim_offset",
			direction
		)


	# --------------------------------------------------------
	# UPDATE INTERACTION RAY
	# --------------------------------------------------------

	if body.has_method(
		"update_interaction_ray"
	):

		body.call(
			"update_interaction_ray"
		)


	# --------------------------------------------------------
	# UPDATE VINCENT
	# --------------------------------------------------------

	if body.has_method(
		"sync_follower_sprite"
	):

		body.call(
			"sync_follower_sprite",
			0.0
		)


# ============================================================
# BODY EXITED
# ============================================================

func _on_body_exited(
	body: Node2D
) -> void:

	# Make sure this is Plum.
	if not body.has_method(
		"try_interact"
	):
		return


	# Plum has now left the Area2D.
	trigger_armed = true


# ============================================================
# BODY ENTERED
# ============================================================

func _on_body_entered(
	body: Node2D
) -> void:

	# --------------------------------------------------------
	# MAKE SURE THIS IS PLUM
	# --------------------------------------------------------

	if not body.has_method(
		"try_interact"
	):
		return


	# --------------------------------------------------------
	# CHECK CONDITION
	# --------------------------------------------------------

	if not _condition_is_met():
		return


	# --------------------------------------------------------
	# REQUIRE EXIT FIRST
	# --------------------------------------------------------

	if (
		require_exit_before_trigger
		and not trigger_armed
	):
		return


	# --------------------------------------------------------
	# DON'T TRIGGER TWICE
	# --------------------------------------------------------

	if starting_dialogue:
		return


	if trigger_once and has_triggered:
		return


	if GameState.in_dialogue:
		return


	# --------------------------------------------------------
	# VALIDATE DIALOGUE
	# --------------------------------------------------------

	if dialogue_resource == null:

		push_warning(
			"AutoDialogueTrigger has no DialogueResource assigned."
		)

		return


	# --------------------------------------------------------
	# DISARM
	# --------------------------------------------------------

	if require_exit_before_trigger:

		trigger_armed = false


	starting_dialogue = true


	# ========================================================
	# START DELAY
	# ========================================================

	if start_delay > 0.0:

		await get_tree().create_timer(
			start_delay
		).timeout


		if not is_inside_tree():

			starting_dialogue = false

			return


		# Plum walked away during the delay.
		if (
			not is_instance_valid(body)
			or not overlaps_body(body)
		):

			starting_dialogue = false

			return


	# --------------------------------------------------------
	# CHECK CONDITION AGAIN
	# --------------------------------------------------------

	if not _condition_is_met():

		starting_dialogue = false

		return


	# ========================================================
	# FORCE DIRECTION
	# ========================================================

	if force_starting_facing:

		# Freeze Plum first so Character.gd can't
		# immediately turn her back.
		_lock_player(
			body
		)


		_force_player_facing(
			body
		)


	# ========================================================
	# OPTIONAL PAUSE AFTER TURNING
	# ========================================================

	if (
		force_starting_facing
		and starting_facing_pause > 0.0
	):

		await get_tree().create_timer(
			starting_facing_pause
		).timeout


		if not is_inside_tree():

			_unlock_player(
				body
			)

			return


		if not is_instance_valid(body):

			return


	# --------------------------------------------------------
	# CHECK CONDITION AGAIN
	# --------------------------------------------------------

	if not _condition_is_met():

		starting_dialogue = false


		if force_starting_facing:

			_unlock_player(
				body
			)


		return


	# --------------------------------------------------------
	# ANOTHER DIALOGUE STARTED
	# --------------------------------------------------------

	if GameState.in_dialogue:

		starting_dialogue = false


		if force_starting_facing:

			_unlock_player(
				body
			)


		return


	# ========================================================
	# MARK AS TRIGGERED
	# ========================================================

	has_triggered = true

	starting_dialogue = false


	if trigger_once and remember_between_visits:

		GameState.mark_event_seen(
			GameState.get_event_id(self)
		)


	# ========================================================
	# START DIALOGUE
	# ========================================================

	DialogueManager.show_dialogue_balloon(
		dialogue_resource,
		start_node
	)


	# ========================================================
	# WAIT FOR DIALOGUE MODE TO TAKE OVER
	# ========================================================

	if force_starting_facing:

		# Give DialogueManager a few frames to set
		# GameState.in_dialogue before Character.gd resumes.
		for i: int in range(5):

			await get_tree().process_frame


			if GameState.in_dialogue:
				break


		_unlock_player(
			body
		)
