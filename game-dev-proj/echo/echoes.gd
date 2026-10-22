#echoes.gd (autoload "Echoes")
# Ren can record an echo anywhere. Each unlocked slot (1-3) can be recorded
# once; finishing a recording spends that slot and greys out its icon in the
# HUD. Reaching a new checkpoint or respawning (dying, or F) gives every slot
# back, and so does R, which also wipes the echoes. Levels with an echo par
# (level_standalone.gd) count every echo recorded in a run, re-recordings
# included, and award a star for clearing at or under par.
# During the boss fight the budget is lifted (`unlimited`).
extends Node

const EchoScene = preload("res://echo/echo.tscn")
const FONT = preload("res://assets/fonts/BoldPixels.ttf")
const ICON_SHEET = preload("res://assets/platformer_metroidvania asset pack v1.01/platformer_metroidvania asset pack v1.01/herochar sprites(new)/herochar_idle_anim_strip_4.png")
const SFX_CLEAR = "res://audio/sfx/clear.mp3"
const SFX_EMPTY = "res://audio/sfx/woosh_r.mp3"

const MAX_SLOTS = 3
## Echoes further than this from Ren pause and fade out (0 = always active).
const ACTIVATION_RANGE = 600.0
# HUD icon tints: echo.gd's slot colours, with slot 3 lifted so it reads on dark rooms
const ICON_COLORS = [Color(0.4, 0.8, 1.0), Color(0.7, 0.3, 1.0), Color(0.75, 0.75, 0.8)]
const USED_COLOR = Color(0.3, 0.3, 0.32, 0.55)

signal echo_saved(slot: int)
signal echoes_cleared()

var player: CharacterBody2D = null
var is_recording: bool = false
var active_slot: int = -1
var unlimited: bool = false:
	set(value):
		unlimited = value
		_update_hud()

var _spent: Array[bool] = [false, false, false]
var _recording: Array = []
var _echo_nodes: Array = [null, null, null]
var _crates_at_start: Dictionary = {}  # crate -> global position when the recording began
var _player_was_dead := false

# the level run being scored (see begin_run / end_run)
var _run_level: String = ""
var _run_par: int = -1
var _run_used: int = 0

var _hud: CanvasLayer
var _icons: Array[Panel] = []
var _run_label: Label
var _banner: Label
var _banner_tween: Tween


func _ready() -> void:
	_build_hud()
	GameManager.checkpoint_changed.connect(func(_pos): refill())
	GameManager.echo_unlocked.connect(func(_slot): _update_hud())
	GameManager.player_teleported.connect(func(_from, _to): stop_recording())


func _physics_process(_delta: float) -> void:
	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player") as CharacterBody2D
		_player_was_dead = false
		_update_hud()
		if player == null:
			return
	var dead: bool = player.get("is_dead")
	if _player_was_dead and not dead:
		refill()  # respawned at the checkpoint
	_player_was_dead = dead

	if is_recording and not dead:
		var sprite: AnimatedSprite2D = player.get_node("animations")
		_recording.append({
			"pos":    player.global_position,
			"flip_h": sprite.flip_h,
			"anim":   sprite.animation,
			"interact": Input.is_action_just_pressed("interact")
		})

	for echo_node in _echo_nodes:
		if is_instance_valid(echo_node):
			echo_node.set_active(player.global_position.distance_to(echo_node.global_position) <= ACTIVATION_RANGE)

	if is_recording:
		_set_icon_alpha(active_slot, 0.55 + 0.45 * sin(Time.get_ticks_msec() / 120.0))


func _unhandled_input(event: InputEvent) -> void:
	if not is_instance_valid(player) or player.get("is_dead") or player.get("controls_locked"):
		return
	if event.is_action_pressed("clear_echoes"):
		clear_echoes()
		return
	for slot in range(1, MAX_SLOTS + 1):
		if event.is_action_pressed("echo_slot_%d" % slot):
			if not GameManager.is_echo_unlocked(slot):
				print("Echo slot ", slot, " is locked")
				return
			_handle_slot_press(slot - 1)
			return


# ── Budget ────────────────────────────────────────────────────────────────────
func is_spent(slot: int) -> bool:
	return not unlimited and _spent[slot]

## Gives every slot back (new checkpoint, respawn, new level). Echoes stay.
func refill() -> void:
	for i in MAX_SLOTS:
		_spent[i] = false
	_update_hud()


