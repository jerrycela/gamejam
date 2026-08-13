class_name PresentationController
extends Node
## L2 presentation contract (specs/003 "L2 Behavior", docs/03_INTERACTION_CONTRACTS.md
## §6-8). Owns exactly the two blocking events this spec registers — Deal card
## and Dealer hole card reveal — plus their `fallback_duration_ms` safety nets.
## The third registered row (ambient/idle glow) is `blocking: false` and is the
## L3 loop itself; it never calls into RoundController.begin_presentation and
## therefore needs no code here (docs/03:107-109).
##
## Presentation Mapping (docs/03_INTERACTION_CONTRACTS.md:112-117 format),
## matching specs/003 "L2 Behavior" table — keep code and doc in sync, no
## magic numbers duplicated elsewhere (L2-5):
##   | Event                     | blocking | fallback_duration_ms |
##   | Deal card (4-card initial)| true     | 1500                 |
##   | Dealer hole card reveal   | true     | 1200                 |
##   | Ambient/idle glow (L3)    | false    | n/a (not started here)|
##
## Hard rule this class must uphold (docs/03_INTERACTION_CONTRACTS.md:136):
## PresentationController never decides the next legal action. On completion
## (real or fallback) it always re-reads RoundController.legal_actions() and
## only reflects that result onto ActionBar; it never advances state itself.

const FALLBACK_DEAL_CARD_MS: int = 1500
const FALLBACK_DEALER_HOLE_REVEAL_MS: int = 1200

signal presentation_started(kind: StringName, token: String)
signal presentation_completed(kind: StringName, token: String, via_fallback: bool)
signal presentation_completion_rejected(kind: StringName, token: String, reason: StringName)

const _ACTION_ID_BY_BUTTON_ACTION := {
	ActionButtonView.Action.HIT: RoundController.ACTION_HIT,
	ActionButtonView.Action.STAND: RoundController.ACTION_STAND,
	ActionButtonView.Action.DOUBLE: RoundController.ACTION_DOUBLE,
	ActionButtonView.Action.SURRENDER: RoundController.ACTION_SURRENDER,
}

var _controller: RoundController = null
var _action_bar: Control = null

var _token_sequence: int = 0
var _active_token: String = ""
var _active_kind: StringName = &""
var _fallback_timer: Timer = null

# Overridable only through override_fallback_ms_for_test(); production code
# must always read FALLBACK_DEAL_CARD_MS / FALLBACK_DEALER_HOLE_REVEAL_MS.
var _fallback_ms_deal_card: int = FALLBACK_DEAL_CARD_MS
var _fallback_ms_dealer_hole_reveal: int = FALLBACK_DEALER_HOLE_REVEAL_MS


func setup(round_controller: RoundController, action_bar: Control) -> void:
	_controller = round_controller
	_action_bar = action_bar


func active_token() -> String:
	return _active_token


## Wraps RoundController.deal(): the core commit/draw/peek resolution runs
## synchronously and instantly (it is the authority), then a single blocking
## presentation opens to represent the four-card deal animation catching up
## to what already happened. Returns false without starting anything if the
## core rejects the deal (e.g. wrong state, bet not committed).
func begin_deal_presentation(round_id: String) -> bool:
	if _controller == null:
		return false
	if not _controller.deal(round_id):
		return false
	_begin_presentation(&"DEAL_CARD", _fallback_ms_deal_card)
	return true


## Wraps RoundController.dealer_step(): only opens a blocking presentation
## when this particular call was the one that revealed the dealer's hole
## card (the first dealer_step() call in DEALER_TURN). Any other dealer_step
## outcome (a hit, a stand/resolve) is out of this spec's registered mapping
## and is left uncovered here, per specs/003 Out of Scope.
func begin_dealer_hole_reveal_presentation() -> bool:
	if _controller == null:
		return false
	var events_before := _controller.events().size()
	if not _controller.dealer_step():
		return false
	var events_after := _controller.events()
	if events_after.size() <= events_before:
		return false
	var latest_event: RoundEvent = events_after[events_after.size() - 1]
	if latest_event.event_id != RoundEvent.DEALER_HOLE_CARD_REVEALED:
		return false
	_begin_presentation(&"DEALER_HOLE_REVEAL", _fallback_ms_dealer_hole_reveal)
	return true


