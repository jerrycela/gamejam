class_name ActionBarView
extends PanelContainer
## Native Godot control for PANEL_ACTION_BAR (Figma node 21:38).
##
## Player State (Betting/PlayerTurnFirst/PlayerTurnDecided/RoundEnd/Blocking)
## drives which BTN_ACTION instances exist, mirrored here by
## sync_with_legal_actions() being driven from RoundController.legal_actions()
## rather than this component computing anything itself.
##
## HIT/STAND/DOUBLE/SURRENDER each map to an ActionButtonView. DEAL and
## NEXT_ROUND both map to the single DealButtonView (BTN_DEAL, docs/12 node
## 9:17, approved_version 1.1.0), switched via its `label` export — that is
## exactly the change 1.1.0 introduced (one component, two labels) so the
## Betting/RoundEnd Figma variants that instance BTN_DEAL are representable
## here. PLACE_BET still has no button in this component: Bet Controls is a
## separate TableUI node, listed apart from ActionBar's four player actions
## in docs/01_GAME_AND_LAYER_SPEC.md:35-54 and docs/05_FIGMA_TO_GODOT.md:29-51.
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

## Real player-input wiring: fires whenever any button in this panel is
## pressed, carrying the RoundController action StringName that button
## represents — a GameplayController connects to this exactly once and
## never needs to know whether the press came from an ActionButtonView or
## a DealButtonView.
signal action_requested(action_id: StringName)

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
@export var deal_button_scene: PackedScene = preload("res://ui/components/deal_button.tscn")

@onready var _button_row: HBoxContainer = $ButtonRow


func _ready() -> void:
	theme_type_variation = &"ActionBarPanel"


## Rebuilds the button set to exactly what `legal_actions` calls for, in
## Figma's canonical order (DEAL/NEXT_ROUND first, matching the Betting/
## RoundEnd variant screenshots where BTN_DEAL is the only button), each
## enabled. remove_child() happens synchronously so callers can inspect the
## new composition (button_count()/buttons()/deal_button()) in the same
## frame — that guarantee comes from remove_child() leaving the tree
## immediately, not from how the old node's memory gets released, so this
## uses queue_free() rather than free(): a real player-input caller
## (GameplayController) can end up calling this from inside the very
## button's own `pressed` handler that's about to become illegal (e.g. HIT
## staying legal while STAND does, or vice versa) — Godot forbids
## synchronously free()-ing an object that's still mid-signal-emission
## ("attempted to free a locked object"), and queue_free() is exactly the
## engine's own answer to that: same effect, deferred to a safe point.
##
## PLACE_BET is intentionally ignored here — see class doc for why it has no
## ActionBar button.
func sync_with_legal_actions(legal_actions: Array) -> void:
	for child in _button_row.get_children():
		_button_row.remove_child(child)
		child.queue_free()
	if legal_actions.has(RoundController.ACTION_DEAL):
		_add_deal_button(DealButtonView.DealLabel.DEAL)
	elif legal_actions.has(RoundController.ACTION_NEXT_ROUND):
		_add_deal_button(DealButtonView.DealLabel.NEXT_ROUND)
	for action: int in ACTION_ORDER:
		var action_id: StringName = _ACTION_ID_BY_BUTTON_ACTION[action]
		if legal_actions.has(action_id):
			var button := button_scene.instantiate() as ActionButtonView
			_button_row.add_child(button)
			button.action = action
			button.disabled = false
			button.pressed.connect(_emit_action_requested.bind(action_id))


func _add_deal_button(label_variant: DealButtonView.DealLabel) -> void:
	var deal_button := deal_button_scene.instantiate() as DealButtonView
	_button_row.add_child(deal_button)
	deal_button.label = label_variant
	deal_button.disabled = false
	var action_id: StringName = (
		RoundController.ACTION_DEAL
		if label_variant == DealButtonView.DealLabel.DEAL
		else RoundController.ACTION_NEXT_ROUND
	)
	deal_button.pressed.connect(_emit_action_requested.bind(action_id))


## Every button's `pressed` connects here via .bind(action_id) — a bound
## Callable to a named method, not an inline lambda (gdUnit4's known
## lambda-adjacency test-discovery bug is specifically about hand-written
## `signal.connect(func(...): ...)`; this sidesteps it in production code
## too, not just tests).
func _emit_action_requested(action_id: StringName) -> void:
	action_requested.emit(action_id)


## Disables (or re-enables) every currently-instantiated button without
## adding/removing any — the composition-preserving half of the
## docs/03_INTERACTION_CONTRACTS.md:126 ActionBar.disabled=true contract.
## Covers both button kinds this panel can hold (ActionButtonView and
## DealButtonView) so a DEAL/NEXT_ROUND button present during a blocking
## presentation (see report to team-lead: DEAL is a registered blocking
## event) is disabled in place exactly like HIT/STAND/DOUBLE/SURRENDER.
func set_blocking_disabled(disabled: bool) -> void:
	for button in buttons():
		button.disabled = disabled
	var deal := deal_button()
	if deal != null:
		deal.disabled = disabled


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


## The at-most-one DealButtonView currently instantiated (DEAL during
## Betting, NEXT ROUND during RoundEnd), or null when neither is legal.
func deal_button() -> DealButtonView:
	for child in _button_row.get_children():
		if child is DealButtonView:
			return child
	return null


func button_count() -> int:
	return _button_row.get_child_count()
