
extends Area2D

@export_range(0.1, 1.0, 0.05) var speed_multiplier: float = 0.5

var original_speeds: Dictionary = {}


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node2D) -> void:
	if not body is CharacterBody2D:
		return

	if original_speeds.has(body):
		return

	if not _has_speed_properties(body):
		return

	var walk: float = float(body.get("walk_speed"))
	var run: float = float(body.get("run_speed"))

	original_speeds[body] = Vector2(walk, run)

	body.set("walk_speed", walk * speed_multiplier)
	body.set("run_speed", run * speed_multiplier)


func _on_body_exited(body: Node2D) -> void:
	_restore_speed(body)


func _restore_speed(body: Node2D) -> void:
	if not original_speeds.has(body):
		return

	var speeds: Vector2 = original_speeds[body]

	if is_instance_valid(body):
		body.set("walk_speed", speeds.x)
		body.set("run_speed", speeds.y)

	original_speeds.erase(body)


func _has_speed_properties(body: Node2D) -> bool:
	var has_walk: bool = false
	var has_run: bool = false

	for property_info in body.get_property_list():
		if property_info["name"] == "walk_speed":
			has_walk = true

		if property_info["name"] == "run_speed":
			has_run = true

	return has_walk and has_run


func _exit_tree() -> void:
	for body in original_speeds.keys():
		if is_instance_valid(body):
			_restore_speed(body)
