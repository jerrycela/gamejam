class_name TestRoundController
extends GdUnitTestSuite


func test_injected_controller_starts_in_betting_with_only_betting_actions() -> void:
	var ledger := BetLedger.new()
	var shoe := DeckShoe.create_injected([], "shoe-initial")
	var controller := RoundController.create_injected(shoe, ledger)

	assert_int(controller.current_state).is_equal(RoundController.State.BETTING)
	assert_bool(controller.has_active_round()).is_false()
	assert_bool(controller.has_outcome()).is_false()
	assert_array(controller.legal_actions()).contains_exactly([
		RoundController.ACTION_PLACE_BET,
		RoundController.ACTION_DEAL,
	])


func test_place_bet_delegates_selection_without_committing_chips() -> void:
	var ledger := BetLedger.new()
	var shoe := DeckShoe.create_injected([], "shoe-bet")
	var controller := RoundController.create_injected(shoe, ledger)

	assert_bool(controller.place_bet(100)).is_true()
	assert_int(ledger.selected_bet).is_equal(100)
	assert_int(ledger.available_chips).is_equal(1000)
	assert_int(ledger.committed_bet).is_equal(0)
	assert_int(controller.current_state).is_equal(RoundController.State.BETTING)

	assert_bool(controller.place_bet(9)).is_false()
	assert_int(ledger.selected_bet).is_equal(100)


func test_deal_commits_bet_captures_metadata_and_emits_top_first_p_d_p_d() -> void:
	var player_first := _card(Card.Rank.EIGHT, Card.Suit.HEARTS)
	var dealer_up := _card(Card.Rank.SEVEN, Card.Suit.SPADES)
	var player_second := _card(Card.Rank.NINE, Card.Suit.CLUBS)
	var dealer_hole := _card(Card.Rank.SIX, Card.Suit.DIAMONDS)
	var cards: Array[Card] = [
		player_first,
		dealer_up,
		player_second,
		dealer_hole,
	]
	var ledger := BetLedger.new()
	var shoe := DeckShoe.create_injected(cards, "shoe-deal")
	var controller := RoundController.create_injected(shoe, ledger)
	assert_bool(controller.place_bet(100)).is_true()

	assert_bool(controller.deal("round-deal")).is_true()

	assert_int(ledger.available_chips).is_equal(900)
	assert_int(ledger.committed_bet).is_equal(100)
	assert_int(shoe.draw_index()).is_equal(4)
	assert_int(controller.current_state).is_equal(RoundController.State.PLAYER_TURN)
	assert_bool(controller.has_active_round()).is_true()

	var metadata := controller.round_metadata()
	assert_str(metadata.round_id).is_equal("round-deal")
	assert_str(metadata.shoe_id).is_equal("shoe-deal")
	assert_int(metadata.shuffle_seed).is_equal(0)
	assert_int(metadata.draw_index_at_round_start).is_equal(0)

	var events := controller.events()
	assert_int(events.size()).is_equal(5)
	assert_str(events[0].event_id).is_equal(RoundEvent.ROUND_STARTED)
	assert_int(events[0].sequence_no).is_equal(1)
	_assert_deal_event(events[1], 2, RoundEvent.HAND_PLAYER, player_first, true)
	_assert_deal_event(events[2], 3, RoundEvent.HAND_DEALER, dealer_up, true)
	_assert_deal_event(events[3], 4, RoundEvent.HAND_PLAYER, player_second, true)
	_assert_deal_event(events[4], 5, RoundEvent.HAND_DEALER, null, false)


func test_snapshot_hides_the_hole_identity_and_complete_dealer_total() -> void:
	var player_first := _card(Card.Rank.EIGHT, Card.Suit.HEARTS)
	var dealer_up := _card(Card.Rank.SEVEN, Card.Suit.SPADES)
	var player_second := _card(Card.Rank.NINE, Card.Suit.CLUBS)
	var dealer_hole := _card(Card.Rank.SIX, Card.Suit.DIAMONDS)
	var cards: Array[Card] = [
		player_first,
		dealer_up,
		player_second,
		dealer_hole,
	]
	var controller := RoundController.create_injected(
		DeckShoe.create_injected(cards, "shoe-snapshot"),
		BetLedger.new(),
	)
	assert_bool(controller.deal("round-snapshot")).is_true()

	var snapshot := controller.snapshot()
	assert_str(snapshot.round_id).is_equal("round-snapshot")
	assert_int(snapshot.current_state).is_equal(RoundController.State.PLAYER_TURN)
	assert_array(snapshot.player_cards).contains_exactly([player_first, player_second])
	assert_array(snapshot.dealer_visible_cards).contains_exactly([dealer_up])
	assert_int(snapshot.dealer_hidden_card_count).is_equal(1)
	assert_int(snapshot.player_total).is_equal(17)
	assert_bool(snapshot.dealer_total_known).is_false()
	assert_int(snapshot.dealer_total).is_equal(0)

	snapshot.player_cards.clear()
	snapshot.dealer_visible_cards.clear()
	var fresh_snapshot := controller.snapshot()
	assert_int(fresh_snapshot.player_cards.size()).is_equal(2)
	assert_int(fresh_snapshot.dealer_visible_cards.size()).is_equal(1)


func test_invalid_and_duplicate_deal_do_not_draw_or_charge_again() -> void:
	var cards: Array[Card] = [
		_card(Card.Rank.EIGHT, Card.Suit.HEARTS),
		_card(Card.Rank.SEVEN, Card.Suit.SPADES),
		_card(Card.Rank.NINE, Card.Suit.CLUBS),
		_card(Card.Rank.SIX, Card.Suit.DIAMONDS),
	]
	var ledger := BetLedger.new()
	var shoe := DeckShoe.create_injected(cards, "shoe-deal-guard")
	var controller := RoundController.create_injected(shoe, ledger)

	assert_bool(controller.deal("")).is_false()
	assert_int(shoe.draw_index()).is_equal(0)
	assert_int(ledger.available_chips).is_equal(1000)
	assert_int(ledger.committed_bet).is_equal(0)
	assert_int(controller.current_state).is_equal(RoundController.State.BETTING)

	assert_bool(controller.deal("round-deal-guard")).is_true()
	assert_bool(controller.deal("round-deal-duplicate")).is_false()
	assert_bool(controller.place_bet(100)).is_false()
	assert_int(shoe.draw_index()).is_equal(4)
	assert_int(ledger.available_chips).is_equal(990)
	assert_int(ledger.committed_bet).is_equal(10)
	assert_int(ledger.selected_bet).is_equal(10)
	assert_int(controller.current_state).is_equal(RoundController.State.PLAYER_TURN)


func test_deal_resolves_push_when_both_player_and_dealer_have_natural() -> void:
	var cards: Array[Card] = [
		_card(Card.Rank.ACE, Card.Suit.HEARTS),
		_card(Card.Rank.ACE, Card.Suit.SPADES),
		_card(Card.Rank.KING, Card.Suit.CLUBS),
		_card(Card.Rank.KING, Card.Suit.DIAMONDS),
	]
	var ledger := BetLedger.new()
	var controller := RoundController.create_injected(
		DeckShoe.create_injected(cards, "shoe-both-natural"),
		ledger,
	)
	assert_bool(controller.place_bet(100)).is_true()

	assert_bool(controller.deal("round-both-natural")).is_true()

	assert_int(controller.current_state).is_equal(RoundController.State.ROUND_END)
	assert_bool(controller.has_outcome()).is_true()
	assert_int(controller.outcome()).is_equal(BlackjackOutcome.Type.PUSH)
	assert_int(ledger.committed_bet).is_equal(0)
	assert_int(ledger.available_chips).is_equal(1000)

	var events := controller.events()
	assert_int(events.size()).is_equal(7)
	assert_str(events[5].event_id).is_equal(RoundEvent.DEALER_PEEK_COMPLETED)
	assert_str(events[6].event_id).is_equal(RoundEvent.DEALER_HOLE_CARD_REVEALED)
	assert_object(events[6].card).is_same(cards[3])
	assert_bool(events[6].face_up).is_true()

	assert_bool(controller.deal("round-both-natural-again")).is_false()
	assert_int(ledger.available_chips).is_equal(1000)


