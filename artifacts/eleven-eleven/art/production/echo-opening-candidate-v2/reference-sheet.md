# Echo Awakening Candidate V2 — Design & Reference Sheet

## 1. Approved Canonical Source Documentation

This candidate is authored strictly against the approved Canon and production authorities:
- **Canonical Manhwa Publication:** `11.11_Echo_Network_Manhwa_FINAL_ORDERED_NO_DUPLICATES.pdf`
  - SHA-256: `6BE33FDD8A66210302AA44ED56D854B544F7A8B4C62AA57108557438571BFF1C`
  - Total Pages: 70
  - Converted Archive: `public/manhwa/echo-network-final-2026-09-v1/`
- **Story Bible:** `story-bible--echo-network.ar.md`
  - SHA-256: `6611D77A9360033267FBCC92674523FCE3D0D682471E7544DCEB5882F8E6B982`
- **Narrative Master:** `narrative-master--echo-network.ar.md`
  - SHA-256: `0C347C44A8C288FFAA7C2C308A5A4917D60955B641DA7EFEEE8461DE6DEFC88A`
- **Owner Video References:** `art/references/owner-2026-09-09/videos/`

---

## 2. Manhwa Page Inspection & Appearance Evidence (Chapter 1: Pages 1–9)

| Manhwa Page | Key Visual Features & Canon Evidence | Model Translation in Candidate V2 |
|---|---|---|
| **Cover (`page-001.webp`)** | Iconic hero shot: Jet black layered anime hair with distinct pointed locks falling over the forehead and temples; sharp youthful jawline with tapered chin; determined dark grey/obsidian eyes; structured dark jacket over lighter high-collar under-layer; direct-skin exposure on left neck. | Sculpted 13-clump layered hair volume (front fringe, temples, crown tufts, nape locks); defined chin and jawline; dark anime eye meshes with white sclera and pupils; dual-layer jacket with lapels and inner shirt collar; left-neck decal mesh `SkinTattoo_EX011`. |
| **Page 2 (`page-002.webp`)** | Threshold of 11:11 ("عتبة 11:11"): Digital clock frozen at 11:11; cold industrial laboratory lighting; high contrast shadow and teal/crimson accents. | 3-point anime lighting (warm sun key, cool ambient fill, rim kicker light highlighting hair and silhouette edges). |
| **Pages 3–4 (`page-003.webp`, `page-004.webp`)** | Echo awakening inside the consciousness transfer pod: Reclined posture; eyes slowly opening from closed slit; disorientation and awakening breathing; collar slightly open. | Authored `WAKEUP` animation (72 frames): starts reclined, head turns left and right, chest breathes deeply, torso lifts; neutral anime eyelid and brow geometry. |
| **Pages 5–6 (`page-005.webp`, `page-006.webp`)** | Echo sitting upright in experiment chamber: Direct skin of left neck exposed showing subject identification mark `EX-011`; ordinary youth anatomy (not yet transformed); lean athletic build (~175cm, ~1:7.5 head-to-body proportion). | Geometry strictly keeps human proportions: height 1.75m, head 0.23m; `SkinTattoo_EX011` bound directly to neck skin mesh with signal crimson material `M_Echo_Tattoo`. |
| **Pages 7–8 (`page-007.webp`, `page-008.webp`)** | Full standing posture in isolation chamber: Echo examining his hands and fingers; realizing his physical presence in the system; tailored dark trousers and dark footwear with light soles; interactive movement towards frozen clock. | Articulated hands with palm, thumb (2 segments), and 4 fingers (each with knuckle definition); authored `STANDUP` (72 frames) and `INTERACT` (48 frames) showing reach and hand operation. |
| **Page 9 (`page-009.webp`)** | Approach to heavy vault exit door: Transition into third-person exploration and escape room sequence; active locomotion. | Authored loopable `IDLE` (60 frames), `WALK` (32 frames), and `RUN` (20 frames) with alternating leg/arm swing and hip bobbing. |

---

## 3. Strict Canon & Design Boundaries

1. **Pre-Zero Canon State:**
   - In Chapter 1, Echo is an ordinary young man entering the experiment.
   - **No Zero transformation elements** are present: no dark shadowy aura, no black sclera or split violet/crimson eyes, no monstrous appendages.
2. **Direct-Skin Identification:**
   - The production code `EX-011` is placed directly on the skin of the neck, not on clothing.
   - Represented by the mesh `SkinTattoo_EX011` with `M_Echo_Tattoo`.
3. **Clothing Hierarchy:**
   - Outer layer: Dark charcoal/obsidian anime jacket (`M_Echo_Jacket`).
   - Inner layer: Pale grey/ivory shirt (`M_Echo_Shirt`).
   - Lower body: Dark tailored trousers (`M_Echo_Pants`) and sneakers (`M_Echo_Shoes` with `M_Echo_ShoeSole`).
4. **Locomotion Ownership:**
   - All authored animations are in-place; the Three.js/R3F runtime owns world translation.
   - Root bone remains fixed at (0, 0, 0).

---

## 4. Discrepancies & Next-Stage Artistic Notes

- **Current Hand-Crafted Geometry vs. Studio Sculpting:**
  The candidate geometry provides genuine 3D humanoid topology, facial features, layered hair clumps, and 5-finger hands. However, studio Genshin-grade character models typically utilize ZBrush high-poly sculpting baked onto a retopologized mesh with custom normal maps and cel-shade vertex color painting.
- **Facial Rigging:**
  The current head uses a single `head` bone with separate eye/pupil/lid geometry. For dynamic dialogue and cinematic cutscenes, 52 ARKit facial blendshapes or dedicated facial bone controllers (jaw, eyelids, lips, cheeks, brows) should be authored in the next phase.
