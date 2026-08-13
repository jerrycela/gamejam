# 12 - Figma Component Manifest

## 1. Purpose

本文件追蹤 Figma 視覺元件與 Godot runtime scene 的穩定映射。

- Figma design file: <https://www.figma.com/design/vufbRMFF4rpBt6W1jedHxb>
- Figma 是視覺定義的 source of truth；Godot scene 是 runtime implementation。
- `approved_version = DRAFT` 代表元件已建立、但尚未通過 Human Visual Approval。
- `status = PENDING_CREATE` 代表元件仍待建立，不可視為已批准或已同步至 Godot。
- `status = APPROVED_PENDING_GODOT_SYNC` 代表 Human Visual Approval 已完成、`approved_version` 已取得正式版本號，但 Godot scene／Theme 同步與三種 viewport screenshot QA **尚未完成**。此狀態滿足 `specs/003` 的 `L1-1`，但不滿足 `L1-2` ~ `L1-5`；Godot 端完成同步並通過 QA 後才可再往下推進狀態。
- **填寫規則**：`figma_node_id` 與 `DRAFT` 只能在該 node 已實際存在於 Figma file 時填寫。
- **存在性查核規則（重要）**：判定某個 node 是否存在，**必須用 `get_metadata(fileKey, nodeId)` 直接查該 node**。
  不得用不帶 `nodeId` 的 `get_metadata(fileKey)` 頁面列表作為「不存在」的依據——該列表已證實會回傳不完整的結果（見下方 Verification Log 2026-08-13 第二筆）。
  否定型結論（「這個 node 不存在」）必須附上實際查詢過的 nodeId 與回傳內容，不能只說「沒看到」。
- **Component property 查核規則**：`get_metadata` 只回傳結構（node id／型別／座標／尺寸），**不顯示 component property**。
  要確認某個 property 是否存在、綁在哪個節點上，必須用 `get_context_for_code_connect(fileKey, nodeId)`，
  或以 `use_figma` 讀該節點的 `componentPropertyReferences`。用 `get_metadata` 查不到 property 不構成「property 不存在」的證據。

### Verification Log

