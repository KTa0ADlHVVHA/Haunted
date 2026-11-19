
extends Node

const SAVE_DIR: String = "user://saves/"
const SLOT_COUNT: int = 15

var current_slot: int = 1
var pending_load_data: Dictionary = {}
var is_loading: bool = false

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)

func _get_slot_path(slot: int) -> String:
	return SAVE_DIR + "slot_%d.json" % slot

# ------------------------------------------------------------
# SAVE
# ------------------------------------------------------------

func save_game(slot: int, data: Dictionary) -> bool:
	current_slot = slot
	var data_to_save: Dictionary = data.duplicate(true)

	# Existing global state
	data_to_save["playtime"] = GameState.total_playtime
	data_to_save["has_vincent"] = GameState.has_vincent
	data_to_save["has_house_key"] = GameState.has_house_key
	data_to_save["fountain_key_taken"] = GameState.fountain_key_taken

	# NEW: remember where the player last left each room, and
	# which opening cutscenes / one-time triggers were completed.
	data_to_save["room_positions"] = GameState.room_positions.duplicate(true)
	data_to_save["seen_events"] = GameState.seen_events.duplicate(true)

	data_to_save["timestamp"] = Time.get_datetime_string_from_system(false, true)

	var path: String = _get_slot_path(slot)
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Could not open save file: " + path)
		return false

	file.store_string(JSON.stringify(data_to_save, "\t"))
	file.close()
	return true

# ------------------------------------------------------------
# READ SLOT (DO NOT LOAD)
# ------------------------------------------------------------

func get_slot_data(slot: int) -> Dictionary:
	var path: String = _get_slot_path(slot)
	if not FileAccess.file_exists(path):
		return {}

	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}

	var file_text: String = file.get_as_text()
	file.close()

	var parsed = JSON.parse_string(file_text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("Save slot %d contains invalid data." % slot)
		return {}
	return parsed

# ------------------------------------------------------------
# LOAD
# ------------------------------------------------------------

func load_game(slot: int) -> bool:
	var data: Dictionary = get_slot_data(slot)
	if data.is_empty():
		return false

	var scene_path: String = str(data.get("scene_path", ""))
	if scene_path.is_empty():
		push_warning("Save slot %d has no scene_path." % slot)
		return false
	if not ResourceLoader.exists(scene_path):
		push_warning("Saved scene does not exist: " + scene_path)
		return false

	current_slot = slot

	GameState.total_playtime = float(data.get("playtime", 0.0))
	GameState.has_vincent = bool(data.get("has_vincent", false))
	GameState.has_house_key = bool(data.get("has_house_key", false))
	GameState.fountain_key_taken = bool(data.get("fountain_key_taken", false))

	# Older save files do not have these fields. They load safely
	# with an empty history, so entrances may replay once.
	var remembered_positions = data.get("room_positions", {})
	if remembered_positions is Dictionary:
		GameState.room_positions = remembered_positions.duplicate(true)
	else:
		GameState.room_positions = {}

	var completed_events = data.get("seen_events", {})
	if completed_events is Dictionary:
		GameState.seen_events = completed_events.duplicate(true)
	else:
		GameState.seen_events = {}

	# Character.gd loads the exact saved player_position in _ready.
	# Tell Cutscene.gd not to overwrite that with an earlier room position.
	GameState.loading_from_save = true
	GameState.skip_room_restore_path = scene_path

	pending_load_data = data.duplicate(true)
	is_loading = true
	get_tree().paused = false

	var error: Error = get_tree().change_scene_to_file(scene_path)
	if error != OK:
		push_error("Could not load scene: " + scene_path)
		pending_load_data.clear()
		is_loading = false
		GameState.loading_from_save = false
		GameState.skip_room_restore_path = ""
		return false

	return true

# ------------------------------------------------------------
# PENDING LOAD (USED BY Character.gd)
# ------------------------------------------------------------

func has_pending_load() -> bool:
	return is_loading and not pending_load_data.is_empty()

func consume_pending_load() -> Dictionary:
	var data: Dictionary = pending_load_data.duplicate(true)
	pending_load_data.clear()
	is_loading = false
	return data

# ------------------------------------------------------------
# DELETE / SLOT INFO
# ------------------------------------------------------------

func delete_slot(slot: int) -> bool:
	var path: String = _get_slot_path(slot)
	if not FileAccess.file_exists(path):
		return true
	var error: Error = DirAccess.remove_absolute(path)
	return error == OK

func slot_exists(slot: int) -> bool:
	return FileAccess.file_exists(_get_slot_path(slot))

func get_current_slot() -> int:
	return current_slot

# ------------------------------------------------------------
# VECTOR2 SERIALIZATION
# ------------------------------------------------------------

func serialize_vector2(value: Vector2) -> Dictionary:
	return {"x": value.x, "y": value.y}

func deserialize_vector2(data, fallback: Vector2 = Vector2.ZERO) -> Vector2:
	if typeof(data) != TYPE_DICTIONARY:
		return fallback
	if not data.has("x") or not data.has("y"):
		return fallback
	return Vector2(float(data["x"]), float(data["y"]))
