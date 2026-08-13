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

## L2 item 2 (翻底牌): total flip duration (split into two equal halves —
## see _play_dealer_hole_reveal_animation()). Kept comfortably under
## PresentationController.DEALER_HOLE_REVEAL_PRESENTATION_DWELL_MS (300ms),
## that constant's own safety net.
const DEALER_HOLE_REVEAL_ANIMATION_TWEEN_MS: int = 240

## L2 item 3 (點數跳動): within team-lead's requested 150-250ms range. Not
## gated by any PresentationController dwell/fallback — HandTotal updates
## happen on non-blocking actions (HIT/STAND/etc, specs/003 Out of Scope for
## blocking) as well as blocking ones, so this only has to stay readable,
## not race a presentation timer.
const VALUE_TOTAL_TICK_MS: int = 200

## Bust gets extra emphasis on top of the tick (team-lead: "短暫放大回彈"):
## a brief scale bounce on the whole ValueDisplayView, played once the
## ticking number lands on its final (bust) total.
const VALUE_TOTAL_BUST_EMPHASIS_MS: int = 220
const VALUE_TOTAL_BUST_EMPHASIS_SCALE: float = 1.2

## L2 item 4a (籌碼變化 — numeric roll half only, see this file's batch
## report for the color-flash half's blocker): same 150-250ms family as the
## hand total tick.
const CHIPS_TICK_MS: int = 200

## L2 item 5 (結果橫幅進場): fade+scale entrance for the result banner
## instead of it simply always being there. PLAYER_BLACKJACK gets a
## stronger (bigger, springier) entrance — team-lead's spec also asked for
## `result/blackjack` gold, but that token doesn't exist in
## ui/theme/lsbj_theme.tres yet either (same real gap as item 4's
## result/win/lose — flagged in this batch's report), so only the motion
## half of "更強的進場" ships this batch.
const RESULT_BANNER_FADE_MS: int = 220
const RESULT_BANNER_BLACKJACK_BOUNCE_MS: int = 280
const RESULT_BANNER_BLACKJACK_SCALE: float = 1.15

## L2 item 6 (荷官反應轉場): fade-in only (team-lead's spec: "貼圖切換時淡入
## ，不要硬切") — never stop()/pause() DealerIdleView's own AnimationPlayer
## (specs/003 L3-3/L3-4), so this only ever touches modulate/visible on
## both views, exactly like the pre-existing hide/show it replaces.
const DEALER_REACTION_FADE_MS: int = 220

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

# Overridable only through override_dealer_hole_reveal_animation_timing_for_test();
# production code must always read DEALER_HOLE_REVEAL_ANIMATION_TWEEN_MS.
var _dealer_hole_reveal_tween_ms: int = DEALER_HOLE_REVEAL_ANIMATION_TWEEN_MS

# Overridable only through override_value_total_animation_timing_for_test();
# production code must always read VALUE_TOTAL_TICK_MS/VALUE_TOTAL_BUST_EMPHASIS_MS.
var _value_total_tick_ms: int = VALUE_TOTAL_TICK_MS
var _value_total_bust_emphasis_ms: int = VALUE_TOTAL_BUST_EMPHASIS_MS

# -1 is "never rendered yet" (a real total is always >= 0) — refresh() runs
# right inside setup() itself (see that function), so the very first render
# must snap straight to the real value instead of ticking up from a bogus 0.
var _last_rendered_hand_total: int = -1

# Test-facing only (hand_total_bust_emphasis_played_for_test()): proves the
# extra bust emphasis actually ran, since a real Tween's mid-flight scale
# can't be asserted on reliably (see the deal-card animation's own ordering
# test for why a wall-clock partial snapshot was abandoned in this codebase).
var _bust_emphasis_played: bool = false

# Whether the most recently *requested* hand total render was a bust — set
# unconditionally every _animate_hand_total_to() call, independent of
# whether a tick tween actually ran. force_value_and_chips_ticks_finished_for_test()
# consults this to know whether it still owes a bust emphasis play when it
# kills an in-flight tick before that tick's own completion callback would
# have played it.
var _pending_bust_total_evaluation_is_bust: bool = false

# Overridable only through override_chips_animation_timing_for_test().
var _chips_tick_ms: int = CHIPS_TICK_MS

