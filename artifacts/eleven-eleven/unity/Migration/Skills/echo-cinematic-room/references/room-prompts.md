# Four-image room direction packet

Read this when preparing room reference images and a Flow cinematic. Replace bracketed fields with measured project facts; remove irrelevant requests rather than inventing features.

## Shared room description

Original premium anime game environment for [room/storybeat]. The SAME measured [width]m × [length]m × [height]m room appears in every image. The continuity anchors are [entrance transform], [exit transform], [hero apparatus transform], [observation wall transform], and [primary interaction transform]. Materials: readable charcoal titanium, neutral pale ceramic, controlled cyan equipment lighting, violet reflected accents and small amber mechanism indicators. Physically modeled bevels, service seams, ventilation fins, cable organizers and believable fasteners. Layered specular response and localized condensation; details remain visible in shadow. Preserve an unobstructed main playable path. Characters, readable signs and later-story effects appear only if explicitly required by Canon. No unrelated props or altered architecture.

## Four separate reference prompts

1. Entry wide: eye-height [camera]m, [lens]mm lens, view from the measured entrance toward the hero apparatus. Strong foreground/midground/background separation; stable wall rhythm and clear equipment scale. Use the actual native entry screenshot as the geometry anchor. Enrich materials and functional details without moving landmarks.
2. Reverse wide: same room and exact accepted entry-reference geometry, view back toward the entrance from the hero-apparatus side. Retain the capsule, observation panel and equipment positions. Use the native reverse screenshot together with the accepted first image as anchors. No mirrored floor plan or duplicated doors.
3. Lateral utility view: same accepted room, oblique side view revealing the observation bay, diagnostic cart and recessed maintenance modules. Show practical connections and mounting details. Preserve doorway clearance and equipment identities from both wide views.
4. Hero detail: close three-quarter view of the approved hero apparatus with some surrounding floor and wall landmarks for continuity. Show material transitions, seals, latches, rim lights and limited condensation at usable modeling resolution. Avoid cropped-only silhouettes when the image will become a Tripo reference.

For every generated image inspect perspective, door count, prop identity, room plan and actual usable silhouette before acceptance. Generate versions non-destructively. Keep four individual files; a four-panel contact sheet is an optional presentation artifact and never replaces them.

## Flow cinematic template

Create an original [duration]-second [aspect]-ratio cinematic of the SAME empty room shown in the four-image packet. Preserve measured architecture, ceiling height, landmark positions, prop counts and material palette throughout. Start at [accepted entry camera] with a deliberate [camera move] toward [hero landmark], then [supported second view/shot]. Camera movement has gentle acceleration and deceleration, stable perspective and natural parallax. Introduce visual life through sparse suspended dust, a thin condensation curl and one restrained reactive status-light change; keep solid architecture stationary. Controlled cyan/violet/amber contrast, readable neutral surfaces, rich reflected material detail, crisp silhouettes, filmic depth of field that does not obscure resources. No camera shake, architectural morphing, duplicate props, object melting, text overlays, unexplained powers or story spoilers.

Audio: [approved language and dialogue, or no speech]. Low room-tone ventilation, occasional quiet relay click and restrained glass/metal resonance tied to the actual scene; dialogue remains intelligible. Do not add an unapproved soundtrack or dialogue. Retain a clean ambient take when audio is requested for reusable game sound.

Record all four image filenames and the exact submitted prompt alongside the actual Flow job. Check the selected mode's attachment limit. If it cannot ingest four images in one clip, use a supported storyboard/multi-shot packet or a reviewed four-view contact sheet with the individual originals retained; record actual submissions. Do not silently drop a reference or claim all four were uploaded. A blocked submission remains open.

## Frame-to-resource brief

For each accepted resource: object ID, reference frame timestamp and crop, measured target dimensions, front/up axes, pivot, hidden-side modeling assumptions, material needs, triangle/texture budget, interaction/physics that must stay, and current Tripo parameters/taskID. For multiview use matching views of the same isolated object. Keep VFX and characters outside structural resource generation. Asset acceptance requires actual geometry and native review, not cinematic beauty alone.

## Evidence packet records

Use contained relative file paths and their actual SHA256 values. A file record has the form `{"path":"references/entry.png","sha256":"actual-64-character-sha256"}`. Keep provider credentials outside the packet. The validator checks common image/video/model container structure and declared ledger links; it cannot prove pixels are coherent, frames were genuinely extracted, a video was watched, audio was heard, or gameplay was tested.

Compressed Blender `.blend` files use a Zstandard header on current Blender versions. When an optional decoder is absent, the standalone validator recognizes that header only; open the file in Blender to verify its actual editable contents. External buffers/textures of a `.gltf` also require separate contained file records and inspection. Full decode/playback and independent native review remain mandatory.

- Each `references` row has a nonempty unique `id`, one of `entry`, `reverse`, `lateral`, `hero-detail` as `role`, a `file` record, and `review`. Use `accepted` only after actual independent image review. All four must be distinct image files before `references-reviewed`.
- `cinematic` uses `provider`, `provider_task_id`, `status`, `review`, `file`, `duration_s`, `submitted_reference_ids`, `prompt_file` and `submission_evidence`. The last two are file records of the actual submitted prompt and actual submission evidence. A blocked job stays `blocked`, with acceptance open and no invented movie.
- Each `frames` row uses a nonempty unique `id`, `file`, `timestamp_s`, `review` and `source_video_sha256` matching the cinematic file. Select at least four distinct actual timestamps after watching the entire video and listening to requested audio. The hash association is declared provenance, not a replacement for extraction/playback evidence.
- Each `assets` row uses `id`, `provider`, `provider_task_id`, `source_frame_id`, `raw`, `model`, `editable`, `geometry_review` and `native_review`; file fields are file records. Add measured dimensions, axes, pivots and hidden-side assumptions to each resource brief. Group `asset_briefs` into structure, equipment, furniture and hero props. Actors and moving VFX remain separate from the environment kit.
- `generation_jobs` rows use `provider`, `task_id`, `status` and `charged_credits`. A successful cinematic/asset must match its actual successful job in the shared ledger with its recorded nonnegative numeric charge. Booleans are not credit costs. `budgets` map each provider to `authorized_credits`; sum all known charges, including charged failed attempts. Never fabricate a zero charge for an unknown deduction.
- `native-reviewed` additionally requires independent `PASS` declarations for visual, traversal, pause, Reduced Motion, mute and performance, plus actual contained `native_evidence` file records. Validator PASS describes packet integrity; final native/art/device judgments remain independent.

Keep the packet at `draft` or the last truly completed stage while Flow is blocked. Independent Tripo work may continue within existing authorization and a shared budget, but it does not satisfy the missing cinematic stage. Synthetic test packets and reused media must be clearly labeled and never promoted to production evidence.

## EchoNetwork opening example

Current measured opening shell is18m wide,25.4m long and7.2m tall, centered z=-5.5; fullfacility42m length is not the opening room length. Existing entry/reverse/detail screenshots are in audits/evidence/opening_visual_candidate_v5_20261008. Sourcegeometry/authority remains the live Godot scene; any still-generated additional greebles are proposed derivatives, not evidence of implementation. The wake capsule, clock, photo/memory pedestal and signal terminal keep existing approved transforms. Zero/powers/revenge do not appear in opening room imagery. Japanese voice direction with Arabic/English captions follows currentprojectmemory unless the owner changes it.
