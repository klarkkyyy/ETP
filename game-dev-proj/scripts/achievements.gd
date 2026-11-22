#achievements.gd (autoload "Achievements")
# The game's achievements: the list (LIST), which are unlocked, and the pop-up
# when one is. Later each one maps to a Google Play Games achievement
# (`play_id`, filled in once they're created in the Play Console); `unlock` is
# the one place to report them from.
#
# Unlocks live in their own file, user://achievements.json, not in the save:
# like store achievements they're the player's for good, and NEW GAME (which
# wipes the save) doesn't take them away. Only sessions that save (started
# from the menu, SaveManager.active) write it, so test runs (F6) can still
# pop them up without keeping them.
#
# Most are read off the game's own state every second (levels cleared, stars,
# secrets, echo slots, the guardian), so progress made before achievements
# existed counts as soon as the save is loaded. The rest are moments, caught as
# they happen: deaths, echoes out at once, standing on echoes, guides heard,
# the stranger.
extends Node

const PATH := "user://achievements.json"

enum Rarity { COMMON, RARE, EPIC, LEGENDARY }
const RARITY_NAMES := ["COMMON", "RARE", "EPIC", "LEGENDARY"]
const RARITY_COLORS := [
	Color(0.78, 0.8, 0.86),   # common: silver
	Color(0.4, 0.75, 1.0),    # rare: blue
	Color(0.78, 0.5, 1.0),    # epic: purple
	Color(1.0, 0.8, 0.3),     # legendary: gold
]

## In display order. `hidden`: the name and text stay "???" until unlocked
## (the secrets), with `hint` shown instead. `play_id`: Google Play's id.
const LIST := [
	# The climb
	{"id": "first_steps", "title": "First Steps", "text": "Clear Level 1.", "rarity": Rarity.COMMON},
	{"id": "light_feet", "title": "Light on Your Feet", "text": "Clear Level 2, the Stacks, without dying.", "rarity": Rarity.COMMON},
	{"id": "keep_behind", "title": "Out of the Keep", "text": "Clear Level 3, the Firelit Keep.", "rarity": Rarity.COMMON},
	{"id": "released", "title": "Released", "text": "Defeat the first guardian.", "rarity": Rarity.COMMON},
	{"id": "gauntlet", "title": "Through the Gauntlet", "text": "Clear Level 6.", "rarity": Rarity.COMMON},
	{"id": "outfall", "title": "Light at the End", "text": "Clear Level 10, the Outfall.", "rarity": Rarity.RARE},
	{"id": "overseer", "title": "Out of Sight", "text": "Escape the Overseer.", "rarity": Rarity.RARE},
	# Echoes
	{"id": "second_self", "title": "A Second Pair of Hands", "text": "Unlock your second echo.", "rarity": Rarity.COMMON},
	{"id": "three_of_me", "title": "Three of Me", "text": "Have three echoes out at once.", "rarity": Rarity.COMMON},
	{"id": "own_shoulders", "title": "On Your Own Shoulders", "text": "Stand on one of your echoes.", "rarity": Rarity.COMMON},
	{"id": "tower", "title": "Tower of Echoes", "text": "Stand on an echo that is standing on another echo.", "rarity": Rarity.RARE},
	# Mastery
	{"id": "first_star", "title": "Thrifty", "text": "Earn a star: clear a level within its echo goal.", "rarity": Rarity.COMMON},
	{"id": "untouched", "title": "Untouched", "text": "Clear Level 4 or later without dying.", "rarity": Rarity.RARE},
	{"id": "not_a_scratch", "title": "Not a Scratch", "text": "Clear Level 10 without dying.", "rarity": Rarity.EPIC},
	{"id": "perfect_memory", "title": "Perfect Memory", "text": "Earn every star.", "rarity": Rarity.LEGENDARY},
	{"id": "again", "title": "Again. And Again.", "text": "Fall 100 times.", "rarity": Rarity.COMMON},
	{"id": "decades", "title": "Decades of Practice", "text": "Fall 500 times.", "rarity": Rarity.RARE},
	# The story
	{"id": "familiar_face", "title": "A Familiar Face", "text": "Catch the amber stranger's eye.", "rarity": Rarity.COMMON},
	{"id": "fallen_voices", "title": "Voices of the Fallen", "text": "Hear from all eight of the fallen.", "rarity": Rarity.RARE},
	# Secrets
	{"id": "l3_atop_the_shelves", "title": "Atop the Shelves", "text": "Find the chest above the bookshelves.", "rarity": Rarity.COMMON,
		"hidden": true, "hint": "Something is hidden in Level 3."},
	{"id": "l5_ossuary", "title": "The Ossuary", "text": "Find the room under the Undercroft.", "rarity": Rarity.RARE,
		"hidden": true, "hint": "Something is hidden in Level 5."},
	{"id": "l8_cracked_ceiling", "title": "The Cracked Ceiling", "text": "Find what's above the dripping crack.", "rarity": Rarity.EPIC,
		"hidden": true, "hint": "Something is hidden in Level 8."},
	{"id": "l10_under_grate", "title": "The Under-Grate", "text": "Find the crawlway under the grates.", "rarity": Rarity.EPIC,
		"hidden": true, "hint": "Something is hidden in Level 10."},
	{"id": "all_secrets", "title": "Nothing Stays Hidden", "text": "Find every secret.", "rarity": Rarity.LEGENDARY},
]

