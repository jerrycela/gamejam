# Deterministic DeckShoe Design

**Status:** `APPROVED BY EXISTING SPECS`

**Sources:** `specs/000_HOUSE_RULES_DECISION.md` §A, `specs/001_FIRST_VERTICAL_SLICE.md` Task 2, and `specs/002_CORE_TRANSACTION_AND_DEAL_FLOW.md` §5.

## Purpose

`DeckShoe` is the single authority for building, shuffling and drawing cards from one Blackjack shoe. It is pure core logic and has no `Node`, SceneTree, UI, presentation or bankroll dependency.

## Chosen Shape

Use a typed `RefCounted` with two explicit factories:

```gdscript
DeckShoe.create_injected(cards, shoe_id)
DeckShoe.create_runtime(shoe_id, shuffle_seed)
```

A `Node` would couple deterministic rules to SceneTree lifetime. A `Resource` would imply editor serialization that the MVP does not need. `RefCounted` matches `Card` and `HandEvaluator`, remains directly unit-testable, and can later be owned by `RoundController`.

## Public Contract

```gdscript
static func create_injected(cards: Array[Card], shoe_id: String) -> DeckShoe
static func create_runtime(shoe_id: String, shuffle_seed: int) -> DeckShoe
func draw_card() -> Card
func can_draw(card_count: int) -> bool
func remaining_count() -> int
func draw_index() -> int
func should_reshuffle_before_next_round() -> bool
func capture_round_start(round_id: String) -> RoundStartMetadata
```

- Injected order is top-first: index `0` is the next card.
- The factory copies the injected array so later caller mutation cannot alter the active Shoe.
- Runtime construction always builds exactly 6 standard decks, or 312 cards.
- Every rank/suit pair appears exactly 6 times before shuffle.
- Runtime shuffle is an in-place Fisher-Yates shuffle driven by a dedicated Godot `RandomNumberGenerator` seeded with `shuffle_seed`.
- The same seed produces the same complete order. Different seeds are expected to produce different orders.
- `draw_card()` advances one position. Exhaustion returns `null`, leaves the draw index unchanged and never shuffles silently.
- `can_draw()` is the preflight API for `RoundController`; negative requests are invalid.
- Reshuffle is required only before a future round when remaining cards are below 20. Exactly 20 does not reshuffle.

## Reproducibility Metadata

`capture_round_start(round_id)` returns an immutable-enough snapshot containing:

```text
round_id
shoe_id
shuffle_seed
draw_index_at_round_start
```

The Shoe never invents a round or Shoe identifier. A future `RoundController` supplies stable IDs, while `DeckShoe` supplies seed and position evidence.

## Error Boundary

`DeckShoe` detects insufficient cards but does not decide refunds or outcomes. The future `RoundController` will treat a failed mid-round preflight/draw as a blocking implementation error and instruct `BetLedger` to refund according to spec 002 §5.

## Acceptance Evidence

- Top-first injected order and defensive copy are unit-tested.
- Exhaustion is unit-tested to prove no hidden reshuffle.
- Six-deck size and full rank/suit composition are unit-tested.
- Same-seed full-order reproducibility is unit-tested.
- Metadata position is unit-tested after prior draws.
- Remaining-card boundaries `20 → false` and `19 → true` are unit-tested.

