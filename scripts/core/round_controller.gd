class_name RoundController
extends RefCounted
## Deterministic authority for one Blackjack round.

enum State {
	BETTING,
	INITIAL_DEAL,
	PLAYER_TURN,
	DEALER_TURN,
	RESOLVE_ROUND,
	ROUND_END,
}

const ACTION_PLACE_BET: StringName = &"PLACE_BET"
const ACTION_DEAL: StringName = &"DEAL"
const ACTION_HIT: StringName = &"HIT"
const ACTION_STAND: StringName = &"STAND"
const ACTION_DOUBLE: StringName = &"DOUBLE"
const ACTION_SURRENDER: StringName = &"SURRENDER"

const ERROR_INVALID_STATE: StringName = &"INVALID_STATE"
const ERROR_BET_REJECTED: StringName = &"BET_REJECTED"
const ERROR_DEAL_REJECTED: StringName = &"DEAL_REJECTED"
const ERROR_SHOE_EXHAUSTED: StringName = &"SHOE_EXHAUSTED"
const ERROR_SETTLEMENT_REJECTED: StringName = &"SETTLEMENT_REJECTED"
const ERROR_REFUND_REJECTED: StringName = &"REFUND_REJECTED"
const ERROR_NOT_FIRST_DECISION: StringName = &"NOT_FIRST_DECISION"
const ERROR_DOUBLE_REJECTED: StringName = &"DOUBLE_REJECTED"

var current_state: State = State.BETTING
var last_error: StringName = &""

var _shoe: DeckShoe
var _ledger: BetLedger
var _round_id: String = ""
var _has_outcome: bool = false
var _outcome: int = -1
var _player_turn_decision_made: bool = false
var _round_metadata: DeckShoe.RoundStartMetadata
var _player_cards: Array[Card] = []
var _dealer_cards: Array[Card] = []
var _events: Array[RoundEvent] = []
var _sequence_no: int = 0


static func create_injected(shoe: DeckShoe, ledger: BetLedger) -> RoundController:
	var controller := RoundController.new()
	controller._shoe = shoe
	controller._ledger = ledger
	return controller


func legal_actions() -> Array[StringName]:
	var actions: Array[StringName] = []
	if current_state == State.BETTING:
		actions.assign([ACTION_PLACE_BET, ACTION_DEAL])
	return actions


func place_bet(amount: int) -> bool:
	if current_state != State.BETTING:
		last_error = ERROR_INVALID_STATE
		return false
	if not _ledger.set_selected_bet(amount):
		last_error = ERROR_BET_REJECTED
		return false
	last_error = &""
	return true


func deal(round_id: String) -> bool:
	if current_state != State.BETTING or round_id.is_empty():
		last_error = ERROR_INVALID_STATE if current_state != State.BETTING else ERROR_DEAL_REJECTED
		return false
	if not _ledger.commit(round_id):
		last_error = ERROR_DEAL_REJECTED
		return false

	_round_id = round_id
	_round_metadata = _shoe.capture_round_start(round_id)
	current_state = State.INITIAL_DEAL
	_emit_event(RoundEvent.ROUND_STARTED)

	if not _draw_initial_card(RoundEvent.HAND_PLAYER, true):
		_abort_for_shoe_exhaustion()
		return false
	if not _draw_initial_card(RoundEvent.HAND_DEALER, true):
		_abort_for_shoe_exhaustion()
		return false
	if not _draw_initial_card(RoundEvent.HAND_PLAYER, true):
		_abort_for_shoe_exhaustion()
		return false
	if not _draw_initial_card(RoundEvent.HAND_DEALER, false):
		_abort_for_shoe_exhaustion()
		return false

	last_error = &""
	_resolve_naturals()
	return true


func hit() -> bool:
	if current_state != State.PLAYER_TURN:
		last_error = ERROR_INVALID_STATE
		return false
	if not _draw_player_turn_card():
		_abort_for_shoe_exhaustion()
		return false

	last_error = &""
	_player_turn_decision_made = true
	var evaluation := HandEvaluator.evaluate(_player_cards)
	if evaluation.is_bust:
		_settle_round(BlackjackOutcome.Type.PLAYER_BUST)
	elif evaluation.total == 21:
		current_state = State.DEALER_TURN
	return true


func stand() -> bool:
	if current_state != State.PLAYER_TURN:
		last_error = ERROR_INVALID_STATE
		return false
	_player_turn_decision_made = true
	current_state = State.DEALER_TURN
	last_error = &""
	return true


func double() -> bool:
	if current_state != State.PLAYER_TURN:
		last_error = ERROR_INVALID_STATE
		return false
	if _player_turn_decision_made:
		last_error = ERROR_NOT_FIRST_DECISION
		return false
	if not _ledger.double_committed_bet(_round_id):
		last_error = ERROR_DOUBLE_REJECTED
		return false

	_player_turn_decision_made = true
	if not _draw_player_turn_card():
		_abort_for_shoe_exhaustion()
		return false

	last_error = &""
	var evaluation := HandEvaluator.evaluate(_player_cards)
	if evaluation.is_bust:
		_settle_round(BlackjackOutcome.Type.PLAYER_BUST)
	else:
		current_state = State.DEALER_TURN
	return true


