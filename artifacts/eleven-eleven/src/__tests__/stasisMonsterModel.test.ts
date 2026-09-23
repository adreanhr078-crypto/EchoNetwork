import { describe, it } from 'node:test';
import assert from 'node:assert/strict';

describe('EX-000 Stasis Monster Combat Systems & State Logic', () => {
  it('triggers Phase 2 transition when HP drops to or below 350', () => {
    const maxHp = 1000;
    const phaseThreshold = 350;

    function resolvePhase(hp: number): 1 | 2 {
      return hp <= phaseThreshold ? 2 : 1;
    }

    assert.equal(resolvePhase(1000), 1);
    assert.equal(resolvePhase(500), 1);
    assert.equal(resolvePhase(351), 1);
    assert.equal(resolvePhase(350), 2);
    assert.equal(resolvePhase(100), 2);
    assert.equal(resolvePhase(0), 2);
  });

  it('calculates shockwave expansion radius accurately across windup duration', () => {
    const totalDuration = 0.75;
    function calculateShockwaveRadius(timerRemaining: number): number {
      const progress = Math.max(0, Math.min(1, 1.0 - (timerRemaining / totalDuration)));
      return 0.5 + progress * 3.8;
    }

    // At start (timer = 0.75)
    assert.equal(calculateShockwaveRadius(0.75), 0.5);
    // At midpoint (timer = 0.375)
    assert.ok(Math.abs(calculateShockwaveRadius(0.375) - 2.4) < 0.01);
    // At end (timer = 0)
    assert.ok(Math.abs(calculateShockwaveRadius(0) - 4.3) < 0.01);
  });

  it('calculates combo multiplier based on hit streak thresholds', () => {
    function getComboMultiplier(hits: number): number {
      if (hits >= 10) return 3;
      if (hits >= 5) return 2;
      return 1;
    }

    assert.equal(getComboMultiplier(0), 1);
    assert.equal(getComboMultiplier(1), 1);
    assert.equal(getComboMultiplier(4), 1);
    assert.equal(getComboMultiplier(5), 2);
    assert.equal(getComboMultiplier(9), 2);
    assert.equal(getComboMultiplier(10), 3);
    assert.equal(getComboMultiplier(25), 3);
  });

  it('enforces stamina costs and prevents dodging when depleted', () => {
    const DODGE_COST = 20;
    const MIN_DODGE_STAMINA = 15;

    function attemptDodge(currentStamina: number): { success: boolean; nextStamina: number } {
      if (currentStamina < MIN_DODGE_STAMINA) {
        return { success: false, nextStamina: currentStamina };
      }
      return { success: true, nextStamina: Math.max(0, currentStamina - DODGE_COST) };
    }

    assert.deepEqual(attemptDodge(100), { success: true, nextStamina: 80 });
    assert.deepEqual(attemptDodge(25), { success: true, nextStamina: 5 });
    assert.deepEqual(attemptDodge(15), { success: true, nextStamina: 0 });
    assert.deepEqual(attemptDodge(14), { success: false, nextStamina: 14 });
    assert.deepEqual(attemptDodge(0), { success: false, nextStamina: 0 });
  });

  it('applies 2x kinetic stagger multiplier to incoming counter attacks', () => {
    const baseDamage = 45;
    function calculateDamage(base: number, isStaggered: boolean): number {
      return isStaggered ? base * 2 : base;
    }

    assert.equal(calculateDamage(baseDamage, false), 45);
    assert.equal(calculateDamage(baseDamage, true), 90);
  });
});
