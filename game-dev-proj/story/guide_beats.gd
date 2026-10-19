# guide_beats.gd
# Data for the guide echoes: other people who were pulled into the Reach,
# failed somewhere along the climb, and stayed behind as echoes. One appears
# beside Ren (a faceless glowing silhouette) the first time he meets a
# mechanic or picks up a new echo stone, and explains it.
#
# Lore: echoes lose their faces the longer they stay in the Reach. Nobody
# knows who the Warden was. (He is Ren's own echo from an earlier attempt;
# that is the final-boss reveal. The guides only drop hints that make sense
# afterwards. Never have a guide say it outright.)
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
	# The opening area has the stone, an echo zone, a pad and a lever close
	# together, so Mira covers all of them in one short beat; `covers` marks
	# those mechanics' own beats as already told.
	1: {"guide": "Mira", "covers": ["echo_zone", "pressure_pad", "lever"], "lines": [
		{"who": "@", "text": "Hey! Over here. Don't be scared. I'm Mira. I fell in here too, a long time ago."},
		{"who": "Ren", "text": "You don't have a face."},
		{"who": "@", "text": "You lose it, the longer you stay. When you fail in the Reach, you don't leave."},
		{"who": "Ren", "text": "And the Warden?"},
		{"who": "@", "text": "Here before any of us. Nobody knows who he was. Anyway! That stone lets you leave an echo behind."},
		{"who": "@", "text": "Where the air hums, that's an echo zone. Press 1 to record, 1 again to stop. Your echo repeats it forever."},
		{"who": "@", "text": "Pads and levers need someone on them. Let your echo do it while you go on."},
		{"who": "@", "text": "Messed up? R wipes your echoes."},
	]},
	2: {"guide": "Hollis", "lines": [
		{"who": "@", "text": "A second stone. Huh. You're further along than I ever got."},
		{"who": "Ren", "text": "Who are you?"},
		{"who": "@", "text": "Hollis. I built bridges, back home. Figured this place would be easy. It's all levers and weights, right?"},
		{"who": "@", "text": "Press 2 to record a second echo. Each number keeps its own, so you can redo one without losing the other."},
		{"who": "@", "text": "One holds the door, the other is your step up. Two hands are better than one."},
		{"who": "@", "text": "The Warden helped me too, you know. Then I failed anyway. He didn't even look surprised. Like he'd seen it happen before."},
	]},
	3: {"guide": "Old Tomas", "lines": [
		{"who": "@", "text": "The third stone. Well, well. I've watched a lot of people walk past this spot. Not many picked that up."},
		{"who": "@", "text": "Press 3 for your last echo. That's as many as anyone can carry."},
		{"who": "@", "text": "They fade when you wander too far from them. Don't leave your past too far behind, boy."},
		{"who": "@", "text": "And when the guardians throw their power at you, let an echo take the hit. That's what they're for."},
		{"who": "Ren", "text": "...Thanks. Really."},
		{"who": "@", "text": "Don't thank me. Get out. Get out for all of us."},
	]},
}

