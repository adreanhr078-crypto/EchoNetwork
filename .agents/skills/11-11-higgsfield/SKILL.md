---
name: 11-11-higgsfield
description: >-
  Generate AI video and images using the Higgsfield API and integrate outputs
  into the 11.11 cinematic pipeline. Use for Echo transformations, chess
  entrances, cinematic cutscenes, and any image-to-video or text-to-video
  generation. Always supply a Blender-rendered reference frame when generating
  cinematic content. Do not modify frozen game logic, puzzle canon, or reward
  authority.
metadata:
  category: tooling
  source:
    repository: 'https://github.com/your-org/Futuristic-Eleven-Eleven'
    path: .agents/skills/11-11-higgsfield
    license: project-internal
---

# 11.11 Higgsfield AI Skill

Higgsfield AI is a cloud video and image generation service used to turn
Blender-authored scenes into polished cinematic AI video. It complements the
Blender → FFmpeg pipeline for cases where generative motion, stylization,
or camera animation is needed beyond what Blender's render can provide.

## Required environment variables

```bash
HF_API_KEY_ID=your-api-key-id       # from https://cloud.higgsfield.ai
HF_API_KEY_SECRET=your-api-key-secret
```

Add these to the `.env` file in the repository root. Never commit them to source control.

## Active implementation facts

- **Tool entry point:** `tools/higgsfield/run-higgsfield.ts` — CLI wrapper
- **Core client:** `tools/higgsfield/higgsfield-client.ts` — TypeScript HTTP client
- **Blender pipeline:** `tools/higgsfield/blender-to-video.ts` — renders a Blender frame then generates video
- **API base URL:** `https://api.higgsfield.ai`
- **Auth format:** `Authorization: Key {HF_API_KEY_ID}:{HF_API_KEY_SECRET}`
- **Asset destinations:**
  - AI-generated videos → `public/assets/cinematics/`
  - AI-generated images → `public/assets/ui/<surface>/`
- **Lazy-load rule:** All generated assets must follow the project lazy-load policy — load only after player enters the relevant surface.

## API request lifecycle

1. **Submit** → POST to generation endpoint → receive `request_id` and `status: "queued"`
2. **Poll** → GET `/requests/{request_id}/status` with exponential backoff
3. **Terminal states:** `completed` | `failed` | `nsfw` | `canceled`
4. **Download** → Fetch the `videos[0].url` or `images[0].url` to local disk

## Available subcommands

### Test credentials
```bash
npx tsx tools/higgsfield/run-higgsfield.ts -- doctor
```

### Generate an image
```bash
npx tsx tools/higgsfield/run-higgsfield.ts -- generate-image \
  --prompt "obsidian chess board, pale ivory pieces, signal crimson lighting, cinematic" \
  --aspect-ratio "16:9" \
  --output public/assets/ui/chess/ai-poster.jpg
```

### Generate video from text
```bash
npx tsx tools/higgsfield/run-higgsfield.ts -- generate-video \
  --prompt "Echo transforms from human to obsidian chess piece, signal crimson energy" \
  --duration 4 \
  --fps 24 \
  --camera-motion zoom_in \
  --output public/assets/cinematics/echo-transform.mp4
```

### Generate video from a Blender render (image-to-video)
```bash
npx tsx tools/higgsfield/run-higgsfield.ts -- generate-video \
  --image-file public/assets/ui/chess/poster.png \
  --prompt "cinematic push-in, obsidian chess board glows with crimson energy" \
  --duration 4 \
  --output public/assets/cinematics/chess-entrance.mp4
```

### Full Blender → Higgsfield pipeline (recommended for cinematics)
```bash
npx tsx tools/higgsfield/blender-to-video.ts -- \
  --blend path/to/scene.blend \
  --prompt "cinematic obsidian chess entrance, signal crimson lighting, fog" \
  --frame 1 \
  --camera-motion zoom_in \
  --output public/assets/cinematics/chess-entrance.mp4
```

### Check request status
```bash
npx tsx tools/higgsfield/run-higgsfield.ts -- status \
  --request-id d7e6c0f3-6699-4f6c-bb45-2ad7fd9158ff
```

## Visual contract for prompts

All prompts for 11.11 content MUST align with the visual contract:

| Element | Value |
|---|---|
| Primary palette | Obsidian black, pale ivory, signal crimson |
| Lighting | Restrained, dramatic; crimson rim light |
| Camera | Deliberate, slow push-in or orbit; no shaky-cam |
| Style | Cinematic, editorial; no cartoon or anime |
| Text | Never include readable text in generated images |
| Characters | Echo only — never invent new characters |

**Example prompt scaffold:**
```
"[subject/action], obsidian [environment], pale ivory [secondary element],
signal crimson [lighting/energy], cinematic lighting, editorial photography,
fog, 4K, no text"
```

## What is frozen and must not change

- Canon puzzle logic, story endings, Memory Shards counts.
- Achievement registry and server-owned reward authority.
- Cinematic scene assignments (do not replace Blender-authored cinematics
  with AI video without explicit owner approval).
- Do not auto-grant rewards from presentation or generation code.

## Required workflow for cinematics

1. Run `npm run agent:preflight` before any edit.
2. Author or confirm the Blender scene first — the AI video is derived from it.
3. Render the reference frame via `blender-to-video.ts` or manually via `run-blender.ts`.
4. Validate the prompt against the visual contract above.
5. Submit to Higgsfield and verify the output before integrating.
6. Integrate with lazy loading, reserved dimensions, and a CSS fallback frame.
7. Run `npm run agent:postflight` after integration.