## Level clears that count, by the name GameManager keeps records under
## (LevelList.run_name).
const CLEARS := {"first_steps": "level_1", "keep_behind": "level_3", "gauntlet": "Level_6",
	"outfall": "Level_10", "overseer": "Boss_2"}
const DEATHLESS_FROM := 4   # "Untouched": Level 4 and later
const DEATHS := {"again": 100, "decades": 500}

const SFX := "res://audio/sfx/clear.mp3"
const TOAST_TIME := 3.2

signal unlocked_achievement(id: String)

var unlocked := {}        # id -> unix time it was unlocked
var deaths := 0           # every fall, across all runs
var guides_heard := {}    # guide name -> true
var _was_dead := false
var _check := 0.0
var _toasts: Array = []
var _toasting := false
var _layer: CanvasLayer
var _game_id := 0
var _quiet := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load()
	_layer = CanvasLayer.new()
	_layer.layer = 70   # over the game, the menus and the dialogue box
	add_child(_layer)
	StoryDirector.beat_started.connect(_on_beat)


## The entry for `id` in LIST ({} if there's none).
static func entry(id: String) -> Dictionary:
	for a in LIST:
		if a["id"] == id:
			return a
	return {}

func is_unlocked(id: String) -> bool:
	return unlocked.has(id)

func unlocked_count() -> int:
	return LIST.filter(func(a): return unlocked.has(a["id"])).size()

## Unlocks `id` (once) and pops it up (`quiet`: no pop-up). This is also
## where Google Play gets told, once it's hooked up.
func unlock(id: String, quiet := false) -> void:
	if unlocked.has(id) or entry(id).is_empty():
		return
	unlocked[id] = int(Time.get_unix_time_from_system())
	_save()
	unlocked_achievement.emit(id)
	if quiet:
		return
	_toasts.append(id)
	if not _toasting:
		_show_toasts()


# ── Watching the game ────────────────────────────────────────────────────────