func test_deal_resolves_dealer_blackjack_after_peek_when_only_dealer_has_natural() -> void:
	var cards: Array[Card] = [
		_card(Card.Rank.EIGHT, Card.Suit.HEARTS),
		_card(Card.Rank.KING, Card.Suit.SPADES),
		_card(Card.Rank.NINE, Card.Suit.CLUBS),
		_card(Card.Rank.ACE, Card.Suit.DIAMONDS),
	]
	var ledger := BetLedger.new()
	var controller := RoundController.create_injected(
		DeckShoe.create_injected(cards, "shoe-dealer-natural"),
		ledger,
	)
	assert_bool(controller.place_bet(100)).is_true()

	assert_bool(controller.deal("round-dealer-natural")).is_true()

	assert_int(controller.current_state).is_equal(RoundController.State.ROUND_END)
	assert_bool(controller.has_outcome()).is_true()
	assert_int(controller.outcome()).is_equal(BlackjackOutcome.Type.DEALER_BLACKJACK)
	assert_int(ledger.committed_bet).is_equal(0)
	assert_int(ledger.available_chips).is_equal(900)

	var events := controller.events()
	assert_int(events.size()).is_equal(7)
	assert_str(events[5].event_id).is_equal(RoundEvent.DEALER_PEEK_COMPLETED)
	assert_str(events[6].event_id).is_equal(RoundEvent.DEALER_HOLE_CARD_REVEALED)

	assert_bool(controller.deal("round-dealer-natural-again")).is_false()
	assert_int(ledger.available_chips).is_equal(900)


func test_deal_resolves_player_blackjack_after_peek_finds_no_dealer_natural() -> void:
	var cards: Array[Card] = [
		_card(Card.Rank.ACE, Card.Suit.HEARTS),
		_card(Card.Rank.ACE, Card.Suit.SPADES),
		_card(Card.Rank.KING, Card.Suit.CLUBS),
		_card(Card.Rank.NINE, Card.Suit.DIAMONDS),
	]
	var ledger := BetLedger.new()
	var controller := RoundController.create_injected(
		DeckShoe.create_injected(cards, "shoe-player-natural-after-peek"),
		ledger,
	)
	assert_bool(controller.place_bet(100)).is_true()

	assert_bool(controller.deal("round-player-natural-after-peek")).is_true()

	assert_int(controller.current_state).is_equal(RoundController.State.ROUND_END)
	assert_bool(controller.has_outcome()).is_true()
	assert_int(controller.outcome()).is_equal(BlackjackOutcome.Type.PLAYER_BLACKJACK)
	assert_int(ledger.committed_bet).is_equal(0)
	assert_int(ledger.available_chips).is_equal(1150)

	var events := controller.events()
	assert_int(events.size()).is_equal(6)
	assert_str(events[5].event_id).is_equal(RoundEvent.DEALER_PEEK_COMPLETED)

	assert_bool(controller.deal("round-player-natural-after-peek-again")).is_false()
	assert_int(ledger.available_chips).is_equal(1150)


func test_deal_returns_to_player_turn_when_peek_finds_no_naturals() -> void:
	var cards: Array[Card] = [
		_card(Card.Rank.EIGHT, Card.Suit.HEARTS),
		_card(Card.Rank.KING, Card.Suit.SPADES),
		_card(Card.Rank.NINE, Card.Suit.CLUBS),
		_card(Card.Rank.NINE, Card.Suit.DIAMONDS),
	]
	var ledger := BetLedger.new()
	var controller := RoundController.create_injected(
		DeckShoe.create_injected(cards, "shoe-peek-no-naturals"),
		ledger,
	)
	assert_bool(controller.place_bet(100)).is_true()

	assert_bool(controller.deal("round-peek-no-naturals")).is_true()

	assert_int(controller.current_state).is_equal(RoundController.State.PLAYER_TURN)
	assert_bool(controller.has_outcome()).is_false()
	assert_int(ledger.committed_bet).is_equal(100)
	assert_int(ledger.available_chips).is_equal(900)

	var events := controller.events()
	assert_int(events.size()).is_equal(6)
	assert_str(events[5].event_id).is_equal(RoundEvent.DEALER_PEEK_COMPLETED)


func test_deal_resolves_player_blackjack_immediately_without_peek_on_low_upcard() -> void:
	var cards: Array[Card] = [
		_card(Card.Rank.ACE, Card.Suit.HEARTS),
		_card(Card.Rank.SEVEN, Card.Suit.SPADES),
		_card(Card.Rank.KING, Card.Suit.CLUBS),
		_card(Card.Rank.SIX, Card.Suit.DIAMONDS),
	]
	var ledger := BetLedger.new()
	var controller := RoundController.create_injected(
		DeckShoe.create_injected(cards, "shoe-no-peek-player-natural"),
		ledger,
	)
	assert_bool(controller.place_bet(100)).is_true()

	assert_bool(controller.deal("round-no-peek-player-natural")).is_true()

	assert_int(controller.current_state).is_equal(RoundController.State.ROUND_END)
	assert_bool(controller.has_outcome()).is_true()
	assert_int(controller.outcome()).is_equal(BlackjackOutcome.Type.PLAYER_BLACKJACK)
	assert_int(ledger.committed_bet).is_equal(0)
	assert_int(ledger.available_chips).is_equal(1150)

	var events := controller.events()
	assert_int(events.size()).is_equal(5)
	for event in events:
		assert_str(event.event_id).is_not_equal(RoundEvent.DEALER_PEEK_COMPLETED)

	assert_bool(controller.deal("round-no-peek-player-natural-again")).is_false()
	assert_int(ledger.available_chips).is_equal(1150)


func test_deal_aborts_and_refunds_when_shoe_is_exhausted_before_hole_card() -> void:
	var cards: Array[Card] = [
		_card(Card.Rank.EIGHT, Card.Suit.HEARTS),
		_card(Card.Rank.SEVEN, Card.Suit.SPADES),
		_card(Card.Rank.NINE, Card.Suit.CLUBS),
	]
	var ledger := BetLedger.new()
	var shoe := DeckShoe.create_injected(cards, "shoe-exhausted")
	var controller := RoundController.create_injected(shoe, ledger)
	assert_bool(controller.place_bet(100)).is_true()

	assert_bool(controller.deal("round-exhausted")).is_false()

	assert_int(shoe.draw_index()).is_equal(3)
	assert_int(ledger.available_chips).is_equal(1000)
	assert_int(ledger.committed_bet).is_equal(0)
	assert_bool(controller.has_outcome()).is_false()
	assert_int(controller.current_state).is_equal(RoundController.State.ROUND_END)
	assert_str(controller.last_error).is_equal(RoundController.ERROR_SHOE_EXHAUSTED)

	var metadata := controller.round_metadata()
	assert_str(metadata.round_id).is_equal("round-exhausted")
	assert_str(metadata.shoe_id).is_equal("shoe-exhausted")


