extends CanvasLayer


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
# DIALOGUE SETTINGS
# ============================================================

@export var dialogue_resource: DialogueResource

@export var start_from_title: String = ""

@export var auto_start: bool = false

@export var next_action: StringName = &"interact"


# X / Cancel
const FAST_FORWARD_ACTION: StringName = &"cancel"

const FAST_FORWARD_MULTIPLIER: float = 10.0


# ============================================================
# STATE
# ============================================================

var temporary_game_states: Array = []

var is_waiting_for_input: bool = false

var will_hide_balloon: bool = false

var locals: Dictionary = {}

var _locale: String = TranslationServer.get_locale()


# ============================================================
# VISIBILITY STATE
# ============================================================

var screen_only_locked: bool = false

var manual_hide_active: bool = false

var hide_disabled: bool = false


# ============================================================
# SAFE LINE TRANSITIONS
# ============================================================

var line_revision: int = 0

var transition_in_progress: bool = false


# ============================================================
# SCENE CHANGING
# ============================================================

# When the current dialogue line contains:
#
# [scene=Outside]
#
# the scene isn't changed immediately.
#
# Instead, its path is saved here and the scene changes
# when the player ADVANCES from that dialogue line.
var pending_scene_path: String = ""


# ============================================================
# TYPEWRITER
# ============================================================

var normal_seconds_per_step: float = 0.0

var normal_seconds_per_pause_step: float = 0.0


# ============================================================
# MUTATION TIMER
# ============================================================

var mutation_cooldown: Timer = Timer.new()


# ============================================================
# CURRENT DIALOGUE LINE
# ============================================================

var dialogue_line: DialogueLine:
	set(value):

		line_revision += 1

		dialogue_line = value

		transition_in_progress = false

		_restore_typing_speed()


		if value != null:

			apply_dialogue_line(
				line_revision
			)


		else:

			is_waiting_for_input = false

			pending_scene_path = ""

			manual_hide_active = false

			hide_disabled = false


			if screen_only_locked:

				_set_screen_only_mode(
					false
				)


			screen_only_locked = false


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

	progress.hide()


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
	# DIALOGUE MANAGER SIGNALS
	# --------------------------------------------------------

	var dm := Engine.get_singleton(
		"DialogueManager"
	)


	if dm != null:

		if dm.has_signal(
			"mutated"
		):

			dm.mutated.connect(
				_on_mutated
			)


		if dm.has_signal(
			"action"
		):

			dm.action.connect(
				_on_dialogue_action
			)


	# --------------------------------------------------------
	# RESPONSES
	# --------------------------------------------------------

	if responses_menu.next_action.is_empty():

		responses_menu.next_action = (
			next_action
		)


	# --------------------------------------------------------
	# MUTATION TIMER
	# --------------------------------------------------------

	mutation_cooldown.one_shot = true


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

func _process(
	_delta: float
) -> void:

	_update_fast_forward()


	if not is_instance_valid(
		dialogue_line
	):

		progress.hide()

		return


	progress.visible = (
		is_waiting_for_input
		and not dialogue_label.is_typing
		and dialogue_line.responses.is_empty()
		and not dialogue_line.has_tag("voice")
		and not manual_hide_active
		and not screen_only_locked
	)


# ============================================================
# INPUT
# ============================================================

func _input(
	event: InputEvent
) -> void:

	if dialogue_line == null:
		return


	# Don't process keyboard echo events.
	if (
		event is InputEventKey
		and event.echo
	):

		return


	# --------------------------------------------------------
	# HIDE / SHOW
	# --------------------------------------------------------

	if event.is_action_pressed(
		"hide"
	):

		if screen_only_locked:
			return


		if hide_disabled:
			return


		_toggle_manual_hide()


		get_viewport().set_input_as_handled()


		return


	if manual_hide_active:
		return


	# --------------------------------------------------------
	# RESPONSES
	# --------------------------------------------------------

	# Don't let X / Z automatically select dialogue choices.
	if not dialogue_line.responses.is_empty():
		return


	# --------------------------------------------------------
	# ADVANCE
	# --------------------------------------------------------

	if is_waiting_for_input:

		if (
			event.is_action_pressed(
				next_action
			)
			or event.is_action_pressed(
				&"ui_accept"
			)
			or event.is_action_pressed(
				FAST_FORWARD_ACTION
			)
		):

			_request_advance()


			get_viewport().set_input_as_handled()


# ============================================================
# OLD GUI INPUT CONNECTION
# ============================================================

