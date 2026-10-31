extends StaticBody2D


# ============================================================
# DIALOGUE
# ============================================================

@export var dialogue_resource: DialogueResource

@export var start_node: String = "start"


# ============================================================
# INTERACTION STATE
# ============================================================

# Counts how many times the object itself has been interacted
# with.
#
# Dialogue can read:
#
# interaction_count
#
var interaction_count: int = 0


# Stores counters for SPECIFIC choices/actions.
#
# Examples:
#
# "get_in"  -> 2
# "pray"    -> 5
# "flush"   -> 1
#
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


	# --------------------------------------------------------
	# COUNT GENERAL INTERACTION
	# --------------------------------------------------------

	interaction_count += 1


	# --------------------------------------------------------
	# START NODE
	# --------------------------------------------------------

	var title: String = start_node.strip_edges()


	if title.is_empty():

		title = "start"


	# --------------------------------------------------------
	# START DIALOGUE
	# --------------------------------------------------------

	# Passing [self] allows the dialogue file to use:
	#
	# interaction_count
	# get_choice_count(...)
	# increment_choice(...)
	# reset_choice(...)
	#
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


func set_interaction_count(
	value: int
) -> void:

	interaction_count = maxi(
		value,
		0
	)


# ============================================================
# SPECIFIC CHOICE COUNTERS
# ============================================================

# Get how many times a particular choice has happened.
#
# Example:
#
# get_choice_count("get_in")
#
func get_choice_count(
	choice_name: String
) -> int:

	return int(
		choice_counts.get(
			choice_name,
			0
		)
	)


# Increase a particular choice counter by 1.
#
# Example:
#
# increment_choice("get_in")
#
func increment_choice(
	choice_name: String
) -> void:

	var current_count: int = get_choice_count(
		choice_name
	)


	choice_counts[
		choice_name
	] = current_count + 1


# Set a counter manually.
#
# Example:
#
# set_choice_count("get_in", 5)
#
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


# Reset one particular counter.
#
# Example:
#
# reset_choice("get_in")
#
func reset_choice(
	choice_name: String
) -> void:

	choice_counts.erase(
		choice_name
	)


# Reset every specific-choice counter.
func reset_all_choices() -> void:

	choice_counts.clear()
