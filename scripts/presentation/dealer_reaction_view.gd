class_name DealerReactionView
extends TextureRect
## L2 dealer reaction overlay (docs/01:56-72 "Dealer Reaction" — L2 gives
## feedback for what just happened). Renders one of the 6
## assets/textures/L2_DEALER_REACT_*_V001.png assets, chosen by
## GameplayController (this class holds no outcome-mapping logic itself,
## matching every other L1/L2 display component's "dumb view, logic lives
## in the controller" pattern).
##
## Hidden by default (visible = false in scenes/game_root.tscn) — only
## GameplayController toggles this, at ROUND_END (show) and the next
## DEAL/NEXT_ROUND press (hide). Anchored identically to DealerIdleView
## (same anchor_right/anchor_bottom/stretch_mode/expand_mode) so swapping
## between them never shifts the dealer's position — verified in
## tests/ui/test_l2_dealer_reaction.gd.


func show_texture(reaction_texture: Texture2D) -> void:
	texture = reaction_texture
	visible = true


func hide_reaction() -> void:
	visible = false
