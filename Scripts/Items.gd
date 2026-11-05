
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


# Remember the player who interacted with this object.
var interacting_player: CharacterBody2D = null


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

	# Remember who interacted with us.
	if _player is CharacterBody2D:
		interacting_player = _player

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

# Supports Sprite2D, Polygon2D and other CanvasItem nodes.

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
	add_collision_exception_with(
		interacting_player
	)

	# Also make the player ignore this object.
	interacting_player.add_collision_exception_with(
		self
	)


func make_solid() -> void:
	if interacting_player == null:
		push_warning(
			"make_solid() could not find the interacting player."
		)
		return

	remove_collision_exception_with(
		interacting_player
	)

	interacting_player.remove_collision_exception_with(
		self
	)


# ============================================================
# COLLISION HELPERS
# ============================================================

# Supports:
# - CollisionShape2D
# - CollisionPolygon2D

func disable_collision(
	node_path: String
) -> void:

	var target: Node = get_node_or_null(
		NodePath(node_path)
	)

	if target == null:
		push_warning(
			"Could not find collision node: " + node_path
		)
		return

	if target is CollisionShape2D or target is CollisionPolygon2D:
		target.set_deferred(
			"disabled",
			true
		)
	else:
		push_warning(
			"Node is not a CollisionShape2D or CollisionPolygon2D: "
			+ node_path
		)


func enable_collision(
	node_path: String
) -> void:

	var target: Node = get_node_or_null(
		NodePath(node_path)
	)

	if target == null:
		push_warning(
			"Could not find collision node: " + node_path
		)
		return

	if target is CollisionShape2D or target is CollisionPolygon2D:
		target.set_deferred(
			"disabled",
			false
		)
	else:
		push_warning(
			"Node is not a CollisionShape2D or CollisionPolygon2D: "
			+ node_path
		)


# ============================================================
# NODE SKEW
# ============================================================

# Supports Sprite2D, Polygon2D and other Node2D nodes.

func set_node_skew(
	node_path: String,
	degrees: float
) -> void:

	var sprite := get_node_or_null(node_path) as Node2D

	if sprite != null:
		sprite.skew = deg_to_rad(degrees)
