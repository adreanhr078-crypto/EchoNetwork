import React, { useState, useEffect, useCallback } from 'react';
import { useGameplayAudio } from '../audio/useGameplayAudio';

export interface SubstationMinigameProps {
  isOpen: boolean;
  onClose: () => void;
  onSuccess: () => void;
  reducedMotion?: boolean;
}

// 4-Node Tactical Hydraulic Conduit Grid
// Target solution requires all nodes aligned to establish a closed circuit from PWR-IN to GATE-OUT
interface CircuitNode {
  id: number;
  label: string;
  rotation: number; // 0, 90, 180, 270
  targetRotation: number;
  type: 'corner' | 'straight' | 't-junction';
}

const INITIAL_NODES: CircuitNode[] = [
  { id: 0, label: 'مكثف الدفع A // COND-01', rotation: 90, targetRotation: 0, type: 'corner' },
  { id: 1, label: 'مرحّل التوزيع // RELAY-B', rotation: 180, targetRotation: 90, type: 'corner' },
  { id: 2, label: 'محوّل النبضات // HUB-C', rotation: 270, targetRotation: 180, type: 'corner' },
  { id: 3, label: 'مشغّل البوابة // ACT-04', rotation: 90, targetRotation: 270, type: 'corner' },
];

export const SubstationMinigame: React.FC<SubstationMinigameProps> = ({
  isOpen,
  onClose,
  onSuccess,
  reducedMotion = false,
}) => {
  const [nodes, setNodes] = useState<CircuitNode[]>(INITIAL_NODES);
  const [isSolved, setIsSolved] = useState(false);
  const { playCue } = useGameplayAudio();

  // Reset or initialize on open
  useEffect(() => {
    if (isOpen) {
      setNodes(INITIAL_NODES.map((n) => ({ ...n, rotation: (n.rotation + (n.id * 90)) % 360 })));
      setIsSolved(false);
    }
  }, [isOpen]);

  // Check circuit continuity
  const checkContinuity = useCallback((currentNodes: CircuitNode[]) => {
    const allAligned = currentNodes.every((node) => node.rotation % 360 === node.targetRotation);
    if (allAligned && !isSolved) {
      setIsSolved(true);
      playCue('circuitSpark', { volume: 0.75 });
      setTimeout(() => {
        playCue('powerSurge', { volume: 0.9 });
      }, 200);

      setTimeout(() => {
        onSuccess();
      }, 1400);
    }
  }, [isSolved, onSuccess, playCue]);

  const handleRotateNode = (id: number) => {
    if (isSolved) return;
    playCue('circuitClick', { volume: 0.6 });

    setNodes((prev) => {
      const next = prev.map((node) => {
        if (node.id === id) {
          return { ...node, rotation: (node.rotation + 90) % 360 };
        }
        return node;
      });
      checkContinuity(next);
      return next;
    });
  };

  useEffect(() => {
    const handleKeyDown = (e: KeyboardEvent) => {
      if (!isOpen) return;
      if (e.key === 'Escape') {
        onClose();
      }
    };
    window.addEventListener('keydown', handleKeyDown);
    return () => window.removeEventListener('keydown', handleKeyDown);
  }, [isOpen, onClose]);

  if (!isOpen) return null;

  return (
    <div
      role="dialog"
      aria-modal="true"
      aria-label="محطة تحويل مسار الطاقة الفرعية"
      style={{
        position: 'fixed',
        inset: 0,
        zIndex: 9999,
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        background: 'rgba(3, 8, 14, 0.88)',
        backdropFilter: 'blur(8px)',
        color: '#e2f1f8',
        fontFamily: 'system-ui, -apple-system, sans-serif',
        userSelect: 'none',
      }}
    >
      <div
        style={{
          width: '92%',
          maxWidth: '560px',
          background: 'linear-gradient(180deg, #0d1822 0%, #060b10 100%)',
          border: isSolved ? '2px solid #00f0ff' : '2px solid rgba(0, 240, 255, 0.35)',
          borderRadius: '12px',
          boxShadow: isSolved
            ? '0 0 45px rgba(0, 240, 255, 0.4), inset 0 0 20px rgba(0, 240, 255, 0.15)'
            : '0 16px 40px rgba(0, 0, 0, 0.8)',
          padding: '24px',
          display: 'flex',
          flexDirection: 'column',
          gap: '18px',
          transition: reducedMotion ? 'none' : 'all 0.3s cubic-bezier(0.16, 1, 0.3, 1)',
        }}
      >
        {/* Header */}
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', borderBottom: '1px solid rgba(0, 240, 255, 0.2)', paddingBottom: '12px' }}>
          <div>
            <div style={{ color: '#00f0ff', fontSize: '11px', letterSpacing: '2px', fontWeight: 'bold' }}>
              SECTOR 11 // AUXILIARY POWER SUBSTATION
            </div>
            <h2 style={{ margin: '4px 0 0', fontSize: '19px', fontWeight: 600, color: '#f0f9fc' }}>
              إعادة توجيه مسار الطاقة الهيدروليكية
            </h2>
          </div>
          <button
            type="button"
            onClick={onClose}
            aria-label="إغلاق"
            style={{
              background: 'transparent',
              border: '1px solid rgba(255, 255, 255, 0.2)',
              color: '#fff',
              borderRadius: '6px',
              padding: '6px 12px',
              cursor: 'pointer',
              fontSize: '13px',
            }}
          >
            ✕
          </button>
        </div>

        {/* Tactical Diagram Description */}
        <div style={{ fontSize: '13px', color: '#8fa8b7', lineHeight: '1.5' }}>
          {isSolved
            ? '⚡ تم غلق الدائرة الكهربائية بنجاح! تدفق الطاقة الهيدروليكية يتجه نحو أقفال بوابة الحجر.'
            : 'انقر أو اضغط على العقد لتدوير مسارات التوصيل وإكمال الدائرة المغلقة من المولد إلى مشغّل البوابة.'}
        </div>

        {/* Circuit Board 2x2 Grid */}
        <div
          style={{
            display: 'grid',
            gridTemplateColumns: 'repeat(2, 1fr)',
            gap: '16px',
            background: '#04070a',
            padding: '20px',
            borderRadius: '8px',
            border: '1px solid rgba(0, 240, 255, 0.15)',
            position: 'relative',
          }}
        >
          {/* Input Power Rail Indicator (Top-Left) */}
          <div
            style={{
              position: 'absolute',
              top: '-10px',
              left: '24px',
              background: '#00f0ff',
              color: '#000',
              fontSize: '10px',
              fontWeight: 800,
              padding: '2px 8px',
              borderRadius: '3px',
              letterSpacing: '1px',
            }}
          >
            PWR-IN (650V)
          </div>

          {/* Output Gate Rail Indicator (Bottom-Right) */}
          <div
            style={{
              position: 'absolute',
              bottom: '-10px',
              right: '24px',
              background: isSolved ? '#00f0ff' : '#ff4455',
              color: isSolved ? '#000' : '#fff',
              fontSize: '10px',
              fontWeight: 800,
              padding: '2px 8px',
              borderRadius: '3px',
              letterSpacing: '1px',
            }}
          >
            {isSolved ? 'GATE-ONLINE' : 'GATE-OFFLINE'}
          </div>

          {nodes.map((node) => {
            const isAligned = node.rotation % 360 === node.targetRotation;
            return (
              <button
                key={node.id}
                type="button"
                onClick={() => handleRotateNode(node.id)}
                disabled={isSolved}
                aria-label={`${node.label} - الزاوية ${node.rotation} درجة`}
                style={{
                  height: '110px',
                  background: isSolved
                    ? 'radial-gradient(circle, rgba(0,240,255,0.18) 0%, #0a141d 100%)'
                    : isAligned
                      ? 'rgba(0, 240, 255, 0.08)'
                      : '#0a141e',
                  border: isSolved
                    ? '2px solid #00f0ff'
                    : isAligned
                      ? '1px solid rgba(0, 240, 255, 0.6)'
                      : '1px solid rgba(255, 255, 255, 0.12)',
                  borderRadius: '8px',
                  display: 'flex',
                  flexDirection: 'column',
                  alignItems: 'center',
                  justifyContent: 'center',
                  cursor: isSolved ? 'default' : 'pointer',
                  position: 'relative',
                  outline: 'none',
                  transition: reducedMotion ? 'none' : 'transform 0.22s ease-out, border-color 0.2s',
                }}
              >
                {/* Visual Conduit Icon inside rotated container */}
                <div
                  style={{
                    width: '54px',
                    height: '54px',
                    position: 'relative',
                    transform: `rotate(${node.rotation}deg)`,
                    transition: reducedMotion ? 'none' : 'transform 0.22s cubic-bezier(0.34, 1.56, 0.64, 1)',
                  }}
                >
                  {/* Conduit Elbow Pipe Graphic */}
                  <svg viewBox="0 0 60 60" width="100%" height="100%">
                    <path
                      d="M 30 0 L 30 30 L 60 30"
                      fill="none"
                      stroke={isSolved ? '#00f0ff' : isAligned ? '#40e0d0' : '#4a6272'}
                      strokeWidth="8"
                      strokeLinecap="round"
                    />
                    <circle
                      cx="30"
                      cy="30"
                      r="6"
                      fill={isSolved ? '#ffaa00' : isAligned ? '#00f0ff' : '#273843'}
                    />
                  </svg>
                </div>

                <span
                  style={{
                    fontSize: '11px',
                    color: isSolved ? '#00f0ff' : '#7f99a8',
                    marginTop: '6px',
                    fontWeight: 500,
                  }}
                >
                  {node.label}
                </span>
              </button>
            );
          })}
        </div>

        {/* Footer Action */}
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginTop: '4px' }}>
          <div style={{ fontSize: '12px', color: isSolved ? '#00f0ff' : '#ff9944' }}>
            {isSolved ? '⚡ تم التحويل بنجاح!' : '• اضغط على أي مقبس لتغيير اتجاه السريان 90°'}
          </div>
          {isSolved && (
            <button
              type="button"
              onClick={onSuccess}
              style={{
                background: '#00f0ff',
                color: '#020b12',
                border: 'none',
                borderRadius: '6px',
                padding: '8px 18px',
                fontWeight: 700,
                fontSize: '13px',
                cursor: 'pointer',
              }}
            >
              متابعة
            </button>
          )}
        </div>
      </div>
    </div>
  );
};
