extends SceneTree
## Drives the real game_root.tscn scene with synthesized real InputEvents
## (Input.parse_input_event()) at real button screen positions — the one
## thing headless gdUnit4 cannot check (it does not transport InputEvents at
## all in headless mode).
##
## Must run non-headless (this is a real Window, real rendering):
##   /Applications/Godot.app/Contents/MacOS/Godot --path . -s tools/playtest_real_clicks.gd
##
## COORDINATE SPACE, the part that broke the first attempt at this
## (team-lead's original scratch script fed raw Control.get_global_rect()
## coordinates straight into Input.parse_input_event() and saw zero effect
## after clicking DEAL): project.godot sets
## window/size/viewport_width=1080 + window/size/window_width_override=540
## (same for height, 1920/960) — a real 2x content-scale factor between the
## actual OS window's pixel space and the logical/canvas coordinate space
## every Control's get_global_rect() reports in.
##
## Control.get_global_rect() is always in the LOGICAL/canvas space.
## Input.parse_input_event() expects OS WINDOW pixel space (the same space
## a real mouse/touch event arrives in from the OS) — Godot's Window then
## applies its own stretch/canvas transform to map that into each
## Viewport's local space before dispatching to Controls, exactly the way
## it would for a real click on a real device. That transform is *why*
## clicking works correctly for real users regardless of window size; it
## only needs to be done manually here because parse_input_event() is a
## synthetic injection path that bypasses the normal OS-to-Window pixel
## delivery a real click already arrives through.
## Verified empirically: the exact same click that did nothing at logical
## coordinates registered correctly (state changed, presentation began)
## once scaled into window-pixel space — proving this was a test-harness
## coordinate bug, not a production input-routing bug.

func _init() -> void:
	var root_scene: Node = load("res://scenes/game_root.tscn").instantiate()
	get_root().add_child(root_scene)
	await process_frame
	await process_frame

	var bar := root_scene.find_child("ActionBar", true, false) as ActionBarView
	var presentation := root_scene.find_child("PresentationController", true, false) as PresentationController
	var ctrl_node := root_scene.find_child("RoundController", true, false) as RoundControllerNode
	var ctrl: RoundController = ctrl_node.controller

	print("BEFORE: state=%d buttons=%d legal=%s" % [ctrl.current_state, bar.button_count(), str(ctrl.legal_actions())])

	var deal_click_start_ms := Time.get_ticks_msec()
	_click_control(bar.deal_button())
	await _wait_for_presentation_to_settle(presentation)
	print("DEAL barrier held for %d ms (real click to real unblock)" % (Time.get_ticks_msec() - deal_click_start_ms))
	print(
		"AFTER DEAL click: state=%d player_total=%d dealer_child_count=%d legal=%s" % [
			ctrl.current_state,
			ctrl.snapshot().player_total,
			root_scene.find_child("DealerHandView", true, false).get_child_count(),
			str(ctrl.legal_actions()),
		]
	)

	if ctrl.current_state == RoundController.State.PLAYER_TURN:
		var stand_button: ActionButtonView = null
		for button in bar.buttons():
			if button.action == ActionButtonView.Action.STAND:
				stand_button = button
		var stand_click_start_ms := Time.get_ticks_msec()
		_click_control(stand_button)
		await _wait_for_presentation_to_settle(presentation)
		print("HOLE-REVEAL barrier held for %d ms (real click to real unblock)" % (Time.get_ticks_msec() - stand_click_start_ms))
		print("AFTER STAND click: state=%d" % ctrl.current_state)

	# Any further dealer hits are direct (non-presented) calls that
	# GameplayController already drove synchronously inside its
	# presentation_completed handler above — nothing more to click for
	# those, matching specs/003's registered-events scope.
	print("AFTER round resolves: state=%d has_outcome=%s outcome=%s legal=%s" % [
		ctrl.current_state, str(ctrl.has_outcome()),
		str(ctrl.outcome()) if ctrl.has_outcome() else "n/a",
		str(ctrl.legal_actions()),
	])

	var deal_button_after := bar.deal_button()
	if deal_button_after != null and ctrl.current_state == RoundController.State.ROUND_END:
		print("NEXT_ROUND button label=%d (0=DEAL,1=NEXT_ROUND)" % deal_button_after.label)
		_click_control(deal_button_after)
		for _i in 10: await process_frame
		print("AFTER NEXT_ROUND click: state=%d buttons=%d" % [ctrl.current_state, bar.button_count()])

	print("DONE — every state change above was driven by a real synthesized InputEventMouseButton at the button's actual on-screen position, not .pressed.emit().")
	quit(0)


## Converts a Control's logical/canvas-space center into the OS window's
## pixel space (see file header) and injects a real press+release there.
func _click_control(control: Control) -> void:
	var window := get_root()
	var scale: Vector2 = Vector2(window.size) / Vector2(window.content_scale_size)
	var window_space_pos: Vector2 = control.get_global_rect().get_center() * scale
	print(
		"  _click_control: window.size=%s content_scale_size=%s scale=%s rect=%s window_space_pos=%s" % [
			str(window.size), str(window.content_scale_size), str(scale),
			str(control.get_global_rect()), str(window_space_pos),
		]
	)
	for pressed in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = pressed
		ev.position = window_space_pos
		ev.global_position = window_space_pos
		Input.parse_input_event(ev)


## A real click starts a presentation with a real fallback_duration_ms wall
## clock (1200/1500ms) — wait long enough for that to fire for real instead
## of forcing it, since this script exists specifically to prove the real,
## un-shortcut path works end to end.
##
## Always waits at least a few frames FIRST, before checking
## active_token(): parse_input_event() queues the synthesized event for the
## engine's own input-processing pass rather than dispatching it inline, so
## checking the loop condition before any frame has elapsed sees whatever
## state existed *before* the click was even delivered to the Button —
## looks identical to "the click did nothing" while actually meaning "we
## never gave the click a chance to be processed at all".
func _wait_for_presentation_to_settle(presentation: PresentationController) -> void:
	for _i in 10:
		await process_frame
	var frames := 0
	while presentation.active_token() != "" and frames < 600:
		await process_frame
		frames += 1
