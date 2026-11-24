extends Area2D

## Starts dialogue when Plum walks into this area.
## One-time triggers can remain completed between room visits.


# ============================================================
# DIALOGUE
# ============================================================

@export var dialogue_resource: DialogueResource
@export var start_node: String = ""


# ============================================================
# CONDITION
# ============================================================

## Example: met_rosie
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

@export var force_starting_facing: bool = false

@export var starting_facing: FacingDirection = FacingDirection.DOWN

@export var starting_facing_pause: float = 0.0


# ============================================================
# SETTINGS
# ============================================================

@export var trigger_once: bool = true

@export var start_delay: float = 0.0

## Remember completed triggers between room visits.
@export var remember_between_visits: bool = true

## Plum must leave and re-enter the area before it activates.
@export var require_exit_before_trigger: bool = false


# ============================================================
# STATE
# ============================================================

var has_triggered: bool = false

var starting_dialogue: bool = false

var trigger_armed: bool = true

var _locked_body: Node2D = null
var _restore_input: bool = false
var _restore_physics: bool = false


# ============================================================
# READY
# ============================================================

func _ready() -> void:

	if trigger_once and remember_between_visits:

		has_triggered = GameState.was_event_seen(
			GameState.get_event_id(self)
		)

	trigger_armed = not require_exit_before_trigger

	body_entered.connect(_on_body_entered)

	body_exited.connect(_on_body_exited)


# ============================================================
# CLEANUP
# ============================================================

func _exit_tree() -> void:

	# Never leave Plum locked if this trigger is removed.
	_unlock_player(_locked_body)


# ============================================================
# CHECK CONDITION
# ============================================================

func _condition_is_met() -> bool:

	var event_name: String = required_event.strip_edges()

	if event_name.is_empty():
		return true

	return GameState.was_event_seen(event_name)


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

func _lock_player(body: Node2D) -> void:

	if not is_instance_valid(body):
		return

	_locked_body = body

	# Remember which controls were already enabled.
	# This avoids unlocking controls owned by another cutscene.
	_restore_input = body.is_processing_input()
	_restore_physics = body.is_physics_processing()

	if body is CharacterBody2D:

		var character := body as CharacterBody2D

		character.velocity = Vector2.ZERO

	body.set_physics_process(false)

	body.set_process_input(false)


# ============================================================
# UNLOCK PLAYER
# ============================================================

func _unlock_player(body: Node2D) -> void:

	if is_instance_valid(body) and body == _locked_body:

		if _restore_physics:
			body.set_physics_process(true)

		if _restore_input:
			body.set_process_input(true)

	_locked_body = null

	_restore_input = false

	_restore_physics = false


# ============================================================
# FORCE PLAYER FACING
# ============================================================

func _force_player_facing(body: Node2D) -> void:

	var direction: Vector2 = _get_starting_direction()

	if body is CharacterBody2D:

		var character := body as CharacterBody2D

		character.velocity = Vector2.ZERO

	body.set("facing_dir", direction)

	body.set("last_dir", Vector2.ZERO)

	body.set("anim_timer", 0.0)

	var sprite: Sprite2D = (
		body.get_node_or_null("Sprite2D") as Sprite2D
	)

	if sprite != null and body.has_method("get_anim_offset"):

		sprite.frame = body.call(
			"get_anim_offset",
			direction
		)

	if body.has_method("update_interaction_ray"):

		body.call("update_interaction_ray")

	if body.has_method("sync_follower_sprite"):

		body.call("sync_follower_sprite", 0.0)


# ============================================================
# BODY EXITED
# ============================================================

func _on_body_exited(body: Node2D) -> void:

	if not body.has_method("try_interact"):
		return

	trigger_armed = true


# ============================================================
# BODY ENTERED
# ============================================================

func _on_body_entered(body: Node2D) -> void:

	# Make sure this is Plum.
	if not body.has_method("try_interact"):
		return

	# Check required event.
	if not _condition_is_met():
		return

	# Require Plum to leave first, if enabled.
	if require_exit_before_trigger and not trigger_armed:
		return

	# Prevent duplicate triggers.
	if starting_dialogue:
		return

	if trigger_once and has_triggered:
		return

	if GameState.in_dialogue:
		return

	# Validate dialogue resource.
	if dialogue_resource == null:

		push_warning(
			"AutoDialogueTrigger has no DialogueResource assigned."
		)

		return

	if require_exit_before_trigger:

		trigger_armed = false

	starting_dialogue = true


	# ========================================================
	# START DELAY
	# ========================================================

	# The timer now stops while the game is paused.
	if start_delay > 0.0:

		await get_tree().create_timer(
			start_delay,
			false
		).timeout

	if not is_inside_tree():
		return


	# ========================================================
	# WAIT FOR PAUSE / ROOM TRANSITION
	# ========================================================

	# Never start a dialogue while the pause menu is open
	# or while another room is loading.

	while get_tree().paused or GameState.room_transition_active:

		await get_tree().process_frame

		if not is_inside_tree():
			return

		if not is_instance_valid(body):

			starting_dialogue = false

			return


	# ========================================================
	# CHECK PLAYER IS STILL INSIDE
	# ========================================================

	if not is_instance_valid(body) or not overlaps_body(body):

		starting_dialogue = false

		return

	if not _condition_is_met() or GameState.in_dialogue:

		starting_dialogue = false

		return


	# ========================================================
	# FORCE STARTING DIRECTION
	# ========================================================

	if force_starting_facing:

		_lock_player(body)

		_force_player_facing(body)


	# ========================================================
	# OPTIONAL FACING PAUSE
	# ========================================================

	if force_starting_facing and starting_facing_pause > 0.0:

		await get_tree().create_timer(
			starting_facing_pause,
			false
		).timeout

		if not is_inside_tree():

			_unlock_player(body)

			return

		if not is_instance_valid(body):

			starting_dialogue = false

			_unlock_player(body)

			return


	# ========================================================
	# FINAL SAFETY CHECKS
	# ========================================================

	if (
		not _condition_is_met()
		or GameState.in_dialogue
		or GameState.room_transition_active
		or get_tree().paused
	):

		starting_dialogue = false

		if force_starting_facing:

			_unlock_player(body)

		return


	# ========================================================
	# REMEMBER TRIGGER
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

	# Lock normal player input BEFORE Dialogue Manager
	# creates the dialogue balloon.
	# This prevents X from opening the pause menu
	# during the short gap before dialogue appears.

	GameState.in_dialogue = true

	DialogueManager.show_dialogue_balloon(
		dialogue_resource,
		start_node
	)


	# ========================================================
	# RETURN PLAYER CONTROL
	# ========================================================

	# GameState.in_dialogue now prevents normal movement,
	# so we no longer need to wait several frames.

	if force_starting_facing:

		_unlock_player(body)
