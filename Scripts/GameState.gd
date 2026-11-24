
extends Node

var interaction_states: Dictionary = {}
# General game state
var pov: String = "father"
var in_dialogue: bool = false
var has_vincent: bool = false
var total_playtime: float = 0.0
var in_game: bool = true
var windows_username: String = OS.get_environment("USERNAME")
# ============================================================
# HIDE / CHASE EVENT
# ============================================================
var room_transition_active: bool = false
var hide_chase_active: bool = false
var hide_chase_time_left: float = 0.0

var _hide_chase_id: int = 0

# Story / inventory
var has_flower: bool = false
var flower_taken: bool = false
var has_house_key: bool = false
var fountain_key_taken: bool = false

# Broken chair
var chair_broken: bool = false
var has_broken_chair_part: bool = false
var has_fixed_chair_part: bool = false

# Fake door / code
var door_fallen: bool = false
var has_door_code: bool = false
const SAFE_CODE_ITEM: String = "Code (247)"

# Safe
var safe_opened: bool = false

# Inventory
var inventory: Array[String] = []

# Room memory: scene path -> {x, y, facing_x, facing_y}
var room_positions: Dictionary = {}

# Once-only events: "scene_path:node_path" -> true
var seen_events: Dictionary = {}

# Used by SaveManager to avoid overwriting the position from a save.
var loading_from_save: bool = false
var skip_room_restore_path: String = ""

func _ready() -> void:
	get_tree().process_frame.connect(_debug_freeze)
	if not DialogueManager.dialogue_started.is_connected(_on_dialogue_started):
		DialogueManager.dialogue_started.connect(_on_dialogue_started)
	if not DialogueManager.dialogue_ended.is_connected(_on_dialogue_ended):
		DialogueManager.dialogue_ended.connect(_on_dialogue_ended)
	if not get_tree().scene_changed.is_connected(_on_scene_changed):
		get_tree().scene_changed.connect(_on_scene_changed)

func _process(delta: float) -> void:
	if in_game:
		total_playtime += delta

func _on_dialogue_started(_resource = null) -> void:
	if room_transition_active:
		return

	in_dialogue = true

func _on_dialogue_ended(_resource = null) -> void:
	in_dialogue = false
func _on_scene_changed(_new_scene = null) -> void:
	loading_from_save = false
	skip_room_restore_path = ""
	room_transition_active = false

func get_playtime() -> int:
	return int(total_playtime)

# House key
func give_house_key() -> void:
	has_house_key = true
	fountain_key_taken = true

func has_item_house_key() -> bool:
	return has_house_key

func remove_house_key() -> void:
	has_house_key = false

# Chair
func collect_broken_chair_part() -> void:
	chair_broken = true
	has_broken_chair_part = true

func remove_broken_chair_part() -> void:
	has_broken_chair_part = false

func fix_broken_chair_part() -> void:
	if has_broken_chair_part:
		has_broken_chair_part = false
		has_fixed_chair_part = true

func remove_fixed_chair_part() -> void:
	has_fixed_chair_part = false

# Fake door
func use_fixed_chair_part_for_door() -> void:
	if has_fixed_chair_part:
		has_fixed_chair_part = false
		door_fallen = true

# Inventory
func add_item(item_name: String) -> void:
	if not inventory.has(item_name):
		inventory.append(item_name)
	if item_name == SAFE_CODE_ITEM:
		has_door_code = true

func has_item(item_name: String) -> bool:
	return inventory.has(item_name)

func remove_item(item_name: String) -> void:
	inventory.erase(item_name)
	if item_name == SAFE_CODE_ITEM:
		has_door_code = false

func collect_safe_code() -> void:
	if door_fallen:
		add_item(SAFE_CODE_ITEM)

# Safe
func can_open_safe() -> bool:
	return has_item(SAFE_CODE_ITEM) and not safe_opened

func open_safe() -> void:
	if can_open_safe():
		safe_opened = true
		add_item("Stool")

# Find the root scene containing a cutscene or dialogue trigger.
func get_room_path_for_node(node: Node) -> String:
	if node == null or not node.is_inside_tree():
		return ""
	var scene_root: Node = node
	while scene_root.get_parent() != null and scene_root.get_parent() != get_tree().root:
		scene_root = scene_root.get_parent()
	return scene_root.scene_file_path

# Each trigger gets a stable ID unique to its scene and node name/path.
func get_event_id(node: Node) -> String:
	var scene_path: String = get_room_path_for_node(node)
	if scene_path.is_empty():
		return ""
	var scene_root: Node = node
	while scene_root.get_parent() != null and scene_root.get_parent() != get_tree().root:
		scene_root = scene_root.get_parent()
	return scene_path + ":" + str(scene_root.get_path_to(node))

func was_event_seen(event_id: String) -> bool:
	return not event_id.is_empty() and bool(seen_events.get(event_id, false))

func mark_event_seen(event_id: String) -> void:
	if not event_id.is_empty():
		seen_events[event_id] = true

# Save the last location inside each separate room.
func remember_room_position(scene_path: String, world_pos: Vector2, facing: Vector2) -> void:
	if scene_path.is_empty():
		return
	room_positions[scene_path] = {
		"x": world_pos.x,
		"y": world_pos.y,
		"facing_x": facing.x,
		"facing_y": facing.y
	}

func get_remembered_room_position(scene_path: String) -> Dictionary:
	var saved = room_positions.get(scene_path, {})
	if saved is Dictionary:
		return saved
	return {}

