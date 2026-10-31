extends CanvasLayer

## Dialogue balloon for Dialogue Manager
##
## Controls:
## Z / interact = advance
## Enter        = advance
## X / cancel  = hold to fast-forward, advance when finished
## H / hide    = hide/show dialogue UI
##
## Includes protection against rapid input / overlapping dialogue lines.


# ============================================================
# NODES
# ============================================================

@onready var portrait_sprite: Sprite2D = $Potrait
@onready var screen_sprite: Sprite2D = $ScreenSprite
@onready var vbox_container: VBoxContainer = $VBoxContainer

@onready var audio_stream_player: AudioStreamPlayer = %AudioStreamPlayer
@onready var balloon: Control = %Balloon
@onready var character_label: RichTextLabel = $CharacterLabel
@onready var dialogue_label: DialogueLabel = %DialogueLabel
@onready var responses_menu: DialogueResponsesMenu = %ResponsesMenu
@onready var progress: Polygon2D = %Progress
@onready var paint_node: Node = $Paint


# ============================================================
# SETTINGS
# ============================================================

@export var dialogue_resource: DialogueResource
@export var start_from_title: String = ""
@export var auto_start: bool = false

# Z
@export var next_action: StringName = &"interact"

# X
const FAST_FORWARD_ACTION: StringName = &"cancel"

# H
const HIDE_ACTION: StringName = &"hide"

# Enter
const ACCEPT_ACTION: StringName = &"ui_accept"

# Obvious speed increase while testing.
@export var fast_forward_multiplier: float = 10.0


# ============================================================
# DIALOGUE STATE
# ============================================================

var temporary_game_states: Array = []

var is_waiting_for_input: bool = false
var transition_in_progress: bool = false

var will_hide_balloon: bool = false

var locals: Dictionary = {}

var _locale := TranslationServer.get_locale()

var mutation_cooldown := Timer.new()


# ============================================================
# UI STATE
# ============================================================

var screen_only_locked: bool = false

# This variable is now the SINGLE source of truth for H.
var manual_hide_active: bool = false

var hide_disabled: bool = false


# ============================================================
# TYPEWRITER
# ============================================================

var normal_seconds_per_step: float = 0.02
var normal_seconds_per_pause_step: float = 0.3


# ============================================================
# RACE PROTECTION
# ============================================================

# Incremented whenever the current line changes.
#
# Async work belonging to an older line can detect that it
# is obsolete and stop touching the UI.
var line_revision: int = 0


# ============================================================
# CURRENT LINE
# ============================================================

var dialogue_line: DialogueLine:
	set(value):

		# Invalidate any old async apply_dialogue_line().
		line_revision += 1

		# A requested transition has finished.
		transition_in_progress = false

		_restore_normal_text_speed()


		if value:

			dialogue_line = value

			var my_revision := line_revision

			apply_dialogue_line(
				my_revision
			)

		else:

			dialogue_line = null

			is_waiting_for_input = false
			transition_in_progress = false

			manual_hide_active = false
			hide_disabled = false


			if screen_only_locked:

				_set_screen_only_mode(false)

				screen_only_locked = false


			_restore_normal_text_speed()


			if owner == null:

				queue_free()

			else:

				hide()


	get:

		return dialogue_line


# ============================================================
# READY
# ============================================================

func _ready() -> void:

	balloon.hide()
	screen_sprite.hide()
	paint_node.hide()
	vbox_container.hide()


	# --------------------------------------------------------
	# SAVE NORMAL TYPEWRITER SPEED
	# --------------------------------------------------------

	normal_seconds_per_step = (
		dialogue_label.seconds_per_step
	)

	normal_seconds_per_pause_step = (
		dialogue_label.seconds_per_pause_step
	)


	# --------------------------------------------------------
	# DIALOGUE MANAGER
	# --------------------------------------------------------

	var dm := Engine.get_singleton(
		"DialogueManager"
	)


	if dm.has_signal("mutated"):

		dm.mutated.connect(
			_on_mutated
		)


	if dm.has_signal("action"):

		dm.action.connect(
			_on_dialogue_action
		)


	# --------------------------------------------------------
	# RESPONSES
	# --------------------------------------------------------

	if responses_menu.next_action.is_empty():

		responses_menu.next_action = next_action


	# --------------------------------------------------------
	# MUTATION TIMER
	# --------------------------------------------------------

	mutation_cooldown.timeout.connect(
		_on_mutation_cooldown_timeout
	)

	add_child(
		mutation_cooldown
	)


	# --------------------------------------------------------
	# AUTO START
	# --------------------------------------------------------

	if auto_start:

		start()


