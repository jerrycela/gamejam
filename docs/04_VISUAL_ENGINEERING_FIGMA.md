# 04 - Visual Engineering and Figma

## 1. Visual Engineering Goal

讓視覺細節可以被穩定修改，而不是每次靠 AI 重畫整張畫面。

核心原則：

> 先定義元件與 token，再生產元件所需素材；不是先生成一張完整 UI，再猜它有哪些元件。

---

## 2. Component or Asset?

### 必須是 Component

- 可點擊。
- 有 enabled／disabled／pressed／focus 狀態。
- 文字會變。
- 尺寸會變。
- 會重複使用。
- 需要多解析度適配。

### 可以是 Texture Asset

- Icon。
- 卡背圖案。
- 裝飾框。
- 不含動態文字的牌桌裝飾。
- 可用 Nine Patch 的邊框材質。

### 可以是 Presentation Media

- Dealer portrait。
- Dealer idle loop。
- Dealer reaction。
- 背景 ambience。
- 一次性 FX。

---

## 3. Figma File Structure

本專案可使用企業付費帳號、Team Library 與 Figma MCP 完整讀寫。為了讓第一個 Blackjack 專案保持清楚，仍建議先以一個主要 Figma Design file 管理核心系統；這是協作簡化策略，不是方案限制：

```text
00_README
01_TOKENS
02_COMPONENTS_L1
03_COMPONENTS_FEEDBACK
04_SCREENS
05_STATE_REFERENCES
06_EXPORT
90_ARCHIVE
```

FigJam 可另外放：

```text
Game flow
Decision tree
Review notes
Workshop
```

不要把 FigJam 當成 Godot component source。

---

## 4. Design Tokens

先從少量 semantic tokens 開始。

### Color

```text
color.bg.table
color.bg.overlay
color.text.primary
color.text.secondary
color.action.primary
color.action.danger
color.action.disabled
color.result.win
color.result.lose
color.result.push
color.focus
```

### Typography

```text
type.display.total
type.label.hand
type.button.action
type.value.chips
type.result
```

### Spacing / Shape

```text
space.1 / 2 / 3 / 4 / 6 / 8
radius.small / medium / large
stroke.thin / regular
shadow.panel
```

### Motion

```text
motion.fast
motion.normal
motion.result
motion.easing.standard
```

不要一開始建立數百個 token。

---

## 5. L1 Component Catalog

**架構說明用，非權威登記表**：實際 Component 對應的 `.tscn` 路徑、node id、批准版本與同步狀態，一律以 `docs/12_FIGMA_COMPONENT_MANIFEST.md` 為準；本節若日後再度與 `docs/12` 不一致，以 `docs/12` 為正確答案。下表的「狀態」欄區分「已建立」（真實檔案存在，路徑為 Godot 實際使用的 snake_case 檔名）與「規劃中」（尚未建立，路徑為預定目標，不代表已存在）。

| Component ID | Figma component | Godot target | 狀態 | Key variants |
|---|---|---|---|---|
| `BTN_ACTION` | Action Button | `res://ui/components/action_button.tscn` | 已建立 | action, state, size |
| `BTN_DEAL` | Deal Button | `res://ui/components/deal_button.tscn` | 已建立 | state, size |
| `CARD_FACE` | Card Face | `res://ui/components/card_view.tscn` | 已建立 | suit, rank, orientation |
| `CARD_BACK` | Card Back | `res://ui/components/card_view.tscn`（共用） | 規劃中 | style |
| `HAND_DEALER` | Dealer Hand Area | `res://ui/components/hand_view.tscn` | 規劃中，尚未建立 | count, hidden-card |
| `HAND_PLAYER` | Player Hand Area | `res://ui/components/hand_view.tscn` | 規劃中，尚未建立 | count |
| `VALUE_TOTAL` | Hand Total | `res://ui/components/value_display.tscn` | 已建立 | soft/hard/bust |
| `VALUE_CHIPS` | Chips Counter | `res://ui/components/value_display.tscn`（共用） | 規劃中 | positive/low/zero |
| `VALUE_BET` | Bet Counter | `res://ui/components/value_display.tscn`（共用） | 規劃中 | editable/locked |
| `STATUS_RESULT` | Round Result | `res://ui/components/result_banner.tscn` | 規劃中，尚未建立 | win/lose/push/etc. |
| `PANEL_ACTION_BAR` | Action Bar | `res://ui/components/action_bar.tscn` | 已建立 | player state |

---

## 6. Recommended Variants

Action Button：

```text
Action = Hit / Stand / Double / Surrender
State  = Default / Pressed / Disabled / Focus
Size   = Compact / Standard
```

不要為每個狀態建立毫無關係的獨立圖片；使用 component variants。

---

## 7. Naming

```text
L1/Button/Action
L1/Card/Face
L1/Value/Chips
L1/Panel/ActionBar
L2/Overlay/Result
L2/FX/CardDeal
L3/Dealer/IdleReference
```

Stable ID 使用大寫底線：

```text
BTN_ACTION
STATUS_RESULT
DEALER_IDLE_BASE
```

顯示名稱可改，Stable ID 不要隨意改。

---

## 8. Component Manifest

每個需要映射到 Godot 的元件記錄：

| Field | Example |
|---|---|
| component_id | BTN_ACTION |
| figma_file_url | Figma file URL |
| figma_node_id | node-id |
| approved_version | 1.2.0 |
| runtime_type | native_control / texture / media |
| godot_scene | res://ui/action_button.tscn |
| variants | action,state,size |
| export_files | optional |
| last_reviewed | YYYY-MM-DD |

此 Manifest 可以先放在本文件旁的專案資料，未必要一開始做資料庫。

---

## 9. Figma Enterprise MCP Operating Model

本專案已確認可使用同事提供的 Figma 企業付費帳號，因此工作基線是：

- Figma MCP 可作為主要的 design context 讀取與定向寫入通路。
- Codex 可依批准規格建立或修改 Component、Variant、Token／Variable、Screen 與相關設計節點。
- Team Library 與跨檔案元件可以使用；是否拆檔依協作與維護需求決定。
- Figma 仍是視覺定義的 source of truth；MCP 寫入不得跳過 Component Spec、Stable ID 與版本批准。
- 每次寫入必須鎖定明確 file／node／component ID，避免大範圍非預期修改。
- Component Manifest 用於追蹤 Figma 節點、批准版本與 Godot 對應。
- 只有 Godot Runtime 真正需要的 texture／media 才匯出；native UI 仍由 Theme、Control 與 Scene 實作。

正式流程：

```text
Approved visual spec
→ MCP read current Figma component context
→ targeted MCP write
→ human review and version approval in Figma
→ update Component Manifest
→ export runtime-only assets when required
→ update Godot Theme / Scene
→ screenshot QA
```

MCP 可以執行設計修改，但不能取代 Figma 的元件治理與人工視覺批准。

---

## 10. Visual Review Gate

Figma Component 要進 Godot 前：

- Stable ID 正確。
- Variants 完整。
- Auto Layout 合理。
- 文字不是 rasterized。
- Safe area 正確。
- Export layer 沒有多餘背景。
- 人工批准版本號。
