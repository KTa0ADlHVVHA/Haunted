extends Area2D

## Starts dialogue when Plum walks into this area.
## A one-time trigger can stay completed even when the room reloads.

# ============================================================
# DIALOGUE
# ============================================================

@export var dialogue_resource: DialogueResource
@export var start_node: String = ""


# ============================================================
# SETTINGS
# ============================================================

@export var trigger_once: bool = true

@export var start_delay: float = 0.0


# Turn this off for a one-time trigger that SHOULD reset
# when the room is re-entered.
@export var remember_between_visits: bool = true


# If enabled:
#
# Plum starting INSIDE this Area2D will NOT trigger it.
#
# She must first:
# 1. Leave the Area2D
# 2. Re-enter the Area2D
#
# Then the dialogue will begin.
@export var require_exit_before_trigger: bool = false


# ============================================================
# STATE
# ============================================================

var has_triggered: bool = false

var starting_dialogue: bool = false


# Normally the trigger is armed immediately.
#
# If require_exit_before_trigger is enabled,
# this starts false and becomes true after Plum leaves.
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
# BODY EXITED
# ============================================================

func _on_body_exited(
	body: Node2D
) -> void:

	# Make sure this is Plum / the player.
	if not body.has_method(
		"try_interact"
	):
		return


	# Once Plum has left the area,
	# she is now allowed to trigger it by re-entering.
	trigger_armed = true


# ============================================================
# BODY ENTERED
# ============================================================

func _on_body_entered(
	body: Node2D
) -> void:

	# --------------------------------------------------------
	# MAKE SURE THIS IS THE PLAYER
	# --------------------------------------------------------

	if not body.has_method(
		"try_interact"
	):
		return


	# --------------------------------------------------------
	# WAIT UNTIL PLAYER HAS LEFT FIRST
	# --------------------------------------------------------

	if require_exit_before_trigger and not trigger_armed:
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


	# Player has entered.
	#
	# If this is a repeatable trigger, they must leave
	# before another entry can trigger it again.
	if require_exit_before_trigger:

		trigger_armed = false


	starting_dialogue = true


	# --------------------------------------------------------
	# OPTIONAL DELAY
	# --------------------------------------------------------

	if start_delay > 0.0:

		await get_tree().create_timer(
			start_delay
		).timeout


		if not is_inside_tree():
			return


		# Don't play the dialogue if Plum walked back out
		# during the delay.
		if (
			not is_instance_valid(body)
			or not overlaps_body(body)
		):

			starting_dialogue = false

			return


	# --------------------------------------------------------
	# ANOTHER DIALOGUE STARTED
	# --------------------------------------------------------

	if GameState.in_dialogue:

		starting_dialogue = false

		return


	# --------------------------------------------------------
	# TRIGGER
	# --------------------------------------------------------

	has_triggered = true

	starting_dialogue = false


	if trigger_once and remember_between_visits:

		GameState.mark_event_seen(
			GameState.get_event_id(self)
		)


	DialogueManager.show_dialogue_balloon(
		dialogue_resource,
		start_node
	)
