#level_list.gd
# The levels in play order, for the level select. A level starts either at a
# lantern ("start", a node path in game.tscn) or at its level_standalone start
# ("level", the level's root node in game.tscn). A level is unlocked once Ren
# touches one of its lanterns (see `id_for`). `goal` levels have an echo goal
# and a star.
class_name LevelList

const THUMBS = "res://MENU/level_thumbs/%s.png"

const LEVELS = [
	{"id": "level_1", "label": "LEVEL 1", "start": "level 1/roomSections/room1/SavePoint2"},
	{"id": "level_2", "label": "LEVEL 2", "start": "level 2/room1/SavePoint2"},
	{"id": "level_3", "label": "LEVEL 3", "level": "Level_3"},
	{"id": "level_4", "label": "LEVEL 4", "level": "Level_4", "goal": true},
	{"id": "level_5", "label": "LEVEL 5", "level": "Level_5", "goal": true},
	{"id": "boss", "label": "BOSS", "start": "boss/SavePoint2"},
	{"id": "level_6", "label": "LEVEL 6", "level": "Level_6", "goal": true},
	{"id": "level_7", "label": "LEVEL 7", "level": "Level_7", "goal": true},
	{"id": "level_8", "label": "LEVEL 8", "level": "Level_8", "goal": true},
	{"id": "level_9", "label": "LEVEL 9", "level": "Level_9", "goal": true},
]

## game.tscn's top-level node for each level -> level id ("tutorial" for the
## opening area, which comes before every level)
const ROOTS = {
	"outside": "tutorial", "start": "tutorial", "tutorial": "tutorial",
	"level 1": "level_1", "level 2": "level_2", "Level_3": "level_3", "boss": "boss",
	"Level_4": "level_4", "Level_5": "level_5", "Level_6": "level_6",
	"Level_7": "level_7", "Level_8": "level_8", "Level_9": "level_9",
}

static func entry(id: String) -> Dictionary:
	for e in LEVELS:
		if e["id"] == id:
			return e
	return {}

## The level a node in the game belongs to ("" for the tutorial area etc.).
static func id_for(node: Node) -> String:
	var game := node.get_tree().current_scene
	while node and node.get_parent() != game:
		node = node.get_parent()
	return ROOTS.get(str(node.name), "") if node else ""

## Where Ren starts the level `id` in the running game.
static func start_position(game: Node, id: String) -> Vector2:
	var e := entry(id)
	if e.has("level"):
		return game.get_node(NodePath(e["level"]))._start_node().global_position
	return game.get_node(NodePath(e["start"])).global_position

## The star for a goal level (GameManager keys its stars by the level node's name).
static func has_star(id: String) -> bool:
	var e := entry(id)
	return e.has("goal") and GameManager.has_star(e["level"])
