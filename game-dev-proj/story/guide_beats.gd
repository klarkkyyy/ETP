# guide_beats.gd
# Data for the guide echoes: other people who were pulled into the Reach,
# failed somewhere along the climb, and stayed behind as echoes. One appears
# beside Ren (a faceless glowing silhouette) the first time he meets a
# mechanic or picks up a new echo stone.
#
# They hint, they don't instruct: the player works the puzzle out, the guide
# only nudges (what a thing is for, or that an echo could help). Mechanic
# beats play as speech bubbles while the game runs; the echo stone beats are
# conversations and pause it.
#
# Lore: echoes lose their faces the longer they stay in the Reach. The voice
# that spoke to Ren in the dark (the Warden) is never named before Ren meets
# him at the end: he is "???" in dialogue, and the guides won't say his name,
# out of fear ("him", "the voice"). He is Ren's own echo from an earlier
# attempt, and the amber stranger Ren keeps glimpsing (stranger.gd); that is
# the final-boss reveal. The guides only drop hints that make sense
# afterwards. Never have a guide say it outright.
#
# In `lines`, "who": "@" means this beat's guide; anything else is a speaker
# name (e.g. "Ren").
extends RefCounted

## The guides. `color` tints the silhouette and name tag, `pitch` is their
## voice blip, `shape` scales the silhouette so each reads as a different
## person (x = width, y = height).
const CAST := {
	"Mira": {"color": Color(0.45, 0.85, 1.0), "pitch": 1.4, "shape": Vector2(0.95, 0.95)},
	"Old Tomas": {"color": Color(0.95, 0.8, 0.45), "pitch": 0.8, "shape": Vector2(1.05, 1.12)},
	"Hollis": {"color": Color(0.55, 1.0, 0.7), "pitch": 1.0, "shape": Vector2(1.15, 1.05)},
	"Kit": {"color": Color(1.0, 0.6, 0.8), "pitch": 1.7, "shape": Vector2(0.85, 0.8)},
	"Juno": {"color": Color(1.0, 0.55, 0.4), "pitch": 1.2, "shape": Vector2(0.95, 1.0)},
	"Sable": {"color": Color(0.75, 0.5, 1.0), "pitch": 0.95, "shape": Vector2(0.9, 1.1)},
	"Brann": {"color": Color(0.6, 0.75, 0.6), "pitch": 0.75, "shape": Vector2(1.25, 1.15)},
	"Vesna": {"color": Color(0.85, 0.85, 0.95), "pitch": 1.05, "shape": Vector2(1.0, 1.08)},
}

## Played when Ren picks up the echo stone for that slot.
const ECHO_UNLOCKS := {
	# Ren has just watched the stranger hold the door open on the pad and
	# vanish (stranger.gd), so Mira doesn't explain pads or levers; `covers`
	# marks those mechanics' own beats as already told.
	1: {"guide": "Mira", "covers": ["pressure_pad", "lever"], "lines": [
		{"who": "@", "text": "You saw it too. The one on the pad."},
		{"who": "Ren", "text": "Who was that?"},
		{"who": "@", "text": "I don't know. Nobody does. It was here before any of us."},
		{"who": "@", "text": "I'm Mira. I fell, like you. A long time ago."},
		{"who": "Ren", "text": "You don't have a face."},
		{"who": "@", "text": "You lose it, the longer you stay. When you fail in the Reach, you don't leave."},
		{"who": "Ren", "text": "There was a voice, when I was falling. Was that you?"},
		{"who": "@", "text": "...You heard him already?"},
		{"who": "@", "text": "Don't talk about him. Not here. Things carry, in the Reach."},
		{"who": "@", "text": "That stone remembers you. Wake it, and it listens. Wake it again, and it lets go."},
		{"who": "@", "text": "It only remembers once, mind. Rest by a lantern and it forgets."},
	]},
	2: {"guide": "Hollis", "lines": [
		{"who": "@", "text": "A second stone. Huh. You're further along than I ever got."},
		{"who": "Ren", "text": "Who are you?"},
		{"who": "@", "text": "Hollis. I built bridges, back home. Figured this place would be easy. It's all levers and weights, right?"},
		{"who": "@", "text": "Two memories, then. Each one minds its own business."},
		{"who": "@", "text": "Funny how a door gets easier with a second pair of hands. Or a second pair of shoulders."},
		{"who": "@", "text": "He helped me too, you know. The voice. Then I failed anyway. He didn't even sound surprised. Like he'd heard it all before."},
	]},
	3: {"guide": "Old Tomas", "lines": [
		{"who": "@", "text": "The third stone. Well, well. I've watched a lot of people walk past this spot. Not many picked that up."},
		{"who": "@", "text": "That's as many as anyone can carry."},
		{"who": "@", "text": "They fade when you wander too far from them. Don't leave your past too far behind, boy."},
		{"who": "@", "text": "And when the guardians throw their power at you... well. Your past can't be hurt twice."},
		{"who": "Ren", "text": "Have you seen it? The one that looks like me?"},
		{"who": "@", "text": "...Get out, boy. Get out for all of us."},
	]},
}

