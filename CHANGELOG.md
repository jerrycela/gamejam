# Changelog

## V3.1 - 2026-08-13

- Corrected the development methodology name to **SDD - Spec-Driven Development** throughout the Knowledge Pack.
- Updated the Figma operating assumption to an enterprise paid account with full MCP read/write capability.
- Removed Starter/free-plan quotas and manual-export constraints as the project baseline.
- Kept Component Manifest, targeted node writes, and human visual approval as governance controls rather than account limitations.

## V3 - 2026-08-13

### Rebuilt around the actual product

- Product is explicitly Blackjack / 21, not a generic interactive-video game.
- Preserved the deck's LAYER-1 / LAYER-2 / LAYER-3 and WAIT / HOLD / LOOP concepts.
- Added a formal Interaction Contract between rules, visuals, and runtime.

### Visual Engineering restructuring

- Rejected the flattened full-screen AI UI approach.
- Defined Figma Tokens, Components, Variants, stable IDs, and a Component Manifest.
- Separated design-time Figma architecture from runtime L1/L2/L3.
- Defined a Figma component workflow; V3.1 updates its account baseline to enterprise MCP read/write access.

### Godot restructuring

- Reduced the runtime to a minimal set of responsibilities.
- Added Figma-to-Godot mapping through Control, Container, Theme, StyleBox, and reusable scenes.
- Added explicit blocking/non-blocking presentation contracts and failure fallback.

### AI asset restructuring

- Added anti-infographic instructions.
- Added transparent PNG and chroma-key fallback specifications.
- Added canonical Dealer, L2 reaction, L3 idle, card-back, table texture, and video prompts.
- Separated MP4 production masters from validated Godot runtime video assets.

### SDD and Codex

- Added four gates: rule, interaction, visual, acceptance.
- Added one-page start instructions and reusable Codex prompts.
- Added PROJECT_STATE.md for session handoff.
- Added lightweight knowledge-asset versioning without introducing a general-purpose framework.
