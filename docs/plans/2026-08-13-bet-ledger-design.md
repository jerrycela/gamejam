# BetLedger Transaction Design

**Status:** `APPROVED BY EXISTING SPECS`

**Sources:** `specs/000_HOUSE_RULES_DECISION.md` §§C–G, `specs/001_FIRST_VERTICAL_SLICE.md` Task 3, and `specs/002_CORE_TRANSACTION_AND_DEAL_FLOW.md` §§2–4.

## Purpose

`BetLedger` is the sole core authority for integer chips, selected bet, committed bet, settlement credits and defensive refunds. It is not a backend wallet and does not validate Blackjack hand/state timing.

## Chosen Shape

Use a pure typed `RefCounted` with the approved fixed prototype profile:

```text
starting chips = 1000
minimum bet = 10
maximum bet = 500
non-integer player credit rounds upward
```

The object exposes current `available_chips`, `selected_bet` and `committed_bet` for a future read model. Only its transaction methods mutate them.

## Canonical Outcome Type

Create a small `BlackjackOutcome` core type containing the eight approved canonical IDs. `BetLedger` consumes these IDs but presentation mapping remains outside the ledger.

## Public Contract

```gdscript
func set_selected_bet(amount: int) -> bool
func commit(round_id: String) -> bool
func double_committed_bet(round_id: String) -> bool
func settle(round_id: String, outcome: int) -> CreditResult
func refund(round_id: String) -> CreditResult
func prepare_next_round() -> bool
```

`CreditResult` reports:

```text
accepted
credit
committed_bet_before
available_chips_after
```

Rejected operations return `accepted = false`, `credit = 0` and never mutate ledger state.

## Invariants

- Selection is legal only when no bet is active and `10 <= amount <= 500 <=? available_chips`; concretely, amount must also be at most current available chips.
- Commit deducts `selected_bet` and creates `committed_bet` exactly once for a non-empty `round_id`.
- Only one round may be active in one ledger.
- DOUBLE requires the matching active round, enough available chips and no earlier accepted DOUBLE for that `round_id`.
- Settlement requires the matching active round, a canonical outcome and no prior close. It credits once, clears committed bet and closes the round.
- Refund returns the full committed bet once, clears it and closes the round. Settlement after refund is rejected.
- A closed or previously committed `round_id` can never be recommitted.
- Failed operations do not consume an exactly-once token.
- `prepare_next_round` is rejected while a bet is active. Otherwise it restores selected bet to 10 and resets available chips to 1000 only when available chips are below 10.

## Credit Mapping

| Outcome | Credit including returned stake |
|---|---:|
| `PLAYER_BLACKJACK` | `committed + ceil(3 × committed / 2)` |
| `PLAYER_WIN` | `2 × committed` |
| `DEALER_BUST` | `2 × committed` |
| `PUSH` | `committed` |
| `PLAYER_SURRENDER` | `ceil(committed / 2)` |
| `DEALER_BLACKJACK` | `0` |
| `DEALER_WIN` | `0` |
| `PLAYER_BUST` | `0` |

Integer upward rounding is implemented without floating-point state: `(numerator + denominator - 1) / denominator`, converted to integer.

## Responsibility Boundary

- `RoundController` decides whether state/card timing permits DEAL, DOUBLE or SURRENDER.
- `BetLedger` independently rejects money-invalid and duplicate transactions.
- `RoundController` passes the canonical resolved outcome; `BetLedger` never compares hands.
- Persistence, real money, audit backend and provably-fair accounting remain non-goals.

## Acceptance Evidence

- Selection boundary and preservation on rejection.
- Commit deduction plus duplicate/non-matching rejection.
- DOUBLE success, insufficient chips and duplicate rejection.
- Every canonical outcome mapping, including odd 25-chip Blackjack and surrender rounding.
- Numeric examples from spec 002, including DOUBLE win to 1200.
- Duplicate settlement and refund leave chips unchanged.
- Refund prevents later settlement and recommit of the same round.
- Next-round low-bankroll reset and active-round rejection.

