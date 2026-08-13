class_name TestGameplayController
extends GdUnitTestSuite
## Covers the new player-input task: a real person must be able to play a
## full round with the mouse. GameplayController is the piece that was
## entirely missing — zero buttons had a `pressed` connection anywhere in
## the codebase before this (grep confirmed it), so pressing anything did
## nothing.
##
## Every action here is driven through PresentationController's real
## begin_*_presentation()/notify_presentation_finished() path, never a direct
## RoundController.deal()/dealer_step() bypass — docs/03_INTERACTION_CONTRACTS.md's
## input barrier (L2-1~L2-3) only means something if the real entry points are
## used.
##
## Boundary this suite is honest about: gdUnit4 does not transport real
## InputEvents in headless mode, so "does a physical mouse click reach the
## Button" is NOT covered here — every test drives the exact same signal
## (`.pressed.emit()`) a real click would fire, which is the boundary
## test_l3_root_mouse_filter.gd already documents for this codebase.


func _card(rank: int, suit: int) -> Card:
	return Card.new(rank, suit)


class Harness:
	extends RefCounted

	var controller: RoundController
	var ledger: BetLedger
	var presentation: PresentationController
	var action_bar: ActionBarView
	var dealer_hand_view: HBoxContainer
	var player_hand_view: HBoxContainer
	var hand_total: ValueDisplayView
	var chips_label: Label
	var bet_label: Label
	var result_banner: Label
	var gameplay: GameplayController


## Builds a full synthetic UI (no game_root.tscn dependency) so these tests
## can pin down GameplayController's own contract in isolation. A separate
## end-to-end test below drives the real scene for the "does the whole chain
## actually connect" proof.
func _make_harness(cards: Array[Card], shoe_id: String) -> Harness:
	var harness := Harness.new()
	harness.ledger = BetLedger.new()
	var shoe := DeckShoe.create_injected(cards, shoe_id)
	harness.controller = RoundController.create_injected(shoe, harness.ledger)

	harness.presentation = auto_free(PresentationController.new())
	add_child(harness.presentation)

	var action_bar_runner := scene_runner("res://ui/components/action_bar.tscn")
	harness.action_bar = action_bar_runner.scene() as ActionBarView

	harness.dealer_hand_view = auto_free(HBoxContainer.new())
	add_child(harness.dealer_hand_view)
	harness.player_hand_view = auto_free(HBoxContainer.new())
	add_child(harness.player_hand_view)

	var hand_total_runner := scene_runner("res://ui/components/value_display.tscn")
	harness.hand_total = hand_total_runner.scene() as ValueDisplayView

	harness.chips_label = auto_free(Label.new())
	add_child(harness.chips_label)
	harness.bet_label = auto_free(Label.new())
	add_child(harness.bet_label)
	harness.result_banner = auto_free(Label.new())
	add_child(harness.result_banner)

	harness.gameplay = auto_free(GameplayController.new())
	add_child(harness.gameplay)
	harness.gameplay.setup(
		harness.controller,
		harness.ledger,
		harness.presentation,
		harness.action_bar,
		harness.dealer_hand_view,
		harness.player_hand_view,
		harness.hand_total,
		harness.chips_label,
		harness.bet_label,
		harness.result_banner,
	)
	harness.presentation.setup(harness.controller, harness.action_bar, null)
	return harness


## Same deterministic script as tests/ui/test_l1_6_action_bar_legal_actions.gd:
## player 8H+9C=17 (no natural), dealer up 7S / hole 6D (no peek, <10), one
## HIT draws 2H (17->19), STAND, dealer reveals 6D (13, must hit), one dealer
## hit draws KS (13->23, DEALER_BUST) resolving PLAYER_WIN.
func _full_round_cards() -> Array[Card]:
	return [
		_card(Card.Rank.EIGHT, Card.Suit.HEARTS),
		_card(Card.Rank.SEVEN, Card.Suit.SPADES),
		_card(Card.Rank.NINE, Card.Suit.CLUBS),
		_card(Card.Rank.SIX, Card.Suit.DIAMONDS),
		_card(Card.Rank.TWO, Card.Suit.HEARTS),
		_card(Card.Rank.KING, Card.Suit.SPADES),
	]


