# 14 - MVP 交接說明

> **這份文件是給下一個接手的人（或幾週後的自己）的入口。**
> 撰寫日期 2026-08-13。若你正在讀這份，先跑一次測試確認狀態沒變，再往下讀。

## 1. 現在是什麼狀態

`specs/003_LAYERED_PRESENTATION_PIPELINE.md` 的 **19 條驗收條件全數達成**。這份 spec 就是 MVP 的定義。

```
gdUnit4：216 test cases，0 errors／failures／flaky／skipped／orphans，exit code 0
headless parse check：exit code 0
```

> **這個數字會過期。** 讀到時請自己跑一次，並用靜態原始碼交叉核對
> （`grep -rc '^func test_' tests/core/*.gd tests/ui/*.gd`），因為失敗的測試
> 會讓同檔案後續測試靜默消失，而唯一症狀就是這個數字（見 §4.6）。

驗收指令（`docs/09_TEST_AND_ACCEPTANCE.md` 為權威來源）：

```bash
cd /Users/admin/blackjack/LOW_SCALE_BLACKJACK_AI_NATIVE_BLUEPRINT_V3_1
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
  -s addons/gdUnit4/bin/GdUnitCmdTool.gd --ignoreHeadlessMode -a tests
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --editor --quit
```

**`--ignoreHeadlessMode` 不可省略**，否則 gdUnit4 的 headless 檢查會直接擋下並回報 `Abnormal exit with 103`，看起來像測試壞了。

**遊戲可以玩**：開啟專案按執行即可用滑鼠玩完整一局——發牌、要牌／停牌／加倍／投降、莊家翻底牌補牌、結算、下一局。介面為繁體中文，有逐張發牌與翻牌動畫、點數與籌碼滾動、荷官依結果切換表情。

**尚無音效**（檔案已備好但未接線）。

## 2. MVP 的定義是什麼——這點最容易誤解

MVP **不是**「能玩完一局 21 點」。

MVP 是**把 L1／L2／L3 分層架構跑起來**。21 點規則是載體，不是目的。要驗證的是「Figma 定義視覺 → 元件化 → 進 Godot 成為真正分層的 runtime 場景」這條管線走得通。

因此一個單層、能玩的畫面**不算** MVP——它恰好繞過了要驗證的東西。`AGENTS.md:132`「不可把整個 UI 當成一張扁平背景圖」不是美術偏好，是在守住這個架構。

`specs/003` 把它拆成**三個互相獨立的證明**：

| 層 | 要證明什麼 | 靠什麼證 |
|---|---|---|
| **L1** | 元件化管線成立 | Figma → Godot Theme／scene 同步，且落地為原生 Control（文字是 `Label` 不是烙在圖上、完整畫面是多 scene 組合不是單張圖） |
| **L2** | 演出契約成立 | `presentation_token` 的 exactly-once guard、演出期間鎖住輸入、逾時後遲到的完成訊號不得推進狀態、**下一步由 `RoundController` 決定而非演出層自行猜測** |
| **L3** | 分層本身成立 | scene tree `L3Root < L2Root < L1Root`、L3 永不攔截輸入、L2 overlay 後 loop 恢復、連跑兩局不中斷 |

三者要用三種方式證明，因為 **Figma 元件化管線在文件設計上只對應 L1**（`docs/04` 的檔案結構只有 `02_COMPONENTS_L1`）。L2 的角色回饋與 L3 走 Presentation Media 流程，不經過 Figma。

## 3. 架構的關鍵邊界（改動前務必理解）

### `RoundController` 是 `RefCounted`，不是 `Node`

這是刻意的。純邏輯、無場景依賴，所以能 headless 測試（85 個 core 測試都不需要場景樹）。

要把它接進場景，用 `scripts/presentation/round_controller_node.gd` 這層 **Node 適配器**——它只是持有引用的空 `Node`。**不要為了方便把 core 改成 `Node`**，那會污染這個邊界。

### 規則權威只有一個

- L1 只表達玩家意圖與顯示狀態，**不自行計算勝負**（`AGENTS.md:86`）
- L2 **不決定 outcome**（`AGENTS.md:100`）
- L3 **不改變規則**、不攔截輸入（`AGENTS.md:111`）

具體例子：`ValueDisplayView` 的 soft／hard／bust 判定來自 `HandEvaluator.Evaluation` 的欄位，元件本身不算。一個會自行判定「什麼算 soft」的顯示元件，等於第二個規則權威。

### exactly-once guard 只存在於 core

