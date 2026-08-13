class_name TestBetLedger
extends GdUnitTestSuite


func test_default_ledger_uses_the_approved_prototype_profile() -> void:
	var ledger := BetLedger.new()

	assert_int(ledger.available_chips).is_equal(1000)
	assert_int(ledger.selected_bet).is_equal(10)
	assert_int(ledger.committed_bet).is_equal(0)
	assert_int(ledger.minimum_bet).is_equal(10)
	assert_int(ledger.maximum_bet).is_equal(500)


func test_selected_bet_accepts_approved_boundaries() -> void:
	var ledger := BetLedger.new()

	assert_bool(ledger.set_selected_bet(10)).is_true()
	assert_int(ledger.selected_bet).is_equal(10)
	assert_bool(ledger.set_selected_bet(500)).is_true()
	assert_int(ledger.selected_bet).is_equal(500)


func test_invalid_selected_bet_is_rejected_without_mutation() -> void:
	var ledger := BetLedger.new()
	assert_bool(ledger.set_selected_bet(25)).is_true()

	assert_bool(ledger.set_selected_bet(9)).is_false()
	assert_int(ledger.selected_bet).is_equal(25)
	assert_bool(ledger.set_selected_bet(501)).is_false()
	assert_int(ledger.selected_bet).is_equal(25)


func test_commit_deducts_selected_bet_exactly_once_for_one_active_round() -> void:
	var ledger := BetLedger.new()
	assert_bool(ledger.set_selected_bet(100)).is_true()

	assert_bool(ledger.commit("")).is_false()
	assert_bool(ledger.commit("round-commit")).is_true()
	assert_int(ledger.available_chips).is_equal(900)
	assert_int(ledger.committed_bet).is_equal(100)

	assert_bool(ledger.commit("round-commit")).is_false()
	assert_bool(ledger.commit("round-other")).is_false()
	assert_bool(ledger.set_selected_bet(25)).is_false()
	assert_int(ledger.available_chips).is_equal(900)
	assert_int(ledger.committed_bet).is_equal(100)
	assert_int(ledger.selected_bet).is_equal(100)


func test_double_deducts_the_original_bet_once_for_the_matching_round() -> void:
	var ledger := BetLedger.new()
	assert_bool(ledger.set_selected_bet(100)).is_true()
	assert_bool(ledger.commit("round-double")).is_true()

	assert_bool(ledger.double_committed_bet("round-other")).is_false()
	assert_bool(ledger.double_committed_bet("round-double")).is_true()
	assert_int(ledger.available_chips).is_equal(800)
	assert_int(ledger.committed_bet).is_equal(200)
	assert_bool(ledger.double_committed_bet("round-double")).is_false()
	assert_int(ledger.available_chips).is_equal(800)
	assert_int(ledger.committed_bet).is_equal(200)


func test_double_rejects_when_available_chips_cannot_match_the_committed_bet() -> void:
	var ledger := _committed_ledger(400, "round-prior-loss")
	ledger.settle("round-prior-loss", BlackjackOutcome.Type.DEALER_WIN)
	assert_bool(ledger.prepare_next_round()).is_true()
	assert_bool(ledger.set_selected_bet(500)).is_true()
	assert_bool(ledger.commit("round-insufficient-double")).is_true()

	assert_bool(ledger.double_committed_bet("round-insufficient-double")).is_false()
	assert_int(ledger.available_chips).is_equal(100)
	assert_int(ledger.committed_bet).is_equal(500)


func test_player_win_and_dealer_bust_credit_twice_the_committed_bet() -> void:
	var outcomes: Array[int] = [
		BlackjackOutcome.Type.PLAYER_WIN,
		BlackjackOutcome.Type.DEALER_BUST,
	]
	for outcome in outcomes:
		var round_id := "round-even-win-%d" % outcome
		var ledger := _committed_ledger(100, round_id)

		var result := ledger.settle(round_id, outcome)

		assert_bool(result.accepted).is_true()
		assert_int(result.credit).is_equal(200)
		assert_int(result.committed_bet_before).is_equal(100)
		assert_int(result.available_chips_after).is_equal(1100)
		assert_int(ledger.available_chips).is_equal(1100)
		assert_int(ledger.committed_bet).is_equal(0)


