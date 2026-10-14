import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { runInNewContext } from 'node:vm';
import { it } from 'node:test';

it('executes the shipped browser predicate against parent, sibling, self and absent message sources', () => {
  const source = readFileSync(new URL('../../godot/scripts/systems/opening_web_handoff.gd', import.meta.url), 'utf8');
  const match = source.match(/^const PARENT_EVENT_PREDICATE := ("[^\n]+")$/m);
  assert.ok(match, 'Native browser predicate must be available for review');
  const body = JSON.parse(match[1]) as string;
  const parent = {};
  const child = { parent };
  const predicate = runInNewContext(`new Function('event', ${JSON.stringify(body)})`, { window: child }) as (event: { source: unknown }) => boolean;
  assert.equal(predicate({ source: parent }), true);
  assert.equal(predicate({ source: {} }), false, 'Same-origin sibling must not configure the child');
  assert.equal(predicate({ source: child }), false, 'Self-sent message must not configure the child');
  assert.equal(predicate({ source: null }), false);
  assert.equal(predicate({ source: undefined }), false);
});
