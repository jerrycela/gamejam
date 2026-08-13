# 003 - Layered Presentation Pipeline

Status: DRAFT

Version: 0.2.1

## Goal

證明 L1/L2/L3 分層架構本身可以端到端運作 — 不是證明「能玩完一局 21 點」。Blackjack 規則是驗證載體，本規格要求的是三個獨立、各自可核對的證明：

1. **L1 — 元件化管線成立**：Figma component → Godot Theme／scene 的同步確實發生，且 Godot 端是原生 Control 組合，不是整張圖。
2. **L2 — 演出契約成立**：`presentation_token` exactly-once guard、input barrier、fallback timeout 依 `docs/03_INTERACTION_CONTRACTS.md` 運作，`PresentationController` 不自行猜下一個 state。
3. **L3 — 分層本身成立**：scene tree 固定為 `L3Root` 最底、`L2Root` 中、`L1Root` 最高；L3 持續 loop、可被 L2 暫時 overlay／取代後恢復、永不攔截輸入。

本規格**不修改**、**不推翻** `specs/001_FIRST_VERTICAL_SLICE.md` 的任何 Non-Goal，包含「Figma pixel-perfect sync」——該項排除的是像素級對齊保真度標準，不排除本規格要求的元件化管線本身（`AGENTS.md:32` 已把「Figma 中已批准的 Component／Screen」列為 source-of-truth 第 4 項，排在 Godot implementation 之上）。

## Player Behavior

不適用。本規格不新增或改變玩家可執行的 Blackjack 動作；玩家行為仍以 `specs/001` Task 5 與 `specs/002` 為準。本規格只規定「同一套既有動作在跑過 RoundController 時，L1/L2/L3 三層各自要留下什麼可核對證據」。

## Game Rules

不適用。牌規、下注交易與 settlement 語意維持 `docs/02_BLACKJACK_RULES.md`、`specs/000_HOUSE_RULES_DECISION.md`、`specs/002_CORE_TRANSACTION_AND_DEAL_FLOW.md` 現狀，本規格不新增或修改任何規則判斷。

## Valid States

沿用 `docs/01_GAME_AND_LAYER_SPEC.md:37-48` 的六狀態機（`BETTING / INITIAL_DEAL / PLAYER_TURN / DEALER_TURN / RESOLVE_ROUND / ROUND_END`），本規格額外要求狀態機必須完整跑滿一整圈（`BETTING → ... → ROUND_END → NEXT_ROUND → BETTING`）才算三個證明成立——只跑到 `RESOLVE_ROUND` 不足以驗證 L3 loop 的「暫時取代後恢復」與 L1 的「下一局重置」。

## Interaction Events

沿用 `docs/03_INTERACTION_CONTRACTS.md` §4 canonical event IDs 與 §5 Interaction Matrix，不新增事件。本規格額外要求：

- 每個在本規格範圍內觸發的 L2 event，必須依 `docs/03_INTERACTION_CONTRACTS.md:112-117` 的格式在 Presentation Mapping 記錄 `blocking: true/false` 與 `fallback_duration_ms`（見「L2 Behavior」）。
- `presentation_token` 的 exactly-once completion guard（`docs/03_INTERACTION_CONTRACTS.md:138`）必須對本規格觸發的每一個 blocking event 生效，不只是既有測試涵蓋的子集。

---

## L1 Behavior — Proof 1: Component Pipeline

### 需求

1. Figma component 必須先在 `pingliu@cela-tech.com`（`CELA International Corp.`，Full 席位，`docs/12_FIGMA_COMPONENT_MANIFEST.md:17`）帳號下的 design file `vufbRMFF4rpBt6W1jedHxb` 中建立、標註 Stable ID 並取得 Human Visual Approval，才能進入 Godot 同步。
2. Godot 端對應 scene 必須是 `docs/05_FIGMA_TO_GODOT.md:66-74` 列出的獨立 `.tscn`，文字一律用 `Label`／`RichTextLabel`（`docs/05_FIGMA_TO_GODOT.md:116-119`），不得把文字烙進圖片。
3. 完整畫面必須是 `docs/05_FIGMA_TO_GODOT.md:29-51` 定義的 scene tree 組合，不可用單一整張圖／單一 `TextureRect` 覆蓋畫面。
4. Component Manifest（`docs/12_FIGMA_COMPONENT_MANIFEST.md`）每個進入本規格範圍的元件都要填實 `figma_node_id`、`approved_version`、`godot_scene`、`last_reviewed`，`status` 由目前現況（`PENDING_CREATE`／`HUMAN_APPROVAL_REQUIRED`）更新為已同步版本，非全部從 `PENDING_CREATE` 起算——`BTN_ACTION`、`BTN_DEAL`、`CARD_FACE` 在 Figma 端已有既有進度，見「本規格的 Figma 元件範圍」。

