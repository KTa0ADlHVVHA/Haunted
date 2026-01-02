extends Node2D

@export var player: CharacterBody2D
@onready var reflection_sprite: Sprite2D = $SubViewportContainer/Reflection
@onready var mirror_sprite: Sprite2D = $MirrorSprite
@onready var detection_area: Area2D =  $Area2D



@export var dialogue_resource: DialogueResource
@export var start_node := "start"




# Maximum distance for full alpha (inside the area)
@export var max_fade_distance := 200.0
@export var fade_speed := 3.0  # higher = faster fade

var player_inside := false

func _ready():
	# Start fully invisible
	reflection_sprite.modulate.a = 0.0

	# Connect Area2D signals
	detection_area.body_entered.connect(_on_area_entered)
	detection_area.body_exited.connect(_on_area_exited)

func _process(_delta):
	if not player or not player_inside:
		reflection_sprite.modulate.a = lerp(reflection_sprite.modulate.a, 0.0, fade_speed * _delta)
		return

	var distance = player.global_position.distance_to(mirror_sprite.global_position)
	var target_alpha = clamp(1.0 - distance / max_fade_distance, 0.0, 1.0)
	target_alpha *= 200.0 / 255.0
	reflection_sprite.modulate.a = lerp(reflection_sprite.modulate.a, target_alpha, fade_speed * _delta)

	if reflection_sprite.modulate.a < 0.01:
		return

	var ps: Sprite2D = player.get_node("Sprite2D")
	reflection_sprite.texture = ps.texture
	reflection_sprite.hframes = ps.hframes
	reflection_sprite.vframes = ps.vframes

	var hframe = ps.frame % ps.hframes
	var vframe = int(ps.frame / ps.hframes)

	# Swap vertical frames for mirror (Up/Down)
	if vframe == 0:
		vframe = 3
	elif vframe == 3:
		vframe = 0

	reflection_sprite.frame = vframe * ps.hframes + hframe

	# --- Mirror horizontal flip properly ---
	if vframe == 0 or vframe == 3:
		reflection_sprite.flip_h = not ps.flip_h
	else:
		reflection_sprite.flip_h = ps.flip_h

	reflection_sprite.position = Vector2(-22.139, 262.766)



# --- Area2D signals ---
func _on_area_entered(body):
	if body == player:
		player_inside = true

func _on_area_exited(body):
	if body == player:
		player_inside = false
		
		
		
		
		
func interact(_player):
	if GameState.in_dialogue:
		return

	DialogueManager.show_dialogue_balloon(
		dialogue_resource,
		start_node
	)
