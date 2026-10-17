# story_director.gd  (autoload: StoryDirector)
# Plays the Warden's in-game story beats. It watches the scene tree instead of
# living in game.tscn, so beats are added here as data:
#   ARRIVAL_BEATS: teleport this_id -> lines, played when the player teleports there.
#   BOSS_BEATS:    boss node name   -> lines, played after that boss dies.
#   Guide echoes (story/guide_beats.gd): other fallen people who appear the
#   first time Ren meets a mechanic or picks up an echo stone.
# Each beat plays once per run (reset by the intro on NEW GAME).
# While a beat plays the game is paused; only the dialogue box runs.
extends Node

## Emitted as each beat begins playing (after any queue wait).
signal beat_started(key: String)

const HERO := "Ren"
const WARDEN := "The Warden"

const ARRIVAL_BEATS := {
	# Level 5 exit -> first boss arena.
	"teleport_g": [
		{"who": WARDEN, "text": "Stop. Do you feel that? The air is heavier here."},
		{"who": HERO, "text": "Something's watching me."},
		{"who": WARDEN, "text": "A guardian. It was someone, once. Someone who fell, like you, and never finished the climb."},
		{"who": WARDEN, "text": "Now it only remembers one thing: keeping others from leaving."},
		{"who": HERO, "text": "So I have to... beat it?"},
		{"who": WARDEN, "text": "You have to get past it. The Reach will not open the next door while it stands."},
		{"who": WARDEN, "text": "Your echoes are not just memories. Use them. Let your past fight beside you."},
		{"who": HERO, "text": "...Okay. Okay. Let's do this."},
	],
}

const BOSS_BEATS := {
	"Boss": [
		{"who": HERO, "text": "Is it... gone?"},
		{"who": WARDEN, "text": "Released. Whatever it was holding onto, it finally let go."},
		{"who": HERO, "text": "Doesn't feel like winning. It felt... sad."},
		{"who": WARDEN, "text": "Good. That means you still remember what it is to be human. Hold on to that. The Reach will try to take it from you."},
		{"who": WARDEN, "text": "Look. A door has opened. Beyond it lies the Gauntlet."},
		{"who": HERO, "text": "How much further until I'm home?"},
		{"who": WARDEN, "text": "Further than you'd like. Closer than you think."},
	],
}

const BOSS_BEAT_DELAY := 2.5  # seconds after the boss is freed, so the portal fades in first

const ARRIVAL_CUTSCENE := "res://story/arrival_cutscene.gd"
const GUIDES := preload("res://story/guide_beats.gd")
const GUIDE_RADIUS := 90.0       # px from a mechanic that counts as meeting it
const GUIDE_CHECK_EVERY := 0.2   # seconds between proximity checks
const GROUNDED_FRAMES := 8       # physics frames Ren must be on solid ground before a guide talks
const CAMERA_SETTLED_PX := 4.0   # view moving less than this per frame counts as settled (Ren walking is ~2)
# Faceless silhouette: flat colour in the sprite's shape, with a slow shimmer.
const GHOST_SHADER := """
shader_type canvas_item;
render_mode blend_add;
uniform vec4 tint : source_color = vec4(1.0);
void fragment() {
	float a = texture(TEXTURE, UV).a;
	float shimmer = 0.8 + 0.2 * sin(TIME * 3.0 + FRAGCOORD.y * 0.15);
	COLOR = vec4(tint.rgb * shimmer, a * tint.a);
}
"""

var seen := {}
## Set by the opening story; the next game.tscn load plays the arrival cutscene.
var arrival_pending := false
## Full-screen black that survives scene changes (for fades across them).
var cover: ColorRect
var box: DialogueBox
## While true, guide beats wait (arrival cutscene, the level title roll).
var hold_guides := false
## Dev bots set this false so dialogue never pauses them.
var guides_enabled := true
var _playing := false
var _queue: Array = []           # [{key, lines, guide}]
var _guide_by_path := {}         # scene/script path -> MECHANICS key
var _watched: Array = []         # [{node: WeakRef, key}]
var _check_timer := 0.0
var _hooked := {}                # instance ids already hooked by _on_node_added


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	box = DialogueBox.new()
	box.speakers[HERO] = {"color": Color(0.55, 0.8, 1.0), "pitch": 1.25}
	box.speakers[WARDEN] = {"color": Color(0.95, 0.75, 0.4), "pitch": 0.7}
	add_child(box)
	var cover_layer := CanvasLayer.new()
	cover_layer.layer = 45  # over the game, under the dialogue box
	add_child(cover_layer)
	cover = ColorRect.new()
	cover.color = Color.BLACK
	cover.set_anchors_preset(Control.PRESET_FULL_RECT)
	cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cover.hide()
	cover_layer.add_child(cover)
	for key in GUIDES.MECHANICS:
		for path in GUIDES.MECHANICS[key]["paths"]:
			_guide_by_path[path] = key
	get_tree().node_added.connect(_on_node_added)
	# A scene run directly at boot entered the tree before we were listening.
	_scan.call_deferred(get_tree().root)


