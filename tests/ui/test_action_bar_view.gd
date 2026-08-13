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


## Real player-input wiring (new task): pressing any button in this panel
## must be observable as a single action_id-carrying signal a controller can
## connect to exactly once, regardless of which concrete button kind
## (ActionButtonView vs DealButtonView) was actually pressed — a
## GameplayController shouldn't need to know button implementation details.
func test_pressing_a_hit_button_emits_action_requested_with_the_hit_action_id() -> void:
	var runner := scene_runner("res://ui/components/action_bar.tscn")
	var bar := runner.scene() as ActionBarView
	bar.sync_with_legal_actions([RoundController.ACTION_HIT, RoundController.ACTION_STAND])
	var hit_button: ActionButtonView = null
	for button in bar.buttons():
		if button.action == ActionButtonView.Action.HIT:
			hit_button = button
	monitor_signals(bar)

	hit_button.pressed.emit()

	await assert_signal(bar).is_emitted("action_requested", RoundController.ACTION_HIT)


func test_pressing_the_deal_button_emits_action_requested_with_the_deal_action_id() -> void:
	var runner := scene_runner("res://ui/components/action_bar.tscn")
	var bar := runner.scene() as ActionBarView
	bar.sync_with_legal_actions([RoundController.ACTION_PLACE_BET, RoundController.ACTION_DEAL])
	monitor_signals(bar)

	bar.deal_button().pressed.emit()

	await assert_signal(bar).is_emitted("action_requested", RoundController.ACTION_DEAL)


func test_pressing_the_next_round_button_emits_action_requested_with_the_next_round_action_id() -> void:
	var runner := scene_runner("res://ui/components/action_bar.tscn")
	var bar := runner.scene() as ActionBarView
	bar.sync_with_legal_actions([RoundController.ACTION_NEXT_ROUND])
	monitor_signals(bar)

	bar.deal_button().pressed.emit()

	await assert_signal(bar).is_emitted("action_requested", RoundController.ACTION_NEXT_ROUND)


## Named-method counter (not an inline lambda) connected directly to the
## signal under test — deliberately avoiding gdUnit4's known lambda-adjacency
## discovery bug (a hand-written `signal.connect(func(...): ...)` in a test
## file can silently drop the *next* test in file order from discovery).
var _resync_emission_count := 0


func _count_resync_emission(_action_id: StringName) -> void:
	_resync_emission_count += 1


func test_pressing_a_button_after_a_resync_still_emits_exactly_once() -> void:
	# Guards against a stale connection surviving a rebuild and firing twice
	# (or a new one stacking on top of an old one that somehow wasn't freed).
	var runner := scene_runner("res://ui/components/action_bar.tscn")
	var bar := runner.scene() as ActionBarView
	bar.sync_with_legal_actions([RoundController.ACTION_HIT, RoundController.ACTION_STAND])
	bar.sync_with_legal_actions([RoundController.ACTION_HIT, RoundController.ACTION_STAND])
	var hit_button: ActionButtonView = null
	for button in bar.buttons():
		if button.action == ActionButtonView.Action.HIT:
			hit_button = button
	bar.action_requested.connect(_count_resync_emission)

	hit_button.pressed.emit()

	assert_int(_resync_emission_count).is_equal(1)
