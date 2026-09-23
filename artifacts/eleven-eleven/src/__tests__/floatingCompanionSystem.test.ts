import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import { Vector3 } from 'three';
import {
  createInitialCompanionState,
  calculateCompanionTarget,
  stepCompanionPhysics,
  triggerCompanionEmotion,
  DEFAULT_COMPANION_CONFIG,
} from '../features/gameplay/domain/floatingCompanionState';

describe('Floating Companion State Machine & Physics', () => {
  it('creates initial state correctly positioned relative to spawn', () => {
    const spawn = new Vector3(0, 0, 10);
    const state = createInitialCompanionState(spawn);

    assert.equal(state.emotion, 'idle');
    assert.ok(Math.abs(state.currentPosition.x - 0.65) < 0.01);
    assert.ok(Math.abs(state.currentPosition.y - 1.35) < 0.01);
    assert.ok(Math.abs(state.currentPosition.z - 9.55) < 0.01);
  });

  it('calculates rotated target position following player yaw', () => {
    const playerPos = new Vector3(0, 0, 0);
    // Facing North (yaw = 0)
    const targetNorth = calculateCompanionTarget(playerPos, 0, DEFAULT_COMPANION_CONFIG, 0, true);
    assert.ok(Math.abs(targetNorth.x - 0.65) < 0.01);
    assert.ok(Math.abs(targetNorth.z - (-0.45)) < 0.01);

    // Facing East (yaw = PI / 2)
    const targetEast = calculateCompanionTarget(playerPos, Math.PI / 2, DEFAULT_COMPANION_CONFIG, 0, true);
    assert.ok(Math.abs(targetEast.x - 0.45) < 0.01);
    assert.ok(Math.abs(targetEast.z - 0.65) < 0.01);
  });

  it('applies sinusoidal hover oscillation when reduced motion is disabled', () => {
    const playerPos = new Vector3(0, 0, 0);
    const targetT0 = calculateCompanionTarget(playerPos, 0, DEFAULT_COMPANION_CONFIG, 0, false);
    const targetTQuarter = calculateCompanionTarget(
      playerPos,
      0,
      DEFAULT_COMPANION_CONFIG,
      1 / (4 * DEFAULT_COMPANION_CONFIG.hoverFrequency),
      false,
    );

    assert.ok(
      Math.abs(targetTQuarter.y - targetT0.y - DEFAULT_COMPANION_CONFIG.hoverAmplitude) < 0.01,
    );
  });

  it('disables hover vertical oscillation under reduced motion', () => {
    const playerPos = new Vector3(0, 0, 0);
    const targetT0 = calculateCompanionTarget(playerPos, 0, DEFAULT_COMPANION_CONFIG, 0, true);
    const targetTQuarter = calculateCompanionTarget(playerPos, 0, DEFAULT_COMPANION_CONFIG, 0.25, true);

    assert.equal(targetT0.y, targetTQuarter.y);
  });

  it('smoothly dampens position updates without overshooting', () => {
    const state = createInitialCompanionState(new Vector3(0, 0, 0));
    const target = new Vector3(2, 1.35, 2);

    // Step physics forward by 0.1s
    stepCompanionPhysics(state, target, 0.1, DEFAULT_COMPANION_CONFIG);

    assert.ok(state.currentPosition.x > 0.65);
    assert.ok(state.currentPosition.x < 2.0);
    assert.equal(state.emotion, 'following');
  });

  it('snaps closer when distance exceeds leash limit', () => {
    const state = createInitialCompanionState(new Vector3(0, 0, 0));
    // Player teleports 50 meters away
    const farTarget = new Vector3(50, 1.35, 50);

    stepCompanionPhysics(state, farTarget, 0.016, DEFAULT_COMPANION_CONFIG);

    // Distance should immediately collapse by at least 85%
    const remainingDist = state.currentPosition.distanceTo(farTarget);
    assert.ok(remainingDist < 15.0);
  });

  it('triggers emotions and decays back to idle/following after duration', () => {
    const state = createInitialCompanionState(new Vector3(0, 0, 0));
    const interactable = new Vector3(5, 0, 5);

    triggerCompanionEmotion(state, 'observing', 2.0, interactable);
    assert.equal(state.emotion, 'observing');
    assert.ok(state.observedTarget !== null);

    // Step 1.0s -> emotion remains
    stepCompanionPhysics(state, state.targetPosition, 1.0, DEFAULT_COMPANION_CONFIG);
    assert.equal(state.emotion, 'observing');

    // Step 1.5s -> emotion timer expires
    stepCompanionPhysics(state, state.targetPosition, 1.5, DEFAULT_COMPANION_CONFIG);
    assert.equal(state.emotion, 'idle');
    assert.equal(state.observedTarget, null);
  });
});