# ── Recording ─────────────────────────────────────────────────────────────────
func _handle_slot_press(slot: int) -> void:
	if is_recording and active_slot == slot:
		_finish_recording()
		return
	if is_spent(slot):
		SoundManager.play(SFX_EMPTY, -10, 1.4)
		_shake_icon(slot)
		return
	if is_recording:
		_finish_recording()
	_start_recording(slot)

func _start_recording(slot: int) -> void:
	_recording = []
	active_slot = slot
	is_recording = true
	# remember where the crates are, so the echo can redo any pushing (see _finish_recording)
	_crates_at_start.clear()
	for crate in get_tree().get_nodes_in_group("box"):
		_crates_at_start[crate] = crate.global_position
	EchoFlash.flash_start(slot + 1)

func _finish_recording() -> void:
	if not is_recording:
		return
	is_recording = false
	# Crates Ren pushed while recording go back, and his echo pushes them instead.
	for crate in _crates_at_start:
		if is_instance_valid(crate):
			crate.global_position = _crates_at_start[crate]
			crate.velocity = Vector2.ZERO
	_crates_at_start.clear()
	EchoFlash.flash_stop(active_slot + 1)
	if _recording.size() >= 2:
		_spawn_echo(active_slot, _recording.duplicate(true))
		if not unlimited:
			_spent[active_slot] = true
		if _run_level != "":
			_run_used += 1
		echo_saved.emit(active_slot + 1)
	active_slot = -1
	_recording = []
	_update_hud()

## Ends a recording in progress and keeps what was recorded (death, teleport).
func stop_recording() -> void:
	_finish_recording()

func _spawn_echo(slot: int, frames: Array) -> void:
	if is_instance_valid(_echo_nodes[slot]):
		_echo_nodes[slot].die()
	var echo_node = EchoScene.instantiate()
	get_tree().current_scene.add_child(echo_node)
	echo_node.setup(frames, ACTIVATION_RANGE > 0.0, slot)
	echo_node.global_position = frames[0]["pos"]
	_echo_nodes[slot] = echo_node

## R: wipes every echo and gives every slot back.
func clear_echoes() -> void:
	if is_recording:
		is_recording = false
		EchoFlash.flash_stop(active_slot + 1)
		active_slot = -1
		_recording = []
	var any := false
	for i in MAX_SLOTS:
		if is_instance_valid(_echo_nodes[i]):
			_echo_nodes[i].die()
			any = true
		_echo_nodes[i] = null
	if any:
		SoundManager.play(SFX_CLEAR, -12, 0.9)
	echoes_cleared.emit()
	refill()


# ── Level runs and stars ──────────────────────────────────────────────────────
## A level with an echo par started: count echoes from here.
func begin_run(level_name: String, par: int) -> void:
	_run_level = level_name
	_run_par = par
	_run_used = 0
	clear_echoes()

## Left a level without clearing it (back through its entrance).
func abort_run(level_name: String) -> void:
	if _run_level == level_name:
		_run_level = ""
		_update_hud()

## Cleared the level: score it against par and show the banner.
func end_run(level_name: String) -> void:
	if _run_level != level_name:
		return
	_run_level = ""
	var star: bool = _run_used <= _run_par
	var best: int = GameManager.record_level_clear(level_name, _run_used, star)
	var title := level_name.replace("_", " ")
	var text := "%s clear\nEchoes used: %d   Goal: %d\n" % [title, _run_used, _run_par]
	text += "Star earned!" if star else "Use %d or fewer echoes for a star" % _run_par
	if best < _run_used:
		text += "\nBest: %d" % best
	show_banner(text, Color(1.0, 0.85, 0.35) if star else Color(0.9, 0.9, 0.95))
	_update_hud()


# ── HUD ───────────────────────────────────────────────────────────────────────
# One framed box per unlocked slot, top left like a health bar: Ren's
# silhouette in the slot's colour, or dim grey once that slot is spent.
const SILHOUETTE = """shader_type canvas_item;
uniform vec4 tint : source_color = vec4(1.0);
void fragment() { COLOR = vec4(tint.rgb, texture(TEXTURE, UV).a * tint.a); }"""

