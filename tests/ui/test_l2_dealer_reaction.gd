class_name TestL2DealerReaction
extends GdUnitTestSuite
## Covers the L2 dealer reaction gap the user found: 6 reaction assets
## (assets/textures/L2_DEALER_REACT_*_V001.png) existed in version control,
## registered in Figma and docs/06 §14, but nothing in code ever referenced
## them (verified: `grep -rn "L2_DEALER_REACT" scripts/ ui/ scenes/` was
## empty before this task) — DealerReactionLayer was a bare empty Control.
##
## Mapping is team-lead's own (8 BlackjackOutcome.Type values -> 6 assets,
## verified against the actual enum rather than assumed):
##   PLAYER_BLACKJACK              -> BLACKJACK
##   DEALER_BLACKJACK, DEALER_WIN  -> PLAYER_LOSE
##   PLAYER_WIN, DEALER_BUST       -> PLAYER_WIN
##   PLAYER_BUST                  -> PLAYER_BUST
##   PUSH                         -> PUSH
##   PLAYER_SURRENDER             -> SURRENDER
##
## Critical constraint (specs/003 L3-3): the reaction overlay must NEVER
## call AnimationPlayer.stop()/pause() on DealerIdleView's idle loop — only
## hide/show the *rendering* of DealerIdleView, keeping the loop itself
## running underneath, so is_idle_loop_active() stays true throughout and
## the existing 4 tests in test_l3_dealer_idle_animation.gd keep passing.


func _card(rank: int, suit: int) -> Card:
	return Card.new(rank, suit)


func _make_harness_scene() -> Dictionary:
	var runner := scene_runner("res://scenes/game_root.tscn")
	var root: Node = runner.scene()
	return {
		"runner": runner,
		"root": root,
		"bootstrap": root.get_node("Bootstrap") as GameBootstrap,
		"action_bar": root.get_node("L1Root/TableUI").find_child("ActionBar", true, false) as ActionBarView,
		"presentation": root.get_node("PresentationController") as PresentationController,
		"dealer_idle_view": root.get_node("L3Root/DealerIdleView") as DealerIdleView,
		"reaction_view": root.get_node("L2Root/DealerReactionLayer").find_child("ReactionImage", true, false) as DealerReactionView,
	}


## PLAYER_WIN via DEALER_BUST: same deterministic script as
## tests/ui/test_l1_6_action_bar_legal_actions.gd / test_gameplay_controller.gd.
func _play_to_dealer_bust(h: Dictionary) -> void:
	var bootstrap: GameBootstrap = h.bootstrap
	bootstrap.bootstrap("shoe-l2-reaction-win", 1)
	var shoe := DeckShoe.create_injected([
		_card(Card.Rank.EIGHT, Card.Suit.HEARTS),
		_card(Card.Rank.SEVEN, Card.Suit.SPADES),
		_card(Card.Rank.NINE, Card.Suit.CLUBS),
		_card(Card.Rank.SIX, Card.Suit.DIAMONDS),
		_card(Card.Rank.TWO, Card.Suit.HEARTS),
		_card(Card.Rank.KING, Card.Suit.SPADES),
	], "shoe-l2-reaction-win")
	var ledger := BetLedger.new()
	var controller := RoundController.create_injected(shoe, ledger)
	var round_controller_node := h.root.get_node("RoundController") as RoundControllerNode
	var gameplay := h.root.get_node("GameplayController") as GameplayController
	round_controller_node.setup(controller)
	gameplay.setup(
		controller, ledger, h.presentation, h.action_bar,
		h.root.get_node("L1Root/TableUI").find_child("DealerHandView", true, false),
		h.root.get_node("L1Root/TableUI").find_child("PlayerHandView", true, false),
		h.root.get_node("L1Root/TableUI").find_child("HandTotal", true, false),
		h.root.get_node("L1Root/TableUI").find_child("ChipsDisplay", true, false),
		h.root.get_node("L1Root/TableUI").find_child("BetControl", true, false),
		h.root.get_node("L1Root/TableUI").find_child("ResultBanner", true, false),
		h.dealer_idle_view,
		h.reaction_view,
	)
	h.presentation.setup(controller, h.action_bar, null)

	h.action_bar.deal_button().pressed.emit()
	h.presentation.notify_presentation_finished(h.presentation.active_token())
	var hit_button: ActionButtonView = null
	var stand_button: ActionButtonView = null
	for button in h.action_bar.buttons():
		if button.action == ActionButtonView.Action.HIT:
			hit_button = button
		if button.action == ActionButtonView.Action.STAND:
			stand_button = button
	hit_button.pressed.emit()
	stand_button.pressed.emit()
	h.presentation.notify_presentation_finished(h.presentation.active_token())
	h["controller"] = controller


func test_dealer_reaction_is_hidden_and_idle_view_visible_at_boot() -> void:
	var h := _make_harness_scene()

	assert_bool((h.reaction_view as DealerReactionView).visible).is_false()
	assert_bool((h.dealer_idle_view as DealerIdleView).visible).is_true()