func test_abort_and_refund_cannot_run_twice_and_shoe_is_not_reshuffled() -> void:
	var cards: Array[Card] = [
		_card(Card.Rank.EIGHT, Card.Suit.HEARTS),
		_card(Card.Rank.SEVEN, Card.Suit.SPADES),
		_card(Card.Rank.NINE, Card.Suit.CLUBS),
	]
	var ledger := BetLedger.new()
	var shoe := DeckShoe.create_injected(cards, "shoe-exhausted-twice")
	var controller := RoundController.create_injected(shoe, ledger)
	assert_bool(controller.place_bet(100)).is_true()
	assert_bool(controller.deal("round-exhausted-first")).is_false()

	assert_bool(controller.deal("round-exhausted-second")).is_false()
	assert_bool(controller.place_bet(50)).is_false()

	assert_int(shoe.draw_index()).is_equal(3)
	assert_int(ledger.available_chips).is_equal(1000)
	assert_int(ledger.committed_bet).is_equal(0)
	assert_int(controller.current_state).is_equal(RoundController.State.ROUND_END)


func test_settle_rejection_surfaces_explicit_error_and_refunds_instead_of_freezing() -> void:
	var cards: Array[Card] = [
		_card(Card.Rank.EIGHT, Card.Suit.HEARTS),
		_card(Card.Rank.KING, Card.Suit.SPADES),
		_card(Card.Rank.NINE, Card.Suit.CLUBS),
		_card(Card.Rank.ACE, Card.Suit.DIAMONDS),
	]
	var ledger := _SettleRejectingLedger.new()
	var controller := RoundController.create_injected(
		DeckShoe.create_injected(cards, "shoe-settle-rejected"),
		ledger,
	)
	assert_bool(controller.place_bet(100)).is_true()

	assert_bool(controller.deal("round-settle-rejected")).is_true()

	assert_int(controller.current_state).is_equal(RoundController.State.ROUND_END)
	assert_bool(controller.has_outcome()).is_false()
	assert_str(controller.last_error).is_equal(RoundController.ERROR_SETTLEMENT_REJECTED)
	assert_int(ledger.committed_bet).is_equal(0)
	assert_int(ledger.available_chips).is_equal(1000)


func test_refund_rejection_during_shoe_exhaustion_abort_surfaces_a_distinct_error() -> void:
	var cards: Array[Card] = [
		_card(Card.Rank.EIGHT, Card.Suit.HEARTS),
		_card(Card.Rank.SEVEN, Card.Suit.SPADES),
		_card(Card.Rank.NINE, Card.Suit.CLUBS),
	]
	var ledger := _RefundRejectingLedger.new()
	var controller := RoundController.create_injected(
		DeckShoe.create_injected(cards, "shoe-refund-rejected"),
		ledger,
	)
	assert_bool(controller.place_bet(100)).is_true()

	assert_bool(controller.deal("round-refund-rejected")).is_false()

	assert_int(controller.current_state).is_equal(RoundController.State.ROUND_END)
	assert_bool(controller.has_outcome()).is_false()
	assert_str(controller.last_error).is_equal(RoundController.ERROR_REFUND_REJECTED)


class _SettleRejectingLedger:
	extends BetLedger

	func settle(_round_id: String, _outcome: int) -> BetLedger.CreditResult:
		return BetLedger.CreditResult.new(false, 0, committed_bet, available_chips)


class _RefundRejectingLedger:
	extends BetLedger

	func refund(_round_id: String) -> BetLedger.CreditResult:
		return BetLedger.CreditResult.new(false, 0, committed_bet, available_chips)


func test_hit_below_21_stays_in_player_turn_and_records_the_card() -> void:
	var cards: Array[Card] = [
		_card(Card.Rank.NINE, Card.Suit.HEARTS),
		_card(Card.Rank.SEVEN, Card.Suit.SPADES),
		_card(Card.Rank.TWO, Card.Suit.CLUBS),
		_card(Card.Rank.SIX, Card.Suit.DIAMONDS),
		_card(Card.Rank.FOUR, Card.Suit.HEARTS),
	]
	var ledger := BetLedger.new()
	var shoe := DeckShoe.create_injected(cards, "shoe-hit-under-21")
	var controller := RoundController.create_injected(shoe, ledger)
	assert_bool(controller.place_bet(100)).is_true()
	assert_bool(controller.deal("round-hit-under-21")).is_true()
	assert_int(controller.current_state).is_equal(RoundController.State.PLAYER_TURN)

	assert_bool(controller.hit()).is_true()

	assert_int(controller.current_state).is_equal(RoundController.State.PLAYER_TURN)
	assert_bool(controller.has_outcome()).is_false()
	assert_int(shoe.draw_index()).is_equal(5)
	assert_int(controller.snapshot().player_total).is_equal(15)

	var events := controller.events()
	assert_int(events.size()).is_equal(6)
	assert_str(events[5].event_id).is_equal(RoundEvent.PLAYER_CARD_DEALT)
	assert_str(events[5].hand_owner).is_equal(RoundEvent.HAND_PLAYER)
	assert_object(events[5].card).is_same(cards[4])
	assert_bool(events[5].face_up).is_true()


func test_hit_to_exactly_21_closes_player_turn_and_enters_dealer_turn() -> void:
	var cards: Array[Card] = [
		_card(Card.Rank.NINE, Card.Suit.HEARTS),
		_card(Card.Rank.SEVEN, Card.Suit.SPADES),
		_card(Card.Rank.TWO, Card.Suit.CLUBS),
		_card(Card.Rank.SIX, Card.Suit.DIAMONDS),
		_card(Card.Rank.KING, Card.Suit.HEARTS),
	]
	var ledger := BetLedger.new()
	var shoe := DeckShoe.create_injected(cards, "shoe-hit-to-21")
	var controller := RoundController.create_injected(shoe, ledger)
	assert_bool(controller.place_bet(100)).is_true()
	assert_bool(controller.deal("round-hit-to-21")).is_true()

	assert_bool(controller.hit()).is_true()

	assert_int(controller.current_state).is_equal(RoundController.State.DEALER_TURN)
	assert_bool(controller.has_outcome()).is_false()
	assert_int(controller.snapshot().player_total).is_equal(21)

	assert_bool(controller.hit()).is_false()
	assert_str(controller.last_error).is_equal(RoundController.ERROR_INVALID_STATE)
	assert_int(shoe.draw_index()).is_equal(5)


func test_hit_bust_resolves_player_bust_immediately() -> void:
	var cards: Array[Card] = [
		_card(Card.Rank.TEN, Card.Suit.HEARTS),
		_card(Card.Rank.SEVEN, Card.Suit.SPADES),
		_card(Card.Rank.NINE, Card.Suit.CLUBS),
		_card(Card.Rank.SIX, Card.Suit.DIAMONDS),
		_card(Card.Rank.FIVE, Card.Suit.HEARTS),
	]
	var ledger := BetLedger.new()
	var shoe := DeckShoe.create_injected(cards, "shoe-hit-bust")
	var controller := RoundController.create_injected(shoe, ledger)
	assert_bool(controller.place_bet(100)).is_true()
	assert_bool(controller.deal("round-hit-bust")).is_true()

	assert_bool(controller.hit()).is_true()

	assert_int(controller.current_state).is_equal(RoundController.State.ROUND_END)
	assert_bool(controller.has_outcome()).is_true()
	assert_int(controller.outcome()).is_equal(BlackjackOutcome.Type.PLAYER_BUST)
	assert_int(ledger.committed_bet).is_equal(0)
	assert_int(ledger.available_chips).is_equal(900)

	assert_bool(controller.hit()).is_false()
	assert_str(controller.last_error).is_equal(RoundController.ERROR_INVALID_STATE)
	assert_int(shoe.draw_index()).is_equal(5)


func test_hit_outside_player_turn_is_rejected_without_drawing() -> void:
	var ledger := BetLedger.new()
	var shoe := DeckShoe.create_injected([], "shoe-hit-wrong-state")
	var controller := RoundController.create_injected(shoe, ledger)

	assert_bool(controller.hit()).is_false()
	assert_str(controller.last_error).is_equal(RoundController.ERROR_INVALID_STATE)
	assert_int(shoe.draw_index()).is_equal(0)


