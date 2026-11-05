
extends Area2D


func _ready() -> void:
	monitoring = true


func _input(event: InputEvent) -> void:
	if GameState.in_dialogue:
		return

	if get_tree().paused:
		return

	if event is InputEventKey and event.echo:
		return

	if not (
		event.is_action_pressed("interact")
		or event.is_action_pressed("ui_accept")
	):
		return

	for body in get_overlapping_bodies():
		if body is CharacterBody2D:
			var hole = get_parent()

			if hole.has_method("interact"):
				hole.interact(body)
				get_viewport().set_input_as_handled()

			return
