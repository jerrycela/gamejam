# 修訂提案：docs/06 素材結構拆分（Dealer / Background 分離）

Status: **APPROVED（2026-08-13）**

核准來源：使用者於 2026-08-13 明示授權「驗收過後即可通過」；本提案由 team-lead 依該授權於 2026-08-13 核准套用，非使用者本人逐行審閱。已套用至 `docs/06_AI_ART_AND_MEDIA_PROMPTS.md`（§1、§3、§4、§5、§6、§11、§13、§14），並補充兩項新事實：(1) 生成後端 `hermes-script` 實測不支援影片生成，(2) `image_generate` 支援 image-to-image 角色參考。

本文件原為提案，以下「修訂內容」章節保留作為變更歷史紀錄；實際套用結果以 `docs/06_AI_ART_AND_MEDIA_PROMPTS.md` 現況為準，兩者若有出入以 `docs/06` 為準。

---

## 1. 問題陳述

`docs/06_AI_ART_AND_MEDIA_PROMPTS.md` 目前對「荷官」這一個角色，同時要求兩種互不相容的素材形態：

- **§5「L3 Full Background / Dealer Idle Reference」**（`docs/06:107-127`）要求 L3 背景板是一張**不透明整圖**，且明文「use the approved canonical dealer reference」「dealer placed in the upper-middle visual zone」（`docs/06:118,120`）——即荷官被直接畫進背景裡，成為背景的一部分。
- **§6「L2 Isolated Dealer Reaction」**（`docs/06:131-156`）要求荷官反應是**透明背景 PNG、單一角色、不含桌子**（`docs/06:146-151`「transparent background」「one character only」「no table unless the reaction specifically requires hand contact with it」）。

同一個角色因此有兩套不相容的素材形態：待機時是背景裡烙死的像素、反應時是疊圖用的去背 PNG。後果：

1. **演出切換必跳位**：L2 反應疊上 L3 背景時，兩張圖各自獨立生成，機位／比例／光線只要有一絲偏差，畫面就會出現「兩個荷官」或明顯錯位。
2. **背景裡的荷官需要額外遮蓋**：L2 演出期間背景裡原本畫進去的荷官必須被蓋住，否則穿幫；這是為了修補結構問題而額外增加的實作負擔，`docs/06` 目前完全沒有處理這件事。
3. **與既有 Godot scene tree 設計本身矛盾**：`docs/05_FIGMA_TO_GODOT.md:29-33` 定義的 Recommended Scene Tree 已經把 `L3Root` 拆成 `BackgroundView` 與 `DealerIdleView` 兩個獨立子節點：

   ```text
   L3Root
   ├── BackgroundView
   └── DealerIdleView
   ```

   也就是說 Godot 端從一開始就預期背景與荷官是兩個可獨立換圖的節點；但 `docs/06` §5 產出的素材規格卻是「兩者已經燒在同一張圖裡」，兩邊對不上。這不只是美術一致性問題，是素材規格與既有 runtime 架構的直接衝突。

---

## 2. 修訂內容（逐節列出建議改法）

### 2.1 §5「L3 Full Background / Dealer Idle Reference」（`docs/06:107-127`）

**現狀**：單一 prompt，要求輸出一張把荷官烙進去的整合背景板。

**建議改為兩個獨立 prompt 區塊**，對應 `L3Root` 底下的兩個節點：

- **`§5a L3 Room Background`**（餵給 `BackgroundView`）
  - 內容：房間、牆面、壁燈、布幔、賭桌，**明確排除人物**。
  - 輸出：不透明 PNG，1080×1920（沿用既有 9:16 基準，`docs/01_GAME_AND_LAYER_SPEC.md:17-30`）。
  - Prompt 需明確加入 "no character, no person, no dealer"，避免模型自動把人物腦補進畫面。
  - Prompt 需**明確指定光源方向與色溫**（例如："warm key light from upper-left, 3200K tungsten-leaning color temperature, soft rim light from table-level chip lights"），作為荷官素材對齊的錨點（見第 4 節代價與緩解）。