# New game / reset
func reset_story_state() -> void:
	has_vincent = false
	has_flower = false
	flower_taken = false
	has_house_key = false
	fountain_key_taken = false
	chair_broken = false
	has_broken_chair_part = false
	has_fixed_chair_part = false
	door_fallen = false
	has_door_code = false
	safe_opened = false
	inventory.clear()
	seen_events.clear()
	room_positions.clear()
	loading_from_save = false
	skip_room_restore_path = ""
	interaction_states.clear()
	
 

# ============================================================
# START HIDE CHASE
# ============================================================

func start_hide_chase(
	seconds: float = 15.0,
	failure_dialogue_path: String = "",
	failure_start_node: String = "start"
) -> void:

	# Cancel any previous chase timer.
	_hide_chase_id += 1

	var this_chase_id: int = _hide_chase_id


	hide_chase_active = false

	hide_chase_time_left = seconds


	_run_hide_chase(
		seconds,
		failure_dialogue_path,
		failure_start_node,
		this_chase_id
	)


# ============================================================
# RUN HIDE CHASE
# ============================================================

func _run_hide_chase(
	seconds: float,
	failure_dialogue_path: String,
	failure_start_node: String,
	chase_id: int
) -> void:

	# --------------------------------------------------------
	# WAIT FOR INTRO DIALOGUE TO CLOSE
	# --------------------------------------------------------

	while in_dialogue:

		await get_tree().process_frame


		if chase_id != _hide_chase_id:
			return


	# --------------------------------------------------------
	# START TIMER
	# --------------------------------------------------------

	hide_chase_active = true

	hide_chase_time_left = seconds


	# --------------------------------------------------------
	# COUNTDOWN
	# --------------------------------------------------------

	while hide_chase_time_left > 0.0:

		await get_tree().process_frame


		# A newer chase replaced this one.
		if chase_id != _hide_chase_id:
			return


		# Player successfully hid.
		if not hide_chase_active:
			return


		# Pause timer while the player is reading dialogue.
		if in_dialogue:
			continue


		hide_chase_time_left -= (
			get_process_delta_time()
		)


	# ========================================================
	# TIMER RAN OUT
	# ========================================================

	if chase_id != _hide_chase_id:
		return


	if not hide_chase_active:
		return


	hide_chase_active = false

	hide_chase_time_left = 0.0


	# ========================================================
	# PLAY FAILURE DIALOGUE
	# ========================================================

	_play_hide_failure_dialogue(
		failure_dialogue_path,
		failure_start_node
	)


# ============================================================
# FAILURE DIALOGUE
# ============================================================

func _play_hide_failure_dialogue(
	dialogue_path: String,
	start_node: String
) -> void:

	if dialogue_path.strip_edges().is_empty():

		push_warning(
			"Hide chase ended, but no failure dialogue was assigned."
		)

		return


	if not ResourceLoader.exists(
		dialogue_path
	):

		push_warning(
			"Hide chase failure dialogue doesn't exist: "
			+ dialogue_path
		)

		return


	var dialogue_resource = load(
		dialogue_path
	)


	if dialogue_resource == null:

		push_warning(
			"Couldn't load hide chase failure dialogue: "
			+ dialogue_path
		)

		return


	DialogueManager.show_dialogue_balloon(
		dialogue_resource,
		start_node
	)


# ============================================================
# SUCCESSFULLY HIDE
# ============================================================

func complete_hide_chase(
	completion_event: String = ""
) -> void:

	if not hide_chase_active:
		return


	hide_chase_active = false

	hide_chase_time_left = 0.0


	# Stop the existing timer.
	_hide_chase_id += 1


	if not completion_event.strip_edges().is_empty():

		mark_event_seen(
			completion_event.strip_edges()
		)


# ============================================================
# CANCEL HIDE CHASE
# ============================================================

func cancel_hide_chase() -> void:

	hide_chase_active = false

	hide_chase_time_left = 0.0

	_hide_chase_id += 1
func start_workroom_chase() -> void:
	start_hide_chase(
		15.0,
		"res://workroom_chase_death.dialogue",
		"start"
	)
	
func save_interaction_state(
	event_id: String,
	interaction_count: int,
	choice_counts: Dictionary,
	node_visibility: Dictionary = {}
) -> void:

	if event_id.is_empty():
		return

	interaction_states[event_id] = {
		"interaction_count": interaction_count,
		"choice_counts": choice_counts.duplicate(true),
		"node_visibility": node_visibility.duplicate(true)
	}


func get_interaction_state(
	event_id: String
) -> Dictionary:

	if event_id.is_empty():
		return {}

	var state = interaction_states.get(
		event_id,
		{}
	)

	if state is Dictionary:
		return state

	return {}
var _last_debug_state: String = ""

func _debug_freeze() -> void:
	var tree := get_tree()
	var scene := tree.current_scene

	if scene == null:
		return

	var plum := scene.find_child("Plum", true, false)

	var state: String = ""

	state += "\nRoom: " + scene.scene_file_path
	state += "\nTree paused: " + str(tree.paused)
	state += "\nIn dialogue: " + str(in_dialogue)
	state += "\nRoom transition: " + str(room_transition_active)
	state += "\nX held: " + str(Input.is_action_pressed("cancel"))

	if is_instance_valid(plum):
		state += "\nPause menu: " + str(plum.get("is_paused"))
		state += "\nPlayer input: " + str(plum.is_processing_input())
		state += "\nPlayer physics: " + str(plum.is_physics_processing())

	if state != _last_debug_state:
		_last_debug_state = state

		print("====================")
		print(state)
		print("====================")
