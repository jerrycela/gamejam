class_name BlackjackOutcome
extends RefCounted
## Canonical Blackjack round outcomes shared by core and presentation mapping.

enum Type {
	PLAYER_BLACKJACK,
	DEALER_BLACKJACK,
	PLAYER_WIN,
	DEALER_WIN,
	PLAYER_BUST,
	DEALER_BUST,
	PUSH,
	PLAYER_SURRENDER,
}


static func is_valid(outcome: int) -> bool:
	return outcome in Type.values()
