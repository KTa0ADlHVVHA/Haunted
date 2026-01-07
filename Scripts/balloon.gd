extends CanvasLayer
## Dialogue balloon for Dialogue Manager (portrait + screen support)

@onready var portrait_sprite: Sprite2D = $Potrait
@onready var screen_sprite: Sprite2D = $ScreenSprite

@export var dialogue_resource: DialogueResource
@export var start_from_title: String = ""
@export var auto_start: bool = false
@export var next_action: StringName = &"interact"
@export var skip_action: StringName = &"ui_cancel"

@onready var audio_stream_player: AudioStreamPlayer = %AudioStreamPlayer
@onready var balloon: Control = %Balloon
@onready var character_label: RichTextLabel = $CharacterLabel
@onready var dialogue_label: DialogueLabel = %DialogueLabel
@onready var responses_menu: DialogueResponsesMenu = %ResponsesMenu
@onready var progress: Polygon2D = %Progress

var temporary_game_states: Array = []
var is_waiting_for_input := false
var will_hide_balloon := false
var locals: Dictionary = {}
var _locale := TranslationServer.get_locale()

var mutation_cooldown := Timer.new()

var dialogue_line: DialogueLine:
	set(value):
		if value:
			dialogue_line = value
			apply_dialogue_line()
		else:
			if owner == null:
				queue_free()
			else:
				hide()
	get:
		return dialogue_line


func _ready() -> void:
	balloon.hide()
	screen_sprite.hide()

	Engine.get_singleton("DialogueManager").mutated.connect(_on_mutated)

	if responses_menu.next_action.is_empty():
		responses_menu.next_action = next_action

	mutation_cooldown.timeout.connect(_on_mutation_cooldown_timeout)
	add_child(mutation_cooldown)

	if auto_start:
		start()


func _process(_delta: float) -> void:
	if is_instance_valid(dialogue_line):
		progress.visible = (
			not dialogue_label.is_typing
			and dialogue_line.responses.size() == 0
			and not dialogue_line.has_tag("voice")
		)


func _unhandled_input(_event: InputEvent) -> void:
	get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and _locale != TranslationServer.get_locale():
		_locale = TranslationServer.get_locale()
		var ratio := dialogue_label.visible_ratio
		dialogue_line = await dialogue_resource.get_next_dialogue_line(dialogue_line.id)
		if ratio < 1:
			dialogue_label.skip_typing()


## START DIALOGUE
func start(with_dialogue_resource: DialogueResource = null, title: String = "", extra_game_states: Array = []) -> void:
	temporary_game_states = [self] + extra_game_states
	is_waiting_for_input = false

	if with_dialogue_resource:
		dialogue_resource = with_dialogue_resource
	if not title.is_empty():
		start_from_title = title

	dialogue_line = await dialogue_resource.get_next_dialogue_line(start_from_title, temporary_game_states)
	show()


## APPLY LINE
func apply_dialogue_line() -> void:
	mutation_cooldown.stop()

	progress.hide()
	is_waiting_for_input = false
	balloon.focus_mode = Control.FOCUS_ALL
	balloon.grab_focus()

	var text_with_tags := dialogue_line.text
	var parsed := _extract_emotion(text_with_tags)

	character_label.visible = not dialogue_line.character.is_empty()
	character_label.text = tr(dialogue_line.character, "dialogue")

	# Portrait emotion
	_update_portrait(dialogue_line.character, parsed.emotion)

	# ✅ SCREEN TAG HANDLING
	var screen_tag_regex := RegEx.new()
	screen_tag_regex.compile("\\[screen=([^\\]]+)\\]")
	var matches := screen_tag_regex.search_all(text_with_tags)
	for m in matches:
		_set_screen_sprite(m.get_string(1))

	dialogue_label.hide()
	dialogue_label.dialogue_line = dialogue_line

	# 🔹 Replace [time] token with current system time
	var final_text: String = parsed.text.replace("[time]", get_system_time())
	dialogue_label.dialogue_line.text = final_text

	responses_menu.hide()
	responses_menu.responses = dialogue_line.responses

	balloon.show()
	will_hide_balloon = false

	dialogue_label.show()
	if not parsed.text.is_empty():
		dialogue_label.type_out()
		await dialogue_label.finished_typing

	if dialogue_line.has_tag("voice"):
		audio_stream_player.stream = load(dialogue_line.get_tag_value("voice"))
		audio_stream_player.play()
		await audio_stream_player.finished
		next(dialogue_line.next_id)
	elif dialogue_line.responses.size() > 0:
		balloon.focus_mode = Control.FOCUS_NONE
		responses_menu.show()
	elif dialogue_line.time != "":
		var t = parsed.text.length() * 0.02 if dialogue_line.time == "auto" else dialogue_line.time.to_float()
		await get_tree().create_timer(t).timeout
		next(dialogue_line.next_id)
	else:
		is_waiting_for_input = true
		balloon.grab_focus()