# -1 sentinel, same reasoning as _last_rendered_hand_total.
var _last_rendered_chips: int = -1

# Overridable only through override_result_banner_animation_timing_for_test().
var _result_banner_fade_ms: int = RESULT_BANNER_FADE_MS
var _result_banner_blackjack_bounce_ms: int = RESULT_BANNER_BLACKJACK_BOUNCE_MS

# "" sentinel doubles as "no banner shown" (ResultBanner's own empty text) —
# no separate not-yet-rendered flag needed, unlike the -1 int sentinels
# above, since "" is never a real banner message.
var _last_rendered_result_banner_text: String = ""
var _result_banner_tween: Tween = null

# Overridable only through override_dealer_reaction_fade_timing_for_test().
var _dealer_reaction_fade_ms: int = DEALER_REACTION_FADE_MS
var _dealer_reaction_tween: Tween = null

# Only one tick of each kind should ever be running at once — refresh() can
# fire again (e.g. two actions in quick succession) before a prior tick
# finishes; without killing the stale Tween first, two Tweens would race to
# write the same Label's text every frame.
var _hand_total_tick_tween: Tween = null
var _chips_tick_tween: Tween = null


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
			_show_dealer_reaction_with_fade(reaction_texture)
			return
	_dealer_reaction_view.hide_reaction()
	_dealer_reaction_view.modulate.a = 1.0
	_dealer_idle_view.visible = true
	_dealer_idle_view.modulate.a = 1.0


## L2 item 6: visible/hidden booleans flip exactly as immediately as the
## pre-animation code did (docs/03-style tests assert these synchronously
## right after driving a round to ROUND_END, with no `await` — deferring
## either flag to a Tween's completion would reintroduce the exact
## flakiness this file's batch report already documented and fixed for
## HandTotal/chips). Only the reaction image's own opacity fades — the
## crossfade is "the dealer's face fades in on top", not "the idle view
## visibly lingers while fading out".
func _show_dealer_reaction_with_fade(texture: Texture2D) -> void:
	var already_showing := _dealer_reaction_view.visible
	_dealer_reaction_view.texture = texture
	_dealer_reaction_view.visible = true
	_dealer_idle_view.visible = false
	# ROUND_END can refresh() more than once (e.g. GameplayController's own
	# dealer-hit loop after the hole reveal) without the outcome changing —
	# don't replay the fade for a no-op re-render.
	if already_showing:
		return
	_dealer_reaction_view.modulate.a = 0.0
	if _dealer_reaction_tween != null and _dealer_reaction_tween.is_valid():
		_dealer_reaction_tween.kill()
	var dur_sec := maxf(0.001, _dealer_reaction_fade_ms / 1000.0)
	var tween := _dealer_reaction_view.create_tween()
	_dealer_reaction_tween = tween
	tween.tween_property(_dealer_reaction_view, "modulate:a", 1.0, dur_sec)


## Test seam: shortens the crossfade's own timing so a real Tween-driven
## test can finish quickly. Never used by production wiring.
func override_dealer_reaction_fade_timing_for_test(fade_ms: int) -> void:
	_dealer_reaction_fade_ms = fade_ms


## Test seam: mirrors force_value_and_chips_ticks_finished_for_test() — lets
## a test assert the fully-faded-in end state deterministically.
func force_dealer_reaction_fade_finished_for_test() -> void:
	if _dealer_reaction_tween != null and _dealer_reaction_tween.is_valid():
		_dealer_reaction_tween.kill()
	if _dealer_reaction_view != null:
		_dealer_reaction_view.modulate.a = 1.0


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
## started" arrow) — this is where both entrance animations (DEAL_CARD's
## stagger, DEALER_HOLE_REVEAL's flip) actually start, well before
## completion.
func _on_presentation_started(kind: StringName, token: String) -> void:
	if kind == &"DEAL_CARD":
		_play_deal_card_animation(token)
	elif kind == &"DEALER_HOLE_REVEAL":
		_play_dealer_hole_reveal_animation(token)


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


