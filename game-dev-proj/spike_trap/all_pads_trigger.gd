#all_pads_trigger.gd
# Fires a trap only while every listed pressure pad is held at the same time,
# e.g. one held by an echo and one by the player. Releasing any pad lets go.
#
# Add it to a plain Node, list the pads and the target (spike_trap.tscn or
# anything with activate_trap()/deactivate_trap()) in the Inspector, and leave
# the pads' own linked_trap empty so they don't fire the trap on their own.
extends Node

signal all_pressed()
signal released()

@export var pads: Array[NodePath] = []
@export var target: NodePath

var _pads: Array[Node] = []
var _active: bool = false

func _ready() -> void:
	for path in pads:
		var pad := get_node_or_null(path)
		if pad and pad.has_signal("pad_activated"):
			_pads.append(pad)
			pad.pad_activated.connect(_update)
			pad.pad_deactivated.connect(_update)

func _update() -> void:
	var all_held := not _pads.is_empty() and _pads.all(func(p): return p.is_pressed)
	if all_held == _active:
		return
	_active = all_held
	var t := get_node_or_null(target)
	if _active:
		emit_signal("all_pressed")
		if t and t.has_method("activate_trap"):
			t.activate_trap()
	else:
		emit_signal("released")
		if t and t.has_method("deactivate_trap"):
			t.deactivate_trap()
