# START HERE - 一頁式啟動指令

## 你一定要做的事

1. 決定 `specs/000_HOUSE_RULES_DECISION.md` 中的必要規則。
2. 選擇並批准 Figma 視覺方向與 AI 素材。
3. 實際玩遊戲，判斷節奏、易用性與美術品質。
4. 決定何時接受版本並建立 Git checkpoint。

其餘工作原則上可交給 Codex：建立 Scene、寫 GDScript、連接 Signal、匯入資產、執行測試與修復錯誤。

---

## 第一次開啟 Codex 時貼這段

```text
Read these files in order:

1. AGENTS.md
2. START_HERE.md
3. PROJECT_STATE.md
4. docs/00_BLUEPRINT.md
5. docs/01_GAME_AND_LAYER_SPEC.md
6. docs/11_REFERENCE_DECK_ANALYSIS.md
7. docs/02_BLACKJACK_RULES.md
8. docs/03_INTERACTION_CONTRACTS.md
9. docs/04_VISUAL_ENGINEERING_FIGMA.md
10. docs/05_FIGMA_TO_GODOT.md
11. docs/06_AI_ART_AND_MEDIA_PROMPTS.md — 圖片／影片 Prompt 與素材命名規則；動手產出或核對任何美術素材前必讀，否則容易重複產出或漏掉既有母帶登記。
12. docs/07_SDD_WORKFLOW.md
13. docs/08_CODEX_PLAYBOOK.md — 可直接套用的 Codex Prompt 範本；動手前先看有沒有現成 Prompt 可用，避免每次重新想措辭。
14. docs/09_TEST_AND_ACCEPTANCE.md — 測試框架釘選（gdUnit4）與唯一指定的 headless 測試指令；**沒讀這份會用錯測試指令或框架，判斷「測試是否通過」會失準**。
15. docs/10_KNOWLEDGE_GOVERNANCE_RISKS.md — 知識資產版本與風險登記；變更會影響既有素材／規格版本時必讀。
16. docs/12_FIGMA_COMPONENT_MANIFEST.md — Figma Component 對應 Godot `.tscn` 的權威登記表（node id、批准版本、同步狀態）；**沒讀這份會不知道哪些元件已建立、哪些只是規劃中**。
17. docs/13_PRESENTATION_MAPPING.md — L2/L3 blocking／non-blocking 與 `fallback_duration_ms` 的登記表；動 `PresentationController` 前必讀，避免 magic number 漂移。
18. specs/000_HOUSE_RULES_DECISION.md
19. specs/001_FIRST_VERTICAL_SLICE.md
20. specs/002_CORE_TRANSACTION_AND_DEAL_FLOW.md
21. specs/003_LAYERED_PRESENTATION_PIPELINE.md — 目前 MVP 現行的驗收依據（L1 元件化管線／L2 presentation contract／L3 layering 三個獨立證明）；動 `specs/003` 範圍內的任何元件、presentation 或場景樹之前必讀。

Then inspect:
- git status
- the current Godot project
- the active scene
- available Godot MCP tools
- existing scripts and UI scenes

Do not modify anything yet.

Report:
1. what already exists
2. what conflicts with the specs
3. which house-rule decisions are still unresolved
4. whether the first vertical slice is blocked
5. the smallest safe next task
6. exact files that task would change
7. exact acceptance test
```

---

## House Rules 尚未確認時

不要叫 Codex「先自行決定」。

請先完成：

```text
specs/000_HOUSE_RULES_DECISION.md
```

若只是要做技術 Prototype，可以批准文件中的 provisional profile；它不是最終商業規則。

---

## 第一個實作 Prompt

House Rules 已批准後，貼：

```text
Read AGENTS.md, specs/001_FIRST_VERTICAL_SLICE.md, and specs/002_CORE_TRANSACTION_AND_DEAL_FLOW.md.

Use the SDD workflow.

First create an implementation plan that divides the vertical slice into the smallest verifiable tasks.
Do not build final art.
Use placeholder UI and placeholder L2/L3 presentation.

Priorities:
1. Blackjack correctness
2. deterministic tests
3. stable game state
4. independent L1 components
5. L2/L3 placeholders

Do not add split, insurance, side bets, backend, multiplayer, live AI generation, or a generic framework.

After each task:
- run Godot
- inspect runtime errors
- run the exact acceptance test
- update PROJECT_STATE.md

Stop after the first completed task and report the result.
```

---

## 視覺工作開始條件

以下成立後，才換正式圖：

- Hand evaluation tests pass。
- HIT / STAND 流程可完整跑。
- Dealer turn 正確。
- Round 不會重複結算。
- L1 元件是獨立 Godot Control，不是一張扁平 UI 圖。

---

## Figma 企業帳號策略

本專案以可使用同事提供的 Figma 企業付費帳號為前提，並視 Figma MCP 的完整讀寫能力為正式工作流程的一部分。

基礎流程採：

```text
批准 Component／Screen Spec
→ Codex 透過 Figma MCP 讀取現況
→ 定向建立或修改 Component、Variant、Token／Variable、Screen
→ 人工在 Figma 審核並批准版本
→ 更新 Component Manifest
→ 匯出 Godot 真正需要的 texture／media
→ Codex 更新 Godot Theme／Scene
→ Screenshot QA
```

Team Library、跨檔案元件與 MCP 寫入可依專案需求使用；任何自動寫入都必須鎖定明確 node／component ID，並經人工視覺批准。
