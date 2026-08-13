class_name TestL15LayoutDefects
extends GdUnitTestSuite
## Covers the three L1-5 visual defects viewport-qa's real screenshots
## surfaced (reports/viewport_qa/*.png + capture_report.txt) that the
## existing rect-only assertions in test_l1_viewport_responsiveness.gd
## cannot catch — those check L1 components against each other; all three
## defects here are between L1 and L3, or between an L3 texture and the
## canvas, which no L1-vs-L1 rect comparison can see:
##
## 1. HandTotal (ValueDisplayView) text overflowed past its allocated
##    BottomCluster row and visually overlapped ChipsAndBet/PlayerHandView,
##    because ValueDisplayView extends Control (not Container) and never
##    reported a minimum size for its VBoxContainer child.
## 2. BackgroundView's stretch_mode left ~40% of the canvas as bare grey
##    clear-color on non-matching aspect ratios (texture only 720x1280,
##    stretched with STRETCH_KEEP instead of covering the canvas).
## 3. DealerIdleView was anchored full-rect + STRETCH_KEEP_ASPECT_CENTERED,
##    which scales the dealer to fill the *entire* viewport height instead
##    of just the upper region above the room background's table edge.
## 4. (Found after fixing #3) DealerHandView's two cards stayed pinned to
##    the very top of TableUI's Layout, which used to only cover the hair
##    bun when the dealer filled the whole screen — once #3 confined the
##    dealer to the upper 53.7%, that same fixed top position landed the
##    cards squarely on the dealer's eyes instead (docs/01 §1: Dealer is
##    the primary visual focus; L2's six reaction assets are all facial and
##    would never be seen if the face stays covered mid-round).

const VIEWPORT_SIZES: Array[Vector2i] = [
	Vector2i(1080, 1920),
	Vector2i(1080, 2400),
	Vector2i(1200, 1600),
]


## Same pinning technique as test_l1_viewport_responsiveness.gd's
## _apply_viewport_size — duplicated locally rather than shared because that
## file doesn't expose it publicly and this is a small, self-contained helper.
func _apply_viewport_size(viewport: Viewport, size: Vector2i) -> void:
	var window := viewport as Window
	if window != null:
		window.content_scale_size = size
		window.size = size


## Defect #1 (component level): a bare Control never propagates a child's
## minimum size to its own layout unless it explicitly reports one.
func test_value_display_view_reports_a_minimum_size_that_fits_both_labels() -> void:
	var runner := scene_runner("res://ui/components/value_display.tscn")
	var view := runner.scene() as ValueDisplayView
	await runner.simulate_frames(1)

	var min_size := view.get_combined_minimum_size()

	# Font sizes are Theme Tokens (value_total_font_size=68,
	# value_total_state_font_size=26 — enlarged from Figma's original 56/18
	# for real-device readability, see tests/ui/test_lsbj_theme_tokens.gd's
	# font-size deviation note) — two stacked single-line Labels need at
	# least that much combined height (plus the VBoxContainer's own
	# separation), not the (0, 0) a bare Control silently reports by default.
	assert_float(min_size.y).is_greater_equal(68.0 + 26.0)
	assert_float(min_size.x).is_greater(0.0)


## Defect #1 (integration level): with the minimum size now reported,
## BottomCluster's VBoxContainer must actually give HandTotal enough room
## that it stops visually overlapping its siblings, at all three reference
## viewport sizes — not just the one the bug happened to be caught in.
func test_hand_total_does_not_overlap_its_bottom_cluster_siblings_at_any_reference_size() -> void:
	var runner := scene_runner("res://scenes/game_root.tscn")
	var root: Node = runner.scene()
	var table_ui := root.get_node("L1Root/TableUI") as Control
	var hand_total := table_ui.find_child("HandTotal", true, false) as Control
	var chips_and_bet := table_ui.find_child("ChipsAndBet", true, false) as Control
	var player_hand_view := table_ui.find_child("PlayerHandView", true, false) as Control
	var viewport := root.get_viewport()

	for size: Vector2i in VIEWPORT_SIZES:
		_apply_viewport_size(viewport, size)
		await runner.simulate_frames(2)

		var hand_total_rect := hand_total.get_global_rect()
		var chips_rect := chips_and_bet.get_global_rect()
		var player_rect := player_hand_view.get_global_rect()

		assert_bool(hand_total_rect.intersects(chips_rect)).is_false()
		assert_bool(hand_total_rect.intersects(player_rect)).is_false()


