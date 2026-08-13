# LOW SCALE PROJECT
## Blackjack / 21 點 AI-Native Development Blueprint V3.1

這是一套可直接放進 Godot repository、供 Codex 長期讀取的專案知識包。

本版只服務一個目標：

> 以 Godot、Codex、Figma 與 AI 影像／影片工具，完成原始簡報所描述的直式 Blackjack／21 點遊戲。

它不是通用遊戲引擎框架，也不是多代理平台。

---

## 這次重構解決的問題

舊版容易把下列事情混在一起：

- Blackjack 遊戲規則。
- 簡報中的 LAYER-1／2／3。
- Figma 元件與 Design Tokens。
- AI 圖片／影片素材。
- Godot Scene 與程式。
- Codex 的操作 Prompt。

V3 將它們分成四層：

```text
1. Product & Rule Spec
   Blackjack 規則、產品範圍、勝負與下注

2. Interaction & Presentation Contract
   玩家動作、狀態轉換、L1/L2/L3 事件

3. Visual Engineering
   Figma Tokens、Components、Variants、Asset Specs

4. Godot Runtime
   Control Scenes、Theme、Rules、Animation、Video、Testing
```

跨越四層的是：

```text
SDD（Spec-Driven Development）
Knowledge Asset Governance
Codex Operating Rules
```

---

## 從這裡開始

1. 先讀 [`START_HERE.md`](START_HERE.md)。
2. 把整個資料夾放進 Godot repository root。
3. 確保 [`AGENTS.md`](AGENTS.md) 位於 repository root。
4. 開啟 Codex，貼上 `START_HERE.md` 中的第一個 Prompt。
5. 先完成 `specs/000_HOUSE_RULES_DECISION.md`，再開始正式規則實作。

---

## 文件索引

| 文件 | 用途 |
|---|---|
| `START_HERE.md` | 一頁式啟動指令與人／AI 分工 |
| `CHANGELOG.md` | V2 到 V3.1 的重構與修正摘要 |
| `AGENTS.md` | Codex 永久規則與架構護欄 |
| `PROJECT_STATE.md` | 每次 Session 的專案狀態交接 |
| `docs/00_BLUEPRINT.md` | 整體四層藍圖與責任邊界 |
| `docs/01_GAME_AND_LAYER_SPEC.md` | Blackjack 產品目標與 L1/L2/L3 |
| `docs/02_BLACKJACK_RULES.md` | 牌值、行動、Dealer 與結果模型 |
| `docs/03_INTERACTION_CONTRACTS.md` | 狀態機、事件、WAIT/HOLD/LOOP |
| `docs/04_VISUAL_ENGINEERING_FIGMA.md` | Figma Components、Tokens、Variants、企業帳號 MCP 讀寫流程 |
| `docs/05_FIGMA_TO_GODOT.md` | Figma 元件映射到 Godot Control／Theme |
| `docs/06_AI_ART_AND_MEDIA_PROMPTS.md` | 圖片、透明 PNG、綠幕與影片 Prompt |
| `docs/07_SDD_WORKFLOW.md` | 本專案的 SDD 流程與 Gate |
| `docs/08_CODEX_PLAYBOOK.md` | 可直接使用的 Codex Prompt |
| `docs/09_TEST_AND_ACCEPTANCE.md` | Rule、UI、Media、Visual QA |
| `docs/10_KNOWLEDGE_GOVERNANCE_RISKS.md` | 知識資產版本、決策與風險 |
| `docs/11_REFERENCE_DECK_ANALYSIS.md` | 原始 Google Slides 概念稿逐頁檢視與 MVP 對應 |
| `docs/12_FIGMA_COMPONENT_MANIFEST.md` | Figma Component 與 Godot `.tscn` 對應的權威登記表（node id、批准版本、同步狀態） |
| `docs/13_PRESENTATION_MAPPING.md` | L2/L3 blocking／non-blocking presentation 與 `fallback_duration_ms` 的登記表 |
| `specs/000_HOUSE_RULES_DECISION.md` | 開工前必須確認的 House Rules |
| `specs/001_FIRST_VERTICAL_SLICE.md` | 第一個可玩 Vertical Slice |
| `specs/002_CORE_TRANSACTION_AND_DEAL_FLOW.md` | 下注交易、發牌、peek、natural 與 Shoe 重現語意 |
| `specs/003_LAYERED_PRESENTATION_PIPELINE.md` | L1/L2/L3 三層管線的驗收規格：元件化、presentation contract、layering 本身 |
| `specs/TEMPLATES.md` | Feature／Component／Asset Spec 模板 |

---

## Source of Truth

不同內容有不同的唯一真實來源：

```text
遊戲規則       → Markdown Specs
視覺定義       → Figma Design File
可執行行為     → Godot Repository
狀態與交接     → PROJECT_STATE.md
```

Figma 不決定 Blackjack 規則；Godot 不應偷偷重新定義視覺；聊天紀錄也不是正式規格。