func _scan(node: Node) -> void:
	if node != self:
		_on_node_added(node)
	for child in node.get_children():
		_scan(child)


func reset() -> void:
	seen.clear()
	_queue.clear()


func _on_node_added(node: Node) -> void:
	if arrival_pending and node.name == "game" and node.get_parent() == get_tree().root:
		arrival_pending = false
		var cutscene := Node.new()
		cutscene.set_script(load(ARRIVAL_CUTSCENE))
		cutscene.name = "ArrivalCutscene"
		node.add_child.call_deferred(cutscene)
		return
	# The boot-time scan and node_added can both see a node; hook it once.
	var id := node.get_instance_id()
	if _hooked.has(id):
		return
	_hooked[id] = true
	if node.has_signal("teleport_used"):
		node.teleport_used.connect(_on_teleport_used)
		_watch_mechanic(node)
	elif BOSS_BEATS.has(node.name) and node.is_in_group("boss"):
		node.tree_exited.connect(_on_boss_gone.bind(node.name, node), CONNECT_ONE_SHOT)
	elif node is Area2D and "unlocks_echo_slot" in node:
		node.body_entered.connect(_on_echo_stone.bind(node))
	else:
		_watch_mechanic(node)


# ── Guide echoes ─────────────────────────────────────────────────────────────

func _watch_mechanic(node: Node) -> void:
	var path := node.scene_file_path
	if path == "" and node.get_script():
		path = node.get_script().resource_path
	var key: String = _guide_by_path.get(path, "")
	if key == "" or seen.has("guide:" + key):
		return
	_watched.append({"node": weakref(node), "key": key})


func _on_echo_stone(body: Node, stone: Node) -> void:
	if not body.is_in_group("player") or not guides_enabled:
		return
	var slot: int = stone.unlocks_echo_slot
	if not GUIDES.ECHO_UNLOCKS.has(slot):
		return
	# Queued right away (the unlock makes other beats eligible), but it lets
	# the pickup animation play before it starts.
	var beat: Dictionary = GUIDES.ECHO_UNLOCKS[slot]
	play("echo:%d" % slot, beat["lines"], {"name": beat["guide"], "near": null, "delay": 0.8})


func _process(delta: float) -> void:
	_check_timer -= delta
	if _check_timer > 0.0 or _watched.is_empty():
		return
	_check_timer = GUIDE_CHECK_EVERY
	if hold_guides or not guides_enabled or get_tree().paused:
		return
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return
	var still: Array = []
	for entry in _watched:
		var node = entry["node"].get_ref()
		if node == null or seen.has("guide:" + entry["key"]):
			continue
		if node is Node2D and node.is_inside_tree() and _met(entry["key"], node, player) \
				and _try_guide(entry["key"], node):
			continue
		still.append(entry)
	_watched = still


## Whether Ren is "meeting" this mechanic: inside it (for `on_enter` areas,
## checked every time so a requirement met while already inside still counts),
## or within its radius of the node or any of its collision shapes (big
## hazards can have their origin far from the shape).
func _met(key: String, node: Node2D, player: Node2D) -> bool:
	var beat: Dictionary = GUIDES.MECHANICS[key]
	if beat.get("on_enter", false):
		return node is Area2D and node.overlaps_body(player)
	var radius: float = beat.get("radius", GUIDE_RADIUS)
	if node.global_position.distance_to(player.global_position) <= radius:
		return true
	for child in node.get_children():
		if child is CollisionShape2D and child.global_position.distance_to(player.global_position) <= radius:
			return true
	return false


## Queues the guide beat for `key` if it hasn't played and its requirements
## are met. Returns true when it was queued.
func _try_guide(key: String, near: Node) -> bool:
	if not guides_enabled or hold_guides or seen.has("guide:" + key):
		return false
	var beat: Dictionary = GUIDES.MECHANICS[key]
	if beat.has("requires_echo") and not GameManager.is_echo_unlocked(beat["requires_echo"]):
		return false
	play("guide:" + key, beat["lines"], {"name": beat["guide"], "near": near})
	return true


func _on_teleport_used(destination_id: String, _player: Node) -> void:
	if not ARRIVAL_BEATS.has(destination_id):
		return
	# Emitted just before the player is moved; let them land first.
	await get_tree().create_timer(0.6).timeout
	play("arrive:" + destination_id, ARRIVAL_BEATS[destination_id])


func _on_boss_gone(boss_name: String, boss: Node) -> void:
	# tree_exited also fires on scene change/reload; only count a real kill.
	if not boss.get("is_dead"):
		return
	await get_tree().create_timer(BOSS_BEAT_DELAY).timeout
	play("boss:" + boss_name, BOSS_BEATS[boss_name])


