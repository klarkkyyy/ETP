#level_clear.gd (autoload "LevelClear")
# The screen after a level: echoes used against the goal, the star, deaths
# and time, the level's records (fewest echoes, fewest deaths, fastest time),
# then Continue (through the exit portal) or Retry (the level again, fresh).
# Levels 4-9 open it from level_standalone.gd, levels 1-3 from EarlyLevels (a
# child of this node). The game is paused while it is up.
extends Node

var _layer: CanvasLayer
var _on_continue: Callable
var _on_retry: Callable
var early: EarlyLevels


func _ready() -> void:
	early = EarlyLevels.new()
	add_child(early)


func is_open() -> bool:
	return is_instance_valid(_layer)


## `result` comes from Echoes.end_run().
func open(result: Dictionary, on_continue: Callable, on_retry: Callable) -> void:
	if is_open():
		return
	_on_continue = on_continue
	_on_retry = on_retry
	get_tree().paused = true
	_layer = MenuStyle.overlay(55)  # over the dialogue box (50)
	add_child(_layer)

	var panel := MenuStyle.panel()
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	panel.add_child(col)
	var title: String = result["level"].replace("_", " ").to_upper() + " CLEAR"
	col.add_child(MenuStyle.label(title, 32))
	col.add_child(MenuStyle.label("Echoes used: %d   Goal: %d" % [result["used"], result["goal"]], 20))
	if result["star"]:
		col.add_child(MenuStyle.label("Star earned!", 22, MenuStyle.GOLD))
	else:
		col.add_child(MenuStyle.label("Use %d or fewer echoes for a star" % result["goal"], 18, MenuStyle.DIM))
	col.add_child(MenuStyle.label("Deaths: %d   Time: %s" % [result["deaths"],
		MenuStyle.format_time(result["time"])], 20))
	if result["new_time"]:
		col.add_child(MenuStyle.label("New best time!", 18, MenuStyle.GOLD))
	col.add_child(MenuStyle.label("Best: %d echoes   %d deaths   %s" % [result["best"], result["best_deaths"],
		MenuStyle.format_time(result["best_time"])], 18, MenuStyle.DIM))

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 8)
	col.add_child(spacer)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	col.add_child(row)
	var cont := MenuStyle.button("Continue")
	var retry := MenuStyle.button("Retry")
	cont.pressed.connect(_choose.bind(true))
	retry.pressed.connect(_choose.bind(false))
	row.add_child(cont)
	row.add_child(retry)
	MenuStyle.centre(_layer, panel)
	# a frame later, so the interact press that used the portal doesn't click Continue
	cont.call_deferred("grab_focus")


func _choose(go_on: bool) -> void:
	_layer.queue_free()
	_layer = null
	get_tree().paused = false
	if go_on:
		_on_continue.call()
	else:
		_on_retry.call()