func _physics_process(delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player") as CharacterBody2D
	var game := get_tree().current_scene
	if player == null or game == null or game.name != "game":
		return
	if game.get_instance_id() != _game_id:
		# just loaded: what the save already holds unlocks without pop-ups
		# (once the save has been restored into it)
		_game_id = game.get_instance_id()
		_check = 0.5
		_quiet = true
	var dead: bool = player.get("is_dead")
	if dead and not _was_dead:
		deaths += 1
		for id in DEATHS:
			if deaths >= DEATHS[id]:
				unlock(id)
		_save()
	_was_dead = dead
	if not dead:
		_check_echoes(player)
	_check -= delta
	if _check <= 0.0:
		_check = 1.0
		_check_progress(_quiet)
		_quiet = false

## What the game's state already says: levels cleared, stars, secrets,
## echo slots, the guardian.
func _check_progress(quiet := false) -> void:
	var give := func(id: String) -> void: unlock(id, quiet)
	for id in CLEARS:
		if GameManager.level_best.has(CLEARS[id]):
			give.call(id)
	if GameManager.boss_defeated:
		give.call("released")
	if GameManager.is_echo_unlocked(2):
		give.call("second_self")
	if GameManager.star_count() > 0:
		give.call("first_star")
	var all_stars := true
	for e in LevelList.LEVELS:
		if e.get("goal", false) and not GameManager.has_star(LevelList.run_name(e["id"])):
			all_stars = false
	if all_stars:
		give.call("perfect_memory")
	for level in GameManager.level_deaths:
		if GameManager.level_deaths[level] == 0 and _level_number(level) >= DEATHLESS_FROM:
			give.call("untouched")
	if GameManager.level_deaths.get("Level_2", -1) == 0:
		give.call("light_feet")
	if GameManager.level_deaths.get("Level_10", -1) == 0:
		give.call("not_a_scratch")
	var all_secrets := true
	for id in GameManager.SECRETS:
		if GameManager.secrets.has(id):
			give.call(id)
		else:
			all_secrets = false
	if all_secrets:
		give.call("all_secrets")

## "Level_7" / "level_3" -> 7 / 3; 0 for anything else (bosses).
static func _level_number(level: String) -> int:
	var n := level.get_slice("_", 1)
	return int(n) if n.is_valid_int() else 0

## Echoes out at once, and Ren standing on them.
func _check_echoes(player: CharacterBody2D) -> void:
	var out := 0
	for e in Echoes._echo_nodes:
		if is_instance_valid(e) and not e.get("_dying"):
			out += 1
	if out >= 3:
		unlock("three_of_me")
	if not player.is_on_floor():
		return
	for i in player.get_slide_collision_count():
		var hit := player.get_slide_collision(i)
		var body := hit.get_collider() as CharacterBody2D
		if body == null or hit.get_normal().y > -0.7 or not body.get_parent().is_in_group("echo"):
			continue
		unlock("own_shoulders")
		# is that echo standing on another one?
		for k in body.get_slide_collision_count():
			var under := body.get_slide_collision(k)
			var other := under.get_collider() as Node
			if other and under.get_normal().y < -0.7 and other.get_parent() and other.get_parent().is_in_group("echo"):
				unlock("tower")

## A guide beat started: note which of the fallen spoke.
func _on_beat(key: String) -> void:
	var guides = StoryDirector.GUIDES
	var who := ""
	if key.begins_with("guide:"):
		who = guides.MECHANICS.get(key.trim_prefix("guide:"), {}).get("guide", "")
	elif key.begins_with("echo:"):
		who = guides.ECHO_UNLOCKS.get(int(key.trim_prefix("echo:")), {}).get("guide", "")
	if who == "" or guides_heard.has(who):
		return
	guides_heard[who] = true
	_save()
	if guides_heard.size() >= guides.CAST.size():
		unlock("fallen_voices")


# ── The file ─────────────────────────────────────────────────────────────────

func _load() -> void:
	if not FileAccess.file_exists(PATH):
		return
	var data = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if typeof(data) != TYPE_DICTIONARY:
		return
	unlocked = data.get("unlocked", {})
	deaths = int(data.get("deaths", 0))
	for g in data.get("guides_heard", []):
		guides_heard[g] = true

func _save() -> void:
	if not SaveManager.active:
		return
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"unlocked": unlocked, "deaths": deaths,
			"guides_heard": guides_heard.keys()}, "\t"))


# ── The pop-up ───────────────────────────────────────────────────────────────

func _show_toasts() -> void:
	_toasting = true
	while not _toasts.is_empty():
		await _toast(entry(_toasts.pop_front()))
	_toasting = false

## Slides in at the top right: trophy, "ACHIEVEMENT UNLOCKED", its name and rarity.
func _toast(a: Dictionary) -> void:
	var c: Color = RARITY_COLORS[a["rarity"]]
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.04, 0.08, 0.94)
	style.border_color = c
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(10)
	panel.add_theme_stylebox_override("panel", style)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	panel.add_child(row)
	row.add_child(TrophyIcon.new(40, c))
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	row.add_child(col)
	for part in [["ACHIEVEMENT UNLOCKED", 13, MenuStyle.DIM], [a["title"], 20, MenuStyle.TEXT], [RARITY_NAMES[a["rarity"]], 13, c]]:
		var l := MenuStyle.label(part[0], part[1], part[2])
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		col.add_child(l)
	_layer.add_child(panel)
	await get_tree().process_frame   # let it size itself
	var w := get_viewport().get_visible_rect().size.x
	panel.position = Vector2(w + 10, 16)
	SoundManager.play(SFX, -8, 1.5)
	var t := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(panel, "position:x", w - panel.size.x - 16, 0.45)
	t.tween_interval(TOAST_TIME)
	t.tween_property(panel, "position:x", w + 10, 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await t.finished
	panel.queue_free()