func test_stand_transitions_to_dealer_turn_without_drawing() -> void:
	var cards: Array[Card] = [
		_card(Card.Rank.NINE, Card.Suit.HEARTS),
		_card(Card.Rank.SEVEN, Card.Suit.SPADES),
		_card(Card.Rank.TWO, Card.Suit.CLUBS),
		_card(Card.Rank.SIX, Card.Suit.DIAMONDS),
	]
	var ledger := BetLedger.new()
	var shoe := DeckShoe.create_injected(cards, "shoe-stand")
	var controller := RoundController.create_injected(shoe, ledger)
	assert_bool(controller.place_bet(100)).is_true()
	assert_bool(controller.deal("round-stand")).is_true()

	assert_bool(controller.stand()).is_true()

	assert_int(controller.current_state).is_equal(RoundController.State.DEALER_TURN)
	assert_bool(controller.has_outcome()).is_false()
	assert_int(shoe.draw_index()).is_equal(4)
	assert_int(controller.snapshot().player_total).is_equal(11)

	assert_bool(controller.stand()).is_false()
	assert_str(controller.last_error).is_equal(RoundController.ERROR_INVALID_STATE)


func test_stand_outside_player_turn_is_rejected() -> void:
	var ledger := BetLedger.new()
	var shoe := DeckShoe.create_injected([], "shoe-stand-wrong-state")
	var controller := RoundController.create_injected(shoe, ledger)

	assert_bool(controller.stand()).is_false()
	assert_str(controller.last_error).is_equal(RoundController.ERROR_INVALID_STATE)


func test_double_draws_one_card_doubles_bet_and_closes_player_turn() -> void:
	var cards: Array[Card] = [
		_card(Card.Rank.NINE, Card.Suit.HEARTS),
		_card(Card.Rank.SEVEN, Card.Suit.SPADES),
		_card(Card.Rank.TWO, Card.Suit.CLUBS),
		_card(Card.Rank.SIX, Card.Suit.DIAMONDS),
		_card(Card.Rank.FIVE, Card.Suit.HEARTS),
	]
	var ledger := BetLedger.new()
	var shoe := DeckShoe.create_injected(cards, "shoe-double-success")
	var controller := RoundController.create_injected(shoe, ledger)
	assert_bool(controller.place_bet(100)).is_true()
	assert_bool(controller.deal("round-double-success")).is_true()

	assert_bool(controller.double()).is_true()

	assert_int(controller.current_state).is_equal(RoundController.State.DEALER_TURN)
	assert_bool(controller.has_outcome()).is_false()
	assert_int(ledger.committed_bet).is_equal(200)
	assert_int(ledger.available_chips).is_equal(800)
	assert_int(shoe.draw_index()).is_equal(5)
	assert_int(controller.snapshot().player_total).is_equal(16)

	var events := controller.events()
	assert_int(events.size()).is_equal(6)
	assert_str(events[5].event_id).is_equal(RoundEvent.PLAYER_CARD_DEALT)
	assert_object(events[5].card).is_same(cards[4])


func test_double_bust_settles_player_bust_on_the_doubled_bet() -> void:
	var cards: Array[Card] = [
		_card(Card.Rank.TEN, Card.Suit.HEARTS),
		_card(Card.Rank.SEVEN, Card.Suit.SPADES),
		_card(Card.Rank.NINE, Card.Suit.CLUBS),
		_card(Card.Rank.SIX, Card.Suit.DIAMONDS),
		_card(Card.Rank.FIVE, Card.Suit.HEARTS),
	]
	var ledger := BetLedger.new()
	var shoe := DeckShoe.create_injected(cards, "shoe-double-bust")
	var controller := RoundController.create_injected(shoe, ledger)
	assert_bool(controller.place_bet(100)).is_true()
	assert_bool(controller.deal("round-double-bust")).is_true()

	assert_bool(controller.double()).is_true()

	assert_int(controller.current_state).is_equal(RoundController.State.ROUND_END)
	assert_bool(controller.has_outcome()).is_true()
	assert_int(controller.outcome()).is_equal(BlackjackOutcome.Type.PLAYER_BUST)
	assert_int(ledger.committed_bet).is_equal(0)
	assert_int(ledger.available_chips).is_equal(800)


func test_double_with_insufficient_chips_is_rejected_without_drawing() -> void:
	var cards: Array[Card] = [
		_card(Card.Rank.NINE, Card.Suit.HEARTS),
		_card(Card.Rank.SEVEN, Card.Suit.SPADES),
		_card(Card.Rank.TWO, Card.Suit.CLUBS),
		_card(Card.Rank.SIX, Card.Suit.DIAMONDS),
		_card(Card.Rank.FIVE, Card.Suit.HEARTS),
	]
	var ledger := BetLedger.new()
	var shoe := DeckShoe.create_injected(cards, "shoe-double-insufficient")
	var controller := RoundController.create_injected(shoe, ledger)
	assert_bool(controller.place_bet(100)).is_true()
	assert_bool(controller.deal("round-double-insufficient")).is_true()
	ledger.available_chips = 50

	assert_bool(controller.double()).is_false()

	assert_str(controller.last_error).is_equal(RoundController.ERROR_DOUBLE_REJECTED)
	assert_int(controller.current_state).is_equal(RoundController.State.PLAYER_TURN)
	assert_int(ledger.committed_bet).is_equal(100)
	assert_int(shoe.draw_index()).is_equal(4)


func test_double_after_hit_is_rejected_as_not_the_first_decision() -> void:
	var cards: Array[Card] = [
		_card(Card.Rank.NINE, Card.Suit.HEARTS),
		_card(Card.Rank.SEVEN, Card.Suit.SPADES),
		_card(Card.Rank.TWO, Card.Suit.CLUBS),
		_card(Card.Rank.SIX, Card.Suit.DIAMONDS),
		_card(Card.Rank.THREE, Card.Suit.HEARTS),
	]
	var ledger := BetLedger.new()
	var shoe := DeckShoe.create_injected(cards, "shoe-double-after-hit")
	var controller := RoundController.create_injected(shoe, ledger)
	assert_bool(controller.place_bet(100)).is_true()
	assert_bool(controller.deal("round-double-after-hit")).is_true()
	assert_bool(controller.hit()).is_true()

	assert_bool(controller.double()).is_false()

	assert_str(controller.last_error).is_equal(RoundController.ERROR_NOT_FIRST_DECISION)
	assert_int(ledger.committed_bet).is_equal(100)
	assert_int(shoe.draw_index()).is_equal(5)


func test_surrender_after_peek_finds_no_dealer_natural_refunds_half_the_bet() -> void:
	var cards: Array[Card] = [
		_card(Card.Rank.NINE, Card.Suit.HEARTS),
		_card(Card.Rank.KING, Card.Suit.SPADES),
		_card(Card.Rank.TWO, Card.Suit.CLUBS),
		_card(Card.Rank.NINE, Card.Suit.DIAMONDS),
	]
	var ledger := BetLedger.new()
	var shoe := DeckShoe.create_injected(cards, "shoe-surrender-after-peek")
	var controller := RoundController.create_injected(shoe, ledger)
	assert_bool(controller.place_bet(100)).is_true()
	assert_bool(controller.deal("round-surrender-after-peek")).is_true()
	assert_int(controller.current_state).is_equal(RoundController.State.PLAYER_TURN)

	assert_bool(controller.surrender()).is_true()

	assert_int(controller.current_state).is_equal(RoundController.State.ROUND_END)
	assert_bool(controller.has_outcome()).is_true()
	assert_int(controller.outcome()).is_equal(BlackjackOutcome.Type.PLAYER_SURRENDER)
	assert_int(ledger.committed_bet).is_equal(0)
	assert_int(ledger.available_chips).is_equal(950)


