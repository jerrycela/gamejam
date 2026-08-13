class_name TestActionBarView
extends GdUnitTestSuite
## Covers PANEL_ACTION_BAR (Figma node 21:38) -> res://ui/components/action_bar.tscn
## per docs/12_FIGMA_COMPONENT_MANIFEST.md. Player State drives which
## BTN_ACTION instances exist; illegal actions are HIDDEN (not merely
## disabled) — this is a Container-driven Auto Layout mapping
## (docs/05_FIGMA_TO_GODOT.md §2), not 5 hardcoded scenes.
##
## Scope note: only HIT/STAND/DOUBLE/SURRENDER map to a button here.
## PLACE_BET/DEAL/NEXT_ROUND have no button in this component — BTN_DEAL is
## explicitly out of specs/003's registered component scope even though it
## is APPROVED_PENDING_GODOT_SYNC in docs/12. See report to team-lead.


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


func test_sync_with_legal_actions_with_no_action_kind_legal_actions_produces_zero_buttons() -> void:
	var runner := scene_runner("res://ui/components/action_bar.tscn")
	var bar := runner.scene() as ActionBarView

	# BETTING: legal_actions() = [PLACE_BET, DEAL] — neither maps to a button here.
	bar.sync_with_legal_actions([RoundController.ACTION_PLACE_BET, RoundController.ACTION_DEAL])

	assert_int(bar.button_count()).is_equal(0)


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


func test_action_bar_is_a_panel_container_using_the_theme_action_bar_panel_variation() -> void:
	var runner := scene_runner("res://ui/components/action_bar.tscn")
	var bar := runner.scene() as ActionBarView

	assert_bool(bar is PanelContainer).is_true()
	assert_str(String(bar.theme_type_variation)).is_equal("ActionBarPanel")
