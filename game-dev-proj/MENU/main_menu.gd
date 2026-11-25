#main_menu.gd
# NEW GAME, and under it CONTINUE, which opens the level select
# (level_select.gd). A new player (no save, so no levels reached yet) sees
# CONTINUE greyed out. NEW GAME over an existing save asks first, since it
# wipes it.
extends Node2D

const LevelSelect = preload("res://MENU/level_select.gd")
const AchievementsScreen = preload("res://MENU/achievements_screen.gd")

@onready var new_game_button: Button = $Button

var _confirm: CanvasLayer
var _continue: Button
var _trophy: Button


func _ready() -> void:
	_continue = new_game_button.duplicate(0) as Button
	_continue.set_script(null)
	_continue.text = "CONTINUE"
	_continue.offset_top += 65
	_continue.offset_bottom += 65
	_continue.add_theme_color_override("font_disabled_color", Color(0.42, 0.42, 0.46))
	add_child(_continue)
	move_child(_continue, new_game_button.get_index() + 1)
	_continue.pressed.connect(_open_level_select)
	_continue.focus_neighbor_top = _continue.get_path_to(new_game_button)
	if OS.is_debug_build():
		_add_unlock_all_toggle()
	_add_trophy_button()
	if TouchControls.enabled:
		_add_controls_button()
	_refresh_continue()
	if _continue.disabled:
		new_game_button.grab_focus()
	else:
		_continue.grab_focus()


## CONTINUE is greyed out until a level has been reached (or testing opens them all).
func _refresh_continue() -> void:
	var reached := SaveManager.levels_reached(SaveManager.load_data())
	_continue.disabled = reached.is_empty()
	_continue.focus_mode = Control.FOCUS_NONE if _continue.disabled else Control.FOCUS_ALL
	_continue.modulate.a = 0.6 if _continue.disabled else 1.0
	# down from the buttons reaches the trophy (skipping a greyed-out CONTINUE)
	var last: Button = new_game_button if _continue.disabled else _continue
	new_game_button.focus_neighbor_bottom = new_game_button.get_path_to(_continue if not _continue.disabled else _trophy)
	_continue.focus_neighbor_bottom = _continue.get_path_to(_trophy)
	_trophy.focus_neighbor_top = _trophy.get_path_to(last)
	_trophy.focus_neighbor_left = _trophy.get_path_to(last)


## Testing only (debug builds, so never in an exported game): a switch in the
## corner that opens every level in the level select, and survives NEW GAME.
func _add_unlock_all_toggle() -> void:
	var toggle := CheckButton.new()
	toggle.text = "TEST: unlock all levels"
	toggle.button_pressed = SaveManager.unlock_all
	toggle.focus_mode = Control.FOCUS_NONE
	toggle.add_theme_font_override("font", MenuStyle.FONT)
	toggle.add_theme_font_size_override("font_size", 16)
	toggle.add_theme_color_override("font_color", MenuStyle.DIM)
	toggle.add_theme_color_override("font_pressed_color", MenuStyle.GOLD)
	toggle.position = Vector2(12, 8)
	toggle.toggled.connect(func(on: bool):
		SaveManager.set_unlock_all(on)
		_refresh_continue())
	var layer := CanvasLayer.new()
	layer.layer = 5
	layer.add_child(toggle)
	add_child(layer)


## The trophy in the top-right corner: opens the achievements list.
func _add_trophy_button() -> void:
	_trophy = Button.new()
	_trophy.custom_minimum_size = Vector2(64, 64)
	_trophy.tooltip_text = "Achievements"
	for state in ["normal", "hover", "pressed", "focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.04, 0.04, 0.08, 0.6 if state == "normal" else 0.85)
		style.set_corner_radius_all(8)
		style.set_border_width_all(2)
		style.border_color = MenuStyle.ACCENT if state != "normal" else Color(1, 1, 1, 0.15)
		_trophy.add_theme_stylebox_override(state, style)
	var icon := TrophyIcon.new(44, MenuStyle.GOLD)
	icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	_trophy.add_child(icon)
	_trophy.pressed.connect(_open_achievements)
	var w := get_viewport().get_visible_rect().size.x
	_trophy.position = Vector2(w - 64 - 16, 16)
	var caption := MenuStyle.label("%d/%d" % [Achievements.unlocked_count(), Achievements.LIST.size()], 14, MenuStyle.DIM)
	caption.position = Vector2(w - 64 - 16, 16 + 66)
	caption.custom_minimum_size.x = 64
	var layer := CanvasLayer.new()
	layer.layer = 5
	layer.add_child(_trophy)
	layer.add_child(caption)
	add_child(layer)


## Phones only: the touch Controls screen (button size, stick, layout).
func _add_controls_button() -> void:
	var button := Button.new()
	button.text = "Controls"
	button.custom_minimum_size = Vector2(130, 64)
	button.add_theme_font_override("font", MenuStyle.FONT)
	button.add_theme_font_size_override("font_size", 20)
	button.add_theme_color_override("font_color", MenuStyle.TEXT)
	for state in ["normal", "hover", "pressed", "focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.04, 0.04, 0.08, 0.6 if state == "normal" else 0.85)
		style.set_corner_radius_all(8)
		style.set_border_width_all(2)
		style.border_color = MenuStyle.ACCENT if state != "normal" else Color(1, 1, 1, 0.15)
		button.add_theme_stylebox_override(state, style)
	var w := get_viewport().get_visible_rect().size.x
	button.position = Vector2(w - 64 - 16 - 12 - 130, 16)
	button.pressed.connect(func():
		var screen := TouchSettingsScreen.new()
		screen.closed.connect(func(): button.grab_focus())
		add_child(screen))
	_trophy.get_parent().add_child(button)


func _open_achievements() -> void:
	var screen := AchievementsScreen.new()
	screen.closed.connect(func(): _trophy.grab_focus())
	add_child(screen)


func _open_level_select() -> void:
	if _continue.disabled:
		return
	var screen := LevelSelect.new()
	screen.closed.connect(func(): _continue.grab_focus())
	add_child(screen)


## NEW GAME (button.gd).
func new_game_pressed() -> void:
	if not SaveManager.has_save():
		SaveManager.new_game()
		return
	_confirm = MenuStyle.overlay(10)
	add_child(_confirm)
	var panel := MenuStyle.panel()
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	panel.add_child(col)
	col.add_child(MenuStyle.label("Start a new game?", 28))
	col.add_child(MenuStyle.label("Your saved progress and stars will be lost.", 18, MenuStyle.DIM))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	col.add_child(row)
	var yes := MenuStyle.button("Start new game")
	var no := MenuStyle.button("Cancel")
	yes.pressed.connect(SaveManager.new_game)
	no.pressed.connect(_close_confirm)
	row.add_child(yes)
	row.add_child(no)
	MenuStyle.centre(_confirm, panel)
	no.grab_focus()


func _close_confirm() -> void:
	_confirm.queue_free()
	new_game_button.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if is_instance_valid(_confirm) and event.is_action_pressed("pause"):
		_close_confirm()
		get_viewport().set_input_as_handled()
