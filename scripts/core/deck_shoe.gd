class_name DeckShoe
extends RefCounted
## Pure card storage and top-first draw cursor for one Blackjack Shoe.

const RUNTIME_DECK_COUNT: int = 6
const CARDS_PER_DECK: int = 52
const RUNTIME_CARD_COUNT: int = RUNTIME_DECK_COUNT * CARDS_PER_DECK
const RESHUFFLE_REMAINING_THRESHOLD: int = 20

class RoundStartMetadata:
	extends RefCounted

	var round_id: String
	var shoe_id: String
	var shuffle_seed: int
	var draw_index_at_round_start: int


	func _init(
		round_identifier: String,
		shoe_identifier: String,
		seed_value: int,
		start_index: int,
	) -> void:
		round_id = round_identifier
		shoe_id = shoe_identifier
		shuffle_seed = seed_value
		draw_index_at_round_start = start_index


var _cards: Array[Card] = []
var _draw_index: int = 0
var _shoe_id: String
var _shuffle_seed: int


func _init(cards: Array[Card], shoe_id: String, shuffle_seed: int) -> void:
	for card in cards:
		_cards.append(card)
	_shoe_id = shoe_id
	_shuffle_seed = shuffle_seed


static func create_injected(cards: Array[Card], shoe_id: String) -> DeckShoe:
	return DeckShoe.new(cards, shoe_id, 0)


static func create_runtime(shoe_id: String, shuffle_seed: int) -> DeckShoe:
	var cards: Array[Card] = []
	for _deck_index in range(RUNTIME_DECK_COUNT):
		for suit_value in Card.Suit.values():
			var suit: int = suit_value
			for rank in range(Card.Rank.ACE, Card.Rank.KING + 1):
				cards.append(Card.new(rank, suit))
	_shuffle_cards(cards, shuffle_seed)
	return DeckShoe.new(cards, shoe_id, shuffle_seed)


static func _shuffle_cards(cards: Array[Card], shuffle_seed: int) -> void:
	var random := RandomNumberGenerator.new()
	random.seed = shuffle_seed
	for card_index in range(cards.size() - 1, 0, -1):
		var swap_index := random.randi_range(0, card_index)
		var card: Card = cards[card_index]
		cards[card_index] = cards[swap_index]
		cards[swap_index] = card


func draw_card() -> Card:
	if not can_draw(1):
		return null
	var card: Card = _cards[_draw_index]
	_draw_index += 1
	return card


func can_draw(card_count: int) -> bool:
	return card_count >= 0 and card_count <= remaining_count()


func remaining_count() -> int:
	return _cards.size() - _draw_index


func draw_index() -> int:
	return _draw_index


func should_reshuffle_before_next_round() -> bool:
	return remaining_count() < RESHUFFLE_REMAINING_THRESHOLD


func capture_round_start(round_id: String) -> RoundStartMetadata:
	return RoundStartMetadata.new(
		round_id,
		_shoe_id,
		_shuffle_seed,
		_draw_index,
	)
