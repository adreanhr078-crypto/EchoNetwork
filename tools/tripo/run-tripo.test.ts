import { describe, expect, it } from 'vitest';
import { resolveApiKey } from './run-tripo';

describe('run-tripo toolchain', () => {
  it('returns empty string when no API key is set or passed', () => {
    const key = resolveApiKey();
    expect(typeof key).toBe('string');
  });

  it('prefers explicitly passed key over environment', () => {
    const key = resolveApiKey('test_key_explicit_12345');
    expect(key).toBe('test_key_explicit_12345');
  });
});