- **`§5b L3 Dealer Idle Reference`**（餵給 `DealerIdleView`）
  - 內容：荷官待機姿，及腰以上，**透明背景 PNG**。
  - 沿用 §4 canonical dealer reference 的身份鎖定語（"use the approved canonical dealer reference"），但輸出格式改為 alpha-clean PNG，不含桌子、不含房間元素。
  - Prompt 需與 §5a 使用**相同的光源方向與色溫描述**，並註明目標疊圖後的視覺位置（"upper-middle visual zone, matching L3 room background composition"）供人工比對用。
  - 呼吸／眨眼等待機動態，建議改由 Godot `AnimationPlayer` 或 shader 做輕微縮放位移，不再依賴 image-to-video（詳見第 4 節理由 4，以及對 §11、§13 的連動建議）。

### 2.2 §6「L2 Isolated Dealer Reaction」（`docs/06:131-156`）

**現狀**：格式定義已經正確（transparent PNG、one character only），**建議保留現有 prompt 邏輯不變**，只新增一條要求：

- 在「Output requirements」清單新增一項：**"match the camera angle, crop, scale, and lighting direction/color temperature of `L3_DEALER_IDLE_V001`"**，明確把 L2 反應圖與新拆出的 L3 荷官素材綁定同一機位／光線基準，而不是各自對齊「canonical dealer reference」後就視為完成。

這一節本身沒有形態矛盾，問題出在它與（舊版）§5 的素材形態不一致；§5 拆分後，§6 只需要多一條「跟誰對齊」的規則。

### 2.3 §14「Naming and Registry」（`docs/06:297-321`）

**現狀命名表**：

```text
CHAR_DEALER_CANON_V001.png
L3_DEALER_IDLE_STAGE00_V001.mp4
L2_DEALER_PLAYER_WIN_V001.png
L2_DEALER_PLAYER_WIN_V001.mp4
L1_CARD_BACK_V001.png
L1_TABLE_FELT_V001.png
```

**建議改為**：

```text
CHAR_DEALER_CANON_V001.png
L3_ROOM_BG_V001.png
L3_DEALER_IDLE_V001.png
L2_DEALER_REACT_PLAYER_WIN_V001.png
L1_CARD_BACK_V001.png
L1_TABLE_FELT_V001.png
```

變動說明：

- 新增 `L3_ROOM_BG_V001.png`（§5a 產出）、`L3_DEALER_IDLE_V001.png`（§5b 產出，取代原本融合圖）。
- 移除 `L3_DEALER_IDLE_STAGE00_V001.mp4`：待機改用引擎內動畫（見 2.1 §5b），不再需要 image-to-video 母帶命名格式；若之後仍要保留 video 版待機作為可選加強，建議另立 `L3_DEALER_IDLE_LOOP_V001.mp4` 而非預設命名，避免暗示這是必要產出。
- `L2_DEALER_PLAYER_WIN_V001` 系列統一補上 `REACT` 語意前綴（`L2_DEALER_REACT_PLAYER_WIN_V001`），與 §6 既有 Reaction IDs（`DEALER_REACT_PLAYER_WIN` 等，`docs/06:161-167`）命名邏輯對齊，避免 asset_id 與 Reaction ID 各用一套詞彙。
- `L2_..._V001.mp4` 版本是否保留，取決於 §11/§13 image-to-video 是否繼續作為 L2 反應的素材來源（本提案不動這部分邏輯，只動 L3）；若人工核准後決定 L2 也全面改用靜態圖＋引擎動畫，需要另一輪修訂，不在本提案範圍內。

`每個素材記錄` 的欄位清單（`docs/06:310-321`）不需變動，`asset_id` 欄位自然會吃到新的命名。

---

## 3. 額外納入：Anti-Infographic 規則的實測失效模式

### 3.1 現況與問題

`docs/06` §1（`docs/06:3-13`）要求每次生成 session 的**第一句**必須逐字貼上一段 anti-infographic 宣告；§3「Do not generate」（`docs/06:60-70`）是一份較長的否定清單，且目前 §4、§5、§6 等各 prompt 區塊都把 §1 的宣告文字整段複製貼在 prompt 開頭（例如 `docs/06:76-77`、`docs/06:110`）。