func test_surrender_when_peek_is_not_required_refunds_half_the_bet() -> void:
	var cards: Array[Card] = [
		_card(Card.Rank.NINE, Card.Suit.HEARTS),
		_card(Card.Rank.SEVEN, Card.Suit.SPADES),
		_card(Card.Rank.TWO, Card.Suit.CLUBS),
		_card(Card.Rank.SIX, Card.Suit.DIAMONDS),
	]
	var ledger := BetLedger.new()
	var shoe := DeckShoe.create_injected(cards, "shoe-surrender-no-peek")
	var controller := RoundController.create_injected(shoe, ledger)
	assert_bool(controller.place_bet(100)).is_true()
	assert_bool(controller.deal("round-surrender-no-peek")).is_true()

	assert_bool(controller.surrender()).is_true()

	assert_int(controller.current_state).is_equal(RoundController.State.ROUND_END)
	assert_bool(controller.has_outcome()).is_true()
	assert_int(controller.outcome()).is_equal(BlackjackOutcome.Type.PLAYER_SURRENDER)
	assert_int(ledger.available_chips).is_equal(950)


func test_surrender_after_hit_is_rejected_as_not_the_first_decision() -> void:
	var cards: Array[Card] = [
		_card(Card.Rank.NINE, Card.Suit.HEARTS),
		_card(Card.Rank.SEVEN, Card.Suit.SPADES),
		_card(Card.Rank.TWO, Card.Suit.CLUBS),
		_card(Card.Rank.SIX, Card.Suit.DIAMONDS),
		_card(Card.Rank.THREE, Card.Suit.HEARTS),
	]
	var ledger := BetLedger.new()
	var shoe := DeckShoe.create_injected(cards, "shoe-surrender-after-hit")
	var controller := RoundController.create_injected(shoe, ledger)
	assert_bool(controller.place_bet(100)).is_true()
	assert_bool(controller.deal("round-surrender-after-hit")).is_true()
	assert_bool(controller.hit()).is_true()

	assert_bool(controller.surrender()).is_false()

	assert_str(controller.last_error).is_equal(RoundController.ERROR_NOT_FIRST_DECISION)
	assert_int(ledger.committed_bet).is_equal(100)
	assert_bool(controller.has_outcome()).is_false()


func test_surrender_after_dealer_natural_already_resolved_is_rejected() -> void:
	var cards: Array[Card] = [
		_card(Card.Rank.EIGHT, Card.Suit.HEARTS),
		_card(Card.Rank.KING, Card.Suit.SPADES),
		_card(Card.Rank.NINE, Card.Suit.CLUBS),
		_card(Card.Rank.ACE, Card.Suit.DIAMONDS),
	]
	var ledger := BetLedger.new()
	var shoe := DeckShoe.create_injected(cards, "shoe-surrender-after-dealer-natural")
	var controller := RoundController.create_injected(shoe, ledger)
	assert_bool(controller.place_bet(100)).is_true()
	assert_bool(controller.deal("round-surrender-after-dealer-natural")).is_true()
	assert_int(controller.current_state).is_equal(RoundController.State.ROUND_END)
	assert_int(ledger.available_chips).is_equal(900)

	assert_bool(controller.surrender()).is_false()

	assert_str(controller.last_error).is_equal(RoundController.ERROR_INVALID_STATE)
	assert_int(ledger.available_chips).is_equal(900)


func test_dealer_step_first_call_only_reveals_the_hole_card() -> void:
	var cards: Array[Card] = [
		_card(Card.Rank.NINE, Card.Suit.HEARTS),
		_card(Card.Rank.SEVEN, Card.Suit.SPADES),
		_card(Card.Rank.NINE, Card.Suit.CLUBS),
		_card(Card.Rank.KING, Card.Suit.DIAMONDS),
	]
	var ledger := BetLedger.new()
	var shoe := DeckShoe.create_injected(cards, "shoe-dealer-reveal-only")
	var controller := RoundController.create_injected(shoe, ledger)
	assert_bool(controller.place_bet(100)).is_true()
	assert_bool(controller.deal("round-dealer-reveal-only")).is_true()
	assert_bool(controller.stand()).is_true()
	var baseline_events := controller.events().size()

	assert_bool(controller.dealer_step()).is_true()

	assert_int(controller.current_state).is_equal(RoundController.State.DEALER_TURN)
	assert_bool(controller.has_outcome()).is_false()
	assert_int(shoe.draw_index()).is_equal(4)

	var new_events := controller.events()
	assert_int(new_events.size()).is_equal(baseline_events + 1)
	var reveal_event := new_events[new_events.size() - 1]
	assert_str(reveal_event.event_id).is_equal(RoundEvent.DEALER_HOLE_CARD_REVEALED)
	assert_object(reveal_event.card).is_same(cards[3])
	assert_bool(reveal_event.face_up).is_true()


func test_dealer_step_hits_exactly_one_card_when_hard_total_is_below_17() -> void:
	var cards: Array[Card] = [
		_card(Card.Rank.NINE, Card.Suit.HEARTS),
		_card(Card.Rank.NINE, Card.Suit.SPADES),
		_card(Card.Rank.NINE, Card.Suit.CLUBS),
		_card(Card.Rank.SEVEN, Card.Suit.DIAMONDS),
		_card(Card.Rank.FIVE, Card.Suit.HEARTS),
	]
	var ledger := BetLedger.new()
	var shoe := DeckShoe.create_injected(cards, "shoe-dealer-hard-16-hit")
	var controller := RoundController.create_injected(shoe, ledger)
	assert_bool(controller.place_bet(100)).is_true()
	assert_bool(controller.deal("round-dealer-hard-16-hit")).is_true()
	assert_bool(controller.stand()).is_true()
	assert_bool(controller.dealer_step()).is_true()
	var baseline_events := controller.events().size()

	assert_bool(controller.dealer_step()).is_true()

	assert_int(controller.current_state).is_equal(RoundController.State.DEALER_TURN)
	assert_bool(controller.has_outcome()).is_false()
	assert_int(shoe.draw_index()).is_equal(5)

	var new_events := controller.events()
	assert_int(new_events.size()).is_equal(baseline_events + 1)
	var hit_event := new_events[new_events.size() - 1]
	assert_str(hit_event.event_id).is_equal(RoundEvent.DEALER_CARD_DEALT)
	assert_str(hit_event.hand_owner).is_equal(RoundEvent.HAND_DEALER)
	assert_object(hit_event.card).is_same(cards[4])


func test_dealer_step_stands_on_hard_17_without_drawing() -> void:
	var cards: Array[Card] = [
		_card(Card.Rank.EIGHT, Card.Suit.HEARTS),
		_card(Card.Rank.SEVEN, Card.Suit.SPADES),
		_card(Card.Rank.EIGHT, Card.Suit.CLUBS),
		_card(Card.Rank.KING, Card.Suit.DIAMONDS),
	]
	var ledger := BetLedger.new()
	var shoe := DeckShoe.create_injected(cards, "shoe-dealer-hard-17-stand")
	var controller := RoundController.create_injected(shoe, ledger)
	assert_bool(controller.place_bet(100)).is_true()
	assert_bool(controller.deal("round-dealer-hard-17-stand")).is_true()
	assert_bool(controller.stand()).is_true()
	assert_bool(controller.dealer_step()).is_true()

	assert_bool(controller.dealer_step()).is_true()

	assert_int(shoe.draw_index()).is_equal(4)
	assert_int(controller.current_state).is_equal(RoundController.State.ROUND_END)
	assert_bool(controller.has_outcome()).is_true()
	assert_int(controller.outcome()).is_equal(BlackjackOutcome.Type.DEALER_WIN)
	assert_int(ledger.committed_bet).is_equal(0)
	assert_int(ledger.available_chips).is_equal(900)


