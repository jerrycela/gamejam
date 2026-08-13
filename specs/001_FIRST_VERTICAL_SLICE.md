# 001 - First Playable Blackjack Vertical Slice

**Status:** `APPROVED`

## Goal

完成一個可從下注到下一局的 Blackjack round，使用獨立 L1 placeholder components、正確 L2 placeholder feedback 與穩定 L3 placeholder。

---

## Required Tasks

### Task 1 - Card / HandEvaluator

- Typed Card value object。
- Pure logic。
- Ace handling。
- Natural blackjack。
- Bust。
- Deterministic unit tests。

### Task 2 - DeckShoe

- [x] Six-deck Fisher-Yates shuffle for runtime core factory。
- [x] Top-first injected fixed sequence for tests。
- [x] Reproducible `shoe_id`／`shuffle_seed`／round start draw index metadata。
- [x] Exact 20-card reshuffle query and no silent shuffle on exhaustion。
- [ ] RoundController integration and mid-round abort/refund path。

### Task 3 - BetLedger

- [x] Available／selected／committed chips。
- [x] Bet validation and commit。
- [x] Settlement credit exactly once。
- [x] DOUBLE／SURRENDER accounting。

### Task 4 - RoundController

```text
BETTING
INITIAL_DEAL
PLAYER_TURN
DEALER_TURN
RESOLVE_ROUND
ROUND_END
```

### Task 5 - Player Actions

- HIT。
- STAND。
- DOUBLE。
- SURRENDER。

### Task 6 - L1 Placeholder UI

獨立元件：

- Action buttons。
- Dealer hand。
- Player hand。
- Total。
- Chips。
- Bet。
- Result。

不可使用一張整體 UI 圖。

### Task 7 - L2 Placeholder

- Deal feedback。
- Flip feedback。
- Win／Lose／Push／Bust／Blackjack label/Tween。
- Input barrier。
- Fallback。

### Task 8 - L3 Placeholder

- Dealer/background placeholder。
- Wait loop。
- L2 後恢復。

### Task 9 - End-to-End

- Complete round。
- Next round reset。
- Regression。

---

## Acceptance Criteria

- [x] House Rules prototype profile approved。
- [x] All HandEvaluator cases pass（9/9, gdUnit4 6.2.0）。
- [x] DeckShoe runtime factory uses reproducible seeded shuffle; tests use top-first deterministic shoe。
- [ ] RoundController creates and consumes the runtime Shoe and persists round metadata。
- [ ] Initial deal correct。
- [ ] HIT correct。
- [ ] STAND and Dealer turn correct。
- [ ] DOUBLE correct。
- [ ] SURRENDER correct。
- [ ] All canonical outcomes correct。
- [ ] Chips/payout applied exactly once。
- [ ] Illegal actions cannot be submitted。
- [ ] Blocking L2 prevents duplicate action。
- [ ] Media/presentation failure does not deadlock。
- [ ] L1 components independent and responsive。
- [ ] L3 resumes after L2。
- [ ] Next round starts cleanly。
- [ ] No blocker runtime errors。
- [ ] PROJECT_STATE.md updated。

---

## Explicit Non-Goals

- Final art。
- Figma pixel-perfect sync。
- Split。
- Insurance。
- Side bets。
- Backend。
- Multiplayer。
- Story progression。
- Live AI generation。
