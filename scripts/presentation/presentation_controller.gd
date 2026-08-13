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

## docs/13 §2.1 (team-lead to register): the *normal* completion path for
## each blocking presentation. Before this, nothing in production ever
## called notify_presentation_finished() — every presentation ran out its
## full FALLBACK_*_MS safety-net window before unblocking, even though
## there is no real animation yet to wait for (team-lead's soak test:
## barrier held exactly ~1504ms on every single deal, matching
## FALLBACK_DEAL_CARD_MS to the millisecond). These dwell timers give the
## player a short, deliberate pause — long enough to read that something
## happened, far shorter than the safety net — then call
## notify_presentation_finished() themselves: the same public entry point a
## real future animation would call. FALLBACK_DEAL_CARD_MS/
## FALLBACK_DEALER_HOLE_REVEAL_MS stay exactly as they were (1500/1200) —
## they remain the safety net for a stuck/failed asset load, not the normal
## timing; only the ceiling's *meaning* was wrong, not its value.
const DEAL_CARD_PRESENTATION_DWELL_MS: int = 350
const DEALER_HOLE_REVEAL_PRESENTATION_DWELL_MS: int = 300

## docs/03_INTERACTION_CONTRACTS.md:142-149 (Failure Fallback) step 2-3: on
## asset load failure, show a text fallback for a bounded dwell, then
## complete. 400ms is a judgment call (not a Figma motion token — `02
## Foundations` only records discrete-transition durations far shorter than
## a "let the player actually read this" dwell): long enough to be legible,
## comfortably inside both registered fallback_duration_ms values (1200/1500)
## so the overall presentation still resolves well within its own safety
## net.
const FALLBACK_VISUAL_DWELL_MS: int = 400

## Deliberately generic/non-technical — docs/03:144 sends the asset ID to
## the log (see report_asset_load_failure), never to the screen.
const FALLBACK_VISUAL_TEXT: String = "請稍候…"

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
var _fallback_overlay: Control = null

var _token_sequence: int = 0
var _active_token: String = ""
var _active_kind: StringName = &""
var _fallback_timer: Timer = null
var _fallback_visual_timer: Timer = null
var _fallback_label: Label = null
var _pending_fallback_visual_token: String = ""
var _completion_timer: Timer = null
var _pending_completion_token: String = ""

# Overridable only through override_fallback_ms_for_test(); production code
# must always read FALLBACK_DEAL_CARD_MS / FALLBACK_DEALER_HOLE_REVEAL_MS.
var _fallback_ms_deal_card: int = FALLBACK_DEAL_CARD_MS
var _fallback_ms_dealer_hole_reveal: int = FALLBACK_DEALER_HOLE_REVEAL_MS

# Overridable only through override_presentation_dwell_ms_for_test();
# production code must always read DEAL_CARD_PRESENTATION_DWELL_MS /
# DEALER_HOLE_REVEAL_PRESENTATION_DWELL_MS.
var _dwell_ms_deal_card: int = DEAL_CARD_PRESENTATION_DWELL_MS
var _dwell_ms_dealer_hole_reveal: int = DEALER_HOLE_REVEAL_PRESENTATION_DWELL_MS


## `fallback_overlay` is optional (specs/003 L2-4): the Control this
## controller adds its fallback text Label into when
## report_asset_load_failure() fires — the caller should pass one of
## L2Root's own layers (ResultOverlay or DealerReactionLayer), matching
## where a real dealer-reaction/result asset would otherwise have appeared.
## Left null, the fallback path still logs and completes safely, it just
## has nothing to show — existing callers that only pass 2 args are
## unaffected.
func setup(round_controller: RoundController, action_bar: Control, fallback_overlay: Control = null) -> void:
	_controller = round_controller
	_action_bar = action_bar
	_fallback_overlay = fallback_overlay


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
	_begin_presentation(&"DEAL_CARD", _fallback_ms_deal_card, round_id)
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
	_begin_presentation(&"DEALER_HOLE_REVEAL", _fallback_ms_dealer_hole_reveal, _current_round_id())
	return true


## The "M-->>P: finished" arrow from docs/03 §3's sequence diagram — call
## this when the real animation/media actually finishes playing.
func notify_presentation_finished(token: String) -> bool:
	return _complete(token, false)


## docs/03_INTERACTION_CONTRACTS.md §8 Failure Fallback, all 4 steps: (1)
## log the failed asset, (2) show a text fallback visual, (3) complete
## within bounded time, (4) never stay in HOLD forever. The asset ID is only
## ever logged here (push_warning) — it never reaches FALLBACK_VISUAL_TEXT,
## which is fixed and generic on purpose (docs/03:144).
func report_asset_load_failure(asset_id: String) -> void:
	if _active_token.is_empty():
		return
	push_warning(
		"PresentationController: asset load failed (%s) during %s (%s) — showing fallback visual" % [
			asset_id, _active_kind, _active_token,
		]
	)
	_show_fallback_visual()
	_pending_fallback_visual_token = _active_token
	# The normal-path completion timer racing to finish "on schedule" would
	# be reporting a success that didn't happen — an asset load failure
	# means the normal path is moot, so stop it rather than let it win a
	# race it has no business winning.
	if _completion_timer != null:
		_completion_timer.stop()
	_pending_completion_token = ""
	_start_fallback_visual_timer(FALLBACK_VISUAL_DWELL_MS)


