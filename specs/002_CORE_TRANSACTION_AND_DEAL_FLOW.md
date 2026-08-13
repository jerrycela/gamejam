# 002 - Core Transaction and Deal Flow

**Status:** `APPROVED`

**Version:** `1.0.0`

Approved by: `Project owner via Codex task`

Date: `2026-08-13`

## 1. Purpose

本規格補足 `docs/02_BLACKJACK_RULES.md` 與 `specs/000_HOUSE_RULES_DECISION.md` 中會造成不同實作結果的交易與時序語意。

本規格只服務第一個 Vertical Slice，不加入 split、insurance、side bet、backend 或正式美術。

## 2. BetLedger Terms

```text
available_chips: 玩家目前可再投入的整數籌碼
selected_bet: BETTING 中正在選擇、尚未扣除的整數下注
committed_bet: DEAL 成功後已從 available_chips 扣除並鎖定的整數下注
settlement_credit: resolve 時一次性加回 available_chips 的整數金額
```

不使用語意不明的 `current_chips` 或 `current_bet` 作為實作欄位。

## 3. Betting Transaction

### PLACE_BET

- 只修改 `selected_bet`，不扣 `available_chips`。
- 合法條件：`minimum_bet <= selected_bet <= maximum_bet`。
- `selected_bet` 不可超過 `available_chips`。

### DEAL / Commit

DEAL 成功時只執行一次：

```text
available_chips -= selected_bet
committed_bet = selected_bet
```

若條件不合法，不得扣款、發牌或改變 round state。

### DOUBLE

只有 000 §D 與本規格定義的 first-decision 條件成立，且：

```text
available_chips >= committed_bet
```

才可執行。成功時只執行一次：

```text
available_chips -= committed_bet
committed_bet *= 2
```

之後只抽一張玩家牌並自動結束 player turn。

## 4. Settlement Credit

下表的 credit 包含應返還的本金，不是只表示淨利：

| Outcome | settlement_credit |
|---|---:|
| `PLAYER_BLACKJACK` | `committed_bet + ceil(committed_bet × 3 / 2)` |
| `PLAYER_WIN` | `committed_bet × 2` |
| `DEALER_BUST` | `committed_bet × 2` |
| `PUSH` | `committed_bet` |
| `PLAYER_SURRENDER` | `ceil(committed_bet / 2)` |
| `DEALER_BLACKJACK` | `0` |
| `DEALER_WIN` | `0` |
| `PLAYER_BUST` | `0` |

Resolve 成功時：

```text
available_chips += settlement_credit
committed_bet = 0
```

同一 `round_id` 的 resolve、refund、DOUBLE 與 settlement 都必須有 exactly-once guard。

### Numeric Examples

| Given | After commit/action | Final result |
|---|---|---|
| chips 1000, bet 100, PLAYER_WIN | available 900, committed 100 | available 1100 |
| chips 1000, bet 100, DEALER_WIN | available 900, committed 100 | available 900 |
| chips 1000, bet 100, PUSH | available 900, committed 100 | available 1000 |
| chips 1000, bet 25, PLAYER_BLACKJACK | available 975, committed 25 | credit 63, available 1038 |
| chips 1000, bet 25, PLAYER_SURRENDER | available 975, committed 25 | credit 13, available 988 |
| chips 1000, bet 100, DOUBLE + PLAYER_WIN | available 800, committed 200 | credit 400, available 1200 |

若 resolve 後 `available_chips < minimum_bet`，只在 `NEXT_ROUND` 時重置為 000 §G 的 starting chips；同時把 `selected_bet` 設回 minimum bet。一般 `NEXT_ROUND` 也把 `selected_bet` 設回 minimum bet。

## 5. Deterministic Shoe Semantics

Injected test shoe 採 top-first：陣列 index `0` 是下一張抽出的牌。

Runtime Shoe 只有在 prototype start 或下一局開始前符合 reshuffle 條件時洗牌；不得在 round 中途靜默洗牌。

可重現資訊至少記錄：

```text
round_id
shoe_id
shuffle_seed
draw_index_at_round_start
```

只記錄每局 seed 不足以重現跨回合持續抽取的 Shoe。

若防禦性檢查發現 round 中途牌耗盡：

1. 記錄 blocking error 與上述 Shoe metadata。
2. 中止該 round，不產生 canonical Blackjack outcome。
3. 全額返還 `committed_bet`，清為 0。
4. 下一局開始前建立新 Shoe。

## 6. Initial Deal and Peek Order

固定發牌順序：

```text
1. Player first card face up
2. Dealer upcard face up
3. Player second card face up
4. Dealer hole card face down
```

Core 可以計算完整 Dealer hand；L1 在 hole card reveal 前不得取得暗牌 identity 或完整 Dealer total。

Initial Deal 完成後依序判斷：

1. 計算 player natural。
2. Dealer upcard 為 A 或 10-value 時執行 peek。
3. Peek 有 dealer natural：revealed hole card 後立即 resolve。
4. Peek 無 dealer natural：保持 hole card 隱藏，late surrender 才成為合法 first decision。
5. Dealer upcard 非 A／10-value 時不需要 peek。

### Natural Resolution Priority

| Player natural | Dealer natural | Result |
|---|---|---|
| true | true | `PUSH` |
| false | true | `DEALER_BLACKJACK` |
| true | false | `PLAYER_BLACKJACK` |
| false | false | `PLAYER_TURN` |

## 7. HIT to 21

HIT 後：

```text
total > 21  → PLAYER_BUST → RESOLVE_ROUND
total == 21 → 自動關閉所有 player actions → DEALER_TURN
total < 21  → 依 legal-action policy 回到 PLAYER_TURN
```

玩家到 21 後不得再送出 HIT、DOUBLE 或 SURRENDER。

## 8. Acceptance Criteria

- [x] 所有 Numeric Examples 以 deterministic tests 驗證。
- [ ] Initial deal 固定使用 P-D-P-D 與 top-first injected shoe。
- [ ] Dealer peek 成功／失敗路徑皆有 state tests。
- [ ] Dealer hole card reveal 前 UI read model 不含完整 total。
- [ ] HIT 到 21 自動進 Dealer turn。
- [x] 同一 `round_id` 不可重複 commit、DOUBLE、refund 或 settle。
- [x] Shoe diagnostics 可重現 shuffle 與 round 起始位置。
- [ ] 中途牌耗盡不靜默洗牌且不損失 committed bet。

## 9. Non-Goals

- Split hand transaction。
- Insurance transaction。
- Persistence／backend wallet。
- Real-money or provably-fair gambling system。
