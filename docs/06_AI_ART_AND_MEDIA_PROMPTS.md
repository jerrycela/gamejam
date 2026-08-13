# 06 - AI Art and Media Prompt Pack

> **修訂紀錄（2026-08-13）**：Dealer／Background 素材結構拆分、§1/§3 定位調整、實測紀錄補充。提案見 `docs/plans/2026-08-13-doc06-asset-structure-revision.md`，經授權由 team-lead 核准套用（使用者已於 2026-08-13 明示授權「驗收過後即可通過」，本次核准為 team-lead 依授權執行，非使用者本人逐行審閱）。

## 1. Anti-Infographic Rule — 產出後檢核清單

**定位調整（2026-08-13）**：以下宣告**不再要求逐字貼在每個 prompt 開頭**。實測發現把整段否定句照抄送進影像模型（尤其 Nano Banana / Gemini 影像 API）會顯著提高失敗率，曾連續多次回傳空結果（`responseParts is not iterable`）；改成簡短正面描述後才恢復穩定產出。

正確用法：**生成完成後**，逐條核對產出是否符合以下條件，不合格則重新生成或調整 prompt——這是驗收清單，不是必貼文字：

```text
This is a production game asset request.
Do not create an infographic, diagram, flowchart, document page, UI mockup, presentation, labels, or explanatory text.
Generate only the requested game asset.
```

這用來避免再次產生「一整頁密密麻麻的流程文字」。各 prompt 區塊本身應以正面描述為主，只在必要時保留精簡的否定句（見 §3 詞彙陷阱）。

---

## 2. Asset Production Order

```text
Art Direction
→ Canonical Dealer Reference
→ L3 Environment / Idle
→ L2 Reactions
→ L1 decorative assets
→ Figma assembly
→ Godot integration
```

L1 interactive structure先在 Figma／Godot 建立，不讓 image model 生成完整 UI。

---

## 3. Output Rules

### Transparent static asset

優先要求：

```text
transparent background
PNG output
clean alpha edges
no shadow outside subject unless requested
```

GPT Image 系列的影像 API 支援透明背景 PNG 輸出；但仍需人工檢查髮絲、半透明與邊緣污染。

### Chroma-key fallback

若透明輸出不穩：

```text
uniform pure green background #00FF00
no green clothing, props, reflections, rim light, or environmental spill
hard separation between subject and background
```

靜態圖優先透明 PNG；綠幕只是 fallback。

### Do not generate

同樣改為**生成後檢核清單**（見 §1），不建議整段照抄進 prompt：

- 完整 UI Screen。
- HIT／STAND 等文字。
- 假的 Chips 數字。
- 牌面 rank/suit（除非是經驗證的單張牌 asset 任務）。
- watermark。
- logo。
- 多格 storyboard。
- before/after sheet。

### 詞彙陷阱（Vocabulary Traps）

實測發現特定詞彙會誘發不要的構圖，即使規則清單已明文排除。此清單隨實際生成過程持續累積，非一次寫完：

- **`"blackjack table"`**：材質類 prompt（如 §8 Table Surface Asset）若直接提到這個詞，模型會自動腦補整套牌桌版面，包含下注圈、`INSURANCE` 保險區與亂碼標語——而本專案規則明文不做 Insurance。改用材料詞彙（例如 `"wool baize"`、`"billiard cloth"`）可完全避開遊戲脈絡，穩定拿到純材質輸出。
- **長串否定句整段照搬**：把 §1／§3 的完整否定清單直接貼進 prompt 開頭，會提高 Nano Banana（Gemini 影像 API）回傳空結果的機率。改寫成簡短正面描述、只保留 1-2 條關鍵否定約束即可。

---

## 4. Canonical Dealer Reference Prompt

```text
This is a production game asset request.
Do not create an infographic, UI mockup, contact sheet, document, or text.

Create one canonical character reference image for the dealer character in a premium portrait mobile Blackjack game.

The character must be the sole identity reference for all later image-to-video and reaction assets.

Composition:
- front-facing or slightly three-quarter view
- seated or positioned behind a casino card table
- camera locked at the intended in-game angle
- enough empty foreground space for cards and Blackjack UI overlays
- portrait 9:16 composition
- consistent face, hairstyle, wardrobe, accessories, body proportions, table, lighting, and camera

Visual quality:
- refined commercial game art
- deliberate materials and lighting
- no generic AI glamour look
- no distorted hands
- no extra fingers
- no cards floating in the air
- no text, UI, logo, watermark, or collage

Output one image only.
```

