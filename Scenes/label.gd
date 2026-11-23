extends Label


@export var top_margin: float = 20.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

	# Makes sure it draws above the game.
	z_index = 100


func _process(_delta: float) -> void:

	if GameState.hide_chase_active:

		visible = true

		var seconds_left: int = int(
			ceil(GameState.hide_chase_time_left)
		)

		text = str(seconds_left)

		_position_timer()

	else:

		visible = false


func _position_timer() -> void:

	var viewport_size: Vector2 = (
		get_viewport_rect().size
	)

	# Update the Label's size based on the number.
	reset_size()

	position = Vector2(
		(viewport_size.x - size.x) / 2.0,
		top_margin
	)