## L2 item 2 (翻底牌): begin_dealer_hole_reveal_presentation() has already
## called RoundController.dealer_step() by the time this fires (it's what
## makes DEALER_HOLE_REVEAL start in the first place) — the core's hole
## card is already really revealed in RoundController.events(), this is
## purely the catch-up visual. The existing face-down CardFaceView already
## sitting in _dealer_hand_view (placed there by the last refresh(), which
## _after_player_action() always runs *before* opening this presentation —
## see that function) is animated in place rather than replaced: scale.x
## tweens to 0 (card reads as edge-on, like a real flip), the face/rank/suit
## flip to their real values at that exact midpoint, then scale.x tweens
## back to 1. scale.y is never touched, so the card never actually shrinks,
## only appears to rotate.
##
## Worst case timing: DEALER_HOLE_REVEAL_ANIMATION_TWEEN_MS (240ms, split
## into two 120ms halves) is comfortably inside
## PresentationController.DEALER_HOLE_REVEAL_PRESENTATION_DWELL_MS (300ms),
## the safety net behind this animation the same way DEAL_CARD_PRESENTATION_DWELL_MS
## is behind _play_deal_card_animation().
##
## Interruption safety: identical reasoning to _play_deal_card_animation() —
## the Tween is bound to the hole card's own view via view.create_tween();
## if the fallback/dwell safety net wins the race instead,
## _on_presentation_completed()'s refresh() rebuilds _dealer_hand_view from
## scratch (fully revealed, no animation), freeing this view and its Tween
## (including the finish callback) before either can act again.
func _play_dealer_hole_reveal_animation(token: String) -> void:
	var hole_view := _find_dealer_hole_card_view()
	# No card shaped the way this animation expects (e.g. this
	# GameplayController's own hand views are wired to a different
	# RoundController instance than the one PresentationController is
	# actually driving — tests/ui/test_l1_6_action_bar_legal_actions.gd
	# exercises exactly this by re-setup()'ing PresentationController alone
	# after GameBootstrap's own auto-wiring already ran). Deliberately NOT
	# auto-completing here: this handler starting is not the same guarantee
	# as a real animation being able to play, and immediately finishing
	# would let a broken/mismatched driver silently swallow the blocking
	# presentation before its own real caller (test or otherwise) gets to
	# call notify_presentation_finished()/observe the block. Doing nothing
	# leaves DEALER_HOLE_REVEAL_PRESENTATION_DWELL_MS / the fallback timer to
	# complete it exactly as they would have before this animation existed.
	if hole_view == null:
		return
	var revealed_card := _revealed_dealer_hole_card()
	var half_dur := maxf(0.001, (_dealer_hole_reveal_tween_ms / 2.0) / 1000.0)
	var tween := hole_view.create_tween()
	tween.tween_property(hole_view, "scale:x", 0.0, half_dur)
	tween.tween_callback(_reveal_hole_card_face.bind(hole_view, revealed_card))
	tween.tween_property(hole_view, "scale:x", 1.0, half_dur)
	tween.tween_callback(_finish_dealer_hole_reveal_animation.bind(token))


## The flip's midpoint: scale.x has just reached 0 (card reads as edge-on),
## this is the moment the face actually swaps from the hidden placeholder
## to the real revealed identity — a named method (not an inline lambda)
## specifically so tests/ui/test_gameplay_controller.gd can drive and assert
## this exact moment via force_dealer_hole_reveal_animation_midpoint_for_test(),
## independent of whether the presentation has fully completed yet (which
## would otherwise immediately rebuild/overwrite this view via refresh()).
func _reveal_hole_card_face(hole_view: CardFaceView, card: Card) -> void:
	hole_view.face_down = false
	if card != null:
		hole_view.suit = _SUIT_MAP.get(card.suit, CardFaceView.Suit.CLUB)
		hole_view.rank = _RANK_STRINGS.get(card.rank, str(card.rank))


## Mirrors _finish_deal_card_animation()'s guard/reasoning exactly.
func _finish_dealer_hole_reveal_animation(token: String) -> void:
	if _presentation.active_token() != token:
		return
	_presentation.notify_presentation_finished(token)


## Test seam: mirrors force_deal_card_animation_finished_for_test().
func force_dealer_hole_reveal_animation_finished_for_test() -> void:
	_finish_dealer_hole_reveal_animation(_presentation.active_token())


