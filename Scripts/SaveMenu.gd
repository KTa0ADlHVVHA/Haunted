extends Control
signal slot_selected(slot: int)

# ---------------- NODES ----------------
@onready var slot_buttons := [
	$"CanvasLayer/Panel/Label/1", $"CanvasLayer/Panel/Label/2", $"CanvasLayer/Panel/Label/3",
	$"CanvasLayer/Panel/Label/4", $"CanvasLayer/Panel/Label/5", $"CanvasLayer/Panel/Label/6",
	$"CanvasLayer/Panel/Label/7", $"CanvasLayer/Panel/Label/8", $"CanvasLayer/Panel/Label/9",
	$"CanvasLayer/Panel/Label/10", $"CanvasLayer/Panel/Label/11", $"CanvasLayer/Panel/Label/12",
	$"CanvasLayer/Panel/Label/13", $"CanvasLayer/Panel/Label/14", $"CanvasLayer/Panel/Label/15"
]
@onready var save_btn := $CanvasLayer/Panel/Save
@onready var load_btn := $CanvasLayer/Panel/Load
@onready var delete_btn := $CanvasLayer/Panel/Delete
@onready var slot_highlight := $"CanvasLayer/Panel/Highlight" if has_node("CanvasLayer/Panel/Highlight") else null

# ---------------- STATE ----------------
var current_action := ""  # "save", "load", or "delete"
var selected_slot := 1
var cancel_pressed_once := false

# ---------------- CURRENT SCENE PATH ----------------
var current_scene_path := "res://scenes/Main.tscn"

# ---------------- READY ----------------
func _ready():
	for btn in slot_buttons:
		if btn:
			btn.disabled = true

	if slot_highlight:
		slot_highlight.visible = false

	# Connect action buttons
	save_btn.pressed.connect(func(): on_action_selected("save"))
	load_btn.pressed.connect(func(): on_action_selected("load"))
	delete_btn.pressed.connect(func(): on_action_selected("delete"))

	# Connect slot buttons
	for i in range(slot_buttons.size()):
		var btn = slot_buttons[i]
		if btn:
			var slot_index = i + 1
			btn.pressed.connect(func(idx=slot_index):
				selected_slot = idx
				update_focus_and_highlight()
				on_slot_pressed(selected_slot)
			)

	call_deferred("_grab_control_focus")
	update_slots()
	update_button_states()

	call_deferred("_focus_save") # ★ NEW (auto-select Save on open)


# ---------------- BUTTON STATE MANAGEMENT ----------------
func update_button_states():
	# Slots enabled only if an action is selected
	for btn in slot_buttons:
		if btn:
			btn.disabled = current_action == ""

	# Action buttons enabled only if no action is selected
	var action_btns = [save_btn, load_btn, delete_btn]
	for btn in action_btns:
		if btn:
			btn.disabled = current_action != ""


# ---------------- FOCUS ----------------
func _grab_control_focus():
	grab_focus()
	update_focus_and_highlight()


func _focus_save(): # ★ NEW
	save_btn.grab_focus()


# ---------------- INPUT ----------------
func _unhandled_input(event):
	if event.is_action_pressed("cancel"):
		handle_cancel()
	elif current_action != "":
		if event.is_action_pressed("up"):
			move_selection(-1)
		elif event.is_action_pressed("down"):
			move_selection(1)
		elif event.is_action_pressed("interact"):
			for i in range(slot_buttons.size()):
				if slot_buttons[i].has_focus():
					selected_slot = i + 1
					break
			on_slot_pressed(selected_slot)


# ---------------- CANCEL ----------------
func handle_cancel():
	if current_action != "":
		current_action = ""
		for btn in slot_buttons:
			if btn:
				btn.disabled = true
		if slot_highlight:
			slot_highlight.visible = false

		update_button_states()
		call_deferred("_focus_save") # ★ NEW (cancel returns to Save)
	else:
		queue_free()


# ---------------- SELECTION ----------------
func move_selection(offset: int):
	selected_slot += offset
	if selected_slot < 1:
		selected_slot = slot_buttons.size()
	elif selected_slot > slot_buttons.size():
		selected_slot = 1
	update_focus_and_highlight()


func update_focus_and_highlight():
	var btn = slot_buttons[selected_slot - 1]
	if btn:
		if slot_highlight:
			slot_highlight.rect_global_position = btn.rect_global_position
			slot_highlight.visible = true
		if not btn.has_focus():
			btn.grab_focus()


# ---------------- UPDATE SLOT TEXT ----------------
func update_slots():
	for i in range(slot_buttons.size()):
		var slot = i + 1
		SaveManager.set_slot(slot)
		var btn = slot_buttons[i]
		if btn:
			if SaveManager.slot_exists(slot):
				var timestamp = SaveManager.get_value("timestamp", "")
				var playtime = SaveManager.get_value("playtime", 0)
				var time_text = format_human_timestamp(timestamp) if timestamp != "" else "Unknown time"
				var playtime_text = format_playtime(playtime)
				btn.text = "Slot %d — Saved\n%s\nPlaytime: %s" % [slot, time_text, playtime_text]
			else:
				btn.text = "Slot %d — Empty" % slot