`PresentationController` 呼叫 `RoundController.complete_presentation()` 並依回傳布林值反應，**不重新實作那個保證**。逾時與正常完成競爭同一個函式，先到者贏、後到者只留診斷訊號。

同一個性質有兩個真源，遲早會分岔。

### 演出節奏參數不進 core

`FALLBACK_DEAL_CARD_MS`（1500）、`FALLBACK_DEALER_HOLE_REVEAL_MS`（1200）、`FALLBACK_VISUAL_DWELL_MS`（400）都在 `PresentationController`。

理由：`RoundController` 沒有計時器，從它的視角「演出播完」與「逾時 fallback」是**同一件事**——都是呼叫同一個 `complete_presentation(token)`。讓規則層知道演出時長會污染分層。

登記表在 `docs/13_PRESENTATION_MAPPING.md`，**表與常數是同一份契約的兩面，只改一邊即為缺陷**。

## 4. 這一天學到的教訓（重複踩過的坑）

### 4.1 綠燈不等於正確——空洞測試比沒有測試危險

發生過三次，兩種形態：

**循環論證**：測試拿被測物自己的 `get_theme_constant()` 結果去跟被測物自己的屬性比對。兩邊同源，是恆等式，即使 production 改成硬編碼也會通過。第一次在 theme 測試、後來在 `test_action_button_view.gd` 與 `test_value_display_view.gd` **復發**。

正確寫法：斷言 **Figma 的字面值**（例如 `Vector2(210, 64)`），不要重新呼叫存取器。

**斷言對象消失**：`bootstrap` 讓場景載入時自動重建按鈕，某個 blocking 測試的迴圈只走 `action_bar.buttons()`（不含 `DealButtonView`），而那個時點唯一存在的按鈕正是 DEAL——迴圈空跑，測試照樣通過。

> **不是斷言寫錯，是斷言的對象不在了。** 這種形態在重構後特別容易產生。

### 4.2 mutation check 必須偏離「真相」而非偏離「方法」

修空洞測試時，第一次把 production 硬編碼成**正確**值（210,64），mutation 仍然通過——那只再次證明了**舊測試**的缺陷。改用**錯誤**值（999,999）才真正驗證新測試有效。

### 4.3 矩形不重疊不等於畫面可讀

`L1-5` 的機器斷言在三個尺寸全部通過（不出界、不重疊、中央區未塌陷），而畫面完全不能用：文字溢出蓋掉兩排、背景只覆蓋 60% 寬度、荷官放大到佔滿全屏。

原因：那些斷言檢查 **L1 元件彼此之間**的矩形關係，而所有缺陷都出在 **L1 與 L3 之間**或**素材尺寸與畫布不符**。

修好三個缺陷後又產生第四個：荷官下移後，**牌的位置沒跟著動**，落在眼睛高度。一個固定位置在它的脈絡改變時變成錯的。

教訓：**能機器化的就不要留給人眼**。臉部遮蔽現在有測試（`DealerIdleView` 已渲染矩形內的 15%-45% 縱向帶），從只有人眼能抓變成可核對。

### 4.4 否定型結論需要更強的證據

早上用不帶 `nodeId` 的 `get_metadata(fileKey)` 列 Figma 頁面，只看到一頁，據此宣告「所有元件不存在、manifest 是假的」——並**改壞了正確的文件**。

實際上 `get_metadata` 不帶 nodeId 會回傳不完整結果。真相是 Codex 建的元件一直都在。

擋下損害的不是我，是 agent 發現既有內容與我的記錄矛盾時**停下來問而不是照做**。

相關規則已寫進 `docs/12` §1：
- 判定 node 存在性**必須直查 nodeId**，否定結論必須附實際查過的 nodeId
- **`get_metadata` 不顯示 component property**，驗證 property 要用 `get_context_for_code_connect`
- 查「有沒有修好」要查**修正本身的痕跡**，不是查 bug 的表面特徵（grep `extends Control` 看不到 `_get_minimum_size()` 覆寫）

### 4.5 文件漂移沒有訊號

今天修了七、八次，全部靠人剛好去看才發現：

| 事件 | 代價 |
|---|---|
| `docs/12` 記載兩個從未存在的 node | 改壞正確文件 |
| `PROJECT_STATE.md` 停在 34/34、「下一步：設計 RoundController」 | 差點重做已完成的工作 |
| `spectra init` 在 `AGENTS.md` 前插入 29 行 | `specs/003` 六處行號引用全失效 |
| 我只更新摘要未更新詳細表格 | 同一份文件對 `RC-2` 給出兩個相反答案 |
| `docs/13` 建立當天就漏登一個常數 | 那份文件自己寫的規則被自己違反 |
| `docs/04` 三個檔名大小寫全錯 | 路徑從來解析不到，但表面上看起來有登記 |

