class_name TestL16ActionBarLegalActions
extends GdUnitTestSuite
## Covers specs/003 L1-6: runs a full round (BETTING -> ... -> ROUND_END ->
## NEXT_ROUND -> BETTING) against the real GameRoot scene's ActionBarView,
## asserting its button composition + enabled/disabled state matches
## RoundController.legal_actions() at every meaningful state-transition
## checkpoint — not just once at the end.
##
## No production L1 driver exists yet (see prior report: "no runtime
## bootstrap"). Where a real driver would call
## action_bar.sync_with_legal_actions(controller.legal_actions()) after a
## non-blocking player action, this test does that call directly — that's
## the orchestration contract this component pair (ActionBarView +
## PresentationController) is built to support, not new production logic.
## Where an action IS one of specs/003's two registered blocking events
## (deal, dealer hole card reveal), PresentationController drives the
## ActionBar itself via begin_*_presentation()/notify_presentation_finished(),
## exactly as it would in real play.
##
## Card sequence is fully deterministic and picked to exercise every state:
## player 8H+9C=17 (no natural), dealer up 7S / hole 6D (no peek, <10), one
## HIT draws 2H (17->19, no bust, decision now locked), STAND, dealer reveals
## 6D (13, must hit), one dealer hit draws KS (13->23, DEALER_BUST) resolving
## PLAYER_WIN and ROUND_END. Exactly the 6 cards drawn are injected, so the
## shoe is exhausted and NEXT_ROUND requires an explicit replacement shoe.


func _card(rank: int, suit: int) -> Card:
	return Card.new(rank, suit)


func _action_id_for(action: int) -> StringName:
	match action:
		ActionButtonView.Action.HIT:
			return RoundController.ACTION_HIT
		ActionButtonView.Action.STAND:
			return RoundController.ACTION_STAND
		ActionButtonView.Action.DOUBLE:
			return RoundController.ACTION_DOUBLE
		ActionButtonView.Action.SURRENDER:
			return RoundController.ACTION_SURRENDER
	return &""


## Drives ActionBar to match RoundController.legal_actions() right now (the
## role a real L1 driver would play after any non-blocking action) and
## asserts the result is exactly correct: right buttons, right order, all
## enabled.
func _assert_action_bar_matches_legal_actions(
	action_bar: ActionBarView, controller: RoundController
) -> void:
	var legal := controller.legal_actions()
	action_bar.sync_with_legal_actions(legal)

	var expected: Array[int] = []
	for action: int in ActionBarView.ACTION_ORDER:
		if legal.has(_action_id_for(action)):
			expected.append(action)

	assert_array(action_bar.button_actions()).contains_exactly(expected)
	for button in action_bar.buttons():
		assert_bool(button.disabled).is_false()


