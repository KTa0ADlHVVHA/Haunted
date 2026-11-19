
extends Node2D


func _ready() -> void:
	GameState.has_vincent = true
	if GameState.was_event_seen("hall_blockers_removed"):
		remove_blockers()

func remove_blockers() -> void:
	var blocker_names = [
		"Area2d",
		"Area2D",
		"StaticBody2D",
		"StaticBody2D2"
	]

	for node_name in blocker_names:
		var blocker = get_node_or_null(NodePath(node_name))

		if blocker == null:
			blocker = find_child(node_name, true, false)

		if blocker != null:
			print("Removing blocker: ", blocker.name)
			blocker.queue_free()