func test_pressing_deal_starts_a_blocking_presentation_and_places_the_default_bet() -> void:
	var harness := _make_harness(_full_round_cards(), "shoe-gc-1")

	harness.action_bar.deal_button().pressed.emit()

	assert_str(harness.presentation.active_token()).is_not_equal("")
	assert_int(harness.ledger.committed_bet).is_equal(BetLedger.MINIMUM_BET)
	assert_bool(harness.action_bar.deal_button().disabled).is_true()


func test_completing_deal_presentation_renders_real_cards_and_hides_the_dealers_hole_card() -> void:
	var harness := _make_harness(_full_round_cards(), "shoe-gc-2")
	harness.action_bar.deal_button().pressed.emit()

	harness.presentation.notify_presentation_finished(harness.presentation.active_token())

	# Player: both cards face up, real values (8H, 9C).
	assert_int(harness.player_hand_view.get_child_count()).is_equal(2)
	var player_card_1 := harness.player_hand_view.get_child(0) as CardFaceView
	var player_card_2 := harness.player_hand_view.get_child(1) as CardFaceView
	assert_bool(player_card_1.face_down).is_false()
	assert_str(player_card_1.rank).is_equal("8")
	assert_int(player_card_1.suit).is_equal(CardFaceView.Suit.HEART)
	assert_bool(player_card_2.face_down).is_false()
	assert_str(player_card_2.rank).is_equal("9")

	# Dealer: upcard (7S) face up, hole card face down — never the real value.
	assert_int(harness.dealer_hand_view.get_child_count()).is_equal(2)
	var dealer_up := harness.dealer_hand_view.get_child(0) as CardFaceView
	var dealer_hole := harness.dealer_hand_view.get_child(1) as CardFaceView
	assert_bool(dealer_up.face_down).is_false()
	assert_str(dealer_up.rank).is_equal("7")
	assert_int(dealer_up.suit).is_equal(CardFaceView.Suit.SPADE)
	assert_bool(dealer_hole.face_down).is_true()

	# HandTotal reflects the player's real evaluation (17, hard).
	assert_str(harness.hand_total.get_value_label().text).is_equal("17")
	assert_str(harness.hand_total.get_state_label().text).is_equal("HARD")

	# Chips/bet labels reflect the real ledger, not static scaffold text.
	assert_str(harness.chips_label.text).is_equal("CHIPS: %d" % (BetLedger.STARTING_CHIPS - BetLedger.MINIMUM_BET))
	assert_str(harness.bet_label.text).is_equal("BET: %d" % BetLedger.MINIMUM_BET)

	# ActionBar already reflects PLAYER_TURN's legal actions (PresentationController's
	# own completion path, not GameplayController re-implementing it).
	assert_int(harness.action_bar.button_count()).is_equal(4)


func test_hit_button_press_draws_a_real_card_and_resyncs_the_action_bar() -> void:
	var harness := _make_harness(_full_round_cards(), "shoe-gc-3")
	harness.action_bar.deal_button().pressed.emit()
	harness.presentation.notify_presentation_finished(harness.presentation.active_token())
	var hit_button: ActionButtonView = null
	for button in harness.action_bar.buttons():
		if button.action == ActionButtonView.Action.HIT:
			hit_button = button

	hit_button.pressed.emit()

	# 8H+9C+2H = 19, still PLAYER_TURN, decision locked -> only HIT/STAND.
	assert_int(harness.player_hand_view.get_child_count()).is_equal(3)
	assert_str(harness.hand_total.get_value_label().text).is_equal("19")
	assert_int(harness.controller.current_state).is_equal(RoundController.State.PLAYER_TURN)
	assert_int(harness.action_bar.button_count()).is_equal(2)