func surrender() -> bool:
	if current_state != State.PLAYER_TURN:
		last_error = ERROR_INVALID_STATE
		return false
	if _player_turn_decision_made:
		last_error = ERROR_NOT_FIRST_DECISION
		return false

	_player_turn_decision_made = true
	last_error = &""
	_settle_round(BlackjackOutcome.Type.PLAYER_SURRENDER)
	return true


func round_metadata() -> DeckShoe.RoundStartMetadata:
	if _round_metadata == null:
		return null
	return DeckShoe.RoundStartMetadata.new(
		_round_metadata.round_id,
		_round_metadata.shoe_id,
		_round_metadata.shuffle_seed,
		_round_metadata.draw_index_at_round_start,
	)


func events() -> Array[RoundEvent]:
	var event_copy: Array[RoundEvent] = []
	event_copy.assign(_events)
	return event_copy


func snapshot() -> RoundSnapshot:
	var player_evaluation := HandEvaluator.evaluate(_player_cards)
	var dealer_visible_cards: Array[Card] = []
	if not _dealer_cards.is_empty():
		dealer_visible_cards.append(_dealer_cards[0])
	return RoundSnapshot.new(
		_round_id,
		current_state,
		_player_cards,
		dealer_visible_cards,
		maxi(_dealer_cards.size() - dealer_visible_cards.size(), 0),
		player_evaluation.total,
		false,
		0,
	)


func has_active_round() -> bool:
	return not _round_id.is_empty()


func has_outcome() -> bool:
	return _has_outcome


func outcome() -> int:
	return _outcome


func _resolve_naturals() -> void:
	var player_natural := HandEvaluator.evaluate(_player_cards).is_blackjack
	var dealer_natural := false

	if _is_peek_upcard(_dealer_cards[0]):
		dealer_natural = HandEvaluator.evaluate(_dealer_cards).is_blackjack
		_emit_event(RoundEvent.DEALER_PEEK_COMPLETED, RoundEvent.HAND_DEALER)
		if dealer_natural:
			_emit_event(
				RoundEvent.HOLE_CARD_REVEALED,
				RoundEvent.HAND_DEALER,
				_dealer_cards[1],
				true,
			)

	if not player_natural and not dealer_natural:
		_player_turn_decision_made = false
		current_state = State.PLAYER_TURN
		return

	var outcome_type: int
	if player_natural and dealer_natural:
		outcome_type = BlackjackOutcome.Type.PUSH
	elif dealer_natural:
		outcome_type = BlackjackOutcome.Type.DEALER_BLACKJACK
	else:
		outcome_type = BlackjackOutcome.Type.PLAYER_BLACKJACK
	_settle_round(outcome_type)


func _settle_round(outcome_type: int) -> void:
	current_state = State.RESOLVE_ROUND
	var result := _ledger.settle(_round_id, outcome_type)
	if result.accepted:
		_outcome = outcome_type
		_has_outcome = true
		current_state = State.ROUND_END
		return

	# Settlement was rejected: do not strand the round in a state that looks
	# finished but neither paid out nor released the committed bet. Fall back
	# to refunding so chips are not permanently locked, and surface a distinct
	# error so the caller can detect the failure instead of reading silence.
	last_error = ERROR_SETTLEMENT_REJECTED
	var fallback_refund := _ledger.refund(_round_id)
	if not fallback_refund.accepted:
		last_error = ERROR_REFUND_REJECTED
	current_state = State.ROUND_END


func _abort_for_shoe_exhaustion() -> void:
	if current_state == State.ROUND_END:
		return
	var refund_result := _ledger.refund(_round_id)
	current_state = State.ROUND_END
	last_error = ERROR_SHOE_EXHAUSTED if refund_result.accepted else ERROR_REFUND_REJECTED


func _is_peek_upcard(card: Card) -> bool:
	return card.rank == Card.Rank.ACE or card.rank >= Card.Rank.TEN


func _draw_player_turn_card() -> bool:
	var drawn_card := _shoe.draw_card()
	if drawn_card == null:
		last_error = ERROR_SHOE_EXHAUSTED
		return false
	_player_cards.append(drawn_card)
	_emit_event(RoundEvent.PLAYER_CARD_DEALT, RoundEvent.HAND_PLAYER, drawn_card, true)
	return true


func _draw_initial_card(hand_owner: StringName, face_up: bool) -> bool:
	var drawn_card := _shoe.draw_card()
	if drawn_card == null:
		last_error = ERROR_SHOE_EXHAUSTED
		return false

	if hand_owner == RoundEvent.HAND_PLAYER:
		_player_cards.append(drawn_card)
	else:
		_dealer_cards.append(drawn_card)
	_emit_event(
		RoundEvent.INITIAL_CARD_DEALT,
		hand_owner,
		drawn_card if face_up else null,
		face_up,
	)
	return true


func _emit_event(
	event_id: StringName,
	hand_owner: StringName = &"",
	card: Card = null,
	face_up: bool = false,
) -> void:
	_sequence_no += 1
	_events.append(RoundEvent.new(
		event_id,
		_round_id,
		_sequence_no,
		hand_owner,
		card,
		face_up,
	))
