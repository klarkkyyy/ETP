#touch_hints.gd
# On touch screens the in-world hints shouldn't talk about keys. TouchControls
# calls `adapt` for every node that enters the tree (so levels rebuilt by
# Retry are covered too): keyboard key pictures and the "/" between them are
# hidden, and hint labels that name keys get touch wording. Dialogue lines go
# through `text` as well (story/dialogue_box.gd).
class_name TouchHints

const KEY_ART := "res://assets/keys/"

## Whole label texts swapped on touch (keys are the PC texts as written).
const LABELS := {
	"Start / Stop\nEcho Recording": "Tap an echo icon\nto start / stop recording",
	"   for\n2nd Echo": "Tap the 2nd\necho icon",
	"Clear Echoe/s": "↻ ALL clears echoes",
	"Out of echoes?\n[R] clears them all.": "Out of echoes?\n↻ ALL clears them all.",
	"[1] [2] [3]: walk to a pad, wait there, stop": "Tap an echo icon, walk to a pad, wait, tap it again",
	"Pull it, then climb before the water does.\nOut of echoes? Shift + 1-3 lets one go.":
		"Pull it, then climb before the water does.\nOut of echoes? Tap a used echo icon to let it go.",
}

## Parts of other texts (dialogue, exit hints) swapped on touch.
const PARTS := {
	"[E] ": "",
	"if you ask it. E.": "if you ask it.",
}

static func text(s: String) -> String:
	if LABELS.has(s):
		return LABELS[s]
	for k in PARTS:
		s = s.replace(k, PARTS[k])
	return s

static func adapt(node: Node) -> void:
	if node is Label:
		var l := node as Label
		var parent := l.get_parent()
		if l.text == "/" and parent and (parent.name == "keys" or (parent.get_parent() and parent.get_parent().name == "keys")):
			l.visible = false   # the "/" between two key pictures
		else:
			var t := text(l.text)
			if t != l.text:
				l.text = t
	elif node is Sprite2D or node is TextureRect:
		var tex: Texture2D = node.get("texture")
		if _is_key_art(tex):
			(node as CanvasItem).visible = false
	elif node is AnimatedSprite2D:
		var frames := (node as AnimatedSprite2D).sprite_frames
		if frames:
			for a in frames.get_animation_names():
				if frames.get_frame_count(a) > 0 and _is_key_art(frames.get_frame_texture(a, 0)):
					(node as CanvasItem).visible = false
					return

static func _is_key_art(tex: Texture2D) -> bool:
	if tex is AtlasTexture:
		tex = (tex as AtlasTexture).atlas
	return tex != null and tex.resource_path.begins_with(KEY_ART)