`tools/check_doc_drift.gd` 就是為此而寫——把偵測從「人剛好去看」變成「有訊號」。

### 4.6 gdUnit4 的兩個行為（會誤導 TDD）

- **parse error 會讓引擎以 signal 11 崩潰**並輸出 C++ backtrace，而非乾淨回報 parse error。RED 階段的輸出會被崩潰堆疊淹沒。
- **某個測試失敗時，同檔案順序上緊接其後的測試可能靜默消失**——無錯誤、無 orphan，只有統計數字變少。已在有／無手寫 lambda 兩種情況下各觀察到一次，**觸發條件是失敗相鄰性**。

緩解：**每輪核對測試總數是否等於預期值，不要只看 0 failures**。被吞掉的測試看起來跟從未寫過的一模一樣。

## 5. 刻意留下的邊界

這些不是遺漏，是有理由的取捨：

| 項目 | 為什麼不做 |
|---|---|
| L3 progression 內容尺度 | `AGENTS.md` §9 明訂只有使用者能決定。原始簡報第 8 頁的「角色變得更為赤裸」機制**不在 MVP 範圍**，L3 目前只有中性佔位 |
| 其餘 6 個 Figma 元件 | `specs/003` 只選 4 個代表性元件證明管線；管線既已證明，剩下的是重複勞動。留給後續 spec 一次納入 |
| golden-image pixel diff | `docs/09` §9 的 Visual Regression 本來就要求「像素差異是檢查線索，不自動代表錯誤，最終由人工批准」，不是自動化關卡。現階段投入產出比不划算 |
| 待機循環影片 | 兩層理由：目前的生成後端**完全沒有影片能力**（實測確認，可能隨工具更新解除）；且 Godot 4 原生只支援 Ogg Theora，**Theora 的 alpha 支援不佳**，無法承載「荷官獨立透明圖層 + 動態」（架構理由，不會消失）。改用引擎內 `AnimationPlayer` |
| 真實 click→action 端到端測試 | gdUnit4 headless 不傳輸 `InputEvent`，是工具限制 |
| `TableUI` 拆成獨立 `.tscn` | `docs/05` §4 有列 `table_ui.tscn`，但那些元件的 Figma 內容尚未批准。目前 `TableUI` 是 `game_root.tscn` 內的節點 |

## 6. 素材與 Figma 的對應

- **權威來源是 `docs/12_FIGMA_COMPONENT_MANIFEST.md`**。`docs/04` §5 與 `docs/05` §4 的清單只是架構說明，會落後。
- Figma file `vufbRMFF4rpBt6W1jedHxb`，帳號 `pingliu@cela-tech.com`（`CELA International Corp.` org，Full 席位）。
- 已核准 5 個元件：`BTN_ACTION`(`5:2`)、`BTN_DEAL`(`9:17`, 1.1.0)、`CARD_FACE`(`11:84`)、`PANEL_ACTION_BAR`(`21:38`)、`VALUE_TOTAL`(`21:62`)。
- **母帶與 runtime 分開**：`assets/source/image/` 是生成原始輸出（不覆蓋），`assets/textures/` 是實際使用的檔案。場景**只能引用 `assets/textures/`**——引用母帶會讓「重生母帶」靜默改變遊戲畫面。
- 被取代的素材標記 `SUPERSEDED` 並**保留**（例如 `L3_DEALER_PLATE_BAKED_V001.png` 是荷官烙進背景的舊結構，是「為什麼不把荷官畫進背景」的直接答案）。未被任何文件提到的檔案會被後人誤判為可清除。

## 7. 產圖的實務注意事項

生成後端是 Slack bot `hermes-script`（`U0BJHQXGX0U`），呼叫格式 `創作圖像，使用以下提示詞：`。它**不支援影片**，但 `image_generate` **支援 image-to-image**（可用 `image_url` 提供角色參考）。

`docs/06 §3` 的「詞彙陷阱」值得先讀：
- 提到 **blackjack table** 會讓模型畫出整套牌桌版面（下注圈、`INSURANCE` 保險區、亂碼標語）——而本專案規則不做保險。要純材質就用材料詞彙（`wool baize`、`billiard cloth`），完全避開遊戲脈絡。
- **照抄長串否定句**會顯著提高失敗率（實測回傳空結果）。`docs/06` §1／§3 已改為**產出後的檢核清單**，不是貼進 prompt 的開頭。
- 透明背景要求常失敗（模型會把透明棋盤格**畫成實體像素**，檔案是 RGB 無 alpha，且無法可靠去背——金色耳環與白襯衫高光會被吃掉）。**改用純綠幕 `#00FF00`**，綠幕與白襯衫在**色相**上分離而非亮度上。
- 去背後**必須用 PIL 確認 alpha**，不可只看預覽：Read 工具不做 alpha 合成，透明區會顯示底層殘留綠色，看起來像沒去背。

