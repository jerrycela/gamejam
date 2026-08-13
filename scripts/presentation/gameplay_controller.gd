class_name GameplayController
extends Node
## Wires real player input (button presses) to RoundController actions and
## refreshes every L1 display node from the core's own authoritative state
## after each action. This is the piece that was entirely missing before
## this task — zero buttons anywhere in the codebase had a `pressed`
## connection, so clicking anything did nothing.
##
## Every blocking action goes through PresentationController's real
## begin_deal_presentation()/begin_dealer_hole_reveal_presentation() entry
## points, never a direct RoundController.deal()/dealer_step() bypass —
## docs/03_INTERACTION_CONTRACTS.md's input barrier (L2-1~L2-3) only means
## something if the real entry points are used. Subsequent dealer hits
## (after the hole card reveal) ARE direct dealer_step() calls, matching
## specs/003's own registered-events scope (only the deal and the hole
## reveal are blocking; further dealer hits are not).
##
## Betting is minimal-viable by design (team-lead's explicit ruling): DEAL
## always commits BetLedger's own MINIMUM_BET. There is no bet amount
## picker UI — BetControl stays a read-only Label reflecting whatever the
## ledger actually holds, never computed independently here (this class
## never runs Blackjack rules itself, only reads what scripts/core/ already
## decided: RoundController.snapshot()/events()/current_state and the
## BetLedger reference it was constructed with).
##
## Dealer hand rendering deliberately does NOT use RoundController.snapshot()
## for anything beyond the upcard and the hidden-count — snapshot()
## hardcodes "only the first dealer card is ever visible" regardless of
## reveal state (see scripts/core/round_controller.gd's own snapshot()); the
## authoritative "what has actually been revealed so far" source is the
## event stream (events() with hand_owner == DEALER and a non-null card),
## scoped to the current round_id since _events accumulates across the
## controller's entire lifetime and is never cleared between rounds.

const CARD_SCENE: PackedScene = preload("res://ui/components/card_view.tscn")

## L2 item 1 (逐張發牌): the four initial cards no longer snap onto the
## table as a single instant render — each one fades and scales in,
## staggered, so dealing reads as a sequence of four small events instead
## of one flat state change. This is purely a visual entrance played on
## top of state RoundController already committed synchronously inside
## deal() (docs/03_INTERACTION_CONTRACTS.md:136 — this never decides
## anything, it only plays after the fact); the FINAL card identities/
## face-down flags rendered here are read from RoundController.events(),
## the same authoritative source _known_dealer_cards() already trusted.
##
## Worst case timing (last of 4 cards): 3 × DEAL_CARD_ANIMATION_STAGGER_MS
## + DEAL_CARD_ANIMATION_TWEEN_MS = 450 + 180 = 630ms — comfortably inside
## PresentationController.DEAL_CARD_PRESENTATION_DWELL_MS (700ms), which
## exists purely as this animation's own safety net (see that constant's
## docstring). Named/colocated per docs/13 §2.1 (no scattered magic
## numbers) — mirror pair below (_deal_card_stagger_ms/_deal_card_tween_ms)
## exists only for override_deal_card_animation_timing_for_test(), the same
## pattern PresentationController uses for override_fallback_ms_for_test().
const DEAL_CARD_ANIMATION_STAGGER_MS: int = 150
const DEAL_CARD_ANIMATION_TWEEN_MS: int = 180
const DEAL_CARD_ANIMATION_ENTRANCE_SCALE: float = 0.55

const _RANK_STRINGS := {
	Card.Rank.ACE: "A",
	Card.Rank.JACK: "J",
	Card.Rank.QUEEN: "Q",
	Card.Rank.KING: "K",
}

const _SUIT_MAP := {
	Card.Suit.CLUBS: CardFaceView.Suit.CLUB,
	Card.Suit.DIAMONDS: CardFaceView.Suit.DIAMOND,
	Card.Suit.HEARTS: CardFaceView.Suit.HEART,
	Card.Suit.SPADES: CardFaceView.Suit.SPADE,
}

