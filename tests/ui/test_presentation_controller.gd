class_name TestPresentationController
extends GdUnitTestSuite
## Covers specs/003 L2 Behavior / Acceptance Criteria L2-1..L2-5 for the two
## blocking events this spec registers (Deal card, Dealer hole card reveal)
## plus the one non-blocking event (L3 ambient loop, which needs no wiring
## here since it never touches RoundController.begin_presentation).
##
## PresentationController never decides the next legal action itself
## (docs/03_INTERACTION_CONTRACTS.md:136) — every assertion about ActionBar
## state after a presentation ends reads it back from
## RoundController.legal_actions(), not from PresentationController's own
## bookkeeping, so a bug that made PresentationController "guess" would show
## up here as a wrong disabled/enabled pattern.

const FALLBACK_DEAL_CARD_MS := 1500
const FALLBACK_DEALER_HOLE_REVEAL_MS := 1200


func _card(rank: int, suit: int) -> Card:
	return Card.new(rank, suit)


## Player 8+9=17 (no natural), dealer up 7 / hole 6 (no peek since upcard < 10).
## Lands cleanly in PLAYER_TURN after deal(), same shape as
## tests/core/test_round_controller.gd's deal-flow fixtures.
func _make_controller() -> RoundController:
	var cards: Array[Card] = [
		_card(Card.Rank.EIGHT, Card.Suit.HEARTS),
		_card(Card.Rank.SEVEN, Card.Suit.SPADES),
		_card(Card.Rank.NINE, Card.Suit.CLUBS),
		_card(Card.Rank.SIX, Card.Suit.DIAMONDS),
	]
	var ledger := BetLedger.new()
	var shoe := DeckShoe.create_injected(cards, "shoe-presentation")
	return RoundController.create_injected(shoe, ledger)


## Player 9+9=18 (no natural), dealer up 7 / hole King (no peek since upcard < 10).
## STAND moves straight to DEALER_TURN so dealer_step() reveals the hole card
## on its very first call.
func _make_controller_ready_for_dealer_turn() -> RoundController:
	var cards: Array[Card] = [
		_card(Card.Rank.NINE, Card.Suit.HEARTS),
		_card(Card.Rank.SEVEN, Card.Suit.SPADES),
		_card(Card.Rank.NINE, Card.Suit.CLUBS),
		_card(Card.Rank.KING, Card.Suit.DIAMONDS),
	]
	var ledger := BetLedger.new()
	var shoe := DeckShoe.create_injected(cards, "shoe-hole-reveal")
	var controller := RoundController.create_injected(shoe, ledger)
	assert_bool(controller.place_bet(100)).is_true()
	assert_bool(controller.deal("round-hole-reveal")).is_true()
	assert_bool(controller.stand()).is_true()
	assert_int(controller.current_state).is_equal(RoundController.State.DEALER_TURN)
	return controller


func _make_action_bar() -> HBoxContainer:
	var bar := HBoxContainer.new()
	for action: int in [
		ActionButtonView.Action.HIT,
		ActionButtonView.Action.STAND,
		ActionButtonView.Action.DOUBLE,
		ActionButtonView.Action.SURRENDER,
	]:
		var button := ActionButtonView.new()
		button.action = action
		bar.add_child(button)
	return bar


func test_fallback_duration_constants_match_the_registered_mapping() -> void:
	var presentation: PresentationController = auto_free(PresentationController.new())

	assert_int(presentation.FALLBACK_DEAL_CARD_MS).is_equal(FALLBACK_DEAL_CARD_MS)
	assert_int(presentation.FALLBACK_DEALER_HOLE_REVEAL_MS).is_equal(FALLBACK_DEALER_HOLE_REVEAL_MS)


func test_begin_deal_presentation_commits_the_deal_and_blocks_the_action_bar() -> void:
	var presentation: PresentationController = auto_free(PresentationController.new())
	add_child(presentation)
	var controller := _make_controller()
	var action_bar: HBoxContainer = auto_free(_make_action_bar())
	add_child(action_bar)
	presentation.setup(controller, action_bar)
	assert_bool(controller.place_bet(100)).is_true()

	var started := presentation.begin_deal_presentation("round-1")

	assert_bool(started).is_true()
	assert_int(controller.current_state).is_equal(RoundController.State.PLAYER_TURN)
	assert_array(controller.legal_actions()).is_empty()
	for child in action_bar.get_children():
		assert_bool((child as BaseButton).disabled).is_true()