## The "M-->>P: finished" arrow from docs/03 §3's sequence diagram — call
## this when the real animation/media actually finishes playing.
func notify_presentation_finished(token: String) -> bool:
	return _complete(token, false)


## docs/03_INTERACTION_CONTRACTS.md §8 Failure Fallback: log the failed
## asset, then complete within bounded time instead of staying in HOLD
## forever. This stub has no real text/Tween fallback visual yet (no asset
## pipeline exists for that at this stage) — it only guarantees the safety
## property: HOLD is never permanent.
func report_asset_load_failure(asset_id: String) -> void:
	if _active_token.is_empty():
		return
	push_warning(
		"PresentationController: asset load failed (%s) during %s (%s) — completing via fallback" % [
			asset_id, _active_kind, _active_token,
		]
	)
	_complete(_active_token, true)


## Test seam: invokes exactly the same completion path a real Timer timeout
## would, without waiting for wall-clock time. Production code must rely on
## the Timer firing naturally (see test_fallback_timer_actually_fires_and_completes_the_presentation
## for a real-timer end-to-end check).
func force_fallback_timeout_for_test() -> void:
	_on_fallback_timeout()


## Test seam: shortens both fallback windows so a real Timer-driven test can
## finish quickly. Never used by production wiring.
func override_fallback_ms_for_test(ms: int) -> void:
	_fallback_ms_deal_card = ms
	_fallback_ms_dealer_hole_reveal = ms


func _begin_presentation(kind: StringName, fallback_ms: int) -> void:
	_token_sequence += 1
	var token := "%s-%d" % [kind, _token_sequence]
	if not _controller.begin_presentation(token):
		push_error(
			"PresentationController: begin_presentation rejected for %s (%s)" % [
				kind, _controller.last_error,
			]
		)
		return
	_active_token = token
	_active_kind = kind
	_set_action_bar_disabled(true)
	_start_fallback_timer(fallback_ms)
	presentation_started.emit(kind, token)


func _complete(token: String, via_fallback: bool) -> bool:
	var kind := _active_kind
	# The exactly-once completion guard is owned entirely by
	# RoundController.complete_presentation() (specs/003 L2-1/L2-2) — this
	# class does not reimplement it, it only reacts to the result.
	var accepted := _controller.complete_presentation(token)
	if not accepted:
		presentation_completion_rejected.emit(kind, token, _controller.last_error)
		return false
	if _fallback_timer != null:
		_fallback_timer.stop()
	_active_token = ""
	_active_kind = &""
	_set_action_bar_disabled(false)
	_sync_action_bar_with_legal_actions()
	presentation_completed.emit(kind, token, via_fallback)
	return true


func _on_fallback_timeout() -> void:
	if _active_token.is_empty():
		return
	_complete(_active_token, true)


func _start_fallback_timer(fallback_ms: int) -> void:
	if _fallback_timer == null:
		_fallback_timer = Timer.new()
		_fallback_timer.one_shot = true
		_fallback_timer.timeout.connect(_on_fallback_timeout)
		add_child(_fallback_timer)
	_fallback_timer.stop()
	_fallback_timer.wait_time = maxf(0.001, fallback_ms / 1000.0)
	_fallback_timer.start()


## ActionBar.disabled = true (docs/03_INTERACTION_CONTRACTS.md:126) means
## every button in the bar rejects input; the HBoxContainer/Control itself is
## never freed or have its children cleared — only each Button's own
## `disabled` flag flips, so no button disappears-then-reappears.
func _set_action_bar_disabled(disabled: bool) -> void:
	if _action_bar == null:
		return
	for child in _action_bar.get_children():
		if child is BaseButton:
			(child as BaseButton).disabled = disabled


## docs/03_INTERACTION_CONTRACTS.md:132-136: RoundController decides the next
## legal actions; ActionBar only reflects that result. This is the only place
## PresentationController reads game state to drive UI, and it always reads
## it fresh from RoundController.legal_actions() rather than caching or
## guessing a transition.
func _sync_action_bar_with_legal_actions() -> void:
	if _action_bar == null or _controller == null:
		return
	var legal := _controller.legal_actions()
	for child in _action_bar.get_children():
		if child is ActionButtonView:
			var button := child as ActionButtonView
			var action_id: StringName = _ACTION_ID_BY_BUTTON_ACTION.get(button.action, &"")
			button.disabled = not legal.has(action_id)
