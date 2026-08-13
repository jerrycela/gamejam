class_name HandEvaluator
extends RefCounted
## Pure Blackjack hand-value calculation with no SceneTree dependency.


class Evaluation:
	extends RefCounted

	var total: int
	var is_soft: bool
	var is_blackjack: bool
	var is_bust: bool
	var card_count: int


	func _init(
		value: int,
		soft: bool,
		blackjack: bool,
		bust: bool,
		count: int,
	) -> void:
		total = value
		is_soft = soft
		is_blackjack = blackjack
		is_bust = bust
		card_count = count


static func evaluate(cards: Array[Card]) -> Evaluation:
	var total := 0
	var ace_count := 0
	for card in cards:
		if card.rank == Card.Rank.ACE:
			ace_count += 1
			total += 11
		elif card.rank >= Card.Rank.TWO and card.rank <= Card.Rank.TEN:
			total += card.rank
		elif card.rank >= Card.Rank.JACK and card.rank <= Card.Rank.KING:
			total += 10

	var aces_counted_as_eleven := ace_count
	while total > 21 and aces_counted_as_eleven > 0:
		total -= 10
		aces_counted_as_eleven -= 1

	return Evaluation.new(
		total,
		aces_counted_as_eleven > 0,
		cards.size() == 2 and total == 21,
		total > 21,
		cards.size(),
	)
