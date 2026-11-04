
extends Node


# ============================================================
# GENERAL GAME STATE
# ============================================================

var pov: String = "father"

var in_dialogue: bool = false

var has_vincent: bool = false

var total_playtime: float = 0.0

var in_game: bool = true


# ============================================================
# STORY / INVENTORY FLAGS
# ============================================================

var has_flower: bool = false
var flower_taken: bool = false

var has_house_key: bool = false
var fountain_key_taken: bool = false


# ============================================================
# BROKEN CHAIR
# ============================================================

var chair_broken: bool = false

var has_broken_chair_part: bool = false

var has_fixed_chair_part: bool = false


# ============================================================
# FAKE DOOR / CODE
# ============================================================

var door_fallen: bool = false

var has_door_code: bool = false

const SAFE_CODE_ITEM: String = "Code (247)"


# ============================================================
# SAFE
# ============================================================

var safe_opened: bool = false


func can_open_safe() -> bool:
	return has_item(SAFE_CODE_ITEM) and not safe_opened


func open_safe() -> void:
	if can_open_safe():
		safe_opened = true
		add_item("Stool")


# ============================================================
# INVENTORY
# ============================================================

var inventory: Array[String] = []


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


# ============================================================
# READY
# ============================================================

func _ready() -> void:
	if not DialogueManager.dialogue_started.is_connected(
		_on_dialogue_started
	):
		DialogueManager.dialogue_started.connect(
			_on_dialogue_started
		)

	if not DialogueManager.dialogue_ended.is_connected(
		_on_dialogue_ended
	):
		DialogueManager.dialogue_ended.connect(
			_on_dialogue_ended
		)


# ============================================================
# PROCESS
# ============================================================

func _process(delta: float) -> void:
	if in_game:
		total_playtime += delta


# ============================================================
# DIALOGUE STATE
# ============================================================

func _on_dialogue_started(
	_resource = null
) -> void:
	in_dialogue = true


func _on_dialogue_ended(
	_resource = null
) -> void:
	in_dialogue = false


# ============================================================
# PLAYTIME
# ============================================================

func get_playtime() -> int:
	return int(total_playtime)


# ============================================================
# HOUSE KEY
# ============================================================

func give_house_key() -> void:
	has_house_key = true
	fountain_key_taken = true


func has_item_house_key() -> bool:
	return has_house_key


func remove_house_key() -> void:
	has_house_key = false


# ============================================================
# BROKEN CHAIR
# ============================================================

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


# ============================================================
# FAKE DOOR
# ============================================================

func use_fixed_chair_part_for_door() -> void:
	if has_fixed_chair_part:
		has_fixed_chair_part = false
		door_fallen = true


# ============================================================
# NEW GAME / RESET
# ============================================================

func reset_story_state() -> void:
	has_vincent = false

	has_house_key = false
	fountain_key_taken = false

	chair_broken = false
	has_broken_chair_part = false
	has_fixed_chair_part = false

	door_fallen = false
	has_door_code = false

	safe_opened = false

	inventory.clear()
