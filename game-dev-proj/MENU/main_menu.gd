#main_menu.gd
# NEW GAME, and under it CONTINUE, which opens the level select
# (level_select.gd). A new player (no save, so no levels reached yet) sees
# CONTINUE greyed out. NEW GAME over an existing save asks first, since it
# wipes it.
extends Node2D

const LevelSelect = preload("res://MENU/level_select.gd")

@onready var new_game_button: Button = $Button

var _confirm: CanvasLayer
var _continue: Button


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

	var reached: Array = SaveManager.load_data().get("levels_unlocked", [])
	if reached.is_empty():
		_continue.disabled = true
		_continue.focus_mode = Control.FOCUS_NONE
		_continue.modulate.a = 0.6
		new_game_button.grab_focus()
		return
	new_game_button.focus_neighbor_bottom = new_game_button.get_path_to(_continue)
	_continue.focus_neighbor_top = _continue.get_path_to(new_game_button)
	_continue.grab_focus()


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