func test_dealer_step_stands_on_soft_17_and_player_wins() -> void:
	var cards: Array[Card] = [
		_card(Card.Rank.NINE, Card.Suit.HEARTS),
		_card(Card.Rank.ACE, Card.Suit.SPADES),
		_card(Card.Rank.NINE, Card.Suit.CLUBS),
		_card(Card.Rank.SIX, Card.Suit.DIAMONDS),
	]
	var ledger := BetLedger.new()
	var shoe := DeckShoe.create_injected(cards, "shoe-dealer-soft-17-stand")
	var controller := RoundController.create_injected(shoe, ledger)
	assert_bool(controller.place_bet(100)).is_true()
	assert_bool(controller.deal("round-dealer-soft-17-stand")).is_true()
	assert_int(controller.current_state).is_equal(RoundController.State.PLAYER_TURN)
	assert_bool(controller.stand()).is_true()
	assert_bool(controller.dealer_step()).is_true()

	assert_bool(controller.dealer_step()).is_true()

	assert_int(shoe.draw_index()).is_equal(4)
	assert_int(controller.current_state).is_equal(RoundController.State.ROUND_END)
	assert_bool(controller.has_outcome()).is_true()
	assert_int(controller.outcome()).is_equal(BlackjackOutcome.Type.PLAYER_WIN)
	assert_int(ledger.committed_bet).is_equal(0)
	assert_int(ledger.available_chips).is_equal(1100)


func test_dealer_step_bust_after_hit_resolves_dealer_bust() -> void:
	var cards: Array[Card] = [
		_card(Card.Rank.NINE, Card.Suit.HEARTS),
		_card(Card.Rank.NINE, Card.Suit.SPADES),
		_card(Card.Rank.NINE, Card.Suit.CLUBS),
		_card(Card.Rank.SEVEN, Card.Suit.DIAMONDS),
		_card(Card.Rank.EIGHT, Card.Suit.HEARTS),
	]
	var ledger := BetLedger.new()
	var shoe := DeckShoe.create_injected(cards, "shoe-dealer-bust")
	var controller := RoundController.create_injected(shoe, ledger)
	assert_bool(controller.place_bet(100)).is_true()
	assert_bool(controller.deal("round-dealer-bust")).is_true()
	assert_bool(controller.stand()).is_true()
	assert_bool(controller.dealer_step()).is_true()

	assert_bool(controller.dealer_step()).is_true()

	assert_int(shoe.draw_index()).is_equal(5)
	assert_int(controller.current_state).is_equal(RoundController.State.ROUND_END)
	assert_bool(controller.has_outcome()).is_true()
	assert_int(controller.outcome()).is_equal(BlackjackOutcome.Type.DEALER_BUST)
	assert_int(ledger.committed_bet).is_equal(0)
	assert_int(ledger.available_chips).is_equal(1100)


func test_dealer_step_resolves_dealer_win_when_dealer_total_is_higher() -> void:
	var cards: Array[Card] = [
		_card(Card.Rank.EIGHT, Card.Suit.HEARTS),
		_card(Card.Rank.NINE, Card.Suit.SPADES),
		_card(Card.Rank.SEVEN, Card.Suit.CLUBS),
		_card(Card.Rank.NINE, Card.Suit.DIAMONDS),
	]
	var ledger := BetLedger.new()
	var shoe := DeckShoe.create_injected(cards, "shoe-dealer-win")
	var controller := RoundController.create_injected(shoe, ledger)
	assert_bool(controller.place_bet(100)).is_true()
	assert_bool(controller.deal("round-dealer-win")).is_true()
	assert_bool(controller.stand()).is_true()
	assert_bool(controller.dealer_step()).is_true()

	assert_bool(controller.dealer_step()).is_true()

	assert_int(controller.current_state).is_equal(RoundController.State.ROUND_END)
	assert_bool(controller.has_outcome()).is_true()
	assert_int(controller.outcome()).is_equal(BlackjackOutcome.Type.DEALER_WIN)
	assert_int(ledger.available_chips).is_equal(900)


func test_dealer_step_resolves_push_when_totals_are_equal() -> void:
	var cards: Array[Card] = [
		_card(Card.Rank.NINE, Card.Suit.HEARTS),
		_card(Card.Rank.EIGHT, Card.Suit.SPADES),
		_card(Card.Rank.EIGHT, Card.Suit.CLUBS),
		_card(Card.Rank.NINE, Card.Suit.DIAMONDS),
	]
	var ledger := BetLedger.new()
	var shoe := DeckShoe.create_injected(cards, "shoe-dealer-push")
	var controller := RoundController.create_injected(shoe, ledger)
	assert_bool(controller.place_bet(100)).is_true()
	assert_bool(controller.deal("round-dealer-push")).is_true()
	assert_bool(controller.stand()).is_true()
	assert_bool(controller.dealer_step()).is_true()

	assert_bool(controller.dealer_step()).is_true()

	assert_int(controller.current_state).is_equal(RoundController.State.ROUND_END)
	assert_bool(controller.has_outcome()).is_true()
	assert_int(controller.outcome()).is_equal(BlackjackOutcome.Type.PUSH)
	assert_int(ledger.available_chips).is_equal(1000)


func test_dealer_step_aborts_and_refunds_when_shoe_is_exhausted_mid_draw() -> void:
	var cards: Array[Card] = [
		_card(Card.Rank.NINE, Card.Suit.HEARTS),
		_card(Card.Rank.NINE, Card.Suit.SPADES),
		_card(Card.Rank.NINE, Card.Suit.CLUBS),
		_card(Card.Rank.SEVEN, Card.Suit.DIAMONDS),
	]
	var ledger := BetLedger.new()
	var shoe := DeckShoe.create_injected(cards, "shoe-dealer-exhausted")
	var controller := RoundController.create_injected(shoe, ledger)
	assert_bool(controller.place_bet(100)).is_true()
	assert_bool(controller.deal("round-dealer-exhausted")).is_true()
	assert_bool(controller.stand()).is_true()
	assert_bool(controller.dealer_step()).is_true()

	assert_bool(controller.dealer_step()).is_false()

	assert_int(shoe.draw_index()).is_equal(4)
	assert_int(controller.current_state).is_equal(RoundController.State.ROUND_END)
	assert_bool(controller.has_outcome()).is_false()
	assert_str(controller.last_error).is_equal(RoundController.ERROR_SHOE_EXHAUSTED)
	assert_int(ledger.committed_bet).is_equal(0)
	assert_int(ledger.available_chips).is_equal(1000)


func test_dealer_step_outside_dealer_turn_is_rejected() -> void:
	var ledger := BetLedger.new()
	var shoe := DeckShoe.create_injected([], "shoe-dealer-step-wrong-state")
	var controller := RoundController.create_injected(shoe, ledger)

	assert_bool(controller.dealer_step()).is_false()
	assert_str(controller.last_error).is_equal(RoundController.ERROR_INVALID_STATE)


func test_begin_presentation_empties_legal_actions_and_rejects_player_commands() -> void:
	var cards: Array[Card] = [
		_card(Card.Rank.NINE, Card.Suit.HEARTS),
		_card(Card.Rank.SEVEN, Card.Suit.SPADES),
		_card(Card.Rank.TWO, Card.Suit.CLUBS),
		_card(Card.Rank.SIX, Card.Suit.DIAMONDS),
	]
	var ledger := BetLedger.new()
	var shoe := DeckShoe.create_injected(cards, "shoe-barrier-blocks")
	var controller := RoundController.create_injected(shoe, ledger)
	assert_bool(controller.place_bet(100)).is_true()
	assert_bool(controller.deal("round-barrier-blocks")).is_true()
	assert_array(controller.legal_actions()).contains_exactly([
		RoundController.ACTION_HIT,
		RoundController.ACTION_STAND,
		RoundController.ACTION_DOUBLE,
		RoundController.ACTION_SURRENDER,
	])

	assert_bool(controller.begin_presentation("token-1")).is_true()

	assert_array(controller.legal_actions()).is_empty()
	assert_bool(controller.hit()).is_false()
	assert_str(controller.last_error).is_equal(RoundController.ERROR_PRESENTATION_BLOCKING)
	assert_bool(controller.stand()).is_false()
	assert_bool(controller.double()).is_false()
	assert_bool(controller.surrender()).is_false()
	assert_int(shoe.draw_index()).is_equal(4)


