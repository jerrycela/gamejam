class_name TestLsbjThemeTokens
extends GdUnitTestSuite
## Loads res://ui/theme/lsbj_theme.tres directly and checks it against literal
## values pulled from Figma (mcp__claude_ai_Figma__get_variable_defs on nodes
## 5:2 and 11:84), independent of any node that merely echoes back whatever
## the Theme happens to contain. This is the actual proof that the Figma
## token -> Godot Theme mapping landed, not just that a getter round-trips.
##
## FONT-SIZE DEVIATION FROM FIGMA (2026-08-13, user-driven, real-device
## readability): `action_button_font_size`, `value_total_font_size`,
## `value_total_state_font_size`, and Theme.default_font_size are asserted
## against ENLARGED values (30/68/26/28), not the original Figma tokens
## (22/56/18/16) — a real person looked at the rendered game on a
## 1080-wide canvas and reported the text too small to read at arm's
## length. Per AGENTS.md:61's source-of-truth order, an approved spec
## normally outranks other sources, but a direct user instruction about
## their own device's readability outranks the spec here — this is a
## deliberate, recorded deviation, not drift: Figma's own tokens have NOT
## been updated to match (team-lead's explicit instruction — Figma will be
## reconciled separately). If a future audit finds these values don't
## match Figma, that is expected and already known, not a new bug.
## card_rank_font_size/card_corner_suit_font_size/card_center_suit_font_size
## were deliberately left untouched — not named in the readability
## complaint, and CARD_FACE's 136x190 footprint has little headroom before
## rank/suit glyphs would start clipping.

const THEME_PATH := "res://ui/theme/lsbj_theme.tres"


func test_tokens_colors_match_figma_hex_values() -> void:
	var theme: Theme = load(THEME_PATH)

	assert_str(theme.get_color("action_primary", "Tokens").to_html(false)).is_equal("f5b942")
	assert_str(theme.get_color("action_primary_pressed", "Tokens").to_html(false)).is_equal("c4871b")
	assert_str(theme.get_color("action_disabled", "Tokens").to_html(false)).is_equal("6f8078")
	assert_str(theme.get_color("action_danger", "Tokens").to_html(false)).is_equal("e05a5a")
	assert_str(theme.get_color("action_danger_pressed", "Tokens").to_html(false)).is_equal("a83c43")
	assert_str(theme.get_color("focus", "Tokens").to_html(false)).is_equal("46e6d2")
	assert_str(theme.get_color("border_subtle", "Tokens").to_html(false)).is_equal("115443")
	assert_str(theme.get_color("text_on_action", "Tokens").to_html(false)).is_equal("07110e")
	assert_str(theme.get_color("text_primary", "Tokens").to_html(false)).is_equal("ffffff")
	assert_str(theme.get_color("text_on_danger", "Tokens").to_html(false)).is_equal("ffffff")
	assert_str(theme.get_color("bg_panel", "Tokens").to_html(false)).is_equal("0b1d18")
	assert_str(theme.get_color("card_face", "Tokens").to_html(false)).is_equal("ffffff")
	assert_str(theme.get_color("card_border", "Tokens").to_html(false)).is_equal("aebbb5")
	assert_str(theme.get_color("card_suit_red", "Tokens").to_html(false)).is_equal("e05a5a")
	assert_str(theme.get_color("card_suit_black", "Tokens").to_html(false)).is_equal("07110e")


func test_tokens_constants_match_figma_dimension_values() -> void:
	var theme: Theme = load(THEME_PATH)

	assert_int(theme.get_constant("space_3", "Tokens")).is_equal(12)
	assert_int(theme.get_constant("space_4", "Tokens")).is_equal(16)
	assert_int(theme.get_constant("space_6", "Tokens")).is_equal(24)
	assert_int(theme.get_constant("radius_medium", "Tokens")).is_equal(16)
	assert_int(theme.get_constant("radius_large", "Tokens")).is_equal(28)
	assert_int(theme.get_constant("stroke_thin", "Tokens")).is_equal(1)
	assert_int(theme.get_constant("stroke_regular", "Tokens")).is_equal(2)
	assert_int(theme.get_constant("action_button_font_size", "Tokens")).is_equal(30)
	assert_int(theme.get_constant("action_button_width", "Tokens")).is_equal(210)
	assert_int(theme.get_constant("action_button_height", "Tokens")).is_equal(64)
	assert_int(theme.get_constant("card_rank_font_size", "Tokens")).is_equal(30)
	assert_int(theme.get_constant("card_corner_suit_font_size", "Tokens")).is_equal(20)
	assert_int(theme.get_constant("card_center_suit_font_size", "Tokens")).is_equal(58)
	assert_int(theme.get_constant("card_upright_width", "Tokens")).is_equal(136)
	assert_int(theme.get_constant("card_upright_height", "Tokens")).is_equal(190)
	assert_int(theme.get_constant("card_landscape_width", "Tokens")).is_equal(190)
	assert_int(theme.get_constant("card_landscape_height", "Tokens")).is_equal(136)
	# Enlarged from Figma's 56/18 — see class doc's font-size deviation note.
	assert_int(theme.get_constant("value_total_font_size", "Tokens")).is_equal(68)
	assert_int(theme.get_constant("value_total_state_font_size", "Tokens")).is_equal(26)