# ============================================================
# PROCESS
# ============================================================

func _process(_delta: float) -> void:

	if dialogue_line == null:

		progress.hide()

		_restore_normal_text_speed()

		return


	# --------------------------------------------------------
	# CONTINUE INDICATOR
	# --------------------------------------------------------

	progress.visible = (
		not manual_hide_active
		and not screen_only_locked
		and is_waiting_for_input
		and not dialogue_label.is_typing
		and dialogue_line.responses.size() == 0
		and not dialogue_line.has_tag("voice")
	)


	# --------------------------------------------------------
	# FAST FORWARD
	# --------------------------------------------------------

	_update_fast_forward()


# ============================================================
# INPUT
# ============================================================

func _input(event: InputEvent) -> void:

	# Ignore keyboard auto-repeat.
	#
	# Holding H should count as ONE press, not hundreds.
	if event is InputEventKey:

		var key_event := event as InputEventKey

		if key_event.echo:

			return


	# ========================================================
	# H — HIDE / SHOW
	# ========================================================

	if event.is_action_pressed(HIDE_ACTION):

		_toggle_manual_hide()

		get_viewport().set_input_as_handled()

		return


	# ========================================================
	# X — FAST FORWARD / ADVANCE
	# ========================================================

	if event.is_action_pressed(FAST_FORWARD_ACTION):

		if manual_hide_active:

			get_viewport().set_input_as_handled()

			return


		if dialogue_line == null:

			return


		# Never use X to choose a response.
		if dialogue_line.responses.size() > 0:

			get_viewport().set_input_as_handled()

			return


		# If typing, holding X speeds it up.
		if dialogue_label.is_typing:

			get_viewport().set_input_as_handled()

			return


		# If already finished, X advances.
		_request_advance()


		get_viewport().set_input_as_handled()

		return


	# ========================================================
	# Z / ENTER — NORMAL ADVANCE
	# ========================================================

	if (
		event.is_action_pressed(next_action)
		or event.is_action_pressed(ACCEPT_ACTION)
	):

		if manual_hide_active:

			return


		if dialogue_line == null:

			return


		# Let ResponsesMenu own Z / Enter when choices exist.
		if dialogue_line.responses.size() > 0:

			return


		# Don't advance normal dialogue while text is typing.
		if dialogue_label.is_typing:

			get_viewport().set_input_as_handled()

			return


		_request_advance()


		get_viewport().set_input_as_handled()

		return


# ============================================================
# HIDE / SHOW
# ============================================================

func _toggle_manual_hide() -> void:

	# These lines intentionally prevent H.
	if screen_only_locked:

		return


	if hide_disabled:

		return


	manual_hide_active = not manual_hide_active


	_sync_dialogue_visibility()


# ============================================================
# AUTHORITATIVE UI VISIBILITY
# ============================================================

