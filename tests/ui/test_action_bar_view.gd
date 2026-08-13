class_name TestActionBarView
extends GdUnitTestSuite
## Covers PANEL_ACTION_BAR (Figma node 21:38) -> res://ui/components/action_bar.tscn
## per docs/12_FIGMA_COMPONENT_MANIFEST.md. Player State drives which
## BTN_ACTION instances exist; illegal actions are HIDDEN (not merely
## disabled) — this is a Container-driven Auto Layout mapping
## (docs/05_FIGMA_TO_GODOT.md §2), not 5 hardcoded scenes.
##
## Scope note: HIT/STAND/DOUBLE/SURRENDER each map to an ActionButtonView.
## DEAL/NEXT_ROUND now map to the single DealButtonView (BTN_DEAL, docs/12
## node 9:17, approved_version 1.1.0) via team-lead's ruling that it enters
## scope through PANEL_ACTION_BAR's own Betting/RoundEnd variants (both of
## which instance BTN_DEAL) rather than as a standalone scope expansion.
## PLACE_BET still has no button here — Bet Controls is a separate TableUI
## node (docs/01:35-54, docs/05:29-51).


func test_sync_with_legal_actions_instantiates_only_the_legal_buttons_in_figma_order() -> void:
	var runner := scene_runner("res://ui/components/action_bar.tscn")
	var bar := runner.scene() as ActionBarView

	bar.sync_with_legal_actions([
		RoundController.ACTION_HIT,
		RoundController.ACTION_STAND,
		RoundController.ACTION_DOUBLE,
		RoundController.ACTION_SURRENDER,
	])

	assert_int(bar.button_count()).is_equal(4)
	var actions := bar.button_actions()
	assert_array(actions).contains_exactly([
		ActionButtonView.Action.HIT,
		ActionButtonView.Action.STAND,
		ActionButtonView.Action.DOUBLE,
		ActionButtonView.Action.SURRENDER,
	])


func test_sync_with_legal_actions_hides_illegal_actions_instead_of_disabling_them() -> void:
	var runner := scene_runner("res://ui/components/action_bar.tscn")
	var bar := runner.scene() as ActionBarView

	# PlayerTurnDecided: only HIT/STAND remain legal after the first decision.
	bar.sync_with_legal_actions([RoundController.ACTION_HIT, RoundController.ACTION_STAND])

	assert_int(bar.button_count()).is_equal(2)
	assert_array(bar.button_actions()).contains_exactly([
		ActionButtonView.Action.HIT,
		ActionButtonView.Action.STAND,
	])


func test_sync_with_legal_actions_ignores_place_bet_but_renders_the_deal_button() -> void:
	var runner := scene_runner("res://ui/components/action_bar.tscn")
	var bar := runner.scene() as ActionBarView

	# BETTING: legal_actions() = [PLACE_BET, DEAL] — PLACE_BET has no button
	# here (Bet Controls is a separate TableUI node), DEAL renders the single
	# DealButtonView labelled "DEAL".
	bar.sync_with_legal_actions([RoundController.ACTION_PLACE_BET, RoundController.ACTION_DEAL])

	assert_int(bar.button_count()).is_equal(1)
	assert_array(bar.button_actions()).is_empty()
	var deal_button := bar.deal_button()
	assert_object(deal_button).is_not_null()
	assert_int(deal_button.label).is_equal(DealButtonView.DealLabel.DEAL)
	assert_bool(deal_button.disabled).is_false()


func test_sync_with_legal_actions_renders_next_round_label_and_no_hit_stand_buttons() -> void:
	var runner := scene_runner("res://ui/components/action_bar.tscn")
	var bar := runner.scene() as ActionBarView

	# ROUND_END: legal_actions() = [NEXT_ROUND].
	bar.sync_with_legal_actions([RoundController.ACTION_NEXT_ROUND])

	assert_int(bar.button_count()).is_equal(1)
	var deal_button := bar.deal_button()
	assert_object(deal_button).is_not_null()
	assert_int(deal_button.label).is_equal(DealButtonView.DealLabel.NEXT_ROUND)


func test_sync_with_legal_actions_rebuilds_from_a_previous_set() -> void:
	var runner := scene_runner("res://ui/components/action_bar.tscn")
	var bar := runner.scene() as ActionBarView

	bar.sync_with_legal_actions([
		RoundController.ACTION_HIT,
		RoundController.ACTION_STAND,
		RoundController.ACTION_DOUBLE,
		RoundController.ACTION_SURRENDER,
	])
	bar.sync_with_legal_actions([RoundController.ACTION_HIT, RoundController.ACTION_STAND])

	assert_int(bar.button_count()).is_equal(2)


func test_set_blocking_disabled_disables_without_changing_composition() -> void:
	var runner := scene_runner("res://ui/components/action_bar.tscn")
	var bar := runner.scene() as ActionBarView
	bar.sync_with_legal_actions([
		RoundController.ACTION_HIT,
		RoundController.ACTION_STAND,
		RoundController.ACTION_DOUBLE,
		RoundController.ACTION_SURRENDER,
	])
	var before_count := bar.button_count()

	bar.set_blocking_disabled(true)

	assert_int(bar.button_count()).is_equal(before_count)
	for button in bar.buttons():
		assert_bool(button.disabled).is_true()

	bar.set_blocking_disabled(false)
	assert_int(bar.button_count()).is_equal(before_count)
	for button in bar.buttons():
		assert_bool(button.disabled).is_false()


func test_set_blocking_disabled_also_covers_the_deal_button() -> void:
	var runner := scene_runner("res://ui/components/action_bar.tscn")
	var bar := runner.scene() as ActionBarView
	bar.sync_with_legal_actions([RoundController.ACTION_PLACE_BET, RoundController.ACTION_DEAL])

	bar.set_blocking_disabled(true)
	assert_bool(bar.deal_button().disabled).is_true()
	assert_int(bar.button_count()).is_equal(1)

	bar.set_blocking_disabled(false)
	assert_bool(bar.deal_button().disabled).is_false()


func test_action_bar_is_a_panel_container_using_the_theme_action_bar_panel_variation() -> void:
	var runner := scene_runner("res://ui/components/action_bar.tscn")
	var bar := runner.scene() as ActionBarView

	assert_bool(bar is PanelContainer).is_true()
	assert_str(String(bar.theme_type_variation)).is_equal("ActionBarPanel")
