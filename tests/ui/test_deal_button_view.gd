class_name TestDealButtonView
extends GdUnitTestSuite
## Covers specs/003 L1-2 (this component's own .tscn) for BTN_DEAL
## (docs/12_FIGMA_COMPONENT_MANIFEST.md node 9:17, approved_version 1.1.0).
## One component serves two ActionBar states via the `label` export
## (Figma `Label` text property): DEAL for Betting, NEXT ROUND for RoundEnd.


func test_default_label_is_deal() -> void:
	var button := (load("res://ui/components/deal_button.tscn") as PackedScene).instantiate() as DealButtonView

	assert_str(button.text).is_equal("發牌")
	assert_object(button).is_not_null()
	button.free()


func test_next_round_label_switches_the_visible_text() -> void:
	var button := (load("res://ui/components/deal_button.tscn") as PackedScene).instantiate() as DealButtonView

	button.label = DealButtonView.DealLabel.NEXT_ROUND

	assert_str(button.text).is_equal("下一局")
	button.free()


func test_size_and_theme_come_entirely_from_theme_tokens_not_hardcoded_literals() -> void:
	var runner := scene_runner("res://scenes/game_root.tscn")
	# _ready() (which reads custom_minimum_size from Theme Tokens) only runs
	# once the node is inside a live tree; scene_runner guarantees that for
	# the ActionBar's dynamically-instantiated children too, but this
	# component is tested standalone here, so instantiate + add to a live
	# root to force _ready().
	var root: Node = runner.scene()
	var button := (load("res://ui/components/deal_button.tscn") as PackedScene).instantiate() as DealButtonView
	root.add_child(button)

	assert_float(button.custom_minimum_size.x).is_equal(320.0)
	assert_float(button.custom_minimum_size.y).is_equal(72.0)
	assert_that(button.theme_type_variation).is_equal(&"DealButton")

	button.queue_free()


func test_touch_height_meets_the_44px_minimum() -> void:
	var runner := scene_runner("res://scenes/game_root.tscn")
	var root: Node = runner.scene()
	var button := (load("res://ui/components/deal_button.tscn") as PackedScene).instantiate() as DealButtonView
	root.add_child(button)

	assert_float(button.custom_minimum_size.y).is_greater_equal(44.0)
	button.queue_free()
