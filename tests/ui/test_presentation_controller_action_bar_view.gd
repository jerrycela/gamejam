class_name TestPresentationControllerActionBarView
extends GdUnitTestSuite
## Covers PresentationController driving a real ActionBarView (PANEL_ACTION_BAR)
## instead of a flat HBoxContainer of buttons. ActionBarView nests its
## buttons inside an internal "ButtonRow" HBoxContainer, so
## PresentationController's disable/sync logic must reach buttons regardless
## of nesting depth, and must delegate composition changes (add/remove
## buttons) to ActionBarView itself rather than reimplementing that logic.


func _card(rank: int, suit: int) -> Card:
	return Card.new(rank, suit)


func _make_controller() -> RoundController:
	var cards: Array[Card] = [
		_card(Card.Rank.EIGHT, Card.Suit.HEARTS),
		_card(Card.Rank.SEVEN, Card.Suit.SPADES),
		_card(Card.Rank.NINE, Card.Suit.CLUBS),
		_card(Card.Rank.SIX, Card.Suit.DIAMONDS),
	]
	var ledger := BetLedger.new()
	var shoe := DeckShoe.create_injected(cards, "shoe-action-bar-view")
	return RoundController.create_injected(shoe, ledger)


func test_begin_deal_presentation_disables_the_action_bar_views_nested_buttons() -> void:
	var presentation: PresentationController = auto_free(PresentationController.new())
	add_child(presentation)
	var controller := _make_controller()
	var bar_runner := scene_runner("res://ui/components/action_bar.tscn")
	var bar := bar_runner.scene() as ActionBarView
	bar.sync_with_legal_actions([
		RoundController.ACTION_HIT,
		RoundController.ACTION_STAND,
		RoundController.ACTION_DOUBLE,
		RoundController.ACTION_SURRENDER,
	])
	presentation.setup(controller, bar)
	assert_bool(controller.place_bet(100)).is_true()

	presentation.begin_deal_presentation("round-abv-1")

	# Composition-preserving: still 4 buttons, all disabled — not cleared to 0.
	assert_int(bar.button_count()).is_equal(4)
	for button in bar.buttons():
		assert_bool(button.disabled).is_true()


func test_completing_deal_presentation_rebuilds_the_action_bar_view_to_match_legal_actions() -> void:
	var presentation: PresentationController = auto_free(PresentationController.new())
	add_child(presentation)
	var controller := _make_controller()
	var bar_runner := scene_runner("res://ui/components/action_bar.tscn")
	var bar := bar_runner.scene() as ActionBarView
	# Panel starts empty (BETTING has no action-kind legal actions).
	presentation.setup(controller, bar)
	assert_bool(controller.place_bet(100)).is_true()
	presentation.begin_deal_presentation("round-abv-2")

	presentation.notify_presentation_finished(presentation.active_token())

	# Deal lands in PLAYER_TURN with the first decision still available:
	# HIT, STAND, DOUBLE, SURRENDER are all legal.
	assert_int(bar.button_count()).is_equal(4)
	assert_array(bar.button_actions()).contains_exactly([
		ActionButtonView.Action.HIT,
		ActionButtonView.Action.STAND,
		ActionButtonView.Action.DOUBLE,
		ActionButtonView.Action.SURRENDER,
	])
	for button in bar.buttons():
		assert_bool(button.disabled).is_false()