| 日期 | 查核方式 | 結果 |
|---|---|---|
| 2026-08-13 | Figma MCP `get_metadata(fileKey=vufbRMFF4rpBt6W1jedHxb)`，**未帶 nodeId** | **此筆結論為誤，已作廢，保留供追溯。** 當時回傳的 page 列表只有 `0:1「00 Cover」`，據此誤判 `5:2` 與 `9:17` 不存在，並錯誤地把 `BTN_ACTION` / `BTN_DEAL` 回退為 `NOT_CREATED`。錯誤成因：把不完整的頁面列表當成檔案全貌，用「列表裡沒看到」推論「不存在」。 |
| 2026-08-13 | Visual Review Gate 六項自檢（`docs/04:227-238`），逐元件以 `get_design_context` 複驗 | `BTN_ACTION`(`5:2`)、`BTN_DEAL`(`9:17`)、`CARD_FACE`(`11:84`) **六項全過**（Stable ID／Variants／Auto Layout／文字非 rasterized／Safe area／無多餘背景）。三者觸控尺寸 210×64、320×72、136×190 皆超過 `touch/min` 44px。Design token 四類（color／typography／spacing／motion）對照 `docs/04:70-116` **全數覆蓋無缺項**：`Primitives` 17、`Color` 23（`var(--lsbj-color-*)`）、`Dimension` 19、Text style 7、Effect style 1；motion 以 `02 Foundations` 文件形式記錄（Figma variable 不支援 duration／easing 型別）。**Gate 自檢通過不等於 Human Visual Approval**，三者 `approved_version` 維持 `DRAFT` 直到人工在 Figma 核准。 |
| 2026-08-13 | Figma 寫入：補 token 缺口與修正硬編碼值 | 新增 `color/result/bust` = `#a83c43`（alias `red/600`，`VariableID:17:2`）與 `color/result/blackjack` = `#ffd36a`（alias `gold/400`，`VariableID:17:3`），補齊 `STATUS_RESULT` 所需的 5 種結果語意色（原僅有 win／lose／push）；兩者均 alias 既有 primitive，未新造 raw 值，並在 `02 Foundations` Colors/Semantic Grid 補上對應 swatch（`17:4`-`17:9`）以維持「每個 semantic token 都有 swatch」的既有慣例。`CARD_FACE` 8 個 variant 的 padding 由硬編碼 `14px` 改綁 `space/4`（16px），消除 `docs/05:80-96` Theme-First 要防的 token 漂移；已截圖複驗兩個 orientation 版面正常，並以 Rank 覆寫為 `"10"`（52 張牌中最寬 rank 字串）做最壞情況測試確認未裁切，測試 instance 已移除。 |
| 2026-08-13 | Figma MCP `get_metadata(fileKey, nodeId=11:84)`，**直接查 node** | `CARD_FACE` 存在。`11:84` = frame `L1/Card/Face`，內含 8 個 symbol（`Suit` = Club/Diamond/Heart/Spade × `Orientation` = Upright/Landscape，node `11:36`-`11:78`）。`Rank` 不是 variant 軸而是 component 的 TEXT property，由呼叫端動態帶入——若 `Rank` 也做成 variant，組合數為 4×13×2 = 104，遠超過可維護門檻。manifest `variants` 欄位已改為 `Suit / Orientation（variants）+ Rank（text property）` 以免誤導。 |
| 2026-08-13 | **Human Visual Approval** — 使用者於 Figma 檢視 `03 Action Button`／`04 Deal Button`／`05 Card` 三頁後核准 | `BTN_ACTION`(`5:2`)、`BTN_DEAL`(`9:17`)、`CARD_FACE`(`11:84`) 視覺方向獲核准，`approved_version` 由 `DRAFT` 推進為 `1.0.0`，`status` 改為 `APPROVED_PENDING_GODOT_SYNC`。核准範圍為**視覺方向**（賭桌綠 `#0c3b2e` 底、金 `#f5b942` 主操作、Surrender 走紅色系、Inter 字族），不含 Godot 同步與 viewport QA——那兩項屬 `specs/003` 的 `L1-2` ~ `L1-5`，尚未執行。此核准可逆：後續調整 token 會傳導至所有元件，不需重建。 |
| 2026-08-13 | Figma MCP `get_metadata(fileKey, nodeId=5:2)` 與 `get_metadata(fileKey, nodeId=9:17)`，**直接查 node** | 兩者**均存在**，原始 manifest 記錄正確，已還原。`5:2` = frame `L1/Button/Action`，內含 16 個 symbol（`Action` = Hit/Stand/Double/Surrender × `State` = Default/Pressed/Disabled/Focus，node `4:21`-`4:51`）。`9:17` = frame `L1/Button/Deal`，內含 4 個 symbol（`State` = Default/Pressed/Disabled/Focus，node `9:9`-`9:15`）。檔案另有 `01 Getting Started` / `02 Foundations` / `03 Action Button` / `04 Deal Button` / `05 Card` / `90 Utilities` 等 page 及一組 `var(--lsbj-color-*)` semantic color variables，均為既有成果。連線帳號 `pingliu@cela-tech.com`，於 `CELA International Corp.`（org tier）持 Full 席位，具寫入權限。 |

## 2. Component Manifest

