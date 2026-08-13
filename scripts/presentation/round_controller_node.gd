class_name RoundControllerNode
extends Node
## Thin scene-tree adapter that hosts the RefCounted scripts/core/round_controller.gd
## instance so sibling Nodes (PresentationController) can reach it through
## normal scene-tree wiring, per specs/003's recommended GameRoot tree
## (docs/05_FIGMA_TO_GODOT.md:29-51 lists a "RoundController" node).
##
## scripts/core/round_controller.gd stays RefCounted on purpose (headless
## unit-testable, zero scene dependency) — this adapter does not reimplement
## or subclass it, it only carries a reference. All gameplay authority stays
## in the injected `controller`; this Node never calls any of its own
## game-rule logic.

var controller: RoundController = null


func setup(injected_controller: RoundController) -> void:
	controller = injected_controller
