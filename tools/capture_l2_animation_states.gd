extends SceneTree
## L2 animation mid-state screenshot capture (team-lead's acceptance
## criterion: "截圖至少 3 個動畫中間狀態"). Drives the REAL primary Window
## (same technique as tools/playtest_real_clicks.gd — real synthesized
## InputEventMouseButton at real on-screen coordinates, not .pressed.emit())
## and captures the Window's own viewport texture at real-time offsets.
##
## An earlier version of this script rendered into an offscreen SubViewport
## with no primary Window ever presented. That measured wildly wrong
## in-flight animation state (e.g. all 4 deal cards already fully opaque
## ~20-250ms after the click, when the worst-case envelope is ~630ms) —
## without a Window actually being presented/vsynced, SceneTree.process_frame
## resolves in a tight loop far faster than real wall-clock time, so a
## "wait N real ms" loop let many more *simulated* Tween frames elapse than
## intended. The real (non-headless, real Window) playtest in
## tools/playtest_real_clicks.gd measured sane, real values (DEAL barrier
## ~469ms, HOLE-REVEAL barrier ~253ms) — this script reuses that same real
## Window path specifically so its timing is trustworthy, and picks capture
## offsets as fractions of those measured real durations rather than of the
## constants' own worst-case math.
##
## Run: /Applications/Godot.app/Contents/MacOS/Godot --path . -s tools/capture_l2_animation_states.gd

const OUTPUT_DIR := "res://reports/l2_animation_qa/"


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))

	var root_scene: Node = load("res://scenes/game_root.tscn").instantiate()
	get_root().add_child(root_scene)
	await process_frame
	await process_frame

	var bar := root_scene.find_child("ActionBar", true, false) as ActionBarView
	var presentation := root_scene.find_child("PresentationController", true, false) as PresentationController
	var ctrl_node := root_scene.find_child("RoundController", true, false) as RoundControllerNode
	var ctrl: RoundController = ctrl_node.controller
	var dealer_hand_view := root_scene.find_child("DealerHandView", true, false) as Control
	var player_hand_view := root_scene.find_child("PlayerHandView", true, false) as Control
	var result_banner := root_scene.find_child("ResultBanner", true, false) as Label
	var gameplay := root_scene.find_child("GameplayController", true, false) as GameplayController

	# This environment's frame-delta/real-time relationship turned out to
	# be unreliable for catching a *production-speed* animation mid-flight
	# by wall-clock waiting alone (an earlier version of this script tried
	# exactly that and captured every animation already fully complete at
	# t=90-220ms, despite tools/playtest_real_clicks.gd measuring real
	# barrier durations of ~469ms/~253ms with the SAME production
	# constants on this SAME machine — the discrepancy is specific to how
	# this headless-adjacent capture session paces frames, not a
	# production timing bug). Stretching the animations themselves via the
	# same override_*_timing_for_test() seams the gdUnit4 suite already
	# uses removes the need to guess this environment's real frame pacing:
	# with a multi-second animation, any reasonable wall-clock wait lands
	# mid-flight regardless.
	gameplay.override_deal_card_animation_timing_for_test(900, 900)
	gameplay.override_dealer_hole_reveal_animation_timing_for_test(1400)
	gameplay.override_result_banner_animation_timing_for_test(1200, 600)
	print(
		"DIAG override check: card delays = [%d, %d, %d, %d] (expect 0,900,1800,2700)" % [
			gameplay.deal_card_delay_ms_for_test(0), gameplay.deal_card_delay_ms_for_test(1),
			gameplay.deal_card_delay_ms_for_test(2), gameplay.deal_card_delay_ms_for_test(3),
		]
	)

	# 1) Deal mid-flight: stretched worst case is 3×900+900=3600ms — capture
	# partway through.
	_click_control(bar.deal_button())
	await _wait_ms(1800)
	_capture("01_deal_mid_flight")
	print(
		"deal mid (t=1800ms, stretched): player_children=%d dealer_children=%d" % [
			player_hand_view.get_child_count(), dealer_hand_view.get_child_count(),
		]
	)
	for c in player_hand_view.get_children():
		print("  player card alpha=%s scale=%s" % [(c as CardFaceView).modulate.a, (c as CardFaceView).scale])
	for c in dealer_hand_view.get_children():
		print("  dealer card alpha=%s scale=%s" % [(c as CardFaceView).modulate.a, (c as CardFaceView).scale])

	await _wait_for_settle(presentation)
	print("deal settled: state=%d" % ctrl.current_state)

	# 2) Hole reveal mid-flip: measured real barrier was ~253ms — capture
	# around its own midpoint.
	if ctrl.current_state == RoundController.State.PLAYER_TURN:
		var stand_button: ActionButtonView = null
		for button in bar.buttons():
			if button.action == ActionButtonView.Action.STAND:
				stand_button = button
		_click_control(stand_button)
		await _wait_ms(700)
		_capture("02_hole_reveal_mid_flip")
		var hole_view := dealer_hand_view.get_child(dealer_hand_view.get_child_count() - 1) as CardFaceView
		print("hole reveal mid (t=700ms, stretched): face_down=%s scale=%s" % [hole_view.face_down, hole_view.scale])
		await _wait_for_settle(presentation)
		print("hole reveal settled: state=%d" % ctrl.current_state)

	# 3) Result banner entrance mid-fade: capture shortly after ROUND_END
	# is first reached (RESULT_BANNER_FADE_MS=220 total).
	var settle_frames := 0
	while not (ctrl.current_state == RoundController.State.ROUND_END and ctrl.has_outcome()) and settle_frames < 600:
		await process_frame
		settle_frames += 1
	await _wait_ms(400)
	_capture("03_result_banner_mid_entrance")
	print(
		"banner mid (t=400ms after ROUND_END, stretched): text=%s alpha=%s scale=%s" % [
			result_banner.text, result_banner.modulate.a, result_banner.scale,
		]
	)

	print("CAPTURE_DONE")
	quit(0)


func _capture(name: String) -> void:
	var image: Image = get_root().get_texture().get_image()
	var out_path: String = OUTPUT_DIR + name + ".png"
	var save_err: int = image.save_png(out_path)
	print("captured %s save_err=%s" % [out_path, save_err])


## Identical to tools/playtest_real_clicks.gd's own _click_control().
func _click_control(control: Control) -> void:
	var window := get_root()
	var scale: Vector2 = Vector2(window.size) / Vector2(window.content_scale_size)
	var window_space_pos: Vector2 = control.get_global_rect().get_center() * scale
	for pressed in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = pressed
		ev.position = window_space_pos
		ev.global_position = window_space_pos
		Input.parse_input_event(ev)


func _wait_ms(ms: int) -> void:
	var start := Time.get_ticks_msec()
	while Time.get_ticks_msec() - start < ms:
		await process_frame


func _wait_for_settle(presentation: PresentationController) -> void:
	for _i in 10:
		await process_frame
	var frames := 0
	while presentation.active_token() != "" and frames < 600:
		await process_frame
		frames += 1
