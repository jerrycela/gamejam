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
- `specs/003_LAYERED_PRESENTATION_PIPELINE.md` approved（Status: APPROVED，version `0.2.1`）：驗證 L1 component pipeline／L2 presentation contract／L3 layering 三個各自獨立的證明，選定 4 個 Figma 元件（`BTN_ACTION`、`CARD_FACE`、`PANEL_ACTION_BAR`、`VALUE_TOTAL`）與 2 個 blocking + 1 個 non-blocking event 作範圍。19 條 Acceptance Criteria 逐條狀態見下方「specs/003 Acceptance Criteria Status」。
- Spectra 已安裝（`openspec/`、`.agents/skills/`、`.spectra.yaml`，commit `9263fce`），但治理層仍以 `AGENTS.md` 為準，Spectra 只承接文件產出格式；`spectra init` 在 `AGENTS.md` 最前面插入 29 行，`specs/003` 內 6 處行號引用已同步修正。

## Pending Decisions

- 待立獨立 spec：progression content、內容尺度、final art style（見 `AGENTS.md` §9）。L3 目前只有中性佔位（`L3_ROOM_BG_V001`、`L3_DEALER_IDLE_V001`），無 progression 內容。
- `docs/plans/2026-08-13-doc06-asset-structure-revision.md` 提案待人工核准：荷官與背景素材拆分、anti-infographic 規則改為產出後檢核清單。目前狀態：**待核准**，尚未生效。

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
- `RoundController`（`scripts/core/round_controller.gd`，`RefCounted`）完整六狀態機已實作並通過 `tests/core/test_round_controller.gd`（51/51 cases，commit `ea2ffa5`、`96d15c4`）：可跑滿 `BETTING → INITIAL_DEAL → PLAYER_TURN → DEALER_TURN → RESOLVE_ROUND → ROUND_END → NEXT_ROUND → BETTING` 一整圈，含 P-D-P-D initial deal、upcard peek／natural priority table、牌靴耗盡中途 abort/refund、HIT/STAND、DOUBLE、late SURRENDER、逐步（stepped）dealer turn、`begin_presentation`/`complete_presentation` exactly-once token guard（含 token 重用防護）、`NEXT_ROUND` 與 runtime 牌靴替換生命週期。對應 `docs/plans/2026-08-13-round-controller.md` Task 1–9 全部完成；Task 10（本文件更新）為當次工作項目。
- 場景樹已依 `docs/05_FIGMA_TO_GODOT.md:29-51` 建立：`scenes/game_root.tscn`（`L3Root`/`L2Root`/`L1Root` 分層）、`ui/components/action_button.tscn`、`ui/components/card_view.tscn`、`ui/theme/lsbj_theme.tres`（commit `526cc46`）。`GameRoot` 由多個獨立子節點組合，非單一整張圖（`tests/ui/test_game_root_composition.gd` 5/5 pass）。
- 美術素材 9 項已產出並進版控（commit `e1a9ddf`、`088d886`）：`L1_TABLE_FELT_V001`、`L1_CARD_BACK_V001`、`L3_ROOM_BG_V001`、`L3_DEALER_IDLE_V001`、6 張 `L2_DEALER_REACT_*`（`BLACKJACK`／`PLAYER_BUST`／`PLAYER_LOSE`／`PLAYER_WIN`／`PUSH`／`SURRENDER`），以及身分基準 `CHAR_DEALER_CANON_V001`（不進遊戲）。母帶存 `assets/source/image/`，runtime 用檔存 `assets/textures/`。
- Git repository 已有多個 commit（非零 commit）並推送至 `origin`（`https://github.com/jerrycela/gamejam.git`）`main` 分支；本檔更新前 `HEAD` 與 `origin/main` 一致，最新 commit `ca90161`。
- **進行中、尚未 commit**（截至本次查核時間點，另一 agent 正在同一 session 中即時修改）：`scripts/presentation/presentation_controller.gd`、`scripts/presentation/round_controller_node.gd`（`RoundController` 的 Node 適配器）、`tests/ui/test_presentation_controller.gd`、`tests/ui/test_round_controller_node.gd`。這是 L2（`PresentationController`）與 L1-6/L3-3/L3-4 所需前置工作，屬於 specs/003 範圍但**尚未完成**，狀態會持續變動，詳見「Current Verification」。

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
- [ ] P2 - `scenes/game_root.tscn` 內 L1 子節點目前使用固定 `offset_left`/`offset_top` 像素座標（實測：`game_root.tscn` 內 28 處 `offset_*`），違反 `docs/01_GAME_AND_LAYER_SPEC.md:29`「必須使用 anchors、containers 與安全區設計，不能依賴固定座標」→ 修正中，屬 `specs/003` `L1-5`（多視窗尺寸 QA）的前置條件，尚未動工。
- [ ] P2 - `scripts/core/round_controller.gd` 是 `RefCounted`，無法直接掛為場景節點腳本，需要 Node 適配器才能讓 `PresentationController` 等場景節點透過正常 scene-tree wiring 取得引用 → 刻意不改 core（維持純邏輯可 headless 測試的邊界）；`scripts/presentation/round_controller_node.gd` 為此適配器，**進行中、尚未 commit**，其對應測試 `tests/ui/test_round_controller_node.gd` 於本次查核時已 3/3 pass。
- [ ] P2 - 專案未內嵌 Inter 字型；`ui/theme/lsbj_theme.tres` 的字級（size／line-height）結構已依 Figma token 建立，但字族在 runtime 回退到 Godot 預設字型，非 Inter → 待補字型檔並在 Theme 綁定。
- [ ] P2 - `docs/plans/2026-08-13-doc06-asset-structure-revision.md`（荷官與背景素材拆分、anti-infographic 規則改為產出後檢核清單）提案**待人工核准**，尚未生效，不可假設已採用該修訂後的資產結構規則。
- [ ] P2 - gdUnit4 在 discovery 階段遇到 parse error（引用尚不存在的 class）時，Godot 會以 signal 11 崩潰並輸出 C++ backtrace，而非乾淨地回報 parse error。已於 2026-08-13 觀察到兩次，兩次皆伴隨 parse error。不影響綠燈時的驗收，但會讓 TDD 的 RED 階段輸出被崩潰堆疊淹沒、難以判讀失敗原因。