func _sync_dialogue_visibility() -> void:

	# ========================================================
	# SCREEN-ONLY MODE
	# ========================================================

	if screen_only_locked:

		balloon.hide()
		dialogue_label.hide()
		character_label.hide()
		portrait_sprite.hide()
		vbox_container.hide()
		responses_menu.hide()
		progress.hide()

		$TextureRect.hide()
		$TextureRect2.hide()
		$Control.hide()

		paint_node.hide()

		screen_sprite.show()

		return


	# ========================================================
	# HIDDEN BY PLAYER
	# ========================================================

	if manual_hide_active:

		dialogue_label.hide()
		character_label.hide()
		portrait_sprite.hide()
		vbox_container.hide()
		responses_menu.hide()
		progress.hide()

		$TextureRect.hide()
		$TextureRect2.hide()
		$Control.hide()

		return


	# ========================================================
	# NORMAL VISIBLE UI
	# ========================================================

	balloon.show()
	vbox_container.show()
	dialogue_label.show()

	$TextureRect.show()
	$TextureRect2.show()
	$Control.show()


	# --------------------------------------------------------
	# CHARACTER NAME
	# --------------------------------------------------------

	if (
		dialogue_line != null
		and not dialogue_line.character.is_empty()
	):

		character_label.show()

	else:

		character_label.hide()


	# --------------------------------------------------------
	# PORTRAIT
	# --------------------------------------------------------

	if (
		dialogue_line != null
		and not dialogue_line.character.is_empty()
		and portrait_sprite.texture != null
	):

		portrait_sprite.show()

	else:

		portrait_sprite.hide()


	# --------------------------------------------------------
	# RESPONSES
	# --------------------------------------------------------

	if (
		dialogue_line != null
		and dialogue_line.responses.size() > 0
		and not dialogue_label.is_typing
	):

		responses_menu.show()

	else:

		responses_menu.hide()


	# --------------------------------------------------------
	# CONTINUE ICON
	# --------------------------------------------------------

	progress.visible = (
		dialogue_line != null
		and is_waiting_for_input
		and not dialogue_label.is_typing
		and dialogue_line.responses.size() == 0
		and not dialogue_line.has_tag("voice")
	)


# ============================================================
# FAST FORWARD
# ============================================================

func _update_fast_forward() -> void:

	if dialogue_line == null:

		_restore_normal_text_speed()

		return


	if manual_hide_active:

		_restore_normal_text_speed()

		return


	var holding_x := Input.is_action_pressed(
		FAST_FORWARD_ACTION
	)


	# --------------------------------------------------------
	# X NOT HELD
	# --------------------------------------------------------

	if not holding_x:

		_restore_normal_text_speed()

		return


	# --------------------------------------------------------
	# X HELD DURING TYPEWRITER
	# --------------------------------------------------------

	if dialogue_label.is_typing:

		var multiplier := maxf(
			fast_forward_multiplier,
			1.0
		)


		dialogue_label.seconds_per_step = (
			normal_seconds_per_step
			/ multiplier
		)


		dialogue_label.seconds_per_pause_step = (
			normal_seconds_per_pause_step
			/ multiplier
		)


		return


	# --------------------------------------------------------
	# X HELD AFTER TEXT FINISHED
	# --------------------------------------------------------

	_restore_normal_text_speed()


	if is_waiting_for_input:

		_request_advance()


func _restore_normal_text_speed() -> void:

	if not is_instance_valid(dialogue_label):

		return


	dialogue_label.seconds_per_step = (
		normal_seconds_per_step
	)


	dialogue_label.seconds_per_pause_step = (
		normal_seconds_per_pause_step
	)


# ============================================================
# REQUEST ADVANCE
# ============================================================

func _request_advance() -> void:

	if transition_in_progress:

		return


	if dialogue_line == null:

		return


	if not is_waiting_for_input:

		return


	if dialogue_label.is_typing:

		return


	if dialogue_line.responses.size() > 0:

		return


	if dialogue_line.has_tag("voice"):

		return


	_advance_to(
		dialogue_line.next_id
	)


# ============================================================
# ADVANCE TO ANOTHER LINE
# ============================================================

func _advance_to(
	next_id: String
) -> void:

	# This is the ONLY function that owns this lock.
	if transition_in_progress:

		return


	transition_in_progress = true

	is_waiting_for_input = false


	var source_revision := line_revision


	var new_line := await dialogue_resource.get_next_dialogue_line(
		next_id,
		temporary_game_states
	)


	# Something else replaced the dialogue while we waited.
	if source_revision != line_revision:

		transition_in_progress = false

		return


	# Setter resets transition_in_progress and creates
	# a new revision.
	dialogue_line = new_line


