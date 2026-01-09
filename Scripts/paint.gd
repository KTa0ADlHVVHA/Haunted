extends Control

@onready var canvas: TextureRect = $Canvas
@onready var brush_icon: TextureRect = $Brush

var image: Image
var texture: ImageTexture
var brush_color: Color = Color.html("#C03B94")

var brush_size := 4
var drawing := false
var last_pos: Vector2

# brush size presets
const BRUSH_SIZES := [1, 4, 8, 16]
var brush_size_index := 1 # default = 4

# brush icon textures
const BRUSH_ICON_SMALL := preload("res://Art/Extras/Laptop Pen Small.png")
const BRUSH_ICON_MED   := preload("res://Art/Extras/Laptop Pen Mid.png")
const BRUSH_ICON_LARGE := preload("res://Art/Extras/Laptop Pen Large.png")

# distance between stamps (higher = faster, lower = smoother)
const STAMP_SPACING := 1.5


func _ready():
	image = Image.create(
		int(canvas.size.x),
		int(canvas.size.y),
		false,
		Image.FORMAT_RGBA8
	)

	# Canvas starts as color 1
	image.fill(Color.html("#FFE0DC"))

	texture = ImageTexture.create_from_image(image)
	canvas.texture = texture

	update_brush_icon() # initialize icon


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


func draw_brush_line(from: Vector2, to: Vector2):
	var dist := from.distance_to(to)
	if dist <= 0.0:
		return

	var steps := int(dist / STAMP_SPACING)

	for i in range(steps + 1):
		var t := float(i) / float(steps)
		var pos := from.lerp(to, t)
		draw_brush(pos)


func draw_brush(pos: Vector2):
	var center := Vector2i(pos)

	for x in range(-brush_size, brush_size + 1):
		for y in range(-brush_size, brush_size + 1):
			if x * x + y * y > brush_size * brush_size:
				continue

			var p := center + Vector2i(x, y)
			if p.x >= 0 and p.y >= 0 and p.x < image.get_width() and p.y < image.get_height():
				image.set_pixel(p.x, p.y, brush_color)


# ─── COLORS ─────────────────────────────

func _on_color_pressed() -> void:
	brush_color = Color.html("#FFE0DC")

func _on_color_2_pressed() -> void:
	brush_color = Color.html("#C03B94")

func _on_color_3_pressed() -> void:
	brush_color = Color.html("#9E20BB")

func _on_color_4_pressed() -> void:
	brush_color = Color.html("#6A1794")

func _on_color_5_pressed() -> void:
	brush_color = Color.html("#220770")


# ─── BRUSH SIZE ──────────────────────────

func cycle_brush_size():
	brush_size_index += 1
	if brush_size_index >= BRUSH_SIZES.size():
		brush_size_index = 1 # back to default (4)

	brush_size = BRUSH_SIZES[brush_size_index]
	update_brush_icon()


func update_brush_icon():
	match brush_size:
		4:
			brush_icon.texture = BRUSH_ICON_SMALL
		8:
			brush_icon.texture = BRUSH_ICON_MED
		16:
			brush_icon.texture = BRUSH_ICON_LARGE


func _on_brush_size_pressed() -> void:
	cycle_brush_size()