### 本規格的 Figma 元件範圍

`docs/12_FIGMA_COMPONENT_MANIFEST.md` 目前列管 11 個元件，現況並非全數未建立：`BTN_ACTION`（node `5:2`）與 `BTN_DEAL`（node `9:17`）已在 Figma 建立、狀態為 `DRAFT`／`HUMAN_APPROVAL_REQUIRED`，`CARD_FACE` 在 Figma `05 Card` page 亦已有實體（`Suit × Orientation` 共 8 個 symbol）但 manifest 尚未回填 node id；其餘 7 個才是真正的 `PENDING_CREATE`（依據：`docs/12` Verification Log 第二筆，2026-08-13 以 `get_metadata(fileKey, nodeId)` 直接查 node 核實，取代已作廢的第一筆「未帶 nodeId 頁面列表」誤判）。11 個一次做完不是證明「管線」所必須；證明管線只需要讓 `docs/05_FIGMA_TO_GODOT.md:13-24` Mapping Strategy 表中會產生不同實作決策的路徑，各至少被實際走過一次。本規格選定 **4 個元件**：

| component_id | 對應的 Mapping Strategy 路徑 | 選擇理由 |
|---|---|---|
| `BTN_ACTION` | Variant → Theme type variation | Figma 端已由先前 Codex 工作建立（node `5:2`，`Action × State` 16 個 symbol），現由 `figma-slice` 進行 Visual Review Gate 驗收（非新建）；`Action × State` 兩軸 variant 是本專案唯一需要 Theme type variation 的互動元件，銜接既有進度而非重做 |
| `CARD_FACE` | Color/Typography variable → Theme resource（花色色彩、點數字型） | Figma 端已有實體（node `11:84`，`05 Card` page），manifest 尚待回填 node id 與審核狀態，非從零開始；結構為 `Suit`(4) × `Orientation`(2) = 8 個 variant symbol，`Rank` 是 component 的 TEXT property、不是 variant 軸（若 Rank 也做成 variant 會是 4×13×2=104 組合，Figma 端刻意避開）；`Suit × Orientation` variant 加上 `Rank` text property 的組合，是本專案唯一需要「同一 scene、Theme variant 與動態文字並存」的元件，能驗證 Theme resource 而非逐一 hardcode |
| `PANEL_ACTION_BAR` | Auto Layout → `Container` | 目錄中唯一以「排列其他元件」為核心語意的元件（`docs/04_VISUAL_ENGINEERING_FIGMA.md:136`），是驗證 Figma Auto Layout 對應 Godot `Container`/anchors 而非逐一手動定位的唯一候選；同時直接對應 `docs/09_TEST_AND_ACCEPTANCE.md:116` 的「Button state reflects legal actions」L1 QA 項目 |
| `VALUE_TOTAL` | Dynamic text → `Label` | `Soft/Hard/Bust` variant 同時牽動文字內容與 `color.result.*` token 切換，是目錄中「動態文字＋動態顏色 token」耦合最緊的元件，比 `VALUE_CHIPS`／`VALUE_BET`（純數字）更能驗證 Dynamic text 路徑 |

`Radius/border → StyleBoxFlat` 與 `Stretchable panel → NinePatchRect` 兩條路徑不另立元件驗證：`BTN_ACTION` 與 `PANEL_ACTION_BAR` 的背板天然會用到 `StyleBoxFlat`，額外指定專屬元件無助於證明管線、只會擴大範圍。`Icon → Texture2D` 路徑本規格不驗證（本規格範圍內元件皆無獨立 icon 需求）。`Full visual screen → composition` 路徑由「L1 Behavior 需求 #3」的 scene tree 組合驗收覆蓋，不需要額外 Figma 節點。