## Test seam: drives just the flip's midpoint face-swap (see
## _reveal_hole_card_face()) without completing the presentation — lets a
## test observe the real-card-face-mid-flip state deterministically instead
## of racing a real Tween. No-op (matching _play_dealer_hole_reveal_animation's
## own defensive path) if there's no face-down card shaped the way this
## animation expects.
func force_dealer_hole_reveal_animation_midpoint_for_test() -> void:
	var hole_view := _find_dealer_hole_card_view()
	if hole_view == null:
		return
	_reveal_hole_card_face(hole_view, _revealed_dealer_hole_card())


## Test seam: shortens the flip's own timing so a real Tween-driven test
## can finish quickly. Never used by production wiring — mirrors
## override_deal_card_animation_timing_for_test().
func override_dealer_hole_reveal_animation_timing_for_test(tween_ms: int) -> void:
	_dealer_hole_reveal_tween_ms = tween_ms


## The dealer's hand's last child, if it's still showing face-down — the
## card this batch's flip is meant to animate. Null (defensive no-op path
## in _play_dealer_hole_reveal_animation()) if the hand doesn't look like
## the shape this animation expects, e.g. no dealer hand rendered at all.
func _find_dealer_hole_card_view() -> CardFaceView:
	if _dealer_hand_view == null or _dealer_hand_view.get_child_count() == 0:
		return null
	var last_child := _dealer_hand_view.get_child(_dealer_hand_view.get_child_count() - 1)
	if last_child is CardFaceView and (last_child as CardFaceView).face_down:
		return last_child as CardFaceView
	return null


## The real hole card identity, read the same authoritative way
## _known_dealer_cards() and _initial_deal_events_in_order() already do —
## RoundEvent.DEALER_HOLE_CARD_REVEALED always carries the real card once
## dealer_step() has actually revealed it (scripts/core/round_controller.gd),
## scoped to the current round_id for the same _events-never-clears reason
## documented elsewhere in this file.
func _revealed_dealer_hole_card() -> Card:
	var metadata := _controller.round_metadata()
	var round_id := metadata.round_id if metadata != null else ""
	if round_id.is_empty():
		return null
	for event in _controller.events():
		if event.round_id == round_id and event.event_id == RoundEvent.DEALER_HOLE_CARD_REVEALED:
			return event.card
	return null


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


## L2 item 3 (點數跳動): still never computes anything itself —
## HandEvaluator.evaluate() is the exact same call _render_hand_total()
## already made; only how the *result* reaches the screen changed (ticking
## instead of an instant text swap).
func _render_hand_total() -> void:
	if _hand_total == null:
		return
	var snapshot := _controller.snapshot()
	var evaluation := HandEvaluator.evaluate(snapshot.player_cards)
	_animate_hand_total_to(evaluation)


## Sets ValueDisplayView's state/color immediately (Hard/Soft/Bust reads as
## an instant category change, not something that "ticks") and only
## animates the number label: a Tween drives an intermediate float from the
## previously-rendered total to the new one, rounding it into the value
## Label's text each step. First-ever render (before/immediately after
## setup(), or whenever nothing actually changed — refresh() can be called
## repeatedly with the same total) always snaps instead of playing a
## pointless 0-length tick.
func _animate_hand_total_to(evaluation: HandEvaluator.Evaluation) -> void:
	_hand_total.state = _value_display_state_for(evaluation)
	var target_total := evaluation.total
	var previous_total := _last_rendered_hand_total
	_last_rendered_hand_total = target_total
	_bust_emphasis_played = false
	_pending_bust_total_evaluation_is_bust = evaluation.is_bust
	if previous_total == -1 or previous_total == target_total:
		_hand_total.value = str(target_total)
		# No tick plays here (nothing to animate), so nothing else will ever
		# call _play_bust_emphasis() for this evaluation — play it now.
		if evaluation.is_bust:
			_play_bust_emphasis()
		return
	var label := _hand_total.get_value_label()
	var dur_sec := maxf(0.001, _value_total_tick_ms / 1000.0)
	if _hand_total_tick_tween != null and _hand_total_tick_tween.is_valid():
		_hand_total_tick_tween.kill()
	var tween := _hand_total.create_tween()
	_hand_total_tick_tween = tween
	tween.tween_method(
		_set_value_total_label_text.bind(label), float(previous_total), float(target_total), dur_sec
	)
	tween.tween_callback(func() -> void:
		_hand_total.value = str(target_total)
		if evaluation.is_bust:
			_play_bust_emphasis()
	)


