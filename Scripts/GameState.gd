extends Node

# ---------------- EXISTING VARIABLES ----------------
var pov := "father"
var in_dialogue := false

# ---------------- PLAYTIME TRACKING ----------------
var total_playtime: float = 0.0  # in seconds
var in_game: bool = true         # set false when in menus or paused

func _process(delta):
	if in_game:
		total_playtime += delta

func get_playtime() -> int:
	return int(total_playtime)  # returns total seconds played


# ---------------- DIALOGUE CONNECTIONS ----------------
func _ready():
	DialogueManager.dialogue_started.connect(_on_dialogue_started)
	DialogueManager.dialogue_ended.connect(_on_dialogue_ended)

func _on_dialogue_started(_resource):
	in_dialogue = true

func _on_dialogue_ended(_resource):
	in_dialogue = false
