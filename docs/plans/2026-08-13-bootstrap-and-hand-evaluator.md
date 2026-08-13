# Bootstrap and HandEvaluator Implementation Plan

> **For Codex:** REQUIRED SUB-SKILLS: Use `executing-plans`, `test-driven-development`, `godot-development`, and `verification-before-completion` while implementing this plan.

**Goal:** Turn the Knowledge Pack into a pinned, testable Godot project and complete the first deterministic `HandEvaluator` task.

**Architecture:** The repository root is the existing Knowledge Pack directory. Core Blackjack logic is implemented as typed `RefCounted` GDScript classes with no SceneTree dependency. gdUnit4 runs deterministic unit tests headlessly before any UI or presentation work begins.

**Tech Stack:** Godot 4.7.1, GDScript, gdUnit4 6.2.0, Git.

---

### Task 1: Establish the repository and toolchain baseline

**Files:**
- Create: `.gitignore`
- Create: `project.godot`
- Vendor: `addons/gdUnit4/**`
- Modify: `PROJECT_STATE.md`
- Modify: `docs/09_TEST_AND_ACCEPTANCE.md`

**Step 1:** Initialize Git in the Knowledge Pack directory without committing.

**Step 2:** Create a minimal Godot 4.7.1 project configured for a 1080×1920 portrait reference viewport.

**Step 3:** Install gdUnit4 6.2.0 from its official release archive.

**Step 4:** Run Godot headlessly and confirm the project imports without script parse errors.

**Step 5:** Run the gdUnit4 CLI and confirm that it starts successfully even before tests exist.

**Step 6:** Record exact pinned versions, executable path, and verified CLI command in project state and test documentation.

### Task 2: Approve the core transaction and deal-flow contract

**Files:**
- Create: `specs/002_CORE_TRANSACTION_AND_DEAL_FLOW.md`
- Modify: `specs/000_HOUSE_RULES_DECISION.md`
- Modify: `docs/02_BLACKJACK_RULES.md`
- Modify: `docs/03_INTERACTION_CONTRACTS.md`
- Modify: `docs/08_CODEX_PLAYBOOK.md`
- Modify: `docs/09_TEST_AND_ACCEPTANCE.md`
- Modify: `docs/10_KNOWLEDGE_GOVERNANCE_RISKS.md`
- Modify: `PROJECT_STATE.md`

**Step 1:** Define selected, available, and committed bet invariants with exact settlement formulas.

**Step 2:** Define P-D-P-D initial deal order, top-first injected shoe semantics, dealer peek ordering, natural resolution priority, hidden total behavior, and HIT-to-21 auto-transition.

**Step 3:** Replace per-round seed logging with reproducible shoe metadata: `shoe_id`, `shuffle_seed`, and `draw_index_at_round_start`.

**Step 4:** Resolve approval-state contradictions and mark `DEC-006` as prototype approved.

**Step 5:** Reorder the implementation playbook so `BetLedger` precedes initial deal.

**Step 6:** Add exact Given/When/Then acceptance examples for the clarified rules.

### Task 3: Implement `Card` and `HandEvaluator` with TDD

**Files:**
- Create: `scripts/core/card.gd`
- Create: `scripts/core/hand_evaluator.gd`
- Create: `tests/core/test_hand_evaluator.gd`

**Step 1: RED — basic total**

Write a gdUnit4 test for `10 + 8 = 18`, run it, and confirm failure because the classes are missing.

**Step 2: GREEN — basic total**

Create the smallest typed `Card` value object and `HandEvaluator.evaluate(cards)` implementation that returns `total`, `is_soft`, `is_blackjack`, `is_bust`, and `card_count`. Run the test and confirm it passes.

**Step 3: RED/GREEN — face cards**

Add `K + 8 = 18`, verify failure, implement face-card value handling, and verify pass.

**Step 4: RED/GREEN — soft Ace**

Add `A + 7 = soft 18`, verify failure, implement Ace-as-11 handling, and verify pass.

**Step 5: RED/GREEN — Ace downgrade**

Add `A + 7 + 9 = hard 17`, verify failure, implement Ace downgrade, and verify pass.

**Step 6: RED/GREEN — multiple Aces**

Add `A + A + 9 = soft 21` and `A + A + 9 + 9 = hard 20`, verifying RED and GREEN for the behavior.

**Step 7: RED/GREEN — bust**

Add `10 + 6 + 8 = bust`, verify failure, implement bust status, and verify pass.

**Step 8: RED/GREEN — natural blackjack**

Add two-card `A + K = blackjack` and a three-card 21 that is not blackjack, verify failure, implement the two-card rule, and verify pass.

**Step 9: Refactor and verify**

Run the complete core test directory and the Godot headless parse check. Keep core classes independent of `Node`, autoloads, UI, and presentation.

### Task 4: Update state and hand off

**Files:**
- Modify: `PROJECT_STATE.md`

**Step 1:** Record the toolchain baseline and completed HandEvaluator task.

**Step 2:** Record actual verification commands and outcomes.

**Step 3:** Set the next smallest task to deterministic `DeckShoe` without starting UI or presentation work.

**Step 4:** Review `git diff` and report changed files. Do not commit unless the user explicitly requests it.
