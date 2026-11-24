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
var node_visibility: Dictionary = {}

var _state_id: String = ""

var interacting_player: CharacterBody2D = null


# ============================================================
# READY
# ============================================================

func _ready() -> void:

	_state_id = GameState.get_event_id(self)

	_restore_interaction_state()


# ============================================================
# RESTORE STATE
# ============================================================

func _restore_interaction_state() -> void:

	if _state_id.is_empty():
		return

	var saved: Dictionary = GameState.get_interaction_state(
		_state_id
	)

	if saved.is_empty():
		return

	# Restore interaction count.
	interaction_count = int(
		saved.get("interaction_count", 0)
	)

	# Restore choice counters.
	var saved_choices = saved.get("choice_counts", {})

	if saved_choices is Dictionary:
		choice_counts = saved_choices.duplicate(true)

	# Restore sprite and node visibility.
	var saved_visibility = saved.get("node_visibility", {})

	if saved_visibility is Dictionary:

		node_visibility = saved_visibility.duplicate(true)

		for node_path in node_visibility:

			var target: Node = get_node_or_null(
				NodePath(str(node_path))
			)

			if target == null:
				continue

			if target is CanvasItem:

				target.visible = bool(
					node_visibility[node_path]
				)


# ============================================================
# SAVE STATE
# ============================================================

func _save_interaction_state() -> void:

	if _state_id.is_empty():

		_state_id = GameState.get_event_id(self)

	if _state_id.is_empty():
		return

	GameState.save_interaction_state(
		_state_id,
		interaction_count,
		choice_counts,
		node_visibility
	)


# ============================================================
# INTERACT
# ============================================================

func interact(_player = null) -> void:

	# Prevent interactions during room transitions.
	if GameState.room_transition_active:
		return

	# Prevent interactions while paused.
	if get_tree().paused:
		return

	# Prevent overlapping dialogues.
	if GameState.in_dialogue:
		return

	# Validate the dialogue resource.
	if dialogue_resource == null:

		push_warning(
			"Interactable has no DialogueResource assigned."
		)

		return

	# Remember the interacting player.
	if _player is CharacterBody2D:

		interacting_player = _player

	# Increase and remember the interaction count.
	interaction_count += 1

	_save_interaction_state()

	# Determine the dialogue start node.
	var title: String = start_node.strip_edges()

	if title.is_empty():
		title = "start"

	# ========================================================
	# PAUSE / FREEZE PROTECTION
	# ========================================================

	# Block normal player input BEFORE Dialogue Manager
	# creates the balloon.
	#
	# This prevents X from opening the pause menu during
	# the short delay before dialogue appears.

	GameState.in_dialogue = true

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

	_save_interaction_state()


func set_interaction_count(value: int) -> void:

	interaction_count = maxi(value, 0)

	_save_interaction_state()


# ============================================================
# CHOICE COUNTERS
# ============================================================

func get_choice_count(choice_name: String) -> int:

	return int(
		choice_counts.get(choice_name, 0)
	)


func increment_choice(choice_name: String) -> void:

	var current_count: int = get_choice_count(choice_name)

	choice_counts[choice_name] = current_count + 1

	_save_interaction_state()


func set_choice_count(
	choice_name: String,
	value: int
) -> void:

	choice_counts[choice_name] = maxi(value, 0)

	_save_interaction_state()


func reset_choice(choice_name: String) -> void:

	choice_counts.erase(choice_name)

	_save_interaction_state()


func reset_all_choices() -> void:

	choice_counts.clear()

	_save_interaction_state()


# ============================================================
# NODE VISIBILITY
# ============================================================

func show_node(node_path: String) -> void:

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

		# Remember that this node should remain visible.
		node_visibility[node_path] = true

		_save_interaction_state()


func hide_node(node_path: String) -> void:

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

		# Remember that this node should remain hidden.
		node_visibility[node_path] = false

		_save_interaction_state()


# ============================================================
# RESET NODE VISIBILITY MEMORY
# ============================================================

func reset_node_visibility(node_path: String) -> void:

	node_visibility.erase(node_path)

	_save_interaction_state()


func reset_all_node_visibility() -> void:

	node_visibility.clear()

	_save_interaction_state()


# ============================================================
# WALKABLE / NON-WALKABLE
# ============================================================

func make_walkable() -> void:

	if interacting_player == null:

		push_warning(
			"make_walkable() could not find the interacting player."
		)

		return

	# Make the object ignore the player.
	add_collision_exception_with(interacting_player)

	# Make the player ignore the object.
	interacting_player.add_collision_exception_with(self)


func make_solid() -> void:

	if interacting_player == null:

		push_warning(
			"make_solid() could not find the interacting player."
		)

		return

	remove_collision_exception_with(interacting_player)

	interacting_player.remove_collision_exception_with(self)


# ============================================================
# COLLISION HELPERS
# ============================================================

func disable_collision(node_path: String) -> void:

	var target: Node = get_node_or_null(
		NodePath(node_path)
	)

	if target == null:

		push_warning(
			"Could not find collision node: " + node_path
		)

		return

	if (
		target is CollisionShape2D
		or target is CollisionPolygon2D
	):

		target.set_deferred("disabled", true)

	else:

		push_warning(
			"Node is not a CollisionShape2D or CollisionPolygon2D: "
			+ node_path
		)


func enable_collision(node_path: String) -> void:

	var target: Node = get_node_or_null(
		NodePath(node_path)
	)

	if target == null:

		push_warning(
			"Could not find collision node: " + node_path
		)

		return

	if (
		target is CollisionShape2D
		or target is CollisionPolygon2D
	):

		target.set_deferred("disabled", false)

	else:

		push_warning(
			"Node is not a CollisionShape2D or CollisionPolygon2D: "
			+ node_path
		)


# ============================================================
# NODE SKEW
# ============================================================

func set_node_skew(
	node_path: String,
	degrees: float
) -> void:

	var sprite := get_node_or_null(node_path) as Node2D

	if sprite != null:

		sprite.skew = deg_to_rad(degrees)