## Next Smallest Task

> 2026-08-13 校準：以下三項（`RoundController` 設計、initial deal 整合、耗盡 abort/refund）已完成，見「Implemented」。當次查核時另一 agent 正在同一 session 即時實作下列項目，本節反映**下一步**而非已完成項目。

1. 完成 `PresentationController`（`scripts/presentation/presentation_controller.gd`，進行中、未 commit）：`begin_deal_presentation`／`begin_dealer_hole_reveal_presentation`／fallback timer／asset-load-failure fallback，對應 `tests/ui/test_presentation_controller.gd`（查核時 9 個 test case、19 項斷言失敗，exit code 非 0，非 GREEN）。這是 `specs/003` `L2-3`、`L2-4`、`L2-5`、`L3-3`、`L1-6` 的共同前置條件。
2. 補齊 `PANEL_ACTION_BAR`（`21:38`）與 `VALUE_TOTAL`（`21:62`）的 Human Visual Approval（目前均為 `DRAFT`），並建立對應 `.tscn`（`res://ui/components/action_bar.tscn`、`res://ui/components/value_display.tscn` 目前皆不存在）；`BTN_DEAL` 因新增 `Label` text property 屬視覺契約變更，需重新核准（見「Visual Status」）。
3. 完成三種 viewport（`1080×1920`／`1080×2400`／`1200×1600`）screenshot QA 並取得人工批准，對應 `specs/003` `L1-5`；未開始。
4. 修正 L1 子節點固定像素座標為 anchors／containers（見「Known Problems」新增項）。

