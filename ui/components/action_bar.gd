class_name ActionBarView
extends PanelContainer
## Native Godot control for PANEL_ACTION_BAR (Figma node 21:38).
##
## Player State (Betting/PlayerTurnFirst/PlayerTurnDecided/RoundEnd/Blocking)
## drives which BTN_ACTION instances exist, mirrored here by
## sync_with_legal_actions() being driven from RoundController.legal_actions()
## rather than this component computing anything itself. Only
## HIT/STAND/DOUBLE/SURRENDER map to a button in this component — PLACE_BET/
## DEAL/NEXT_ROUND have no button here since BTN_DEAL is out of specs/003's
## registered scope (see report to team-lead).
##
## Illegal actions are HIDDEN (added/removed), never merely disabled-and-
## present — Auto Layout (Container mapping, docs/05_FIGMA_TO_GODOT.md §2)
## reflows the row as buttons come and go, matching Figma's screenshots
## (4 buttons for PlayerTurnFirst, 2 for PlayerTurnDecided).
##
## EXCEPTION during presentation blocking: RoundController.legal_actions()
## returns [] while a presentation token is active, so callers must NOT feed
## that empty array into sync_with_legal_actions() during blocking — doing
## so would wrongly clear the panel to zero buttons mid-animation. Use
## set_blocking_disabled() instead, which disables the existing button set
## in place without touching composition, per the Figma component
## description's explicit warning against an empty-panel flash.

const ACTION_ORDER: Array[int] = [
	ActionButtonView.Action.HIT,
	ActionButtonView.Action.STAND,
	ActionButtonView.Action.DOUBLE,
	ActionButtonView.Action.SURRENDER,
]

const _ACTION_ID_BY_BUTTON_ACTION := {
	ActionButtonView.Action.HIT: RoundController.ACTION_HIT,
	ActionButtonView.Action.STAND: RoundController.ACTION_STAND,
	ActionButtonView.Action.DOUBLE: RoundController.ACTION_DOUBLE,
	ActionButtonView.Action.SURRENDER: RoundController.ACTION_SURRENDER,
}

@export var button_scene: PackedScene = preload("res://ui/components/action_button.tscn")

@onready var _button_row: HBoxContainer = $ButtonRow


func _ready() -> void:
	theme_type_variation = &"ActionBarPanel"


## Rebuilds the button set to exactly the HIT/STAND/DOUBLE/SURRENDER entries
## present in `legal_actions`, in Figma's canonical order, each enabled.
## Frees old buttons immediately (not queue_free()) so callers can inspect
## the result synchronously in the same frame.
func sync_with_legal_actions(legal_actions: Array) -> void:
	for child in _button_row.get_children():
		_button_row.remove_child(child)
		child.free()
	for action: int in ACTION_ORDER:
		var action_id: StringName = _ACTION_ID_BY_BUTTON_ACTION[action]
		if legal_actions.has(action_id):
			var button := button_scene.instantiate() as ActionButtonView
			_button_row.add_child(button)
			button.action = action
			button.disabled = false


## Disables (or re-enables) every currently-instantiated button without
## adding/removing any — the composition-preserving half of the
## docs/03_INTERACTION_CONTRACTS.md:126 ActionBar.disabled=true contract.
func set_blocking_disabled(disabled: bool) -> void:
	for button in buttons():
		button.disabled = disabled


func buttons() -> Array[ActionButtonView]:
	var result: Array[ActionButtonView] = []
	for child in _button_row.get_children():
		if child is ActionButtonView:
			result.append(child)
	return result


func button_actions() -> Array[int]:
	var result: Array[int] = []
	for button in buttons():
		result.append(button.action)
	return result


func button_count() -> int:
	return _button_row.get_child_count()