## Played the first time Ren comes near (or into) one of these, as a speech
## bubble over the guide while the game runs. Matched by the node's scene
## path, or its script path for script-only nodes.
## `requires_echo`: only once that slot is unlocked (otherwise it waits).
## `on_enter`: triggers when Ren enters the Area2D instead of by distance.
## `radius`: how close counts as meeting it (default 90 px).
const MECHANICS := {
	"spike": {"paths": ["res://scenes/spike.tscn", "res://spike.gd"],
		"guide": "Old Tomas", "lines": [
		{"who": "@", "text": "Mind the spikes, boy."},
		{"who": "@", "text": "Dying here isn't the end. Took me a while to decide if that's a mercy."},
	]},
	"save_point": {"paths": ["res://scenes/save_point .tscn"],
		"guide": "Old Tomas", "lines": [
		{"who": "@", "text": "Lanterns. Pass one, and the Reach remembers you there."},
		{"who": "@", "text": "Lost? F takes you back to the last one."},
	]},
	"pressure_pad": {"paths": ["res://pressure_pad/pressure_pad.tscn"], "requires_echo": 1,
		"guide": "Hollis", "lines": [
		{"who": "@", "text": "That pad only holds while someone stands on it."},
		{"who": "Ren", "text": "And I can't be in two places at once."},
		{"who": "@", "text": "Can't you?"},
	]},
	"pressure_pad_red": {"paths": ["res://pressure_pad/pressure_pad_red.tscn"],
		"guide": "Sable", "lines": [
		{"who": "@", "text": "A red pad. Those are wired to the heavy things. Stone doors. Weapons, sometimes."},
		{"who": "@", "text": "Remember them. Deeper down, one might be the only thing that can hurt what's waiting."},
	]},
	"falling_platform": {"paths": ["res://scenes/falling_platform.tscn"],
		"guide": "Juno", "lines": [
		{"who": "@", "text": "Those floors don't like being stood on."},
		{"who": "@", "text": "I stood still on one. Once. Don't be me."},
	]},
	"moving_platform": {"paths": ["res://moving_platform.gd"],
		"guide": "Juno", "lines": [
		{"who": "@", "text": "Jump for where it's going to be, not where it is."},
		{"who": "@", "text": "I was a goalkeeper, back home. Same idea. Didn't save me, though."},
	]},
	"portal": {"paths": ["res://scenes/teleport.tscn", "res://Level_3/real_Level_3/Scenes/portal.tscn"],
		"guide": "Sable", "lines": [
		{"who": "@", "text": "A gate. It takes you deeper, if you ask it. E."},
		{"who": "Ren", "text": "Deeper. Not higher?"},
		{"who": "@", "text": "In the Reach, those are the same thing."},
	]},
	"lever": {"paths": ["res://lever/lever.tscn"],
		"guide": "Hollis", "lines": [
		{"who": "@", "text": "Old lever. Still works, if you lean on it."},
		{"who": "@", "text": "Doesn't care whose hand it is, either. Now THAT'S engineering."},
	]},
	"box": {"paths": ["res://scenes/box.tscn"], "requires_echo": 1,
		"guide": "Hollis", "lines": [
		{"who": "@", "text": "Crates. Push them, stand on them, stack them."},
		{"who": "@", "text": "Funny thing: when a memory ends, they go back where they were. As if nothing ever moved them."},
	]},
	"arrow_trap": {"paths": ["res://scenes/arrow_trap.tscn", "res://Level_3/real_Level_3/Scenes/ArrowTrap.tscn"],
		"guide": "Kit", "lines": [
		{"who": "@", "text": "They shoot on a beat. Watch them once before you run. That's what I didn't do."},
	]},
	"drop_enemy": {"paths": ["res://drop_enemy/ratto.tscn", "res://drop_enemy/bateye.tscn", "res://drop_enemy/spike_slug.tscn"],
		"guide": "Brann", "lines": [
		{"who": "@", "text": "Don't fight those. I hunted for thirty years and nothing I did even scratched them."},
		{"who": "@", "text": "The ceiling has teeth, though. And they love a patient bait."},
	]},
	"guardian": {"paths": ["res://Level_3/real_Level_3/Scenes/trap1.tscn"], "radius": 220.0,
		"guide": "Mira", "lines": [
		{"who": "@", "text": "Ren! Nothing you do can hurt a guardian."},
		{"who": "@", "text": "But its own arena might. Watch what the pads do."},
		{"who": "@", "text": "Those orbs it throws? Something without a heartbeat could swallow one."},
		{"who": "@", "text": "And in here, the stones never tire. Remember as much as you like."},
		{"who": "Ren", "text": "You came all the way down here to tell me that?"},
		{"who": "@", "text": "I got this far once. I'd like to see someone get further."},
	]},
	"gauntlet": {"paths": ["res://traps/blade_trap.tscn", "res://traps/crusher.tscn", "res://traps/floor_spikes.tscn", "res://traps/spear_launcher.tscn", "res://traps/trap_door.tscn"], "radius": 170.0,
		"guide": "Vesna", "lines": [
		{"who": "@", "text": "So you beat the guardian. Welcome to the Gauntlet."},
		{"who": "@", "text": "All of it keeps the same beat. Watch one full cycle."},
		{"who": "Ren", "text": "How many people made it past here?"},
		{"who": "@", "text": "Ask me again at the other end."},
		{"who": "@", "text": "...You move a bit like him, you know. Back when he still climbed."},
		{"who": "Ren", "text": "Like who?"},
		{"who": "@", "text": "Forget it. Everyone climbs, at first."},
	]},
}
