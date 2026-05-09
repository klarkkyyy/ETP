extends Area2D

# Double check this path matches your FileSystem exactly!
@export_file("*.tscn") var target_scene: String = "res://Level_3/real_Level_3/Scenes/boss_level.tscn"

func _ready() -> void:
	# Connecting via code is fine, but ensure it's not connected 
	# twice if you also used the 'Node' tab in the editor.
	if not is_connected("body_entered", _on_body_entered):
		connect("body_entered", _on_body_entered)

func _on_body_entered(body: Node) -> void:
	if body.name == "player" or body is CharacterBody2D:
		print("Player entered portal, moving to: ", target_scene)
		call_deferred("_change_scene")
		
func _change_scene():
	var error = get_tree().change_scene_to_file(target_scene)
	if error != OK:
		print("Error: Could not check scene. Check if path is correct: ", target_scene)
