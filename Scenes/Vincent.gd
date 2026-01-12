extends StaticBody2D

@export var dialogue_resource: DialogueResource
@export var start_node := "start"

@onready var sprite: Sprite2D = $Sprite2D

# Set this to your Player node in the Inspector
@export var player_path: NodePath
var player: Node2D

@export var max_distance := 128.0  # optional: only face player if nearby
@export var horizontal_bias := 1.5 # how much horizontal distance counts toward horizontal facing

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS  # always process

	if player_path != NodePath():
		player = get_node(player_path)


func _process(_delta):
	if player == null:
		return
	if max_distance > 0 and global_position.distance_to(player.global_position) > max_distance:
		return

	face_player_based_on_position()


func face_player_based_on_position():
	var dir = player.global_position - global_position
	var abs_x = abs(dir.x)
	var abs_y = abs(dir.y)

	# Apply horizontal bias: horizontal must be significantly larger to override vertical
	if abs_x > abs_y * horizontal_bias:
		# Horizontal dominates
		if dir.x > 0:
			sprite.frame = 4   # right
		else:
			sprite.frame = 8   # left
	else:
		# Vertical dominates
		if dir.y > 0:
			sprite.frame = 0   # down
		else:
			sprite.frame = 12  # up

 

func interact(_player):
	if GameState.in_dialogue:
		return

	DialogueManager.show_dialogue_balloon(
		dialogue_resource,
		start_node
	)