## Defect #2: STRETCH_KEEP_ASPECT_COVERED is defined to scale by
## max(target_w/src_w, target_h/src_h) — by construction that always covers
## the assigned rect fully (the larger axis matches exactly, the other
## overflows and gets center-cropped), so asserting the enum value is a
## direct, non-redundant proof of "no bare canvas can show through" — it is
## not re-deriving the same computation the production code performs.
func test_background_view_uses_a_stretch_mode_that_always_covers_the_canvas() -> void:
	var runner := scene_runner("res://scenes/game_root.tscn")
	var root: Node = runner.scene()
	var background_view := root.get_node("L3Root/BackgroundView") as TextureRect

	assert_int(background_view.stretch_mode).is_equal(TextureRect.STRETCH_KEEP_ASPECT_COVERED)


## Defect #3: DealerIdleView must not be anchored to the full viewport rect
## (that is exactly what scaled the dealer to fill the whole screen height).
## It should be confined to the upper region above the room background's
## table edge (~53.7% of canvas height, docs/06 §5b's approved zoning),
## expressed as an anchor fraction so it holds across all three reference
## aspect ratios rather than a fixed pixel height that only fits one.
func test_dealer_idle_view_is_anchored_to_the_upper_region_not_the_full_viewport() -> void:
	var runner := scene_runner("res://scenes/game_root.tscn")
	var root: Node = runner.scene()
	var dealer_idle_view := root.get_node("L3Root/DealerIdleView") as TextureRect

	assert_float(dealer_idle_view.anchor_top).is_equal(0.0)
	assert_float(dealer_idle_view.anchor_bottom).is_less(1.0)
	assert_float(dealer_idle_view.anchor_bottom).is_equal_approx(0.537, 0.01)


## Defect #3 (integration level): with a shorter anchored box, the dealer's
## rendered rect must end well above the very bottom of the canvas at every
## reference size — not just be "less than 1.0" in the abstract.
func test_dealer_idle_view_rect_ends_above_the_table_edge_region_at_every_reference_size() -> void:
	var runner := scene_runner("res://scenes/game_root.tscn")
	var root: Node = runner.scene()
	var dealer_idle_view := root.get_node("L3Root/DealerIdleView") as Control
	var viewport := root.get_viewport()

	for size: Vector2i in VIEWPORT_SIZES:
		_apply_viewport_size(viewport, size)
		await runner.simulate_frames(2)

		var dealer_rect := dealer_idle_view.get_global_rect()
		# Comfortably above full-height (was previously == size.y exactly);
		# allow slack above/below the nominal 53.7% for anchor rounding.
		assert_float(dealer_rect.end.y).is_less(size.y * 0.7)


## Defect #4: DealerHandView must never land inside the dealer's own face —
## checked against a vertical band *within DealerIdleView's own rendered
## rect* (not the whole canvas), since defect #3's fix means that rect no
## longer equals the canvas. 15%-45% of the rendered image's height is a
## judgment call, not a pixel-measured crop: on this portrait-style bust
## (hair bun -> forehead/eyes -> nose/mouth -> chin -> collar), that band
## brackets "somewhere between the eyebrows and the chin" — wide enough to
## catch "a card sits on the eyes" (the actual defect) without also
## flagging cards that merely graze the hairline or collar, which
## docs/01 §1's "Dealer is the primary visual focus" requirement doesn't
## need to forbid.
func test_dealer_hand_view_does_not_overlap_the_dealers_face_region_at_any_reference_size() -> void:
	var runner := scene_runner("res://scenes/game_root.tscn")
	var root: Node = runner.scene()
	var table_ui := root.get_node("L1Root/TableUI") as Control
	var dealer_hand_view := table_ui.find_child("DealerHandView", true, false) as Control
	var dealer_idle_view := root.get_node("L3Root/DealerIdleView") as Control
	var viewport := root.get_viewport()

	for size: Vector2i in VIEWPORT_SIZES:
		_apply_viewport_size(viewport, size)
		await runner.simulate_frames(2)

		var dealer_idle_rect := dealer_idle_view.get_global_rect()
		var face_top := dealer_idle_rect.position.y + dealer_idle_rect.size.y * 0.15
		var face_bottom := dealer_idle_rect.position.y + dealer_idle_rect.size.y * 0.45
		var face_rect := Rect2(
			dealer_idle_rect.position.x,
			face_top,
			dealer_idle_rect.size.x,
			face_bottom - face_top,
		)

		var hand_rect := dealer_hand_view.get_global_rect()
		assert_bool(hand_rect.intersects(face_rect)).is_false()
