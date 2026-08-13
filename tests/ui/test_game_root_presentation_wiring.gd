class_name TestGameRootPresentationWiring
extends GdUnitTestSuite
## Proves the L2 wiring actually works inside the real GameRoot scene, not
## just against synthetic controllers/ActionBars built in
## test_presentation_controller.gd. Loads scenes/game_root.tscn as-is, wires
## its own "RoundController" and "PresentationController" nodes via setup()
## (the scene ships with no production bootstrap — see report), and runs one
## full deal -> blocked -> completed -> reflected cycle against the scene's
## real ActionBar buttons.


func _card(rank: int, suit: int) -> Card:
	return Card.new(rank, suit)


func test_deal_presentation_blocks_and_then_reflects_legal_actions_on_the_real_action_bar() -> void:
	var runner := scene_runner("res://scenes/game_root.tscn")
	var root: Node = runner.scene()

	var round_controller_node := root.get_node("RoundController") as RoundControllerNode
	var presentation_controller := root.get_node("PresentationController") as PresentationController
	var table_ui := root.get_node("L1Root/TableUI") as Node
	var action_bar := table_ui.find_child("ActionBar", true, false) as Control
	var hit_button := table_ui.find_child("HitButton", true, false) as ActionButtonView

	var cards: Array[Card] = [
		_card(Card.Rank.EIGHT, Card.Suit.HEARTS),
		_card(Card.Rank.SEVEN, Card.Suit.SPADES),
		_card(Card.Rank.NINE, Card.Suit.CLUBS),
		_card(Card.Rank.SIX, Card.Suit.DIAMONDS),
	]
	var ledger := BetLedger.new()
	var shoe := DeckShoe.create_injected(cards, "shoe-game-root-wiring")
	var controller := RoundController.create_injected(shoe, ledger)
	round_controller_node.setup(controller)
	presentation_controller.setup(controller, action_bar)
	assert_bool(controller.place_bet(100)).is_true()

	var started := presentation_controller.begin_deal_presentation("round-game-root-wiring")

	assert_bool(started).is_true()
	assert_bool(hit_button.disabled).is_true()

	var finished := presentation_controller.notify_presentation_finished(
		presentation_controller.active_token()
	)

	assert_bool(finished).is_true()
	# HIT is legal after a non-natural deal lands in PLAYER_TURN — the real
	# scene button must reflect RoundController.legal_actions(), read fresh,
	# not a PresentationController guess.
	assert_bool(hit_button.disabled).is_equal(
		not controller.legal_actions().has(RoundController.ACTION_HIT)
	)
	assert_bool(hit_button.disabled).is_false()


func test_round_controller_node_and_presentation_controller_exist_unwired_by_default() -> void:
	# Documents the current boundary honestly: GameRoot ships with the two
	# adapter nodes present and scripted, but nothing bootstraps a production
	# RoundController into them — see report "runtime bootstrap absent".
	var runner := scene_runner("res://scenes/game_root.tscn")
	var root: Node = runner.scene()

	var round_controller_node := root.get_node("RoundController") as RoundControllerNode
	assert_object(round_controller_node.controller).is_null()
