# 08 - Codex Prompt Playbook

## 1. Session Boot

```text
Read AGENTS.md, PROJECT_STATE.md, and the specs relevant to this task.
Inspect git status and the current Godot project through MCP.
Do not modify anything yet.

Report:
- current state
- spec status
- conflicts
- smallest next task
- changed files expected
- acceptance test
```

---

## 2. Repository Audit

```text
Audit the current repository against the Knowledge Pack.

Do not implement or refactor.

Check:
1. Blackjack core responsibilities
2. L1/L2/L3 separation
3. flattened UI images
4. duplicate rules in UI scripts
5. missing deterministic tests
6. Figma/Godot component mapping
7. runtime dependency on MCP or AI services
8. unresolved house rules

Classify findings as BLOCKER, HIGH, MEDIUM, LOW.
Recommend only the smallest corrective sequence.
```

---

## 3. Implement One Feature

```text
Read AGENTS.md and this approved feature spec:
<SPEC_PATH>

Before coding:
- summarize the behavior
- identify all dependencies
- list files to change
- list files that must not change
- define deterministic tests
- confirm the spec is not blocked

Implement only this feature.
Run Godot and the exact tests.
Update PROJECT_STATE.md.
Report PASS/FAIL and changed files.
```

---

## 4. First Vertical Slice Plan

```text
Read specs/000_HOUSE_RULES_DECISION.md and specs/001_FIRST_VERTICAL_SLICE.md.

If required house rules are not approved, stop with SPEC REQUIRED.

Otherwise, create a task plan in this order:
1. HandEvaluator
2. Card model and deterministic DeckShoe test mode
3. BetLedger transaction core
4. RoundController states
5. initial deal, dealer peek, and natural resolution
6. HIT
7. STAND and Dealer turn
8. general round resolution
9. DOUBLE
10. SURRENDER
11. independent L1 placeholder components
12. L2 placeholder feedback
13. L3 placeholder loop
14. end-to-end regression

Do not implement yet.
For each task give acceptance criteria and affected files.
```

---

## 5. Figma Component Handoff

```text
Read docs/04_VISUAL_ENGINEERING_FIGMA.md and docs/05_FIGMA_TO_GODOT.md.

Component ID:
<COMPONENT_ID>

Figma URL/node or export spec:
<REFERENCE>

Do not modify Blackjack rules.

First inspect whether a Godot component already implements this semantic role.
Prefer updating Theme/type variation over rebuilding the scene.
Implement all approved variants.
Run reference, narrow, and wide portrait viewports.
Capture before/after screenshots.
Report visual differences and HUMAN APPROVAL REQUIRED.
```

---

## 6. AI Asset Integration

```text
Integrate this approved asset:

Asset ID: <ASSET_ID>
Source path: <SOURCE_PATH>
Runtime role: <L1_TEXTURE / L2_REACTION / L3_LOOP>
Trigger or component: <ID>

Preserve the source asset.
Do not change core Blackjack rules.
Validate dimensions, alpha/chroma key, aspect ratio, and import status.
Use PresentationController or the mapped UI component.
Add a safe fallback.
Run the exact triggering scenario.
Report ASSET PASS/FAIL and HUMAN APPROVAL REQUIRED.
```

---

## 7. Figma Enterprise MCP Read/Write

```text
Read docs/04_VISUAL_ENGINEERING_FIGMA.md and docs/05_FIGMA_TO_GODOT.md.

Use the connected enterprise Figma account and Figma MCP full read/write workflow.

Target file/node/component:
<FIGMA_REFERENCE>

Approved spec:
<SPEC_PATH>

Before writing:
- read the current component, variants, tokens/variables, and parent screen
- identify the exact node IDs to modify
- list what will remain unchanged
- confirm the target version and acceptance criteria

Apply only the approved targeted changes.
Do not redesign unrelated components.
After writing, report changed Figma nodes and mark HUMAN APPROVAL REQUIRED.
After approval, update the Component Manifest and corresponding Godot Theme/Scene, then run screenshot QA.
```

---

## 8. Bug Fix

```text
Reproduce this bug before changing code:
<BUG>

Report actual vs expected behavior and root cause.
Implement the smallest fix without redesigning unrelated architecture.
Run the reproduction and relevant regressions.
Update PROJECT_STATE.md.
```

---

## 9. Visual QA

```text
Do not add features.
Run the approved screen at:
- reference portrait
- narrow portrait
- wide portrait

Check:
- overlap
- crop
- stretch
- safe area
- button hit area
- disabled/pressed states
- card readability
- L2 layer order
- L3 continuity

Capture screenshots and list concrete defects.
Do not make subjective art-direction changes without approval.
```

---

## 10. End of Session

```text
Do not add features.

Run the project and relevant tests.
Review git diff.
Update PROJECT_STATE.md with:
- completed
- failing
- pending decisions
- visual approvals required
- next smallest task

Give a recommended commit message, but do not commit automatically.
```