在此 Prompt 後附加你批准的角色、服裝、風格、年齡與內容邊界。

**身分一致性（2026-08-13 補充）**：目前生成後端（`hermes-script` 的 `image_generate`）支援 image-to-image，可用 `image_url` 提供角色參考圖，不必只靠文字描述鎖身分。後續任何產出荷官素材（§5b、§6 等）時，應優先把 `CHAR_DEALER_CANON_V001` 作為 image reference 一併提供，而不是僅靠文字重複描述——純文字描述已知有輕微飄移風險。

---

## 5. L3 Background / Dealer Idle Reference

**結構調整（2026-08-13）**：原本的單一融合 prompt（把荷官烙進背景整圖）已拆成兩個獨立素材，對應 `docs/05_FIGMA_TO_GODOT.md:29-33` scene tree 中 `L3Root` 底下既有的 `BackgroundView` 與 `DealerIdleView` 兩個獨立節點。拆分方案已實際驗證可行：去背荷官合成到空房間背景上，光線、色溫、比例、桌緣位置全部對得上。母帶存於 `assets/source/image/`，runtime 貼圖存於 `assets/textures/`。

### 5a. L3 Room Background（餵給 `BackgroundView`）

```text
This is a production game asset request.
Generate only one Layer-3 room background plate for a portrait Blackjack game.

Purpose:
Persistent background presentation underneath the dealer sprite and independent Godot UI.

Requirements:
- portrait 9:16
- room, walls, wall sconces, drapery, and casino card table
- no character, no person, no dealer, no hands
- warm key light from upper-left, 3200K tungsten-leaning color temperature, soft rim light from table-level chip lights
- clear foreground and lower safe area for cards, action buttons, chips, and bet UI
- visually calm enough to loop as a static background
- no playing-card UI, no buttons, no readable text, no chip numbers
- no infographic, diagram, multi-panel sheet, logo, or watermark

Output one clean background plate only, opaque, no alpha channel required.
```

Asset ID：`L3_ROOM_BG_V001`（`.png`，1080×1920，不透明）。

### 5b. L3 Dealer Idle Reference（餵給 `DealerIdleView`）

```text
This is a production game asset request.
Generate only one Layer-3 dealer idle reference for a portrait Blackjack game.

Use the approved canonical dealer reference (provide CHAR_DEALER_CANON_V001 as an image reference when the generator supports image-to-image; do not rely on text description alone).
Preserve identity: same face, hair, wardrobe, proportions, and camera angle as the canonical reference.

Requirements:
- transparent background, PNG, clean alpha edges
- dealer only, waist-up framing, no table, no room elements
- warm key light from upper-left, 3200K tungsten-leaning color temperature, soft rim light from table-level chip lights (must match L3_ROOM_BG_V001 lighting)
- composed for the upper-middle visual zone, matching L3_ROOM_BG_V001 composition
- no playing-card UI, no buttons, no readable text, no chip numbers
- no infographic, diagram, multi-panel sheet, logo, or watermark

Output one asset only.
```

Asset ID：`L3_DEALER_IDLE_V001`（`.png`，透明背景）。

待機的呼吸／眨眼／輕微姿態調整，改由 Godot `AnimationPlayer` 或 shader 在 runtime 做，不再依賴 image-to-video（理由與實測依據見 §11／§13）。

---

## 6. L2 Isolated Dealer Reaction - Transparent PNG

Replace `<REACTION>`：

```text
This is a production game asset request.
Generate only one isolated dealer reaction asset.

Reaction:
<REACTION>

Use the approved canonical dealer reference (provide CHAR_DEALER_CANON_V001 as an image reference when the generator supports image-to-image; do not rely on text description alone).
Preserve identity, face, hair, wardrobe, proportions, camera angle, and lighting.

Output requirements:
- transparent background
- PNG
- one character only
- crop compatible with the existing portrait game composition
- clean alpha edge
- no table unless the reaction specifically requires hand contact with it
- no UI, text, cards, labels, logo, border, infographic, or contact sheet
- expressive but not exaggerated beyond the approved art direction
- match the camera angle, crop, scale, and lighting direction/color temperature of L3_DEALER_IDLE_V001 (§5b)

Output one asset only.
```

Reaction IDs：