## Current Verification

- Godot executable: `4.7.1.stable.official.a13da4feb`。
- Headless editor import: exit code `0`。
- **查核時間點：本次更新時，於同一 session 內有另一 agent 正在即時修改 `scripts/presentation/` 與對應測試，以下數字是該時間點的快照，非穩定值，重新整理前請重新執行測試指令核實**（`docs/09_TEST_AND_ACCEPTANCE.md:20-22`：`/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gdUnit4/bin/GdUnitCmdTool.gd -a res://tests -c --ignoreHeadlessMode`）。
- gdUnit4 全量測試（`res://tests`）：查核時 **122 test cases，19 failures，0 errors／flaky／skipped／orphans，exit code `100`**（非 GREEN）。全部 19 項失敗集中在 `tests/ui/test_presentation_controller.gd`（`PresentationController` 尚未完成的 WIP，見「Implemented」與「Next Smallest Task」）；其餘 12 個測試檔全數 0 failure：
  - Core（`tests/core`）：85/85 pass（`test_hand_evaluator` 9、`test_deck_shoe` 7、`test_bet_ledger` 18、`test_round_controller` 51），0 errors／failures／flaky／skipped／orphans，單獨執行 `-a res://tests/core` 時 exit code `0`。
  - UI（`tests/ui`，扣除失敗中的 `test_presentation_controller.gd`）：28/28 pass（`test_game_root_layering` 5、`test_action_button_view` 5、`test_l3_root_mouse_filter` 2、`test_game_root_composition` 5、`test_round_controller_node` 3、`test_lsbj_theme_tokens` 5、`test_card_face_dynamic_text` 3）。
  - 若排除進行中、尚未 commit 的 `test_presentation_controller.gd`（單獨執行 `-a res://tests/core` + `-a res://tests/ui` 排除該檔）：113/113 pass，0 errors，exit code `0`。此為「基線功能（不含本次 WIP 的 L2 場景整合）」的驗證結果，**不等於**`specs/003` `RC-2` 要求的「`res://tests` 全量 0 error/failure」——`RC-2` 目前**未達成**，因為全量指令本身仍回傳 exit code `100`。
- **兩個真實存在、指向不同樹的結果，不要混為一談**：
  - **最後一次程式碼變更（commit `526cc46`，「feat: first Godot scenes」；其後的 commit 皆為文件變更，不影響測試結果）＝ 110/110 pass，0 errors／failures／flaky／skipped／orphans，exit code `0`**。該 commit 只含當時的 6 個 UI 測試檔（`test_action_button_view`／`test_card_face_dynamic_text`／`test_game_root_composition`／`test_game_root_layering`／`test_l3_root_mouse_filter`／`test_lsbj_theme_tokens`，共 25 case）+ 85 個 core case，尚不含 `test_round_controller_node.gd` 與 `test_presentation_controller.gd`（`git show --stat 526cc46` 可核對）。這是**可回滾的乾淨綠燈點**，不是憑空的過期數字。
  - **工作區（含另一 agent 正在寫的 `scripts/presentation/` WIP）＝ 122 test cases、19 failures、exit code `100`**，失敗全數集中在 `tests/ui/test_presentation_controller.gd`；`test_round_controller_node.gd`（3 case）已轉綠、其餘 110 個原有 case 仍全數維持 pass（85 core + 25 原 UI，見上），113 = 110 + 3。
  - 前一版本此欄記載「34/34」為過期快照（早於 `RoundController`／場景樹落地）。中途另有一個短暫、非穩定狀態：`test_round_controller_node.gd` 與 `test_presentation_controller.gd` 兩個測試檔案剛加入、對應實作（`RoundControllerNode`／`PresentationController`）尚未落地時，gdUnit4 discovery 階段出現 script parse error（`Identifier "RoundControllerNode" not declared`）並使 Godot 引擎以 signal 11 崩潰、輸出 C++ backtrace，而非乾淨回報測試結果；此狀態既非 `HEAD` 的 110/110，也非查核時的 122/19-failures，只是工作區演進過程中的一個瞬間。

