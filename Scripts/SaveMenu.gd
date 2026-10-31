extends Control


signal slot_selected(slot: int)


# ============================================================
# NODES
# ============================================================

@onready var slot_buttons := [
	$"CanvasLayer/Panel/Label/1",
	$"CanvasLayer/Panel/Label/2",
	$"CanvasLayer/Panel/Label/3",
	$"CanvasLayer/Panel/Label/4",
	$"CanvasLayer/Panel/Label/5",
	$"CanvasLayer/Panel/Label/6",
	$"CanvasLayer/Panel/Label/7",
	$"CanvasLayer/Panel/Label/8",
	$"CanvasLayer/Panel/Label/9",
	$"CanvasLayer/Panel/Label/10",
	$"CanvasLayer/Panel/Label/11",
	$"CanvasLayer/Panel/Label/12",
	$"CanvasLayer/Panel/Label/13",
	$"CanvasLayer/Panel/Label/14",
	$"CanvasLayer/Panel/Label/15"
]


@onready var save_btn := $CanvasLayer/Panel/Save
@onready var load_btn := $CanvasLayer/Panel/Load
@onready var delete_btn := $CanvasLayer/Panel/Delete


@onready var slot_highlight := (
	$"CanvasLayer/Panel/Highlight"
	if has_node("CanvasLayer/Panel/Highlight")
	else null
)


# ============================================================
# STATE
# ============================================================

# "", "save", "load", or "delete"
var current_action: String = ""

var selected_slot: int = 1


# ============================================================
# READY
# ============================================================

func _ready() -> void:
	# Save menu must continue working while game is paused.
	process_mode = Node.PROCESS_MODE_ALWAYS


	# Slot buttons start disabled.
	for btn in slot_buttons:
		if btn:
			btn.disabled = true


	if slot_highlight:
		slot_highlight.visible = false


	# ========================================================
	# MAIN BUTTONS
	# ========================================================

	save_btn.pressed.connect(
		func():
			on_action_selected("save")
	)


	load_btn.pressed.connect(
		func():
			on_action_selected("load")
	)


	delete_btn.pressed.connect(
		func():
			on_action_selected("delete")
	)


	# ========================================================
	# SLOT BUTTONS
	# ========================================================

	for i in range(slot_buttons.size()):
		var btn = slot_buttons[i]

		if btn == null:
			continue


		var slot_index := i + 1


		btn.pressed.connect(
			func(idx = slot_index):
				selected_slot = idx

				update_focus_and_highlight()

				on_slot_pressed(selected_slot)
		)


	update_slots()
	update_button_states()


	call_deferred("_focus_save")


# ============================================================
# INPUT
# ============================================================

func _unhandled_input(event: InputEvent) -> void:
	# ========================================================
	# CANCEL
	# ========================================================

	if event.is_action_pressed("cancel"):
		handle_cancel()

		get_viewport().set_input_as_handled()

		return


	# ========================================================
	# SAVE / LOAD / DELETE SCREEN
	# ========================================================

	if current_action.is_empty():

		# Z / interact acts like pressing the focused button.
		#
		# Enter already works automatically through Godot's
		# normal Button behaviour.
		if event.is_action_pressed("interact"):

			if save_btn.has_focus():
				on_action_selected("save")


			elif load_btn.has_focus():
				on_action_selected("load")


			elif delete_btn.has_focus():
				on_action_selected("delete")


			get_viewport().set_input_as_handled()

			return


		return


	# ========================================================
	# SLOT SELECTION
	# ========================================================

	if event.is_action_pressed("up"):
		move_selection(-1)

		get_viewport().set_input_as_handled()

		return


	if event.is_action_pressed("down"):
		move_selection(1)

		get_viewport().set_input_as_handled()

		return


	# Z confirms the focused slot.
	#
	# We don't manually handle ui_accept here because the
	# Button itself already handles Enter.
	if event.is_action_pressed("interact"):

		for i in range(slot_buttons.size()):
			var btn = slot_buttons[i]

			if btn and btn.has_focus():
				selected_slot = i + 1
				break


		on_slot_pressed(selected_slot)


		get_viewport().set_input_as_handled()

		return


# ============================================================
# BUTTON STATES
# ============================================================

func update_button_states() -> void:
	var choosing_slot := current_action != ""


	for btn in slot_buttons:
		if btn:
			btn.disabled = not choosing_slot


	var action_buttons := [
		save_btn,
		load_btn,
		delete_btn
	]


	for btn in action_buttons:
		if btn:
			btn.disabled = choosing_slot