```text
DEALER_REACT_PLAYER_WIN
DEALER_REACT_PLAYER_LOSE
DEALER_REACT_BLACKJACK
DEALER_REACT_PLAYER_BUST
DEALER_REACT_PUSH
DEALER_REACT_SURRENDER
```

6 張反應圖已產出並進版控（`assets/source/image/L2_DEALER_REACT_*_greenscreen_source.png`，runtime 版本在 `assets/textures/L2_DEALER_REACT_*_V001.png`），與 `L3_DEALER_IDLE_V001` 同機位。

---

## 7. L2 Chroma-Key Fallback

```text
Use a perfectly flat, uniform #00FF00 chroma-key background.
Do not use green in clothing, accessories, eye reflections, table, rim light, or shadows.
No gradient, texture, environmental reflection, glow, or background object.
Keep a clean high-contrast silhouette for keying.
```

---

## 8. Table Surface Asset

```text
Generate one seamless premium Blackjack table felt texture for a game UI.

Requirements:
- top-down material texture, not a full table scene
- subtle woven felt detail
- restrained luxury casino appearance
- tileable or large enough for controlled crop
- no text, betting labels, card outlines, logos, chips, cards, dealer, perspective scene, or UI
- no infographic or texture sample sheet

Output one texture only.
```

---

## 9. Card Back Asset

```text
Generate one symmetrical playing-card back design for a premium Blackjack game.

Requirements:
- exact centered symmetry
- clear safe border
- readable at small mobile size
- no rank, suit, text, logo, watermark, hands, table, mockup, or multiple cards
- flat front-facing orthographic card artwork
- no perspective
- output one design only
```

Card face rank/suit 建議使用可驗證的向量／程式組合，不靠 AI 重複生成 52 張，以避免符號錯誤。

---

## 10. Decorative Button Texture

只有在 Figma／Godot native StyleBox 無法達到視覺目標時使用：

```text
Generate one empty stretchable decorative frame texture for a mobile game action button.

Requirements:
- no label or text
- no icon
- centered and symmetrical
- clean corners suitable for nine-slice scaling
- transparent outside the frame
- no mockup, multiple states, UI screen, infographic, or shadow sheet
- one asset only
```

不同 state 優先由 Godot Theme 調色，不要每個 state 都生成一張完全不同的圖。

---

## 11. Image-to-Video Idle Prompt — 現況：暫不採用，改用引擎內動畫

**實測紀錄（2026-08-13）**：本節原本規劃用 image-to-video 產生待機循環，但已用兩層獨立理由排除，兩者不可混為一談：

1. **能力面（硬限制，當下即擋住）**：實地詢問本專案目前唯一可用的生成後端 `hermes-script`（Slack bot），其回覆明確：
   - **動態影片：不支援。** 工具集中沒有任何影片生成後端（無 MiniMax、Runway、Kling、Sora 等），`image_generate` 僅限靜態圖片。
   - **透明背景：不適用**（因為根本不能產影片）。
   - **參考圖片輸入：圖片生成可以，影片不行。** `image_generate` 支援 image-to-image（可用 `image_url` 提供角色參考／編輯，見 §4、§6 補充）。
   - `hermes-script` 本身也建議走引擎內動畫，理由是「AI 影片生成在角色一致性與無縫循環這兩點上目前還很不穩」。
   - 這是工具鏈當下的限制，未來生成後端更新（例如新增影片模型）可能解除。
2. **架構面（長期理由，即使能力解除仍成立）**：見 §13——Godot 4.x 核心目前原生僅支援 Ogg Theora，Theora 的 alpha channel 支援不佳；「去背荷官＋動態影片」這個組合在引擎端本來就是脆弱路徑。

兩個理由都指向同一個結論（待機動態改用 Godot `AnimationPlayer` 或 shader 做輕微縮放位移／呼吸／眨眼），但性質不同：#1 是當下擋住、可能隨工具更新解除；#2 是架構限制、不會因為工具更新而改變。以下 prompt 保留供未來生成後端支援影片時參考，**目前不作為必要產出**：

```text
Animate the approved Layer-3 dealer reference into a seamless subtle idle loop.

Keep camera, framing, face, wardrobe, table, lighting, and background locked.
Only subtle natural breathing, blinking, tiny posture adjustment, and ambient movement.
No camera movement, zoom, cut, morphing, new props, card dealing, lip-sync, text, or UI.
The first and final frames should be visually compatible for looping.
```

