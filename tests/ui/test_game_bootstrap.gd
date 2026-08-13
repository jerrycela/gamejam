class_name TestGameBootstrap
extends GdUnitTestSuite
## Covers the production bootstrap gap both prior agents flagged as
## SPEC REQUIRED (GameRoot's controller nodes were wired only by tests, never
## by anything that runs when the scene actually loads). team-lead's ruling:
## this is implementation detail (how a startup seed gets produced), not a
## No-Guessing product rule (AGENTS.md §9 covers deck count/penetration/
## soft-17/payouts/content, not "how does the app boot"); the requirement to
## log the shoe seed for reproducibility already exists
## (docs/02_BLACKJACK_RULES.md §8).


func test_default_ready_boots_a_wired_controller_into_betting_with_a_legal_actions_action_bar() -> void:
	var runner := scene_runner("res://scenes/game_root.tscn")
	var root: Node = runner.scene()
	var bootstrap := root.get_node("Bootstrap") as GameBootstrap
	var round_controller_node := root.get_node("RoundController") as RoundControllerNode
	var table_ui := root.get_node("L1Root/TableUI") as Node
	var action_bar := table_ui.find_child("ActionBar", true, false) as ActionBarView

	# Wired, not null, and it's the same controller instance RoundControllerNode
	# was setup() with.
	assert_object(bootstrap.controller).is_not_null()
	assert_object(round_controller_node.controller).is_same(bootstrap.controller)

	assert_int(bootstrap.controller.current_state).is_equal(RoundController.State.BETTING)

	# ActionBar reflects legal_actions() immediately, not an empty/stale
	# design-time scaffold: BETTING -> [PLACE_BET, DEAL] -> one DealButtonView.
	assert_int(action_bar.button_count()).is_equal(1)
	var deal_button := action_bar.deal_button()
	assert_object(deal_button).is_not_null()
	assert_int(deal_button.label).is_equal(DealButtonView.DealLabel.DEAL)
	assert_bool(deal_button.disabled).is_false()


func test_default_ready_generates_and_records_a_reproducible_shoe_id_and_seed() -> void:
	# docs/02_BLACKJACK_RULES.md §8: shoe seed and starting draw index must be
	# recorded for reproducibility. last_shoe_id()/last_shuffle_seed() are the
	# test-facing record of what actually got logged (via print()) at boot.
	var runner := scene_runner("res://scenes/game_root.tscn")
	var root: Node = runner.scene()
	var bootstrap := root.get_node("Bootstrap") as GameBootstrap

	assert_bool(bootstrap.last_shoe_id().is_empty()).is_false()
	# Not asserting a specific seed value (it's genuinely random at boot) —
	# only that one was recorded and is a real integer, not a placeholder.
	assert_int(bootstrap.last_shuffle_seed()).is_not_equal(0)


func test_bootstrap_can_be_reproduced_with_an_explicit_seed_for_tests() -> void:
	# The public bootstrap(shoe_id, shuffle_seed) method IS the test seam
	# (same pattern as PresentationController's force_*_for_test() methods):
	# call it again with fixed values to replace the random boot
	# deterministically, and prove the seed actually reaches DeckShoe by
	# comparing two independently-bootstrapped controllers with the same
	# seed end up dealing the exact same cards.
	var runner_a := scene_runner("res://scenes/game_root.tscn")
	var root_a: Node = runner_a.scene()
	var bootstrap_a := root_a.get_node("Bootstrap") as GameBootstrap
	bootstrap_a.bootstrap("test-shoe-repro", 4242)
	assert_str(bootstrap_a.last_shoe_id()).is_equal("test-shoe-repro")
	assert_int(bootstrap_a.last_shuffle_seed()).is_equal(4242)
	assert_bool(bootstrap_a.controller.place_bet(100)).is_true()
	assert_bool(bootstrap_a.controller.deal("round-repro-a")).is_true()
	var snapshot_a := bootstrap_a.controller.snapshot()

	var runner_b := scene_runner("res://scenes/game_root.tscn")
	var root_b: Node = runner_b.scene()
	var bootstrap_b := root_b.get_node("Bootstrap") as GameBootstrap
	bootstrap_b.bootstrap("test-shoe-repro", 4242)
	assert_bool(bootstrap_b.controller.place_bet(100)).is_true()
	assert_bool(bootstrap_b.controller.deal("round-repro-b")).is_true()
	var snapshot_b := bootstrap_b.controller.snapshot()

	assert_int(snapshot_a.player_cards.size()).is_equal(snapshot_b.player_cards.size())
	for i in snapshot_a.player_cards.size():
		assert_int(snapshot_a.player_cards[i].rank).is_equal(snapshot_b.player_cards[i].rank)
		assert_int(snapshot_a.player_cards[i].suit).is_equal(snapshot_b.player_cards[i].suit)
	assert_int(snapshot_a.dealer_visible_cards.size()).is_equal(snapshot_b.dealer_visible_cards.size())
	for i in snapshot_a.dealer_visible_cards.size():
		assert_int(snapshot_a.dealer_visible_cards[i].rank).is_equal(snapshot_b.dealer_visible_cards[i].rank)
		assert_int(snapshot_a.dealer_visible_cards[i].suit).is_equal(snapshot_b.dealer_visible_cards[i].suit)


func test_fallback_overlay_is_wired_so_asset_failure_shows_a_visual_in_the_live_scene() -> void:
	# Ties Task 2 (L2-4 fallback visual) to the real scene: proves
	# GameBootstrap's PresentationController.setup() call actually passes a
	# real overlay Control, not null — otherwise report_asset_load_failure()
	# would silently have nothing to show in production.
	var runner := scene_runner("res://scenes/game_root.tscn")
	var root: Node = runner.scene()
	var bootstrap := root.get_node("Bootstrap") as GameBootstrap
	var presentation_controller := root.get_node("PresentationController") as PresentationController

	assert_bool(bootstrap.controller.place_bet(100)).is_true()
	var deal_started := presentation_controller.begin_deal_presentation("round-bootstrap-fallback")
	assert_bool(deal_started).is_true()

	presentation_controller.report_asset_load_failure("L2_DEAL_CARD_V001")

	assert_bool(presentation_controller.is_fallback_visual_visible()).is_true()
