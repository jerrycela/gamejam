# 11 - Original Reference Deck Analysis

## 1. Source Snapshot

- Google Slides title: `LOW SCALE PROJECT`
- Presentation ID: `1_NQThhaFi7dpB022AFiUkTx2svX1ebtK0HnTXOx0PTQ`
- Revision ID inspected: `yLVzGbN-jrqx7Q`
- Slides inspected: `9 / 9`
- Inspection date: `2026-08-13`

This document records product intent derived from the original concept deck. It is not a Blackjack rule authority. When the deck conflicts with an approved spec, the approved spec wins according to `AGENTS.md` §3.

## 2. Confirmed Product Intent

The deck defines three runtime presentation layers:

| Layer | Deck intent | MVP translation |
|---|---|---|
| LAYER-1 | GUI objects the player can operate | Independent Godot `Control` components for cards, totals, bet, chips and actions |
| LAYER-2 | Positive or negative feedback caused by player actions | Deal, flip, result, chip and short Dealer-reaction placeholders |
| LAYER-3 | Persistent looping scene and progression-dependent presentation | Dealer/background idle placeholder that resumes after blocking L2 |

The reference phone mockup places the Dealer hand near the top, the player hand in the lower-middle, and chips, bet and actions near the bottom. This is useful composition guidance, not a pixel-perfect screen specification.

## 3. WAIT / HOLD / LOOP Contract

The final slide establishes the intended runtime rhythm:

```text
WAIT  → wait for L1 player input
HOLD  → select and present the corresponding L2 response
LOOP  → maintain or resume L3 while blocking presentation finishes
```

For the MVP this maps to:

1. `RoundController` owns legal input and state progression.
2. L1 only sends player intent and renders a read model.
3. Blocking L2 closes the input gate and completes through an exactly-once presentation token or fallback timeout.
4. L3 remains persistent or resumes after L2; it never decides Blackjack outcomes.

## 4. Authoritative Corrections

- The phone mockup appears to show a complete Dealer total while the hole card is still face down. The MVP must instead follow `specs/002_CORE_TRANSACTION_AND_DEAL_FLOW.md`: before reveal, L1 cannot receive the hole-card identity or complete Dealer total.
- The deck mentions progression-dependent character presentation. Progression content, content boundaries and final art direction remain outside the first Vertical Slice and require a separate approved spec plus human visual approval.
- MP4 is an allowed L2/L3 asset option, not a required runtime architecture. Placeholder Label/Tween/ColorRect presentation is sufficient for MVP feasibility validation.
- The reference is landscape documentation containing a portrait phone mockup. The executable product remains a portrait `1080 × 1920` reference canvas.

## 5. MVP Implications

The concept is feasible with the current architecture. The minimum convincing validation is not final art; it is one complete Blackjack round where:

- independent L1 controls remain responsive and expose only legal actions;
- deterministic core state produces correct outcomes and chips;
- L2 feedback blocks duplicate input without deadlocking;
- L3 visibly persists or resumes after feedback;
- the layout reads clearly on a portrait phone frame.

Formal visual production should begin only after the core HIT/STAND/Dealer flow and exactly-once settlement are proven.