| component_id | Figma component | figma_file_url | figma_node_id | approved_version | runtime_type | godot_scene | variants | last_reviewed | status |
|---|---|---|---|---|---|---|---|---|---|
| `BTN_ACTION` | Action Button | <https://www.figma.com/design/vufbRMFF4rpBt6W1jedHxb> | `5:2` | `1.0.0` | `native_control` | `res://ui/components/action_button.tscn` | `Action / State` | `2026-08-13` | `APPROVED_PENDING_GODOT_SYNC` |
| `BTN_DEAL` | Deal Button | <https://www.figma.com/design/vufbRMFF4rpBt6W1jedHxb> | `9:17` | `1.1.0` | `native_control` | `res://ui/components/deal_button.tscn` | `State`（variants）+ `Label`（text property `Label#24:0`，預設 `DEAL`，另一合法值 `NEXT ROUND`） | `2026-08-13` | `HUMAN_APPROVAL_REQUIRED` |
| `CARD_FACE` | Card Face | <https://www.figma.com/design/vufbRMFF4rpBt6W1jedHxb> | `11:84` | `1.0.0` | `native_control` | `res://ui/components/card_view.tscn` | `Suit / Orientation`（variants）+ `Rank`（text property） | `2026-08-13` | `APPROVED_PENDING_GODOT_SYNC` |
| `CARD_BACK` | Card Back | <https://www.figma.com/design/vufbRMFF4rpBt6W1jedHxb> | — | `NOT_CREATED` | `native_control` | `res://ui/components/card_view.tscn` | `Style` | — | `PENDING_CREATE` |
| `HAND_DEALER` | Dealer Hand Area | <https://www.figma.com/design/vufbRMFF4rpBt6W1jedHxb> | — | `NOT_CREATED` | `native_control` | `res://ui/components/hand_view.tscn` | `Count / Hidden Card` | — | `PENDING_CREATE` |
| `HAND_PLAYER` | Player Hand Area | <https://www.figma.com/design/vufbRMFF4rpBt6W1jedHxb> | — | `NOT_CREATED` | `native_control` | `res://ui/components/hand_view.tscn` | `Count` | — | `PENDING_CREATE` |
| `VALUE_TOTAL` | Hand Total | <https://www.figma.com/design/vufbRMFF4rpBt6W1jedHxb> | `21:62` | `DRAFT` | `native_control` | `res://ui/components/value_display.tscn` | `State` = `Hard / Soft / Bust`（variants）+ `Value`（text property） | `2026-08-13` | `HUMAN_APPROVAL_REQUIRED` |
| `VALUE_CHIPS` | Chips Counter | <https://www.figma.com/design/vufbRMFF4rpBt6W1jedHxb> | — | `NOT_CREATED` | `native_control` | `res://ui/components/value_display.tscn` | `Positive / Low / Zero` | — | `PENDING_CREATE` |
| `VALUE_BET` | Bet Counter | <https://www.figma.com/design/vufbRMFF4rpBt6W1jedHxb> | — | `NOT_CREATED` | `native_control` | `res://ui/components/value_display.tscn` | `Editable / Locked` | — | `PENDING_CREATE` |
| `STATUS_RESULT` | Round Result | <https://www.figma.com/design/vufbRMFF4rpBt6W1jedHxb> | — | `NOT_CREATED` | `native_control` | `res://ui/components/result_banner.tscn` | `Win / Lose / Push / Bust / Blackjack` | — | `PENDING_CREATE` |
| `PANEL_ACTION_BAR` | Action Bar | <https://www.figma.com/design/vufbRMFF4rpBt6W1jedHxb> | `21:38` | `DRAFT` | `native_control` | `res://ui/components/action_bar.tscn` | `Player State` = `Betting / PlayerTurnFirst / PlayerTurnDecided / RoundEnd / Blocking` | `2026-08-13` | `HUMAN_APPROVAL_REQUIRED` |

## 3. Review Gate

元件由 `PENDING_CREATE` 或 `HUMAN_APPROVAL_REQUIRED` 進入正式批准版本前，必須確認：

- Stable ID 與本 Manifest 一致。
- Variants、Auto Layout、動態文字與 Safe Area 符合 `docs/04_VISUAL_ENGINEERING_FIGMA.md`。
- Figma node ID 已回填。
- Human Visual Approval 已完成，並以正式版本號取代 `DRAFT`。
- Godot scene／Theme 同步與三種直式 viewport screenshot QA 已完成。