func test_surrender_button_press_settles_the_round_immediately() -> void:
	var harness := _make_harness(_full_round_cards(), "shoe-gc-surrender")
	harness.action_bar.deal_button().pressed.emit()
	harness.presentation.notify_presentation_finished(harness.presentation.active_token())
	var surrender_button: ActionButtonView = null
	for button in harness.action_bar.buttons():
		if button.action == ActionButtonView.Action.SURRENDER:
			surrender_button = button

	surrender_button.pressed.emit()

	assert_int(harness.controller.current_state).is_equal(RoundController.State.ROUND_END)
	assert_int(harness.controller.outcome()).is_equal(BlackjackOutcome.Type.PLAYER_SURRENDER)
	assert_str(harness.result_banner.text).is_equal("SURRENDERED")
	assert_int(harness.action_bar.deal_button().label).is_equal(DealButtonView.DealLabel.NEXT_ROUND)


func test_double_button_press_doubles_the_committed_bet_and_draws_one_card() -> void:
	var harness := _make_harness(_full_round_cards(), "shoe-gc-double")
	harness.action_bar.deal_button().pressed.emit()
	harness.presentation.notify_presentation_finished(harness.presentation.active_token())
	var double_button: ActionButtonView = null
	for button in harness.action_bar.buttons():
		if button.action == ActionButtonView.Action.DOUBLE:
			double_button = button

	double_button.pressed.emit()

	assert_int(harness.ledger.committed_bet).is_equal(BetLedger.MINIMUM_BET * 2)
	# 8H+9C+2H = 19, not bust -> straight to DEALER_TURN (double locks the
	# decision to exactly one more card), auto-triggering the same real
	# hole-reveal presentation STAND does.
	assert_int(harness.player_hand_view.get_child_count()).is_equal(3)
	assert_int(harness.controller.current_state).is_equal(RoundController.State.DEALER_TURN)
	assert_str(harness.presentation.active_token()).is_not_equal("")


func test_stand_triggers_the_dealer_hole_reveal_presentation_automatically() -> void:
	var harness := _make_harness(_full_round_cards(), "shoe-gc-4")
	harness.action_bar.deal_button().pressed.emit()
	harness.presentation.notify_presentation_finished(harness.presentation.active_token())
	var stand_button: ActionButtonView = null
	for button in harness.action_bar.buttons():
		if button.action == ActionButtonView.Action.STAND:
			stand_button = button

	stand_button.pressed.emit()

	assert_int(harness.controller.current_state).is_equal(RoundController.State.DEALER_TURN)
	# A second blocking presentation is now active — began without any
	# extra button for it, per specs/003's "reveal is automatic" contract.
	assert_str(harness.presentation.active_token()).is_not_equal("")
	assert_int(harness.action_bar.button_count()).is_equal(0)


func test_completing_the_reveal_drives_the_dealer_to_round_end_and_shows_the_result() -> void:
	var harness := _make_harness(_full_round_cards(), "shoe-gc-5")
	harness.action_bar.deal_button().pressed.emit()
	harness.presentation.notify_presentation_finished(harness.presentation.active_token())
	# Matches _full_round_cards()'s documented script exactly: HIT draws 2H
	# (17->19) for the *player* before STAND — skipping this step would
	# leave 2H undrawn and shift it onto the dealer's own hits instead,
	# changing how many cards the dealer ends up with.
	var hit_button: ActionButtonView = null
	for button in harness.action_bar.buttons():
		if button.action == ActionButtonView.Action.HIT:
			hit_button = button
	hit_button.pressed.emit()
	var stand_button: ActionButtonView = null
	for button in harness.action_bar.buttons():
		if button.action == ActionButtonView.Action.STAND:
			stand_button = button
	stand_button.pressed.emit()

	harness.presentation.notify_presentation_finished(harness.presentation.active_token())

	# Dealer's hole card (6D) is revealed then hits KS -> 23, DEALER_BUST,
	# resolving PLAYER_WIN, all driven by direct (non-blocking) dealer_step()
	# calls per specs/003's registered-events scope.
	assert_int(harness.controller.current_state).is_equal(RoundController.State.ROUND_END)
	assert_int(harness.controller.outcome()).is_equal(BlackjackOutcome.Type.DEALER_BUST)
	assert_int(harness.dealer_hand_view.get_child_count()).is_equal(3)
	for child in harness.dealer_hand_view.get_children():
		assert_bool((child as CardFaceView).face_down).is_false()
	assert_bool(harness.result_banner.text.is_empty()).is_false()
	# One DealButtonView (NEXT ROUND label) is now the only button.
	assert_int(harness.action_bar.button_count()).is_equal(1)
	assert_int(harness.action_bar.deal_button().label).is_equal(DealButtonView.DealLabel.NEXT_ROUND)