## Visual Status

- Figma connector: **reconnected 2026-08-13**。`whoami` = `pingliu@cela-tech.com`，於 `CELA International Corp.`（org tier）持 **Full 席位**，具寫入權限。先前卡住的 View-only 來源為 `pingliu's team`（starter tier）。
- Figma component system 現況（依 `docs/12_FIGMA_COMPONENT_MANIFEST.md` §2，`specs/003` 選定的 4 個元件 + 已知進度的 `BTN_DEAL`）：
  - `BTN_ACTION`（`5:2`）：`approved_version = 1.0.0`，`status = APPROVED_PENDING_GODOT_SYNC`。**已通過 Human Visual Approval**（2026-08-13），視覺方向核准（賭桌綠底、金色主操作、Surrender 紅色系、Inter 字族），Godot 同步與 viewport QA 尚未完成。
  - `CARD_FACE`（`11:84`）：`approved_version = 1.0.0`，`status = APPROVED_PENDING_GODOT_SYNC`。同上，已通過 Human Visual Approval，Godot 同步與 viewport QA 尚未完成。
  - `BTN_DEAL`（`9:17`）：`approved_version = 1.1.0`，`status = HUMAN_APPROVAL_REQUIRED`。**待重新核准**——新增 `Label` text property（預設 `DEAL`，另一合法值 `NEXT ROUND`）屬視覺契約變更，先前的核准範圍不涵蓋此變更。`BTN_DEAL` 不在 `specs/003` 選定的 4 個元件內，但已在 Figma 建立。
  - `PANEL_ACTION_BAR`（`21:38`）：`approved_version = DRAFT`，`status = HUMAN_APPROVAL_REQUIRED`。尚未核准。
  - `VALUE_TOTAL`（`21:62`）：`approved_version = DRAFT`，`status = HUMAN_APPROVAL_REQUIRED`。尚未核准。
  - 其餘 6 個元件（`CARD_BACK`、`HAND_DEALER`、`HAND_PLAYER`、`VALUE_CHIPS`、`VALUE_BET`、`STATUS_RESULT`）：`status = PENDING_CREATE`，`specs/003` 範圍外。
- **查核方法警示**：2026-08-13 曾以不帶 `nodeId` 的 `get_metadata(fileKey)` 頁面列表誤判上述元件不存在，並一度錯誤地把 manifest 回退為 `NOT_CREATED`，已還原。判定 node 存在性一律直接查 nodeId，不可用頁面列表推論不存在（詳見 `docs/12` Verification Log）。
- Godot 端同步現況：`BTN_ACTION` → `ui/components/action_button.tscn`、`CARD_FACE` → `ui/components/card_view.tscn` 已建立且通過 scene 測試（見「Current Verification」）。`PANEL_ACTION_BAR` → `res://ui/components/action_bar.tscn`、`VALUE_TOTAL` → `res://ui/components/value_display.tscn` **尚未建立**（manifest 已登記路徑，實際檔案不存在）。
- Original Google Slides reference deck: 9/9 slides inspected；L1/L2/L3 and WAIT/HOLD/LOOP intent traced in `docs/11_REFERENCE_DECK_ANALYSIS.md`.
- Final Dealer reference: not yet approved（`CHAR_DEALER_CANON_V001` 為身分基準，刻意不進遊戲）。
- L1 assets: `BTN_ACTION`／`CARD_FACE` 視覺方向已核准（見上），三種 viewport screenshot QA 未完成。
- L2 assets: 6 張 `L2_DEALER_REACT_*` 已產出並進版控，尚未有 Human Visual Approval 紀錄。
- L3 assets: `L3_ROOM_BG_V001`、`L3_DEALER_IDLE_V001` 已產出並進版控，尚未有 Human Visual Approval 紀錄；內容為中性佔位，非 progression 內容（`docs/plans/2026-08-13-doc06-asset-structure-revision.md` 提案待核准，見「Pending Decisions」）。