其餘 7 個元件（`BTN_DEAL`、`CARD_BACK`、`HAND_DEALER`、`HAND_PLAYER`、`VALUE_CHIPS`、`VALUE_BET`、`STATUS_RESULT`）**不在本規格範圍**——其中 `BTN_DEAL` 已在 Figma 建立（node `9:17`，`DRAFT`／`HUMAN_APPROVAL_REQUIRED`），其餘 6 個維持 `docs/12` 現狀 `PENDING_CREATE`；本規格通過後，其餘 7 個元件由後續 spec 一次納入，非永久排除（見 Open Questions 已裁決事項 #4）。

---

## L2 Behavior — Proof 2: Presentation Contract

### 需求

1. `RoundController` 必須實作 `docs/plans/2026-08-13-round-controller.md` Task 8 定義的 `begin_presentation(token)` / `complete_presentation(token)`：非空、單一 active token、exactly-once completion guard，且遲到或不匹配的 completion 不得再次推進 state 或解鎖 input barrier。
2. `PresentationController` 收到 blocking event 時觸發 `ActionBar.disabled = true`（`docs/03_INTERACTION_CONTRACTS.md:126`）；正常完成或 `fallback_duration_ms` timeout 後，由 `RoundController` 決定下一組合法 action，`ActionBar` 只反映該結果——`PresentationController` 不得自行推測。
3. 本規格範圍內至少涵蓋一個完整回合會觸發的 blocking 與 non-blocking event 各一項，並在下表登記 mapping（沿用 `docs/03_INTERACTION_CONTRACTS.md:112-117` 格式）：

| Event | blocking | fallback_duration_ms | 依據 |
|---|---|---|---|
| Deal card（initial deal 四張連續發牌） | `true` | `1500` | `docs/03_INTERACTION_CONTRACTS.md:99` |
| Dealer hole card reveal | `true` | `1200` | `docs/03_INTERACTION_CONTRACTS.md:100` |
| Ambient/idle glow（L3 loop 本身） | `false` | 不適用 | `docs/03_INTERACTION_CONTRACTS.md:107-109` |

`fallback_duration_ms` 是**逾時上限（安全網）**，不是動畫時長本身：它的作用是在演出卡住或素材載入失敗時，保證 HOLD 一定會在有限時間內解除（`docs/03_INTERACTION_CONTRACTS.md:142-149`）。定值原則是「明顯高於預期演出時間，但低於玩家會感覺當機的時間」。四張連續發牌比單張翻牌演出更長，因此給較大值。這兩個數值已由專案負責人裁決（見 Open Questions「已裁決事項」#1），實作階段若實測演出時間逼近上限應調高、遠低於上限則可回頭收斂，調整需求以 changelog 或後續 spec revision 記錄，不得在 code 中悄悄改動。

4. Failure fallback 依 `docs/03_INTERACTION_CONTRACTS.md:142-149`：素材載入失敗時 log asset ID、改用文字／簡單 Tween fallback、有限時間內送出 `presentation_finished`、不得永久卡在 HOLD。

---

## L3 Behavior — Proof 3: Layering Itself

### 需求

1. `GameRoot` scene tree 必須固定為 `L3Root`（最底）→ `L2Root`（中）→ `L1Root`（最高），依 `docs/05_FIGMA_TO_GODOT.md:29-59`。
2. L3 內容持續 loop（等待玩家輸入期間不得停止或跳幀超出可接受容差）。
3. 至少一個 L2 event（本規格選定：dealer hole card reveal 之 dealer reaction）在演出期間 overlay 或暫時取代 L3 內容，演出結束後 L3 必須恢復到正確的 loop 狀態（不得停在 L2 演出前的最後一幀，也不得跳到錯誤的 progression 狀態）。
4. L3 節點永不攔截輸入：`L3Root` 及其子節點的 mouse/touch filter 必須設定為忽略，`ActionBar` 命中測試不得被 L3 節點擋住。
5. L3 的實際美術／progression 內容尺度**不在本規格範圍**（見 Out of Scope）；本規格只要求 L3 有結構插槽與中性 placeholder（沿用 `specs/001` Task 8 既有 placeholder 定義），可以是純色背景＋一個 idle loop 佔位動畫。