func test_action_bar_children_are_never_cleared_while_blocking() -> void:
	var presentation: PresentationController = auto_free(PresentationController.new())
	add_child(presentation)
	var controller := _make_controller()
	var action_bar: HBoxContainer = auto_free(_make_action_bar())
	add_child(action_bar)
	presentation.setup(controller, action_bar)
	assert_bool(controller.place_bet(100)).is_true()
	var before_count := action_bar.get_child_count()

	presentation.begin_deal_presentation("round-2")

	assert_int(action_bar.get_child_count()).is_equal(before_count)


func test_completing_deal_presentation_unblocks_and_reflects_legal_actions_from_round_controller() -> void:
	var presentation: PresentationController = auto_free(PresentationController.new())
	add_child(presentation)
	var controller := _make_controller()
	var action_bar: HBoxContainer = auto_free(_make_action_bar())
	add_child(action_bar)
	presentation.setup(controller, action_bar)
	assert_bool(controller.place_bet(100)).is_true()
	presentation.begin_deal_presentation("round-3")

	var finished := presentation.notify_presentation_finished(presentation.active_token())

	assert_bool(finished).is_true()
	assert_int(controller.current_state).is_equal(RoundController.State.PLAYER_TURN)
	var legal := controller.legal_actions()
	for child in action_bar.get_children():
		var button := child as ActionButtonView
		var action_id := _round_controller_action_id(button.action)
		assert_bool(button.disabled).is_equal(not legal.has(action_id))


func test_dealer_hole_reveal_presentation_blocks_then_unblocks_via_fallback() -> void:
	var presentation: PresentationController = auto_free(PresentationController.new())
	add_child(presentation)
	var controller := _make_controller_ready_for_dealer_turn()
	var action_bar: HBoxContainer = auto_free(_make_action_bar())
	add_child(action_bar)
	presentation.setup(controller, action_bar)

	var started := presentation.begin_dealer_hole_reveal_presentation()
	assert_bool(started).is_true()
	assert_array(controller.legal_actions()).is_empty()
	for child in action_bar.get_children():
		assert_bool((child as BaseButton).disabled).is_true()

	# Simulate the safety-net firing without waiting FALLBACK_DEALER_HOLE_REVEAL_MS
	# of real wall-clock time.
	presentation.force_fallback_timeout_for_test()

	assert_int(controller.current_state).is_equal(RoundController.State.DEALER_TURN)
	assert_bool(controller.has_outcome()).is_false()


func test_dealer_hole_reveal_presentation_is_not_started_for_a_non_reveal_dealer_step() -> void:
	var presentation: PresentationController = auto_free(PresentationController.new())
	add_child(presentation)
	var controller := _make_controller_ready_for_dealer_turn()
	presentation.setup(controller, null)
	presentation.begin_dealer_hole_reveal_presentation()
	presentation.force_fallback_timeout_for_test()
	# Dealer is now standing on hard 17 (7 + King) — the next dealer_step() call
	# resolves the round instead of emitting another hole-card reveal, so it
	# must NOT open a second blocking presentation.

	var started_again := presentation.begin_dealer_hole_reveal_presentation()

	assert_bool(started_again).is_false()
	assert_str(presentation.active_token()).is_equal("")


func test_late_real_completion_after_fallback_already_unlocked_is_rejected_as_diagnostic_only() -> void:
	var presentation: PresentationController = auto_free(PresentationController.new())
	add_child(presentation)
	var controller := _make_controller()
	var action_bar: HBoxContainer = auto_free(_make_action_bar())
	add_child(action_bar)
	presentation.setup(controller, action_bar)
	assert_bool(controller.place_bet(100)).is_true()
	presentation.begin_deal_presentation("round-race")
	var original_token := presentation.active_token()

	# Fallback timeout wins the race and unlocks the bar first.
	presentation.force_fallback_timeout_for_test()
	assert_str(presentation.active_token()).is_equal("")
	var legal_after_fallback := controller.legal_actions()

	# The "real" completion for the same presentation arrives late.
	var late_result := presentation.notify_presentation_finished(original_token)

	assert_bool(late_result).is_false()
	# State must be unchanged by the late arrival: same legal actions, still
	# not re-entering a blocked state, no button re-disabled by the rejection.
	assert_array(controller.legal_actions()).contains_exactly(legal_after_fallback)
	for child in action_bar.get_children():
		var button := child as ActionButtonView
		var action_id := _round_controller_action_id(button.action)
		assert_bool(button.disabled).is_equal(not legal_after_fallback.has(action_id))


func test_asset_load_failure_completes_the_presentation_within_bounded_time_instead_of_permanent_hold() -> void:
	var presentation: PresentationController = auto_free(PresentationController.new())
	add_child(presentation)
	var controller := _make_controller()
	var action_bar: HBoxContainer = auto_free(_make_action_bar())
	add_child(action_bar)
	presentation.setup(controller, action_bar)
	assert_bool(controller.place_bet(100)).is_true()
	presentation.begin_deal_presentation("round-asset-fail")
	assert_bool(controller.legal_actions().is_empty()).is_true()

	presentation.report_asset_load_failure("L2_DEAL_CARD_V001")

	assert_str(presentation.active_token()).is_equal("")
	assert_bool(controller.legal_actions().is_empty()).is_false()