**實測發現**（生成過程中觀察到的行為，非理論推測）：

1. **Nano Banana（Gemini 影像 API）對長否定句 prompt 不穩定**：把 §1＋§3 整段否定句照抄送入 prompt 時，連續多次回傳空結果（API 層級錯誤 `responseParts is not iterable`）；把同一需求改寫成簡短的正面描述後恢復正常產出。這代表「把規則清單當 prompt 逐字貼上」這個使用方式本身會提高失敗率，不只是風格問題。
2. **"blackjack table" 這個詞本身是構圖陷阱**：在材質類 prompt（如 §8 Table Surface Asset）中提到 "blackjack table"，模型會自動腦補整套牌桌版面，包含下注圈、`INSURANCE` 保險區與亂碼標語——而本專案規則明文不做 Insurance（`AGENTS.md`、`specs/000_HOUSE_RULES_DECISION.md`）。改用材料詞彙（"wool baize"、"billiard cloth"）完全避開遊戲脈絡，才能穩定拿到純材質輸出。

### 3.2 建議修訂方向

- 把 §1／§3 的定位從「**逐字必用的 prompt 開頭**」改為「**生成後的意圖檢核清單**」：生成完成後，用 §1／§3 的條件逐條檢查產出是否誤入 infographic／UI mockup／文字標籤等，而不是把整段文字塞進送給模型的 prompt。
- 各 prompt 區塊（§4、§5、§6、§8 等）改以**正面描述**為主，只在確實需要時加極少量必要的否定句（例如「no text」在部分模型上仍是有效且必要的負面約束，不建議一律移除，只是不再整段照搬 §1/§3）。
- 新增一小節「**詞彙陷阱（Vocabulary Traps）**」，記錄目前已知會誘發不要構圖的詞彙與替代寫法，至少收錄：
  - `"blackjack table"` → 材質類 prompt 改用 `"wool baize"` / `"billiard cloth"` 等材料詞彙，避免觸發遊戲桌版面聯想。
  - 長串否定句整段複製貼上 → 改寫為簡短正面描述；否定約束保留但精簡到 1-2 條關鍵項。

此修訂與第 2 節的素材拆分是兩件獨立的事，但都在 §5/§6 的 prompt 文字範圍內，建議一併提出、一併審查，避免分兩輪改同一批 prompt。

---

## 4. 支持理由（附行號）

1. **消除形態矛盾**：拆分後荷官永遠是同一種素材形態（透明 PNG，疊在背景之上），待機（§5b）、反應（§6）、未來的進程狀態（`docs/01_GAME_AND_LAYER_SPEC.md:80`「Progression-specific Dealer state」、`AGENTS.md:109`「Progression-specific visual state」）都只是同一個插槽換圖，不需要為每種狀態重新設計「荷官在背景裡的位置」。
2. **進程狀態的成本**：`specs/003_LAYERED_PRESENTATION_PIPELINE.md`「L3 Behavior」需求 #5（明文將「L3 progression 內容尺度」列為本規格 Out of Scope，留給後續 spec）已經預告 L3 未來會有多個 progression 狀態。若荷官持續烙進背景，每新增一個進程狀態就要重新生成整張背景（含牆面、壁燈、布幔、賭桌），但這些元素在進程之間通常不變；拆分後只需重生荷官那一張。
3. **讓 L3 自身也是分層的，並與既有 Godot scene tree 對齊**：`docs/05_FIGMA_TO_GODOT.md:29-33` 的 Recommended Scene Tree 已經把 `L3Root` 拆成 `BackgroundView` 與 `DealerIdleView` 兩個獨立節點；`AGENTS.md:132`「不可把整個 UI 當成一張扁平背景圖」與 `specs/003_LAYERED_PRESENTATION_PIPELINE.md`「Cross-Layer Boundary Violations」最後一條（「任何完整畫面用單一扁平圖片呈現，而非多個 scene 組合」）都在講同一件事：不應該用單一整圖取代可組合的 scene 結構。目前 §5 產出的融合背景板，其實從一開始就不符合 Godot 端已經設計好的節點結構——這不是新增規則，是修正素材規格去符合既有架構。

   （附註：`specs/003` 原文引用的是 `AGENTS.md` 當時的第 103 行（此處刻意不寫成可被工具解析的引用格式，因為它描述的是已失效的歷史值，非現行引用），但目前 `AGENTS.md` 該行內容已因文件編修而位移，「不可把整個 UI 當成一張扁平背景圖」目前實際位於 `AGENTS.md:132`。本提案的引用已核對目前檔案的實際行號，`specs/003` 本身的行號註記已過期，是否需要一併修正不在本提案範圍，建議另行處理。）

