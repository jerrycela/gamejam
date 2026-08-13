class_name TestL1ViewportResponsiveness
extends GdUnitTestSuite
## Machine-checkable slice of specs/003 L1-5 (docs/09_TEST_AND_ACCEPTANCE.md
## viewport QA still needs human visual approval for the rest of L1-5, but
## the structural guarantee — ActionBar stays on-screen and never overlaps
## PlayerHandView — is checkable now that L1's TableUI layout is
## anchors/containers-driven (docs/01_GAME_AND_LAYER_SPEC.md:29) instead of
## absolute pixel offsets that only happened to fit the 1080x1920 reference.
##
## Sizes are the three specs/003 "Open Questions" decided viewports:
## reference_1080x1920, narrow_portrait 1080x2400, wide_portrait 1200x1600.

const VIEWPORT_SIZES: Array[Vector2i] = [
	Vector2i(1080, 1920),
	Vector2i(1080, 2400),
	Vector2i(1200, 1600),
]


func test_action_bar_stays_within_the_viewport_across_all_three_reference_sizes() -> void:
	var runner := scene_runner("res://scenes/game_root.tscn")
	var root: Node = runner.scene()
	var table_ui := root.get_node("L1Root/TableUI") as Control
	var action_bar := table_ui.find_child("ActionBar", true, false) as Control
	var viewport := root.get_viewport()

	for size: Vector2i in VIEWPORT_SIZES:
		_apply_viewport_size(viewport, size)
		await runner.simulate_frames(2)

		var bar_rect := action_bar.get_global_rect()
		assert_bool(bar_rect.position.x >= 0.0).is_true()
		assert_bool(bar_rect.position.y >= 0.0).is_true()
		assert_bool(bar_rect.end.x <= size.x).is_true()
		assert_bool(bar_rect.end.y <= size.y).is_true()


func test_action_bar_never_overlaps_player_hand_view_across_all_three_reference_sizes() -> void:
	var runner := scene_runner("res://scenes/game_root.tscn")
	var root: Node = runner.scene()
	var table_ui := root.get_node("L1Root/TableUI") as Control
	var action_bar := table_ui.find_child("ActionBar", true, false) as Control
	var player_hand_view := table_ui.find_child("PlayerHandView", true, false) as Control
	var viewport := root.get_viewport()

	for size: Vector2i in VIEWPORT_SIZES:
		_apply_viewport_size(viewport, size)
		await runner.simulate_frames(2)

		var bar_rect := action_bar.get_global_rect()
		var hand_rect := player_hand_view.get_global_rect()
		assert_bool(bar_rect.intersects(hand_rect)).is_false()


func test_dealer_hand_view_stays_within_the_viewport_across_all_three_reference_sizes() -> void:
	var runner := scene_runner("res://scenes/game_root.tscn")
	var root: Node = runner.scene()
	var table_ui := root.get_node("L1Root/TableUI") as Control
	var dealer_hand_view := table_ui.find_child("DealerHandView", true, false) as Control
	var viewport := root.get_viewport()

	for size: Vector2i in VIEWPORT_SIZES:
		_apply_viewport_size(viewport, size)
		await runner.simulate_frames(2)

		var dealer_rect := dealer_hand_view.get_global_rect()
		assert_bool(dealer_rect.position.y >= 0.0).is_true()
		assert_bool(dealer_rect.end.x <= size.x).is_true()


## Pins both the Window's pixel size and its content_scale_size to the same
## value so get_visible_rect() (what Controls actually anchor against)
## equals `size` exactly. Project stretch/aspect="expand" (docs/05:161 §9)
## otherwise derives a different effective canvas rect from the window's
## aspect ratio vs. the project's base 1080x1920 — correct for real runtime
## scaling, but it means testing "does layout X reflow at target size Y"
## needs the visible rect pinned directly rather than only resizing the
## window and hoping the derived rect lands on Y.
func _apply_viewport_size(viewport: Viewport, size: Vector2i) -> void:
	var window := viewport as Window
	if window != null:
		window.content_scale_size = size
		window.size = size