func _on_balloon_gui_input(
	_event: InputEvent
) -> void:

	# Intentionally empty.
	#
	# Input is handled only in _input().
	#
	# Keeping this function prevents an existing scene signal
	# connection from breaking.
	pass


# ============================================================
# TRANSLATION
# ============================================================

func _notification(
	what: int
) -> void:

	if (
		what == NOTIFICATION_TRANSLATION_CHANGED
		and _locale
		!= TranslationServer.get_locale()
	):

		_locale = TranslationServer.get_locale()


		if dialogue_line == null:
			return


		var ratio: float = (
			dialogue_label.visible_ratio
		)


		var new_line: DialogueLine = await (
			dialogue_resource.get_next_dialogue_line(
				dialogue_line.id,
				temporary_game_states
			)
		)


		dialogue_line = new_line


		if ratio < 1.0:

			dialogue_label.skip_typing()


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

	pending_scene_path = ""


	if with_dialogue_resource != null:

		dialogue_resource = (
			with_dialogue_resource
		)


	if not title.is_empty():

		start_from_title = title


	if dialogue_resource == null:

		push_warning(
			"Dialogue balloon has no DialogueResource."
		)

		return


	var first_line: DialogueLine = await (
		dialogue_resource.get_next_dialogue_line(
			start_from_title,
			temporary_game_states
		)
	)


	dialogue_line = first_line


	show()


# ============================================================
# APPLY DIALOGUE LINE
# ============================================================

func apply_dialogue_line(
	my_revision: int
) -> void:

	if dialogue_line == null:
		return


	var line: DialogueLine = (
		dialogue_line
	)


	# --------------------------------------------------------
	# RESET CURRENT LINE STATE
	# --------------------------------------------------------

	mutation_cooldown.stop()

	will_hide_balloon = false

	progress.hide()

	is_waiting_for_input = false

	pending_scene_path = ""


	balloon.focus_mode = (
		Control.FOCUS_ALL
	)


	balloon.grab_focus()


	# --------------------------------------------------------
	# PARSE LINE
	# --------------------------------------------------------

	var text_with_tags: String = (
		line.text
	)


	var parsed: Dictionary = (
		_extract_emotion(
			text_with_tags
		)
	)


	hide_disabled = bool(
		parsed.get(
			"hide_disabled",
			false
		)
	)


	# --------------------------------------------------------
	# SCREEN ONLY
	# --------------------------------------------------------

	var wants_screen_only: bool = bool(
		parsed.get(
			"hide",
			false
		)
	)


	if wants_screen_only:

		_set_screen_only_mode(
			true
		)


	elif screen_only_locked:

		_set_screen_only_mode(
			false
		)


	# --------------------------------------------------------
	# TEXT AFTER EMOTION PARSING
	# --------------------------------------------------------

	var parsed_text: String = str(
		parsed.get(
			"text",
			""
		)
	)


	# --------------------------------------------------------
	# PAINT
	# --------------------------------------------------------

	if "[show paint]" in parsed_text:

		paint_node.show()


		parsed_text = parsed_text.replace(
			"[show paint]",
			""
		)


	# --------------------------------------------------------
	# CHARACTER NAME
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
		str(
			parsed.get(
				"emotion",
				"neutral"
			)
		)
	)


	# --------------------------------------------------------
	# SCREEN TAG
	# --------------------------------------------------------

	var screen_tag_regex := RegEx.new()


	screen_tag_regex.compile(
		"\\[screen=([^\\]]+)\\]"
	)


	for match_result in screen_tag_regex.search_all(
		parsed_text
	):

		_set_screen_sprite(
			match_result.get_string(
				1
			)
		)


	# Remove [screen=...] from dialogue text.
	parsed_text = screen_tag_regex.sub(
		parsed_text,
		"",
		true
	)


	# --------------------------------------------------------
	# SYSTEM TIME
	# --------------------------------------------------------

	var final_text: String = (
		parsed_text.replace(
			"[time]",
			get_system_time()
		)
	)


	# --------------------------------------------------------
	# SCENE TAG
	# --------------------------------------------------------

	# IMPORTANT:
	#
	# Emotion parsing now PRESERVES anything after
	# "(happy)", "(sad)", etc.
	#
	# Therefore [scene=...] reaches this function correctly.
	final_text = _handle_scene_tag(
		final_text
	)


	# --------------------------------------------------------
	# SET TEXT
	# --------------------------------------------------------

	dialogue_label.hide()


	dialogue_label.dialogue_line = (
		line
	)


	dialogue_label.dialogue_line.text = (
		final_text.strip_edges()
	)


	# --------------------------------------------------------
	# RESPONSES
	# --------------------------------------------------------

	responses_menu.hide()

	responses_menu.responses = (
		line.responses
	)


	# --------------------------------------------------------
	# VISIBILITY
	# --------------------------------------------------------

	_sync_dialogue_visibility()


	# --------------------------------------------------------
	# TYPEWRITER
	# --------------------------------------------------------

	if not final_text.strip_edges().is_empty():

		dialogue_label.show()


		dialogue_label.type_out()


		await dialogue_label.finished_typing


		# Ignore an old coroutine that finished after
		# another line already started.
		if my_revision != line_revision:
			return


		if dialogue_line != line:
			return


	# --------------------------------------------------------
	# VOICE
	# --------------------------------------------------------

	if line.has_tag(
		"voice"
	):

		audio_stream_player.stream = load(
			line.get_tag_value(
				"voice"
			)
		)


		audio_stream_player.play()


		await audio_stream_player.finished


		if my_revision != line_revision:
			return


		if dialogue_line != line:
			return


		await _advance_to(
			line.next_id
		)


		return


	# --------------------------------------------------------
	# RESPONSES
	# --------------------------------------------------------

	if not line.responses.is_empty():

		balloon.focus_mode = (
			Control.FOCUS_NONE
		)


		responses_menu.show()


		_sync_dialogue_visibility()


		return


	# --------------------------------------------------------
	# AUTO / TIMED LINE
	# --------------------------------------------------------

	if line.time != "":

		var wait_time: float


		if line.time == "auto":

			wait_time = (
				final_text.length()
				* 0.02
			)


		else:

			wait_time = (
				line.time.to_float()
			)


		await get_tree().create_timer(
			wait_time
		).timeout


		if my_revision != line_revision:
			return


		if dialogue_line != line:
			return


		await _advance_to(
			line.next_id
		)


		return


	# --------------------------------------------------------
	# WAIT FOR INPUT
	# --------------------------------------------------------

	is_waiting_for_input = true


	balloon.grab_focus()


	_sync_dialogue_visibility()


	# Holding X continues through ordinary lines.
	if Input.is_action_pressed(
		FAST_FORWARD_ACTION
	):

		_request_advance()