6. 「L2 overlay 結束後 L3 恢復正確 loop」的判準採**最小判準**：overlay 前後為同一個 loop 旗標／同一個 idle 動畫（已裁決，見 Open Questions #3）。此判準綁定於「L3 目前只有單一中性 placeholder、無 progression 狀態」的前提；後續 progression spec 一旦引入多重 L3 狀態，此判準必須重新定義，不可直接沿用。

---

## Cross-Layer Boundary Violations（禁止事項）

依 `AGENTS.md` §6 與 `docs/01_GAME_AND_LAYER_SPEC.md` §3，以下在本規格範圍內視為驗收失敗：

- L1 自行計算 Blackjack 勝負或修改 hand total（`AGENTS.md:57`）。
- L2 決定 outcome 或改變 settlement 結果（`AGENTS.md:71`）。
- L3 改變 Blackjack 規則或攔截玩家輸入（`AGENTS.md:82`，本文件「L3 Behavior」#4）。
- Dealer／背景素材被 `Button` 節點或 `HandEvaluator` 直接引用（`AGENTS.md:109`）。
- 任何完整畫面用單一扁平圖片呈現，而非多個 scene 組合（`AGENTS.md:103`）。

---

## Blocking / Fallback

見「L2 Behavior」需求 #2、#3、#4。本規格不新增 `docs/03_INTERACTION_CONTRACTS.md` 未定義的 blocking/fallback 機制，只要求既有機制在 RoundController Task 7-9 完成後對真實回合事件生效並可測。

## Edge Cases

- Fallback timeout 與正常 completion 幾乎同時發生時，exactly-once guard 必須只接受先到者，另一者只記錄 diagnostic（沿用 `docs/03_INTERACTION_CONTRACTS.md:138`，需有對應 gdUnit4 race-condition-style 測試，非計時器 flake）。
- L2 event 在 L3 loop 播放到一半時觸發：L3 必須能被安全中斷並在之後恢復，不得產生半幀殘留或黑屏。
- 玩家在 blocking L2 期間快速重複點擊 ActionBar：input barrier 生效期間 UI 事件必須被忽略，不得堆積成完成後連續觸發多次 action（沿用 `docs/09_TEST_AND_ACCEPTANCE.md:100` state integrity 項）。
- NEXT_ROUND 觸發時上一局的 L2 overlay 若仍在播放：必須等待其 completion 或 fallback 後才視為 ROUND_END 完全結束，不得讓新一局的初始發牌與尚未結束的上一局演出重疊。

## Out of Scope

- **L3 progression 內容尺度**（美術風格、敘事、內容分級）——另立獨立 spec，本規格只交付結構與中性佔位素材（見「L3 Behavior」#5）。
- `specs/001` 已列的全部 Non-Goals（Split、Insurance、Side bets、Backend、Multiplayer、Story progression、Live AI generation、final art、Figma pixel-perfect sync）——本規格不重新開放，也不涉及。
- 4 個以外的其餘 7 個 Figma 元件（`BTN_DEAL`、`CARD_BACK`、`HAND_DEALER`、`HAND_PLAYER`、`VALUE_CHIPS`、`VALUE_BET`、`STATUS_RESULT`）。
- Split / Insurance 相關的任何 L1/L2/L3 呈現。
- 除本規格「L2 Behavior」表列的 2 個 blocking 與 1 個 non-blocking event 之外，其餘 `docs/03_INTERACTION_CONTRACTS.md` §4 事件的 mapping／fallback 數值製作（可沿用既有 placeholder，但不要求本規格新驗收）。
- 本規格「L2 Behavior」表列 2 個 blocking event 以外，其餘尚未訂定的演出節奏數值（本規格範圍內的 `fallback_duration_ms` 已裁決，見 Open Questions #1）。

## Acceptance Criteria

### L1 — Component Pipeline

