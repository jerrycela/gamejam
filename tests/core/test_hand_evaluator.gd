class_name TestHandEvaluator
extends GdUnitTestSuite


func test_ten_plus_eight_is_hard_18() -> void:
	var cards: Array[Card] = [
		Card.new(Card.Rank.TEN, Card.Suit.SPADES),
		Card.new(Card.Rank.EIGHT, Card.Suit.HEARTS),
	]

	var result := HandEvaluator.evaluate(cards)

	assert_int(result.total).is_equal(18)
	assert_bool(result.is_soft).is_false()
	assert_bool(result.is_blackjack).is_false()
	assert_bool(result.is_bust).is_false()
	assert_int(result.card_count).is_equal(2)


func test_king_plus_eight_is_hard_18() -> void:
	var cards: Array[Card] = [
		Card.new(Card.Rank.KING, Card.Suit.CLUBS),
		Card.new(Card.Rank.EIGHT, Card.Suit.DIAMONDS),
	]

	var result := HandEvaluator.evaluate(cards)

	assert_int(result.total).is_equal(18)
	assert_bool(result.is_soft).is_false()


func test_ace_plus_seven_is_soft_18() -> void:
	var cards: Array[Card] = [
		Card.new(Card.Rank.ACE, Card.Suit.SPADES),
		Card.new(Card.Rank.SEVEN, Card.Suit.HEARTS),
	]

	var result := HandEvaluator.evaluate(cards)

	assert_int(result.total).is_equal(18)
	assert_bool(result.is_soft).is_true()


func test_ace_downgrades_to_one_to_avoid_bust() -> void:
	var cards: Array[Card] = [
		Card.new(Card.Rank.ACE, Card.Suit.SPADES),
		Card.new(Card.Rank.SEVEN, Card.Suit.HEARTS),
		Card.new(Card.Rank.NINE, Card.Suit.CLUBS),
	]

	var result := HandEvaluator.evaluate(cards)

	assert_int(result.total).is_equal(17)
	assert_bool(result.is_soft).is_false()


func test_one_of_multiple_aces_can_remain_soft() -> void:
	var cards: Array[Card] = [
		Card.new(Card.Rank.ACE, Card.Suit.SPADES),
		Card.new(Card.Rank.ACE, Card.Suit.HEARTS),
		Card.new(Card.Rank.NINE, Card.Suit.CLUBS),
	]

	var result := HandEvaluator.evaluate(cards)

	assert_int(result.total).is_equal(21)
	assert_bool(result.is_soft).is_true()


func test_all_aces_downgrade_when_needed() -> void:
	var cards: Array[Card] = [
		Card.new(Card.Rank.ACE, Card.Suit.SPADES),
		Card.new(Card.Rank.ACE, Card.Suit.HEARTS),
		Card.new(Card.Rank.NINE, Card.Suit.CLUBS),
		Card.new(Card.Rank.NINE, Card.Suit.DIAMONDS),
	]

	var result := HandEvaluator.evaluate(cards)

	assert_int(result.total).is_equal(20)
	assert_bool(result.is_soft).is_false()


func test_total_over_21_is_bust() -> void:
	var cards: Array[Card] = [
		Card.new(Card.Rank.TEN, Card.Suit.SPADES),
		Card.new(Card.Rank.SIX, Card.Suit.HEARTS),
		Card.new(Card.Rank.EIGHT, Card.Suit.CLUBS),
	]

	var result := HandEvaluator.evaluate(cards)

	assert_int(result.total).is_equal(24)
	assert_bool(result.is_bust).is_true()


func test_two_card_ace_and_king_is_natural_blackjack() -> void:
	var cards: Array[Card] = [
		Card.new(Card.Rank.ACE, Card.Suit.SPADES),
		Card.new(Card.Rank.KING, Card.Suit.HEARTS),
	]

	var result := HandEvaluator.evaluate(cards)

	assert_int(result.total).is_equal(21)
	assert_bool(result.is_blackjack).is_true()


func test_three_card_21_is_not_natural_blackjack() -> void:
	var cards: Array[Card] = [
		Card.new(Card.Rank.ACE, Card.Suit.SPADES),
		Card.new(Card.Rank.KING, Card.Suit.HEARTS),
		Card.new(Card.Rank.KING, Card.Suit.CLUBS),
	]

	var result := HandEvaluator.evaluate(cards)

	assert_int(result.total).is_equal(21)
	assert_bool(result.is_blackjack).is_false()
