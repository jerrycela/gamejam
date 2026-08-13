# 06 - AI Art and Media Prompt Pack

## 1. Anti-Infographic Rule

所有美術生成 Session 的第一句都要明確寫：

```text
This is a production game asset request.
Do not create an infographic, diagram, flowchart, document page, UI mockup, presentation, labels, or explanatory text.
Generate only the requested game asset.
```

這用來避免再次產生「一整頁密密麻麻的流程文字」。

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

- 完整 UI Screen。
- HIT／STAND 等文字。
- 假的 Chips 數字。
- 牌面 rank/suit（除非是經驗證的單張牌 asset 任務）。
- watermark。
- logo。
- 多格 storyboard。
- before/after sheet。

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

---

## 5. L3 Full Background / Dealer Idle Reference

```text
This is a production game asset request.
Generate only one Layer-3 in-game background plate for a portrait Blackjack game.

Purpose:
Persistent dealer/background presentation underneath independent Godot UI.

Requirements:
- portrait 9:16
- use the approved canonical dealer reference
- same face, hair, wardrobe, table, lighting, and camera
- dealer placed in the upper-middle visual zone
- clear foreground and lower safe area for cards, action buttons, chips, and bet UI
- visually calm enough to loop as an idle image-to-video source
- no playing-card UI, no buttons, no readable text, no chip numbers
- no infographic, diagram, multi-panel sheet, logo, or watermark

Output one clean background plate.
```

---

## 6. L2 Isolated Dealer Reaction - Transparent PNG

Replace `<REACTION>`：

```text
This is a production game asset request.
Generate only one isolated dealer reaction asset.

Reaction:
<REACTION>

Use the approved canonical dealer reference.
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

## 11. Image-to-Video Idle Prompt

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

Godot 4.x 核心目前原生支援 Ogg Theora；MP4／H.264 若要直接播放需額外 GDExtension，第一個 Vertical Slice 不應先增加這項依賴。

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
L3_DEALER_IDLE_STAGE00_V001.mp4
L2_DEALER_PLAYER_WIN_V001.png
L2_DEALER_PLAYER_WIN_V001.mp4
L1_CARD_BACK_V001.png
L1_TABLE_FELT_V001.png
```

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
