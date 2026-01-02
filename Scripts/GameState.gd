extends Node

var pov := "father"
var in_dialogue := false



func _ready():
	DialogueManager.dialogue_started.connect(_on_dialogue_started)
	DialogueManager.dialogue_ended.connect(_on_dialogue_ended)

func _on_dialogue_started(_resource):
	in_dialogue = true

func _on_dialogue_ended(_resource):
	in_dialogue = false
