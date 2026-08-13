class_name ValueDisplayView
extends Control
## Native Godot control for VALUE_TOTAL (Figma node 21:62).
##
## State is the Figma variant axis (Hard/Soft/Bust) and only ever drives
## color, per the Figma component description: Hard = color/text/primary,
## Soft = color/text/secondary, Bust = color/result/bust — all existing
## semantic tokens, no new colors. Value is the Figma TEXT property and is
## rendered by a Label (never baked into a texture).
##
## This component NEVER computes soft/hard/bust itself — AGENTS.md:86
## forbids L1 from calculating Blackjack results. Callers must pass in
## HandEvaluator's own result via set_from_hand_evaluation().

enum State {
	HARD,
	SOFT,
	BUST,
}

const STATE_LABELS := {
	State.HARD: "硬",
	State.SOFT: "軟",
	State.BUST: "爆牌",
}

@export var state: State = State.HARD:
	set(new_value):
		state = new_value
		_refresh()

@export var value: String = "0":
	set(new_value):
		value = new_value
		_refresh()

@onready var _value_label: Label = $VBoxContainer/ValueLabel
@onready var _state_label: Label = $VBoxContainer/StateLabel
@onready var _vbox: VBoxContainer = $VBoxContainer


func _ready() -> void:
	# Bold CJK font for the large total number specifically (team-lead's
	# instruction: button labels + this number get Bold, not the smaller
	# state label) — ui/theme/lsbj_theme.tres's ValueTotalLabel type
	# variation.
	_value_label.theme_type_variation = &"ValueTotalLabel"
	_value_label.add_theme_font_size_override(
		"font_size", get_theme_constant("value_total_font_size", "Tokens")
	)
	_state_label.add_theme_font_size_override(
		"font_size", get_theme_constant("value_total_state_font_size", "Tokens")
	)
	_refresh()


## L1-5 layout defect fix: ValueDisplayView extends plain Control (not
## Container), so unless it overrides this, Godot never propagates its
## VBoxContainer child's minimum size upward — a parent layout container
## (BottomCluster's VBoxContainer) then allocates it ~0 height, but the
## Labels still render at their natural size regardless, overflowing into
## whatever sits below (reports/viewport_qa/*.png: the "0" total covering
## CHIPS/BET and the top of PlayerHandView). Reporting the real child
## minimum size here is what makes BottomCluster give this component
## correct room in the first place.
func _get_minimum_size() -> Vector2:
	if _vbox == null:
		return Vector2.ZERO
	return _vbox.get_combined_minimum_size()


## Renders whatever HandEvaluator already decided — this is the only path
## that should feed real gameplay state into the component.
func set_from_hand_evaluation(evaluation: HandEvaluator.Evaluation) -> void:
	value = str(evaluation.total)
	if evaluation.is_bust:
		state = State.BUST
	elif evaluation.is_soft:
		state = State.SOFT
	else:
		state = State.HARD


func get_value_label() -> Label:
	return _value_label


func get_state_label() -> Label:
	return _state_label


func _refresh() -> void:
	if not is_node_ready():
		return
	_value_label.text = value
	_state_label.text = STATE_LABELS.get(state, "")
	var color: Color = _color_for_state()
	_value_label.add_theme_color_override("font_color", color)
	_state_label.add_theme_color_override("font_color", color)
	# Value's text length can change (e.g. "9" -> "21"), which can change
	# the VBoxContainer's minimum width — tell the parent layout container
	# to re-query _get_minimum_size() instead of caching a stale value.
	update_minimum_size()


func _color_for_state() -> Color:
	match state:
		State.SOFT:
			return get_theme_color("text_secondary", "Tokens")
		State.BUST:
			return get_theme_color("result_bust", "Tokens")
	return get_theme_color("text_primary", "Tokens")
