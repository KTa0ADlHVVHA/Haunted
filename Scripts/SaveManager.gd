extends Node


# ============================================================
# SAVE SETTINGS
# ============================================================

const SAVE_DIR: String = "user://saves/"

const SLOT_COUNT: int = 15


# ============================================================
# CURRENT SAVE STATE
# ============================================================

var current_slot: int = 1


# Data waiting for the newly loaded Character scene.
var pending_load_data: Dictionary = {}


var is_loading: bool = false


# ============================================================
# READY
# ============================================================

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(
		SAVE_DIR
	)


# ============================================================
# PATH
# ============================================================

func _get_slot_path(
	slot: int
) -> String:

	return SAVE_DIR + "slot_%d.json" % slot


# ============================================================
# SAVE GAME
# ============================================================

func save_game(
	slot: int,
	data: Dictionary
) -> bool:

	current_slot = slot


	var data_to_save: Dictionary = data.duplicate(
		true
	)


	# --------------------------------------------------------
	# GLOBAL GAME STATE
	# --------------------------------------------------------

	# SaveManager adds these automatically so individual
	# scenes / Character don't have to remember to include
	# every story flag.

	data_to_save["playtime"] = (
		GameState.total_playtime
	)

	data_to_save["has_vincent"] = (
		GameState.has_vincent
	)


	# --------------------------------------------------------
	# HOUSE KEY
	# --------------------------------------------------------

	data_to_save["has_house_key"] = (
		GameState.has_house_key
	)

	data_to_save["fountain_key_taken"] = (
		GameState.fountain_key_taken
	)


	# --------------------------------------------------------
	# SAVE INFORMATION
	# --------------------------------------------------------

	data_to_save["timestamp"] = (
		Time.get_datetime_string_from_system(
			false,
			true
		)
	)


	# --------------------------------------------------------
	# WRITE FILE
	# --------------------------------------------------------

	var path: String = _get_slot_path(
		slot
	)


	var file: FileAccess = FileAccess.open(
		path,
		FileAccess.WRITE
	)


	if file == null:

		push_error(
			"Could not open save file: " + path
		)

		return false


	file.store_string(
		JSON.stringify(
			data_to_save,
			"\t"
		)
	)


	file.close()


	return true


# ============================================================
# READ SLOT WITHOUT LOADING IT
# ============================================================

func get_slot_data(
	slot: int
) -> Dictionary:

	var path: String = _get_slot_path(
		slot
	)


	if not FileAccess.file_exists(
		path
	):
		return {}


	var file: FileAccess = FileAccess.open(
		path,
		FileAccess.READ
	)


	if file == null:
		return {}


	var text: String = file.get_as_text()


	file.close()


	var parsed = JSON.parse_string(
		text
	)


	if typeof(parsed) != TYPE_DICTIONARY:

		push_warning(
			"Save slot %d contains invalid data." % slot
		)

		return {}


	return parsed


# ============================================================
# LOAD GAME
# ============================================================

func load_game(
	slot: int
) -> bool:

	var data: Dictionary = get_slot_data(
		slot
	)


	if data.is_empty():
		return false


	var scene_path: String = str(
		data.get(
			"scene_path",
			""
		)
	)


	if scene_path.is_empty():

		push_warning(
			"Save slot %d has no scene_path." % slot
		)

		return false


	if not ResourceLoader.exists(
		scene_path
	):

		push_warning(
			"Saved scene does not exist: " + scene_path
		)

		return false


	current_slot = slot


	# --------------------------------------------------------
	# RESTORE GLOBAL GAME STATE
	# --------------------------------------------------------

	GameState.total_playtime = float(
		data.get(
			"playtime",
			0.0
		)
	)


	GameState.has_vincent = bool(
		data.get(
			"has_vincent",
			false
		)
	)


	# --------------------------------------------------------
	# RESTORE HOUSE KEY
	# --------------------------------------------------------

	GameState.has_house_key = bool(
		data.get(
			"has_house_key",
			false
		)
	)


	GameState.fountain_key_taken = bool(
		data.get(
			"fountain_key_taken",
			false
		)
	)


	# --------------------------------------------------------
	# CHARACTER LOAD DATA
	# --------------------------------------------------------

	pending_load_data = data.duplicate(
		true
	)


	is_loading = true


	# Never change scenes while the tree is still paused.
	get_tree().paused = false


	var error: Error = get_tree().change_scene_to_file(
		scene_path
	)


	if error != OK:

		push_error(
			"Could not load scene: " + scene_path
		)

		pending_load_data.clear()

		is_loading = false

		return false


	return true


# ============================================================
# PENDING LOAD
# ============================================================

func has_pending_load() -> bool:

	return (
		is_loading
		and not pending_load_data.is_empty()
	)


func consume_pending_load() -> Dictionary:

	var data: Dictionary = pending_load_data.duplicate(
		true
	)


	pending_load_data.clear()

	is_loading = false


	return data


# ============================================================
# DELETE SAVE
# ============================================================

func delete_slot(
	slot: int
) -> bool:

	var path: String = _get_slot_path(
		slot
	)


	if not FileAccess.file_exists(
		path
	):
		return true


	var error: Error = DirAccess.remove_absolute(
		path
	)


	return error == OK


# ============================================================
# SLOT INFORMATION
# ============================================================

func slot_exists(
	slot: int
) -> bool:

	return FileAccess.file_exists(
		_get_slot_path(
			slot
		)
	)


func get_current_slot() -> int:

	return current_slot


# ============================================================
# VECTOR2 SERIALIZATION
# ============================================================

func serialize_vector2(
	value: Vector2
) -> Dictionary:

	return {
		"x": value.x,
		"y": value.y
	}


func deserialize_vector2(
	data,
	fallback: Vector2 = Vector2.ZERO
) -> Vector2:

	if typeof(data) != TYPE_DICTIONARY:
		return fallback


	if not data.has("x"):
		return fallback


	if not data.has("y"):
		return fallback


	return Vector2(
		float(data["x"]),
		float(data["y"])
	)