func test_default_font_size_is_enlarged_for_real_device_readability() -> void:
	# Drives ChipsDisplay/BetControl/ResultBanner (plain Labels with no
	# per-node override) and PresentationController's fallback visual Label
	# — enlarged from Figma's 16, see class doc's font-size deviation note.
	var theme: Theme = load(THEME_PATH)

	assert_int(theme.default_font_size).is_equal(28)


## CJK font wiring (2026-08-13, user-provided asset): Traditional Chinese
## display text (要牌/停牌/發牌/籌碼/etc.) renders as tofu boxes under
## Godot's engine-bundled default font, which has no CJK glyphs — this is
## the actual asset that closes that gap, not a code fix. Source Han Sans
## TC (Adobe, OFL-1.1, assets/fonts/LICENSE.txt) — Regular is the Theme's
## global default_font (covers every plain Label with no override:
## ChipsDisplay/BetControl/ResultBanner/state label/fallback visual); Bold
## goes on the button label type variations and the HandTotal number
## specifically, per team-lead's instruction on which text is "needs
## bold" (button labels, and the large total number — not the smaller
## HARD/SOFT/BUST state label under it).
func test_default_font_is_source_han_sans_tc_regular() -> void:
	var theme: Theme = load(THEME_PATH)

	assert_bool(theme.has_default_font()).is_true()
	var font := theme.default_font
	assert_object(font).is_not_null()
	assert_str(font.resource_path).is_equal("res://assets/fonts/SourceHanSansTC-Regular.otf")


func test_button_and_value_total_type_variations_use_source_han_sans_tc_bold() -> void:
	var theme: Theme = load(THEME_PATH)

	for type_name: String in ["PrimaryActionButton", "DangerActionButton", "DealButton", "ValueTotalLabel"]:
		var font: Font = theme.get_font("font", type_name)
		assert_object(font).is_not_null()
		assert_str(font.resource_path).is_equal("res://assets/fonts/SourceHanSansTC-Bold.otf")


func test_primary_action_button_type_variation_is_registered_on_button() -> void:
	var theme: Theme = load(THEME_PATH)

	assert_bool(theme.get_type_variation_base(&"PrimaryActionButton") == &"Button").is_true()
	assert_bool(theme.get_type_variation_base(&"DangerActionButton") == &"Button").is_true()
	assert_bool(theme.get_type_variation_base(&"CardFacePanel") == &"PanelContainer").is_true()


func test_primary_action_button_stylebox_and_font_color_match_figma() -> void:
	var theme: Theme = load(THEME_PATH)

	var normal := theme.get_stylebox("normal", "PrimaryActionButton") as StyleBoxFlat
	assert_object(normal).is_not_null()
	assert_str(normal.bg_color.to_html(false)).is_equal("f5b942")
	assert_str(normal.border_color.to_html(false)).is_equal("115443")
	assert_int(normal.corner_radius_top_left).is_equal(16)
	assert_int(normal.border_width_left).is_equal(2)
	assert_str(theme.get_color("font_color", "PrimaryActionButton").to_html(false)).is_equal("07110e")

	var danger_normal := theme.get_stylebox("normal", "DangerActionButton") as StyleBoxFlat
	assert_object(danger_normal).is_not_null()
	assert_str(danger_normal.bg_color.to_html(false)).is_equal("e05a5a")
	assert_str(theme.get_color("font_color", "DangerActionButton").to_html(false)).is_equal("ffffff")


func test_card_face_panel_stylebox_matches_figma() -> void:
	var theme: Theme = load(THEME_PATH)

	var panel := theme.get_stylebox("panel", "CardFacePanel") as StyleBoxFlat
	assert_object(panel).is_not_null()
	assert_str(panel.bg_color.to_html(false)).is_equal("ffffff")
	assert_str(panel.border_color.to_html(false)).is_equal("aebbb5")
	assert_int(panel.border_width_left).is_equal(1)
	assert_int(panel.corner_radius_top_left).is_equal(16)
