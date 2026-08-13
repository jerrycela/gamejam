class_name DealButtonView
extends Button
## Native Godot control for BTN_DEAL (Figma node 9:17,
## docs/12_FIGMA_COMPONENT_MANIFEST.md, approved_version 1.1.0).
##
## One component serves two ActionBar states — Betting -> DEAL, RoundEnd ->
## NEXT ROUND — via the `label` export, matching BTN_DEAL 1.1.0's `Label`
## text property (default "DEAL", other legal value "NEXT ROUND"). This is
## exactly the change that moved it from 1.0.0 to 1.1.0 in Figma: one
## component, two labels, instead of two components.
##
## State (Default/Pressed/Disabled/Focus) reuses the same visual family as
## BTN_ACTION's PrimaryActionButton — the manifest's Visual Approval entry
## records DEAL as one of the "其餘走 action/primary 金" buttons (SURRENDER
## is the only danger/red one), so this does not need its own StyleBoxFlat
## set, only its own Theme type name (DealButton) sized to BTN_DEAL's actual
## 320x72 Figma measurement via Tokens/constants — no color/radius/spacing/
## font literal is hardcoded on the node itself (docs/05_FIGMA_TO_GODOT.md §5
## Theme First).

enum DealLabel {
	DEAL,
	NEXT_ROUND,
}

const LABEL_TEXT := {
	DealLabel.DEAL: "發牌",
	DealLabel.NEXT_ROUND: "下一局",
}

@export var label: DealLabel = DealLabel.DEAL:
	set(value):
		label = value
		_refresh()


func _ready() -> void:
	theme_type_variation = &"DealButton"
	custom_minimum_size = Vector2(
		get_theme_constant("deal_button_width", "Tokens"),
		get_theme_constant("deal_button_height", "Tokens"),
	)
	_refresh()


func _refresh() -> void:
	text = LABEL_TEXT.get(label, "發牌")
