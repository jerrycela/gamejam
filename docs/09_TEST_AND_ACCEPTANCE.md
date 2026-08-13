# 09 - Test and Acceptance

## 1. Test Pyramid

```text
Pure logic tests
→ Round-state tests
→ Godot scene integration tests
→ Screenshot / media tests
→ Human playtest
```

先保證規則，再保證畫面。

單元測試框架定案為 gdUnit4，agent 不得自行改用 GUT 或手寫 assert。Godot 版本與 gdUnit4 版本必須在首次建置時釘選並記錄於 PROJECT_STATE.md，之後不得隱性升級。

本機已釘選並驗證的 pure-logic headless 執行方式：

```text
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
  -s addons/gdUnit4/bin/GdUnitCmdTool.gd \
  -a res://tests -c --ignoreHeadlessMode
```

`--ignoreHeadlessMode` 只適用於不依賴 UI input transport 的 pure logic／state tests。需要模擬滑鼠、鍵盤或觸控輸入的 scene tests 必須改用可提供 display/input 的測試環境，不得以此 flag 假裝完成 UI input 驗收。

所有 acceptance criteria 中的「tests pass」一律以測試執行的 exit code 判定，不得由 agent 自行宣告通過。

---

## 2. HandEvaluator Cases

```text
10 + 8 = 18
K + 8 = 18
A + 7 = soft 18
A + 7 + 9 = hard 17
A + A + 9 = soft 21
A + A + 9 + 9 = 20
10 + 6 + 8 = bust
A + K initial two cards = blackjack
A + K after more than two cards != natural blackjack
```

---

## 3. Round Cases

- Player natural blackjack。
- Dealer natural blackjack。
- Both natural according to approved rule。
- Player HIT to 21。
- Player HIT bust。
- Ace downgrade。
- STAND, Dealer draws。
- Dealer bust。
- Push。
- Round resolves exactly once。
- Next round resets all temporary state。

Core round tests 必須使用 `specs/002_CORE_TRANSACTION_AND_DEAL_FLOW.md` 定義的 top-first injected shoe，並對每個案例明列：starting chips、selected bet、牌序、player intent、每一步 state、outcome、settlement credit 與 ending chips。

至少包含以下精確案例：

| Given | When | Then |
|---|---|---|
| chips 1000, bet 100 | commit + PLAYER_WIN | available chips 1100 |
| chips 1000, bet 100 | commit + DEALER_WIN | available chips 900 |
| chips 1000, bet 100 | commit + PUSH | available chips 1000 |
| chips 1000, bet 25 | commit + PLAYER_BLACKJACK | credit 63, available chips 1038 |
| chips 1000, bet 25 | commit + PLAYER_SURRENDER | credit 13, available chips 988 |
| chips 1000, bet 100 | commit + DOUBLE + PLAYER_WIN | credit 400, available chips 1200 |
| top-first `P:A, D:A, P:K, D:K` | initial deal + peek | `PUSH` |
| top-first `P:10, D:A, P:9, D:K` | initial deal + peek | `DEALER_BLACKJACK`，不可 surrender |
| player 11, next card 10 | HIT | total 21，自動進 `DEALER_TURN` |

---

## 4. DOUBLE / SURRENDER

依批准 House Rules 測：

- legal／illegal state。
- insufficient chips。
- bet update exactly once。
- one card only after DOUBLE。
- correct surrender refund。
- no further action after surrender。
- odd committed bet 依 specs/002 的 credit 公式向玩家方向進位。

---

## 5. State Integrity

不得發生：

```text
PLAYER_TURN and DEALER_TURN both active
round result applied twice
player action accepted during blocking L2
new round starts with old hand
media failure leaves permanent HOLD
UI says enabled while core says illegal
late presentation completion advances an already timed-out transition
duplicate commit / DOUBLE / refund / settlement changes chips twice
```

DeckShoe boundary tests另驗證：remaining cards `19` 在下一局前 reshuffle、`20` 不 reshuffle、同一 Shoe 的 `shuffle_seed + draw_index_at_round_start` 可重現該局抽牌位置，以及 round 中途耗盡時全額返還 committed bet 且不靜默洗牌。

---

## 6. L1 QA

自動／半自動：

- Button state reflects legal actions。
- Text values update。
- Hit areas match visual bounds。
- No overlap at target viewports。
- Focus／pressed／disabled variants exist。

人工：

- Action priority clear。
- Chips／Bet readable。
- Dealer hand and Player hand not confused。
- One-handed portrait use feels comfortable。

---

## 7. L2 QA

- Correct event triggers correct feedback。
- Blocking flag is correct。
- Fallback always returns control。
- Result reaction never changes outcome。
- No wrong Win/Lose reaction。
- No duplicate animation from repeated input。

---

## 8. L3 QA

- Loop does not visibly jump beyond accepted tolerance。
- L3 never intercepts input。
- L2 overlay/replacement returns to correct loop。
- Progression visual change does not alter rules。

---

## 9. Visual Regression

對已批准 screen 保存 baseline screenshot：

```text
reference_1080x1920
narrow_portrait
wide_portrait
```

每次 Figma sync 後比較：

- geometry。
- spacing。
- typography。
- colors。
- component variants。
- crop。

像素差異是檢查線索，不自動代表錯誤；最終由人工批准。

---

## 10. First Vertical Slice Definition of Done

- House Rules approved for prototype。
- Complete round playable。
- HIT / STAND / DOUBLE / SURRENDER correct。
- Dealer turn correct。
- Chips correct。
- Deterministic tests pass。
- L1 components independent。
- L2 placeholder events correct。
- L3 placeholder loop stable。
- No blocker runtime error。
- Human confirms basic UX is understandable。
