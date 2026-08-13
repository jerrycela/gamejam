class_name BetLedger
extends RefCounted
## Pure integer chip and bet accounting for the approved prototype profile.

const STARTING_CHIPS: int = 1000
const MINIMUM_BET: int = 10
const MAXIMUM_BET: int = 500

class CreditResult:
	extends RefCounted

	var accepted: bool
	var credit: int
	var committed_bet_before: int
	var available_chips_after: int


	func _init(
		was_accepted: bool,
		credit_amount: int,
		committed_before: int,
		chips_after: int,
	) -> void:
		accepted = was_accepted
		credit = credit_amount
		committed_bet_before = committed_before
		available_chips_after = chips_after


var available_chips: int = STARTING_CHIPS
var selected_bet: int = MINIMUM_BET
var committed_bet: int = 0
var minimum_bet: int = MINIMUM_BET
var maximum_bet: int = MAXIMUM_BET

var _active_round_id: String = ""
var _committed_round_ids: Dictionary[String, bool] = {}
var _doubled_round_ids: Dictionary[String, bool] = {}
var _closed_round_ids: Dictionary[String, bool] = {}


func set_selected_bet(amount: int) -> bool:
	if committed_bet != 0:
		return false
	if amount < minimum_bet or amount > maximum_bet:
		return false
	if amount > available_chips:
		return false
	selected_bet = amount
	return true


func commit(round_id: String) -> bool:
	if round_id.is_empty():
		return false
	if not _active_round_id.is_empty() or committed_bet != 0:
		return false
	if _committed_round_ids.has(round_id):
		return false
	if selected_bet < minimum_bet or selected_bet > maximum_bet:
		return false
	if selected_bet > available_chips:
		return false

	available_chips -= selected_bet
	committed_bet = selected_bet
	_active_round_id = round_id
	_committed_round_ids[round_id] = true
	return true


func double_committed_bet(round_id: String) -> bool:
	if round_id != _active_round_id or committed_bet <= 0:
		return false
	if _doubled_round_ids.has(round_id):
		return false
	if available_chips < committed_bet:
		return false

	available_chips -= committed_bet
	committed_bet *= 2
	_doubled_round_ids[round_id] = true
	return true


func settle(round_id: String, outcome: int) -> CreditResult:
	if round_id != _active_round_id or committed_bet <= 0:
		return _rejected_credit_result()
	if _closed_round_ids.has(round_id):
		return _rejected_credit_result()
	if not BlackjackOutcome.is_valid(outcome):
		return _rejected_credit_result()

	var committed_before := committed_bet
	var credit := _settlement_credit(outcome, committed_before)
	available_chips += credit
	committed_bet = 0
	_active_round_id = ""
	_closed_round_ids[round_id] = true
	return CreditResult.new(true, credit, committed_before, available_chips)


func refund(round_id: String) -> CreditResult:
	if round_id != _active_round_id or committed_bet <= 0:
		return _rejected_credit_result()
	if _closed_round_ids.has(round_id):
		return _rejected_credit_result()

	var committed_before := committed_bet
	available_chips += committed_before
	committed_bet = 0
	_active_round_id = ""
	_closed_round_ids[round_id] = true
	return CreditResult.new(true, committed_before, committed_before, available_chips)


func prepare_next_round() -> bool:
	if not _active_round_id.is_empty() or committed_bet != 0:
		return false
	if available_chips < minimum_bet:
		available_chips = STARTING_CHIPS
	selected_bet = minimum_bet
	return true


func _settlement_credit(outcome: int, committed: int) -> int:
	match outcome:
		BlackjackOutcome.Type.PLAYER_BLACKJACK:
			return committed + _half_rounded_up(committed * 3)
		BlackjackOutcome.Type.PLAYER_WIN, BlackjackOutcome.Type.DEALER_BUST:
			return committed * 2
		BlackjackOutcome.Type.PUSH:
			return committed
		BlackjackOutcome.Type.PLAYER_SURRENDER:
			return _half_rounded_up(committed)
		_:
			return 0


func _half_rounded_up(value: int) -> int:
	return (value >> 1) + (value & 1)


func _rejected_credit_result() -> CreditResult:
	return CreditResult.new(false, 0, committed_bet, available_chips)