4. **避開影片透明通道陷阱**：`docs/06` §11（`docs/06:240-249`）規劃用 image-to-video 做待機循環，但 §13（`docs/06:281`）自陳「Godot 4.x 核心目前原生支援 Ogg Theora；MP4／H.264 若要直接播放需額外 GDExtension，第一個 Vertical Slice 不應先增加這項依賴」。Theora 對 alpha channel 的支援不佳，這代表「用影片做去背荷官待機循環」在目前的引擎管線上本來就是個脆弱路徑。荷官拆成獨立透明 PNG 後，待機的呼吸／眨眼可以改用引擎內 `AnimationPlayer` 或 shader 做輕微縮放位移（不需要 alpha 影片），正好符合 §13 自己主張的「不先增加這項依賴」。

---

## 5. 代價與緩解

**代價**：背景與荷官分開生成後，兩張圖的光線一致性（光源方向、色溫、環境反射）不會被模型自動對齊，需要靠 prompt 明確指定並事後人工比對。

**緩解**（已寫入第 2 節修訂內容）：

- §5a（房間背景）與 §5b（荷官待機）的 prompt 都必須明確寫出**同一組**光源方向與色溫描述，作為兩邊生成時的共同錨點。
- §6 的反應圖 prompt 新增一條要求，明確對齊 `L3_DEALER_IDLE_V001` 的機位、裁切、比例與光線方向/色溫，而不是只對齊「canonical dealer reference」。

**這個代價本來就存在，不是拆分後新增的**：§6 原本的 6 張反應圖（`docs/06:158-167`）本來就是各自獨立生成的透明 PNG，同樣需要人工比對是否與（融合式）L3 背景對得上；拆分只是把「荷官 vs 背景」也變成同一種需要對齊的關係，並不是新增一種全新風險。

---

## 6. 不修改的部分（維持原狀）

- §2 Asset Production Order（`docs/06:17-29`）——production 順序邏輯不變，L3 環境／idle 仍在 canonical dealer reference 之後、L2 反應之前；只是「L3 環境／idle」內部現在對應兩個獨立 prompt，不是一個。
- §4 Canonical Dealer Reference Prompt（`docs/06:73-103`）——身份基準圖邏輯不變，§5b／§6 都繼續引用它。
- §7 L2 Chroma-Key Fallback（`docs/06:171-178`）——不變，仍是 §6 透明輸出不穩時的備援。
- §8 Table Surface Asset（`docs/06:182-196`）——本提案第 3 節指出的「blackjack table 構圖陷阱」建議一併處理，但 §8 本身的素材定位（seamless 材質貼圖）不變，只建議 prompt 措辭調整，不建議動結構。
- §9 Card Back Asset、§10 Decorative Button Texture（`docs/06:200-234`）——與本次問題無關，不動。
- §12 Reaction Video Prompt（`docs/06:253-263`）——L2 反應影片版本不在本提案範圍，因為 §6 靜態圖形態本來就正確，本提案未提議連動修改 §12。
- Reaction IDs 清單本身（`docs/06:158-167`）——沿用既有 6 種反應，不新增不刪除。

---

## 7. 有爭議 / 需要人工拍板的點

