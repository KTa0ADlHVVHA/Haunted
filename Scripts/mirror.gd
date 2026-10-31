extends Node2D


# ============================================================
# PLAYER / MIRROR NODES
# ============================================================

@export var player: CharacterBody2D

@onready var reflection_sprite: Sprite2D = \
	$SubViewportContainer/Reflection

@onready var mirror_sprite: Sprite2D = \
	$MirrorSprite

@onready var detection_area: Area2D = \
	$Area2D


# ============================================================
# DIALOGUE
# ============================================================

@export var dialogue_resource: DialogueResource

@export var start_node: String = "start"


# The dialogue file can read this.
#
# 1 = first interaction
# 2 = second interaction
# 3 = third interaction
# etc.
var interaction_count: int = 0


# ============================================================
# MIRROR SETTINGS
# ============================================================

# Maximum distance for full alpha.
@export var max_fade_distance: float = 200.0

# Higher = faster fade.
@export var fade_speed: float = 3.0


# ============================================================
# STATE
# ============================================================

var player_inside: bool = false


# ============================================================
# READY
# ============================================================

func _ready() -> void:
	# Start fully invisible.
	reflection_sprite.modulate.a = 0.0


	# Connect Area2D signals.
	detection_area.body_entered.connect(
		_on_area_entered
	)

	detection_area.body_exited.connect(
		_on_area_exited
	)


# ============================================================
# PROCESS
# ============================================================

func _process(delta: float) -> void:
	# --------------------------------------------------------
	# PLAYER NOT IN MIRROR AREA
	# --------------------------------------------------------

	if not player or not player_inside:

		reflection_sprite.modulate.a = lerp(
			reflection_sprite.modulate.a,
			0.0,
			fade_speed * delta
		)

		return


	# --------------------------------------------------------
	# MIRROR FADE
	# --------------------------------------------------------

	var distance: float = (
		player.global_position.distance_to(
			mirror_sprite.global_position
		)
	)


	var target_alpha: float = clamp(
		1.0 - distance / max_fade_distance,
		0.0,
		1.0
	)


	target_alpha *= (
		200.0 / 255.0
	)


	reflection_sprite.modulate.a = lerp(
		reflection_sprite.modulate.a,
		target_alpha,
		fade_speed * delta
	)


	# Reflection is basically invisible,
	# so don't bother updating the sprite.
	if reflection_sprite.modulate.a < 0.01:
		return


	# --------------------------------------------------------
	# COPY PLAYER SPRITE
	# --------------------------------------------------------

	var ps: Sprite2D = player.get_node(
		"Sprite2D"
	)


	reflection_sprite.texture = ps.texture

	reflection_sprite.hframes = ps.hframes

	reflection_sprite.vframes = ps.vframes


	# --------------------------------------------------------
	# GET PLAYER FRAME
	# --------------------------------------------------------

	var hframe: int = (
		ps.frame % ps.hframes
	)


	var vframe: int = int(
		ps.frame / ps.hframes
	)


	# --------------------------------------------------------
	# MIRROR UP / DOWN
	# --------------------------------------------------------

	if vframe == 0:

		vframe = 3


	elif vframe == 3:

		vframe = 0


	reflection_sprite.frame = (
		vframe * ps.hframes
		+ hframe
	)


	# --------------------------------------------------------
	# MIRROR HORIZONTAL FLIP
	# --------------------------------------------------------

	if (
		vframe == 0
		or vframe == 3
	):

		reflection_sprite.flip_h = (
			not ps.flip_h
		)


	else:

		reflection_sprite.flip_h = (
			ps.flip_h
		)


	# --------------------------------------------------------
	# REFLECTION POSITION
	# --------------------------------------------------------

	reflection_sprite.position = Vector2(
		7.398,
		15.214
	)


# ============================================================
# AREA ENTERED
# ============================================================

func _on_area_entered(
	body: Node2D
) -> void:

	if body == player:

		player_inside = true


# ============================================================
# AREA EXITED
# ============================================================

func _on_area_exited(
	body: Node2D
) -> void:

	if body == player:

		player_inside = false


# ============================================================
# INTERACT
# ============================================================

func interact(_player = null) -> void:
	if GameState.in_dialogue:
		return


	if dialogue_resource == null:

		push_warning(
			"Mirror has no DialogueResource assigned."
		)

		return


	# --------------------------------------------------------
	# COUNT INTERACTION
	# --------------------------------------------------------

	interaction_count += 1


	# --------------------------------------------------------
	# START NODE
	# --------------------------------------------------------

	var title: String = (
		start_node.strip_edges()
	)


	if title.is_empty():

		title = "start"


	# --------------------------------------------------------
	# START DIALOGUE
	# --------------------------------------------------------

	# [self] exposes interaction_count to the dialogue file.
	DialogueManager.show_dialogue_balloon(
		dialogue_resource,
		title,
		[self]
	)


# ============================================================
# OPTIONAL HELPERS
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
