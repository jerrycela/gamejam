# AGENTS.md - LOW SCALE BLACKJACK

## 1. Mission

你正在開發原始簡報所描述的 **直式 Blackjack／21 點遊戲**。

目標是以最小、可驗證、可維護的方式完成產品；不是建立通用遊戲框架。

---

## 2. Read Order

每個新 Session 必須先讀：

1. `AGENTS.md`
2. `PROJECT_STATE.md`
3. `docs/00_BLUEPRINT.md`
4. `docs/01_GAME_AND_LAYER_SPEC.md`
5. 與任務相關的 `docs/` 與 `specs/`

完整 boot 清單以 `START_HERE.md` 為準；本節僅列每個 session 的最小必讀集合，新增文件時只需更新 `START_HERE.md`。

---

## 3. Source-of-Truth Priority

若內容衝突，依下列優先順序：

1. 已批准的 feature spec／house-rule spec。
2. `docs/02_BLACKJACK_RULES.md`。
3. `docs/03_INTERACTION_CONTRACTS.md`。
4. Figma 中已批准的 Component／Screen。
5. Godot 現有 implementation。
6. 聊天紀錄或臨時文字。

不要用 implementation 反向覆蓋已批准規格。

---

## 4. Runtime Layer Model

### LAYER-1 - Interactive UI

玩家可以操作或需要讀取的 Blackjack GUI：

- Dealer hand
- Player hand
- Hand total
- HIT
- STAND
- DOUBLE
- SURRENDER
- Bet
- Chips
- Result / status

L1 只表達玩家意圖與顯示狀態，不自行計算勝負。

### LAYER-2 - Feedback / Reaction

短期回饋：

- Deal / flip card
- Hand total update
- Win / lose / push
- Bust / blackjack
- Chip feedback
- Dealer reaction
- Short animation / video / sound

L2 不得決定 Blackjack outcome。

### LAYER-3 - Persistent Presentation

長時間存在或循環的 Dealer／背景：

- Dealer idle
- Dealer waiting
- Ambient background
- Progression-specific visual state

L3 不得改變 Blackjack 規則。

---

## 5. Minimal Runtime Architecture

使用：

- `RoundController`：回合狀態與流程 authority。
- `DeckShoe`：建立、洗牌與抽牌。
- `HandEvaluator`：純牌值計算。
- `BetLedger`：籌碼、下注與 payout。
- `TableUI`：L1 顯示與 player intent。
- `PresentationController`：L2／L3。

不要為了未來可能性預先增加 service locator、event bus framework、backend、database 或多代理系統。

---

## 6. Visual Engineering Rules

1. 不可把整個 UI 當成一張扁平背景圖。
2. 可點擊、可變文字、可變狀態、需要 resize 的物件必須是獨立 Godot Control／Scene。
3. Figma Component 是視覺定義；Godot Scene 是 runtime implementation。
4. 重複樣式優先用 Godot `Theme`、Theme type variation、StyleBox 與 tokens。
5. PNG／WebP／SVG 只用於真正需要 texture 的內容。
6. AI 圖片不可包含流程圖、規格文字、假 UI 或不需要的標籤。
7. Dealer 與背景素材不可被 Button 或 HandEvaluator 直接引用。
8. 正式視覺變更需要 Human Visual Approval。

---

## 7. Figma Rules

1. Figma Design 管 Components、Tokens、Variables、Variants、Team Libraries 與 Screens。
2. FigJam 只管流程、註解與 brainstorm，不當作 component source。
3. 本專案以可使用企業付費帳號與 Figma MCP 完整讀寫能力為正式前提。
4. Codex 可透過 Figma MCP 讀取與定向修改已指定的 Component、Variant、Token／Variable 與 Screen；不得未經規格擴大修改範圍。
5. 每個重要元件必須有穩定 `component_id`。
6. Godot path、Figma node URL、批准版本與同步狀態必須記錄在 Component Manifest。
7. Figma MCP 是主要設計交接與更新通路；runtime texture export 仍只針對 Godot 真正需要的素材執行。
8. 所有 Figma 寫入完成後都需要 Human Visual Approval，才可視為正式批准版本。

---

## 8. SDD Rules

專案內統一稱為：

`SDD - Spec-Driven Development`

任何功能依序走：

```text
SPEC
→ CLARIFY
→ APPROVE
→ PLAN
→ IMPLEMENT
→ RUN
→ VERIFY
→ HUMAN ACCEPTANCE
→ UPDATE STATE
```

若規格缺失，回報：

`SPEC REQUIRED`

若缺視覺定義：

`DESIGN REQUIRED`

若缺正式素材：

`ASSET REQUIRED`

若技術完成但需人工判斷：

`HUMAN APPROVAL REQUIRED`

---

## 9. No Guessing

不得自行決定：

- deck count
- penetration / reshuffle
- dealer soft 17
- blackjack payout
- double restriction
- surrender rule
- split
- insurance
- progression content
- sexualized or sensitive content boundaries
- final art style

牌規類（deck count 到 insurance）查 `specs/000_HOUSE_RULES_DECISION.md`；progression content、內容尺度與 final art style 三項的現況查 `PROJECT_STATE.md` 的 Visual Status，且在正式製作前必須另立獨立 spec，未有 spec 前回報 `SPEC REQUIRED`。

---

## 10. Before Editing

先：

1. 檢查 git status。
2. 讀相關 spec。
3. 檢查現有 scene／script，避免重複建立。
4. 說明將改哪些檔案。
5. 說明不會改哪些檔案。
6. 定義 acceptance test。

---

## 11. After Editing

必須：

1. 以 headless 模式啟動並檢查 script parse error，再執行 docs/09 指定的測試指令；實機執行畫面僅保留給人工驗收，agent 不得以「已執行 Godot」作為驗收依據。
2. 檢查 runtime error。
3. 執行規格中的測試。
4. 檢查不相關功能是否退化。
5. 列出 changed files。
6. 更新 `PROJECT_STATE.md`。
7. 不可自行 commit，除非使用者明確要求。

---

## 12. Definition of Done

只有以下全部成立才可完成：

- Spec 已批准且已實作。
- Rule tests pass。
- Godot 可啟動。
- 無新增阻斷性 error。
- Acceptance criteria pass。
- L1／L2／L3 責任沒有混淆。
- 視覺工作已標記是否需要人工批准。
- `PROJECT_STATE.md` 已更新。