---

## 12. Reaction Video Prompt

```text
Animate the approved canonical dealer reference into this reaction:
<REACTION>

Preserve exact identity, wardrobe, camera, table, lighting, and background.
The motion should begin from the standard idle pose and return to a compatible resting pose.
No camera cut, zoom, morphing, extra limbs, new props, text, UI, cards appearing from nowhere, or background redesign.
Produce one short reaction clip only.
```


---

## 13. Video Source and Godot Runtime Pipeline

原始簡報允許 L2／L3 visual 以 MP4 製作；本專案保留這個製作方式，但把「製作母帶」與「Godot runtime 檔案」分開。

```text
AI video / editor output
→ MP4 source master
→ keep under assets/source/video
→ transcode and validate
→ Ogg Theora .ogv runtime asset
→ Godot VideoStreamPlayer
```

Godot 4.x 核心目前原生支援 Ogg Theora；MP4／H.264 若要直接播放需額外 GDExtension，第一個 Vertical Slice 不應先增加這項依賴。Theora 對 alpha channel 支援不佳，這是「去背荷官＋影片待機循環」目前不採用的架構面理由，與 §11 記錄的生成後端能力限制是兩件獨立的事（見 §11 實測紀錄）。

Prototype 建議：

```text
mobile target: up to 720p, 30 FPS
one primary full-frame video decoder at a time
short L2 clips
short seamless L3 loops
static image fallback for every required reaction
```

Codex 必須保存 MP4 source master，不可用轉檔結果覆蓋它。

---

## 14. Naming and Registry

```text
CHAR_DEALER_CANON_V001.png
L3_ROOM_BG_V001.png
L3_DEALER_IDLE_V001.png
L2_DEALER_REACT_PLAYER_WIN_V001.png
L1_CARD_BACK_V001.png
L1_TABLE_FELT_V001.png
```

**2026-08-13 修訂**：

- 新增 `L3_ROOM_BG_V001.png`（§5a）、`L3_DEALER_IDLE_V001.png`（§5b），取代原本的融合背景板。
- 移除 `L3_DEALER_IDLE_STAGE00_V001.mp4` 這個預設命名——待機動態改用引擎內動畫，image-to-video 母帶目前不是必要產出（見 §11 實測紀錄）；若未來生成後端支援影片且團隊決定仍要一份影片版待機，命名為 `L3_DEALER_IDLE_LOOP_V001.mp4`，非本表預設項目。
- `L2_..._V001` 系列統一補上 `REACT` 語意前綴，與 §6 既有 Reaction IDs（`DEALER_REACT_PLAYER_WIN` 等）命名邏輯對齊；`.mp4` 版本是否保留取決於 §12 是否/何時連動修訂（本次修訂未涉及）。

**現況（已產出，非規劃中）**：`L3_ROOM_BG_V001`、`L3_DEALER_IDLE_V001`、6 張 `L2_DEALER_REACT_*`、`L1_CARD_BACK_V001`、`L1_TABLE_FELT_V001`、`CHAR_DEALER_CANON_V001` 皆已生成並進版控。母帶在 `assets/source/image/`，runtime 貼圖在 `assets/textures/`。

### 已取代素材（SUPERSEDED）——保留，不可清除

被 §5 拆分決策取代的素材，狀態標記為 `SUPERSEDED`，**保留供追溯，不進 runtime，不得清除**：

- `L3_DEALER_PLATE_BAKED_V001.png`（`assets/source/image/`）——拆分前「荷官烙進背景」單一融合結構的產物，即本文件修訂前 §5 prompt 的實際輸出樣本。取代理由見 `docs/plans/2026-08-13-doc06-asset-structure-revision.md`（問題陳述第 1 節）。已登記於 Figma `09 Media Assets` 頁（frame `19:21`）。此檔案存在的意義正是「為什麼不把荷官畫進背景」這個問題的直接答案；沒有這張圖，拆分決策就少了最直觀的佐證。

**通則**：被取代的素材應標記 `SUPERSEDED` 並保留，而非刪除；本節命名與登記表應涵蓋 `assets/` 下所有實際存在的素材檔案，而不只是目前生效版本——未被任何文件提到的檔案，會被後續維護者誤判為可清除的殘留垃圾。

每個素材記錄：

```text
asset_id
prompt_version
generator
source references
output date
approval status
source path
runtime path
figma usage
godot usage
```
