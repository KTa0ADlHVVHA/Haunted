extends Area2D

## Automatically starts Dialogue Manager dialogue when
## the player walks into this Area2D.


# ============================================================
# DIALOGUE
# ============================================================

@export var dialogue_resource: DialogueResource

# The title / starting point inside the dialogue file.
@export var start_node: String = ""


# ============================================================
# SETTINGS
# ============================================================

# If true, this trigger only activates once while this
# scene instance exists.
@export var trigger_once: bool = true

# Small delay before the dialogue starts.
# 0.0 = immediately.
@export var start_delay: float = 0.0


# ============================================================
# STATE
# ============================================================

var has_triggered: bool = false
var starting_dialogue: bool = false


# ============================================================
# READY
# ============================================================

func _ready() -> void:
	body_entered.connect(
		_on_body_entered
	)


# ============================================================
# BODY ENTERED
# ============================================================

func _on_body_entered(body: Node2D) -> void:
	# --------------------------------------------------------
	# MAKE SURE THIS IS THE PLAYER
	# --------------------------------------------------------

	# Your player Character has this method.
	# This keeps random physics bodies from activating
	# the dialogue trigger.
	if not body.has_method("try_interact"):
		return


	# --------------------------------------------------------
	# DON'T TRIGGER TWICE
	# --------------------------------------------------------

	if starting_dialogue:
		return


	if trigger_once and has_triggered:
		return


	# Don't try to start another conversation on top
	# of an existing one.
	if GameState.in_dialogue:
		return


	# --------------------------------------------------------
	# VALIDATE DIALOGUE
	# --------------------------------------------------------

	if dialogue_resource == null:
		push_warning(
			"AutoDialogueTrigger has no DialogueResource!"
		)
		return


	starting_dialogue = true


	# --------------------------------------------------------
	# OPTIONAL DELAY
	# --------------------------------------------------------

	if start_delay > 0.0:
		await get_tree().create_timer(
			start_delay
		).timeout


	# Make sure the trigger still exists after the delay.
	if not is_inside_tree():
		return


	# Someone else may have started dialogue during
	# the delay.
	if GameState.in_dialogue:
		starting_dialogue = false
		return


	# --------------------------------------------------------
	# START DIALOGUE
	# --------------------------------------------------------

	has_triggered = true
	starting_dialogue = false


	DialogueManager.show_dialogue_balloon(
		dialogue_resource,
		start_node
	)
