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

# Player currently possesses the house key.
var has_house_key: bool = false


# The key has already been removed from the fountain.
#
# This is separate from has_house_key because later we may
# want situations where an item is removed from somewhere
# without necessarily still being in Plum's possession.
var fountain_key_taken: bool = false


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
# NEW GAME / RESET
# ============================================================

func reset_story_state() -> void:
	has_vincent = false

	has_house_key = false
	fountain_key_taken = false