func test_next_round_button_press_returns_to_betting_and_clears_hands_and_banner() -> void:
	var harness := _make_harness(_full_round_cards(), "shoe-gc-6")
	harness.action_bar.deal_button().pressed.emit()
	harness.presentation.notify_presentation_finished(harness.presentation.active_token())
	var stand_button: ActionButtonView = null
	for button in harness.action_bar.buttons():
		if button.action == ActionButtonView.Action.STAND:
			stand_button = button
	stand_button.pressed.emit()
	harness.presentation.notify_presentation_finished(harness.presentation.active_token())

	harness.action_bar.deal_button().pressed.emit()

	assert_int(harness.controller.current_state).is_equal(RoundController.State.BETTING)
	assert_int(harness.dealer_hand_view.get_child_count()).is_equal(0)
	assert_int(harness.player_hand_view.get_child_count()).is_equal(0)
	assert_bool(harness.result_banner.text.is_empty()).is_true()
	assert_int(harness.action_bar.button_count()).is_equal(1)
	assert_int(harness.action_bar.deal_button().label).is_equal(DealButtonView.DealLabel.DEAL)


## End-to-end: drives the *real* game_root.tscn scene (GameBootstrap's
## automatic wiring, not the synthetic harness above) through an entire
## round using only button .pressed.emit() calls, proving the whole chain
## from click-equivalent signal to on-screen state is actually connected —
## not just GameplayController's own unit contract in isolation.
func test_end_to_end_a_full_round_is_playable_through_the_real_scene() -> void:
	# bootstrap() replaces GameBootstrap's own random-seed boot with a fixed
	# one (its documented test seam), but the resulting shoe is still a real
	# shuffled DeckShoe.create_runtime(), not an injected deterministic
	# sequence — so this drives the round generically off legal_actions()/
	# state instead of assuming a specific outcome (same reasoning as
	# tests/ui/test_l3_dealer_idle_animation.gd's round-2 logic).
	var runner := scene_runner("res://scenes/game_root.tscn")
	var root: Node = runner.scene()
	var bootstrap := root.get_node("Bootstrap") as GameBootstrap
	bootstrap.bootstrap("shoe-gc-e2e", 4242)
	var table_ui := root.get_node("L1Root/TableUI") as Node
	var action_bar := table_ui.find_child("ActionBar", true, false) as ActionBarView
	var presentation_controller := root.get_node("PresentationController") as PresentationController

	action_bar.deal_button().pressed.emit()
	assert_str(presentation_controller.active_token()).is_not_equal("")
	presentation_controller.notify_presentation_finished(presentation_controller.active_token())

	if bootstrap.controller.current_state == RoundController.State.PLAYER_TURN:
		var stand_button: ActionButtonView = null
		for button in action_bar.buttons():
			if button.action == ActionButtonView.Action.STAND:
				stand_button = button
		stand_button.pressed.emit()
		if bootstrap.controller.current_state == RoundController.State.DEALER_TURN:
			presentation_controller.notify_presentation_finished(presentation_controller.active_token())

	assert_int(bootstrap.controller.current_state).is_equal(RoundController.State.ROUND_END)
	var deal_button := action_bar.deal_button()
	assert_object(deal_button).is_not_null()
	assert_int(deal_button.label).is_equal(DealButtonView.DealLabel.NEXT_ROUND)

	deal_button.pressed.emit()

	assert_int(bootstrap.controller.current_state).is_equal(RoundController.State.BETTING)
