# 10 - Knowledge Governance, Decisions, Risks, Sources

## 1. Three Asset Classes

### Code Assets

Godot scenes, scripts, tests, Theme resources。

### Visual Assets

Figma components, tokens, PNG／WebP／SVG, video, audio。

### Knowledge Assets

Specs, prompts, component IDs, decisions, manifests, acceptance criteria。

知識資產若沒有版本與狀態，AI 會反覆依聊天內容猜測。

---

## 2. Minimal Governance

不需要複雜 PLM 系統。

只要求：

- Stable ID。
- Status。
- Version。
- Last updated date。
- Source link/path。
- Approval state。

例如：

```text
ID: BTN_ACTION
Version: 1.2.0
Status: APPROVED
Figma: <node URL>
Godot: res://ui/components/action_button.tscn
```

---

## 3. Version Semantics

```text
PATCH: visual correction, no contract change
MINOR: new variant or backward-compatible behavior
MAJOR: semantic or interaction contract change
```

不需要每次像素微調都新建一大份文件；只更新 relevant version 與 change note。

---

## 4. Decision Log

重要決策放在已批准 spec 或此表：

| Decision ID | Decision | Status |
|---|---|---|
| DEC-001 | UI 不使用整張扁平 AI 圖 | APPROVED |
| DEC-002 | L1/L2/L3 為 runtime presentation model | APPROVED |
| DEC-003 | Figma Components/Tokens 為 design-time model | APPROVED |
| DEC-004 | 使用 Figma 企業付費帳號與 MCP 完整讀寫；定向寫入後需人工批准 | APPROVED |
| DEC-005 | Runtime 不依賴 Codex/MCP/live AI | APPROVED |
| DEC-006 | House Rules prototype profile | PROTOTYPE APPROVED |
| DEC-007 | Core bet transaction, P-D-P-D deal, peek, HIT-to-21, and Shoe diagnostics | APPROVED |

---

## 5. Main Risks

| Risk | Impact | Mitigation |
|---|---|---|
| Figma MCP 寫入範圍過大 | 非預期元件或畫面被修改 | 鎖定 file/node/component ID + version approval + manifest |
| Flat UI image | expensive detail iteration | independent components |
| AI character inconsistency | low visual quality | canonical reference + image-to-video |
| AI-generated card symbols wrong | gameplay trust failure | vector/procedural deck assets |
| L2 blocks forever | game deadlock | timeout + fallback |
| UI and core both calculate rules | inconsistent outcomes | RoundController authority |
| Overengineering | slow prototype | minimal modules and feature specs |
| Spec drift | Codex guesses | source priority + PROJECT_STATE |
| Video format/platform issue | playback failure | validate early, keep static fallback |
| Sensitive-content store restrictions | distribution risk | define content policy before production |
| Figma 企業帳號存取中斷（席次調整或人員異動） | docs/04、05 與 08 §7 的視覺工作流停擺 | 降級為手動 export，Component Manifest 維持不變，已批准元件不受影響 |

---

## 6. Figma Account and MCP Assumption

Project-specific assumption confirmed by the user：

- The project can use a colleague's Figma enterprise paid account.
- Figma MCP full read/write capability is available to the project workflow.
- Components, Variants, Tokens／Variables, Screens, Team Libraries, and targeted canvas updates may be used as required.
- MCP writes still require exact target IDs, approved specs, version tracking, and human visual approval.
- Component Manifest remains required to map approved Figma versions to Godot scenes and themes.

Reference documentation：

- https://developers.figma.com/docs/figma-mcp-server/
- https://help.figma.com/hc/en-us/articles/39216419318551-Get-started-with-the-Figma-MCP-server
- https://help.figma.com/hc/en-us/articles/360056440594-Create-and-use-variants
- https://help.figma.com/hc/en-us/articles/360025508373-Publish-a-library

---

## 7. Godot Official References

- UI is built from `Control` nodes and layout `Container` nodes.
- `Theme` resources allow shared styles across controls.
- Theme type variations avoid repeated per-node overrides.
- PNG and WebP support alpha; SVG support is useful but complex SVG can import imperfectly.

References：

- https://docs.godotengine.org/en/stable/tutorials/ui/
- https://docs.godotengine.org/zh_TW/stable/classes/class_theme.html
- https://docs.godotengine.org/zh-cn/4.x/tutorials/assets_pipeline/importing_images.html
- https://docs.godotengine.org/en/4.4/tutorials/animation/playing_videos.html

---

## 8. OpenAI Image Reference

GPT Image APIs support transparent background with PNG output when requested.

Reference：

- https://platform.openai.com/docs/api-reference/images-streaming
- https://developers.openai.com/api/docs/models/gpt-image-2

透明輸出仍需視覺 QA，不可假設所有邊緣自動 production-ready。