# ---------------- ACTION SELECTION ----------------
func on_action_selected(action: String):
	current_action = action
	cancel_pressed_once = false

	selected_slot = 1 # ★ NEW (always start on Slot 1)

	for btn in slot_buttons:
		if btn:
			btn.disabled = false

	update_button_states()
	update_focus_and_highlight()


# ---------------- SLOT ACTION ----------------
func on_slot_pressed(slot: int):
	if current_action == "":
		return

	selected_slot = slot
	SaveManager.set_slot(slot)

	match current_action:
		"save":
			confirm_save()
		"load":
			confirm_load()
		"delete":
			confirm_delete()


# ---------------- SAVE ----------------
func confirm_save():
	var slot_to_save = selected_slot
	var dlg = ConfirmationDialog.new()
	dlg.dialog_text = "Do you want to save to Slot %d?" % slot_to_save
	dlg.confirmed.connect(func():
		_on_save_confirmed(slot_to_save)
	)
	add_child(dlg)
	dlg.popup_centered()


func _on_save_confirmed(slot: int):
	SaveManager.set_slot(slot)
	SaveManager.set_value("scene_path", current_scene_path)
	SaveManager.set_value("timestamp", Time.get_datetime_string_from_system(false, true))
	SaveManager.set_value("playtime", GameState.get_playtime())
	emit_signal("slot_selected", slot)
	_after_action_completed()


# ---------------- LOAD ----------------
func confirm_load():
	var slot_to_load = selected_slot
	var dlg = ConfirmationDialog.new()
	dlg.dialog_text = "Do you want to load Slot %d? Unsaved progress will be lost!" % slot_to_load
	dlg.confirmed.connect(func():
		_on_load_confirmed(slot_to_load)
	)
	add_child(dlg)
	dlg.popup_centered()


func _on_load_confirmed(slot: int):
	SaveManager.set_slot(slot)

	var saved_scene = SaveManager.get_value("scene_path", "")
	if saved_scene != "" and FileAccess.file_exists(saved_scene):
		get_tree().call_deferred("change_scene_to_file", saved_scene)
	else:
		push_warning("Saved scene not found. Reloading current scene.")
		get_tree().call_deferred("reload_current_scene")

	close_menu()

	_after_action_completed()


# ---------------- DELETE ----------------
func confirm_delete():
	var slot_to_delete = selected_slot
	var dlg = ConfirmationDialog.new()
	dlg.dialog_text = "Do you want to delete Slot %d? This cannot be undone!" % slot_to_delete
	dlg.confirmed.connect(func():
		_on_delete_confirmed(slot_to_delete)
	)
	add_child(dlg)
	dlg.popup_centered()


func _on_delete_confirmed(slot: int):
	SaveManager.delete_slot(slot)
	_after_action_completed()


# ---------------- AFTER ACTION ----------------
func _after_action_completed():
	current_action = ""
	cancel_pressed_once = false
	for btn in slot_buttons:
		if btn:
			btn.disabled = true
	if slot_highlight:
		slot_highlight.visible = false

	update_slots()
	update_button_states()
	call_deferred("_focus_save") # ★ NEW (return to Save)


# ---------------- CLOSE MENU ----------------
func close_menu():
	queue_free()


# ---------------- HELPERS ----------------
func format_playtime(seconds: int) -> String:
	var h = int(seconds / 3600)
	var m = int((seconds % 3600) / 60)
	var s = int(seconds % 60)
	return "%02d:%02d:%02d" % [h, m, s]


func format_human_timestamp(timestamp_str: String) -> String:
	var parts = timestamp_str.split(" ")
	if parts.size() != 2:
		return timestamp_str
	var date_parts = parts[0].split("-")
	var time_parts = parts[1].split(":")
	if date_parts.size() != 3 or time_parts.size() < 2:
		return timestamp_str
	var year = int(date_parts[0])
	var month = int(date_parts[1])
	var day = int(date_parts[2])
	var hour = int(time_parts[0])
	var minute = int(time_parts[1])
	var now = Time.get_datetime_dict_from_system(true)
	var delta_days = DateTime_to_days(now.year, now.month, now.day) - DateTime_to_days(year, month, day)
	if delta_days == 0:
		return "Today %02d:%02d" % [hour, minute]
	elif delta_days == 1:
		return "Yesterday %02d:%02d" % [hour, minute]
	elif delta_days <= 30:
		return "%d days ago %02d:%02d" % [delta_days, hour, minute]
	else:
		return "%02d/%02d %02d:%02d" % [month, day, hour, minute]


func DateTime_to_days(y, m, d):
	return y * 365 + m * 31 + d