## Plays `lines` once under `key`, pausing the game meanwhile. Beats that
## arrive while another is playing wait their turn. With `guide`
## ({name, near, delay?}), that guide's echo appears beside him and "@" in the
## lines is them speaking.
func play(key: String, lines: Array, guide: Dictionary = {}) -> void:
	if seen.has(key):
		return
	seen[key] = true
	_queue.append({"key": key, "lines": lines, "guide": guide})
	if _playing:
		return
	_playing = true
	while not _queue.is_empty():
		var beat: Dictionary = _queue.pop_front()
		beat_started.emit(beat["key"])
		await _play_beat(beat["lines"], beat["guide"])
	_playing = false


func _play_beat(lines: Array, guide: Dictionary) -> void:
	var tree := get_tree()
	var ghost: Node2D = null
	if not guide.is_empty():
		await tree.create_timer(guide.get("delay", 0.0)).timeout
		var player := tree.get_first_node_in_group("player") as Node2D
		if player == null:
			return
		# Never freeze Ren mid-air: wait until he has been standing on solid
		# ground (and alive) for a few frames, however long that takes. Also
		# wait out holds (e.g. the level title sliding past) and camera
		# travel (after a portal or respawn the camera pans to catch up;
		# pausing mid-pan would leave it stuck off Ren).
		var grounded := 0
		var cam := tree.get_first_node_in_group("camera") as Camera2D
		var last_view := cam.get_screen_center_position() if cam else Vector2.ZERO
		while grounded < GROUNDED_FRAMES:
			await tree.physics_frame
			if not is_instance_valid(player) or not player.is_inside_tree():
				return  # scene changed; drop the beat
			var cam_settled := true
			if is_instance_valid(cam):
				var view := cam.get_screen_center_position()
				cam_settled = view.distance_to(last_view) < CAMERA_SETTLED_PX
				last_view = view
			var ready_to_talk: bool = player.is_on_floor() and not player.is_dead \
					and not hold_guides and cam_settled
			grounded = grounded + 1 if ready_to_talk else 0
		var look: Dictionary = GUIDES.CAST[guide["name"]]
		box.speakers[guide["name"]] = {"color": look["color"], "pitch": look["pitch"]}
		lines = lines.map(func(l): return {"who": guide["name"] if l["who"] == "@" else l["who"], "text": l["text"]})
		ghost = _spawn_ghost(player, look, guide.get("near"))
	tree.paused = true
	if ghost:
		await create_tween().tween_property(ghost, "modulate:a", 1.0, 0.5).finished
	await box.run(lines)
	if ghost:
		await create_tween().tween_property(ghost, "modulate:a", 0.0, 0.5).finished
		ghost.queue_free()
	# Let the key that closed the box go stale so the player doesn't jump.
	await tree.create_timer(0.15).timeout
	tree.paused = false


## The guide's echo: a faceless glowing silhouette standing beside Ren,
## facing him, on the side of the mechanic it talks about. It borrows Ren's
## animation frames for the outline, reshaped per person by `look.shape`.
func _spawn_ghost(player: Node2D, look: Dictionary, near) -> Node2D:
	var side := 1.0
	if near is Node2D and is_instance_valid(near):
		side = 1.0 if near.global_position.x >= player.global_position.x else -1.0
	var src: AnimatedSprite2D = player.anim
	var ghost := AnimatedSprite2D.new()
	ghost.process_mode = Node.PROCESS_MODE_ALWAYS
	ghost.sprite_frames = src.sprite_frames
	ghost.offset = src.offset
	var shape: Vector2 = look["shape"]
	ghost.scale = src.scale * shape
	ghost.flip_h = side > 0.0  # face back toward Ren
	ghost.modulate.a = 0.0
	ghost.z_index = player.z_index + 1
	var shader := Shader.new()
	shader.code = GHOST_SHADER
	var mat := ShaderMaterial.new()
	mat.shader = shader
	var c: Color = look["color"]
	mat.set_shader_parameter("tint", Color(c.r, c.g, c.b, 0.75))
	ghost.material = mat
	player.get_parent().add_child(ghost)
	# Taller shapes are raised so every silhouette stands on the same floor.
	var frame := src.sprite_frames.get_frame_texture("idle", 0)
	var lift := frame.get_height() * src.scale.y * (shape.y - 1.0) * 0.5 if frame else 0.0
	ghost.global_position = src.global_position + Vector2(30.0 * side, -3.0 - lift)
	ghost.play("idle")
	# Hover gently.
	var bob := ghost.create_tween().set_loops()
	bob.tween_property(ghost, "position:y", ghost.position.y - 3.0, 0.9).set_trans(Tween.TRANS_SINE)
	bob.tween_property(ghost, "position:y", ghost.position.y, 0.9).set_trans(Tween.TRANS_SINE)
	return ghost