# ============================================================
# FOCUS
# ============================================================

func _focus_save() -> void:
	if is_instance_valid(save_btn):
		save_btn.grab_focus()


func update_focus_and_highlight() -> void:
	if selected_slot < 1:
		return


	if selected_slot > slot_buttons.size():
		return


	var btn = slot_buttons[selected_slot - 1]


	if btn == null:
		return


	if slot_highlight:
		slot_highlight.global_position = btn.global_position
		slot_highlight.visible = true


	if not btn.has_focus():
		btn.grab_focus()


# ============================================================
# CANCEL
# ============================================================

func handle_cancel() -> void:
	# If selecting a slot, return to Save / Load / Delete.
	if not current_action.is_empty():

		current_action = ""


		if slot_highlight:
			slot_highlight.visible = false


		update_button_states()

		call_deferred("_focus_save")

		return


	# Otherwise close the entire menu.
	close_menu()


# ============================================================
# SLOT NAVIGATION
# ============================================================

func move_selection(offset: int) -> void:
	selected_slot += offset


	if selected_slot < 1:
		selected_slot = slot_buttons.size()


	elif selected_slot > slot_buttons.size():
		selected_slot = 1


	update_focus_and_highlight()


# ============================================================
# SLOT DISPLAY
# ============================================================

func update_slots() -> void:
	for i in range(slot_buttons.size()):

		var slot := i + 1

		var btn = slot_buttons[i]


		if btn == null:
			continue


		var data := SaveManager.get_slot_data(slot)


		# ====================================================
		# EMPTY
		# ====================================================

		if data.is_empty():

			btn.text = (
				"Slot %d — Empty"
				% slot
			)

			continue


		# ====================================================
		# SAVED
		# ====================================================

		var timestamp: String = str(
			data.get(
				"timestamp",
				""
			)
		)


		var playtime := int(
			data.get(
				"playtime",
				0
			)
		)


		var time_text := "Unknown time"


		if not timestamp.is_empty():

			time_text = format_human_timestamp(
				timestamp
			)


		var playtime_text := format_playtime(
			playtime
		)


		btn.text = (
			"Slot %d — Saved\n%s\nPlaytime: %s"
			% [
				slot,
				time_text,
				playtime_text
			]
		)


# ============================================================
# ACTION SELECTION
# ============================================================

func on_action_selected(action: String) -> void:
	current_action = action

	selected_slot = 1


	update_button_states()

	update_focus_and_highlight()


# ============================================================
# SLOT SELECTED
# ============================================================

func on_slot_pressed(slot: int) -> void:
	if current_action.is_empty():
		return


	selected_slot = slot


	match current_action:

		"save":
			confirm_save()


		"load":
			confirm_load()


		"delete":
			confirm_delete()


# ============================================================
# CONFIRMATION SHORTCUT
# ============================================================

# Gives the popup's real OK button:
#
# Z / interact
# AND
# Enter / ui_accept
#
# This is important because ConfirmationDialog is its own
# popup window and may not pass Z back to SaveMenu.
func give_dialog_confirm_shortcut(
	dialog: ConfirmationDialog
) -> void:

	var shortcut := Shortcut.new()

	var shortcut_events: Array[InputEvent] = []


	# Add Z / whatever is assigned to "interact".
	for input_event in InputMap.action_get_events("interact"):
		shortcut_events.append(
			input_event.duplicate()
		)


	# Add Enter / whatever is assigned to ui_accept.
	for input_event in InputMap.action_get_events("ui_accept"):
		shortcut_events.append(
			input_event.duplicate()
		)


	shortcut.events = shortcut_events


	var ok_button := dialog.get_ok_button()


	if ok_button:
		ok_button.shortcut = shortcut


# ============================================================
# SAVE
# ============================================================

func confirm_save() -> void:
	var slot_to_save := selected_slot


	var dlg := ConfirmationDialog.new()


	dlg.dialog_text = (
		"Do you want to save to Slot %d?"
		% slot_to_save
	)


	dlg.confirmed.connect(
		func():

			_on_save_confirmed(
				slot_to_save
			)


			if is_instance_valid(dlg):
				dlg.queue_free()
	)


	dlg.canceled.connect(
		func():

			if is_instance_valid(dlg):
				dlg.queue_free()
	)


	add_child(dlg)


	# Z + Enter both activate OK.
	give_dialog_confirm_shortcut(dlg)


	dlg.popup_centered()


func _on_save_confirmed(slot: int) -> void:
	# Character.gd receives this and creates
	# the actual save data.
	slot_selected.emit(slot)


	_after_action_completed()