func test_loss_outcomes_credit_zero() -> void:
	var outcomes: Array[int] = [
		BlackjackOutcome.Type.DEALER_BLACKJACK,
		BlackjackOutcome.Type.DEALER_WIN,
		BlackjackOutcome.Type.PLAYER_BUST,
	]
	for outcome in outcomes:
		var round_id := "round-loss-%d" % outcome
		var ledger := _committed_ledger(100, round_id)

		var result := ledger.settle(round_id, outcome)

		assert_bool(result.accepted).is_true()
		assert_int(result.credit).is_equal(0)
		assert_int(result.available_chips_after).is_equal(900)
		assert_int(ledger.available_chips).is_equal(900)
		assert_int(ledger.committed_bet).is_equal(0)


func test_push_returns_the_committed_bet() -> void:
	var ledger := _committed_ledger(100, "round-push")

	var result := ledger.settle("round-push", BlackjackOutcome.Type.PUSH)

	assert_bool(result.accepted).is_true()
	assert_int(result.credit).is_equal(100)
	assert_int(ledger.available_chips).is_equal(1000)
	assert_int(ledger.committed_bet).is_equal(0)


func test_odd_blackjack_credit_rounds_up_in_the_players_favor() -> void:
	var ledger := _committed_ledger(25, "round-blackjack")

	var result := ledger.settle(
		"round-blackjack",
		BlackjackOutcome.Type.PLAYER_BLACKJACK,
	)

	assert_bool(result.accepted).is_true()
	assert_int(result.credit).is_equal(63)
	assert_int(ledger.available_chips).is_equal(1038)


func test_odd_surrender_credit_rounds_up_in_the_players_favor() -> void:
	var ledger := _committed_ledger(25, "round-surrender")

	var result := ledger.settle(
		"round-surrender",
		BlackjackOutcome.Type.PLAYER_SURRENDER,
	)

	assert_bool(result.accepted).is_true()
	assert_int(result.credit).is_equal(13)
	assert_int(ledger.available_chips).is_equal(988)


func test_double_win_uses_the_doubled_committed_bet_for_credit() -> void:
	var ledger := _committed_ledger(100, "round-double-win")
	assert_bool(ledger.double_committed_bet("round-double-win")).is_true()

	var result := ledger.settle(
		"round-double-win",
		BlackjackOutcome.Type.PLAYER_WIN,
	)

	assert_bool(result.accepted).is_true()
	assert_int(result.committed_bet_before).is_equal(200)
	assert_int(result.credit).is_equal(400)
	assert_int(ledger.available_chips).is_equal(1200)


func test_invalid_and_duplicate_settlement_do_not_mutate_or_consume_the_valid_close() -> void:
	var ledger := _committed_ledger(100, "round-settle-once")

	var invalid := ledger.settle("round-settle-once", 999)
	assert_bool(invalid.accepted).is_false()
	assert_int(ledger.available_chips).is_equal(900)
	assert_int(ledger.committed_bet).is_equal(100)

	var accepted := ledger.settle(
		"round-settle-once",
		BlackjackOutcome.Type.PLAYER_WIN,
	)
	var duplicate := ledger.settle(
		"round-settle-once",
		BlackjackOutcome.Type.PLAYER_WIN,
	)
	assert_bool(accepted.accepted).is_true()
	assert_bool(duplicate.accepted).is_false()
	assert_bool(ledger.commit("round-settle-once")).is_false()
	assert_int(ledger.available_chips).is_equal(1100)
	assert_int(ledger.committed_bet).is_equal(0)


