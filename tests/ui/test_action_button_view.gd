class_name TestActionButtonView
extends GdUnitTestSuite
## Covers the Theme-First contract behind specs/003 L1-2 for BTN_ACTION:
## Action selects label + Theme type variation; no per-node StyleBox override
## stands in for what the Theme resource should own.


func test_default_action_is_hit_with_primary_theme_variation() -> void:
	var runner := scene_runner("res://ui/components/action_button.tscn")
	var button := runner.scene() as ActionButtonView

	assert_str(button.text).is_equal("HIT")
	assert_str(String(button.theme_type_variation)).is_equal("PrimaryActionButton")


func test_surrender_action_switches_to_danger_theme_variation() -> void:
	var runner := scene_runner("res://ui/components/action_button.tscn")
	var button := runner.scene() as ActionButtonView

	button.action = ActionButtonView.Action.SURRENDER
	await runner.simulate_frames(1)

	assert_str(button.text).is_equal("SURRENDER")
	assert_str(String(button.theme_type_variation)).is_equal("DangerActionButton")


func test_stand_and_double_actions_set_expected_labels() -> void:
	var runner := scene_runner("res://ui/components/action_button.tscn")
	var button := runner.scene() as ActionButtonView

	button.action = ActionButtonView.Action.STAND
	await runner.simulate_frames(1)
	assert_str(button.text).is_equal("STAND")
	assert_str(String(button.theme_type_variation)).is_equal("PrimaryActionButton")

	button.action = ActionButtonView.Action.DOUBLE
	await runner.simulate_frames(1)
	assert_str(button.text).is_equal("DOUBLE")
	assert_str(String(button.theme_type_variation)).is_equal("PrimaryActionButton")


func test_button_carries_no_local_stylebox_override() -> void:
	var runner := scene_runner("res://ui/components/action_button.tscn")
	var button := runner.scene() as ActionButtonView

	assert_bool(button.has_theme_stylebox_override("normal")).is_false()
	assert_bool(button.has_theme_stylebox_override("pressed")).is_false()
	assert_bool(button.has_theme_stylebox_override("disabled")).is_false()
	assert_bool(button.has_theme_stylebox_override("focus")).is_false()


func test_button_size_comes_from_theme_tokens_not_a_hardcoded_literal() -> void:
	# Literal Figma values (docs/12_FIGMA_COMPONENT_MANIFEST.md BTN_ACTION,
	# node 5:2) — NOT re-derived via button.get_theme_constant(), which
	# would just compare the production code's own accessor call against
	# itself (an identity, provably true even if _ready() hardcoded the
	# size and never called get_theme_constant() at all). Same pattern as
	# tests/ui/test_deal_button_view.gd's literal 320.0/72.0 assertions.
	var runner := scene_runner("res://ui/components/action_button.tscn")
	var button := runner.scene() as ActionButtonView

	assert_vector(button.custom_minimum_size).is_equal(Vector2(210, 64))
