# 000 - House Rules Decision

**Status:** `PROTOTYPE APPROVED`

這份文件完成前，Codex 不應完成最終 Blackjack rule implementation。

可先採 provisional profile 做技術 prototype，但必須由使用者勾選批准。

---

## A. Deck / Shoe

- [x] Number of decks: `6`
- [x] Shuffle rule: `penetration`
- [x] Reshuffle 門檻: `剩餘牌數低於 20 張時，於下一局開始前重洗`

任何情況下不得在一局進行中重洗。一局進行中若牌數不足以完成該局，視為實作錯誤，必須記錄錯誤而非靜默重洗。

Recommended prototype：

```text
6 decks
shuffle at prototype start or deterministic injected shoe in tests
reshuffle before next round starts when remaining cards < 20
```

---

## B. Dealer

- [x] Soft 17: `STAND`
- [x] Hole card: `US-style hole card`
- [x] US-style hole card 是否含 peek（dealer 明牌為 A 或 10 時先確認底牌）: `YES`
- [x] 若採 no-hole-card：DOUBLE 額外投入對上 dealer blackjack: `N/A（本 profile 採 US-style hole card）`

Recommended prototype：

```text
Dealer stands on soft 17
US-style hole card
peek enabled
```

---

## C. Blackjack Payout

- [x] Natural Blackjack payout: `3:2`
- [x] Player and Dealer both natural: `PUSH`

Recommended prototype：

```text
3:2
both natural = PUSH
```

---

## D. DOUBLE

- [x] Legal on: `any first two cards`
- [x] Requires enough chips: `YES`
- [x] One card then auto-stand: `YES`

Recommended prototype：

```text
any first two cards
requires enough chips
one card then auto-stand
```

---

## E. SURRENDER

- [x] Enabled in MVP: `YES`
- [x] Type: `late`
- [x] Refund: `50%`
- [x] Legal only before HIT and after initial deal: `YES`

Recommended prototype：

```text
late surrender
50% refund
only as first player decision
```

late surrender 的定義依賴 dealer 先完成 peek 且無 blackjack；若 dealer 為 natural，surrender 不成立，依 §C 結算。

---

## F. Out of MVP

- [x] Split confirmed out of first vertical slice。
- [x] Insurance confirmed out of first vertical slice。
- [x] Side bets confirmed out of first vertical slice。

---

## G. Bankroll

- [x] 起始籌碼: `1000`
- [x] Minimum bet: `10`
- [x] Maximum bet: `500`
- [x] 籌碼不足 minimum bet 時的處理: `prototype 重置為起始籌碼`
- [x] 非整數賠付取整方向: `無條件進位給玩家`

Recommended prototype：

```text
starting chips 1000
minimum bet 10
maximum bet 500
reset to starting chips when below minimum bet
round non-integer payout up in player's favor
```

---

## Prototype Approval

- [x] I approve the recommended prototype profile for implementation.

Approved by: `Project owner via Codex task`

Date: `2026-08-13`

Once approved, change status to:

`PROTOTYPE APPROVED`
