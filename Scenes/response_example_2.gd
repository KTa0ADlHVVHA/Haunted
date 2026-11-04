
extends Button

@export var minimum_font_size: int = 8
@export var horizontal_padding: float = 20.0

var normal_font_size: int = 16
var previous_text: String = ""
var previous_width: float = 0.0


func _ready() -> void:
	normal_font_size = get_theme_font_size("font_size")
	clip_text = true
	_update_font_size()


func _process(_delta: float) -> void:
	if text != previous_text or size.x != previous_width:
		_update_font_size()


func _update_font_size() -> void:
	previous_text = text
	previous_width = size.x

	if text.is_empty():
		return

	var font: Font = get_theme_font("font")
	var available_width: float = maxf(1.0, size.x - horizontal_padding)

	for font_size in range(normal_font_size, minimum_font_size - 1, -1):
		var text_width: float = font.get_string_size(
			text,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			font_size
		).x

		if text_width <= available_width:
			add_theme_font_size_override("font_size", font_size)
			return

	add_theme_font_size_override("font_size", minimum_font_size)
