class_name TestL3RootMouseFilter
extends GdUnitTestSuite
## Covers specs/003 L3-2: L3Root and every descendant must ignore mouse input
## so ActionBar hit-testing is never blocked by L3 placeholder visuals.


func test_l3root_and_all_descendants_ignore_mouse() -> void:
	var runner := scene_runner("res://scenes/game_root.tscn")
	var root: Node = runner.scene()
	var l3_root := root.get_node("L3Root") as Control

	assert_object(l3_root).is_not_null()
	assert_int(l3_root.mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)
	_assert_subtree_ignores_mouse(l3_root)


func test_action_bar_button_keeps_default_mouse_filter_under_l3_overlay() -> void:
	# NOTE: this is a structural check, not the "自動化 input 命中測試" that
	# L3-2 ultimately asks for. gdUnit4 itself warns that InputEvents are not
	# transported in headless mode, so a real synthesized-click hit test needs
	# either a non-headless run or an injected InputEvent pipeline neither of
	# which this pass implements. What this asserts: L3Root (and everything
	# under it) is set to IGNORE, while ActionBar's own buttons are left at
	# Godot's default STOP filter, so nothing in the L3 subtree can be the
	# reason a real click on ActionBar would fail to reach it.
	##
	## Checks the DealButtonView specifically, not a node named "HitButton" —
	## GameBootstrap now wires+syncs the scene on load (tests/ui/test_game_bootstrap.gd),
	## so the panel boots into BETTING's single DealButtonView, not the
	## design-time HIT/STAND/DOUBLE/SURRENDER scaffold.
	var runner := scene_runner("res://scenes/game_root.tscn")
	var root: Node = runner.scene()
	var table_ui := root.get_node("L1Root/TableUI") as Node
	var action_bar := table_ui.find_child("ActionBar", true, false) as ActionBarView
	var deal_button := action_bar.deal_button()

	assert_object(deal_button).is_not_null()
	assert_int(deal_button.mouse_filter).is_not_equal(Control.MOUSE_FILTER_IGNORE)


func _assert_subtree_ignores_mouse(node: Node) -> void:
	for child in node.get_children():
		if child is Control:
			var control := child as Control
			assert_int(control.mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)
		_assert_subtree_ignores_mouse(child)