## Deliberately plain/generic — no technical detail, matching the same
## "log has the detail, screen never does" boundary PresentationController's
## fallback visual already established.
const _OUTCOME_LABELS := {
	BlackjackOutcome.Type.PLAYER_BLACKJACK: "黑傑克！你贏了",
	BlackjackOutcome.Type.DEALER_BLACKJACK: "莊家黑傑克",
	BlackjackOutcome.Type.PLAYER_WIN: "你贏了",
	BlackjackOutcome.Type.DEALER_WIN: "莊家贏了",
	BlackjackOutcome.Type.PLAYER_BUST: "爆牌，你輸了",
	BlackjackOutcome.Type.DEALER_BUST: "莊家爆牌，你贏了",
	BlackjackOutcome.Type.PUSH: "平手",
	BlackjackOutcome.Type.PLAYER_SURRENDER: "已投降",
}

## The 6 L2 dealer reaction assets (docs/06 §14 / Figma-registered) mapped
## from all 8 BlackjackOutcome.Type values — verified against the actual
## enum (scripts/core/blackjack_outcome.gd), not assumed. Two outcome pairs
## share one asset: DEALER_BLACKJACK and DEALER_WIN both read as "the
## player lost, no special fanfare" from the dealer's own reaction (only
## PLAYER_BLACKJACK gets the dedicated BLACKJACK asset); PLAYER_WIN and
## DEALER_BUST both read as "the player won" from the dealer's reaction
## (the asset shows the dealer's face, not who specifically caused the
## outcome).
const _REACTION_TEXTURES := {
	BlackjackOutcome.Type.PLAYER_BLACKJACK: preload("res://assets/textures/L2_DEALER_REACT_BLACKJACK_V001.png"),
	BlackjackOutcome.Type.DEALER_BLACKJACK: preload("res://assets/textures/L2_DEALER_REACT_PLAYER_LOSE_V001.png"),
	BlackjackOutcome.Type.PLAYER_WIN: preload("res://assets/textures/L2_DEALER_REACT_PLAYER_WIN_V001.png"),
	BlackjackOutcome.Type.DEALER_WIN: preload("res://assets/textures/L2_DEALER_REACT_PLAYER_LOSE_V001.png"),
	BlackjackOutcome.Type.PLAYER_BUST: preload("res://assets/textures/L2_DEALER_REACT_PLAYER_BUST_V001.png"),
	BlackjackOutcome.Type.DEALER_BUST: preload("res://assets/textures/L2_DEALER_REACT_PLAYER_WIN_V001.png"),
	BlackjackOutcome.Type.PUSH: preload("res://assets/textures/L2_DEALER_REACT_PUSH_V001.png"),
	BlackjackOutcome.Type.PLAYER_SURRENDER: preload("res://assets/textures/L2_DEALER_REACT_SURRENDER_V001.png"),
}

var _controller: RoundController = null
var _ledger: BetLedger = null
var _presentation: PresentationController = null
var _action_bar: ActionBarView = null
var _dealer_hand_view: Node = null
var _player_hand_view: Node = null
var _hand_total: ValueDisplayView = null
var _chips_label: Label = null
var _bet_label: Label = null
var _result_banner: Label = null
var _dealer_idle_view: DealerIdleView = null
var _dealer_reaction_view: DealerReactionView = null

# Overridable only through override_deal_card_animation_timing_for_test();
# production code must always read DEAL_CARD_ANIMATION_STAGGER_MS/
# DEAL_CARD_ANIMATION_TWEEN_MS.
var _deal_card_stagger_ms: int = DEAL_CARD_ANIMATION_STAGGER_MS
var _deal_card_tween_ms: int = DEAL_CARD_ANIMATION_TWEEN_MS