func test_round_end_shows_the_reaction_matching_the_outcome_and_hides_idle_view() -> void:
	var h := _make_harness_scene()
	_play_to_dealer_bust(h)
	var controller: RoundController = h.controller

	assert_int(controller.current_state).is_equal(RoundController.State.ROUND_END)
	assert_int(controller.outcome()).is_equal(BlackjackOutcome.Type.DEALER_BUST)

	var reaction_view: DealerReactionView = h.reaction_view
	var dealer_idle_view: DealerIdleView = h.dealer_idle_view
	assert_bool(reaction_view.visible).is_true()
	assert_bool(dealer_idle_view.visible).is_false()
	assert_str(reaction_view.texture.resource_path).is_equal(
		"res://assets/textures/L2_DEALER_REACT_PLAYER_WIN_V001.png"
	)


func test_idle_loop_keeps_playing_underneath_the_reaction_overlay_l3_3() -> void:
	# specs/003 L3-3: overlay must not stop the loop, only hide its
	# rendering. Verified against the same is_idle_loop_active() signal
	# tests/ui/test_l3_dealer_idle_animation.gd already relies on.
	var h := _make_harness_scene()
	var dealer_idle_view: DealerIdleView = h.dealer_idle_view
	var expected_animation := dealer_idle_view.current_loop_animation()

	_play_to_dealer_bust(h)

	assert_bool(dealer_idle_view.visible).is_false()
	assert_bool(dealer_idle_view.is_idle_loop_active()).is_true()
	assert_that(dealer_idle_view.current_loop_animation()).is_equal(expected_animation)


func test_next_round_hides_the_reaction_and_restores_idle_view_visibility() -> void:
	var h := _make_harness_scene()
	_play_to_dealer_bust(h)
	var reaction_view: DealerReactionView = h.reaction_view
	var dealer_idle_view: DealerIdleView = h.dealer_idle_view
	assert_bool(reaction_view.visible).is_true()

	h.action_bar.deal_button().pressed.emit()

	assert_int((h.controller as RoundController).current_state).is_equal(RoundController.State.BETTING)
	assert_bool(reaction_view.visible).is_false()
	assert_bool(dealer_idle_view.visible).is_true()


## Face-occlusion equivalent for the reaction overlay (team-lead's explicit
## ask): the existing L1-5 defect #4 test only covers DealerIdleView's own
## rect. This proves the reaction view is anchored identically (same
## anchor_right/anchor_bottom as DealerIdleView), so the DealerHandView-vs-
## face-band guarantee carries over without needing a second independent
## geometry check.
func test_reaction_view_is_anchored_identically_to_dealer_idle_view() -> void:
	var h := _make_harness_scene()
	var reaction_view: DealerReactionView = h.reaction_view
	var dealer_idle_view: DealerIdleView = h.dealer_idle_view

	assert_float(reaction_view.anchor_top).is_equal(dealer_idle_view.anchor_top)
	assert_float(reaction_view.anchor_right).is_equal(dealer_idle_view.anchor_right)
	assert_float(reaction_view.anchor_bottom).is_equal(dealer_idle_view.anchor_bottom)
	assert_int(reaction_view.stretch_mode).is_equal(dealer_idle_view.stretch_mode)
	assert_int(reaction_view.expand_mode).is_equal(dealer_idle_view.expand_mode)


## Direct mapping-table proof for all 8 outcomes (not just the 3
## screenshot-friendly ones a full round can easily reach) — calls
## GameplayController's own resolver method rather than duplicating the
## dict, so this fails if the dict is ever edited without the resolver
## being updated too, and vice versa.
func test_all_eight_outcomes_map_to_one_of_the_six_reaction_textures() -> void:
	var gameplay: GameplayController = auto_free(GameplayController.new())
	var expected := {
		BlackjackOutcome.Type.PLAYER_BLACKJACK: "L2_DEALER_REACT_BLACKJACK_V001.png",
		BlackjackOutcome.Type.DEALER_BLACKJACK: "L2_DEALER_REACT_PLAYER_LOSE_V001.png",
		BlackjackOutcome.Type.PLAYER_WIN: "L2_DEALER_REACT_PLAYER_WIN_V001.png",
		BlackjackOutcome.Type.DEALER_WIN: "L2_DEALER_REACT_PLAYER_LOSE_V001.png",
		BlackjackOutcome.Type.PLAYER_BUST: "L2_DEALER_REACT_PLAYER_BUST_V001.png",
		BlackjackOutcome.Type.DEALER_BUST: "L2_DEALER_REACT_PLAYER_WIN_V001.png",
		BlackjackOutcome.Type.PUSH: "L2_DEALER_REACT_PUSH_V001.png",
		BlackjackOutcome.Type.PLAYER_SURRENDER: "L2_DEALER_REACT_SURRENDER_V001.png",
	}
	for outcome: int in expected:
		var texture := gameplay.reaction_texture_for_outcome(outcome)
		assert_object(texture).is_not_null()
		assert_str(texture.resource_path).is_equal("res://assets/textures/%s" % expected[outcome])
