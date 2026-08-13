# PROJECT STATE


## Confirmed Corrections

- Development methodology name: **SDD - Spec-Driven Development**.
- Figma baseline: enterprise paid account with full MCP read/write access.

> Codex 每次工作結束時更新。只記錄目前狀態，不重寫歷史。

## Pinned Versions

- Godot 版本：`4.7.1.stable.official.a13da4feb`
- gdUnit4 版本：`6.2.0`（tag commit `d18770221c2df4a3c991a42fdce7907df40eea75`）
- 釘選日期：`2026-08-13`

本機 Godot executable：`/Applications/Godot.app/Contents/MacOS/Godot`。

首次建置時由人工填入，之後不得隱性升級；docs/09 的測試指令以此處版本為準。

## Current Phase

`IMPLEMENTING`

## Current Goal

完成第一個 Blackjack Vertical Slice：可下注、發牌、HIT、STAND、DOUBLE、SURRENDER、Dealer turn、結果與下一局；L1/L2/L3 先用 placeholder。

## Confirmed Decisions

- Product: vertical Blackjack / 21 game.
- Runtime presentation: LAYER-1 / LAYER-2 / LAYER-3.
- UI components are independent, not a flattened screen image.
- Figma is visual source of truth.
- Godot is executable source of truth.
- Markdown specs are behavioral source of truth.
- Final runtime does not depend on Codex, Godot MCP, Figma MCP, or live image generation.
- House Rules recommended prototype profile approved by the project owner on 2026-08-13.
- Core transaction and deal-flow contract approved in `specs/002_CORE_TRANSACTION_AND_DEAL_FLOW.md`.
- Original Google Slides concept deck revision `yLVzGbN-jrqx7Q` reviewed slide-by-slide（9/9）；derived product intent recorded in `docs/11_REFERENCE_DECK_ANALYSIS.md`.

## Pending Decisions

- 待立獨立 spec：progression content、內容尺度、final art style（見 `AGENTS.md` §9）。

## Implemented

- Git repository initialized at the Knowledge Pack root（尚未 commit）。
- Minimal Godot project created for the 1080×1920 portrait reference viewport。
- gdUnit4 6.2.0 vendored under `addons/gdUnit4`。
- Godot 4.7.1 headless editor import completed with exit code 0。
- Typed `Card` value object implemented in `scripts/core/card.gd`。
- Pure `HandEvaluator` implemented with Ace downgrade、soft/hard、bust、natural blackjack 與 card count。
- `tests/core/test_hand_evaluator.gd`：9/9 cases pass，0 errors／failures／orphans。
- Pure `DeckShoe` implemented with top-first injected order、defensive array copy、explicit exhaustion、6-deck standard composition and seeded Fisher-Yates shuffle。
- Shoe round-start metadata captures `round_id`、`shoe_id`、`shuffle_seed` and `draw_index_at_round_start` without moving the cursor。
- Reshuffle query implements the approved exact boundary：remaining 20 = false，remaining 19 = true；DeckShoe never silently reshuffles。
- `tests/core/test_deck_shoe.gd`：7/7 cases pass，including complete 312-card composition and same-seed reproducibility。
- Canonical `BlackjackOutcome` defines all eight approved outcome IDs and validates external values before settlement。
- Pure `BetLedger` implements the approved 1000／10／500 prototype profile、selection、commit、DOUBLE、settlement、refund and NEXT_ROUND preparation。
- Bet transactions are guarded exactly once per `round_id`；invalid operations preserve state，odd Blackjack／surrender credits round upward，and bankroll resets only below the minimum bet at NEXT_ROUND。
- `tests/core/test_bet_ledger.gd`：18/18 cases pass，covering every specs/002 numeric example、insufficient chips、duplicate close paths and low-bankroll reset。

## Known Problems

