class_name CardFaceView
extends PanelContainer
## Native Godot control for CARD_FACE (Figma node 11:84).
##
## Suit and Orientation are the Figma variant axes; Rank is the Figma TEXT
## property. Rank and suit glyphs are rendered by Label nodes (never baked
## into a texture). Suit selects color (card/suit-red or card/suit-black) and
## glyph (club/diamond/heart/spade); Orientation selects layout size. All
## colors, radii, spacing and font sizes come from res://ui/theme/lsbj_theme.tres
## (Tokens type + CardFacePanel type variation) — no hardcoded design values.

enum Suit {
	CLUB,
	DIAMOND,
	HEART,
	SPADE,
}

## Renamed away from the built-in @GlobalScope.Orientation enum name to avoid
## a static-type ambiguity error when GDScript resolves the exported property.
enum CardOrientation {
	UPRIGHT,
	LANDSCAPE,
}

const SUIT_GLYPHS := {
	Suit.CLUB: "♣",
	Suit.DIAMOND: "♦",
	Suit.HEART: "♥",
	Suit.SPADE: "♠",
}

const RED_SUITS := [Suit.DIAMOND, Suit.HEART]

@export var suit: Suit = Suit.CLUB:
	set(value):
		suit = value
		_refresh()

@export var orientation: CardOrientation = CardOrientation.UPRIGHT:
	set(value):
		orientation = value
		_refresh()

@export var rank: String = "A":
	set(value):
		rank = value
		_refresh()

## Hidden-card rendering for a dealer hole card the core has not (yet)
## revealed. There is no dedicated CARD_BACK Figma component to switch to
## (docs/12: still PENDING_CREATE) — per team-lead's instruction, face_down
## just toggles a plain L1_CARD_BACK_V001 texture over this same component
## rather than blocking on building a new one. Whatever `rank`/`suit` this
## node holds while face_down is irrelevant to a real caller: the presentation
## layer never has the hidden card's real identity in the first place
## (RoundController.snapshot()'s secrecy boundary), so it is never set to
## anything meaningful here.
@export var face_down: bool = false:
	set(value):
		face_down = value
		_refresh()

@onready var _rank_label: Label = $VBoxContainer/CornerBox/RankLabel
@onready var _corner_suit_label: Label = $VBoxContainer/CornerBox/CornerSuitLabel
@onready var _center_suit_label: Label = $VBoxContainer/CenterBox/CenterSuitLabel
@onready var _vbox: VBoxContainer = $VBoxContainer
@onready var _card_back: TextureRect = $CardBackTexture


func _ready() -> void:
	theme_type_variation = &"CardFacePanel"
	_rank_label.add_theme_font_size_override(
		"font_size", get_theme_constant("card_rank_font_size", "Tokens")
	)
	_corner_suit_label.add_theme_font_size_override(
		"font_size", get_theme_constant("card_corner_suit_font_size", "Tokens")
	)
	_center_suit_label.add_theme_font_size_override(
		"font_size", get_theme_constant("card_center_suit_font_size", "Tokens")
	)
	_refresh()


func _refresh() -> void:
	custom_minimum_size = _size_for_orientation()
	if not is_node_ready():
		return

	_vbox.visible = not face_down
	_card_back.visible = face_down
	if face_down:
		return

	var glyph: String = SUIT_GLYPHS.get(suit, "")
	var suit_color: Color = get_theme_color(
		"card_suit_red" if suit in RED_SUITS else "card_suit_black", "Tokens"
	)

	_rank_label.text = rank
	_rank_label.add_theme_color_override("font_color", suit_color)
	_corner_suit_label.text = glyph
	_corner_suit_label.add_theme_color_override("font_color", suit_color)
	_center_suit_label.text = glyph
	_center_suit_label.add_theme_color_override("font_color", suit_color)


func _size_for_orientation() -> Vector2:
	if orientation == CardOrientation.LANDSCAPE:
		return Vector2(
			get_theme_constant("card_landscape_width", "Tokens"),
			get_theme_constant("card_landscape_height", "Tokens"),
		)
	return Vector2(
		get_theme_constant("card_upright_width", "Tokens"),
		get_theme_constant("card_upright_height", "Tokens"),
	)
