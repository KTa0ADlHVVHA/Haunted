extends StaticBody2D

@export var dialogue_resource: DialogueResource
@export var start_node := "start"

func interact(_player):
	if GameState.in_dialogue:
		return

	DialogueManager.show_dialogue_balloon(
		dialogue_resource,
		start_node
	)
