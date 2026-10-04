import { existsSync, createWriteStream, writeFileSync } from "node:fs";
import { resolve, join } from "node:path";
import { pipeline } from "node:stream/promises";
import * as dotenv from "dotenv";
import axios from "axios";

// Load credentials
const envLocalPath = resolve(process.cwd(), ".env.local");
if (existsSync(envLocalPath)) {
  dotenv.config({ path: envLocalPath });
}
dotenv.config();

import { config, higgsfield } from "@higgsfield/client/v2";

const credentials = process.env.HF_CREDENTIALS || process.env.HF_KEY;
if (!credentials) {
  console.error("Error: HF_CREDENTIALS or HF_KEY environment variable is not set.");
  process.exit(1);
}

config({
  credentials,
});

const MODEL = "bytedance/seedance-2.5/text-to-video";

const PROMPT = `High-end AAA anime cinematic style benchmark Genshin Impact and Solo Leveling aesthetic, 8k key visual fidelity. Deep underwater black ocean abyss of pure despair. Echo, a broken and drowning young human male, sinking into the dark reflective void with floating glowing violet memory bubbles. Zero, a majestic and terrifying shadow monarch entity shrouded in obsidian smoke and glowing violet nebulae, appears before him extending a dark metallic clawed hand. Close-up on Echo's desperate crying eyes reflecting the glowing violet singularity eye of Zero. Their hands touch in a soul-binding contract covenant. A colossal shockwave of dark violet energy and shattered reality fragments erupts outward, spreading dark shadow wings behind Echo. Deep obsidian black (#0B0D12), electric violet singularity glow (#7B2CBF, #9D4EDD), cold cyan embers (#00F0FF), subtle signal crimson warning pulses (#E63946). Extreme cinematic lighting, breathtaking hair and fabric physics, dynamic anime camera orbit and punch zoom, zero readable text or symbols.`;

async function downloadFile(url: string, destPath: string): Promise<void> {
  console.log(`Downloading video from ${url} to ${destPath}...`);
  const response = await axios.get(url, { responseType: "stream" });
  await pipeline(response.data, createWriteStream(destPath));
  console.log(`Download completed successfully: ${destPath}`);
}

async function main() {
  console.log("=== 11.11 Higgsfield Cinematics Director ===");
  console.log(`Target Model: ${MODEL}`);
  console.log("Scene: Zero Covenant & Shadow Transformation (Black Ocean Abyss)");
  console.log("Resolution: 1080p | Duration: 5s | Aspect Ratio: 16:9");
  console.log(`Prompt: ${PROMPT}\n`);

  const startTime = Date.now();

  try {
    console.log("Submitting generation request to Higgsfield API...");
    const result = await higgsfield.subscribe(MODEL, {
      input: {
        prompt: PROMPT,
        duration: 5,
        resolution: "1080p",
        aspect_ratio: "16:9",
      },
      withPolling: true,
    });

    console.log("Generation response received:", JSON.stringify(result, null, 2));

    const status = (result as any).status;

    if (status === "completed") {
      const videoUrl =
        (result as any).video?.url ||
        (result as any).videos?.[0]?.url ||
        (result as any).output?.video?.url ||
        (result as any).url ||
        (result as any).output?.url;

      if (!videoUrl) {
        throw new Error("Job completed but video URL was not found in response.");
      }

      console.log(`\nSuccess! Video generated in ${(Date.now() - startTime) / 1000}s`);
      console.log(`Remote Video URL: ${videoUrl}`);

      const outputDir = resolve(process.cwd(), "artifacts/eleven-eleven/cinematics");
      const videoPath = join(outputDir, "zero-covenant-transformation.mp4");
      const metadataPath = join(outputDir, "zero-covenant-transformation.json");

      await downloadFile(videoUrl, videoPath);

      const metadata = {
        title: "Zero Covenant & Shadow Transformation Scene",
        scenePhase: "DESPAIR_ABYSS_FALL -> ZERO_MEETING_COVENANT -> PACT_SEALED_EXPLOSION",
        model: MODEL,
        resolution: "1080p",
        duration: 5,
        aspect_ratio: "16:9",
        palette: [
          "#0B0D12 (Obsidian Void)",
          "#7B2CBF (Singularity Violet)",
          "#00F0FF (Cold Cyan Embers)",
          "#E63946 (Signal Crimson Accent)"
        ],
        prompt: PROMPT,
        remoteUrl: videoUrl,
        localFilePath: videoPath,
        higgsfieldResponse: result,
        generatedAt: new Date().toISOString(),
      };

      writeFileSync(metadataPath, JSON.stringify(metadata, null, 2), "utf8");
      console.log(`Metadata saved to: ${metadataPath}`);
      console.log("\nZero Covenant cinematic generation and pipeline delivery COMPLETE.");
    } else {
      console.error(`Generation ended with non-completed status: ${status}`, result);
      process.exit(1);
    }
  } catch (error: any) {
    console.error("Higgsfield generation failed:", error?.message || error);
    if (error?.response?.data) {
      console.error("Error response data:", JSON.stringify(error.response.data, null, 2));
    }
    process.exit(1);
  }
}

main();