func _set_value_total_label_text(current: float, label: Label) -> void:
	label.text = str(roundi(current))


func _value_display_state_for(evaluation: HandEvaluator.Evaluation) -> int:
	if evaluation.is_bust:
		return ValueDisplayView.State.BUST
	if evaluation.is_soft:
		return ValueDisplayView.State.SOFT
	return ValueDisplayView.State.HARD


## team-lead: "爆牌額外強調（短暫放大回彈...)" — plays once, right as the
## ticking number lands on the bust total. Bound to _hand_total's own Tween
## the same way every other animation in this file is bound to its target
## node, for the same automatic-cleanup reason.
func _play_bust_emphasis() -> void:
	_bust_emphasis_played = true
	var dur_sec := maxf(0.001, (_value_total_bust_emphasis_ms / 2.0) / 1000.0)
	var tween := _hand_total.create_tween()
	tween.tween_property(
		_hand_total, "scale", Vector2(VALUE_TOTAL_BUST_EMPHASIS_SCALE, VALUE_TOTAL_BUST_EMPHASIS_SCALE), dur_sec
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(_hand_total, "scale", Vector2.ONE, dur_sec)


## Test seam: shortens the tick/bust-emphasis timing so a real Tween-driven
## test can finish quickly. Never used by production wiring.
func override_value_total_animation_timing_for_test(tick_ms: int, bust_emphasis_ms: int) -> void:
	_value_total_tick_ms = tick_ms
	_value_total_bust_emphasis_ms = bust_emphasis_ms


## Test-facing: see _bust_emphasis_played's own doc comment.
func hand_total_bust_emphasis_played_for_test() -> bool:
	return _bust_emphasis_played


## L2 item 4a (籌碼變化 — numeric roll only; see this batch's report for why
## the win/lose color flash half is deferred, not silently dropped): chips
## tick from the previously-rendered value to the real ledger value the
## same way _animate_hand_total_to() ticks the hand total. BetControl stays
## an instant text swap (team-lead never asked for a bet-control animation,
## only "chip" changes, and BetControl is a distinct read-only field per
## this class's own setup() doc).
func _render_chips_and_bet() -> void:
	if _chips_label == null or _bet_label == null or _ledger == null:
		return
	_animate_chips_to(_ledger.available_chips)
	var displayed_bet: int = (
		_ledger.committed_bet if _ledger.committed_bet > 0 else _ledger.selected_bet
	)
	_bet_label.text = "下注：%d" % displayed_bet


func _animate_chips_to(target_chips: int) -> void:
	var previous_chips := _last_rendered_chips
	_last_rendered_chips = target_chips
	if previous_chips == -1 or previous_chips == target_chips:
		_chips_label.text = "籌碼：%d" % target_chips
		return
	var dur_sec := maxf(0.001, _chips_tick_ms / 1000.0)
	if _chips_tick_tween != null and _chips_tick_tween.is_valid():
		_chips_tick_tween.kill()
	var tween := _chips_label.create_tween()
	_chips_tick_tween = tween
	tween.tween_method(
		_set_chips_label_text, float(previous_chips), float(target_chips), dur_sec
	)


func _set_chips_label_text(current: float) -> void:
	_chips_label.text = "籌碼：%d" % roundi(current)


## Test seam: shortens the chips tick timing so a real Tween-driven test can
## finish quickly. Never used by production wiring.
func override_chips_animation_timing_for_test(tick_ms: int) -> void:
	_chips_tick_ms = tick_ms


## Test seam: this test harness's assertion helpers run outside any `await`
## (unlike the real-Tween end-to-end tests, which do `await
## get_tree().create_timer(...)`), yet observably some frames still process
## between statements here (gdUnit4/scene_runner button-press plumbing) —
## enough for a real Tween to have advanced partway, but not deterministically
## to any particular value. Any test that needs to assert the *exact* final
## HandTotal/chips text right after a synchronous action must call this
## first, the same way PresentationController's force_*_for_test() seams
## let a test skip past real-Timer nondeterminism. Kills whatever tick is
## still running and snaps both labels straight to the already-known target
## (_last_rendered_hand_total/_last_rendered_chips — set the instant
## _animate_hand_total_to()/_animate_chips_to() are called, before any
## tween exists).
func force_value_and_chips_ticks_finished_for_test() -> void:
	if _hand_total_tick_tween != null and _hand_total_tick_tween.is_valid():
		_hand_total_tick_tween.kill()
	if _chips_tick_tween != null and _chips_tick_tween.is_valid():
		_chips_tick_tween.kill()
	if _hand_total != null and _last_rendered_hand_total != -1:
		_hand_total.value = str(_last_rendered_hand_total)
		if _pending_bust_total_evaluation_is_bust and not _bust_emphasis_played:
			_play_bust_emphasis()
	if _chips_label != null and _last_rendered_chips != -1:
		_chips_label.text = "籌碼：%d" % _last_rendered_chips


## L2 item 5: `.text` is always set immediately/synchronously here, exactly
## as before — only opacity/scale are animated. Existing callers that
## assert result_banner.text right after an action (e.g.
## test_surrender_button_press_settles_the_round_immediately) keep working
## unmodified; only the *entrance* is new.
func _render_result_banner() -> void:
	if _result_banner == null:
		return
	var target_text := ""
	var outcome := -1
	if _controller.current_state == RoundController.State.ROUND_END and _controller.has_outcome():
		outcome = _controller.outcome()
		target_text = _OUTCOME_LABELS.get(outcome, "")
	_result_banner.text = target_text
	_animate_result_banner_entrance(target_text, outcome)


## Skips replaying the entrance for a no-op refresh() (ROUND_END can
## refresh() more than once without the outcome changing) or for the
## "banner cleared" case (team-lead only asked for an entrance, not an
## exit animation) — those just reset opacity/scale instantly so the next
## real entrance starts clean.
func _animate_result_banner_entrance(target_text: String, outcome: int) -> void:
	var already_shown := target_text == _last_rendered_result_banner_text
	_last_rendered_result_banner_text = target_text
	if target_text.is_empty():
		_result_banner.modulate.a = 0.0
		_result_banner.scale = Vector2.ONE
		return
	if already_shown:
		return
	var is_blackjack := outcome == BlackjackOutcome.Type.PLAYER_BLACKJACK
	_result_banner.modulate.a = 0.0
	_result_banner.scale = Vector2(0.4, 0.4) if is_blackjack else Vector2(0.92, 0.92)
	if _result_banner_tween != null and _result_banner_tween.is_valid():
		_result_banner_tween.kill()
	var fade_dur_sec := maxf(0.001, _result_banner_fade_ms / 1000.0)
	var tween := _result_banner.create_tween()
	_result_banner_tween = tween
	tween.set_parallel(true)
	tween.tween_property(_result_banner, "modulate:a", 1.0, fade_dur_sec)
	if is_blackjack:
		var bounce_dur_sec := maxf(0.001, _result_banner_blackjack_bounce_ms / 1000.0)
		tween.tween_property(
			_result_banner, "scale", Vector2(RESULT_BANNER_BLACKJACK_SCALE, RESULT_BANNER_BLACKJACK_SCALE), bounce_dur_sec
		).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.chain().tween_property(_result_banner, "scale", Vector2.ONE, bounce_dur_sec * 0.5)
	else:
		tween.tween_property(_result_banner, "scale", Vector2.ONE, fade_dur_sec)


## Test seam: shortens the entrance's own timing so a real Tween-driven
## test can finish quickly. Never used by production wiring.
func override_result_banner_animation_timing_for_test(fade_ms: int, blackjack_bounce_ms: int) -> void:
	_result_banner_fade_ms = fade_ms
	_result_banner_blackjack_bounce_ms = blackjack_bounce_ms


## Test seam: mirrors force_value_and_chips_ticks_finished_for_test().
func force_result_banner_entrance_finished_for_test() -> void:
	if _result_banner_tween != null and _result_banner_tween.is_valid():
		_result_banner_tween.kill()
	if _result_banner != null and not _last_rendered_result_banner_text.is_empty():
		_result_banner.modulate.a = 1.0
		_result_banner.scale = Vector2.ONE


func _new_round_id() -> String:
	return "round-%d-%d" % [Time.get_ticks_usec(), randi()]


func _new_shoe_id() -> String:
	return "shoe-%d-%d" % [Time.get_unix_time_from_system(), Time.get_ticks_usec()]


func _new_shuffle_seed() -> int:
	return randi()