func next(next_id: String) -> void:
	dialogue_line = await dialogue_resource.get_next_dialogue_line(next_id, temporary_game_states)


# ---------------- MUTATIONS ----------------
func _on_mutated(_mutation: Dictionary) -> void:
	if not _mutation.is_inline:
		is_waiting_for_input = false
		will_hide_balloon = true
		mutation_cooldown.start(0.1)


func _on_mutation_cooldown_timeout() -> void:
	if will_hide_balloon:
		will_hide_balloon = false
		balloon.hide()


# ---------------- INPUT ----------------
func _on_balloon_gui_input(event: InputEvent) -> void:
	# Skip typing if dialogue is typing
	if dialogue_label.is_typing:
		if event.is_action_pressed(skip_action):
			dialogue_label.skip_typing()
			return

	# Toggle hiding/showing the entire dialogue UI, always
	if event.is_action_pressed("hide"):
		var currently_visible := dialogue_label.visible
		var new_visible := not currently_visible

		# Main dialogue UI
		dialogue_label.visible = new_visible
		character_label.visible = new_visible
		portrait_sprite.visible = new_visible
		$TextureRect.visible = new_visible
		$TextureRect2.visible = new_visible
		# Responses menu
		$Control.visible = new_visible

		# Optional: grab focus back when showing
		if new_visible:
			balloon.grab_focus()
		return

	# Only allow next if waiting for input and no responses (regular advancement)
	if not is_waiting_for_input or dialogue_line.responses.size() > 0:
		return

	if event.is_action_pressed(next_action):
		next(dialogue_line.next_id)


func _on_responses_menu_response_selected(response: DialogueResponse) -> void:
	next(response.next_id)


# ---------------- HELPERS ----------------
func _extract_emotion(text: String) -> Dictionary:
	var emotion := "neutral"
	var clean_text := text

	var open := text.rfind("(")
	var close := text.rfind(")")

	if open != -1 and close != -1 and close > open:
		emotion = text.substr(open + 1, close - open - 1).strip_edges()
		clean_text = text.substr(0, open).strip_edges()

	return {
		"text": clean_text,
		"emotion": emotion.to_lower()
	}


func _update_portrait(character: String, emotion: String) -> void:
	if character.is_empty():
		portrait_sprite.hide()
		return

	var char := character.capitalize()
	var emo := emotion.capitalize()

	var base := "res://Art/Expressions/%s/" % char
	var path := "%s%s_%s.png" % [base, char, emo]
	var fallback := "%s%s_Neutral.png" % [base, char]

	if ResourceLoader.exists(path):
		portrait_sprite.texture = load(path)
	elif ResourceLoader.exists(fallback):
		portrait_sprite.texture = load(fallback)
	else:
		portrait_sprite.texture = null

	portrait_sprite.show()


func _set_screen_sprite(name: String) -> void:
	if name.is_empty() or name == "none":
		screen_sprite.hide()
		return

	var path := "res://Art/Screens/%s.png" % name.strip_edges()

	if ResourceLoader.exists(path):
		screen_sprite.texture = load(path)
		screen_sprite.show()
	else:
		push_warning("Missing screen sprite: " + path)
		screen_sprite.hide()


# ---------------- DIALOGUE FUNCTION (TIME) ----------------
func get_system_time() -> String:
	var now := Time.get_datetime_dict_from_system()
	return "%02d:%02d" % [now.hour, now.minute]
