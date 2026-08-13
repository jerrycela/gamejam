class_name DealerIdleView
extends TextureRect
## L3 ambient/idle placeholder (specs/003 "L3 Behavior" #6): a subtle
## breathing/pose-float loop for the static dealer illustration, driven by a
## child AnimationPlayer instead of a video track.
##
## docs/06_AI_ART_AND_MEDIA_PROMPTS.md §11 (revised 2026-08-13) is why this
## is engine-native animation and not video: the current generation backend
## has no video capability at all, and even if it did, Godot 4 only natively
## decodes Ogg Theora, whose alpha-channel support cannot carry an
## independent transparent dealer layer composited over the L3 background.
##
## The loop itself (`idle_breathe`, defined on the sibling AnimationPlayer in
## scenes/game_root.tscn) is a tiny scale + vertical-offset oscillation —
## amplitude and period are NOT sourced from a Figma motion token:
## `02 Foundations` only records discrete-transition durations
## (fast/normal/result = 120/220/420ms, docs/04), all far shorter than an
## ambient idle cycle belongs at. Chosen here instead, atmosphere not
## performance: ~1.5% scale, ~3px vertical offset, 3.6s period (midpoint of
## the 3-4s range this task specified). If Figma later adds an idle/ambient
## motion token, this should switch to reading it instead of this constant.
##
## Observable loop signal for tests (specs/003 L3-3/L3-4): is_idle_loop_active()
## and current_loop_animation() let a test assert the same loop is active
## before/after an L2 overlay, and stays active across multiple full rounds,
## without depending on wall-clock animation progress (gdUnit4 does not
## advance engine time by default).

const LOOP_ANIMATION_NAME: StringName = &"idle_breathe"

@onready var _player: AnimationPlayer = $AnimationPlayer


func _ready() -> void:
	pivot_offset = size / 2.0
	if not resized.is_connected(_on_resized):
		resized.connect(_on_resized)
	if _player.has_animation(LOOP_ANIMATION_NAME) and _player.current_animation != LOOP_ANIMATION_NAME:
		_player.play(LOOP_ANIMATION_NAME)


## True exactly when the idle breathing loop is the animation actually
## assigned and playing — the minimal "same loop flag" signal specs/003
## L3-3 asks for.
func is_idle_loop_active() -> bool:
	return _player.is_playing() and _player.current_animation == LOOP_ANIMATION_NAME


## The name of whatever animation is currently assigned, whether playing or
## not — lets a test assert "unchanged" without assuming it's always
## LOOP_ANIMATION_NAME (future L2 dealer-reaction progressions might swap in
## a different clip here without this component needing to know about it).
func current_loop_animation() -> StringName:
	return _player.current_animation


func _on_resized() -> void:
	pivot_offset = size / 2.0