## `ledger` is the same BetLedger instance the caller constructed
## RoundController with — RoundController itself exposes no public
## accessor for it (by design: scripts/core/ never leaks its ledger
## reference), so the caller must pass the same object it already has
## rather than this class reaching into RoundController for one.
func setup(
	round_controller: RoundController,
	ledger: BetLedger,
	presentation_controller: PresentationController,
	action_bar: ActionBarView,
	dealer_hand_view: Node,
	player_hand_view: Node,
	hand_total: ValueDisplayView,
	chips_label: Label,
	bet_label: Label,
	result_banner: Label,
	dealer_idle_view: DealerIdleView = null,
	dealer_reaction_view: DealerReactionView = null,
) -> void:
	_controller = round_controller
	_ledger = ledger
	_presentation = presentation_controller
	_action_bar = action_bar
	_dealer_hand_view = dealer_hand_view
	_player_hand_view = player_hand_view
	_hand_total = hand_total
	_chips_label = chips_label
	_bet_label = bet_label
	_result_banner = result_banner
	_dealer_idle_view = dealer_idle_view
	_dealer_reaction_view = dealer_reaction_view

	if not _action_bar.action_requested.is_connected(_on_action_requested):
		_action_bar.action_requested.connect(_on_action_requested)
	if not _presentation.presentation_completed.is_connected(_on_presentation_completed):
		_presentation.presentation_completed.connect(_on_presentation_completed)
	if not _presentation.presentation_started.is_connected(_on_presentation_started):
		_presentation.presentation_started.connect(_on_presentation_started)

	refresh()
	_action_bar.sync_with_legal_actions(_controller.legal_actions())


## Re-renders every display node from current core state without changing
## anything — safe to call any time, including right after setup() so a
## freshly-booted scene shows real (empty) state instead of design-time
## scaffold values.
func refresh() -> void:
	_render_hands()
	_render_hand_total()
	_render_chips_and_bet()
	_render_result_banner()
	_render_dealer_reaction()


## The at-most-one-of-6 reaction texture for a given BlackjackOutcome.Type,
## or null for any other int — a pure lookup with no instance state, so it
## can be (and is, in tests/ui/test_l2_dealer_reaction.gd) called on a
## GameplayController that was never setup().
func reaction_texture_for_outcome(outcome: int) -> Texture2D:
	return _REACTION_TEXTURES.get(outcome, null)


## specs/003 L3-3: this NEVER calls stop()/pause() on DealerIdleView's
## AnimationPlayer — only hides its *rendering* (Control.visible), so the
## idle loop keeps running underneath and is_idle_loop_active() stays true
## the whole time (verified in
## tests/ui/test_l2_dealer_reaction.gd::test_idle_loop_keeps_playing_underneath_the_reaction_overlay_l3_3,
## which would fail if this ever changed to stop()/pause()).
func _render_dealer_reaction() -> void:
	if _dealer_reaction_view == null or _dealer_idle_view == null:
		return
	var show_reaction := (
		_controller.current_state == RoundController.State.ROUND_END
		and _controller.has_outcome()
	)
	if show_reaction:
		var reaction_texture := reaction_texture_for_outcome(_controller.outcome())
		if reaction_texture != null:
			_dealer_reaction_view.show_texture(reaction_texture)
			_dealer_idle_view.visible = false
			return
	_dealer_reaction_view.hide_reaction()
	_dealer_idle_view.visible = true


func _on_action_requested(action_id: StringName) -> void:
	match action_id:
		RoundController.ACTION_DEAL:
			_handle_deal()
		RoundController.ACTION_NEXT_ROUND:
			_handle_next_round()
		RoundController.ACTION_HIT:
			_controller.hit()
			_after_player_action()
		RoundController.ACTION_STAND:
			_controller.stand()
			_after_player_action()
		RoundController.ACTION_DOUBLE:
			_controller.double()
			_after_player_action()
		RoundController.ACTION_SURRENDER:
			_controller.surrender()
			_after_player_action()


