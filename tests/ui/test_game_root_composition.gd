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
	# TableUI's direct child is a layout container (anchors/containers per
	# docs/01_GAME_AND_LAYER_SPEC.md:29), so count the whole descendant tree
	# rather than only direct children — still proves this is many real nodes,
	# not a flattened image.
	assert_int(table_ui.find_children("*", "", true, false).size()).is_greater(1)


func test_hand_views_instantiate_the_card_face_component_not_a_texture() -> void:
	# GameplayController now renders real hands from RoundController's own
	# state (tests/ui/test_gameplay_controller.gd), so the design-time
	# "DealerCard1"/"PlayerCard1" scaffold nodes get freed the instant
	# GameBootstrap._ready() runs its first refresh() — same
	# free-and-rebuild lifecycle every other dynamic component in this
	# codebase already has (ActionBar's buttons, etc). At rest (BETTING,
	# nothing dealt yet) both hand views are legitimately empty; drive an
	# actual deal to prove real cards render as CardFaceView instances.
	var runner := scene_runner("res://scenes/game_root.tscn")
	var root: Node = runner.scene()
	var table_ui := root.get_node("L1Root/TableUI") as Node
	var action_bar := table_ui.find_child("ActionBar", true, false) as ActionBarView
	var presentation_controller := root.get_node("PresentationController") as PresentationController
	var dealer_hand_view := table_ui.find_child("DealerHandView", true, false) as Node
	var player_hand_view := table_ui.find_child("PlayerHandView", true, false) as Node

	action_bar.deal_button().pressed.emit()
	presentation_controller.notify_presentation_finished(presentation_controller.active_token())

	assert_int(player_hand_view.get_child_count()).is_greater(0)
	for card in player_hand_view.get_children():
		assert_object(card).is_instanceof(CardFaceView)
	assert_int(dealer_hand_view.get_child_count()).is_greater(0)
	for card in dealer_hand_view.get_children():
		assert_object(card).is_instanceof(CardFaceView)


func test_action_bar_instantiates_real_button_components_not_a_texture() -> void:
	# Since GameBootstrap now wires and syncs the scene on load (see
	# tests/ui/test_game_bootstrap.gd), the panel's composition at rest is
	# BETTING's single DealButtonView, not the design-time HitButton/
	# StandButton/DoubleButton/SurrenderButton scaffold — those get freed the
	# moment sync_with_legal_actions() first runs, same as any other gameplay
	# test that touches the ActionBar. What L1-4 actually needs proven (real
	# node composition, never a flat texture standing in for a button) holds
	# for whichever buttons are actually present.
	var runner := scene_runner("res://scenes/game_root.tscn")
	var root: Node = runner.scene()
	var table_ui := root.get_node("L1Root/TableUI") as Node
	var action_bar := table_ui.find_child("ActionBar", true, false) as ActionBarView

	assert_int(action_bar.button_count()).is_greater(0)
	for child in action_bar.get_node("ButtonRow").get_children():
		assert_bool(child is ActionButtonView or child is DealButtonView).is_true()
		assert_bool(child is TextureRect or child is Sprite2D).is_false()

	# BETTING (the state the scene boots into) specifically renders through
	# DealButtonView, not ActionButtonView — assert that concretely too.
	assert_object(action_bar.deal_button()).is_instanceof(DealButtonView)
