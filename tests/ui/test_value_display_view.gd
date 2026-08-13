class_name TestValueDisplayView
extends GdUnitTestSuite
## Covers VALUE_TOTAL (Figma node 21:62) -> res://ui/components/value_display.tscn
## per docs/12_FIGMA_COMPONENT_MANIFEST.md. State (Hard/Soft/Bust) is a Figma
## variant driving color only; Value is the dynamic TEXT property. The
## component itself never computes soft/hard/bust — AGENTS.md:86 forbids L1
## from calculating hand results; the caller must pass in HandEvaluator's
## result.


func test_value_and_state_are_rendered_by_label_nodes_not_a_texture() -> void:
	var runner := scene_runner("res://ui/components/value_display.tscn")
	var view := runner.scene() as ValueDisplayView
	view.state = ValueDisplayView.State.HARD
	view.value = "18"
	await runner.simulate_frames(1)

	assert_int(view.find_children("*", "TextureRect", true, false).size()).is_equal(0)
	assert_int(view.find_children("*", "Sprite2D", true, false).size()).is_equal(0)
	var labels := view.find_children("*", "Label", true, false)
	assert_int(labels.size()).is_equal(2)


func test_hard_state_uses_text_primary_and_shows_hard_label() -> void:
	var runner := scene_runner("res://ui/components/value_display.tscn")
	var view := runner.scene() as ValueDisplayView
	view.state = ValueDisplayView.State.HARD
	view.value = "18"
	await runner.simulate_frames(1)

	assert_str(view.get_value_label().text).is_equal("18")
	assert_str(view.get_state_label().text).is_equal("HARD")
	var expected := view.get_theme_color("text_primary", "Tokens")
	assert_that(view.get_value_label().get_theme_color("font_color")).is_equal(expected)
	assert_that(view.get_state_label().get_theme_color("font_color")).is_equal(expected)


func test_soft_state_uses_text_secondary_and_shows_soft_label() -> void:
	var runner := scene_runner("res://ui/components/value_display.tscn")
	var view := runner.scene() as ValueDisplayView
	view.state = ValueDisplayView.State.SOFT
	view.value = "18"
	await runner.simulate_frames(1)

	assert_str(view.get_state_label().text).is_equal("SOFT")
	var expected := view.get_theme_color("text_secondary", "Tokens")
	assert_that(view.get_value_label().get_theme_color("font_color")).is_equal(expected)


func test_bust_state_uses_result_bust_and_shows_bust_label() -> void:
	var runner := scene_runner("res://ui/components/value_display.tscn")
	var view := runner.scene() as ValueDisplayView
	view.state = ValueDisplayView.State.BUST
	view.value = "24"
	await runner.simulate_frames(1)

	assert_str(view.get_value_label().text).is_equal("24")
	assert_str(view.get_state_label().text).is_equal("BUST")
	var expected := view.get_theme_color("result_bust", "Tokens")
	assert_that(view.get_value_label().get_theme_color("font_color")).is_equal(expected)


func test_font_sizes_come_from_theme_tokens_not_hardcoded_literals() -> void:
	# Literal Figma/theme values (ui/theme/lsbj_theme.tres
	# Tokens/constants/value_total_font_size=56,
	# value_total_state_font_size=18) — NOT re-derived via
	# view.get_theme_constant(), which would just compare the production
	# code's own accessor call against itself (an identity, provably true
	# even if _ready() hardcoded the font size and never called
	# get_theme_constant() at all).
	var runner := scene_runner("res://ui/components/value_display.tscn")
	var view := runner.scene() as ValueDisplayView

	assert_int(view.get_value_label().get_theme_font_size("font_size")).is_equal(56)
	assert_int(view.get_state_label().get_theme_font_size("font_size")).is_equal(18)


func test_set_from_hand_evaluation_reflects_the_evaluator_result_without_computing_it_itself() -> void:
	# AGENTS.md:86 — L1 must not calculate Blackjack results itself. This
	# component only ever renders whatever HandEvaluator already decided.
	var runner := scene_runner("res://ui/components/value_display.tscn")
	var view := runner.scene() as ValueDisplayView
	var cards: Array[Card] = [
		Card.new(Card.Rank.ACE, Card.Suit.HEARTS),
		Card.new(Card.Rank.SEVEN, Card.Suit.SPADES),
	]
	var evaluation := HandEvaluator.evaluate(cards)

	view.set_from_hand_evaluation(evaluation)
	await runner.simulate_frames(1)

	assert_str(view.get_value_label().text).is_equal(str(evaluation.total))
	assert_int(view.state).is_equal(ValueDisplayView.State.SOFT)