# ============================================================
# REQUEST ADVANCE
# ============================================================

func _request_advance() -> void:

	if dialogue_line == null:
		return


	if transition_in_progress:
		return


	if not is_waiting_for_input:
		return


	if not dialogue_line.responses.is_empty():
		return


	_advance_to(
		dialogue_line.next_id
	)


# ============================================================
# ADVANCE
# ============================================================

func _advance_to(
	next_id: String
) -> void:

	if transition_in_progress:
		return


	transition_in_progress = true

	is_waiting_for_input = false


	# --------------------------------------------------------
	# SCENE CHANGE
	# --------------------------------------------------------

	if not pending_scene_path.is_empty():

		var scene_path: String = (
			pending_scene_path
		)


		pending_scene_path = ""


		await _change_scene_safe(
			scene_path
		)


		return


	# --------------------------------------------------------
	# NORMAL DIALOGUE ADVANCE
	# --------------------------------------------------------

	var source_revision: int = (
		line_revision
	)


	var new_line: DialogueLine = await (
		dialogue_resource.get_next_dialogue_line(
			next_id,
			temporary_game_states
		)
	)


	if source_revision != line_revision:

		transition_in_progress = false

		return


	dialogue_line = new_line


# ============================================================
# RESPONSE SELECTED
# ============================================================

func _on_responses_menu_response_selected(
	response: DialogueResponse
) -> void:

	await _advance_to(
		response.next_id
	)


# ============================================================
# FAST FORWARD
# ============================================================

func _update_fast_forward() -> void:

	if dialogue_label == null:
		return


	if (
		dialogue_label.is_typing
		and Input.is_action_pressed(
			FAST_FORWARD_ACTION
		)
		and not manual_hide_active
	):

		dialogue_label.seconds_per_step = (
			normal_seconds_per_step
			/ FAST_FORWARD_MULTIPLIER
		)


		dialogue_label.seconds_per_pause_step = (
			normal_seconds_per_pause_step
			/ FAST_FORWARD_MULTIPLIER
		)


	else:

		_restore_typing_speed()


