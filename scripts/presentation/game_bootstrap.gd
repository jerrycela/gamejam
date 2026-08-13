class_name GameBootstrap
extends Node
## Wires GameRoot's RoundControllerNode and PresentationController together
## at scene load, so the scene is actually playable the moment it's opened —
## not just a disconnected tree of components that only tests ever drive
## (the SPEC REQUIRED gap both prior agents flagged: "no production
## bootstrap exists").
##
## team-lead's ruling on scope: this is an implementation detail (how a
## startup seed gets produced), not a No-Guessing product rule.
## AGENTS.md §9's No-Guessing list covers deck count/penetration/soft-17/
## payouts/content scale/art style — not "how does the app boot". The
## requirement to record the shoe seed for reproducibility already exists
## (docs/02_BLACKJACK_RULES.md §8: "指定 Godot RandomNumberGenerator／
## Fisher-Yates，並記錄 Shoe seed 與每局起始 draw index") — this class is
## the first caller of that existing requirement, not a new decision.
## RoundController.next_round()'s explicit shoe_id/shuffle_seed inputs
## (Task 9) are the exact same mechanism this reuses for the very first
## shoe, so no new core surface is introduced (scripts/core/ stays
## untouched).

@onready var _round_controller_node: RoundControllerNode = get_node("../RoundController")
@onready var _presentation_controller: PresentationController = get_node("../PresentationController")
@onready var _action_bar: ActionBarView = get_node("../L1Root/TableUI").find_child("ActionBar", true, false)
@onready var _fallback_overlay: Control = get_node("../L2Root/ResultOverlay")

var controller: RoundController = null

var _last_shoe_id: String = ""
var _last_shuffle_seed: int = 0


func _ready() -> void:
	bootstrap(_generate_shoe_id(), _generate_shuffle_seed())


## The production entry point AND the test seam (same pattern as
## PresentationController's force_*_for_test() methods): _ready() calls this
## once with a freshly generated shoe_id/seed; a test can call it again with
## fixed values to replace the random boot deterministically, since
## docs/02 §8 requires the seed be reproducible, not merely logged.
func bootstrap(shoe_id: String, shuffle_seed: int) -> void:
	_last_shoe_id = shoe_id
	_last_shuffle_seed = shuffle_seed
	print("GameBootstrap: starting round with shoe_id=%s shuffle_seed=%d" % [shoe_id, shuffle_seed])

	var shoe := DeckShoe.create_runtime(shoe_id, shuffle_seed)
	var ledger := BetLedger.new()
	controller = RoundController.create_injected(shoe, ledger)

	_round_controller_node.setup(controller)
	_presentation_controller.setup(controller, _action_bar, _fallback_overlay)
	_action_bar.sync_with_legal_actions(controller.legal_actions())


## Test-facing record of what was actually passed to DeckShoe.create_runtime()
## at the last bootstrap() call — the observable half of docs/02 §8's
## logging requirement (the other half is the print() line above).
func last_shoe_id() -> String:
	return _last_shoe_id


func last_shuffle_seed() -> int:
	return _last_shuffle_seed


func _generate_shoe_id() -> String:
	return "shoe-%d-%d" % [Time.get_unix_time_from_system(), Time.get_ticks_usec()]


func _generate_shuffle_seed() -> int:
	return randi()
