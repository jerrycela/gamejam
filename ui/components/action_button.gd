class_name ActionButtonView
extends Button
## Native Godot control for BTN_ACTION (Figma node 5:2).
##
## Action selects the label text and the Theme type variation (PrimaryActionButton
## vs DangerActionButton for SURRENDER). Button.disabled already maps to the
## Theme's Disabled StyleBox / font color; State/Focus/Pressed are handled by
## the engine's built-in Button visuals driven by the same Theme resource.
## No color, radius, spacing or font value is hardcoded here — everything comes
## from res://ui/theme/lsbj_theme.tres.

enum Action {
	HIT,
	STAND,
	DOUBLE,
	SURRENDER,
}

const ACTION_LABELS := {
	Action.HIT: "要牌",
	Action.STAND: "停牌",
	Action.DOUBLE: "加倍",
	Action.SURRENDER: "投降",
}

const DANGER_ACTIONS := [Action.SURRENDER]

@export var action: Action = Action.HIT:
	set(value):
		action = value
		_refresh()


func _ready() -> void:
	custom_minimum_size = Vector2(
		get_theme_constant("action_button_width", "Tokens"),
		get_theme_constant("action_button_height", "Tokens"),
	)
	_refresh()


func _refresh() -> void:
	text = ACTION_LABELS.get(action, "")
	theme_type_variation = &"DangerActionButton" if action in DANGER_ACTIONS else &"PrimaryActionButton"
