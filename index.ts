import { existsSync } from "node:fs";
import { resolve } from "node:path";
import * as dotenv from "dotenv";

// Load server-side credentials from .env.local without exposing their values
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

// Configure client server-side
config({
  credentials,
});

export async function runExample(): Promise<string | undefined> {
  const model = "bytedance/seedance-2.5/text-to-video";
  const prompt = "A cinematic scene at sunset";
  const duration = 5;
  const resolution = "720p";
  const aspectRatio = "16:9";

  console.log(`Submitting generation request to ${model}...`);
  console.log(`Parameters: prompt="${prompt}", duration=${duration}, resolution=${resolution}, aspect_ratio=${aspectRatio}`);

  try {
    const result = await higgsfield.subscribe(model, {
      input: {
        prompt,
        duration,
        resolution,
        aspect_ratio: aspectRatio,
      },
      withPolling: true,
    });

    const status = result.status as string;

    if (status === "completed") {
      const videoUrl =
        result.video?.url ||
        (result as any).videos?.[0]?.url ||
        (result as any).output?.video?.url ||
        (result as any).url;

      if (!videoUrl) {
        console.error("Generation marked as completed, but no video URL was returned in the response payload.");
        process.exit(1);
      }

      console.log(`Generation completed successfully!`);
      console.log(`Video URL: ${videoUrl}`);
      return videoUrl;
    } else if (status === "failed") {
      const errorDetail = (result as any).error || (result as any).message || "Generation failed on server";
      console.error(`Generation failed: ${errorDetail}`);
      process.exit(1);
    } else if (status === "canceled") {
      console.error("Generation request was canceled.");
      process.exit(1);
    } else if (status === "nsfw") {
      console.error("Generation request was moderated / flagged for content policy (nsfw).");
      process.exit(1);
    } else {
      console.error(`Request ended with unhandled status: ${status}`);
      process.exit(1);
    }
  } catch (error: any) {
    console.error(`Error during Higgsfield generation: ${error?.message || error}`);
    process.exit(1);
  }
}

// Execute when run directly via CLI
if (process.argv[1] && (process.argv[1].endsWith("index.ts") || process.argv[1].endsWith("index.js"))) {
  runExample().catch((err) => {
    console.error("Unhandled execution error:", err?.message || err);
    process.exit(1);
  });
}
