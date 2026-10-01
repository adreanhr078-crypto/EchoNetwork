import { createHash } from "node:crypto";
import { createReadStream, existsSync, readFileSync, statSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const repoRoot = resolve(dirname(fileURLToPath(import.meta.url)), "../..");
const unityRoot = resolve(
  repoRoot,
  "artifacts/eleven-eleven/art/unity/EchoNetwork-Unity",
);
const migrationPath = resolve(
  repoRoot,
  "artifacts/eleven-eleven/art/unity/migration-manifest.json",
);
const godotRoot = resolve(
  repoRoot,
  "artifacts/eleven-eleven/art/godot/technical-proofs/g0-vertical-slice",
);

function fail(message) {
  console.error(`UNITY_MIGRATION_STRUCTURE_FAIL: ${message}`);
  process.exitCode = 1;
}

function required(relativePath) {
  const absolute = resolve(unityRoot, relativePath);
  if (!existsSync(absolute)) {
    fail(`missing ${relativePath}`);
    return null;
  }
  return absolute;
}

async function sha256(absolutePath) {
  const hash = createHash("sha256");
  for await (const chunk of createReadStream(absolutePath)) hash.update(chunk);
  return hash.digest("hex").toUpperCase();
}

const migration = JSON.parse(readFileSync(migrationPath, "utf8"));
const version = readFileSync(resolve(unityRoot, "ProjectSettings/ProjectVersion.txt"), "utf8");
if (!version.includes("6000.3.23f1") || !version.includes("09d2ecc7fb28"))
  fail("pinned Unity version or changeset is missing");

for (const path of [
  "Packages/manifest.json",
  "README.md",
  "Assets/Scenes/G0_Sector11_Escape.unity",
  "Assets/Editor/G0SceneBuilder.cs",
  "Assets/Scripts/G0/UnityG0Bootstrap.cs",
  "Assets/Scripts/G0/ThirdPersonController.cs",
  "Assets/Scripts/G0/G0Interactable.cs",
  "Assets/Scripts/G0/G0SmokeProbe.cs",
]) required(path);

for (const asset of migration.assets) {
  const target = required(asset.target);
  if (!target) continue;
  const actualBytes = statSync(target).size;
  const actualHash = await sha256(target);
  if (actualBytes !== asset.bytes) fail(`${asset.target} byte count changed`);
  if (actualHash !== asset.sha256) fail(`${asset.target} hash changed`);
  if (target.toLowerCase().endsWith(".glb") && readFileSync(target).subarray(0, 4).toString() !== "glTF")
    fail(`${asset.target} is not a GLB`);
  if (asset.bridge) {
    const bridge = required(asset.bridge);
    if (bridge && (await sha256(bridge)) !== asset.bridgeSha256) fail(`${asset.bridge} hash changed`);
    if (bridge && statSync(bridge).size !== asset.bridgeBytes) fail(`${asset.bridge} byte count changed`);
  }
}

if (!migration.source.godotOriginalPreserved || !existsSync(godotRoot))
  fail("original Godot proof is not present");

for (const [label, path, expectedHash] of [
  ["official Unity Editor installer", migration.targetEditor.installerStagingPath, migration.targetEditor.installerSha256],
  ["official Unity Download Assistant", migration.targetEditor.downloadAssistantStagingPath, migration.targetEditor.downloadAssistantSha256],
]) {
  const absolute = path.replaceAll("/", "\\");
  if (!existsSync(absolute)) fail(`${label} is not staged at ${absolute}`);
  else if ((await sha256(absolute)) !== expectedHash) fail(`${label} hash changed`);
}

if (!process.exitCode) console.log("UNITY_MIGRATION_STRUCTURE_OK");
