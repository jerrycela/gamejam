class_name TestL3DealerIdleAnimation
extends GdUnitTestSuite
## Covers specs/003 "L3 Behavior" #6, L3-3 and L3-4: the dealer idle loop
## (docs/06_AI_ART_AND_MEDIA_PROMPTS.md §11, revised 2026-08-13 to an
## engine-native animation instead of video — no generation backend has
## video capability, and Godot 4's native Ogg Theora codec cannot carry an
## independent transparent dealer layer).
##
## L3-3's judgment is the spec's own minimal criterion (specs/003:153): the
## L2 dealer-hole-reveal overlay must not change which loop is active —
## same loop flag / same idle animation name before and after, not a stricter
## progression-state check (no such states exist yet).


func _card(rank: int, suit: int) -> Card:
	return Card.new(rank, suit)


func _dealer_idle_view(root: Node) -> DealerIdleView:
	return root.get_node("L3Root/DealerIdleView") as DealerIdleView


func test_idle_loop_is_active_immediately_after_the_scene_loads() -> void:
	var runner := scene_runner("res://scenes/game_root.tscn")
	var root: Node = runner.scene()
	var dealer_idle := _dealer_idle_view(root)

	assert_object(dealer_idle).is_not_null()
	assert_bool(dealer_idle.is_idle_loop_active()).is_true()
	assert_that(dealer_idle.current_loop_animation()).is_equal(DealerIdleView.LOOP_ANIMATION_NAME)


func test_l3root_mouse_filter_regression_still_holds_with_the_animation_attached() -> void:
	# L3-2 (tests/ui/test_l3_root_mouse_filter.gd) must not regress: adding an
	# AnimationPlayer/script to DealerIdleView must not touch mouse_filter.
	var runner := scene_runner("res://scenes/game_root.tscn")
	var root: Node = runner.scene()
	var dealer_idle := _dealer_idle_view(root)

	assert_int(dealer_idle.mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)


func test_l3_3_loop_state_is_unchanged_across_a_dealer_hole_reveal_overlay() -> void:
	var runner := scene_runner("res://scenes/game_root.tscn")
	var root: Node = runner.scene()
	var round_controller_node := root.get_node("RoundController") as RoundControllerNode
	var presentation_controller := root.get_node("PresentationController") as PresentationController
	var table_ui := root.get_node("L1Root/TableUI") as Node
	var action_bar := table_ui.find_child("ActionBar", true, false) as ActionBarView
	var dealer_idle := _dealer_idle_view(root)

	var cards: Array[Card] = [
		_card(Card.Rank.EIGHT, Card.Suit.HEARTS),
		_card(Card.Rank.SEVEN, Card.Suit.SPADES),
		_card(Card.Rank.NINE, Card.Suit.CLUBS),
		_card(Card.Rank.SIX, Card.Suit.DIAMONDS),
		_card(Card.Rank.TWO, Card.Suit.HEARTS),
		_card(Card.Rank.KING, Card.Suit.SPADES),
	]
	var ledger := BetLedger.new()
	var shoe := DeckShoe.create_injected(cards, "shoe-l3-3")
	var controller := RoundController.create_injected(shoe, ledger)
	round_controller_node.setup(controller)
	presentation_controller.setup(controller, action_bar)

	assert_bool(controller.place_bet(100)).is_true()
	presentation_controller.begin_deal_presentation("round-l3-3")
	presentation_controller.notify_presentation_finished(presentation_controller.active_token())
	assert_bool(controller.hit()).is_true()
	assert_bool(controller.stand()).is_true()
	assert_int(controller.current_state).is_equal(RoundController.State.DEALER_TURN)

	var loop_active_before := dealer_idle.is_idle_loop_active()
	var loop_animation_before := dealer_idle.current_loop_animation()
	assert_bool(loop_active_before).is_true()

	# Dealer hole card reveal: the second registered L2 blocking event.
	var reveal_started := presentation_controller.begin_dealer_hole_reveal_presentation()
	assert_bool(reveal_started).is_true()

	# During the overlay: same loop flag / same idle animation (L3-3's
	# minimal judgment), not paused, not stuck, not swapped.
	assert_bool(dealer_idle.is_idle_loop_active()).is_equal(loop_active_before)
	assert_that(dealer_idle.current_loop_animation()).is_equal(loop_animation_before)

	presentation_controller.notify_presentation_finished(presentation_controller.active_token())

	# After the overlay ends: still the same loop flag / same idle animation.
	assert_bool(dealer_idle.is_idle_loop_active()).is_equal(loop_active_before)
	assert_that(dealer_idle.current_loop_animation()).is_equal(loop_animation_before)


func _assert_loop_uninterrupted(dealer_idle: DealerIdleView, expected_animation: StringName) -> void:
	assert_bool(dealer_idle.is_idle_loop_active()).is_true()
	assert_that(dealer_idle.current_loop_animation()).is_equal(expected_animation)