# ============================================================
# PUBLIC NEXT
# ============================================================

# Keep this method because your existing scene/plugin may call it.
func next(
	next_id: String
) -> void:

	_advance_to(
		next_id
	)


# ============================================================
# START DIALOGUE
# ============================================================

func start(
	with_dialogue_resource: DialogueResource = null,
	title: String = "",
	extra_game_states: Array = []
) -> void:

	temporary_game_states = (
		[self]
		+ extra_game_states
	)


	is_waiting_for_input = false
	transition_in_progress = false


	if with_dialogue_resource:

		dialogue_resource = with_dialogue_resource


	if not title.is_empty():

		start_from_title = title


	var first_line := await dialogue_resource.get_next_dialogue_line(
		start_from_title,
		temporary_game_states
	)


	dialogue_line = first_line


	show()


# ============================================================
# APPLY LINE
# ============================================================

func apply_dialogue_line(
	my_revision: int
) -> void:

	var line := dialogue_line


	if line == null:

		return


	# An old mutation timer must not suddenly hide this
	# brand-new line.
	mutation_cooldown.stop()

	will_hide_balloon = false


	progress.hide()

	is_waiting_for_input = false


	balloon.focus_mode = Control.FOCUS_ALL


	# --------------------------------------------------------
	# PARSE TEXT
	# --------------------------------------------------------

	var text_with_tags := line.text


	var parsed := _extract_emotion(
		text_with_tags
	)


	hide_disabled = parsed.hide_disabled


	# --------------------------------------------------------
	# SCREEN-ONLY
	# --------------------------------------------------------

	if parsed.hide:

		_set_screen_only_mode(
			true
		)


	# --------------------------------------------------------
	# PAINT
	# --------------------------------------------------------

	if "[show paint]" in parsed.text:

		paint_node.show()


		parsed.text = parsed.text.replace(
			"[show paint]",
			""
		)


	# --------------------------------------------------------
	# CHARACTER
	# --------------------------------------------------------

	character_label.text = tr(
		line.character,
		"dialogue"
	)


	# --------------------------------------------------------
	# PORTRAIT
	# --------------------------------------------------------

	_update_portrait(
		line.character,
		parsed.emotion
	)


	# --------------------------------------------------------
	# SCREEN TAG
	# --------------------------------------------------------

	var screen_tag_regex := RegEx.new()


	screen_tag_regex.compile(
		"\\[screen=([^\\]]+)\\]"
	)


	for match_result in screen_tag_regex.search_all(
		text_with_tags
	):

		_set_screen_sprite(
			match_result.get_string(1)
		)


	# Remove screen tags from visible dialogue.
	parsed.text = screen_tag_regex.sub(
		parsed.text,
		"",
		true
	)


	# --------------------------------------------------------
	# DIALOGUE LABEL
	# --------------------------------------------------------

	dialogue_label.hide()


	dialogue_label.dialogue_line = line


	var final_text: String = parsed.text.replace(
		"[time]",
		get_system_time()
	)


	final_text = _handle_scene_tag(
		final_text
	)


	dialogue_label.dialogue_line.text = final_text


	# --------------------------------------------------------
	# RESPONSES
	# --------------------------------------------------------

	responses_menu.hide()

	responses_menu.responses = line.responses


	# --------------------------------------------------------
	# APPLY CURRENT H STATE
	# --------------------------------------------------------

	_sync_dialogue_visibility()


	# --------------------------------------------------------
	# TYPEWRITER
	# --------------------------------------------------------

	if not parsed.text.is_empty():

		dialogue_label.type_out()


		await dialogue_label.finished_typing


		# If a newer line started while we waited,
		# this old coroutine dies here.
		if my_revision != line_revision:

			return


		if dialogue_line != line:

			return


	_restore_normal_text_speed()


	# Check once more before any post-line behaviour.
	if my_revision != line_revision:

		return


	if dialogue_line != line:

		return


	# Re-sync H state after typing ends.
	_sync_dialogue_visibility()


	# ========================================================
	# VOICE
	# ========================================================

	if line.has_tag("voice"):

		audio_stream_player.stream = load(
			line.get_tag_value("voice")
		)


		audio_stream_player.play()


		await audio_stream_player.finished


		if my_revision != line_revision:

			return


		if dialogue_line != line:

			return


		_advance_to(
			line.next_id
		)


	# ========================================================
	# RESPONSES
	# ========================================================

	elif line.responses.size() > 0:

		balloon.focus_mode = Control.FOCUS_NONE


		_sync_dialogue_visibility()


	# ========================================================
	# TIMED DIALOGUE
	# ========================================================

	elif line.time != "":

		var wait_time: float = (
			parsed.text.length() * 0.02
			if line.time == "auto"
			else line.time.to_float()
		)


		await get_tree().create_timer(
			wait_time
		).timeout


		if my_revision != line_revision:

			return


		if dialogue_line != line:

			return


		_advance_to(
			line.next_id
		)


	# ========================================================
	# NORMAL WAITING LINE
	# ========================================================

	else:

		is_waiting_for_input = true


		_sync_dialogue_visibility()


		if (
			not manual_hide_active
			and not screen_only_locked
		):

			balloon.grab_focus()


		# Keep holding X through multiple lines.
		if Input.is_action_pressed(
			FAST_FORWARD_ACTION
		):

			_request_advance()


