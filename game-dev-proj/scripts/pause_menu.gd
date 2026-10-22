#pause_menu.gd (autoload "PauseMenu")
# Esc in the game: Resume, Back to last lantern (as F does), Retry level (in
# a scored level, 4-9), Main menu, Quit. It only opens while playing: not over dialogue, a cutscene, the
# level-clear screen or the menus, which pause the game themselves.
extends Node

var _layer: CanvasLayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("pause"):
		return
	if is_instance_valid(_layer):
		_close()
		get_viewport().set_input_as_handled()
	elif _can_open():
		_open()
		get_viewport().set_input_as_handled()


func _can_open() -> bool:
	var tree := get_tree()
	var scene := tree.current_scene
	if scene == null or scene.name != "game" or tree.paused or LevelClear.is_open():
		return false
	var player := tree.get_first_node_in_group("player")
	return player != null and not player.get("is_dead") and not player.get("controls_locked")


func _open() -> void:
	get_tree().paused = true
	_layer = MenuStyle.overlay(56)
	add_child(_layer)
	var panel := MenuStyle.panel()
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	panel.add_child(col)
	col.add_child(MenuStyle.label("PAUSED", 32))
	var level := Echoes.run_level()
	if level != "":
		col.add_child(MenuStyle.label(level.replace("_", " "), 18, MenuStyle.DIM))
	var resume := MenuStyle.button("Resume")
	resume.pressed.connect(_close)
	col.add_child(resume)
	if GameManager.has_checkpoint:
		var lantern := MenuStyle.button("Back to last lantern")
		lantern.pressed.connect(_back_to_lantern)
		col.add_child(lantern)
	if level != "":
		var retry := MenuStyle.button("Retry level")
		retry.pressed.connect(_retry.bind(level))
		col.add_child(retry)
	var menu := MenuStyle.button("Main menu")
	menu.pressed.connect(_to_menu)
	col.add_child(menu)
	var quit := MenuStyle.button("Quit game")
	quit.pressed.connect(func(): get_tree().quit())
	col.add_child(quit)
	col.add_child(MenuStyle.label("Progress is saved at each lantern", 14, MenuStyle.DIM))
	MenuStyle.centre(_layer, panel)
	resume.grab_focus()


func _close() -> void:
	if is_instance_valid(_layer):
		_layer.queue_free()
	_layer = null
	get_tree().paused = false


## Same as pressing F: Ren respawns at the last lantern he touched.
func _back_to_lantern() -> void:
	_close()
	var player := get_tree().get_first_node_in_group("player")
	if player and not player.is_dead:
		player.die()


func _retry(level: String) -> void:
	_close()
	var node := get_tree().current_scene.get_node_or_null(NodePath(level))
	if node and node.has_method("retry"):
		node.retry()


func _to_menu() -> void:
	_close()
	SaveManager.quit_to_menu()
