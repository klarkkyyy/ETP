#button.gd
# The main menu's NEW GAME button.
extends Button


func _on_pressed() -> void:
	owner.new_game_pressed()
