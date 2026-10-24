#secret_chest.gd
# The chest at the end of a hidden room. Touching it opens it, marks its
# secret found (GameManager.find_secret, which is what a store achievement
# would hang off), saves, and puts up a short banner. A chest whose secret was
# found on an earlier visit stands open. It only glows with Ren close by. Builds
# its own sprite, glow and shape, so its scene is just an Area2D with this script.
extends Area2D

## The secret's id, one of GameManager.SECRETS.
@export var secret_id: String = ""
## Shown on the banner under "SECRET FOUND".
@export var title: String = ""

const CHESTS = "res://assets/Another Metroidvania Asset Pack Vol. 1 ver. 1.7/Another Metroidvania Asset Pack Vol. 1 ver. 1.7/Props/chests/"
const SFX_OPEN = "res://audio/sfx/clear.mp3"
const FRAMES = 8
const GLOW_RANGE = 36.0   # close enough to be in its room, not on the far side of a wall

var _anim: AnimatedSprite2D
var _glow: PointLight2D

func _ready() -> void:
	collision_layer = 0
	collision_mask = 2   # the player
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(16, 16)
	shape.shape = rect
	add_child(shape)
	_anim = AnimatedSprite2D.new()
	_anim.sprite_frames = _frames()
	_anim.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_anim)
	_glow = preload("res://story/stranger.gd").glow_light(Color(1.0, 0.8, 0.45), 0.5, 0.9)
	add_child(_glow)
	_glow.energy = 0.0
	if GameManager.secrets.has(secret_id):
		_show_open()
	else:
		_anim.play("idle")
		body_entered.connect(_on_body_entered)

## The glow only shows close up: from outside the room it would give it away.
func _process(delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	var near := player != null and player.global_position.distance_to(global_position) < GLOW_RANGE
	var want := (0.3 if GameManager.secrets.has(secret_id) else 0.9) if near else 0.0
	_glow.energy = move_toward(_glow.energy, want, delta * 2.0)

func _frames() -> SpriteFrames:
	var f := SpriteFrames.new()
	f.remove_animation("default")
	for anim in [["idle", "brown_chest_closed.png", true, 8.0], ["open", "brown_chest_opening.png", false, 12.0]]:
		f.add_animation(anim[0])
		f.set_animation_loop(anim[0], anim[2])
		f.set_animation_speed(anim[0], anim[3])
		var tex: Texture2D = load(CHESTS + anim[1])
		for i in FRAMES:
			var a := AtlasTexture.new()
			a.atlas = tex
			a.region = Rect2(i * 16, 0, 16, 16)
			f.add_frame(anim[0], a)
	return f

func _show_open() -> void:
	_anim.animation = "open"
	_anim.frame = FRAMES - 1

func _on_body_entered(body: Node) -> void:
	if not body.is_in_group("player") or GameManager.secrets.has(secret_id):
		return
	body_entered.disconnect(_on_body_entered)
	GameManager.find_secret(secret_id)
	SaveManager.save()
	SoundManager.play(SFX_OPEN, -6, 1.2)
	_anim.play("open")
	_banner()

## "SECRET FOUND" and the chest's title, for a few seconds.
func _banner() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 20
	get_tree().root.add_child(layer)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER_TOP)
	box.position = Vector2(-160, 70)
	box.custom_minimum_size = Vector2(320, 0)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	layer.add_child(box)
	var head := MenuStyle.label("SECRET FOUND", 22, MenuStyle.GOLD)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(head)
	if title != "":
		var sub := MenuStyle.label(title, 14)
		sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(sub)
	box.modulate.a = 0.0
	var t := layer.create_tween()
	t.tween_property(box, "modulate:a", 1.0, 0.4)
	t.tween_interval(3.0)
	t.tween_property(box, "modulate:a", 0.0, 0.8)
	t.tween_callback(layer.queue_free)
