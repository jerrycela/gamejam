class_name Card
extends RefCounted
## Immutable-enough value object for one standard playing card.

enum Suit {
	CLUBS,
	DIAMONDS,
	HEARTS,
	SPADES,
}

enum Rank {
	ACE = 1,
	TWO = 2,
	THREE = 3,
	FOUR = 4,
	FIVE = 5,
	SIX = 6,
	SEVEN = 7,
	EIGHT = 8,
	NINE = 9,
	TEN = 10,
	JACK = 11,
	QUEEN = 12,
	KING = 13,
}

var rank: int
var suit: int


func _init(card_rank: int, card_suit: int) -> void:
	rank = card_rank
	suit = card_suit

