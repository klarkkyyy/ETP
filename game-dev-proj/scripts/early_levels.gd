#early_levels.gd
# Levels 1-3 live inside game.tscn instead of being level_standalone scenes,
# so this wires them up the same way from a table: a scored run (echoes
# against the level's goal for a star, deaths and time) starts when Ren comes
# in through the level's entrance or lights one of its lanterns, and the exit
# holds for the level-clear screen (Continue goes through, Retry restarts the
# level fresh). Levels 2 and 3 get a title at their entrance like levels 4-9
# have. Lives under LevelClear.
class_name EarlyLevels
extends Node

const FONT = preload("res://assets/fonts/BoldPixels.ttf")

## id (LevelList) -> echo goal for the star, entry teleport ("" = walked
## into), exit teleport, title (placed `title_offset` from the entry teleport;
## "" = none). The goals count the doors that need something held down.
const LEVELS = {
	"level_1": {"par": 3, "entry": "", "exit": "teleport_a", "title": ""},
	"level_2": {"par": 2, "entry": "teleport_b", "exit": "teleport_c", "title": "LEVEL 2\nThe Lower Halls",
		"title_offset": Vector2(120, -70)},
	"level_3": {"par": 5, "entry": "teleport_d", "exit": "teleport_f", "title": "LEVEL 3\nThe Firelit Keep",
		"title_offset": Vector2(120, -70)},
}


func _ready() -> void:
	get_tree().node_added.connect(_on_node_added)
	GameManager.player_teleported.connect(_on_player_teleported)
	GameManager.checkpoint_changed.connect(_on_checkpoint)


func _on_node_added(node: Node) -> void:
	if node.name == "game" and node.get_parent() == get_tree().root:
		_hook.call_deferred(node)


func _hook(game: Node) -> void:
	for tp in get_tree().get_nodes_in_group("teleport"):
		if not "hold_until" in tp:
			continue
		for id in LEVELS:
			if tp.this_id == LEVELS[id]["exit"]:
				tp.hold_until = _on_exit_used.bind(id)
	for id in LEVELS:
		var e: Dictionary = LEVELS[id]
		if e["title"] != "":
			var tp := _teleport(e["entry"])
			if tp:
				_add_title(game, id, e["title"], tp.global_position + e["title_offset"])


func _teleport(id: String) -> Node2D:
	for tp in get_tree().get_nodes_in_group("teleport"):
		if tp.this_id == id:
			return tp
	return null


## Same look as the LEVEL N titles in levels 4-9: BoldPixels with a grey shadow.
func _add_title(game: Node, id: String, text: String, pos: Vector2) -> void:
	var title := Node2D.new()
	title.name = "Title_" + id
	title.z_index = 8  # over the tile layers (Level 3's foreground is 7)
	game.add_child(title)
	title.global_position = pos
	for shadow in [true, false]:
		var l := Label.new()
		l.text = text
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.add_theme_font_override("font", FONT)
		l.add_theme_font_size_override("font_size", 16)
		if shadow:
			l.add_theme_color_override("font_color", Color(0.265, 0.265, 0.265))
			l.position = Vector2(-159, -28)
		else:
			l.position = Vector2(-160, -30)
		l.size = Vector2(320, 60)
		title.add_child(l)


## Starts level `id`'s run (also used when the level select or Retry starts it).
func begin(id: String) -> void:
	if LEVELS.has(id):
		Echoes.begin_run(id, LEVELS[id]["par"])


func _on_player_teleported(from_id: String, to_id: String) -> void:
	for id in LEVELS:
		var entry: String = LEVELS[id]["entry"]
		if entry == "":
			continue
		if to_id == entry:
			begin(id)
		elif from_id == entry:
			Echoes.abort_run(id)  # went back out the way he came


## Lighting a lantern in a level that isn't being run starts its run (level 1
## has no entrance portal, and a save from before runs existed picks one up).
func _on_checkpoint(pos: Vector2) -> void:
	var game := get_tree().current_scene
	if game == null or game.name != "game":
		return
	for lantern in game.find_children("*", "Area2D", true, false):
		if lantern is SavePoint and lantern.global_position.distance_to(pos) < 1.0:
			var id := LevelList.id_for(lantern)
			if LEVELS.has(id) and Echoes.run_level() != id:
				begin(id)
				SaveManager.save()  # it saved for this lantern before the run began
			return


func _on_exit_used(tp: Node, id: String) -> bool:
	var result := Echoes.end_run(id)
	if result.is_empty():
		return false  # not running this level (came in some other way): just go
	LevelClear.open(result, _continue_through.bind(tp), retry.bind(id))
	return true


func _continue_through(tp: Node) -> void:
	tp.go()
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player:
		GameManager.set_checkpoint(player.global_position)
	SaveManager.save()


## Reloads the game world (these levels can't be reloaded on their own) and
## starts level `id` fresh, keeping what Ren has earned.
func retry(id: String) -> void:
	SaveManager.restart_level(id)