## 8. 下一步的候選

沒有既定順序，依需求選：

**最高優先（見 §10）**：把寫死在 `const` 的參數搬進編輯器可調的形式。在那之前，每新增一個動畫就是多鎖死一個使用者碰不到的旋鈕。

其餘候選，無既定順序：

1. **音效接線** —— `assets/audio/` 有 9 個合成音效但**尚未接線**。接時請放場景節點而非程式碼建立（見 §10）。
2. **`Bet Controls` 可操作** —— 簡報把它列為獨立可操作元件，`BetLedger.set_selected_bet()` 邏輯完整存在但**沒有任何 UI 呼叫它**，下注永遠固定 10。與反應圖曾經是同一種「邏輯在、沒接線」形態。
3. **呈現層分歧** —— 簡報第 9 頁「向下指向到無數個可能的分歧」目前只在規則層成立（8 種 outcome），畫面呈現的分支僅有荷官反應圖與結果文字。
4. **節點查找脆弱性** —— 大量 `find_child("名字")`，使用者在編輯器改名就會壞且無明顯錯誤。見 §10 末。
5. **其餘 6 個 Figma 元件** —— `CARD_BACK`、`HAND_DEALER`、`HAND_PLAYER`、`VALUE_CHIPS`、`VALUE_BET`、`STATUS_RESULT`，需先立後續 spec。
6. **progression 內容 spec** —— 需使用者決定內容尺度才能開始。
7. **Inter 字型內嵌** —— 中文已用思源黑體（`assets/fonts/`，OFL），但 Figma 指定的 Inter 尚未內嵌，拉丁字仍回退預設。

**已完成、不要重做**：玩家輸入接線（`GameplayController`，真實點擊驗證過完整一局）、L2 荷官反應接線、繁體中文化、字型內嵌、逐張發牌與翻底牌動畫、點數與籌碼滾動。

## 9. 相關文件

| 情境 | 讀哪份 |
|---|---|
| MVP 驗收依據 | `specs/003_LAYERED_PRESENTATION_PIPELINE.md` |
| 牌規 | `specs/000`（house rules 定案）、`docs/02_BLACKJACK_RULES.md` |
| 演出契約與事件 | `docs/03_INTERACTION_CONTRACTS.md`、`docs/13_PRESENTATION_MAPPING.md` |
| 元件與 scene 對應 | `docs/12_FIGMA_COMPONENT_MANIFEST.md`（權威） |
| 分層定義 | `docs/01_GAME_AND_LAYER_SPEC.md:35-84` |
| Figma→Godot 管線 | `docs/05_FIGMA_TO_GODOT.md` |
| 產圖 prompt 與陷阱 | `docs/06_AI_ART_AND_MEDIA_PROMPTS.md` |
| 測試指令與驗收 | `docs/09_TEST_AND_ACCEPTANCE.md` |
| agent 行為守則 | `AGENTS.md`（治理權威，Spectra 只承接文件格式） |
| 目前狀態與已知問題 | `PROJECT_STATE.md` |

---

## 10. 2026-08-13 晚間交接：把東西寫進引擎

### 這一節存在的理由

使用者指出一個架構問題，是本專案至今最重要的一次校正：

> 「你有實際用 Godot 引擎去控制裡面的功能，還是只是用你的方式寫程式碼，然後用 Godot 把它 compile 出來？這兩種差很多：前者我可以去引擎裡面細節地調這些參數；後者變成我都得依賴你。用這套製程做遊戲，為什麼要用 Godot？就是希望後續可以藉由人來改善各種細節體驗。」

**他是對的，而且問題是我造成的。**

當時的狀態：13 個動畫參數全部是 `const`（發牌間隔 150ms、進場縮放 0.55、翻牌 240ms、點數滾動 200ms、爆牌強調 1.2 倍…），全專案 `@export` 只有 10 個、`const` 有 29 個。`const` 不會出現在 Inspector，所以想把發牌間隔改成 120ms，唯一的路是找 AI 改程式碼。

**「能跑」與「能被 polish」是兩種完成度，而我一直只做到前者。**

### 判準