## Test seam: invokes exactly the same completion path a real Timer timeout
## would, without waiting for wall-clock time. Production code must rely on
## the Timer firing naturally (see test_fallback_timer_actually_fires_and_completes_the_presentation
## for a real-timer end-to-end check).
func force_fallback_timeout_for_test() -> void:
	_on_fallback_timeout()


## Test seam: same idea as force_fallback_timeout_for_test(), for the
## fallback *visual*'s own dwell timer (started by report_asset_load_failure()).
func force_fallback_visual_dwell_elapsed_for_test() -> void:
	_on_fallback_visual_dwell_elapsed()


## Test seam: same idea as force_fallback_timeout_for_test(), for the
## *normal* per-presentation completion dwell (started by _begin_presentation()
## itself, not by a failure path) — lets a synchronous test prove the normal
## path fires without a real wall-clock wait.
func force_completion_dwell_elapsed_for_test() -> void:
	_on_completion_dwell_elapsed()


## Test seam: shortens both completion dwells so a real Timer-driven test can
## finish quickly. Never used by production wiring — mirrors
## override_fallback_ms_for_test().
func override_presentation_dwell_ms_for_test(ms: int) -> void:
	_dwell_ms_deal_card = ms
	_dwell_ms_dealer_hole_reveal = ms


## True while the fallback text is on screen — from report_asset_load_failure()
## until its dwell timer elapses (or, defensively, once _complete() runs at
## all, in case some future caller drives completion by another path).
func is_fallback_visual_visible() -> bool:
	return _fallback_label != null and _fallback_label.visible


## The currently-shown fallback text, or "" if none is showing. Test-facing;
## production code never branches on this.
func fallback_visual_text() -> String:
	return _fallback_label.text if _fallback_label != null else ""


## Test seam: shortens both fallback windows so a real Timer-driven test can
## finish quickly. Never used by production wiring.
func override_fallback_ms_for_test(ms: int) -> void:
	_fallback_ms_deal_card = ms
	_fallback_ms_dealer_hole_reveal = ms


## Tokens are only guaranteed unique for the lifetime of this
## PresentationController instance (`_token_sequence` is per-instance state).
## RoundController's `_used_presentation_tokens` guard never clears, not even
## across NEXT_ROUND (see tests/core/test_round_controller.gd
## test_begin_presentation_rejects_a_token_reused_across_a_next_round_boundary),
## so a fresh instance's counter restarting at 0 would otherwise collide with
## a token already burned by a previous instance on the same RoundController
## (e.g. this node destroyed and recreated between rounds). round_id is
## already unique per round by construction (RoundController.deal() requires
## a caller-supplied round_id), so folding it into the token closes that gap
## without requiring any cross-instance coordination.
func _current_round_id() -> String:
	var metadata := _controller.round_metadata()
	return metadata.round_id if metadata != null else ""


func _begin_presentation(kind: StringName, fallback_ms: int, round_id: String) -> void:
	_token_sequence += 1
	var token := "%s-%s-%d" % [round_id, kind, _token_sequence]
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
	_start_completion_timer(token, _dwell_ms_for_kind(kind))
	presentation_started.emit(kind, token)


func _dwell_ms_for_kind(kind: StringName) -> int:
	if kind == &"DEALER_HOLE_REVEAL":
		return _dwell_ms_dealer_hole_reveal
	return _dwell_ms_deal_card


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
	if _completion_timer != null:
		_completion_timer.stop()
	_pending_completion_token = ""
	_active_token = ""
	# _active_kind is deliberately NOT cleared here: `_active_token.is_empty()`
	# is the sole "no presentation is active" signal used elsewhere in this
	# class. Keeping the last-known kind means a late/mismatched completion
	# arriving after this one still reports which presentation it was late
	# for in its diagnostic signal, instead of an uninformative "".
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


## docs/03_INTERACTION_CONTRACTS.md:142-149 step 3: the fallback visual's own
## dwell elapsing is what actually completes the presentation on this path
## (report_asset_load_failure() only shows the visual and starts this timer).
func _on_fallback_visual_dwell_elapsed() -> void:
	var token := _pending_fallback_visual_token
	_pending_fallback_visual_token = ""
	_hide_fallback_visual()
	if token.is_empty():
		return
	_complete(token, true)


func _start_fallback_visual_timer(dwell_ms: int) -> void:
	if _fallback_visual_timer == null:
		_fallback_visual_timer = Timer.new()
		_fallback_visual_timer.one_shot = true
		_fallback_visual_timer.timeout.connect(_on_fallback_visual_dwell_elapsed)
		add_child(_fallback_visual_timer)
	_fallback_visual_timer.stop()
	_fallback_visual_timer.wait_time = maxf(0.001, dwell_ms / 1000.0)
	_fallback_visual_timer.start()


