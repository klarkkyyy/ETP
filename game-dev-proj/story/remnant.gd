#remnant.gd
# What's left of someone who didn't make it: a faint, faceless grey echo
# frozen in one moment of their climb (mid-jump, hanging on a wall, sitting
# where they gave up). It fades away when Ren comes near, and stays gone for
# the run. Set dressing for the dark outside the castle; it says nothing.
extends Node2D

@export var pose: String = "idle"   # one of Ren's animations
@export var pose_frame: int = 0
@export var face_right: bool = true
@export var radius: float = 70.0

const TINT = Color(0.62, 0.68, 0.8, 0.32)
const SHADER := """
shader_type canvas_item;
render_mode unshaded;
uniform vec4 tint : source_color = vec4(1.0);
void fragment() {
	float a = texture(TEXTURE, UV).a;
	float drift = 0.85 + 0.15 * sin(TIME * 1.3 + FRAGCOORD.x * 0.05);
	COLOR = vec4(tint.rgb, a * tint.a * drift);
}
"""

var _gone := false

func _ready() -> void:
	if StoryDirector.seen.has(_key()):
		queue_free()
		return
	await get_tree().process_frame
	var player := get_tree().get_first_node_in_group("player")
	var src: AnimatedSprite2D = player.get_node("animations")
	var s := AnimatedSprite2D.new()
	s.sprite_frames = src.sprite_frames
	s.position = src.position
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	s.flip_h = not face_right
	s.animation = pose
	s.frame = pose_frame
	s.pause()
	var mat := ShaderMaterial.new()
	mat.shader = Shader.new()
	mat.shader.code = SHADER
	mat.set_shader_parameter("tint", TINT)
	s.material = mat
	add_child(s)

func _key() -> String:
	return "remnant:" + str(get_path())

func _process(_delta: float) -> void:
	if _gone:
		return
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player and player.global_position.distance_to(global_position) < radius:
		_gone = true
		StoryDirector.seen[_key()] = true
		var t := create_tween()
		t.tween_property(self, "modulate:a", 0.0, 1.4).set_trans(Tween.TRANS_SINE)
		t.tween_callback(queue_free)
