class_name TestGameRootLayering
extends GdUnitTestSuite
## Covers specs/003 L3-1: GameRoot child order must be L3Root < L2Root < L1Root
## (bottom to top), per docs/05_FIGMA_TO_GODOT.md:29-59.


func test_game_root_has_the_recommended_top_level_nodes() -> void:
	var runner := scene_runner("res://scenes/game_root.tscn")
	var root: Node = runner.scene()

	assert_bool(root.has_node("L3Root")).is_true()
	assert_bool(root.has_node("L2Root")).is_true()
	assert_bool(root.has_node("L1Root")).is_true()
	assert_bool(root.has_node("RoundController")).is_true()
	assert_bool(root.has_node("PresentationController")).is_true()


func test_layer_roots_are_ordered_l3_below_l2_below_l1() -> void:
	var runner := scene_runner("res://scenes/game_root.tscn")
	var root: Node = runner.scene()
	var children := root.get_children()

	var l3_index := children.find(root.get_node("L3Root"))
	var l2_index := children.find(root.get_node("L2Root"))
	var l1_index := children.find(root.get_node("L1Root"))

	assert_int(l3_index).is_greater(-1)
	assert_int(l2_index).is_greater(-1)
	assert_int(l1_index).is_greater(-1)
	assert_int(l3_index).is_less(l2_index)
	assert_int(l2_index).is_less(l1_index)


func test_l3root_children_match_recommended_scene_tree() -> void:
	var runner := scene_runner("res://scenes/game_root.tscn")
	var root: Node = runner.scene()

	assert_bool(root.has_node("L3Root/BackgroundView")).is_true()
	assert_bool(root.has_node("L3Root/DealerIdleView")).is_true()


func test_l2root_children_match_recommended_scene_tree() -> void:
	var runner := scene_runner("res://scenes/game_root.tscn")
	var root: Node = runner.scene()

	assert_bool(root.has_node("L2Root/CardAnimationLayer")).is_true()
	assert_bool(root.has_node("L2Root/DealerReactionLayer")).is_true()
	assert_bool(root.has_node("L2Root/ResultOverlay")).is_true()
	assert_bool(root.has_node("L2Root/FXLayer")).is_true()


func test_l1root_children_match_recommended_scene_tree() -> void:
	var runner := scene_runner("res://scenes/game_root.tscn")
	var root: Node = runner.scene()

	var table_ui_path := "L1Root/TableUI"
	for child_name: String in [
		"DealerHandView",
		"PlayerHandView",
		"HandTotal",
		"ResultBanner",
		"ActionBar",
		"ChipsDisplay",
		"BetControl",
	]:
		assert_bool(root.has_node("%s/%s" % [table_ui_path, child_name])).is_true()
