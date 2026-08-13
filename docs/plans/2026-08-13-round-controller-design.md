# RoundController Core Design

**Status:** `APPROVED BY EXISTING SPECS AND USER DIRECTION TO FOLLOW THE RECOMMENDED APPROACH`

**Sources:** `specs/000_HOUSE_RULES_DECISION.md`, `specs/001_FIRST_VERTICAL_SLICE.md`, `specs/002_CORE_TRANSACTION_AND_DEAL_FLOW.md`, `docs/02_BLACKJACK_RULES.md`, and `docs/03_INTERACTION_CONTRACTS.md`.

## Purpose

`RoundController` is the single authority for one Blackjack table's round state, legal commands, card flow, canonical outcome and coordination of `DeckShoe`, `HandEvaluator` and `BetLedger`. It does not own Control nodes, animations, media, character reactions or Figma assets.

## Considered Approaches

1. **Pure enum-based `RefCounted` orchestrator — chosen.** Six approved states fit one explicit controller, deterministic tests need no SceneTree, and later Godot nodes can call down or connect to its signals.
2. **One Node per state.** Useful when states have independent lifecycle/process loops, but excessive for six synchronous rule states and harder to unit-test without a tree.
3. **One large scene `Node` mixing rules and presentation.** Fast initially but violates L1/L2/L3 responsibility boundaries and makes hole-card secrecy and duplicate-input behavior difficult to prove.

## Core Shape

The controller uses the approved states:

```text
BETTING → INITIAL_DEAL → PLAYER_TURN → DEALER_TURN
                               ↘ RESOLVE_ROUND → ROUND_END → BETTING
```

It is created through one of two explicit factories:

```gdscript
RoundController.create_injected(shoe, ledger)
RoundController.create_runtime(shoe_id, shuffle_seed, ledger)
```

Injected shoes make edge cases deterministic. The runtime factory creates the approved six-deck `DeckShoe`; no command silently replaces or shuffles a shoe during a round.

Public command methods return `bool`. Rejection preserves all state and records a stable diagnostic ID in `last_error`. Public mutable game data is not exposed directly; consumers receive a defensive `RoundSnapshot`. The controller emits or queues typed `RoundEvent` values with `round_id` and increasing `sequence_no` for later L1/L2 integration.

## Data Ownership and Secrecy

The controller privately owns player and dealer hands. Before reveal, `RoundSnapshot` contains only the dealer upcard, `dealer_hidden_card_count = 1`, and no complete dealer total. The face-down initial-deal event carries no `Card` identity. `DEALER_HOLE_CARD_REVEALED` is the first public event allowed to include that card and the full dealer evaluation.

This boundary is enforced in core tests rather than trusting `TableUI` to hide already-leaked data. Presentation can draw a card back from `dealer_hidden_card_count`; it never receives the secret identity early.

Round-start metadata is captured immediately after a successful bet commit and before the first draw:

```text
round_id
shoe_id
shuffle_seed
draw_index_at_round_start
```

## Command and State Flow

`PLACE_BET` delegates to `BetLedger` only in `BETTING`. `DEAL` requires a non-empty new `round_id`, commits once, captures metadata, enters `INITIAL_DEAL`, then consumes cards P-D-P-D. Failed commit does not draw or change state.

After the four cards, the controller evaluates player natural first. Dealer A or ten-value upcards trigger peek. Dealer natural reveals the hole card and resolves immediately; otherwise a player natural reveals and resolves. With no natural, the hole remains secret and the controller enters `PLAYER_TURN` with first-decision DOUBLE and late-surrender eligibility.

`HIT` draws one, disables first-decision actions, resolves bust, moves 21 to `DEALER_TURN`, or remains in `PLAYER_TURN`. `STAND` enters `DEALER_TURN`. `DOUBLE` validates state, first two cards and chips, doubles through the ledger, draws exactly one, then resolves bust or enters dealer turn. `SURRENDER` resolves immediately through the canonical outcome.

Dealer work is stepped rather than run in one loop. The first `dealer_step()` reveals the hole card; later calls draw at most one card or resolve. This permits a blocking L2 animation between reveal and each draw. The approved dealer rule is stand on soft 17, so the dealer draws only below 17.

## Error and Exactly-Once Handling

Every command first checks the input barrier, state and command-specific invariants. `BetLedger` remains the second line of defense for money duplicates. Once a canonical outcome settles, the controller reaches `ROUND_END`; all player/dealer commands reject there.

If any required draw returns `null`, the controller records a blocking shoe-exhaustion diagnostic with the captured metadata, refunds the committed bet once, clears public hand data, marks `round_aborted = true` and `requires_new_shoe = true`, and enters `ROUND_END` without a canonical outcome. It never calls settlement for this path.

Blocking presentation uses a unique token guard. While a token is active, `legal_actions()` is empty and player commands reject. Normal completion and timeout call the same `complete_presentation(token)` method; only the first matching token unlocks or advances, so a late duplicate cannot replay a command or state transition.

`NEXT_ROUND` is accepted only from `ROUND_END`, calls `BetLedger.prepare_next_round()`, clears round-local state, and creates a new runtime shoe only when the old shoe is below the approved threshold or an exhaustion abort requires replacement. Runtime shoe identity/seed are explicit inputs so sessions remain reproducible.

## Verification Strategy

Tests use real `Card`, `DeckShoe`, `HandEvaluator` and `BetLedger` objects without mocks. Each behavior follows RED → GREEN:

- initial state and legal-action matrix;
- commit before draw, exact P-D-P-D order and metadata position;
- peek success/failure and all natural priorities;
- no hole identity or full total before reveal;
- exhaustion refund without outcome or silent shuffle;
- HIT, STAND, DOUBLE, SURRENDER and illegal repeats;
- dealer soft-17 stand, draw progression and all comparison outcomes;
- input-barrier token exactly once;
- clean next round and conditional shoe replacement.

Pure-logic headless tests do not prove UI input delivery or visual correctness. Those remain separate scene/integration and human-approval gates.
