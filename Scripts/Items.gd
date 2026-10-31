extends StaticBody2D


# ============================================================
# DIALOGUE
# ============================================================

@export var dialogue_resource: DialogueResource
@export var start_node: String = "start"


# ============================================================
# INTERACTION STATE
# ============================================================

var interaction_count: int = 0

var choice_counts: Dictionary = {}


# ============================================================
# INTERACT
# ============================================================

func interact(_player = null) -> void:
	if GameState.in_dialogue:
		return


	if dialogue_resource == null:
		push_warning(
			"Interactable has no DialogueResource assigned."
		)
		return


	interaction_count += 1


	var title: String = start_node.strip_edges()


	if title.is_empty():
		title = "start"


	DialogueManager.show_dialogue_balloon(
		dialogue_resource,
		title,
		[self]
	)


# ============================================================
# GENERAL INTERACTION COUNT
# ============================================================

func get_interaction_count() -> int:
	return interaction_count


func reset_interaction_count() -> void:
	interaction_count = 0


func set_interaction_count(value: int) -> void:
	interaction_count = maxi(
		value,
		0
	)


# ============================================================
# CHOICE COUNTERS
# ============================================================

func get_choice_count(
	choice_name: String
) -> int:

	return int(
		choice_counts.get(
			choice_name,
			0
		)
	)


func increment_choice(
	choice_name: String
) -> void:

	var current_count: int = get_choice_count(
		choice_name
	)


	choice_counts[
		choice_name
	] = current_count + 1


func set_choice_count(
	choice_name: String,
	value: int
) -> void:

	choice_counts[
		choice_name
	] = maxi(
		value,
		0
	)


func reset_choice(
	choice_name: String
) -> void:

	choice_counts.erase(
		choice_name
	)


func reset_all_choices() -> void:
	choice_counts.clear()


# ============================================================
# NODE VISIBILITY
# ============================================================

# Allows dialogue to show one of this object's child nodes.
#
# Example:
#
# $> show_node("Sprite2D2")
#
func show_node(
	node_path: String
) -> void:

	var target: Node = get_node_or_null(
		NodePath(node_path)
	)


	if target == null:

		push_warning(
			"Could not find node: " + node_path
		)

		return


	if target is CanvasItem:

		target.visible = true


# Allows dialogue to hide one of this object's child nodes.
#
# Example:
#
# $> hide_node("Sprite2D2")
#
func hide_node(
	node_path: String
) -> void:

	var target: Node = get_node_or_null(
		NodePath(node_path)
	)


	if target == null:

		push_warning(
			"Could not find node: " + node_path
		)

		return


	if target is CanvasItem:

		target.visible = false
