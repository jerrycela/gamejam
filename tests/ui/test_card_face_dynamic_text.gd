class_name TestCardFaceDynamicText
extends GdUnitTestSuite
## Covers specs/003 L1-3: dynamic text (Rank, Suit glyph) must be rendered by
## Label/RichTextLabel nodes, never baked into a texture.


func test_card_face_rank_and_suit_are_rendered_by_label_nodes() -> void:
	var runner := scene_runner("res://ui/components/card_view.tscn")
	var card := runner.scene() as CardFaceView
	card.rank = "10"
	card.suit = CardFaceView.Suit.HEART
	await runner.simulate_frames(1)

	var rank_label := card.get_node("VBoxContainer/CornerBox/RankLabel")
	var corner_suit_label := card.get_node("VBoxContainer/CornerBox/CornerSuitLabel")
	var center_suit_label := card.get_node("VBoxContainer/CenterBox/CenterSuitLabel")

	assert_object(rank_label).is_instanceof(Label)
	assert_object(corner_suit_label).is_instanceof(Label)
	assert_object(center_suit_label).is_instanceof(Label)

	assert_str((rank_label as Label).text).is_equal("10")
	assert_str((center_suit_label as Label).text).is_equal("♥")
	assert_str((corner_suit_label as Label).text).is_equal("♥")


func test_card_face_scene_has_no_texture_node_carrying_text() -> void:
	var runner := scene_runner("res://ui/components/card_view.tscn")
	var card := runner.scene() as CardFaceView

	assert_int(card.find_children("*", "TextureRect", true, false).size()).is_equal(0)
	assert_int(card.find_children("*", "Sprite2D", true, false).size()).is_equal(0)


func test_card_face_updates_color_by_suit_via_theme_tokens() -> void:
	var runner := scene_runner("res://ui/components/card_view.tscn")
	var card := runner.scene() as CardFaceView
	var center_suit_label := card.get_node("VBoxContainer/CenterBox/CenterSuitLabel") as Label

	card.suit = CardFaceView.Suit.SPADE
	await runner.simulate_frames(1)
	var black_color: Color = card.get_theme_color("card_suit_black", "Tokens")
	assert_that(center_suit_label.get_theme_color("font_color")).is_equal(black_color)

	card.suit = CardFaceView.Suit.DIAMOND
	await runner.simulate_frames(1)
	var red_color: Color = card.get_theme_color("card_suit_red", "Tokens")
	assert_that(center_suit_label.get_theme_color("font_color")).is_equal(red_color)
