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
const ACTION_NEXT_ROUND: StringName = &"NEXT_ROUND"

const ERROR_INVALID_STATE: StringName = &"INVALID_STATE"
const ERROR_BET_REJECTED: StringName = &"BET_REJECTED"
const ERROR_DEAL_REJECTED: StringName = &"DEAL_REJECTED"
const ERROR_SHOE_EXHAUSTED: StringName = &"SHOE_EXHAUSTED"
const ERROR_SETTLEMENT_REJECTED: StringName = &"SETTLEMENT_REJECTED"
const ERROR_REFUND_REJECTED: StringName = &"REFUND_REJECTED"
const ERROR_NOT_FIRST_DECISION: StringName = &"NOT_FIRST_DECISION"
const ERROR_DOUBLE_REJECTED: StringName = &"DOUBLE_REJECTED"
const ERROR_PRESENTATION_TOKEN_INVALID: StringName = &"PRESENTATION_TOKEN_INVALID"
const ERROR_PRESENTATION_ALREADY_ACTIVE: StringName = &"PRESENTATION_ALREADY_ACTIVE"
const ERROR_PRESENTATION_TOKEN_REUSED: StringName = &"PRESENTATION_TOKEN_REUSED"
const ERROR_PRESENTATION_TOKEN_MISMATCH: StringName = &"PRESENTATION_TOKEN_MISMATCH"
const ERROR_PRESENTATION_BLOCKING: StringName = &"PRESENTATION_BLOCKING"
const ERROR_NEXT_ROUND_REJECTED: StringName = &"NEXT_ROUND_REJECTED"
const ERROR_NEXT_SHOE_REQUIRED: StringName = &"NEXT_SHOE_REQUIRED"

var current_state: State = State.BETTING
var last_error: StringName = &""

var _shoe: DeckShoe
var _ledger: BetLedger
var _round_id: String = ""
var _has_outcome: bool = false
var _outcome: int = -1
var _player_turn_decision_made: bool = false
var _dealer_hole_revealed: bool = false
var _active_presentation_token: String = ""
var _used_presentation_tokens: Dictionary[String, bool] = {}
var _requires_new_shoe: bool = false
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
	if not _active_presentation_token.is_empty():
		return actions
	if current_state == State.BETTING:
		actions.assign([ACTION_PLACE_BET, ACTION_DEAL])
	elif current_state == State.PLAYER_TURN:
		actions.append(ACTION_HIT)
		actions.append(ACTION_STAND)
		if not _player_turn_decision_made:
			actions.append(ACTION_DOUBLE)
			actions.append(ACTION_SURRENDER)
	elif current_state == State.ROUND_END:
		actions.append(ACTION_NEXT_ROUND)
	return actions


func begin_presentation(token: String) -> bool:
	if token.is_empty():
		last_error = ERROR_PRESENTATION_TOKEN_INVALID
		return false
	if not _active_presentation_token.is_empty():
		last_error = ERROR_PRESENTATION_ALREADY_ACTIVE
		return false
	if _used_presentation_tokens.has(token):
		last_error = ERROR_PRESENTATION_TOKEN_REUSED
		return false
	_active_presentation_token = token
	_used_presentation_tokens[token] = true
	last_error = &""
	return true


func complete_presentation(token: String) -> bool:
	if token.is_empty() or token != _active_presentation_token:
		last_error = ERROR_PRESENTATION_TOKEN_MISMATCH
		return false
	_active_presentation_token = ""
	last_error = &""
	return true


func place_bet(amount: int) -> bool:
	if _reject_if_presentation_blocking():
		return false
	if current_state != State.BETTING:
		last_error = ERROR_INVALID_STATE
		return false
	if not _ledger.set_selected_bet(amount):
		last_error = ERROR_BET_REJECTED
		return false
	last_error = &""
	return true


func deal(round_id: String) -> bool:
	if _reject_if_presentation_blocking():
		return false
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
	if _reject_if_presentation_blocking():
		return false
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
		_enter_dealer_turn()
	return true


