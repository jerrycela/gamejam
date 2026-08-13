extends Node
## L1-5 viewport QA capture harness (specs/003_LAYERED_PRESENTATION_PIPELINE.md:138).
##
## Renders res://scenes/game_root.tscn into a SubViewport sized exactly to
## each of the three specs/003-decided viewport sizes, captures a PNG per
## size, and writes a plain-text measurement report of the acceptance-facing
## rects (ActionBar / DealerHandView / PlayerHandView / CenterSpacer).
##
## Why SubViewport instead of resizing the OS Window (first attempt, kept
## here in git history/PR discussion, not in this file): resizing the real
## Window to 1080x2400 got silently clamped by macOS to whatever the local
## screen's usable height is (measured 1080x2194 on this machine's screen —
## a MacBook display is not physically tall enough at 1:1 to host a
## 2400px-tall window). A SubViewport renders into an offscreen buffer of
## the exact size requested regardless of physical screen/window
## dimensions, so the captured PNG's pixel size == the requested spec size
## exactly. This also sidesteps project.godot's window/stretch/aspect
## "expand" entirely: a SubViewport is not the base Window, so Controls
## inside it anchor 1:1 against the SubViewport's own size — which is
## exactly "what does layout X look like when the canvas is WxH", the
## question L1-5 is asking.
##
## Still must be run non-headless: headless mode has no real GPU render
## context at all (dummy rendering driver), so SubViewport textures would
## come back black/empty. See run instructions in the agent's final report.

const GAME_ROOT_SCENE: PackedScene = preload("res://scenes/game_root.tscn")

const OUTPUT_DIR := "res://reports/viewport_qa/"

const TARGETS: Array[Dictionary] = [
	{"name": "reference_1080x1920", "size": Vector2i(1080, 1920)},
	{"name": "narrow_portrait_1080x2400", "size": Vector2i(1080, 2400)},
	{"name": "wide_portrait_1200x1600", "size": Vector2i(1200, 1600)},
]


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))

	var sub_viewport: SubViewport = SubViewport.new()
	sub_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	sub_viewport.transparent_bg = false
	add_child(sub_viewport)

	var game_root: Node = GAME_ROOT_SCENE.instantiate()
	sub_viewport.add_child(game_root)

	var table_ui: Control = game_root.get_node("L1Root/TableUI") as Control
	var action_bar: Control = table_ui.find_child("ActionBar", true, false) as Control
	var dealer_hand_view: Control = table_ui.find_child("DealerHandView", true, false) as Control
	var player_hand_view: Control = table_ui.find_child("PlayerHandView", true, false) as Control
	var center_spacer: Control = table_ui.find_child("CenterSpacer", true, false) as Control

	var report_lines: PackedStringArray = []
	report_lines.append("L1-5 viewport capture report")
	report_lines.append("Method: SubViewport sized exactly to each target (decoupled from the physical OS window/screen). Reported sizes below are canvas sizes = SubViewport.size = captured texture size.")
	report_lines.append("")

	for target: Dictionary in TARGETS:
		var target_name: String = target["name"]
		var target_size: Vector2i = target["size"]

		sub_viewport.size = target_size
		await get_tree().process_frame
		await get_tree().process_frame
		await get_tree().process_frame

		var image: Image = sub_viewport.get_texture().get_image()
		var out_path: String = OUTPUT_DIR + target_name + ".png"
		var save_err: int = image.save_png(out_path)

		var texture_size: Vector2i = image.get_size()

		var bar_rect: Rect2 = action_bar.get_global_rect()
		var dealer_rect: Rect2 = dealer_hand_view.get_global_rect()
		var player_rect: Rect2 = player_hand_view.get_global_rect()
		var center_rect: Rect2 = center_spacer.get_global_rect()

		report_lines.append("=== %s ===" % target_name)
		report_lines.append("requested_size=%s sub_viewport.size=%s texture_size=%s save_err=%s" % [target_size, sub_viewport.size, texture_size, save_err])
		report_lines.append("ActionBar rect=%s in_bounds=%s" % [bar_rect, (bar_rect.position.x >= 0.0 and bar_rect.position.y >= 0.0 and bar_rect.end.x <= target_size.x and bar_rect.end.y <= target_size.y)])
		report_lines.append("DealerHandView rect=%s in_bounds=%s" % [dealer_rect, (dealer_rect.position.x >= 0.0 and dealer_rect.position.y >= 0.0 and dealer_rect.end.x <= target_size.x and dealer_rect.end.y <= target_size.y)])
		report_lines.append("PlayerHandView rect=%s in_bounds=%s" % [player_rect, (player_rect.position.x >= 0.0 and player_rect.position.y >= 0.0 and player_rect.end.x <= target_size.x and player_rect.end.y <= target_size.y)])
		report_lines.append("CenterSpacer(L3 reserved area) rect=%s visible_height=%s" % [center_rect, center_rect.size.y])
		report_lines.append("ActionBar_overlaps_PlayerHandView=%s" % bar_rect.intersects(player_rect))
		report_lines.append("ActionBar_overlaps_DealerHandView=%s" % bar_rect.intersects(dealer_rect))
		report_lines.append("PlayerHandView_overlaps_DealerHandView=%s" % player_rect.intersects(dealer_rect))
		report_lines.append("")

	var report_path: String = OUTPUT_DIR + "capture_report.txt"
	var f: FileAccess = FileAccess.open(report_path, FileAccess.WRITE)
	for line: String in report_lines:
		f.store_line(line)
	f.close()

	print("CAPTURE_DONE")
	for line: String in report_lines:
		print(line)

	get_tree().quit()
