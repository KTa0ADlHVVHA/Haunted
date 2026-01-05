extends Node

const SAVE_DIR := "user://"
const SLOT_COUNT := 15  # Number of save slots

var current_slot: int = 1
var save_data: Dictionary = {}

# ---------------- INTERNAL ----------------
func _get_slot_path(slot: int) -> String:
	return "%ssave_slot_%d.json" % [SAVE_DIR, slot]

# ---------------- SLOT CONTROL ----------------
func set_slot(slot: int):
	current_slot = clamp(slot, 1, SLOT_COUNT)
	load_slot(current_slot)

func get_slot() -> int:
	return current_slot

# ---------------- SAVE ----------------
func save():
	var path := _get_slot_path(current_slot)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Failed to open save file for slot %d" % current_slot)
		return
	file.store_string(JSON.stringify(save_data))
	file.close()

# ---------------- LOAD ----------------
func load_slot(slot: int):
	var path := _get_slot_path(slot)
	if not FileAccess.file_exists(path):
		save_data = {}
		return

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Failed to open save file for slot %d" % slot)
		return

	var parsed = JSON.parse_string(file.get_as_text())
	file.close()

	if typeof(parsed) == TYPE_DICTIONARY:
		save_data = parsed
	else:
		save_data = {}

# ---------------- DELETE ----------------
func delete_slot(slot: int):
	var path := _get_slot_path(slot)
	if FileAccess.file_exists(path):
		var dir := DirAccess.open(SAVE_DIR)
		if dir:
			dir.remove(path.get_file())

	if slot == current_slot:
		save_data = {}

# ---------------- SET / GET ----------------
func set_value(key: String, value):
	save_data[key] = value

func get_value(key: String, default_value = null):
	return save_data.get(key, default_value)

# ---------------- HELPERS ----------------
func serialize_vector2(v: Vector2) -> Dictionary:
	return { "x": v.x, "y": v.y }

func deserialize_vector2(d: Dictionary, fallback := Vector2.ZERO) -> Vector2:
	if d.has("x") and d.has("y"):
		return Vector2(d["x"], d["y"])
	return fallback

# ---------------- INFO ----------------
func slot_exists(slot: int) -> bool:
	return FileAccess.file_exists(_get_slot_path(slot))
