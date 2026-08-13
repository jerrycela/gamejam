# 12 - Figma Component Manifest

## 1. Purpose

本文件追蹤 Figma 視覺元件與 Godot runtime scene 的穩定映射。

- Figma design file: <https://www.figma.com/design/vufbRMFF4rpBt6W1jedHxb>
- Figma 是視覺定義的 source of truth；Godot scene 是 runtime implementation。
- `approved_version = DRAFT` 代表元件已建立、但尚未通過 Human Visual Approval。
- `status = PENDING_CREATE` 代表元件仍待建立，不可視為已批准或已同步至 Godot。
- **填寫規則**：`figma_node_id` 與 `DRAFT` 只能在該 node 已實際存在於 Figma file 時填寫。
- **存在性查核規則（重要）**：判定某個 node 是否存在，**必須用 `get_metadata(fileKey, nodeId)` 直接查該 node**。
  不得用不帶 `nodeId` 的 `get_metadata(fileKey)` 頁面列表作為「不存在」的依據——該列表已證實會回傳不完整的結果（見下方 Verification Log 2026-08-13 第二筆）。
  否定型結論（「這個 node 不存在」）必須附上實際查詢過的 nodeId 與回傳內容，不能只說「沒看到」。

### Verification Log

| 日期 | 查核方式 | 結果 |
|---|---|---|
| 2026-08-13 | Figma MCP `get_metadata(fileKey=vufbRMFF4rpBt6W1jedHxb)`，**未帶 nodeId** | **此筆結論為誤，已作廢，保留供追溯。** 當時回傳的 page 列表只有 `0:1「00 Cover」`，據此誤判 `5:2` 與 `9:17` 不存在，並錯誤地把 `BTN_ACTION` / `BTN_DEAL` 回退為 `NOT_CREATED`。錯誤成因：把不完整的頁面列表當成檔案全貌，用「列表裡沒看到」推論「不存在」。 |
| 2026-08-13 | Figma MCP `get_metadata(fileKey, nodeId=5:2)` 與 `get_metadata(fileKey, nodeId=9:17)`，**直接查 node** | 兩者**均存在**，原始 manifest 記錄正確，已還原。`5:2` = frame `L1/Button/Action`，內含 16 個 symbol（`Action` = Hit/Stand/Double/Surrender × `State` = Default/Pressed/Disabled/Focus，node `4:21`-`4:51`）。`9:17` = frame `L1/Button/Deal`，內含 4 個 symbol（`State` = Default/Pressed/Disabled/Focus，node `9:9`-`9:15`）。檔案另有 `01 Getting Started` / `02 Foundations` / `03 Action Button` / `04 Deal Button` / `05 Card` / `90 Utilities` 等 page 及一組 `var(--lsbj-color-*)` semantic color variables，均為既有成果。連線帳號 `pingliu@cela-tech.com`，於 `CELA International Corp.`（org tier）持 Full 席位，具寫入權限。 |

## 2. Component Manifest

| component_id | Figma component | figma_file_url | figma_node_id | approved_version | runtime_type | godot_scene | variants | last_reviewed | status |
|---|---|---|---|---|---|---|---|---|---|
| `BTN_ACTION` | Action Button | <https://www.figma.com/design/vufbRMFF4rpBt6W1jedHxb> | `5:2` | `DRAFT` | `native_control` | `res://ui/components/action_button.tscn` | `Action / State` | `2026-08-13` | `HUMAN_APPROVAL_REQUIRED` |
| `BTN_DEAL` | Deal Button | <https://www.figma.com/design/vufbRMFF4rpBt6W1jedHxb> | `9:17` | `DRAFT` | `native_control` | `res://ui/components/deal_button.tscn` | `State` | `2026-08-13` | `HUMAN_APPROVAL_REQUIRED` |
| `CARD_FACE` | Card Face | <https://www.figma.com/design/vufbRMFF4rpBt6W1jedHxb> | — | `NOT_CREATED` | `native_control` | `res://ui/components/card_view.tscn` | `Suit / Rank / Orientation` | — | `PENDING_CREATE` |
| `CARD_BACK` | Card Back | <https://www.figma.com/design/vufbRMFF4rpBt6W1jedHxb> | — | `NOT_CREATED` | `native_control` | `res://ui/components/card_view.tscn` | `Style` | — | `PENDING_CREATE` |
| `HAND_DEALER` | Dealer Hand Area | <https://www.figma.com/design/vufbRMFF4rpBt6W1jedHxb> | — | `NOT_CREATED` | `native_control` | `res://ui/components/hand_view.tscn` | `Count / Hidden Card` | — | `PENDING_CREATE` |
| `HAND_PLAYER` | Player Hand Area | <https://www.figma.com/design/vufbRMFF4rpBt6W1jedHxb> | — | `NOT_CREATED` | `native_control` | `res://ui/components/hand_view.tscn` | `Count` | — | `PENDING_CREATE` |
| `VALUE_TOTAL` | Hand Total | <https://www.figma.com/design/vufbRMFF4rpBt6W1jedHxb> | — | `NOT_CREATED` | `native_control` | `res://ui/components/value_display.tscn` | `Soft / Hard / Bust` | — | `PENDING_CREATE` |
| `VALUE_CHIPS` | Chips Counter | <https://www.figma.com/design/vufbRMFF4rpBt6W1jedHxb> | — | `NOT_CREATED` | `native_control` | `res://ui/components/value_display.tscn` | `Positive / Low / Zero` | — | `PENDING_CREATE` |
| `VALUE_BET` | Bet Counter | <https://www.figma.com/design/vufbRMFF4rpBt6W1jedHxb> | — | `NOT_CREATED` | `native_control` | `res://ui/components/value_display.tscn` | `Editable / Locked` | — | `PENDING_CREATE` |
| `STATUS_RESULT` | Round Result | <https://www.figma.com/design/vufbRMFF4rpBt6W1jedHxb> | — | `NOT_CREATED` | `native_control` | `res://ui/components/result_banner.tscn` | `Win / Lose / Push / Bust / Blackjack` | — | `PENDING_CREATE` |
| `PANEL_ACTION_BAR` | Action Bar | <https://www.figma.com/design/vufbRMFF4rpBt6W1jedHxb> | — | `NOT_CREATED` | `native_control` | `res://ui/components/action_bar.tscn` | `Player State` | — | `PENDING_CREATE` |

## 3. Review Gate

元件由 `PENDING_CREATE` 或 `HUMAN_APPROVAL_REQUIRED` 進入正式批准版本前，必須確認：

- Stable ID 與本 Manifest 一致。
- Variants、Auto Layout、動態文字與 Safe Area 符合 `docs/04_VISUAL_ENGINEERING_FIGMA.md`。
- Figma node ID 已回填。
- Human Visual Approval 已完成，並以正式版本號取代 `DRAFT`。
- Godot scene／Theme 同步與三種直式 viewport screenshot QA 已完成。