1. **待機影片是否完全捨棄**：本提案建議待機改用引擎內動畫取代 image-to-video（理由見第 4 節第 4 點），但若團隊已經在別處依賴 `L3_DEALER_IDLE_STAGE00_V001.mp4` 這個產出（例如已有生成好的素材或下游腳本引用該檔名），移除會有額外遷移成本。建議先確認目前是否已有實際產出此檔案，再決定是「立即移除」還是「保留作為可選加強、預設不生成」。
2. **§12 Reaction Video 是否需要連動修訂**：本提案只處理 L3（§5）與 L2 静態圖（§6），沒有動 §12 的反應影片 prompt。如果團隊之後也想把 L2 反應影片一併改成「静態圖＋引擎動畫」，那是範圍更大的第二輪修訂，建議另立提案，不建議塞進本次一起做。
3. **`specs/003` 的過期行號引用**（`AGENTS.md` 當時的第 103 行應為現行的 `AGENTS.md:132`）：本提案第 4 節第 3 點已指出這個落差，但修正 `specs/003` 本身不在「修訂 docs/06」這個任務範圍內，需要另外決定是否連動修正。
4. **§3 詞彙陷阱清單的完整度**：本提案第 3 節目前只收錄兩個已實測到的陷阱詞（"blackjack table"、長否定句照搬）。這份清單會隨著實際生成過程持續累積，建議定調為「持續維護的清單」而非一次寫完，需要人工確認是否同意這個維護方式。

---

## 8. 摘要（供快速核准用）

| 項目 | 建議 |
|---|---|
| §5 | 拆成 §5a（L3 房間背景，無人物，不透明 PNG）＋ §5b（L3 荷官待機，透明 PNG） |
| §6 | 保留現有邏輯，新增一條「對齊 §5b 機位/光線」的要求 |
| §14 | 新增 `L3_ROOM_BG_V001`、`L3_DEALER_IDLE_V001`；移除／降級 `L3_DEALER_IDLE_STAGE00_V001.mp4`；`L2_...` 系列補 `REACT` 前綴 |
| §1/§3 | 定位從「逐字必用開頭」改為「生成後檢核清單」；新增「詞彙陷阱」小節 |
| 待機動態 | 建議改用 Godot `AnimationPlayer`/shader，不依賴 image-to-video alpha 通道 |
| 需人工拍板 | 待機影片存廢、§12 是否連動、`specs/003` 行號修正、詞彙陷阱清單維護方式 |

本提案不修改任何既有檔案，需人工核准後才可套用到 `docs/06_AI_ART_AND_MEDIA_PROMPTS.md`（以及視第 7 節裁決結果，可能連動 `specs/003_LAYERED_PRESENTATION_PIPELINE.md` 的行號註記）。

---

## 9. 套用結果與現況落差（2026-08-13 套用時記錄）

- 第 7 節爭議點 #1（待機影片存廢）已由 team-lead 依現況資訊裁決：目前生成後端 `hermes-script` 實地測試回覆「不支援影片生成」，屬硬限制，不是團隊取捨——`L3_DEALER_IDLE_STAGE00_V001.mp4` 已從 §14 命名表移除，改記錄為「未來若後端支援影片，命名為 `L3_DEALER_IDLE_LOOP_V001.mp4`，非預設項目」。
- 第 7 節爭議點 #2（§12 是否連動）：本次套用**未修改** §12 Reaction Video Prompt，維持提案原範圍；§13 已加一句 cross-reference 提醒兩節理由不同層次，但未展開修訂 §12 本身。
- 第 7 節爭議點 #3（`specs/003` 過期行號引用）：本次套用**未修改** `specs/003_LAYERED_PRESENTATION_PIPELINE.md`，範圍限定在 `docs/06`。
- 第 7 節爭議點 #4（詞彙陷阱清單維護方式）：已在 `docs/06` §3 明確標註「此清單隨實際生成過程持續累積，非一次寫完」。
- **新發現的落差**：`assets/source/image/L3_ROOM_BG_V001.png` 母帶已存在，但 `assets/textures/` 目前**沒有**對應的 runtime 貼圖（`L3_DEALER_IDLE_V001.png` 有兩邊都存在，`L3_ROOM_BG_V001.png` 只有母帶、缺 runtime import）。`assets/source/image/` 另外還有一個 `L3_DEALER_PLATE_BAKED_V001.png`，疑似是拆分前的融合圖殘留。這兩點屬於「素材資產現況」而非「文件內容」問題，本次任務範圍是修訂 `docs/06`，未動 `assets/` 目錄下任何檔案，僅在此記錄供後續處理判斷。
