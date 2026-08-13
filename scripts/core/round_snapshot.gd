class_name RoundSnapshot
extends RefCounted
## Defensive public projection of the current core round state.

var round_id: String
var current_state: int
var player_cards: Array[Card] = []
var dealer_visible_cards: Array[Card] = []
var dealer_hidden_card_count: int
var player_total: int
var dealer_total_known: bool
var dealer_total: int


func _init(
	round_identifier: String,
	state: int,
	visible_player_cards: Array[Card],
	visible_dealer_cards: Array[Card],
	hidden_dealer_cards: int,
	visible_player_total: int,
	is_dealer_total_known: bool,
	visible_dealer_total: int,
) -> void:
	round_id = round_identifier
	current_state = state
	player_cards.assign(visible_player_cards)
	dealer_visible_cards.assign(visible_dealer_cards)
	dealer_hidden_card_count = hidden_dealer_cards
	player_total = visible_player_total
	dealer_total_known = is_dealer_total_known
	dealer_total = visible_dealer_total