## docs/13 §2.1: the normal-path completion — the dwell timer started by
## _begin_presentation() itself elapsing means "enough time has passed for
## the (future) animation to have plausibly finished", so this calls the
## exact same _complete() path notify_presentation_finished() would, with
## via_fallback = false. If a real completion or the fallback safety net has
## already won the race (_pending_completion_token cleared by _complete() or
## report_asset_load_failure()), this is a no-op — _complete()'s own
## exactly-once guard would have caught it anyway, but checking here avoids
## emitting a pointless rejected-completion diagnostic for a timer that was
## always going to lose gracefully.
func _on_completion_dwell_elapsed() -> void:
	var token := _pending_completion_token
	_pending_completion_token = ""
	if token.is_empty():
		return
	_complete(token, false)


## docs/13 §2.1: starts (once, then reuses) the Timer backing the normal
## completion path. Mirrors _start_fallback_timer()/_start_fallback_visual_timer()
## exactly — one-shot, restarted fresh on every call, duration read from the
## per-kind dwell constant (see _dwell_ms_for_kind()), never from the fallback
## constants.
func _start_completion_timer(token: String, dwell_ms: int) -> void:
	_pending_completion_token = token
	if _completion_timer == null:
		_completion_timer = Timer.new()
		_completion_timer.one_shot = true
		_completion_timer.timeout.connect(_on_completion_dwell_elapsed)
		add_child(_completion_timer)
	_completion_timer.stop()
	_completion_timer.wait_time = maxf(0.001, dwell_ms / 1000.0)
	_completion_timer.start()


## Creates (once) and shows the fallback Label inside `_fallback_overlay`.
## Theme-driven (default_font_size / Label font_color already come from
## res://ui/theme/lsbj_theme.tres via the overlay's inherited theme, docs/05
## §5 Theme First) — no color/size literal is set here. No-op if setup()
## was never given an overlay to draw into.
func _show_fallback_visual() -> void:
	if _fallback_overlay == null:
		return
	if _fallback_label == null:
		_fallback_label = Label.new()
		_fallback_label.name = "PresentationFallbackLabel"
		_fallback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_fallback_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_fallback_label.set_anchors_preset(Control.PRESET_FULL_RECT)
		_fallback_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_fallback_overlay.add_child(_fallback_label)
	_fallback_label.text = FALLBACK_VISUAL_TEXT
	_fallback_label.visible = true


func _hide_fallback_visual() -> void:
	if _fallback_label != null:
		_fallback_label.visible = false


## ActionBar.disabled = true (docs/03_INTERACTION_CONTRACTS.md:126) means
## every button in the bar rejects input; composition (which buttons exist)
## is never touched here — only each Button's own `disabled` flag flips, so
## no button disappears-then-reappears.
##
## When `_action_bar` is a real ActionBarView (PANEL_ACTION_BAR), this
## delegates to its own set_blocking_disabled(), which is guaranteed to
## disable its nested buttons without touching composition (see that
## component's docstring for why: an empty-panel flash mid-animation is
## exactly what specs/003 warns against). Any other Control (e.g. the flat
## HBoxContainer-of-buttons used by earlier tests) falls back to a recursive
## descendant search, since a plain Control has no dedicated API for this.
func _set_action_bar_disabled(disabled: bool) -> void:
	if _action_bar == null:
		return
	if _action_bar is ActionBarView:
		(_action_bar as ActionBarView).set_blocking_disabled(disabled)
		return
	for button in _find_buttons_recursive(_action_bar):
		button.disabled = disabled


## docs/03_INTERACTION_CONTRACTS.md:132-136: RoundController decides the next
## legal actions; ActionBar only reflects that result. This is the only place
## PresentationController reads game state to drive UI, and it always reads
## it fresh from RoundController.legal_actions() rather than caching or
## guessing a transition.
##
## MUST NOT be called while a presentation is active: RoundController.legal_actions()
## returns [] during blocking, and feeding that into an ActionBarView would
## wrongly clear its buttons to zero mid-animation (see _set_action_bar_disabled
## above for why that composition change is reserved for completion only).
## This is only ever called from _complete(), i.e. after a presentation has
## just ended.
func _sync_action_bar_with_legal_actions() -> void:
	if _action_bar == null or _controller == null:
		return
	var legal := _controller.legal_actions()
	if _action_bar is ActionBarView:
		(_action_bar as ActionBarView).sync_with_legal_actions(legal)
		return
	for child in _find_buttons_recursive(_action_bar):
		if child is ActionButtonView:
			var button := child as ActionButtonView
			var action_id: StringName = _ACTION_ID_BY_BUTTON_ACTION.get(button.action, &"")
			button.disabled = not legal.has(action_id)


func _find_buttons_recursive(node: Node) -> Array[BaseButton]:
	var result: Array[BaseButton] = []
	for child in node.get_children():
		if child is BaseButton:
			result.append(child)
		result.append_array(_find_buttons_recursive(child))
	return result