- [ ] `L1-1` `BTN_ACTION`、`CARD_FACE`、`PANEL_ACTION_BAR`、`VALUE_TOTAL` 四個元件在 Figma 取得 Human Visual Approval，`docs/12_FIGMA_COMPONENT_MANIFEST.md` 對應列的 `approved_version` 不為 `DRAFT`／`NOT_CREATED`，`status` 不為 `PENDING_CREATE`。
- [ ] `L1-2` 上述四元件各自對應獨立 `.tscn`（`docs/05_FIGMA_TO_GODOT.md:66-74` 路徑），Godot headless editor import 對這些 scene 回傳 exit code 0、無 parse error。
- [ ] `L1-3` 對四個 scene 逐一 grep／人工核對：不存在把 `VALUE_TOTAL`／`VALUE_CHIPS`／`VALUE_BET` 等動態文字烙進 texture 的節點；文字節點類型為 `Label` 或 `RichTextLabel`。
- [ ] `L1-4` `GameRoot` scene 由 `docs/05_FIGMA_TO_GODOT.md:29-51` 定義的多個子 scene 組合而成（可用 gdUnit4 scene tree 測試核對節點型別與階層），不存在覆蓋整個 viewport 的單一 `TextureRect`/`Sprite2D`。
- [ ] `L1-5` 三種 viewport screenshot QA 完成並經人工批准（`docs/09_TEST_AND_ACCEPTANCE.md:151-171`）：`reference_1080x1920` = `1080 × 1920`（9:16，`docs/01_GAME_AND_LAYER_SPEC.md:17-30` 既有基準）、`narrow_portrait` = `1080 × 2400`（20:9，現代長螢幕手機，壓測上下貼邊元件被拉開或裁切）、`wide_portrait` = `1200 × 1600`（3:4，平板直式，壓測中央留給 L3 的空間塌陷或操作列過度拉寬）。三個尺寸各壓測一種失效模式而非隨意取值（已裁決，見 Open Questions #2），截圖解析度固定後本項可機器核對（尺寸比對＋人工視覺批准雙軌）。
- [ ] `L1-6` `ActionBar`（`PANEL_ACTION_BAR` 實例）的按鈕 enabled/disabled 狀態在完整跑過一個回合（`BETTING → ... → ROUND_END → NEXT_ROUND`）期間，每個 state 切換點都與 `RoundController.legal_actions()` 一致（gdUnit4 scene test 或等效自動化，逐 state 斷言）。

### L2 — Presentation Contract

- [ ] `L2-1` `RoundController` 完成 `docs/plans/2026-08-13-round-controller.md` Task 8：`begin_presentation`/`complete_presentation` 對非空、單一 active token、exactly-once completion 皆有 gdUnit4 RED→GREEN 測試，測試以 exit code 判定通過（`docs/09_TEST_AND_ACCEPTANCE.md:27`）。
- [ ] `L2-2` 遲到或不匹配的 `complete_presentation` 呼叫不改變 state、不重複解鎖 `ActionBar`：至少一則 gdUnit4 測試模擬「fallback timeout 已推進 state 後，原始 completion 才抵達」並斷言其無效。
- [ ] `L2-3` Deal card 與 Dealer hole card reveal 兩個 blocking event 在演出期間 `ActionBar.disabled == true`，演出完成或 fallback timeout 後由 `RoundController` 而非 `PresentationController` 決定下一組合法 action（場景測試斷言呼叫來源）。
- [ ] `L2-4` 素材載入失敗路徑：模擬資源載入失敗，斷言 fallback 於 `fallback_duration_ms` 內送出 `presentation_finished`，不永久卡在 HOLD（對應 `docs/03_INTERACTION_CONTRACTS.md:142-149`）。
- [ ] `L2-5` 上表列出的 blocking/non-blocking／`fallback_duration_ms` mapping 已記錄在專案的 Presentation Mapping（沿用 `docs/03` 格式），且與程式碼常數一致（無 magic number 漂移）。

### L3 — Layering Itself

- [ ] `L3-1` `GameRoot` 子節點順序（或等效 z-index/CanvasLayer 設定）符合 `L3Root < L2Root < L1Root`（由下到上），由 gdUnit4 scene test 對節點樹結構斷言。
- [ ] `L3-2` `L3Root` 及其子節點 `mouse_filter`／`Control.MOUSE_FILTER_IGNORE`（或 2D 對應設定）為忽略輸入，`ActionBar` 命中測試在 L3 佔位素材疊加下仍可觸發（自動化 input 命中測試，非人工假設）。
- [ ] `L3-3` Dealer hole card reveal 觸發的 L2 overlay 結束後，L3 loop 恢復到正確狀態：依「L3 Behavior」#6 的最小判準，overlay 前後為同一個 loop 旗標／同一個 idle 動畫（可觀測訊號斷言），非停在最後一幀或跳到錯誤狀態；此判準綁定單一 L3 狀態前提，多重 progression 狀態出現時需重新定義。
- [ ] `L3-4` 完整跑兩個連續回合（`NEXT_ROUND` 後再跑一次 `BETTING → ROUND_END`），L3 loop 全程未中斷或需要人工介入重啟。
- [ ] `L3-5` L3 佔位素材為中性內容（不含 progression／內容尺度決策），依「Out of Scope」與 `specs/001` Task 8 既有 placeholder 定義核對。

