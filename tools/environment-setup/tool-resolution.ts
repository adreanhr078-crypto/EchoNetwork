import { spawnSync } from "node:child_process";
import { existsSync, readFileSync, readdirSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

export type ToolRequirement = "required" | "optional" | "deferred";

export type ToolCheck = {
  id: string;
  requirement: ToolRequirement;
  found: boolean;
  healthy: boolean;
  path?: string;
  version?: string;
  note: string;
};

type ExecutableSpec = {
  id: string;
  requirement: ToolRequirement;
  envKeys?: string[];
  commands?: string[];
  knownPaths?: string[];
  versionArgs?: string[];
  note: string;
};

const REPO_ROOT = resolve(dirname(fileURLToPath(import.meta.url)), "..", "..");

function registryValue(key: string, value: string): string | undefined {
  if (process.platform !== "win32") return undefined;
  const result = spawnSync("reg.exe", ["query", key, "/v", value], {
    encoding: "utf8",
    windowsHide: true,
  });
  if (result.status !== 0) return undefined;
  const line = result.stdout
    .split(/\r?\n/)
    .find((candidate) => candidate.trimStart().startsWith(value));
  return (
    line
      ?.split(/\s{2,}/)
      .at(-1)
      ?.trim() || undefined
  );
}

export function readConfiguredPath(envKey: string): string | undefined {
  return (
    process.env[envKey]?.trim() || registryValue("HKCU\\Environment", envKey)
  );
}

function commandPath(command: string): string | undefined {
  const locator = process.platform === "win32" ? "where.exe" : "which";
  const result = spawnSync(locator, [command], {
    encoding: "utf8",
    windowsHide: true,
  });
  if (result.status !== 0) return undefined;
  return result.stdout
    .split(/\r?\n/)
    .map((line) => line.trim())
    .find(Boolean);
}

function firstExisting(
  candidates: Array<string | undefined>,
): string | undefined {
  for (const candidate of candidates) {
    if (candidate && existsSync(candidate)) return resolve(candidate);
  }
  return undefined;
}

function childDirectories(parent: string): string[] {
  if (!existsSync(parent)) return [];
  try {
    return readdirSync(parent, { withFileTypes: true })
      .filter((entry) => entry.isDirectory())
      .map((entry) => join(parent, entry.name));
  } catch {
    return [];
  }
}

function unityEditorCandidates(): string[] {
  if (process.platform === "darwin") {
    return childDirectories("/Applications/Unity/Hub/Editor")
      .sort((left, right) =>
        right.localeCompare(left, undefined, { numeric: true }),
      )
      .map((editorRoot) =>
        join(editorRoot, "Unity.app", "Contents", "MacOS", "Unity"),
      );
  }

  if (process.platform !== "win32") {
    return ["/opt/unity/Editor/Unity"];
  }

  const hubRoots = [
    "C:/Program Files/Unity/Hub/Editor",
    "C:/Program Files (x86)/Unity/Hub/Editor",
  ];
  const hubEditors = hubRoots
    .flatMap((root) => childDirectories(root))
    .sort((left, right) =>
      right.localeCompare(left, undefined, { numeric: true }),
    )
    .map((editorRoot) => join(editorRoot, "Editor", "Unity.exe"));

  const portableRoots = childDirectories("C:/Tools").filter((candidate) =>
    /(?:^|[\\/])unity(?:[-_ ].*)?$/i.test(candidate),
  );
  const portableEditors = portableRoots.flatMap((root) => [
    join(root, "Editor", "Unity.exe"),
    join(root, "Unity.exe"),
  ]);

  return [...portableEditors, ...hubEditors];
}

export function resolveUnityExecutable(): string | undefined {
  return firstExisting([
    readConfiguredPath("UNITY_EXE"),
    commandPath(process.platform === "win32" ? "Unity.exe" : "Unity"),
    ...unityEditorCandidates(),
  ]);
}

function preferGodotConsole(candidate: string | undefined): string | undefined {
  if (!candidate || process.platform !== "win32") return candidate;
  if (/_console\.exe$/i.test(candidate)) return candidate;
  const consoleCandidate = candidate.replace(/\.exe$/i, "_console.exe");
  return existsSync(consoleCandidate) ? consoleCandidate : candidate;
}

function godotExecutableCandidates(): string[] {
  if (process.platform === "darwin") {
    return ["/Applications/Godot.app/Contents/MacOS/Godot"];
  }
  if (process.platform !== "win32") {
    return ["/opt/godot/godot", "/usr/local/bin/godot"];
  }

  const exactPinnedRoot = "C:/Tools/Godot-4.7.2-stable";
  const boundedPortableRoots = childDirectories("C:/Tools")
    .filter((candidate) => /(?:^|[\\/])godot(?:[-_ ].*)?$/i.test(candidate))
    .sort((left, right) =>
      right.localeCompare(left, undefined, { numeric: true }),
    );

  return [exactPinnedRoot, ...boundedPortableRoots].flatMap((root) => [
    join(root, "Godot_v4.7.2-stable_win64_console.exe"),
    join(root, "Godot_v4.7.2-stable_win64.exe"),
    join(root, "godot_console.exe"),
    join(root, "godot.exe"),
  ]);
}

export function resolveGodotExecutable(): string | undefined {
  const candidates = [
    readConfiguredPath("GODOT_EXE"),
    commandPath(process.platform === "win32" ? "godot_console.exe" : "godot"),
    commandPath(process.platform === "win32" ? "godot.exe" : "godot"),
    ...godotExecutableCandidates(),
  ].map(preferGodotConsole);
  return firstExisting(candidates);
}

function firstVersionLine(output: string): string | undefined {
  return output
    .split(/\r?\n/)
    .map((line) => line.trim())
    .find(Boolean);
}

function checkExecutable(spec: ExecutableSpec): ToolCheck {
  const envCandidates = (spec.envKeys ?? []).map(readConfiguredPath);
  const commandCandidates = (spec.commands ?? []).map(commandPath);
  const executable = firstExisting([
    ...envCandidates,
    ...commandCandidates,
    ...(spec.knownPaths ?? []),
  ]);
  if (!executable) {
    return {
      id: spec.id,
      requirement: spec.requirement,
      found: false,
      healthy: false,
      note: spec.note,
    };
  }

  if (!spec.versionArgs) {
    return {
      id: spec.id,
      requirement: spec.requirement,
      found: true,
      healthy: true,
      path: executable,
      note: spec.note,
    };
  }

  const result = spawnSync(executable, spec.versionArgs, {
    encoding: "utf8",
    timeout: 20_000,
    windowsHide: true,
  });
  const output = `${result.stdout ?? ""}\n${result.stderr ?? ""}`.trim();
  return {
    id: spec.id,
    requirement: spec.requirement,
    found: true,
    healthy: result.status === 0,
    path: executable,
    version: firstVersionLine(output),
    note: spec.note,
  };
}

function packageCheck(
  id: string,
  packageName: string,
  requirement: ToolRequirement,
  note: string,
): ToolCheck {
  const packagePath = join(
    REPO_ROOT,
    "node_modules",
    ...packageName.split("/"),
    "package.json",
  );
  if (!existsSync(packagePath)) {
    return { id, requirement, found: false, healthy: false, note };
  }
  const parsed = JSON.parse(readFileSync(packagePath, "utf8")) as {
    version?: string;
  };
  return {
    id,
    requirement,
    found: true,
    healthy: Boolean(parsed.version),
    path: packagePath,
    version: parsed.version,
    note,
  };
}

function ffprobeCandidates(): string[] {
  const configured = readConfiguredPath("FFPROBE_EXE");
  const ffmpeg = readConfiguredPath("FFMPEG_EXE");
  return [
    configured,
    ffmpeg
      ? join(
          dirname(ffmpeg),
          process.platform === "win32" ? "ffprobe.exe" : "ffprobe",
        )
      : "",
  ].filter(Boolean);
}

export function checkTools(): ToolCheck[] {
  const edgeVersion =
    registryValue("HKCU\\Software\\Microsoft\\Edge\\BLBeacon", "version") ??
    registryValue("HKLM\\Software\\Microsoft\\Edge\\BLBeacon", "version");
  const executableChecks = [
    checkExecutable({
      id: "blender",
      requirement: "required",
      envKeys: ["BLENDER_EXE"],
      commands: [process.platform === "win32" ? "blender.exe" : "blender"],
      knownPaths: [
        "C:/Tools/Blender-5.2.1-x64/Blender Foundation/Blender 5.2/blender.exe",
      ],
      versionArgs: ["--version"],
      note: "Headless 3D authoring and GLB export.",
    }),
    checkExecutable({
      id: "ffmpeg",
      requirement: "required",
      envKeys: ["FFMPEG_EXE"],
      commands: [process.platform === "win32" ? "ffmpeg.exe" : "ffmpeg"],
      versionArgs: ["-version"],
      note: "Deterministic WebM/MP4/audio encoding.",
    }),
    checkExecutable({
      id: "ffprobe",
      requirement: "required",
      envKeys: ["FFPROBE_EXE"],
      commands: [process.platform === "win32" ? "ffprobe.exe" : "ffprobe"],
      knownPaths: ffprobeCandidates(),
      versionArgs: ["-version"],
      note: "Codec, duration, dimensions, and stream validation.",
    }),
    checkExecutable({
      id: "toktx",
      requirement: "required",
      envKeys: ["TOKTX_EXE"],
      commands: [process.platform === "win32" ? "toktx.exe" : "toktx"],
      knownPaths: ["C:/Tools/KTX-Software-4.4.2-portable/bin/toktx.exe"],
      versionArgs: ["--version"],
      note: "KTX2/Basis Universal texture compression for mobile GPU memory.",
    }),
    checkExecutable({
      id: "edge",
      requirement: "required",
      envKeys: ["EDGE_EXE"],
      commands: [
        process.platform === "win32" ? "msedge.exe" : "microsoft-edge",
      ],
      knownPaths: [
        "C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe",
        "C:/Program Files/Microsoft/Edge/Application/msedge.exe",
      ],
      note: "Required browser target for desktop and mobile-emulation QA.",
    }),
    checkExecutable({
      id: "imagemagick",
      requirement: "optional",
      envKeys: ["MAGICK_EXE", "IMAGEMAGICK_EXE"],
      commands: [process.platform === "win32" ? "magick.exe" : "magick"],
      knownPaths: ["C:/Tools/ImageMagick-7.1.2-29-x64/magick.exe"],
      versionArgs: ["--version"],
      note: "Optional; Sharp is the supported non-admin image-processing fallback.",
    }),
  ];

  const edge = executableChecks.find((tool) => tool.id === "edge");
  if (edge && edgeVersion) edge.version = `Microsoft Edge ${edgeVersion}`;

  return [
    ...executableChecks,
    packageCheck(
      "gltf-transform",
      "@gltf-transform/cli",
      "required",
      "Pinned GLB optimization and Meshopt pipeline.",
    ),
    packageCheck(
      "gltf-validator",
      "gltf-validator",
      "required",
      "Khronos glTF 2.0 structural validation.",
    ),
    packageCheck(
      "sharp",
      "sharp",
      "required",
      "Non-admin image metadata and poster processing.",
    ),
    checkExecutable({
      id: "unity",
      requirement: "deferred",
      envKeys: ["UNITY_EXE"],
      commands: [process.platform === "win32" ? "Unity.exe" : "Unity"],
      knownPaths: unityEditorCandidates(),
      versionArgs: ["-batchmode", "-quit", "-version", "-logFile", "-"],
      note: "Availability is detected, but production use remains deferred until the measured engine greenlight.",
    }),
    checkExecutable({
      id: "godot",
      requirement: "deferred",
      knownPaths: [resolveGodotExecutable()].filter(
        (candidate): candidate is string => Boolean(candidate),
      ),
      versionArgs: ["--version"],
      note: "Verified portable candidate for isolated non-Canon proofs; it is not the selected production runtime.",
    }),
    {
      id: 'comfyui',
      requirement: 'deferred',
      found: false,
      healthy: false,
      note: 'Deliberately deferred on this 8 GB Intel-UHD machine; use connected generation tools for concepts.',
    },
    {
      id: 'higgsfield',
      requirement: 'optional' as ToolRequirement,
      found: Boolean(process.env['HF_API_KEY_ID'] && process.env['HF_API_KEY_SECRET']),
      healthy: Boolean(process.env['HF_API_KEY_ID'] && process.env['HF_API_KEY_SECRET']),
      note: 'Higgsfield AI video/image generation. Set HF_API_KEY_ID and HF_API_KEY_SECRET from https://cloud.higgsfield.ai',
    },
  ];
}

export function requiredToolFailures(tools: ToolCheck[]): ToolCheck[] {
  return tools.filter(
    (tool) => tool.requirement === "required" && (!tool.found || !tool.healthy),
  );
}