## Fires the instant a blocking presentation opens (docs/03 §3's "P->>M:
## started" arrow) — this is where the entrance animation for DEAL_CARD
## actually starts, well before completion. DEALER_HOLE_REVEAL and any
## other kind are left alone here (out of this batch's scope).
func _on_presentation_started(kind: StringName, token: String) -> void:
	if kind == &"DEAL_CARD":
		_play_deal_card_animation(token)


## Renders the four initial cards face-up/face-down exactly as
## _render_hands() eventually would, but starting fully transparent and
## scaled down, then tweens each one in, staggered by _deal_card_stagger_ms
## per card in real deal order (docs/03 sequence: player, dealer upcard,
## player, dealer hole). The event stream (not snapshot()) is the source
## for the same secrecy reason _known_dealer_cards() already documents —
## event.card is null for the hole card, so this never has its real
## identity to leak even by accident.
##
## Interruption safety (specs/003's exactly-once guard / "動畫不可阻擋"):
## this does NOT own completion beyond starting it. Every card's Tween is
## created via view.create_tween(), which Godot auto-binds to and kills
## with that view — so if the fallback or dwell safety net completes the
## presentation first, _on_presentation_completed()'s refresh() call below
## clears and rebuilds both hand containers from scratch, freeing every
## in-flight card (and its tween, including the last card's finish
## callback) before it can do anything.
func _play_deal_card_animation(token: String) -> void:
	_clear_hand_view(_player_hand_view)
	_clear_hand_view(_dealer_hand_view)
	var entries := _initial_deal_events_in_order()
	for i in entries.size():
		var event: RoundEvent = entries[i]
		var face_down := event.card == null
		var view := _make_card_view(event.card, face_down)
		var parent := _player_hand_view if event.hand_owner == RoundEvent.HAND_PLAYER else _dealer_hand_view
		parent.add_child(view)
		view.modulate.a = 0.0
		view.scale = Vector2(DEAL_CARD_ANIMATION_ENTRANCE_SCALE, DEAL_CARD_ANIMATION_ENTRANCE_SCALE)

		var dur_sec := maxf(0.001, _deal_card_tween_ms / 1000.0)
		var tween := view.create_tween()
		tween.tween_interval(_deal_card_delay_sec(i))
		tween.set_parallel(true)
		tween.tween_property(view, "modulate:a", 1.0, dur_sec)
		tween.tween_property(view, "scale", Vector2.ONE, dur_sec).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		if i == entries.size() - 1:
			tween.chain().tween_callback(_finish_deal_card_animation.bind(token))


## The animation's own "M-->>P: finished" call — same public entry point a
## click-driven completion or a real future asset-backed animation would
## use. Guarded by active_token() match so a fallback/dwell timeout that
## already completed (and already froze this token) can never be answered
## twice; without freed-tween cancellation above this guard would still be
## needed on its own, so it stays as defense in depth.
func _finish_deal_card_animation(token: String) -> void:
	if _presentation.active_token() != token:
		return
	_presentation.notify_presentation_finished(token)


## Test seam: same idea as PresentationController's force_*_for_test()
## methods — lets a synchronous test finish the deal entrance animation
## without waiting on real Tween processing (GdUnit test bodies run
## synchronously; a Tween never advances until a frame is actually
## processed).
func force_deal_card_animation_finished_for_test() -> void:
	_finish_deal_card_animation(_presentation.active_token())


## Test seam: shortens the animation's own timing so a real Tween-driven
## test can finish quickly. Never used by production wiring — mirrors
## PresentationController.override_presentation_dwell_ms_for_test().
func override_deal_card_animation_timing_for_test(stagger_ms: int, tween_ms: int) -> void:
	_deal_card_stagger_ms = stagger_ms
	_deal_card_tween_ms = tween_ms