func test_begin_presentation_rejects_empty_token_and_a_second_concurrent_token() -> void:
	var ledger := BetLedger.new()
	var shoe := DeckShoe.create_injected([], "shoe-barrier-validation")
	var controller := RoundController.create_injected(shoe, ledger)

	assert_bool(controller.begin_presentation("")).is_false()

	assert_bool(controller.begin_presentation("token-a")).is_true()
	assert_bool(controller.begin_presentation("token-b")).is_false()

	assert_bool(controller.complete_presentation("token-b")).is_false()
	assert_bool(controller.complete_presentation("token-a")).is_true()


func test_complete_presentation_with_matching_token_restores_legal_actions() -> void:
	var cards: Array[Card] = [
		_card(Card.Rank.NINE, Card.Suit.HEARTS),
		_card(Card.Rank.SEVEN, Card.Suit.SPADES),
		_card(Card.Rank.TWO, Card.Suit.CLUBS),
		_card(Card.Rank.SIX, Card.Suit.DIAMONDS),
		_card(Card.Rank.FOUR, Card.Suit.HEARTS),
	]
	var ledger := BetLedger.new()
	var shoe := DeckShoe.create_injected(cards, "shoe-barrier-unblock")
	var controller := RoundController.create_injected(shoe, ledger)
	assert_bool(controller.place_bet(100)).is_true()
	assert_bool(controller.deal("round-barrier-unblock")).is_true()
	assert_bool(controller.begin_presentation("token-unblock")).is_true()

	assert_bool(controller.complete_presentation("token-unblock")).is_true()

	assert_array(controller.legal_actions()).contains_exactly([
		RoundController.ACTION_HIT,
		RoundController.ACTION_STAND,
		RoundController.ACTION_DOUBLE,
		RoundController.ACTION_SURRENDER,
	])
	assert_bool(controller.hit()).is_true()
	assert_int(shoe.draw_index()).is_equal(5)


func test_complete_presentation_with_mismatched_token_stays_blocked() -> void:
	var cards: Array[Card] = [
		_card(Card.Rank.NINE, Card.Suit.HEARTS),
		_card(Card.Rank.SEVEN, Card.Suit.SPADES),
		_card(Card.Rank.TWO, Card.Suit.CLUBS),
		_card(Card.Rank.SIX, Card.Suit.DIAMONDS),
	]
	var ledger := BetLedger.new()
	var shoe := DeckShoe.create_injected(cards, "shoe-barrier-mismatch")
	var controller := RoundController.create_injected(shoe, ledger)
	assert_bool(controller.place_bet(100)).is_true()
	assert_bool(controller.deal("round-barrier-mismatch")).is_true()
	assert_bool(controller.begin_presentation("token-real")).is_true()

	assert_bool(controller.complete_presentation("token-imposter")).is_false()

	assert_str(controller.last_error).is_equal(RoundController.ERROR_PRESENTATION_TOKEN_MISMATCH)
	assert_array(controller.legal_actions()).is_empty()
	assert_bool(controller.hit()).is_false()


func test_late_completion_after_the_first_matching_token_already_unlocked_is_ineffective() -> void:
	var cards: Array[Card] = [
		_card(Card.Rank.NINE, Card.Suit.HEARTS),
		_card(Card.Rank.SEVEN, Card.Suit.SPADES),
		_card(Card.Rank.TWO, Card.Suit.CLUBS),
		_card(Card.Rank.SIX, Card.Suit.DIAMONDS),
		_card(Card.Rank.FOUR, Card.Suit.HEARTS),
	]
	var ledger := BetLedger.new()
	var shoe := DeckShoe.create_injected(cards, "shoe-barrier-exactly-once")
	var controller := RoundController.create_injected(shoe, ledger)
	assert_bool(controller.place_bet(100)).is_true()
	assert_bool(controller.deal("round-barrier-exactly-once")).is_true()
	assert_bool(controller.begin_presentation("token-race")).is_true()

	# Simulates the fallback timeout reaching the controller first and
	# unlocking the barrier; the game then advances (HIT) before the original,
	# now-late completion signal for the same token finally arrives.
	assert_bool(controller.complete_presentation("token-race")).is_true()
	assert_bool(controller.hit()).is_true()
	assert_int(shoe.draw_index()).is_equal(5)

	assert_bool(controller.complete_presentation("token-race")).is_false()

	assert_str(controller.last_error).is_equal(RoundController.ERROR_PRESENTATION_TOKEN_MISMATCH)
	assert_int(shoe.draw_index()).is_equal(5)
	assert_bool(controller.begin_presentation("token-next")).is_true()
	assert_bool(controller.complete_presentation("token-next")).is_true()


func test_dealer_step_is_rejected_while_presentation_is_blocking() -> void:
	var cards: Array[Card] = [
		_card(Card.Rank.NINE, Card.Suit.HEARTS),
		_card(Card.Rank.SEVEN, Card.Suit.SPADES),
		_card(Card.Rank.NINE, Card.Suit.CLUBS),
		_card(Card.Rank.KING, Card.Suit.DIAMONDS),
	]
	var ledger := BetLedger.new()
	var shoe := DeckShoe.create_injected(cards, "shoe-barrier-dealer-step")
	var controller := RoundController.create_injected(shoe, ledger)
	assert_bool(controller.place_bet(100)).is_true()
	assert_bool(controller.deal("round-barrier-dealer-step")).is_true()
	assert_bool(controller.stand()).is_true()
	assert_bool(controller.begin_presentation("token-dealer")).is_true()

	assert_bool(controller.dealer_step()).is_false()

	assert_str(controller.last_error).is_equal(RoundController.ERROR_PRESENTATION_BLOCKING)
	assert_int(shoe.draw_index()).is_equal(4)


func test_next_round_is_rejected_before_round_end_without_side_effects() -> void:
	var ledger := BetLedger.new()
	var shoe := DeckShoe.create_injected([], "shoe-next-round-wrong-state-betting")
	var controller := RoundController.create_injected(shoe, ledger)

	assert_bool(controller.next_round()).is_false()
	assert_str(controller.last_error).is_equal(RoundController.ERROR_INVALID_STATE)
	assert_int(controller.current_state).is_equal(RoundController.State.BETTING)

	var cards: Array[Card] = [
		_card(Card.Rank.NINE, Card.Suit.HEARTS),
		_card(Card.Rank.SEVEN, Card.Suit.SPADES),
		_card(Card.Rank.TWO, Card.Suit.CLUBS),
		_card(Card.Rank.SIX, Card.Suit.DIAMONDS),
	]
	var shoe2 := DeckShoe.create_injected(cards, "shoe-next-round-wrong-state-player-turn")
	var controller2 := RoundController.create_injected(shoe2, ledger)
	assert_bool(controller2.place_bet(100)).is_true()
	assert_bool(controller2.deal("round-next-round-wrong-state")).is_true()

	assert_bool(controller2.next_round()).is_false()

	assert_str(controller2.last_error).is_equal(RoundController.ERROR_INVALID_STATE)
	assert_int(controller2.current_state).is_equal(RoundController.State.PLAYER_TURN)
	assert_int(ledger.selected_bet).is_equal(100)