# ============================================================
# LOAD
# ============================================================

func confirm_load() -> void:
	var slot_to_load := selected_slot


	if not SaveManager.slot_exists(slot_to_load):

		push_warning(
			"Slot %d is empty."
			% slot_to_load
		)

		return


	var dlg := ConfirmationDialog.new()


	dlg.dialog_text = (
		"Do you want to load Slot %d?\n"
		+ "Unsaved progress will be lost!"
	) % slot_to_load


	dlg.confirmed.connect(
		func():

			_on_load_confirmed(
				slot_to_load
			)


			if is_instance_valid(dlg):
				dlg.queue_free()
	)


	dlg.canceled.connect(
		func():

			if is_instance_valid(dlg):
				dlg.queue_free()
	)


	add_child(dlg)


	# Z + Enter both activate OK.
	give_dialog_confirm_shortcut(dlg)


	dlg.popup_centered()


func _on_load_confirmed(slot: int) -> void:
	var success := SaveManager.load_game(slot)


	if not success:

		push_warning(
			"Could not load Slot %d."
			% slot
		)

		return


	close_menu()


# ============================================================
# DELETE
# ============================================================

func confirm_delete() -> void:
	var slot_to_delete := selected_slot


	if not SaveManager.slot_exists(slot_to_delete):

		push_warning(
			"Slot %d is already empty."
			% slot_to_delete
		)

		return


	var dlg := ConfirmationDialog.new()


	dlg.dialog_text = (
		"Do you want to delete Slot %d?\n"
		+ "This cannot be undone!"
	) % slot_to_delete


	dlg.confirmed.connect(
		func():

			_on_delete_confirmed(
				slot_to_delete
			)


			if is_instance_valid(dlg):
				dlg.queue_free()
	)


	dlg.canceled.connect(
		func():

			if is_instance_valid(dlg):
				dlg.queue_free()
	)


	add_child(dlg)


	# Z + Enter both activate OK.
	give_dialog_confirm_shortcut(dlg)


	dlg.popup_centered()


func _on_delete_confirmed(slot: int) -> void:
	SaveManager.delete_slot(slot)


	_after_action_completed()


# ============================================================
# AFTER ACTION
# ============================================================

func _after_action_completed() -> void:
	current_action = ""

	selected_slot = 1


	if slot_highlight:
		slot_highlight.visible = false


	update_slots()

	update_button_states()


	call_deferred("_focus_save")


# ============================================================
# CLOSE MENU
# ============================================================

func close_menu() -> void:
	queue_free()


# ============================================================
# PLAYTIME
# ============================================================

func format_playtime(seconds: int) -> String:
	var hours := int(
		seconds / 3600
	)


	var minutes := int(
		(seconds % 3600) / 60
	)


	var remaining_seconds := int(
		seconds % 60
	)


	return "%02d:%02d:%02d" % [
		hours,
		minutes,
		remaining_seconds
	]


# ============================================================
# TIMESTAMP
# ============================================================

func format_human_timestamp(
	timestamp_str: String
) -> String:

	var parts := timestamp_str.split(" ")


	if parts.size() != 2:
		return timestamp_str


	var date_parts := parts[0].split("-")

	var time_parts := parts[1].split(":")


	if date_parts.size() != 3:
		return timestamp_str


	if time_parts.size() < 2:
		return timestamp_str


	var year := int(
		date_parts[0]
	)


	var month := int(
		date_parts[1]
	)


	var day := int(
		date_parts[2]
	)


	var hour := int(
		time_parts[0]
	)


	var minute := int(
		time_parts[1]
	)


	var now := Time.get_datetime_dict_from_system(
		true
	)


	var saved_unix := Time.get_unix_time_from_datetime_dict(
		{
			"year": year,
			"month": month,
			"day": day,
			"hour": hour,
			"minute": minute,
			"second": 0
		}
	)


	var now_unix := Time.get_unix_time_from_datetime_dict(
		now
	)


	var difference := int(
		now_unix - saved_unix
	)


	var delta_days := int(
		difference / 86400
	)


	if delta_days <= 0:

		return "Today %02d:%02d" % [
			hour,
			minute
		]


	if delta_days == 1:

		return "Yesterday %02d:%02d" % [
			hour,
			minute
		]


	if delta_days <= 30:

		return "%d days ago %02d:%02d" % [
			delta_days,
			hour,
			minute
		]


	return "%02d/%02d/%04d %02d:%02d" % [
		month,
		day,
		year,
		hour,
		minute
	]