# ============================================================
# RESPONSE SELECTED
# ============================================================

func _on_responses_menu_response_selected(
	response: DialogueResponse
) -> void:

	if transition_in_progress:

		return


	_advance_to(
		response.next_id
	)


# ============================================================
# BALLOON GUI INPUT
# ============================================================

func _on_balloon_gui_input(
	_event: InputEvent
) -> void:

	# INTENTIONALLY EMPTY.
	#
	# Your scene already has this signal connected, so we leave
	# the method here.
	#
	# H / Z / X / Enter are handled ONLY in _input().
	#
	# This prevents a single keypress from being processed
	# twice.
	pass


# ============================================================
# TRANSLATION
# ============================================================

func _notification(
	what: int
) -> void:

	if (
		what == NOTIFICATION_TRANSLATION_CHANGED
		and _locale != TranslationServer.get_locale()
	):

		_locale = TranslationServer.get_locale()


		if dialogue_line == null:

			return


		var ratio := dialogue_label.visible_ratio


		var translated_line := await dialogue_resource.get_next_dialogue_line(
			dialogue_line.id
		)


		dialogue_line = translated_line


		if (
			dialogue_line != null
			and ratio < 1
		):

			dialogue_label.skip_typing()


# ============================================================
# DIALOGUE ACTION
# ============================================================

func _on_dialogue_action(
	action_name: String,
	_params: Dictionary
) -> void:

	if action_name == "load_paint":

		balloon.hide()


		await get_tree().process_frame


		get_tree().change_scene_to_file(
			"res://paint.tscn"
		)


# ============================================================
# MUTATIONS
# ============================================================

func _on_mutated(
	_mutation: Dictionary
) -> void:

	if not _mutation.is_inline:

		is_waiting_for_input = false

		will_hide_balloon = true


		mutation_cooldown.start(
			0.1
		)


func _on_mutation_cooldown_timeout() -> void:

	if not will_hide_balloon:

		return


	will_hide_balloon = false


	# Don't override the player's H state.
	if manual_hide_active:

		return


	balloon.hide()
	vbox_container.hide()


# ============================================================
# SCREEN-ONLY MODE
# ============================================================

func _set_screen_only_mode(
	enabled: bool
) -> void:

	screen_only_locked = enabled


	if enabled:

		balloon.hide()
		dialogue_label.hide()
		character_label.hide()
		portrait_sprite.hide()
		vbox_container.hide()
		responses_menu.hide()
		progress.hide()

		$TextureRect.hide()
		$TextureRect2.hide()
		$Control.hide()

		paint_node.hide()

		screen_sprite.show()


	else:

		screen_sprite.hide()

		_sync_dialogue_visibility()


