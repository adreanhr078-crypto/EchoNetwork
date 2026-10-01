import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

const root = new URL('../../artifacts/eleven-eleven/art/unity/EchoNetwork-Unity/', import.meta.url);
const read = path => readFileSync(new URL(path, root), 'utf8');

// Source guardrails only. These tests never certify C# compilation or Play Mode.
test('scene building is explicit and protects unsaved work', () => {
  const source = read('Assets/Editor/G0SceneBuilder.cs');
  assert.doesNotMatch(source, /\[InitializeOnLoadMethod\]/);
  assert.match(source, /SaveCurrentModifiedScenesIfUserWantsTo/);
  assert.match(source, /spawn.SetParent\(player.transform, true\)/);
  assert.match(source, /capsule.center = new Vector3\(0f, 0.85f, 0f\)/);
});
test('component presence cannot produce a successful runtime verdict', () => {
  const source = read('Assets/Scripts/G0/G0SmokeProbe.cs');
  assert.doesNotMatch(source, /UNITY_G0_SMOKE_OK|Application.Quit\(0\)/);
  assert.match(source, /Application.Quit\(1\)/);
  assert.match(source, /Application.Quit\(2\)/);
});
test('scene roots point at transforms and build settings use their own class', () => {
  assert.match(read('ProjectSettings/EditorBuildSettings.asset'), /--- !u!1045 &1/);
  assert.match(read('Assets/Scenes/G0_Sector11_Escape.unity'), /m_Roots:\s+- \{fileID: 1001\}/);
});
