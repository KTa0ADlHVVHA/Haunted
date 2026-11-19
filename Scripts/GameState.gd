
extends Node

# General game state
var pov: String = "father"
var in_dialogue: bool = false
var has_vincent: bool = false
var total_playtime: float = 0.0
var in_game: bool = true

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
	in_dialogue = true

func _on_dialogue_ended(_resource = null) -> void:
	in_dialogue = false

func _on_scene_changed(_new_scene: Node) -> void:
	# Runs after the incoming scene has finished _ready().
	loading_from_save = false
	skip_room_restore_path = ""

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
