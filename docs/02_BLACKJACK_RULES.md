# 02 - Blackjack Rules

## 1. Purpose

本文件定義核心規則模型。

House Rules 的實際值由：

`specs/000_HOUSE_RULES_DECISION.md`

決定。

Codex 不得從網路慣例或自己的偏好補完 TBD。

---

## 2. Card Model

```text
Suit: CLUBS / DIAMONDS / HEARTS / SPADES
Rank: A, 2-10, J, Q, K
```

牌值：

- 2-10：牌面值。
- J/Q/K：10。
- A：先計 11；若 Bust，依需要降為 1。

HandEvaluator 應回傳至少：

```text
total
is_soft
is_blackjack
is_bust
card_count
```

`is_soft` 為 true 當且僅當手牌中至少有一張 Ace 以 11 計入目前 total。

Examples：

```text
A + 7       = 18 soft
A + 7 + 9   = 17 hard
A + A + 9   = 21 soft
K + 8       = 18
10 + 6 + 8  = bust
A + K       = natural blackjack when it is the initial two-card hand
```

---

## 3. Round States

```text
BETTING
INITIAL_DEAL
PLAYER_TURN
DEALER_TURN
RESOLVE_ROUND
ROUND_END
```

只有 `PLAYER_TURN` 可以接受一般 player action。

---

## 4. Player Actions

### HIT

- 抽一張牌。
- 更新 hand value。
- Bust 則立即進入 resolve。
- Total 恰為 21 則自動關閉 player actions 並進入 `DEALER_TURN`。
- Total 小於 21 則依 legal-action policy 維持或返回 `PLAYER_TURN`。

### STAND

- 不再抽玩家牌。
- 進入 `DEALER_TURN`。

### DOUBLE

基本語意：

- 額外投入與原 bet 等額的籌碼。
- 只抽一張牌。
- 自動結束 player turn。

合法條件由 House Rules 決定。

### SURRENDER

基本語意：

- 放棄本局。
- 依 House Rules 返還部分 bet。
- 直接 resolve。

---

## 5. Dealer Turn

Dealer 必須根據已批准規則持續抽牌或停止。

特別要區分：

```text
hard 17
soft 17
```

不要把 soft 17 寫成單純 `total >= 17`。

玩家 bust 或 surrender 後玩家已無有效手牌，dealer 不再抽牌，round 直接進入 resolve。

底牌是否翻開屬 presentation 決定（預設翻開以維持演出一致），但無論翻或不翻都不得改變已判定的 outcome。

---

## 6. Outcomes

建議 canonical outcome IDs：

```text
PLAYER_BLACKJACK
DEALER_BLACKJACK
PLAYER_WIN
DEALER_WIN
PLAYER_BUST
DEALER_BUST
PUSH
PLAYER_SURRENDER
```

Presentation 使用這些 ID 取得 L2 reaction，但不得重算 outcome。

---

## 7. Betting

下注交易欄位、commit 時點、settlement credit 與 exactly-once 語意以 `specs/002_CORE_TRANSACTION_AND_DEAL_FLOW.md` 為準。

BetLedger 至少管理：

```text
available_chips
selected_bet
committed_bet
minimum_bet
maximum_bet
```

規則：

- PLACE_BET 只改 `selected_bet`；DEAL 成功時才扣 `available_chips` 並建立 `committed_bet`。
- Bet 必須在 Initial Deal 前合法。
- 同一局 payout 只能套用一次。
- DOUBLE 不可讓籌碼變負數。
- SURRENDER refund 只能套用一次。
- Round 結束後必須可清楚區分 committed bet 與新的可用籌碼。
- 籌碼與 bet 一律為整數；當賠付計算產生非整數結果時（例如 3:2 賠率遇到奇數 bet），取整方向由 House Rules 決定，實作不得自行決定，見 `specs/000_HOUSE_RULES_DECISION.md` §G。

### Outcome Settlement Credit Mapping

Credit 包含應返還本金；不是只表示淨利。

| Outcome ID | Settlement credit | 說明 |
| --- | --- | --- |
| `PLAYER_BLACKJACK` | `committed + ceil(committed × 3 / 2)` | 玩家 natural，dealer 非 natural |
| `DEALER_BLACKJACK` | `0` | dealer natural，玩家非 natural |
| `PLAYER_WIN` | `committed × 2` | 一般比大小玩家勝 |
| `DEALER_WIN` | `0` | 一般比大小 dealer 勝 |
| `PLAYER_BUST` | `0` | 玩家爆牌，立即 resolve |
| `DEALER_BUST` | `committed × 2` | dealer 爆牌 |
| `PUSH` | `committed` | 平手退回本金 |
| `PLAYER_SURRENDER` | `ceil(committed / 2)` | 玩家投降 |

DOUBLE 之後 committed bet 為原 bet 的兩倍，上表所有倍率皆以 committed bet 為基數計算。

---

## 8. Deterministic Testing

DeckShoe 必須能在 test mode 注入固定牌序；index `0` 是下一張抽出的牌。

例如：

```text
player: A, K
 dealer: 10, 7
```

不可用隨機洗牌來驗證 edge cases。

Runtime 洗牌使用 Godot `RandomNumberGenerator`，採 Fisher-Yates。每局記錄 `round_id`、`shoe_id`、該 Shoe 的 `shuffle_seed` 與 `draw_index_at_round_start`；單機 prototype 不需要 CSPRNG 或 provably-fair 機制。中途耗盡時的退款與恢復規則見 specs/002 §5。

---

## 9. Rules That Require Approval

- Number of decks。
- Shuffle / penetration。
- Dealer soft 17。
- Blackjack payout。
- DOUBLE legality。
- SURRENDER type / timing / refund。
- Dealer hole-card behavior。
- Split／Insurance（目前 out of MVP）。
