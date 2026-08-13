# RoundController Implementation Plan

> **For Codex:** REQUIRED SUB-SKILL: Use `executing-plans`, `test-driven-development`, `godot-development`, `godot-best-practices`, and `verification-before-completion` task-by-task. Do not commit without explicit user authorization.

**Goal:** Build the complete deterministic Blackjack round authority from bet selection through next round, including hole-card secrecy, all approved actions, dealer play, settlement, abort/refund and input-barrier guards.

**Architecture:** A pure typed `RoundController` uses an enum state machine and injected `DeckShoe`/`BetLedger`. Defensive snapshots and typed event values form the only public card/read boundary, while `HandEvaluator` and `BetLedger` remain the rule and accounting authorities.

**Tech Stack:** Godot 4.7.1, typed GDScript, gdUnit4 6.2.0.

---

### Task 1: State authority and betting commands

**Files:**
- Create: `tests/core/test_round_controller.gd`
- Create after RED: `scripts/core/round_controller.gd`

**Steps:**
1. Write a failing test for injected construction, initial `BETTING`, empty hands/outcome and legal `PLACE_BET`/`DEAL` actions.
2. Run the targeted gdUnit4 suite and require RED because `RoundController` is missing.
3. Implement the six-state enum, injected factory, dependency fields, read-only query methods and betting delegation only.
4. Add a failing test that `PLACE_BET` rejects outside `BETTING` without mutation; implement only the needed state guard.
5. Run targeted GREEN.

### Task 2: Transactional P-D-P-D initial deal and public read boundary

**Files:**
- Create after RED: `scripts/core/round_event.gd`
- Create after RED: `scripts/core/round_snapshot.gd`
- Modify: `scripts/core/round_controller.gd`
- Modify: `tests/core/test_round_controller.gd`

**Steps:**
1. Write a failing test with an injected top-first shoe proving successful commit, exact P-D-P-D event ownership/order and round metadata at draw index 0.
2. Implement typed events, sequence numbers, private hands and four sequential draws.
3. Write a failing secrecy test proving the face-down event has no card identity and the snapshot exposes only the dealer upcard, one hidden count and no full dealer total.
4. Implement defensive snapshot copies and the secrecy projection.
5. Write a failing invalid-DEAL test proving blank/duplicate/wrong-state commands do not draw or deduct.
6. Run targeted GREEN.

### Task 3: Peek and natural resolution

**Files:**
- Modify: `scripts/core/round_controller.gd`
- Modify: `tests/core/test_round_controller.gd`

**Steps:**
1. Add four deterministic RED cases for both-natural PUSH, dealer-only natural, player-only natural after peek, and neither natural after failed peek.
2. Implement upcard peek detection, `DEALER_PEEK_COMPLETED`, hole reveal and the approved priority table.
3. Add a RED case for a non-peek upcard with player natural; implement immediate player-blackjack resolution.
4. Assert settlement/chips once and duplicate DEAL rejection in every resolved path.
5. Run targeted GREEN.

### Task 4: Shoe exhaustion abort and refund

**Files:**
- Modify: `scripts/core/round_controller.gd`
- Modify: `tests/core/test_round_controller.gd`

**Steps:**
1. Write a RED test using a three-card shoe: commit occurs, fourth draw fails, committed bet is refunded, no canonical outcome exists, metadata remains available and state becomes `ROUND_END` aborted.
2. Implement one `_abort_for_shoe_exhaustion()` path used by every draw site.
3. Add a duplicate-command test proving the refund and abort cannot run twice and the shoe is not shuffled.
4. Run targeted GREEN.

### Task 5: HIT and STAND

**Files:**
- Modify: `scripts/core/round_controller.gd`
- Modify: `tests/core/test_round_controller.gd`

**Steps:**
1. Add RED cases for HIT below 21, HIT to exactly 21 and HIT bust.
2. Implement one-card HIT, player evaluation, first-decision closure and transitions/outcome.
3. Add a RED STAND case proving no player draw and transition to `DEALER_TURN`.
4. Implement STAND and wrong-state rejection.
5. Run targeted GREEN.

### Task 6: DOUBLE and late SURRENDER

**Files:**
- Modify: `scripts/core/round_controller.gd`
- Modify: `tests/core/test_round_controller.gd`

**Steps:**
1. Add RED cases for successful DOUBLE, doubled-bet bust, insufficient chips and rejection after HIT.
2. Implement ledger DOUBLE, exactly one draw and automatic player-turn closure.
3. Add RED cases for late SURRENDER after completed/irrelevant peek and rejection after HIT or dealer natural.
4. Implement first-decision surrender through canonical settlement.
5. Run targeted GREEN.

### Task 7: Stepped dealer turn and remaining outcomes

**Files:**
- Modify: `scripts/core/round_controller.gd`
- Modify: `tests/core/test_round_controller.gd`

**Steps:**
1. Add a RED test that the first dealer step only reveals the hole card.
2. Implement reveal-first stepping.
3. Add RED deterministic cases for hard 16 hit, hard 17 stand, soft 17 stand, dealer bust, player win, dealer win and push.
4. Implement at-most-one-card dealer steps and final comparison settlement.
5. Reuse the exhaustion abort for a dealer draw failure and add its RED/GREEN test.
6. Run targeted GREEN.

### Task 8: Presentation input barrier

**Files:**
- Modify: `scripts/core/round_controller.gd`
- Modify: `tests/core/test_round_controller.gd`

**Steps:**
1. Add a RED test that a unique blocking token empties legal actions and rejects otherwise-legal player commands.
2. Implement `begin_presentation(token)` with non-empty/one-active-token validation.
3. Add a RED test that only the first matching `complete_presentation(token)` succeeds; mismatched and late completion do not advance or unlock twice.
4. Implement the exactly-once token guard and run GREEN.

### Task 9: NEXT_ROUND and runtime shoe lifecycle

**Files:**
- Modify: `scripts/core/round_controller.gd`
- Modify: `tests/core/test_round_controller.gd`

**Steps:**
1. Add a RED test proving NEXT_ROUND rejects before `ROUND_END` and resets round-local state/selected bet after a completed round.
2. Implement clean reset to `BETTING` through `BetLedger.prepare_next_round()`.
3. Add RED cases for retaining a shoe at 20 cards, requiring replacement below 20, and mandatory replacement after exhaustion.
4. Implement explicit runtime replacement inputs (`next_shoe_id`, `next_shuffle_seed`) without in-round shuffle.
5. Add a runtime-factory reproducibility test and run GREEN.

### Task 10: Verify and update project truth

**Files:**
- Modify: `specs/001_FIRST_VERTICAL_SLICE.md`
- Modify: `specs/002_CORE_TRANSACTION_AND_DEAL_FLOW.md`
- Modify: `PROJECT_STATE.md`

**Steps:**
1. Mark only criteria directly proven by RoundController tests; leave L1/L2/L3 scene criteria unchecked.
2. Run Godot headless editor import and require exit code 0 with no parse errors.
3. Run all `res://tests` with the pinned gdUnit4 CLI and require zero errors/failures/flaky/skipped/orphans.
4. Inspect the diff and report changed files. Do not commit without explicit authorization.
