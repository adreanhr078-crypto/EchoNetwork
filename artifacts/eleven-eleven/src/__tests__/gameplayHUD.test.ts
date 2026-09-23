import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { renderToString } from 'react-dom/server';
import React from 'react';
import { GameplayHUD } from '../features/gameplay/components/GameplayHUD';

const baseProps = {
  prompt: null,
  objective: 'الهروب من قطاع الحجر 11',
  puzzleProgress: '11:11 // SYNAPSE ACTIVE',
  showTutorial: false,
  onDismissTutorial: () => {},
  onInteract: () => {},
  onPause: () => {},
  setTouchDirection: () => {},
};

describe('GameplayHUD Component Integrations & Combat State', () => {
  it('renders EchoAvatarHUD inside GameplayHUD with player vitals', () => {
    const html = renderToString(
      React.createElement(GameplayHUD, {
        ...baseProps,
        playerHp: 180,
        maxPlayerHp: 200,
        playerStamina: 85,
        maxPlayerStamina: 100,
        echoEmotion: 'combat',
      }),
    );
    assert.ok(html.includes('echo-avatar-hud'));
    assert.ok(html.includes('echo-avatar-hud--combat'));
    assert.ok(html.includes('180'));
    assert.ok(html.includes('85'));
  });

  it('renders Phase II enrage banner and boss warning when monsterPhase === 2', () => {
    const html = renderToString(
      React.createElement(GameplayHUD, {
        ...baseProps,
        bossActive: true,
        monsterHp: 320,
        maxMonsterHp: 1000,
        monsterPhase: 2,
      }),
    );
    assert.ok(html.includes('PHASE II'));
    assert.ok(html.includes('EX-000 انتقل إلى المرحلة الثانية'));
    assert.ok(html.includes('مرحلة الهياج الكاملة'));
  });

  it('renders Kinetic Counter / Stagger window banner when monsterStaggered is active', () => {
    const html = renderToString(
      React.createElement(GameplayHUD, {
        ...baseProps,
        bossActive: true,
        monsterHp: 600,
        maxMonsterHp: 1000,
        monsterStaggered: true,
      }),
    );
    assert.ok(html.includes('STAGGER'));
    assert.ok(html.includes('نافذة عداد الحركية — ضرر مضاعف نشط!'));
  });

  it('renders Ground Slam Danger telegraph warning banner when slamWarning is active', () => {
    const html = renderToString(
      React.createElement(GameplayHUD, {
        ...baseProps,
        bossActive: true,
        slamWarning: true,
      }),
    );
    assert.ok(html.includes('DANGER'));
    assert.ok(html.includes('ضربة أرضية ساحقة قادمة'));
    assert.ok(html.includes('EVADE SLAM'));
  });

  it('renders Combo Counter with appropriate multiplier badge when comboCount >= 2', () => {
    const html = renderToString(
      React.createElement(GameplayHUD, {
        ...baseProps,
        bossActive: true,
        comboCount: 7,
        comboMultiplier: 2,
      }),
    );
    assert.ok(html.includes('7'));
    assert.ok(html.includes('CHAIN ×2'));
  });

  it('renders MAX CHAIN ×3 combo badge when comboMultiplier is 3', () => {
    const html = renderToString(
      React.createElement(GameplayHUD, {
        ...baseProps,
        bossActive: true,
        comboCount: 12,
        comboMultiplier: 3,
      }),
    );
    assert.ok(html.includes('12'));
    assert.ok(html.includes('MAX CHAIN ×3'));
  });

  it('respects reducedMotion by turning off CSS animation inline style', () => {
    const html = renderToString(
      React.createElement(GameplayHUD, {
        ...baseProps,
        bossActive: true,
        comboCount: 5,
        slamWarning: true,
        reducedMotion: true,
      }),
    );
    assert.ok(html.includes('animation:none'));
  });
});
