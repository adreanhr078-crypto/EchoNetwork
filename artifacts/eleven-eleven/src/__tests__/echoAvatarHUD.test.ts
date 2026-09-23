import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { renderToString } from 'react-dom/server';
import React from 'react';
import { EchoAvatarHUD, type EchoAvatarEmotion } from '../features/gameplay/components/EchoAvatarHUD';

describe('EchoAvatarHUD Component & Emotion States', () => {
  it('renders default calm state with correct accessibility labels and stable badge', () => {
    const html = renderToString(
      React.createElement(EchoAvatarHUD, {
        emotion: 'calm',
        hp: 100,
        maxHp: 100,
        stamina: 100,
        maxStamina: 100,
      }),
    );
    assert.ok(html.includes('echo-avatar-hud--calm'));
    assert.ok(html.includes('SYNAPSE // STABLE'));
    assert.ok(html.includes('الحالة الحيوية لـ Echo'));
    assert.ok(html.includes('SUBJECT EX-011'));
  });

  it('elevates to surge state when perfectDodgeSurgeActive is true', () => {
    const html = renderToString(
      React.createElement(EchoAvatarHUD, {
        emotion: 'calm',
        perfectDodgeSurgeActive: true,
      }),
    );
    assert.ok(html.includes('echo-avatar-hud--surge'));
    assert.ok(html.includes('SURGE // 3x POWER'));
  });

  it('switches to combat state during combat or sprinting', () => {
    const html = renderToString(
      React.createElement(EchoAvatarHUD, {
        emotion: 'combat',
        isSprinting: true,
      }),
    );
    assert.ok(html.includes('echo-avatar-hud--combat'));
    assert.ok(html.includes('COMBAT // ENGAGED'));
  });

  it('triggers hurt critical state when HP is low (< 35%)', () => {
    const html = renderToString(
      React.createElement(EchoAvatarHUD, {
        hp: 25,
        maxHp: 100,
      }),
    );
    assert.ok(html.includes('echo-avatar-hud--hurt'));
    assert.ok(html.includes('VITAL // CRITICAL'));
  });

  it('displays stealth concealed state when isStealth is active', () => {
    const html = renderToString(
      React.createElement(EchoAvatarHUD, {
        isStealth: true,
      }),
    );
    assert.ok(html.includes('echo-avatar-hud--stealth'));
    assert.ok(html.includes('STEALTH // CONCEALED'));
  });

  it('displays triumph state on stage victory', () => {
    const html = renderToString(
      React.createElement(EchoAvatarHUD, {
        emotion: 'triumph',
      }),
    );
    assert.ok(html.includes('echo-avatar-hud--triumph'));
    assert.ok(html.includes('VICTORY // CLEAR'));
  });
});