## Deliberately deterministic and wall-clock-free: this is the exact math
## _play_deal_card_animation() feeds into tween_interval() for card index
## `i` — asserting on this directly (tests/ui/test_gameplay_controller.gd's
## ordering test) proves "card N starts strictly after card N-1" without
## racing a real Tween against a fragile, headless-CI-sensitive partial
## wall-clock wait (a real such wait for this exact scenario was tried and
## was flaky under headless frame-delta jitter — see git history of this
## file). The one genuine real-Tween, real-wall-clock proof this codebase
## relies on is test_deal_card_animation_completes_the_presentation_via_a_real_tween,
## which only asserts the *final* state, not a mid-flight snapshot.
func _deal_card_delay_sec(index: int) -> float:
	return (index * _deal_card_stagger_ms) / 1000.0


## Test-facing wrapper for _deal_card_delay_sec(), in milliseconds (tests
## read constants in ms elsewhere, e.g. override_deal_card_animation_timing_for_test()).
func deal_card_delay_ms_for_test(index: int) -> int:
	return roundi(_deal_card_delay_sec(index) * 1000.0)


## The four RoundEvent.INITIAL_CARD_DEALT events for the current round, in
## real deal order (player, dealer upcard, player, dealer hole) — the array
## is already append-ordered by scripts/core/round_controller.gd's deal(),
## so no separate sort is needed. round_id-scoped for the same reason
## _known_dealer_cards() is: _events accumulates for the controller's whole
## lifetime and is never cleared between rounds.
func _initial_deal_events_in_order() -> Array[RoundEvent]:
	var result: Array[RoundEvent] = []
	var metadata := _controller.round_metadata()
	var round_id := metadata.round_id if metadata != null else ""
	if round_id.is_empty():
		return result
	for event in _controller.events():
		if event.round_id == round_id and event.event_id == RoundEvent.INITIAL_CARD_DEALT:
			result.append(event)
	return result


## Minimal-viable betting (team-lead's ruling): commit MINIMUM_BET and go
## straight to the real deal presentation. place_bet() only sets the
## ledger's selected_bet; deal() is what actually commits it, and that
## happens inside begin_deal_presentation() itself.
func _handle_deal() -> void:
	_controller.place_bet(BetLedger.MINIMUM_BET)
	_presentation.begin_deal_presentation(_new_round_id())


func _handle_next_round() -> void:
	_controller.next_round(_new_shoe_id(), _new_shuffle_seed())
	refresh()
	_action_bar.sync_with_legal_actions(_controller.legal_actions())


## Shared tail for every non-presented player action (HIT/STAND/DOUBLE/
## SURRENDER — none of these are registered blocking events, specs/003 Out
## of Scope). Syncs the bar to whatever's now legal FIRST (which may
## already be empty, e.g. DEALER_TURN has no player actions), then — only
## if the action just entered DEALER_TURN — starts the real hole-reveal
## presentation, which disables that (already correct) button set in place.
func _after_player_action() -> void:
	refresh()
	_action_bar.sync_with_legal_actions(_controller.legal_actions())
	if _controller.current_state == RoundController.State.DEALER_TURN:
		_presentation.begin_dealer_hole_reveal_presentation()


## Fires for both registered blocking events (kind distinguishes them).
## DEAL_CARD: PresentationController's own _complete() already resynced the
## action bar to the post-deal legal_actions() — nothing else to do here
## beyond re-rendering the now-real hands/total/chips/banner.
## DEALER_HOLE_REVEAL: after the hole card itself is shown, the dealer may
## still need to hit repeatedly (house rules, "< 17 hits") — those
## subsequent hits are direct dealer_step() calls per specs/003's scope, so
## this loop drives them to completion and then re-syncs the bar itself
## (PresentationController's own resync from a moment ago is now stale).
func _on_presentation_completed(kind: StringName, _token: String, _via_fallback: bool) -> void:
	refresh()
	if kind != &"DEALER_HOLE_REVEAL":
		return
	while _controller.current_state == RoundController.State.DEALER_TURN:
		if not _controller.dealer_step():
			break
	refresh()
	_action_bar.sync_with_legal_actions(_controller.legal_actions())


