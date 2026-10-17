# display_manager.gd  (autoload: DisplayManager)
# F11 or Alt+Enter toggles fullscreen anywhere in the game. Scaling to the
# window/screen itself is handled by the project's stretch settings
# (display/window/stretch: canvas_items + keep).
extends Node


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if event.keycode == KEY_F11 or (event.keycode == KEY_ENTER and event.alt_pressed):
		toggle_fullscreen()
		get_viewport().set_input_as_handled()


func toggle_fullscreen() -> void:
	if get_window().is_embedded():
		print("DisplayManager: fullscreen is unavailable while the game is embedded in the editor's Game tab. ",
			"Untick 'Embed Game on Next Play' in the Game tab to run in a real window.")
		return
	if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