## specs/003 Acceptance Criteria Status

> 依 `specs/003_LAYERED_PRESENTATION_PIPELINE.md`「Acceptance Criteria」逐條核對，依 `AGENTS.md` §11 由執行者事後更新。判準：核對現有測試檔（`tests/ui/`、`tests/core/test_round_controller.gd`）與「Current Verification」的實測結果，不確定者標「待驗證」，不猜測為已完成。

### RoundController 前置需求

| ID | 狀態 | 依據 |
|---|---|---|
| `RC-1` | **完成** | `docs/plans/2026-08-13-round-controller.md` Task 7（stepped dealer turn）、Task 8（presentation input barrier）、Task 9（NEXT_ROUND／shoe lifecycle）均有對應 gdUnit4 case 且全數 pass，見 `tests/core/test_round_controller.gd`（51/51 pass，commit `ea2ffa5`、`96d15c4`）。 |
| `RC-2` | **未達成** | `docs/09_TEST_AND_ACCEPTANCE.md` 指定的 `res://tests` 全量測試指令，查核時回傳 `122 test cases, 19 failures, exit code 100`，非 0 error/failure。失敗集中在進行中、尚未 commit 的 `tests/ui/test_presentation_controller.gd`（見「Current Verification」）。 |
| `RC-3` | **進行中（本次任務）** | 本文件更新即為 `RC-3` 的執行；本次更新完成後仍需在 `RC-2` 轉綠後再次核對是否需要修訂。 |

### L1 — Component Pipeline

| ID | 狀態 | 依據 |
|---|---|---|
| `L1-1` | **未達成（部分）** | `BTN_ACTION`、`CARD_FACE` 已 `1.0.0`／`APPROVED_PENDING_GODOT_SYNC`；`PANEL_ACTION_BAR`、`VALUE_TOTAL` 仍為 `DRAFT`／`HUMAN_APPROVAL_REQUIRED`（`docs/12` §2）。4 元件中 2 個未達成。 |
| `L1-2` | **未達成（部分）** | `BTN_ACTION`→`action_button.tscn`、`CARD_FACE`→`card_view.tscn` 已存在且 headless import 隨整體專案通過。`PANEL_ACTION_BAR`→`action_bar.tscn`、`VALUE_TOTAL`→`value_display.tscn` 檔案不存在（實測 `find ui -type f`）。 |
| `L1-3` | **待驗證（部分）** | `CARD_FACE` 有明確測試 `test_card_face_scene_has_no_texture_node_carrying_text`（pass，`tests/ui/test_card_face_dynamic_text.gd`）。`BTN_ACTION` 未見同等「非 texture」明確斷言，僅有 Label 內容／主題變體測試（`tests/ui/test_action_button_view.gd`）。`PANEL_ACTION_BAR`、`VALUE_TOTAL` 因 scene 不存在無法核對。 |
| `L1-4` | **完成** | `tests/ui/test_game_root_composition.gd` 5/5 pass：`GameRoot` 非扁平圖片、無單一 `TextureRect`/`Sprite2D` 覆蓋全螢幕、hand views 用 `CardFace` 元件、action bar 用 `ActionButton` 元件而非 texture。 |
| `L1-5` | **未達成** | 三種 viewport（`1080×1920`／`1080×2400`／`1200×1600`）screenshot QA 未見任何執行紀錄或截圖產出，未開始。 |
| `L1-6` | **未達成** | 需要真實 `ActionBar` scene 在完整回合（`BETTING → ... → ROUND_END → NEXT_ROUND`）中逐 state 反映 `RoundController.legal_actions()`，此依賴 `PresentationController`／`RoundControllerNode` 場景整合，查核時對應測試 `tests/ui/test_presentation_controller.gd` 為 WIP、未 GREEN。 |