func _render_hands() -> void:
	var snapshot := _controller.snapshot()
	_render_player_hand(snapshot.player_cards)
	_render_dealer_hand(snapshot)


func _render_player_hand(cards: Array[Card]) -> void:
	_clear_hand_view(_player_hand_view)
	for card in cards:
		_player_hand_view.add_child(_make_card_view(card, false))


func _render_dealer_hand(snapshot: RoundSnapshot) -> void:
	_clear_hand_view(_dealer_hand_view)
	var known_cards := _known_dealer_cards(snapshot.round_id)
	for card in known_cards:
		_dealer_hand_view.add_child(_make_card_view(card, false))
	# snapshot.dealer_visible_cards.size() is 0 (not "always 1") whenever no
	# round is active yet (BETTING, freshly booted or just after
	# NEXT_ROUND) — assuming "at least the upcard" here was the actual bug
	# this comment now documents: it double-counted an upcard that doesn't
	# exist yet, leaving one stray face-down placeholder rendered at rest.
	var total_dealer_cards := snapshot.dealer_visible_cards.size() + snapshot.dealer_hidden_card_count
	var hidden_remaining := maxi(total_dealer_cards - known_cards.size(), 0)
	for _i in hidden_remaining:
		_dealer_hand_view.add_child(_make_card_view(null, true))


## The event stream is the only source that actually reflects what has been
## revealed so far — see class doc for why snapshot() cannot be used for
## this. round_id scoping matters because _events is never cleared between
## rounds (scripts/core/round_controller.gd's _reset_round_state()).
func _known_dealer_cards(round_id: String) -> Array[Card]:
	var result: Array[Card] = []
	if round_id.is_empty():
		return result
	for event in _controller.events():
		if event.round_id == round_id and event.hand_owner == RoundEvent.HAND_DEALER and event.card != null:
			result.append(event.card)
	return result


func _clear_hand_view(container: Node) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.free()


## `card` is null exactly when `face_down` is true — a hidden dealer card's
## real identity is never available to this class in the first place
## (RoundController.snapshot()'s secrecy boundary), so there is nothing to
## accidentally leak here even by mistake.
func _make_card_view(card: Card, face_down: bool) -> CardFaceView:
	var view := CARD_SCENE.instantiate() as CardFaceView
	view.face_down = face_down
	if not face_down and card != null:
		view.suit = _SUIT_MAP.get(card.suit, CardFaceView.Suit.CLUB)
		view.rank = _RANK_STRINGS.get(card.rank, str(card.rank))
	return view


func _render_hand_total() -> void:
	if _hand_total == null:
		return
	var snapshot := _controller.snapshot()
	var evaluation := HandEvaluator.evaluate(snapshot.player_cards)
	_hand_total.set_from_hand_evaluation(evaluation)


func _render_chips_and_bet() -> void:
	if _chips_label == null or _bet_label == null or _ledger == null:
		return
	_chips_label.text = "籌碼：%d" % _ledger.available_chips
	var displayed_bet: int = (
		_ledger.committed_bet if _ledger.committed_bet > 0 else _ledger.selected_bet
	)
	_bet_label.text = "下注：%d" % displayed_bet


func _render_result_banner() -> void:
	if _result_banner == null:
		return
	if _controller.current_state == RoundController.State.ROUND_END and _controller.has_outcome():
		_result_banner.text = _OUTCOME_LABELS.get(_controller.outcome(), "")
	else:
		_result_banner.text = ""


func _new_round_id() -> String:
	return "round-%d-%d" % [Time.get_ticks_usec(), randi()]


func _new_shoe_id() -> String:
	return "shoe-%d-%d" % [Time.get_unix_time_from_system(), Time.get_ticks_usec()]


func _new_shuffle_seed() -> int:
	return randi()
