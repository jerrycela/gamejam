class_name TestL13DynamicTextComponents
extends GdUnitTestSuite
## Covers specs/003 L1-3 for the three dynamic-text components not already
## covered by tests/ui/test_card_face_dynamic_text.gd (CARD_FACE is the
## fourth): ActionButtonView, DealButtonView, ValueDisplayView. L1-3's
## wording is not scoped to CARD_FACE specifically — "dynamic text must
## never be baked into a texture" applies to every component whose Figma
## TEXT property drives what a player reads (button labels, HAND value,
## STATE badge), not just card rank/suit.
##
## Shared assertion logic lives in one helper (_assert_no_texture_carries_text)
## rather than four near-identical test bodies, per team-lead's request.


func _assert_no_texture_carries_text(root: Node) -> void:
	assert_int(root.find_children("*", "TextureRect", true, false).size()).is_equal(0)
	assert_int(root.find_children("*", "Sprite2D", true, false).size()).is_equal(0)


func test_action_button_view_renders_its_label_via_the_button_text_property() -> void:
	var runner := scene_runner("res://ui/components/action_button.tscn")
	var button := runner.scene() as ActionButtonView

	# Button has no dedicated Label child — Godot's built-in Button renders
	# its own `text` property. Asserting that explicitly (not merely
	# "some child is a Label") is the point: a texture-based label swap
	# would leave `text` unset while still "looking" like it works visually.
	assert_object(button).is_instanceof(Button)
	button.action = ActionButtonView.Action.STAND
	assert_str(button.text).is_equal("停牌")
	assert_bool(button.text.is_empty()).is_false()
	_assert_no_texture_carries_text(button)


func test_deal_button_view_renders_both_labels_via_the_button_text_property() -> void:
	var runner := scene_runner("res://ui/components/deal_button.tscn")
	var button := runner.scene() as DealButtonView

	assert_object(button).is_instanceof(Button)
	assert_str(button.text).is_equal("發牌")

	button.label = DealButtonView.DealLabel.NEXT_ROUND
	assert_str(button.text).is_equal("下一局")
	_assert_no_texture_carries_text(button)


func test_value_display_view_renders_value_and_state_via_label_nodes() -> void:
	var runner := scene_runner("res://ui/components/value_display.tscn")
	var display := runner.scene() as ValueDisplayView

	display.value = "19"
	display.state = ValueDisplayView.State.SOFT
	await runner.simulate_frames(1)

	var value_label := display.get_value_label()
	var state_label := display.get_state_label()

	assert_object(value_label).is_instanceof(Label)
	assert_object(state_label).is_instanceof(Label)
	assert_str(value_label.text).is_equal("19")
	assert_str(state_label.text).is_equal("軟")
	_assert_no_texture_carries_text(display)
