extends Node2D


# ============================================================
# FLASHLIGHT SETTINGS
# ============================================================

enum FlashlightMode {
	ALWAYS_ON,
	ALWAYS_OFF,
	UNRELIABLE
}

@export var flashlight_mode: FlashlightMode = FlashlightMode.ALWAYS_ON

# How long the flashlight works before failing.
@export var min_working_time: float = 8.0
@export var max_working_time: float = 18.0

# How long the flashlight stops working.
@export var min_failure_time: float = 1.0
@export var max_failure_time: float = 3.0


# ============================================================
# STATE
# ============================================================

@onready var flashlight: PointLight2D = (
	get_node_or_null("Plum/Flashlight") as PointLight2D
)

var time_remaining: float = 0.0


# ============================================================
# READY
# ============================================================

func _ready() -> void:

	GameState.has_vincent = true

	if flashlight == null:
		push_warning("Could not find Plum/Flashlight.")
		return

	match flashlight_mode:

		FlashlightMode.ALWAYS_ON:
			flashlight.enabled = true

		FlashlightMode.ALWAYS_OFF:
			flashlight.enabled = false

		FlashlightMode.UNRELIABLE:
			flashlight.enabled = true

			time_remaining = randf_range(
				min_working_time,
				max_working_time
			)


# ============================================================
# FLASHLIGHT FAILURE
# ============================================================

func _process(delta: float) -> void:

	if flashlight == null:
		return

	if flashlight_mode != FlashlightMode.UNRELIABLE:
		return

	if GameState.in_dialogue:
		return

	time_remaining -= delta

	if time_remaining > 0.0:
		return

	flashlight.enabled = not flashlight.enabled

	if flashlight.enabled:

		time_remaining = randf_range(
			min_working_time,
			max_working_time
		)

	else:

		time_remaining = randf_range(
			min_failure_time,
			max_failure_time
		)