func test_l3_4_loop_survives_two_consecutive_full_rounds_uninterrupted() -> void:
	var runner := scene_runner("res://scenes/game_root.tscn")
	var root: Node = runner.scene()
	var round_controller_node := root.get_node("RoundController") as RoundControllerNode
	var presentation_controller := root.get_node("PresentationController") as PresentationController
	var table_ui := root.get_node("L1Root/TableUI") as Node
	var action_bar := table_ui.find_child("ActionBar", true, false) as ActionBarView
	var dealer_idle := _dealer_idle_view(root)

	var round_1_cards: Array[Card] = [
		_card(Card.Rank.EIGHT, Card.Suit.HEARTS),
		_card(Card.Rank.SEVEN, Card.Suit.SPADES),
		_card(Card.Rank.NINE, Card.Suit.CLUBS),
		_card(Card.Rank.SIX, Card.Suit.DIAMONDS),
		_card(Card.Rank.TWO, Card.Suit.HEARTS),
		_card(Card.Rank.KING, Card.Suit.SPADES),
	]
	var ledger := BetLedger.new()
	var shoe := DeckShoe.create_injected(round_1_cards, "shoe-l3-4-round-1")
	var controller := RoundController.create_injected(shoe, ledger)
	round_controller_node.setup(controller)
	presentation_controller.setup(controller, action_bar)

	# Assert at every meaningful checkpoint across round 1 that the loop
	# never needs a manual restart: same flag, same animation, every time.
	var expected_animation := dealer_idle.current_loop_animation()

	_assert_loop_uninterrupted(dealer_idle, expected_animation)
	assert_bool(controller.place_bet(100)).is_true()
	_assert_loop_uninterrupted(dealer_idle, expected_animation)
	presentation_controller.begin_deal_presentation("round-l3-4-r1")
	_assert_loop_uninterrupted(dealer_idle, expected_animation)
	presentation_controller.notify_presentation_finished(presentation_controller.active_token())
	_assert_loop_uninterrupted(dealer_idle, expected_animation)
	assert_bool(controller.hit()).is_true()
	_assert_loop_uninterrupted(dealer_idle, expected_animation)
	assert_bool(controller.stand()).is_true()
	_assert_loop_uninterrupted(dealer_idle, expected_animation)
	presentation_controller.begin_dealer_hole_reveal_presentation()
	_assert_loop_uninterrupted(dealer_idle, expected_animation)
	presentation_controller.notify_presentation_finished(presentation_controller.active_token())
	_assert_loop_uninterrupted(dealer_idle, expected_animation)
	assert_bool(controller.dealer_step()).is_true()
	assert_int(controller.current_state).is_equal(RoundController.State.ROUND_END)
	_assert_loop_uninterrupted(dealer_idle, expected_animation)

	# NEXT_ROUND -> back to BETTING, then a second full round. Round 2's
	# replacement shoe (RoundController.next_round with a shoe_id/seed) is a
	# real shuffled 52-card runtime shoe, not an injected deterministic
	# sequence (see RoundController.next_round: shoe_replacement_required
	# builds one via DeckShoe.create_runtime) — this test only cares that
	# the L3 loop survives whatever that round's actual outcome is, so it
	# drives the round generically instead of assuming round 1's exact
	# HIT/STAND/one-dealer-hit script.
	assert_bool(controller.next_round("shoe-l3-4-round-2", 99)).is_true()
	_assert_loop_uninterrupted(dealer_idle, expected_animation)

	assert_bool(controller.place_bet(100)).is_true()
	_assert_loop_uninterrupted(dealer_idle, expected_animation)
	presentation_controller.begin_deal_presentation("round-l3-4-r2")
	_assert_loop_uninterrupted(dealer_idle, expected_animation)
	presentation_controller.notify_presentation_finished(presentation_controller.active_token())
	_assert_loop_uninterrupted(dealer_idle, expected_animation)

	if controller.current_state == RoundController.State.PLAYER_TURN:
		assert_bool(controller.stand()).is_true()
		_assert_loop_uninterrupted(dealer_idle, expected_animation)

	if controller.current_state == RoundController.State.DEALER_TURN:
		var reveal_started_r2 := presentation_controller.begin_dealer_hole_reveal_presentation()
		assert_bool(reveal_started_r2).is_true()
		_assert_loop_uninterrupted(dealer_idle, expected_animation)
		presentation_controller.notify_presentation_finished(presentation_controller.active_token())
		_assert_loop_uninterrupted(dealer_idle, expected_animation)
		while controller.current_state == RoundController.State.DEALER_TURN:
			assert_bool(controller.dealer_step()).is_true()
			_assert_loop_uninterrupted(dealer_idle, expected_animation)

	assert_int(controller.current_state).is_equal(RoundController.State.ROUND_END)
	_assert_loop_uninterrupted(dealer_idle, expected_animation)