- [x] Existing repository inspected；原始資料夾不是 Git／Godot project，現已於 Knowledge Pack root 建立基線。
- [x] P2 - docs/02 §2 `A + A + 9` 標為 evaluator 自定義 soft/hard，is_soft 語意未定 → 明定 is_soft 為「至少一張 Ace 以 11 計入 total」，docs/02 §2 與 docs/09 §2 該案例標為 soft 21。
- [x] P2 - docs/02 §8 只規範 test mode 牌序，runtime 洗牌 RNG/seed 未定義 → 指定 Godot RandomNumberGenerator／Fisher-Yates，並記錄 Shoe seed 與每局起始 draw index。
- [x] P2 - AGENTS.md §9 指向 specs/000 取 progression/敏感內容/美術風格，但該檔僅有牌規 → specs/000 加內容與美術方向佔位節，或改指 PROJECT_STATE.md Visual Status。
- [x] P2 - docs/01 §4 流程圖 DOUBLE 分支缺 bust 直接 RESOLVE 的線，與 docs/03 §5 矩陣不一致 → 流程圖補分支，矩陣不需動。
- [x] P2 - docs/02 §5 未定義玩家 bust/surrender 後 dealer 是否抽牌、是否翻底牌 → 該節補兩句明訂。
- [x] P2 - AGENTS.md §11 第 1 條「Run Godot」對 agent 不可執行 → 改為 headless parse check 加跑測試，實機執行留給人工驗收。
- [x] P2 - 整份藍圖未指定 Godot 版本號，GDScript/Tween API 各版本有差異 → 於 PROJECT_STATE.md 釘選版本並在 docs/09 引用。
- [x] P2 - docs/10 §5 風險表未涵蓋 Figma 企業帳號存取中斷，docs/04、05、08 §7 皆依賴該帳號 → 風險表加一列，降級路徑為手動 export 加 Component Manifest。
- [x] P2 - START_HERE.md 與 AGENTS.md §2 各自維護 read order 清單，易改一邊漏另一邊 → AGENTS.md §2 加一行註明完整 boot 清單以 START_HERE.md 為準。

## Next Smallest Task

1. Design and plan the minimal `RoundController` state authority from specs/001 Tasks 4–5 and specs/002 §§5–7。
2. Integrate injected `DeckShoe` and `BetLedger` for DEAL commit、P-D-P-D initial deal、round metadata and peek／natural resolution。
3. Add the defensive mid-round shoe-exhaustion abort/refund path before HIT、STAND、DOUBLE and SURRENDER flow expansion。

## Current Verification

- Godot executable: `4.7.1.stable.official.a13da4feb`。
- Headless editor import: exit code `0`。
- gdUnit4 core tests: `34/34` passed（HandEvaluator 9 + DeckShoe 7 + BetLedger 18），0 errors／failures／flaky／skipped／orphans，exit code `0`。
- UI／scene input tests: not started；不得由 pure-logic headless result推論為通過。

## Visual Status

- Figma connector: **reconnected 2026-08-13**。`whoami` = `pingliu@cela-tech.com`，於 `CELA International Corp.`（org tier）持 **Full 席位**，具寫入權限。先前卡住的 View-only 來源為 `pingliu's team`（starter tier）。
- Figma component system: **0 / 11 元件已建立**（2026-08-13 以 `get_metadata` 實地查核）。design file `vufbRMFF4rpBt6W1jedHxb` 目前僅有 page `0:1「00 Cover」` 與封面 frame `3:7`。`docs/12` 先前將 `BTN_ACTION`(`5:2`) 與 `BTN_DEAL`(`9:17`) 記為 `DRAFT` 屬誤記，該兩個 node 從未存在，已回退為 `NOT_CREATED`。視覺工作起點為從零建立元件。
- Original Google Slides reference deck: 9/9 slides inspected；L1/L2/L3 and WAIT/HOLD/LOOP intent traced in `docs/11_REFERENCE_DECK_ANALYSIS.md`.
- Final Dealer reference: not yet approved.
- L1 assets: not yet approved.
- L2 assets: not yet approved.
- L3 assets: not yet approved.