func _restore_typing_speed() -> void:

	if dialogue_label == null:
		return


	dialogue_label.seconds_per_step = (
		normal_seconds_per_step
	)


	dialogue_label.seconds_per_pause_step = (
		normal_seconds_per_pause_step
	)


# ============================================================
# ACTIONS
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
	_mutation
) -> void:

	var is_inline: bool = false


	if _mutation is Dictionary:

		is_inline = bool(
			_mutation.get(
				"is_inline",
				false
			)
		)


	else:

		is_inline = bool(
			_mutation.is_inline
		)


	if not is_inline:

		is_waiting_for_input = false

		will_hide_balloon = true


		mutation_cooldown.start(
			0.1
		)


func _on_mutation_cooldown_timeout() -> void:

	if not will_hide_balloon:
		return


	will_hide_balloon = false


	if dialogue_line == null:
		return


	_sync_dialogue_visibility()


# ============================================================
# MANUAL HIDE
# ============================================================

func _toggle_manual_hide() -> void:

	manual_hide_active = (
		not manual_hide_active
	)


	_sync_dialogue_visibility()


	if not manual_hide_active:

		balloon.grab_focus()


# ============================================================
# SCREEN-ONLY MODE
# ============================================================

func _set_screen_only_mode(
	enabled: bool
) -> void:

	screen_only_locked = enabled


	_sync_dialogue_visibility()


# ============================================================
# SYNC VISIBILITY
# ============================================================

func _sync_dialogue_visibility() -> void:

	# --------------------------------------------------------
	# SCREEN-ONLY MODE
	# --------------------------------------------------------

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


	# --------------------------------------------------------
	# MANUALLY HIDDEN
	# --------------------------------------------------------

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


	# --------------------------------------------------------
	# NORMAL DIALOGUE
	# --------------------------------------------------------

	balloon.show()

	vbox_container.show()

	dialogue_label.show()

	$TextureRect.show()

	$TextureRect2.show()

	$Control.show()


	character_label.visible = (
		dialogue_line != null
		and not dialogue_line.character.is_empty()
	)


	portrait_sprite.visible = (
		portrait_sprite.texture != null
		and dialogue_line != null
		and not dialogue_line.character.is_empty()
	)


	if dialogue_line != null:

		responses_menu.visible = (
			not dialogue_label.is_typing
			and not dialogue_line.responses.is_empty()
		)


	else:

		responses_menu.hide()


# ============================================================
# EMOTION / SPECIAL TAG PARSING
# ============================================================

