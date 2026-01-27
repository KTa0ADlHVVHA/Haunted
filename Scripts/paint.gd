extends Control

@onready var canvas: TextureRect = $Canvas
@onready var brush_icon: TextureRect = $Brush

var image: Image
var texture: ImageTexture
var brush_color: Color = Color.html("#C03B94")

var brush_size := 4
var drawing := false
var last_pos: Vector2

# ─── BRUSH SIZE PRESETS ──────────────────

const BRUSH_SIZES := [1, 4, 8, 16]
var brush_size_index := 1 # default = 4

# remember last brush state
var last_brush_size := 4
var last_brush_size_index := 1
var last_brush_color := Color.html("#C03B94")

# eraser state
var is_eraser := false
var needs_restore := false

# ─── BRUSH ICONS ─────────────────────────

const BRUSH_ICON_SMALL := preload("res://Art/Extras/Laptop Pen Small.png")
const BRUSH_ICON_MED   := preload("res://Art/Extras/Laptop Pen Mid.png")
const BRUSH_ICON_LARGE := preload("res://Art/Extras/Laptop Pen Large.png")

const STAMP_SPACING := 1.5


func _ready():
	image = Image.create(
		int(canvas.size.x),
		int(canvas.size.y),
		false,
		Image.FORMAT_RGBA8
	)

	image.fill(Color.html("#FFE0DC"))
	texture = ImageTexture.create_from_image(image)
	canvas.texture = texture

	update_brush_icon()


# ─── INPUT ───────────────────────────────

func _gui_input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		drawing = event.pressed
		if drawing:
			last_pos = event.position
			draw_brush(event.position)
			texture.update(image)

	elif event is InputEventMouseMotion and drawing:
		draw_brush_line(last_pos, event.position)
		last_pos = event.position
		texture.update(image)


# ─── DRAWING ─────────────────────────────

func draw_brush_line(from: Vector2, to: Vector2):
	var dist := from.distance_to(to)
	if dist <= 0.0:
		return

	var steps := int(dist / STAMP_SPACING)
	for i in range(steps + 1):
		var t := float(i) / float(steps)
		draw_brush(from.lerp(to, t))


func draw_brush(pos: Vector2):
	var center := Vector2i(pos)

	for x in range(-brush_size, brush_size + 1):
		for y in range(-brush_size, brush_size + 1):
			if x * x + y * y > brush_size * brush_size:
				continue

			var p := center + Vector2i(x, y)
			if p.x >= 0 and p.y >= 0 and p.x < image.get_width() and p.y < image.get_height():
				image.set_pixel(p.x, p.y, brush_color)


# ─── COLORS ──────────────────────────────

func _set_brush_color(color: Color):
	is_eraser = false
	needs_restore = false
	brush_color = color
	last_brush_color = color


func _on_color_pressed() -> void:
	_set_brush_color(Color.html("#FFE0DC"))

func _on_color_2_pressed() -> void:
	_set_brush_color(Color.html("#C03B94"))

func _on_color_3_pressed() -> void:
	_set_brush_color(Color.html("#9E20BB"))

func _on_color_4_pressed() -> void:
	_set_brush_color(Color.html("#6A1794"))

func _on_color_5_pressed() -> void:
	# ERASER
	if not is_eraser:
		last_brush_size = brush_size
		last_brush_size_index = brush_size_index
		last_brush_color = brush_color

	is_eraser = true
	needs_restore = true
	brush_color = Color.html("#220770")


# ─── BRUSH SIZE BUTTON ───────────────────

func _on_brush_size_pressed() -> void:
	# FIRST click after eraser → restore brush
	if needs_restore:
		is_eraser = false
		needs_restore = false

		brush_size = last_brush_size
		brush_size_index = last_brush_size_index
		brush_color = last_brush_color

		update_brush_icon()
		return

	# SECOND+ click → normal cycling
	cycle_brush_size()


func cycle_brush_size():
	brush_size_index += 1
	if brush_size_index >= BRUSH_SIZES.size():
		brush_size_index = 1

	brush_size = BRUSH_SIZES[brush_size_index]

	last_brush_size = brush_size
	last_brush_size_index = brush_size_index

	update_brush_icon()


func update_brush_icon():
	match brush_size:
		4:
			brush_icon.texture = BRUSH_ICON_SMALL
		8:
			brush_icon.texture = BRUSH_ICON_MED
		16:
			brush_icon.texture = BRUSH_ICON_LARGE
