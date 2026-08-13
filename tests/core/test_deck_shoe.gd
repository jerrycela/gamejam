class_name TestDeckShoe
extends GdUnitTestSuite


func test_injected_shoe_draws_top_first_and_tracks_position() -> void:
	var cards: Array[Card] = [
		Card.new(Card.Rank.ACE, Card.Suit.SPADES),
		Card.new(Card.Rank.TEN, Card.Suit.HEARTS),
		Card.new(Card.Rank.FIVE, Card.Suit.CLUBS),
	]
	var shoe := DeckShoe.create_injected(cards, "injected-order")

	var first_card: Card = shoe.draw_card()
	var second_card: Card = shoe.draw_card()

	assert_int(first_card.rank).is_equal(Card.Rank.ACE)
	assert_int(first_card.suit).is_equal(Card.Suit.SPADES)
	assert_int(second_card.rank).is_equal(Card.Rank.TEN)
	assert_int(second_card.suit).is_equal(Card.Suit.HEARTS)
	assert_int(shoe.draw_index()).is_equal(2)
	assert_int(shoe.remaining_count()).is_equal(1)


func test_injected_shoe_copies_the_callers_array() -> void:
	var cards: Array[Card] = [
		Card.new(Card.Rank.THREE, Card.Suit.DIAMONDS),
		Card.new(Card.Rank.QUEEN, Card.Suit.CLUBS),
	]
	var shoe := DeckShoe.create_injected(cards, "injected-copy")

	cards.clear()

	assert_int(shoe.remaining_count()).is_equal(2)
	var first_card: Card = shoe.draw_card()
	assert_int(first_card.rank).is_equal(Card.Rank.THREE)
	assert_int(first_card.suit).is_equal(Card.Suit.DIAMONDS)


func test_exhausted_shoe_returns_null_without_advancing_or_reshuffling() -> void:
	var cards: Array[Card] = [
		Card.new(Card.Rank.SEVEN, Card.Suit.HEARTS),
	]
	var shoe := DeckShoe.create_injected(cards, "injected-exhaustion")

	assert_bool(shoe.can_draw(1)).is_true()
	assert_bool(shoe.can_draw(0)).is_true()
	assert_bool(shoe.can_draw(-1)).is_false()
	shoe.draw_card()

	assert_bool(shoe.can_draw(1)).is_false()
	assert_object(shoe.draw_card()).is_null()
	assert_int(shoe.draw_index()).is_equal(1)
	assert_int(shoe.remaining_count()).is_equal(0)


func test_runtime_shoe_contains_six_complete_standard_decks() -> void:
	var shoe := DeckShoe.create_runtime("runtime-composition", 123456)
	var counts: Dictionary[String, int] = {}

	assert_int(shoe.remaining_count()).is_equal(312)
	while shoe.can_draw(1):
		var card: Card = shoe.draw_card()
		var card_key := "%d:%d" % [card.rank, card.suit]
		counts[card_key] = counts.get(card_key, 0) + 1

	assert_int(shoe.draw_index()).is_equal(312)
	assert_int(counts.size()).is_equal(52)
	for count in counts.values():
		assert_int(count).is_equal(6)


func test_runtime_shuffle_is_reproducible_from_its_seed() -> void:
	var first_order := _draw_complete_order(
		DeckShoe.create_runtime("runtime-seed-a", 8675309),
	)
	var repeated_order := _draw_complete_order(
		DeckShoe.create_runtime("runtime-seed-b", 8675309),
	)
	var different_order := _draw_complete_order(
		DeckShoe.create_runtime("runtime-seed-c", 8675310),
	)

	assert_array(first_order).is_equal(repeated_order)
	assert_array(first_order).is_not_equal(different_order)


func test_round_start_metadata_captures_shoe_seed_and_current_position() -> void:
	var shoe := DeckShoe.create_runtime("runtime-metadata", 424242)
	shoe.draw_card()
	shoe.draw_card()

	var metadata := shoe.capture_round_start("round-007")

	assert_str(metadata.round_id).is_equal("round-007")
	assert_str(metadata.shoe_id).is_equal("runtime-metadata")
	assert_int(metadata.shuffle_seed).is_equal(424242)
	assert_int(metadata.draw_index_at_round_start).is_equal(2)
	assert_int(shoe.draw_index()).is_equal(2)


func test_reshuffle_is_required_below_twenty_cards_but_not_at_twenty() -> void:
	var cards: Array[Card] = []
	for _card_index in range(20):
		cards.append(Card.new(Card.Rank.TWO, Card.Suit.CLUBS))
	var shoe := DeckShoe.create_injected(cards, "injected-threshold")

	assert_bool(shoe.should_reshuffle_before_next_round()).is_false()
	shoe.draw_card()

	assert_int(shoe.remaining_count()).is_equal(19)
	assert_bool(shoe.should_reshuffle_before_next_round()).is_true()


func _draw_complete_order(shoe: DeckShoe) -> Array[String]:
	var order: Array[String] = []
	while shoe.can_draw(1):
		var card: Card = shoe.draw_card()
		order.append("%d:%d" % [card.rank, card.suit])
	return order