> **如果一個不寫程式的人可能想改它，它就必須在編輯器裡可見可調。**

分界：
- **手感參數開放**（`@export`）：動畫時長、縮放幅度、緩動曲線、音量、間距
- **契約參數鎖死**（`const`）：`FALLBACK_DEAL_CARD_MS`(1500)、`FALLBACK_DEALER_HOLE_REVEAL_MS`(1200)、各 dwell 值——它們登記在 `docs/13`，`specs/003` `L2-5` 會核對文件與程式碼一致，在 Inspector 隨手改掉會靜默破壞契約。這類必須在註解寫明「要改必須同步 `docs/13`」

### 已接上 Godot MCP

`.mcp.json`（專案層級）→ `mkdevkit/godot-mcp`，server 建在 `~/.local/share/godot-mcp`（**刻意在 repo 外**，工具鏈不隨遊戲出貨）。

**選擇過程與熱門度相反**，值得記：

| MCP | 星數 | 能編輯動畫／屬性／`.tres`？ |
|---|---|---|
| `Coding-Solo/godot-mcp` | 5182 | ❌ 只能啟動編輯器、跑專案（headless 腳本） |
| `ee0pdt/godot-mcp` | 603 | ❌ 節點增刪改，無動畫編輯 |
| **`mkdevkit/godot-mcp`** | **8** | ✅ 173 工具：動畫軌道／關鍵影格／Theme／音訊／粒子／shader／`.tres` |

因為只有 8 星，**安裝前讀過 `plugin.gd` 全文**。它是 `EditorPlugin`，啟用時注入 3 個 autoload、停用時移除。實測三條路徑均無污染：

- 測試 `-s` 模式 → EditorPlugin 不載入
- parse check `--editor --quit` → 載入後乾淨移除
- 互動式編輯器 → 僅執行期間存在

**若編輯器被強制中止，autoload 可能殘留在 `project.godot`。commit 前務必 `git diff project.godot` 確認。**

MCP 走 UndoRedo，所以 AI 做的改動**使用者可以在編輯器裡直接 Ctrl+Z 復原**——這讓「AI 改」與「人改」變成同一個操作層，而不是兩套互相看不見的機制。

### 重啟後的第一要務

**把目前只活在程式碼裡的東西，搬進編輯器可編輯的形式。**

優先序：

1. **`const` → `@export`**（不需要 MCP，最直接）。用 `@export_range` 加合理範圍與 `suffix:ms`，用 `@export_group` 分組讓 Inspector 不是一長串。預設值必須等於現有 `const` 值，不改變行為。
2. **緩動曲線改成 `@export`**：`@export var deal_card_transition: Tween.TransitionType = Tween.TRANS_BACK`。Godot 會自動顯示成下拉選單。**曲線是動畫手感的核心**，`TRANS_BACK` 與 `TRANS_ELASTIC` 的差別講一百句不如自己拉一次。
3. **音效節點放進 `.tscn`**：`AudioStreamPlayer` 具名節點放在 `L2Root` 底下、`stream` 在場景裡指好。用 `AudioStreamPlayer.new()` 在程式碼建立會讓換音檔、調 `volume_db`、`pitch_scale` 全部鎖死。
4. **tween 動畫 → `AnimationPlayer` 資源**（需要 MCP）。目前只有荷官呼吸（`idle_breathe`）是真正的 `Animation` sub-resource，可在動畫面板拉曲線；其餘 tween 動畫只活在程式碼。動態序列（依牌數變動）保留 tween 是正確工程判斷，但固定結構的動畫應該搬進去。

### 尚未解的脆弱點

程式碼大量用 `find_child("ActionBar", true, false)` 依名字找節點。**使用者在編輯器裡重新命名節點，程式就壞了，而且不會有明顯錯誤訊息。**

這是「人可以介入」的實質障礙——連改個節點名都有風險。可能解法：`@export NodePath` 或 `%UniqueName`。尚未處理。

### 音效現況

`assets/audio/` 有 9 個程序化合成的 `.wav`（無授權負擔，說明見同目錄 `README.md`），**但尚未接線**——`grep -c "sfx_\|AudioStream" scripts/presentation/gameplay_controller.gd` 為 0。接線時請直接放場景節點，見上方第 3 點。

### 影片路徑已確認關閉

`hermes-script` 的影片能力實測回覆：**無 alpha 輸出、無無縫循環、不支援 Ogg Theora、角色一致性不可靠、解析度卡 768P**。它自己也建議走靜態圖 + 引擎內動畫。

**不要再嘗試這條路。** 現行的引擎內動畫就是最終方案。