# ============================================================
# EMOTION PARSING
# ============================================================

func _extract_emotion(
	text: String
) -> Dictionary:

	var emotion := "neutral"

	var clean_text := text

	var hide_screen_only := false

	var disable_hide := false


	# --------------------------------------------------------
	# SCREEN-ONLY
	# --------------------------------------------------------

	if "(hide)" in clean_text:

		hide_screen_only = true


		clean_text = clean_text.replace(
			"(hide)",
			""
		).strip_edges()


	# --------------------------------------------------------
	# NO HIDE
	# --------------------------------------------------------

	if "(nohide)" in clean_text:

		disable_hide = true


		clean_text = clean_text.replace(
			"(nohide)",
			""
		).strip_edges()


	# --------------------------------------------------------
	# EMOTION
	# --------------------------------------------------------

	var open := clean_text.rfind("(")

	var close := clean_text.rfind(")")


	if (
		open != -1
		and close != -1
		and close > open
	):

		emotion = clean_text.substr(
			open + 1,
			close - open - 1
		).strip_edges()


		clean_text = clean_text.substr(
			0,
			open
		).strip_edges()


	return {
		"text": clean_text,
		"emotion": emotion.to_lower(),
		"hide": hide_screen_only,
		"hide_disabled": disable_hide
	}


# ============================================================
# PORTRAIT
# ============================================================

func _update_portrait(
	character: String,
	emotion: String
) -> void:

	if character.is_empty():

		portrait_sprite.texture = null
		portrait_sprite.hide()

		return


	var char := character.capitalize()

	var emo := emotion.capitalize()


	var base := (
		"res://Art/Expressions/%s/"
		% char
	)


	var path := (
		"%s%s_%s.png"
		% [
			base,
			char,
			emo
		]
	)


	var fallback := (
		"%s%s_Neutral.png"
		% [
			base,
			char
		]
	)


	if ResourceLoader.exists(path):

		portrait_sprite.texture = load(
			path
		)


	elif ResourceLoader.exists(fallback):

		portrait_sprite.texture = load(
			fallback
		)


	else:

		portrait_sprite.texture = null


# ============================================================
# SCREEN SPRITE
# ============================================================

func _set_screen_sprite(
	name: String
) -> void:

	if (
		name.is_empty()
		or name == "none"
	):

		screen_sprite.hide()

		return


	var path := (
		"res://Art/Screens/%s.png"
		% name.strip_edges()
	)


	if ResourceLoader.exists(path):

		screen_sprite.texture = load(
			path
		)


		screen_sprite.show()


	else:

		push_warning(
			"Missing screen sprite: "
			+ path
		)


		screen_sprite.hide()


# ============================================================
# TIME
# ============================================================

func get_system_time() -> String:

	var now := Time.get_datetime_dict_from_system()


	return "%02d:%02d" % [
		now.hour,
		now.minute
	]


# ============================================================
# SAFE SCENE CHANGE
# ============================================================

func _change_scene_safe(
	path: String
) -> void:

	balloon.hide()
	screen_sprite.hide()


	await get_tree().process_frame


	get_tree().change_scene_to_file(
		path
	)


# ============================================================
# SCENE TAG
# ============================================================

func _handle_scene_tag(
	text: String
) -> String:

	var scene_tag_regex := RegEx.new()


	scene_tag_regex.compile(
		"\\[scene=([^\\]]+)\\]"
	)


	for match_result in scene_tag_regex.search_all(
		text
	):

		var scene_name := (
			match_result.get_string(1).strip_edges()
		)


		var path := (
			"res://Scenes/%s.tscn"
			% scene_name
		)


		if ResourceLoader.exists(path):

			call_deferred(
				"_change_scene_safe",
				path
			)


		else:

			push_warning(
				"Missing scene: "
				+ path
			)


	return scene_tag_regex.sub(
		text,
		"",
		true
	)
