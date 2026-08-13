class_name TestCardFaceViewFaceDown
extends GdUnitTestSuite
## Covers the hidden-card rendering CardFaceView needs for a real playable
## round (new player-input task): the dealer's hole card must be rendered
## face-down using L1_CARD_BACK_V001 (assets/textures/) — CARD_BACK is still
## PENDING_CREATE in docs/12_FIGMA_COMPONENT_MANIFEST.md, so per team-lead's
## instruction this uses the texture directly instead of building a new
## Figma component/scene for it.
##
## Godot's own RoundController.snapshot() never exposes the hidden card's
## identity at all (scripts/core/round_controller.gd's secrecy boundary), so
## a face-down CardFaceView is always constructed with placeholder rank/suit
## it never actually shows — the card back texture must fully cover the
## rank/suit Labels, not just sit alongside them.


func test_default_card_is_face_up_and_shows_rank_and_suit() -> void:
	var runner := scene_runner("res://ui/components/card_view.tscn")
	var card := runner.scene() as CardFaceView

	assert_bool(card.face_down).is_false()
	assert_bool(card.get_node("VBoxContainer").visible).is_true()
	assert_bool(card.get_node("CardBackTexture").visible).is_false()


func test_face_down_hides_rank_and_suit_and_shows_the_card_back_texture() -> void:
	var runner := scene_runner("res://ui/components/card_view.tscn")
	var card := runner.scene() as CardFaceView

	card.face_down = true

	assert_bool(card.get_node("VBoxContainer").visible).is_false()
	var back_texture := card.get_node("CardBackTexture") as TextureRect
	assert_bool(back_texture.visible).is_true()
	assert_str(back_texture.texture.resource_path).is_equal(
		"res://assets/textures/L1_CARD_BACK_V001.png"
	)


func test_switching_back_to_face_up_hides_the_card_back_texture_again() -> void:
	var runner := scene_runner("res://ui/components/card_view.tscn")
	var card := runner.scene() as CardFaceView

	card.face_down = true
	card.face_down = false

	assert_bool(card.get_node("VBoxContainer").visible).is_true()
	assert_bool(card.get_node("CardBackTexture").visible).is_false()
