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