### RoundController 前置需求（三個證明的共同依賴）

- [ ] `RC-1` `docs/plans/2026-08-13-round-controller.md` Task 7（stepped dealer turn）、Task 8（presentation input barrier）、Task 9（`NEXT_ROUND` and runtime shoe lifecycle）全部完成並通過 gdUnit4，exit code 判定。三者是 L1-6、L2-1~L2-3、L3-3~L3-4 的前置條件，不做完 Task 7-9 則三個證明都無法完整跑滿一個回合週期。
- [ ] `RC-2` Godot headless 啟動與 `docs/09_TEST_AND_ACCEPTANCE.md` 指定的 `res://tests` 全量測試 0 error/failure/flaky/skipped/orphan。
- [ ] `RC-3` `PROJECT_STATE.md` 更新反映 Task 7-9 完成狀態與本規格對應的驗收結果（依 `AGENTS.md` §11 執行者事後更新，非本規格自行修改）。

## Open Questions

以下 4 項在起草時列為待拍板事項，已由專案負責人裁決；保留理由與依據，供實作階段追溯，不再視為 open：

### 已裁決事項

1. **`fallback_duration_ms` 數值**（deal card 與 dealer hole card reveal 兩個 blocking event）——裁決：deal card = `1500`，dealer hole card reveal = `1200`。理由：`fallback_duration_ms` 是逾時上限（安全網），不是動畫時長，作用是保證演出卡住或素材失敗時 HOLD 一定會解除；定值原則為「明顯高於預期演出時間，但低於玩家會認為當機的時間」，四張連續發牌演出比單張翻牌長故給較大值。實作階段若實測演出時間逼近上限應調高而非縮短動畫，遠低於上限則可回頭收斂；已寫入「L2 Behavior」#3 表格與說明。
2. **`narrow_portrait` / `wide_portrait` 實際像素尺寸**——裁決：`reference_1080x1920` = `1080 × 1920`（9:16，`docs/01_GAME_AND_LAYER_SPEC.md:17-30` 既有基準）、`narrow_portrait` = `1080 × 2400`（20:9，現代長螢幕手機，壓測上下貼邊元件被拉開或裁切）、`wide_portrait` = `1200 × 1600`（3:4，平板直式，壓測中央讓給 L3 的留白塌陷或操作列過度拉寬）。理由：三個尺寸各自針對一種失效模式而非任意取值；截圖解析度固定後 `L1-5` 可機器核對，已寫入「Acceptance Criteria」`L1-5`。
3. **`L3-3` 的「正確 loop 狀態」判準**——裁決：採最小判準（overlay 前後同一個 loop 旗標／同一個 idle 動畫）。理由：目前 L3 只有中性 placeholder、無 progression 狀態，更嚴格的判準無對象可測；此判準綁定於「單一 L3 狀態」的前提，後續 progression spec 引入多重 L3 狀態時必須重新定義，不可直接沿用——已寫入「L3 Behavior」#6 與 `L3-3`。
4. **其餘 7 個 Figma 元件**（`BTN_DEAL`、`CARD_BACK`、`HAND_DEALER`、`HAND_PLAYER`、`VALUE_CHIPS`、`VALUE_BET`、`STATUS_RESULT`）——裁決：維持不在本規格範圍。理由：本規格目的是證明管線成立、不是完成視覺，管線一旦證明成立，其餘 7 個元件是重複勞動、風險低，可用單一後續 spec 一次涵蓋；其中 `BTN_DEAL` 已在 Figma 建立（node `9:17`，`DRAFT`／`HUMAN_APPROVAL_REQUIRED`），其餘 6 個仍為 `PENDING_CREATE`。本規格通過後，其餘 7 個元件由後續 spec 一次納入，**非永久排除**。
