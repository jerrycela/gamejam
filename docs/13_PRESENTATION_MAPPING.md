# 13 - Presentation Mapping

## 1. Purpose

本文件是 `docs/03_INTERACTION_CONTRACTS.md` 要求的 Presentation Spec 登記表——每個會觸發演出的事件，必須標註 `blocking` 與 `fallback_duration_ms`（格式見 `docs/03_INTERACTION_CONTRACTS.md:112-117`）。

- 本表與程式碼常數是**同一份契約的兩個面**，必須一致。`specs/003_LAYERED_PRESENTATION_PIPELINE.md` 的驗收條件 `L2-5` 會核對兩者。
- `fallback_duration_ms` 是**逾時上限（安全網）**，不是動畫時長。它的作用是在演出卡住或素材載入失敗時，保證 HOLD 一定會在有限時間內解除（`docs/03_INTERACTION_CONTRACTS.md:142-149`）。
- 定值原則：**明顯高於預期演出時間，但低於玩家會認為當機的時間**。實作階段若實測演出時間逼近上限，應調高上限而非縮短動畫；若遠低於上限，可回頭收斂。
- **調整必須同時改本表與程式碼常數，並以 changelog 或 spec revision 記錄**，不得只改其中一邊、也不得在 code 中悄悄改動。

## 2. Mapping

| Event | blocking | fallback_duration_ms | 程式碼常數 | 依據 |
|---|---|---|---|---|
| Deal card（initial deal 四張連續發牌） | `true` | `1500` | `PresentationController.FALLBACK_DEAL_CARD_MS` | `docs/03_INTERACTION_CONTRACTS.md:99`；數值由 `specs/003` Open Questions 已裁決事項 #1 定案 |
| Dealer hole card reveal | `true` | `1200` | `PresentationController.FALLBACK_DEALER_HOLE_REVEAL_MS` | `docs/03_INTERACTION_CONTRACTS.md:100`；同上 |
| Ambient / idle glow（L3 loop 本身） | `false` | 不適用 | 無（非 blocking 不需逾時上限） | `docs/03_INTERACTION_CONTRACTS.md:107-109` |

四張連續發牌的逾時上限高於單張翻牌，因為該演出本身較長。

## 3. 範圍

本表目前只登記 `specs/003` 範圍內的 2 個 blocking 與 1 個 non-blocking 事件。

`docs/03_INTERACTION_CONTRACTS.md` §4 事件目錄中的其餘事件**尚未登記**，依 `specs/003` 的 Out of Scope 刻意排除；那些事件在本規格範圍內可沿用既有 placeholder，但不要求本規格驗收。新增事件時必須同時補本表與對應的程式碼常數。

## 4. 實作邊界

- 常數由 `scripts/presentation/presentation_controller.gd` 持有，**不放進 `scripts/core/`**。`RoundController` 沒有計時器，從它的視角「演出正常播完」與「逾時 fallback」是同一件事——都是呼叫同一個 `complete_presentation(token)`。讓規則層知道演出節奏會污染分層邊界（`AGENTS.md` §6 跨層引用禁令的同向推論）。
- exactly-once completion guard **由 `RoundController` 單獨持有**，`PresentationController` 只呼叫 `complete_presentation()` 並依回傳布林值反應。逾時與正常完成競爭同一個函式，先到者贏、後到者只留診斷訊號、不得再推進 state。**不得在演出層重新實作這個保證**——同一個性質有兩個真源，遲早會分岔。

## 5. Verification Log

| 日期 | 查核方式 | 結果 |
|---|---|---|
| 2026-08-13 | 直接讀 `scripts/presentation/presentation_controller.gd:23-24` | `FALLBACK_DEAL_CARD_MS = 1500`、`FALLBACK_DEALER_HOLE_REVEAL_MS = 1200`，與本表一致。兩者皆為 `const`，非散落的 magic number。 |
