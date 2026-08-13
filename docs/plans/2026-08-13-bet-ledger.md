# BetLedger Implementation Plan

> **For Codex:** REQUIRED SUB-SKILL: Use `executing-plans`, `test-driven-development`, `godot-development`, `godot-best-practices`, and `verification-before-completion` to implement this plan task-by-task.

**Goal:** Implement the approved Blackjack chip ledger with exact commit, DOUBLE, settlement, refund and next-round reset behavior guarded exactly once per round.

**Architecture:** A pure typed `BetLedger` owns all mutable chip fields and transaction token sets. A separate `BlackjackOutcome` defines canonical cross-layer outcome IDs. Round state/card legality remains outside the ledger so the future `RoundController` can orchestrate without duplicating accounting.

**Tech Stack:** Godot 4.7.1, typed GDScript, gdUnit4 6.2.0.

---

### Task 1: Define defaults and bet selection

**Files:**
- Create: `tests/core/test_bet_ledger.gd`
- Create after RED: `scripts/core/bet_ledger.gd`

**Step 1:** Write tests for defaults `1000 / 10 / 0`, valid selection, lower/upper boundaries, insufficient chips and preservation after rejection.

**Step 2:** Run the targeted suite and verify RED because `BetLedger` is missing.

**Step 3:** Implement constants, fields, constructor and `set_selected_bet` only.

**Step 4:** Run GREEN and the complete core suite.

### Task 2: Commit exactly once

**Files:**
- Modify: `tests/core/test_bet_ledger.gd`
- Modify after RED: `scripts/core/bet_ledger.gd`

**Step 1:** Write tests proving a 100-chip commit produces available 900 / committed 100 and duplicate commit, blank ID, a second active round and selection during an active round are rejected without mutation.

**Step 2:** Run RED because `commit` is missing.

**Step 3:** Implement active round tracking and accepted committed-round tokens.

**Step 4:** Run GREEN.

### Task 3: DOUBLE accounting

**Files:**
- Modify: `tests/core/test_bet_ledger.gd`
- Modify after RED: `scripts/core/bet_ledger.gd`

**Step 1:** Write tests for a successful 100-chip DOUBLE, duplicate/non-matching rejection, and an insufficient-chips case after a prior loss lowers bankroll.

**Step 2:** Run RED because DOUBLE is missing.

**Step 3:** Deduct the original committed amount, multiply committed bet by two and record the round token only on success.

**Step 4:** Run GREEN.

### Task 4: Canonical settlement and rounding

**Files:**
- Create after outcome RED: `scripts/core/blackjack_outcome.gd`
- Modify: `tests/core/test_bet_ledger.gd`
- Modify after RED: `scripts/core/bet_ledger.gd`

**Step 1:** Write the exact spec 002 numeric examples for win, loss, push, odd 25-chip Blackjack, odd surrender and DOUBLE win.

**Step 2:** Run RED because outcome IDs and settlement are missing.

**Step 3:** Implement the eight canonical outcome IDs, `CreditResult`, outcome validation and integer credit mapping.

**Step 4:** Add/verify coverage for `DEALER_BLACKJACK`, `PLAYER_BUST` and `DEALER_BUST` so every canonical ID is mapped.

**Step 5:** Run GREEN.

### Task 5: Close-path exactly-once and next round

**Files:**
- Modify: `tests/core/test_bet_ledger.gd`
- Modify after RED: `scripts/core/bet_ledger.gd`

**Step 1:** Write tests proving duplicate settlement and invalid outcome do not mutate chips.

**Step 2:** Run RED, then implement settlement close tokens and validate before mutation.

**Step 3:** Write tests proving refund returns the complete committed bet once, blocks later settlement/recommit, and duplicate refund changes nothing.

**Step 4:** Run RED, then implement refund through the same close invariant.

**Step 5:** Write tests for next-round selected-bet reset, low-bankroll reset to 1000 and rejection while a round is active.

**Step 6:** Run RED, implement `prepare_next_round`, then run GREEN.

### Task 6: Verify and update state

**Files:**
- Modify: `specs/001_FIRST_VERTICAL_SLICE.md`
- Modify: `specs/002_CORE_TRANSACTION_AND_DEAL_FLOW.md`
- Modify: `PROJECT_STATE.md`

**Step 1:** Mark only transaction criteria directly proven by BetLedger tests; leave RoundController action timing unchecked.

**Step 2:** Run all `res://tests` through the pinned gdUnit4 CLI and require zero errors/failures/flaky/skipped/orphans.

**Step 3:** Run Godot headless editor import and require exit code 0 with no script parse errors.

**Step 4:** Inspect changed files and report. Do not commit without explicit user authorization.
