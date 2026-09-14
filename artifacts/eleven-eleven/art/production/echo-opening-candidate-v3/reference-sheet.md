# Echo Opening Candidate V3 — Reference Sheet & Canon Alignment

**Asset Identifier:** `EX-011`  
**Character:** Echo (Protagonist)  
**Target Quality Bar:** Genshin Impact / AAA Stylized Anime PBR  
**Canon Source Authority:** `docs/internal/narrative/current/ar/manifest.json` & Approved Part 1 Manhwa

---

## 1. Visual Identity & Anime Design Rules

| Feature | Canon Requirement | Candidate V3 Implementation |
|---|---|---|
| **Facial Structure & Expression** | Sharp stylized anime contours, calm focus, cold intensity | 46K Quad-based anime head with sharp jaw, tapered chin, and anime facial planes |
| **Eyes (Heterochromia)** | Left eye glowing vibrant cyan/blue; right eye system-corrupted/dark patch | High-contrast left cyan iris with emissive bloom; right eye system-shadowed |
| **Hair Style** | Layered obsidian anime bangs, fringe tapering past brow | 13 detailed anatomical hair clumps/tufts with rim highlight response |
| **Tactical Outerwear** | Long armored trench coat, obsidian black, flared skirts | Multi-layered high-collar coat with split tail and red structural piping |
| **Material Finish** | Non-reflective, matte fabric/leather (eliminating plastic gloss) | Principled BSDF with Roughness 0.72, Specular 0.18, and anime 3-point lighting response |
| **System Identity Mark** | Direct-skin `EX-011` barcode/tattoo on the neck | Dedicated `SkinTattoo_EX011` geometry bound to `neck` bone with Signal Crimson emission |
| **Lighting Response** | Cel-shaded 2-band shadow falloff with edge rim kicker | Tuned key/fill/rim response compatible with Three.js/R3F toon shaders |

---

## 2. Technical Topology & Engine Compatibility

* **Base Model Source:** High-fidelity Quad46K source derived from 8K studio asset.
* **Triangle Budget:** 75,081 triangles (Strictly within the `<= 80,000` budget).
* **Bone Hierarchy:** 41 bones (Strictly within the `<= 128` budget), all fully connected back to `root`.
* **Standard Clip Suite:** 6 dynamic actions (`IDLE`, `WALK`, `RUN`, `INTERACT`, `WAKEUP`, `STANDUP`), each with verified non-rigid relative bone transformations.
* **Tattoo Binding:** Distinct mesh `SkinTattoo_EX011` weighted to `neck` bone.
