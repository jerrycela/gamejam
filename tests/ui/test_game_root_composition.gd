class_name TestGameRootComposition
extends GdUnitTestSuite
## Covers specs/003 L1-4: GameRoot must be a composition of multiple scenes;
## no single TextureRect/Sprite2D may cover the whole viewport in its place.


func test_game_root_root_node_is_not_a_flat_image() -> void:
	var runner := scene_runner("res://scenes/game_root.tscn")
	var root: Node = runner.scene()

	assert_bool(root is TextureRect).is_false()
	assert_bool(root is Sprite2D).is_false()
	assert_int(root.get_child_count()).is_greater(1)


func test_no_top_level_image_node_stands_in_for_the_whole_screen() -> void:
	var runner := scene_runner("res://scenes/game_root.tscn")
	var root: Node = runner.scene()

	var flat_image_children := 0
	for child in root.get_children():
		if child is TextureRect or child is Sprite2D:
			flat_image_children += 1
	assert_int(flat_image_children).is_equal(0)


func test_table_ui_is_composed_of_multiple_independent_nodes() -> void:
	var runner := scene_runner("res://scenes/game_root.tscn")
	var root: Node = runner.scene()
	var table_ui := root.get_node("L1Root/TableUI") as Control

	assert_bool(table_ui is TextureRect).is_false()
	assert_int(table_ui.get_child_count()).is_greater(1)


func test_hand_views_instantiate_the_card_face_component_not_a_texture() -> void:
	var runner := scene_runner("res://scenes/game_root.tscn")
	var root: Node = runner.scene()

	var dealer_card := root.get_node("L1Root/TableUI/DealerHandView/DealerCard1")
	var player_card := root.get_node("L1Root/TableUI/PlayerHandView/PlayerCard1")

	assert_object(dealer_card).is_instanceof(CardFaceView)
	assert_object(player_card).is_instanceof(CardFaceView)


func test_action_bar_instantiates_the_action_button_component_not_a_texture() -> void:
	var runner := scene_runner("res://scenes/game_root.tscn")
	var root: Node = runner.scene()

	for button_name: String in ["HitButton", "StandButton", "DoubleButton", "SurrenderButton"]:
		var button := root.get_node("L1Root/TableUI/ActionBar/%s" % button_name)
		assert_object(button).is_instanceof(ActionButtonView)