func _extract_emotion(
	text: String
) -> Dictionary:

	var emotion: String = "neutral"

	var clean_text: String = text

	var hide_screen_only: bool = false

	var disable_hide: bool = false


	# --------------------------------------------------------
	# HIDE
	# --------------------------------------------------------

	if "(hide)" in clean_text:

		hide_screen_only = true


		clean_text = clean_text.replace(
			"(hide)",
			""
		)


	# --------------------------------------------------------
	# NOHIDE
	# --------------------------------------------------------

	if "(nohide)" in clean_text:

		disable_hide = true


		clean_text = clean_text.replace(
			"(nohide)",
			""
		)


	# --------------------------------------------------------
	# EMOTION
	# --------------------------------------------------------

	var open_index: int = (
		clean_text.rfind(
			"("
		)
	)


	var close_index: int = (
		clean_text.find(
			")",
			open_index
		)
	)


	if (
		open_index != -1
		and close_index != -1
		and close_index > open_index
	):

		emotion = (
			clean_text.substr(
				open_index + 1,
				close_index - open_index - 1
			).strip_edges()
		)


		# ====================================================
		# IMPORTANT FIX
		# ====================================================
		#
		# OLD VERSION:
		#
		# clean_text = clean_text.substr(0, open_index)
		#
		# That deleted EVERYTHING after the emotion.
		#
		# Example:
		#
		# Good. (happy) [scene=Outside]
		#
		# became:
		#
		# Good.
		#
		# This version removes ONLY "(happy)" and keeps
		# everything after it.
		# ====================================================

		var before_emotion: String = (
			clean_text.substr(
				0,
				open_index
			)
		)


		var after_emotion: String = (
			clean_text.substr(
				close_index + 1
			)
		)


		clean_text = (
			before_emotion
			+ after_emotion
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

		portrait_sprite.hide()

		return


	var character_name: String = (
		character.capitalize()
	)


	var emotion_name: String = (
		emotion.capitalize()
	)


	var base_path: String = (
		"res://Art/Expressions/%s/"
		% character_name
	)


	var portrait_path: String = (
		"%s%s_%s.png"
		% [
			base_path,
			character_name,
			emotion_name
		]
	)


	var fallback_path: String = (
		"%s%s_Neutral.png"
		% [
			base_path,
			character_name
		]
	)


	if ResourceLoader.exists(
		portrait_path
	):

		portrait_sprite.texture = load(
			portrait_path
		)


	elif ResourceLoader.exists(
		fallback_path
	):

		portrait_sprite.texture = load(
			fallback_path
		)


	else:

		portrait_sprite.texture = null


	if portrait_sprite.texture != null:

		portrait_sprite.show()


	else:

		portrait_sprite.hide()


# ============================================================
# SCREEN IMAGE
# ============================================================

func _set_screen_sprite(
	screen_name: String
) -> void:

	screen_name = (
		screen_name.strip_edges()
	)


	if (
		screen_name.is_empty()
		or screen_name.to_lower() == "none"
	):

		screen_sprite.hide()

		screen_sprite.texture = null

		return


	var path: String = (
		"res://Art/Screens/%s.png"
		% screen_name
	)


	if ResourceLoader.exists(
		path
	):

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

	var now: Dictionary = (
		Time.get_datetime_dict_from_system()
	)


	return "%02d:%02d" % [
		now.hour,
		now.minute
	]


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

		var scene_value: String = (
			match_result.get_string(
				1
			).strip_edges()
		)


		var resolved_path: String = (
			_resolve_scene_path(
				scene_value
			)
		)


		if resolved_path.is_empty():

			push_warning(
				"Could not find scene from tag: "
				+ scene_value
			)


		else:

			print(
				"Dialogue scene tag found: ",
				resolved_path
			)


			pending_scene_path = (
				resolved_path
			)


	return scene_tag_regex.sub(
		text,
		"",
		true
	)


# ============================================================
# RESOLVE SCENE PATH
# ============================================================

func _resolve_scene_path(
	scene_value: String
) -> String:

	var value: String = (
		scene_value.strip_edges()
	)


	if value.is_empty():

		return ""


	# --------------------------------------------------------
	# FULL PATH
	# --------------------------------------------------------

	# Example:
	#
	# [scene=res://Outside.tscn]
	if value.begins_with(
		"res://"
	):

		var full_path: String = (
			value
		)


		if not full_path.ends_with(
			".tscn"
		):

			full_path += ".tscn"


		if ResourceLoader.exists(
			full_path
		):

			return full_path


		return ""


	# --------------------------------------------------------
	# SHORT NAME
	# --------------------------------------------------------

	# Example:
	#
	# [scene=Outside]

	var relative_path: String = (
		value
	)


	if not relative_path.ends_with(
		".tscn"
	):

		relative_path += ".tscn"


	# --------------------------------------------------------
	# PROJECT ROOT
	# --------------------------------------------------------

	var root_path: String = (
		"res://"
		+ relative_path
	)


	if ResourceLoader.exists(
		root_path
	):

		return root_path


	# --------------------------------------------------------
	# SCENES FOLDER
	# --------------------------------------------------------

	var scenes_path: String = (
		"res://Scenes/"
		+ relative_path
	)


	if ResourceLoader.exists(
		scenes_path
	):

		return scenes_path


	return ""


# ============================================================
# SAFE SCENE CHANGE
# ============================================================

func _change_scene_safe(
	path: String
) -> void:

	if path.is_empty():

		transition_in_progress = false

		return


	if not ResourceLoader.exists(
		path
	):

		push_warning(
			"Cannot change scene. Missing scene: "
			+ path
		)


		transition_in_progress = false

		return


	print(
		"Changing scene to: ",
		path
	)


	is_waiting_for_input = false


	_restore_typing_speed()


	balloon.hide()

	dialogue_label.hide()

	character_label.hide()

	portrait_sprite.hide()

	responses_menu.hide()

	progress.hide()

	screen_sprite.hide()

	paint_node.hide()


	# Make sure the incoming Character isn't locked because
	# Dialogue Manager hasn't finished cleaning up yet.
	GameState.in_dialogue = false


	await get_tree().process_frame


	if not is_inside_tree():
		return


	var error: Error = (
		get_tree().change_scene_to_file(
			path
		)
	)


	if error != OK:

		push_error(
			"Failed to change scene to: "
			+ path
			+ " Error: "
			+ str(error)
		)


		transition_in_progress = false
