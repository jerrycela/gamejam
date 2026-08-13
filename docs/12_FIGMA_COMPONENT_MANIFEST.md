# 12 - Figma Component Manifest

## 1. Purpose

本文件追蹤 Figma 視覺元件與 Godot runtime scene 的穩定映射。

- Figma design file: <https://www.figma.com/design/vufbRMFF4rpBt6W1jedHxb>
- Figma 是視覺定義的 source of truth；Godot scene 是 runtime implementation。
- `approved_version = DRAFT` 代表元件已建立、但尚未通過 Human Visual Approval。
- `status = PENDING_CREATE` 代表元件仍待建立，不可視為已批准或已同步至 Godot。
- **填寫規則**：`figma_node_id` 與 `DRAFT` 只能在該 node 已實際存在於 Figma file 時填寫。禁止預先填入規劃中的 node id；未建立一律維持 `—` / `NOT_CREATED` / `PENDING_CREATE`。

### Verification Log

| 日期 | 查核方式 | 結果 |
|---|---|---|
| 2026-08-13 | Figma MCP `get_metadata(fileKey=vufbRMFF4rpBt6W1jedHxb)` | 檔案僅有單一 page `0:1 「00 Cover」`，其下只有封面 frame `3:7` 及 5 個子節點（`3:8`-`3:12`）。`BTN_ACTION` 宣稱的 `5:2` 與 `BTN_DEAL` 宣稱的 `9:17` **均不存在**，已回退為 `NOT_CREATED` / `PENDING_CREATE`。連線帳號 `pingliu@cela-tech.com`，於 `CELA International Corp.`（org tier）持 Full 席位，具寫入權限。 |

## 2. Component Manifest

| component_id | Figma component | figma_file_url | figma_node_id | approved_version | runtime_type | godot_scene | variants | last_reviewed | status |
|---|---|---|---|---|---|---|---|---|---|
| `BTN_ACTION` | Action Button | <https://www.figma.com/design/vufbRMFF4rpBt6W1jedHxb> | — | `NOT_CREATED` | `native_control` | `res://ui/components/action_button.tscn` | `Action / State` | — | `PENDING_CREATE` |
| `BTN_DEAL` | Deal Button | <https://www.figma.com/design/vufbRMFF4rpBt6W1jedHxb> | — | `NOT_CREATED` | `native_control` | `res://ui/components/deal_button.tscn` | `State` | — | `PENDING_CREATE` |
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
