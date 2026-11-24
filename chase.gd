extends CanvasModulate


# ============================================================
# SETTINGS
# ============================================================

@export var chase_darkness: Color = Color("#282828")

@export var transition_speed: float = 5.0


# ============================================================
# STATE
# ============================================================

@onready var flashlight: PointLight2D = (
	get_parent().get_node_or_null("Plum/Flashlight") as PointLight2D
)

var normal_colour: Color
var flashlight_was_enabled: bool = true
var was_chasing: bool = false


# ============================================================
# READY
# ============================================================

func _ready() -> void:
	normal_colour = color


# ============================================================
# LIGHTING
# ============================================================

func _process(delta: float) -> void:

	var chasing: bool = GameState.hide_chase_active

	# Chase just started.
	if chasing and not was_chasing:

		normal_colour = color

		if flashlight != null:
			flashlight_was_enabled = flashlight.enabled
			flashlight.enabled = false

	# Chase just ended.
	elif not chasing and was_chasing:

		if flashlight != null:
			flashlight.enabled = flashlight_was_enabled

	was_chasing = chasing

	# Gradually change the room's darkness.
	var target_colour: Color = normal_colour

	if chasing:
		target_colour = chase_darkness

	color = color.lerp(
		target_colour,
		clampf(delta * transition_speed, 0.0, 1.0)
	)