func test_next_round_retains_the_shoe_at_exactly_20_remaining_cards_and_resets_round_state() -> void:
	var cards: Array[Card] = [
		_card(Card.Rank.ACE, Card.Suit.HEARTS),
		_card(Card.Rank.ACE, Card.Suit.SPADES),
		_card(Card.Rank.KING, Card.Suit.CLUBS),
		_card(Card.Rank.KING, Card.Suit.DIAMONDS),
	]
	for _i in range(20):
		cards.append(_card(Card.Rank.TWO, Card.Suit.HEARTS))
	var ledger := BetLedger.new()
	var shoe := DeckShoe.create_injected(cards, "shoe-retain-at-20")
	var controller := RoundController.create_injected(shoe, ledger)
	assert_bool(controller.place_bet(100)).is_true()
	assert_bool(controller.deal("round-retain-at-20")).is_true()
	assert_int(controller.current_state).is_equal(RoundController.State.ROUND_END)
	assert_int(shoe.remaining_count()).is_equal(20)
	assert_array(controller.legal_actions()).contains_exactly([RoundController.ACTION_NEXT_ROUND])

	assert_bool(controller.next_round()).is_true()

	assert_int(controller.current_state).is_equal(RoundController.State.BETTING)
	assert_bool(controller.has_active_round()).is_false()
	assert_bool(controller.has_outcome()).is_false()
	assert_int(ledger.selected_bet).is_equal(BetLedger.MINIMUM_BET)
	assert_int(ledger.committed_bet).is_equal(0)

	assert_bool(controller.deal("round-retain-at-20-second")).is_true()
	assert_int(shoe.draw_index()).is_equal(8)


func test_next_round_requires_an_explicit_replacement_shoe_below_20_remaining_cards() -> void:
	var cards: Array[Card] = [
		_card(Card.Rank.ACE, Card.Suit.HEARTS),
		_card(Card.Rank.ACE, Card.Suit.SPADES),
		_card(Card.Rank.KING, Card.Suit.CLUBS),
		_card(Card.Rank.KING, Card.Suit.DIAMONDS),
	]
	for _i in range(15):
		cards.append(_card(Card.Rank.TWO, Card.Suit.HEARTS))
	var ledger := BetLedger.new()
	var shoe := DeckShoe.create_injected(cards, "shoe-requires-replacement")
	var controller := RoundController.create_injected(shoe, ledger)
	assert_bool(controller.place_bet(100)).is_true()
	assert_bool(controller.deal("round-requires-replacement")).is_true()
	assert_int(shoe.remaining_count()).is_equal(15)

	assert_bool(controller.next_round()).is_false()

	assert_str(controller.last_error).is_equal(RoundController.ERROR_NEXT_SHOE_REQUIRED)
	assert_int(controller.current_state).is_equal(RoundController.State.ROUND_END)
	assert_int(ledger.selected_bet).is_equal(100)

	assert_bool(controller.next_round("shoe-replacement-below-20", 999)).is_true()

	assert_int(controller.current_state).is_equal(RoundController.State.BETTING)
	assert_int(ledger.selected_bet).is_equal(BetLedger.MINIMUM_BET)


func test_next_round_replacement_shoe_is_reproducible_from_the_same_id_and_seed() -> void:
	var cards: Array[Card] = [
		_card(Card.Rank.ACE, Card.Suit.HEARTS),
		_card(Card.Rank.ACE, Card.Suit.SPADES),
		_card(Card.Rank.KING, Card.Suit.CLUBS),
		_card(Card.Rank.KING, Card.Suit.DIAMONDS),
	]
	for _i in range(15):
		cards.append(_card(Card.Rank.TWO, Card.Suit.HEARTS))
	var ledger := BetLedger.new()
	var shoe := DeckShoe.create_injected(cards, "shoe-repro-before")
	var controller := RoundController.create_injected(shoe, ledger)
	assert_bool(controller.place_bet(100)).is_true()
	assert_bool(controller.deal("round-repro-before")).is_true()
	assert_bool(controller.next_round("shoe-repro", 4242)).is_true()
	assert_bool(controller.place_bet(100)).is_true()

	assert_bool(controller.deal("round-repro-after")).is_true()

	var snapshot := controller.snapshot()
	var reference_shoe := DeckShoe.create_runtime("shoe-repro", 4242)
	var reference_player_first := reference_shoe.draw_card()
	var reference_dealer_up := reference_shoe.draw_card()
	var reference_player_second := reference_shoe.draw_card()
	assert_int(snapshot.player_cards[0].rank).is_equal(reference_player_first.rank)
	assert_int(snapshot.player_cards[0].suit).is_equal(reference_player_first.suit)
	assert_int(snapshot.dealer_visible_cards[0].rank).is_equal(reference_dealer_up.rank)
	assert_int(snapshot.dealer_visible_cards[0].suit).is_equal(reference_dealer_up.suit)
	assert_int(snapshot.player_cards[1].rank).is_equal(reference_player_second.rank)
	assert_int(snapshot.player_cards[1].suit).is_equal(reference_player_second.suit)


func test_next_round_requires_replacement_after_a_shoe_exhaustion_abort() -> void:
	var cards: Array[Card] = [
		_card(Card.Rank.EIGHT, Card.Suit.HEARTS),
		_card(Card.Rank.SEVEN, Card.Suit.SPADES),
		_card(Card.Rank.NINE, Card.Suit.CLUBS),
	]
	var ledger := BetLedger.new()
	var shoe := DeckShoe.create_injected(cards, "shoe-next-round-after-abort")
	var controller := RoundController.create_injected(shoe, ledger)
	assert_bool(controller.place_bet(100)).is_true()
	assert_bool(controller.deal("round-next-round-after-abort")).is_false()
	assert_int(controller.current_state).is_equal(RoundController.State.ROUND_END)

	assert_bool(controller.next_round()).is_false()

	assert_str(controller.last_error).is_equal(RoundController.ERROR_NEXT_SHOE_REQUIRED)

	assert_bool(controller.next_round("shoe-after-abort", 55)).is_true()

	assert_int(controller.current_state).is_equal(RoundController.State.BETTING)
	assert_bool(controller.place_bet(100)).is_true()
	assert_bool(controller.deal("round-after-abort-replacement")).is_true()


func test_next_round_is_rejected_while_presentation_is_blocking() -> void:
	var cards: Array[Card] = [
		_card(Card.Rank.ACE, Card.Suit.HEARTS),
		_card(Card.Rank.ACE, Card.Suit.SPADES),
		_card(Card.Rank.KING, Card.Suit.CLUBS),
		_card(Card.Rank.KING, Card.Suit.DIAMONDS),
	]
	for _i in range(20):
		cards.append(_card(Card.Rank.TWO, Card.Suit.HEARTS))
	var ledger := BetLedger.new()
	var shoe := DeckShoe.create_injected(cards, "shoe-next-round-blocked")
	var controller := RoundController.create_injected(shoe, ledger)
	assert_bool(controller.place_bet(100)).is_true()
	assert_bool(controller.deal("round-next-round-blocked")).is_true()
	assert_bool(controller.begin_presentation("token-next-round")).is_true()

	assert_bool(controller.next_round()).is_false()

	assert_str(controller.last_error).is_equal(RoundController.ERROR_PRESENTATION_BLOCKING)
	assert_int(controller.current_state).is_equal(RoundController.State.ROUND_END)

	assert_bool(controller.complete_presentation("token-next-round")).is_true()
	assert_bool(controller.next_round()).is_true()


func _assert_deal_event(
	event: RoundEvent,
	sequence_no: int,
	hand_owner: StringName,
	card: Card,
	face_up: bool,
) -> void:
	assert_str(event.event_id).is_equal(RoundEvent.INITIAL_CARD_DEALT)
	assert_str(event.round_id).is_equal("round-deal")
	assert_int(event.sequence_no).is_equal(sequence_no)
	assert_str(event.hand_owner).is_equal(hand_owner)
	assert_bool(event.face_up).is_equal(face_up)
	assert_object(event.card).is_same(card)


func _card(rank: int, suit: int) -> Card:
	return Card.new(rank, suit)