## Played the first time Ren comes near (or into) one of these. Matched by the
## node's scene path, or its script path for script-only nodes.
## `requires_echo`: only once that slot is unlocked (otherwise it waits).
## `on_enter`: triggers when Ren enters the Area2D instead of by distance.
## `radius`: how close counts as meeting it (default 90 px).
const MECHANICS := {
	"spike": {"paths": ["res://scenes/spike.tscn", "res://spike.gd"],
		"guide": "Old Tomas", "lines": [
		{"who": "@", "text": "Mind the spikes, boy. Obviously."},
		{"who": "@", "text": "Dying here isn't the end. You wake at the last lantern you touched. Took me a while to decide if that's a mercy."},
	]},
	"save_point": {"paths": ["res://scenes/save_point .tscn"],
		"guide": "Old Tomas", "lines": [
		{"who": "@", "text": "See that lantern? Walk past it and the Reach remembers you there."},
		{"who": "@", "text": "Fall, and you start again from the last one. Stuck somewhere? Press F to go back to it."},
	]},
	"echo_zone": {"paths": ["res://echo_zone/echo_zone.tscn"], "on_enter": true, "requires_echo": 1,
		"guide": "Kit", "lines": [
		{"who": "@", "text": "Ooh, feel that? It hums! That's an echo zone."},
		{"who": "@", "text": "You can only record echoes inside one. Outside, it's just boring regular you."},
	]},
	"pressure_pad": {"paths": ["res://pressure_pad/pressure_pad.tscn"], "requires_echo": 1,
		"guide": "Hollis", "lines": [
		{"who": "@", "text": "Pressure pad. It holds that door open, but only while something's standing on it."},
		{"who": "Ren", "text": "And I can't stand on it and walk through the door at the same time."},
		{"who": "@", "text": "You can't. Your echo can. Record yourself standing on it, then go."},
	]},
	"pressure_pad_red": {"paths": ["res://pressure_pad/pressure_pad_red.tscn"],
		"guide": "Sable", "lines": [
		{"who": "@", "text": "A red pad. Those are wired to the heavy things. Stone doors, old mechanisms. Weapons, sometimes."},
		{"who": "@", "text": "Same rule as the others: it only works while something stands on it. Your echo is very good at standing."},
		{"who": "@", "text": "Remember them. Deeper down, a red pad might be the only thing that can hurt what's waiting for you."},
	]},
	"falling_platform": {"paths": ["res://scenes/falling_platform.tscn"],
		"guide": "Juno", "lines": [
		{"who": "@", "text": "Those floors give way a second after you land. Keep moving."},
		{"who": "@", "text": "I stood still on one. Once. Don't be me."},
	]},
	"moving_platform": {"paths": ["res://moving_platform.gd"],
		"guide": "Juno", "lines": [
		{"who": "@", "text": "Moving platforms. Jump for where it's going to be, not where it is."},
		{"who": "@", "text": "I was a goalkeeper, back home. Same idea. Didn't save me, though."},
	]},
	"portal": {"paths": ["res://scenes/teleport.tscn", "res://Level_3/real_Level_3/Scenes/portal.tscn"],
		"guide": "Sable", "lines": [
		{"who": "@", "text": "A gate. Stand in it and press E. It'll take you deeper."},
		{"who": "Ren", "text": "Deeper. Not higher?"},
		{"who": "@", "text": "In the Reach, those are the same thing."},
	]},
	"lever": {"paths": ["res://lever/lever.tscn"],
		"guide": "Hollis", "lines": [
		{"who": "@", "text": "Lever. Press E next to it."},
		{"who": "@", "text": "Your echo can pull it too, if you record yourself doing it. Now THAT'S engineering."},
	]},
	"box": {"paths": ["res://scenes/box.tscn"], "requires_echo": 1,
		"guide": "Hollis", "lines": [
		{"who": "@", "text": "Crates! Push them, stand on them, stack them. Best building blocks in the Reach."},
		{"who": "@", "text": "Your echo can push them too. Record yourself shoving one. When you stop, the crate goes back where it was..."},
		{"who": "@", "text": "...and your echo does the shoving for you. Every time it loops. Your hands stay free."},
		{"who": "@", "text": "Lost one down a pit? Wipe your echoes and they all come home."},
	]},
	"arrow_trap": {"paths": ["res://scenes/arrow_trap.tscn", "res://Level_3/real_Level_3/Scenes/ArrowTrap.tscn"],
		"guide": "Kit", "lines": [
		{"who": "@", "text": "Arrows! They shoot on a beat. Watch them once before you run. That's what I didn't do."},
	]},
	"drop_enemy": {"paths": ["res://drop_enemy/ratto.tscn", "res://drop_enemy/bateye.tscn", "res://drop_enemy/spike_slug.tscn"],
		"guide": "Brann", "lines": [
		{"who": "@", "text": "Don't fight those things. You can't. I hunted for thirty years and nothing I did even scratched them."},
		{"who": "@", "text": "But the ceiling spikes can. Lure one underneath, then drop the spikes on it."},
		{"who": "@", "text": "An echo makes good bait. Patient, and it doesn't flinch."},
	]},
	"guardian": {"paths": ["res://Level_3/real_Level_3/Scenes/trap1.tscn"], "radius": 220.0,
		"guide": "Mira", "lines": [
		{"who": "@", "text": "Ren! Psst. Don't try to hit it. Nothing you do can hurt a guardian."},
		{"who": "@", "text": "But its arena can. See the pads? They fire the traps. Put an echo on a pad while it's standing underneath."},
		{"who": "@", "text": "And those glowing orbs it throws? An echo will swallow one for you. The echo's gone after, so record a new one."},
		{"who": "@", "text": "This whole level is an echo zone. Use it to your advantage."},
		{"who": "Ren", "text": "You came all the way down here to tell me that?"},
		{"who": "@", "text": "I got this far once. I'd like to see someone get further."},
	]},
	"gauntlet": {"paths": ["res://traps/blade_trap.tscn", "res://traps/crusher.tscn", "res://traps/floor_spikes.tscn", "res://traps/spear_launcher.tscn", "res://traps/trap_door.tscn"], "radius": 170.0,
		"guide": "Vesna", "lines": [
		{"who": "@", "text": "So you beat the guardian. Welcome to the Gauntlet."},
		{"who": "@", "text": "Blades, crushers, spears. All of it keeps the same beat. Watch one full cycle, then move on the beat, not before it."},
		{"who": "Ren", "text": "How many people made it past here?"},
		{"who": "@", "text": "Ask me again at the other end."},
		{"who": "@", "text": "...You know, you move a bit like him. The Warden. Back when he still climbed."},
		{"who": "Ren", "text": "He climbed?"},
		{"who": "@", "text": "Everyone climbs, at first."},
	]},
}