func _build_hud() -> void:
	_hud = CanvasLayer.new()
	_hud.layer = 30  # under the boss HUD (40), story overlay and dialogue box
	add_child(_hud)
	var row := HBoxContainer.new()
	row.position = Vector2(14, 12)
	row.add_theme_constant_override("separation", 6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(row)
	var shader := Shader.new()
	shader.code = SILHOUETTE
	for i in MAX_SLOTS:
		var box := Panel.new()
		box.custom_minimum_size = Vector2(44, 44)
		box.pivot_offset = Vector2(22, 22)
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.05, 0.05, 0.09, 0.6)
		style.set_border_width_all(2)
		style.set_corner_radius_all(6)
		box.add_theme_stylebox_override("panel", style)
		var frame := AtlasTexture.new()
		frame.atlas = ICON_SHEET
		frame.region = Rect2(0, 0, 16, 16)
		var icon := TextureRect.new()
		icon.texture = frame
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.stretch_mode = TextureRect.STRETCH_SCALE
		icon.position = Vector2(6, 4)
		icon.size = Vector2(32, 32)
		icon.material = ShaderMaterial.new()
		icon.material.shader = shader
		box.add_child(icon)
		var number := Label.new()
		number.text = str(i + 1)
		number.add_theme_font_override("font", FONT)
		number.add_theme_font_size_override("font_size", 14)
		number.add_theme_color_override("font_outline_color", Color(0.04, 0.04, 0.08))
		number.add_theme_constant_override("outline_size", 4)
		number.position = Vector2(31, 24)
		box.add_child(number)
		row.add_child(box)
		_icons.append(box)

	_run_label = Label.new()
	_run_label.position = Vector2(16, 60)
	_run_label.add_theme_font_override("font", FONT)
	_run_label.add_theme_font_size_override("font_size", 14)
	_run_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9))
	_run_label.add_theme_color_override("font_outline_color", Color(0.04, 0.04, 0.08))
	_run_label.add_theme_constant_override("outline_size", 4)
	_hud.add_child(_run_label)

	_banner = Label.new()
	_banner.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_banner.offset_left = -260
	_banner.offset_right = 260
	_banner.offset_top = 70
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.add_theme_font_override("font", FONT)
	_banner.add_theme_font_size_override("font_size", 20)
	_banner.add_theme_color_override("font_outline_color", Color(0.04, 0.04, 0.08))
	_banner.add_theme_constant_override("outline_size", 6)
	_banner.modulate.a = 0.0
	_hud.add_child(_banner)
	_update_hud()

func _set_icon_alpha(slot: int, alpha: float) -> void:
	var tint: Color = USED_COLOR if is_spent(slot) else ICON_COLORS[slot]
	tint.a *= alpha
	(_icons[slot].get_child(0) as TextureRect).material.set_shader_parameter("tint", tint)

func _update_hud() -> void:
	if _icons.is_empty():
		return
	var any_unlocked := false
	for i in MAX_SLOTS:
		var box := _icons[i]
		box.visible = GameManager.is_echo_unlocked(i + 1)
		any_unlocked = any_unlocked or box.visible
		var spent := is_spent(i)
		var style := box.get_theme_stylebox("panel") as StyleBoxFlat
		style.border_color = USED_COLOR if spent else ICON_COLORS[i]
		(box.get_child(1) as Label).add_theme_color_override("font_color", Color(0.5, 0.5, 0.55) if spent else Color(0.95, 0.95, 1.0))
		_set_icon_alpha(i, 1.0)
	_hud.visible = any_unlocked and is_instance_valid(player)
	if unlimited:
		_run_label.text = "Echoes are free here"
	elif _run_level != "":
		_run_label.text = "Echoes used: %d   Goal: %d" % [_run_used, _run_par]
	else:
		_run_label.text = ""

func _shake_icon(slot: int) -> void:
	var box := _icons[slot]
	var tw := box.create_tween()
	for dx in [-3.0, 3.0, -2.0, 0.0]:
		tw.tween_property(box, "rotation_degrees", dx * 3.0, 0.04)

func show_banner(text: String, color: Color = Color.WHITE) -> void:
	_banner.text = text
	_banner.add_theme_color_override("font_color", color)
	if _banner_tween:
		_banner_tween.kill()
	_banner_tween = _banner.create_tween()
	_banner_tween.tween_property(_banner, "modulate:a", 1.0, 0.3)
	_banner_tween.tween_interval(3.5)
	_banner_tween.tween_property(_banner, "modulate:a", 0.0, 0.6)