func test_fallback_timer_actually_fires_and_completes_the_presentation() -> void:
	# Genuine end-to-end confidence check (not the test seam): use a very
	# short real fallback window and let a real engine Timer fire it.
	var presentation: PresentationController = auto_free(PresentationController.new())
	add_child(presentation)
	var controller := _make_controller()
	presentation.setup(controller, null)
	assert_bool(controller.place_bet(100)).is_true()
	presentation.override_fallback_ms_for_test(30)

	presentation.begin_deal_presentation("round-real-timer")
	assert_str(presentation.active_token()).is_not_equal("")

	await get_tree().create_timer(0.3).timeout

	assert_str(presentation.active_token()).is_equal("")
	assert_bool(controller.legal_actions().is_empty()).is_false()


## Reproduces the exact failure team-lead flagged: a PresentationController
## instance is destroyed and a fresh one created for the next round (its
## _token_sequence counter restarts at 0), while the SAME RoundController
## (and its lifetime-scoped _used_presentation_tokens history) survives.
## Without round_id baked into the token, the second instance's first token
## for a given kind collides with the first instance's already-burned token
## of the same kind, begin_presentation is silently rejected, and the round
## proceeds with no input barrier at all.
func test_recreating_presentation_controller_across_a_round_boundary_does_not_collide_with_a_burned_token() -> void:
	var controller := _make_controller()
	var first_presentation: PresentationController = auto_free(PresentationController.new())
	add_child(first_presentation)
	first_presentation.setup(controller, null)
	assert_bool(controller.place_bet(100)).is_true()
	assert_bool(first_presentation.begin_deal_presentation("round-A")).is_true()
	assert_bool(
		first_presentation.notify_presentation_finished(first_presentation.active_token())
	).is_true()

	# Drive round A to ROUND_END without going through PresentationController
	# (STAND/dealer resolution aren't registered blocking events in this spec).
	assert_bool(controller.stand()).is_true()
	assert_bool(controller.dealer_step()).is_true()  # reveals the hole card
	# Shoe is exhausted (all 4 injected cards were drawn during deal()): the
	# next hit attempt fails and dealer_step() itself returns false, but it
	# still aborts the round to ROUND_END internally.
	assert_bool(controller.dealer_step()).is_false()
	assert_int(controller.current_state).is_equal(RoundController.State.ROUND_END)
	assert_bool(controller.next_round("shoe-round-b", 7)).is_true()
	assert_bool(controller.place_bet(100)).is_true()

	# A brand-new PresentationController for round B — fresh _token_sequence.
	var second_presentation: PresentationController = auto_free(PresentationController.new())
	add_child(second_presentation)
	second_presentation.setup(controller, null)

	second_presentation.begin_deal_presentation("round-B")

	# The real proof isn't just "token non-empty" — it's that the input
	# barrier is genuinely active. Under the bug, core's begin_presentation
	# silently rejects the reused token, core's active token stays empty, and
	# legal_actions() returns the full PLAYER_TURN action list instead of [].
	assert_array(controller.legal_actions()).is_empty()
	assert_str(second_presentation.active_token()).is_not_equal("")


func test_late_completion_diagnostic_reports_the_kind_it_was_late_for() -> void:
	var presentation: PresentationController = auto_free(PresentationController.new())
	add_child(presentation)
	var controller := _make_controller()
	presentation.setup(controller, null)
	assert_bool(controller.place_bet(100)).is_true()
	presentation.begin_deal_presentation("round-diagnostic")
	var original_token := presentation.active_token()
	presentation.force_fallback_timeout_for_test()
	monitor_signals(presentation)

	presentation.notify_presentation_finished(original_token)

	# Diagnostics are most needed exactly when something arrives late — the
	# signal must still say which presentation it was late for, not "".
	assert_signal(presentation).is_emitted(
		"presentation_completion_rejected",
		&"DEAL_CARD",
		original_token,
		RoundController.ERROR_PRESENTATION_TOKEN_MISMATCH,
	)


func _round_controller_action_id(button_action: int) -> StringName:
	match button_action:
		ActionButtonView.Action.HIT:
			return RoundController.ACTION_HIT
		ActionButtonView.Action.STAND:
			return RoundController.ACTION_STAND
		ActionButtonView.Action.DOUBLE:
			return RoundController.ACTION_DOUBLE
		ActionButtonView.Action.SURRENDER:
			return RoundController.ACTION_SURRENDER
	return &""
