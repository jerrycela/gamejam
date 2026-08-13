class_name TestRoundControllerNode
extends GdUnitTestSuite
## Covers the Node adapter that hosts the RefCounted scripts/core/RoundController
## inside the scene tree (specs/003 L2, GameRoot's "RoundController" node).
## scripts/core/round_controller.gd stays RefCounted and untouched; this
## adapter only carries the reference so sibling Nodes (PresentationController)
## can reach it through normal scene-tree wiring.


func _card(rank: int, suit: int) -> Card:
	return Card.new(rank, suit)


func test_adapter_starts_with_no_controller_until_setup_is_called() -> void:
	var node: RoundControllerNode = auto_free(RoundControllerNode.new())
	add_child(node)

	assert_object(node.controller).is_null()


func test_setup_wires_the_injected_refcounted_controller_without_wrapping_it() -> void:
	var node: RoundControllerNode = auto_free(RoundControllerNode.new())
	add_child(node)

	var ledger := BetLedger.new()
	var shoe := DeckShoe.create_injected([], "shoe-adapter")
	var controller := RoundController.create_injected(shoe, ledger)

	node.setup(controller)

	assert_object(node.controller).is_same(controller)
	assert_int(node.controller.current_state).is_equal(RoundController.State.BETTING)


func test_adapter_is_a_plain_node_not_a_refcounted_reimplementation() -> void:
	var node: RoundControllerNode = auto_free(RoundControllerNode.new())

	assert_bool(node is Node).is_true()
