class_name TestL24PresentationFallbackVisual
extends GdUnitTestSuite
## Covers specs/003 L2-4 / docs/03_INTERACTION_CONTRACTS.md:142-149 (Failure
## Fallback): on asset load failure, PresentationController must show a
## Theme-driven text fallback visual (not just log-and-complete), then
## complete within bounded time and remove/hide that visual — never leave
## the player staring at nothing during a failure, and never leave the
## fallback text stuck on screen after the round has moved on.
##
## Text content is deliberately neutral/non-technical (no asset_id, no error
## code) — docs/03:144 sends the asset ID to the log, not the screen;
## players should never see internal identifiers.


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
	var shoe := DeckShoe.create_injected(cards, "shoe-l2-4")
	return RoundController.create_injected(shoe, ledger)


func test_asset_load_failure_shows_a_neutral_text_fallback_in_the_given_overlay() -> void:
	var overlay: Control = auto_free(Control.new())
	add_child(overlay)
	var presentation: PresentationController = auto_free(PresentationController.new())
	add_child(presentation)
	var controller := _make_controller()
	presentation.setup(controller, null, overlay)
	assert_bool(controller.place_bet(100)).is_true()
	presentation.begin_deal_presentation("round-l2-4-1")

	presentation.report_asset_load_failure("L2_DEAL_CARD_V001")

	assert_bool(presentation.is_fallback_visual_visible()).is_true()
	var shown_text := presentation.fallback_visual_text()
	assert_bool(shown_text.is_empty()).is_false()
	assert_str(shown_text).not_contains("L2_DEAL_CARD_V001")
	assert_bool(overlay.find_children("*", "Label", true, false).size() > 0).is_true()


func test_fallback_visual_is_hidden_once_the_presentation_completes() -> void:
	var overlay: Control = auto_free(Control.new())
	add_child(overlay)
	var presentation: PresentationController = auto_free(PresentationController.new())
	add_child(presentation)
	var controller := _make_controller()
	presentation.setup(controller, null, overlay)
	assert_bool(controller.place_bet(100)).is_true()
	presentation.begin_deal_presentation("round-l2-4-2")
	presentation.report_asset_load_failure("L2_DEAL_CARD_V001")
	assert_bool(presentation.is_fallback_visual_visible()).is_true()

	presentation.force_fallback_visual_dwell_elapsed_for_test()

	assert_bool(presentation.is_fallback_visual_visible()).is_false()
	assert_str(presentation.active_token()).is_equal("")


func test_fallback_visual_path_never_stays_permanently_held() -> void:
	# Same HOLD-forever safety property the older synchronous path already
	# guaranteed, re-verified through the new dwell-timer path that replaced
	# it (docs/03:142-149 step 4).
	var presentation: PresentationController = auto_free(PresentationController.new())
	add_child(presentation)
	var controller := _make_controller()
	presentation.setup(controller, null, null)
	assert_bool(controller.place_bet(100)).is_true()
	presentation.begin_deal_presentation("round-l2-4-3")

	presentation.report_asset_load_failure("L2_DEAL_CARD_V001")
	presentation.force_fallback_visual_dwell_elapsed_for_test()

	assert_str(presentation.active_token()).is_equal("")
	assert_bool(controller.legal_actions().is_empty()).is_false()


func test_no_fallback_overlay_configured_still_completes_safely() -> void:
	# fallback_overlay is optional (setup()'s third arg defaults to null) —
	# existing callers/tests that only pass (controller, action_bar) must
	# keep working exactly as before, just without a visible fallback text.
	var presentation: PresentationController = auto_free(PresentationController.new())
	add_child(presentation)
	var controller := _make_controller()
	presentation.setup(controller, null)
	assert_bool(controller.place_bet(100)).is_true()
	presentation.begin_deal_presentation("round-l2-4-4")

	presentation.report_asset_load_failure("L2_DEAL_CARD_V001")
	assert_bool(presentation.is_fallback_visual_visible()).is_false()
	presentation.force_fallback_visual_dwell_elapsed_for_test()

	assert_str(presentation.active_token()).is_equal("")