### L2 — Presentation Contract

| ID | 狀態 | 依據 |
|---|---|---|
| `L2-1` | **完成（核心層）** | `RoundController.begin_presentation`/`complete_presentation` 對非空、單一 active token、exactly-once completion 均有 gdUnit4 case 且 pass（`test_begin_presentation_empties_legal_actions_and_rejects_player_commands`、`test_begin_presentation_rejects_empty_token_and_a_second_concurrent_token`、`test_complete_presentation_with_matching_token_restores_legal_actions` 等，`tests/core/test_round_controller.gd`）。 |
| `L2-2` | **完成（核心層）** | 遲到／不匹配 completion 不改變 state、不重複解鎖：`test_complete_presentation_with_mismatched_token_stays_blocked`、`test_late_completion_after_the_first_matching_token_already_unlocked_is_ineffective` 均 pass。此為 `RoundController` 核心層驗證；`ActionBar` 場景層的等效驗證屬 `L2-3`。 |
| `L2-3` | **未達成** | 需要 `PresentationController` 對真實 `ActionBar` 節點設 `disabled = true` 並由 `RoundController` 而非 `PresentationController` 決定下一組合法 action；查核時 `tests/ui/test_presentation_controller.gd` 對應 case 未 GREEN（WIP）。 |
| `L2-4` | **未達成** | 素材載入失敗 fallback（`presentation.report_asset_load_failure`）測試存在於 `tests/ui/test_presentation_controller.gd`，但該檔查核時未 GREEN。 |
| `L2-5` | **待驗證** | mapping 表已記錄於 `specs/003` L2 Behavior（Deal card `blocking=true`／`1500ms`、Dealer hole reveal `blocking=true`／`1200ms`、Ambient loop `blocking=false`）。程式碼常數 `PresentationController.FALLBACK_DEAL_CARD_MS`／`FALLBACK_DEALER_HOLE_REVEAL_MS` 是否與此一致，因該類尚在 WIP、對應測試未 GREEN，無法確認「無 magic number 漂移」已成立。 |

### L3 — Layering Itself

| ID | 狀態 | 依據 |
|---|---|---|
| `L3-1` | **完成** | `tests/ui/test_game_root_layering.gd` 5/5 pass：`L3Root < L2Root < L1Root` 節點順序與子節點組成皆有斷言。 |
| `L3-2` | **完成** | `tests/ui/test_l3_root_mouse_filter.gd` 2/2 pass：`L3Root` 及子節點忽略滑鼠、`ActionBar` 按鈕在 L3 疊加下仍保有預設 mouse filter（可命中）。 |
| `L3-3` | **未達成** | 需要 dealer hole card reveal 的 L2 overlay 結束後 L3 loop 恢復同一 loop 旗標／idle 動畫的可觀測斷言；此依賴 `PresentationController`，查核時對應測試未 GREEN。 |
| `L3-4` | **未達成** | 需要完整跑兩個連續回合（`NEXT_ROUND` 後再跑一次）且 L3 loop 不中斷的自動化驗證；未見對應測試檔案或 pass 紀錄。 |
| `L3-5` | **待驗證** | L3 佔位素材（`L3_ROOM_BG_V001`、`L3_DEALER_IDLE_V001`）已產出，依既有 placeholder 定義應為中性內容，但未見明確的「非 progression／內容尺度決策」核對紀錄（人工或自動化），標待驗證。 |

**摘要**：19 條中，**完成 6 條**（`RC-1`、`L1-4`、`L2-1`、`L2-2`、`L3-1`、`L3-2`）、**進行中 1 條**（`RC-3`，本次任務）、**待驗證 3 條**（`L1-3`、`L2-5`、`L3-5`）、**未達成 9 條**（`RC-2`、`L1-1`、`L1-2`、`L1-5`、`L1-6`、`L2-3`、`L2-4`、`L3-3`、`L3-4`）。僅供快速掃視，實際驗收請以上表逐條為準。