func test_full_round_keeps_action_bar_consistent_with_legal_actions_at_every_transition() -> void:
	var runner := scene_runner("res://scenes/game_root.tscn")
	var root: Node = runner.scene()
	var round_controller_node := root.get_node("RoundController") as RoundControllerNode
	var presentation_controller := root.get_node("PresentationController") as PresentationController
	var table_ui := root.get_node("L1Root/TableUI") as Node
	var action_bar := table_ui.find_child("ActionBar", true, false) as ActionBarView

	var cards: Array[Card] = [
		_card(Card.Rank.EIGHT, Card.Suit.HEARTS),
		_card(Card.Rank.SEVEN, Card.Suit.SPADES),
		_card(Card.Rank.NINE, Card.Suit.CLUBS),
		_card(Card.Rank.SIX, Card.Suit.DIAMONDS),
		_card(Card.Rank.TWO, Card.Suit.HEARTS),
		_card(Card.Rank.KING, Card.Suit.SPADES),
	]
	var ledger := BetLedger.new()
	var shoe := DeckShoe.create_injected(cards, "shoe-l1-6")
	var controller := RoundController.create_injected(shoe, ledger)
	round_controller_node.setup(controller)
	presentation_controller.setup(controller, action_bar)

	# 1) BETTING (fresh scene default): 0 registered-scope buttons (PLACE_BET/
	#    DEAL have no button in this component — see report).
	assert_int(controller.current_state).is_equal(RoundController.State.BETTING)
	_assert_action_bar_matches_legal_actions(action_bar, controller)
	assert_int(action_bar.button_count()).is_equal(0)

	assert_bool(controller.place_bet(100)).is_true()

	# 2) Still BETTING after PLACE_BET.
	_assert_action_bar_matches_legal_actions(action_bar, controller)
	assert_int(action_bar.button_count()).is_equal(0)

	# 3) DEAL is a registered blocking event: PresentationController commits
	#    the deal then opens the presentation; the panel must stay untouched
	#    (still 0 buttons, nothing to disable) while blocking.
	var deal_started := presentation_controller.begin_deal_presentation("round-l1-6")
	assert_bool(deal_started).is_true()
	assert_array(controller.legal_actions()).is_empty()
	assert_int(action_bar.button_count()).is_equal(0)

	# 4) Deal presentation completes -> PLAYER_TURN, first decision still
	#    open: HIT/STAND/DOUBLE/SURRENDER all legal.
	assert_bool(
		presentation_controller.notify_presentation_finished(presentation_controller.active_token())
	).is_true()
	assert_int(controller.current_state).is_equal(RoundController.State.PLAYER_TURN)
	_assert_action_bar_matches_legal_actions(action_bar, controller)
	assert_int(action_bar.button_count()).is_equal(4)

	# 5) HIT (not a registered blocking event in this spec) draws 2H
	#    (17 -> 19, no bust): PLAYER_TURN continues, decision now locked ->
	#    only HIT/STAND remain legal.
	assert_bool(controller.hit()).is_true()
	assert_int(controller.current_state).is_equal(RoundController.State.PLAYER_TURN)
	_assert_action_bar_matches_legal_actions(action_bar, controller)
	assert_int(action_bar.button_count()).is_equal(2)

	# 6) STAND -> DEALER_TURN: no L1 player action is legal here at all.
	assert_bool(controller.stand()).is_true()
	assert_int(controller.current_state).is_equal(RoundController.State.DEALER_TURN)
	_assert_action_bar_matches_legal_actions(action_bar, controller)
	assert_int(action_bar.button_count()).is_equal(0)

	# 7) Dealer hole card reveal is the second registered blocking event.
	var reveal_started := presentation_controller.begin_dealer_hole_reveal_presentation()
	assert_bool(reveal_started).is_true()
	assert_array(controller.legal_actions()).is_empty()
	assert_int(action_bar.button_count()).is_equal(0)

	assert_bool(
		presentation_controller.notify_presentation_finished(presentation_controller.active_token())
	).is_true()
	assert_int(controller.current_state).is_equal(RoundController.State.DEALER_TURN)
	_assert_action_bar_matches_legal_actions(action_bar, controller)
	assert_int(action_bar.button_count()).is_equal(0)

	# 8) Dealer resolves (draws KS, busts) — not a registered blocking event
	#    in this spec, driven directly. Lands in ROUND_END.
	assert_bool(controller.dealer_step()).is_true()
	assert_int(controller.current_state).is_equal(RoundController.State.ROUND_END)
	assert_int(controller.outcome()).is_equal(BlackjackOutcome.Type.DEALER_BUST)
	_assert_action_bar_matches_legal_actions(action_bar, controller)
	# NEXT_ROUND has no button in this component either (see report) — 0 is
	# the correct, verified state here, not an oversight.
	assert_int(action_bar.button_count()).is_equal(0)

	# 9) NEXT_ROUND: shoe is fully exhausted (all 6 injected cards drawn),
	#    so an explicit replacement shoe is required -> back to BETTING.
	assert_bool(controller.next_round("shoe-l1-6-round-2", 99)).is_true()
	assert_int(controller.current_state).is_equal(RoundController.State.BETTING)
	_assert_action_bar_matches_legal_actions(action_bar, controller)
	assert_int(action_bar.button_count()).is_equal(0)