func test_refund_returns_committed_bet_once_and_closes_the_round() -> void:
	var ledger := _committed_ledger(100, "round-refund")
	var wrong_round := ledger.refund("round-other")
	assert_bool(wrong_round.accepted).is_false()
	assert_int(ledger.available_chips).is_equal(900)
	assert_int(ledger.committed_bet).is_equal(100)

	var result := ledger.refund("round-refund")

	assert_bool(result.accepted).is_true()
	assert_int(result.credit).is_equal(100)
	assert_int(result.committed_bet_before).is_equal(100)
	assert_int(ledger.available_chips).is_equal(1000)
	assert_int(ledger.committed_bet).is_equal(0)

	var duplicate := ledger.refund("round-refund")
	var settlement := ledger.settle(
		"round-refund",
		BlackjackOutcome.Type.PLAYER_WIN,
	)
	assert_bool(duplicate.accepted).is_false()
	assert_bool(settlement.accepted).is_false()
	assert_bool(ledger.commit("round-refund")).is_false()
	assert_int(ledger.available_chips).is_equal(1000)
	assert_int(ledger.committed_bet).is_equal(0)


func test_prepare_next_round_rejects_an_active_committed_bet() -> void:
	var ledger := _committed_ledger(100, "round-active")

	assert_bool(ledger.prepare_next_round()).is_false()
	assert_int(ledger.available_chips).is_equal(900)
	assert_int(ledger.selected_bet).is_equal(100)
	assert_int(ledger.committed_bet).is_equal(100)


func test_prepare_next_round_resets_selection_without_changing_a_playable_bankroll() -> void:
	var ledger := _committed_ledger(100, "round-complete")
	ledger.settle("round-complete", BlackjackOutcome.Type.PLAYER_WIN)

	assert_bool(ledger.prepare_next_round()).is_true()
	assert_int(ledger.available_chips).is_equal(1100)
	assert_int(ledger.selected_bet).is_equal(10)
	assert_int(ledger.committed_bet).is_equal(0)


func test_prepare_next_round_restores_starting_chips_below_the_minimum_bet() -> void:
	var ledger := _committed_ledger(500, "round-loss-one")
	ledger.settle("round-loss-one", BlackjackOutcome.Type.DEALER_WIN)
	assert_bool(ledger.prepare_next_round()).is_true()
	assert_bool(ledger.set_selected_bet(500)).is_true()
	assert_bool(ledger.commit("round-loss-two")).is_true()
	ledger.settle("round-loss-two", BlackjackOutcome.Type.DEALER_WIN)
	assert_int(ledger.available_chips).is_equal(0)

	assert_bool(ledger.prepare_next_round()).is_true()
	assert_int(ledger.available_chips).is_equal(1000)
	assert_int(ledger.selected_bet).is_equal(10)
	assert_int(ledger.committed_bet).is_equal(0)


func test_selected_bet_rejects_an_amount_above_the_remaining_available_chips() -> void:
	var ledger := _committed_ledger(500, "round-selection-loss-one")
	ledger.settle("round-selection-loss-one", BlackjackOutcome.Type.DEALER_WIN)
	assert_bool(ledger.prepare_next_round()).is_true()
	assert_bool(ledger.set_selected_bet(400)).is_true()
	assert_bool(ledger.commit("round-selection-loss-two")).is_true()
	ledger.settle("round-selection-loss-two", BlackjackOutcome.Type.DEALER_WIN)
	assert_bool(ledger.prepare_next_round()).is_true()
	assert_int(ledger.available_chips).is_equal(100)

	assert_bool(ledger.set_selected_bet(200)).is_false()
	assert_int(ledger.selected_bet).is_equal(10)


func _committed_ledger(bet: int, round_id: String) -> BetLedger:
	var ledger := BetLedger.new()
	ledger.set_selected_bet(bet)
	ledger.commit(round_id)
	return ledger