func stand() -> bool:
	if _reject_if_presentation_blocking():
		return false
	if current_state != State.PLAYER_TURN:
		last_error = ERROR_INVALID_STATE
		return false
	_player_turn_decision_made = true
	_enter_dealer_turn()
	last_error = &""
	return true


func double() -> bool:
	if _reject_if_presentation_blocking():
		return false
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
		_enter_dealer_turn()
	return true


func surrender() -> bool:
	if _reject_if_presentation_blocking():
		return false
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


func dealer_step() -> bool:
	if _reject_if_presentation_blocking():
		return false
	if current_state != State.DEALER_TURN:
		last_error = ERROR_INVALID_STATE
		return false

	if not _dealer_hole_revealed:
		_dealer_hole_revealed = true
		_emit_event(
			RoundEvent.DEALER_HOLE_CARD_REVEALED,
			RoundEvent.HAND_DEALER,
			_dealer_cards[1],
			true,
		)
		last_error = &""
		return true

	var evaluation := HandEvaluator.evaluate(_dealer_cards)
	if evaluation.total < 17:
		if not _draw_dealer_card():
			_abort_for_shoe_exhaustion()
			return false
		last_error = &""
		evaluation = HandEvaluator.evaluate(_dealer_cards)
		if evaluation.is_bust:
			_settle_round(BlackjackOutcome.Type.DEALER_BUST)
		return true

	last_error = &""
	_settle_dealer_comparison(evaluation.total)
	return true


func next_round(next_shoe_id: String = "", next_shuffle_seed: int = 0) -> bool:
	if _reject_if_presentation_blocking():
		return false
	if current_state != State.ROUND_END:
		last_error = ERROR_INVALID_STATE
		return false

	var shoe_replacement_required := _requires_new_shoe or _shoe.should_reshuffle_before_next_round()
	if shoe_replacement_required and next_shoe_id.is_empty():
		last_error = ERROR_NEXT_SHOE_REQUIRED
		return false

	if not _ledger.prepare_next_round():
		last_error = ERROR_NEXT_ROUND_REJECTED
		return false

	if shoe_replacement_required:
		_shoe = DeckShoe.create_runtime(next_shoe_id, next_shuffle_seed)
		_requires_new_shoe = false

	_reset_round_state()
	current_state = State.BETTING
	last_error = &""
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
				RoundEvent.DEALER_HOLE_CARD_REVEALED,
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


func _reject_if_presentation_blocking() -> bool:
	if _active_presentation_token.is_empty():
		return false
	last_error = ERROR_PRESENTATION_BLOCKING
	return true


func _settle_dealer_comparison(dealer_total: int) -> void:
	var player_total := HandEvaluator.evaluate(_player_cards).total
	var outcome_type: int
	if dealer_total > player_total:
		outcome_type = BlackjackOutcome.Type.DEALER_WIN
	elif dealer_total < player_total:
		outcome_type = BlackjackOutcome.Type.PLAYER_WIN
	else:
		outcome_type = BlackjackOutcome.Type.PUSH
	_settle_round(outcome_type)


func _enter_dealer_turn() -> void:
	_dealer_hole_revealed = false
	current_state = State.DEALER_TURN


func _abort_for_shoe_exhaustion() -> void:
	if current_state == State.ROUND_END:
		return
	var refund_result := _ledger.refund(_round_id)
	_requires_new_shoe = true
	current_state = State.ROUND_END
	last_error = ERROR_SHOE_EXHAUSTED if refund_result.accepted else ERROR_REFUND_REJECTED


func _reset_round_state() -> void:
	_round_id = ""
	_round_metadata = null
	_player_cards = []
	_dealer_cards = []
	_has_outcome = false
	_outcome = -1
	_player_turn_decision_made = false
	_dealer_hole_revealed = false


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


func _draw_dealer_card() -> bool:
	var drawn_card := _shoe.draw_card()
	if drawn_card == null:
		last_error = ERROR_SHOE_EXHAUSTED
		return false
	_dealer_cards.append(drawn_card)
	_emit_event(RoundEvent.DEALER_CARD_DEALT, RoundEvent.HAND_DEALER, drawn_card, true)
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
