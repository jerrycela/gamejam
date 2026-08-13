class_name RoundEvent
extends RefCounted
## One typed core event projected toward presentation and UI consumers.

const ROUND_STARTED: StringName = &"ROUND_STARTED"
const INITIAL_CARD_DEALT: StringName = &"INITIAL_CARD_DEALT"
const DEALER_PEEK_COMPLETED: StringName = &"DEALER_PEEK_COMPLETED"
const DEALER_HOLE_CARD_REVEALED: StringName = &"DEALER_HOLE_CARD_REVEALED"
const PLAYER_CARD_DEALT: StringName = &"PLAYER_CARD_DEALT"
const DEALER_CARD_DEALT: StringName = &"DEALER_CARD_DEALT"

const HAND_PLAYER: StringName = &"PLAYER"
const HAND_DEALER: StringName = &"DEALER"

var event_id: StringName
var round_id: String
var sequence_no: int
var hand_owner: StringName
var card: Card
var face_up: bool


func _init(
	core_event_id: StringName,
	round_identifier: String,
	sequence: int,
	owner: StringName = &"",
	event_card: Card = null,
	is_face_up: bool = false,
) -> void:
	event_id = core_event_id
	round_id = round_identifier
	sequence_no = sequence
	hand_owner = owner
	card = event_card
	face_up = is_face_up
