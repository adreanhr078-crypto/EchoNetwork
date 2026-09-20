import { createHash } from 'node:crypto';
import { createRequire } from 'node:module';
import { readFileSync, statSync, writeFileSync } from 'node:fs';
import { extname, resolve } from 'node:path';
import { pathToFileURL } from 'node:url';

import budgets from './asset-budgets.json';

type ValidationIssue = { code?: string; message?: string; severity?: number; pointer?: string };
type ValidationReport = {
  issues?: {
    numErrors?: number;
    numWarnings?: number;
    numInfos?: number;
    numHints?: number;
    messages?: ValidationIssue[];
  };
  info?: {
    totalTriangleCount?: number;
    totalVertexCount?: number;
  };
};

type GlbJson = {
  asset?: { version?: string };
  meshes?: Array<{ primitives?: unknown[] }>;
  materials?: unknown[];
  textures?: unknown[];
  animations?: unknown[];
  skins?: Array<{ joints?: unknown[] }>;
  cameras?: unknown[];
  extensionsUsed?: string[];
  extensionsRequired?: string[];
};

type Arguments = {
  input?: string;
  report?: string;
  strict: boolean;
};

const require = createRequire(import.meta.url);
const validator = require('gltf-validator') as {
  validateBytes(data: Uint8Array, options: Record<string, unknown>): Promise<ValidationReport>;
};

function parseArgs(): Arguments {
  const raw = process.argv.slice(2).filter((value, index) => !(value === '--' && index === 0));
  const args: Arguments = { strict: false };
  for (let index = 0; index < raw.length; index += 1) {
    const value = raw[index];
    if (value === '--strict') {
      args.strict = true;
      continue;
    }
    if (value === '--input' || value === '--report') {
      const next = raw[index + 1];
      if (!next || next.startsWith('--')) throw new Error(`${value} requires a value.`);
      args[value.slice(2) as 'input' | 'report'] = next;
      index += 1;
    }
  }
  return args;
}

function parseGlbJson(bytes: Buffer): GlbJson {
  if (bytes.length < 20 || bytes.toString('ascii', 0, 4) !== 'glTF') {
    throw new Error('Input is not a GLB 2.0 binary container.');
  }
  const version = bytes.readUInt32LE(4);
  if (version !== 2) throw new Error(`Unsupported GLB version: ${version}`);
  const declaredLength = bytes.readUInt32LE(8);
  if (declaredLength !== bytes.length) {
    throw new Error(`GLB length mismatch: header=${declaredLength}, actual=${bytes.length}`);
  }
  const jsonLength = bytes.readUInt32LE(12);
  const jsonType = bytes.readUInt32LE(16);
  if (jsonType !== 0x4e4f534a) throw new Error('First GLB chunk is not JSON.');
  return JSON.parse(bytes.toString('utf8', 20, 20 + jsonLength).trimEnd()) as GlbJson;
}

export async function validateGlb(
  inputPath: string,
  strict = false,
  enforceBudgets = true,
): Promise<Record<string, unknown>> {
  const input = resolve(inputPath);
  if (extname(input).toLowerCase() !== '.glb') throw new Error('Only .glb input is accepted.');
  const bytes = readFileSync(input);
  const json = parseGlbJson(bytes);
  const report = await validator.validateBytes(new Uint8Array(bytes), {
    uri: input,
    format: 'glb',
    maxIssues: 0,
    writeTimestamp: false,
  });

  const meshCount = json.meshes?.length ?? 0;
  const primitiveCount = (json.meshes ?? []).reduce((sum, mesh) => sum + (mesh.primitives?.length ?? 0), 0);
  const materialCount = json.materials?.length ?? 0;
  const textureCount = json.textures?.length ?? 0;
  const maxJoints = Math.max(0, ...(json.skins ?? []).map((skin) => skin.joints?.length ?? 0));
  const triangleCount = report.info?.totalTriangleCount ?? 0;
  const issues = report.issues ?? {};

  const failures: string[] = [];
  if ((issues.numErrors ?? 0) > 0) failures.push(`Khronos validator errors: ${issues.numErrors}`);
  if (strict && (issues.numWarnings ?? 0) > 0) failures.push(`Khronos validator warnings: ${issues.numWarnings}`);
  if (enforceBudgets) {
    if (bytes.length > budgets.glb.maxBytes) failures.push(`File size ${bytes.length} exceeds ${budgets.glb.maxBytes} bytes.`);
    if (triangleCount > budgets.glb.maxTriangles) failures.push(`Triangles ${triangleCount} exceed ${budgets.glb.maxTriangles}.`);
    if (meshCount > budgets.glb.maxMeshes) failures.push(`Meshes ${meshCount} exceed ${budgets.glb.maxMeshes}.`);
    if (primitiveCount > budgets.glb.maxPrimitives) failures.push(`Primitives ${primitiveCount} exceed ${budgets.glb.maxPrimitives}.`);
    if (materialCount > budgets.glb.maxMaterials) failures.push(`Materials ${materialCount} exceed ${budgets.glb.maxMaterials}.`);
    if (textureCount > budgets.glb.maxTextures) failures.push(`Textures ${textureCount} exceed ${budgets.glb.maxTextures}.`);
    if (maxJoints > budgets.glb.maxJointsPerSkin) failures.push(`Joints per skin ${maxJoints} exceed ${budgets.glb.maxJointsPerSkin}.`);
  }
  if ((json.cameras?.length ?? 0) > 0) failures.push('Runtime GLB must not contain cameras.');

  const result = {
    status: failures.length === 0 ? 'PASS' : 'FAIL',
    input,
    sha256: createHash('sha256').update(bytes).digest('hex'),
    bytes: statSync(input).size,
    assetVersion: json.asset?.version,
    metrics: {
      triangles: triangleCount,
      vertices: report.info?.totalVertexCount ?? 0,
      meshes: meshCount,
      primitives: primitiveCount,
      materials: materialCount,
      textures: textureCount,
      animations: json.animations?.length ?? 0,
      maxJointsPerSkin: maxJoints,
    },
    extensionsUsed: json.extensionsUsed ?? [],
    extensionsRequired: json.extensionsRequired ?? [],
    issues: {
      errors: issues.numErrors ?? 0,
      warnings: issues.numWarnings ?? 0,
      infos: issues.numInfos ?? 0,
      hints: issues.numHints ?? 0,
      messages: issues.messages ?? [],
    },
    failures,
  };
  return result;
}

async function main(): Promise<void> {
  const args = parseArgs();
  if (!args.input) throw new Error('Usage: validate-glb.ts -- --input <asset.glb> [--strict] [--report <report.json>]');
  const result = await validateGlb(args.input, args.strict);
  const serialized = `${JSON.stringify(result, null, 2)}\n`;
  console.log(serialized.trimEnd());
  if (args.report) writeFileSync(resolve(args.report), serialized);
  if (result.status !== 'PASS') process.exitCode = 1;
}

const invokedPath = process.argv[1] ? pathToFileURL(process.argv[1]).href : '';
if (import.meta.url === invokedPath) {
  main().catch((error) => {
    console.error(error instanceof Error ? error.stack ?? error.message : String(error));
    process.exitCode = 1;
  });
}
