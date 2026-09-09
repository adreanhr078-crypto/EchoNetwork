import { useEffect, useRef, useState } from 'react';
import { useEchoMindLivingStore } from '../../application/echo/echoMindLivingStore';

interface ScreenBreakRuntimeProps {
  reducedMotion: boolean;
  onComplete: () => void;
}

const COVER_IMAGE = '/manhwa/echo-network-final-2026-09-v1/page-001.webp';

function createShards(width: number, height: number) {
  const shards: any[] = [];
  const rows = 12;
  const cols = 12;
  const vertices: {x: number, y: number}[][] = [];
  
  for (let r = 0; r <= rows; r++) {
    const row: {x: number, y: number}[] = [];
    for (let c = 0; c <= cols; c++) {
      const x = (c / cols) * width + (c === 0 || c === cols ? 0 : (Math.random() - 0.5) * (width / cols));
      const y = (r / rows) * height + (r === 0 || r === rows ? 0 : (Math.random() - 0.5) * (height / rows));
      row.push({ x, y });
    }
    vertices.push(row);
  }

  const cx = width / 2;
  const cy = height / 2;

  for (let r = 0; r < rows; r++) {
    for (let c = 0; c < cols; c++) {
      const v1 = vertices[r][c];
      const v2 = vertices[r][c+1];
      const v3 = vertices[r+1][c+1];
      const v4 = vertices[r+1][c];

      const addShard = (p1: any, p2: any, p3: any) => {
        const centroidX = (p1.x + p2.x + p3.x) / 3;
        const centroidY = (p1.y + p2.y + p3.y) / 3;
        const dx = centroidX - cx;
        const dy = centroidY - cy;
        const dist = Math.sqrt(dx * dx + dy * dy) || 1;
        const speed = (Math.random() * 300 + 100) / (dist * 0.05 + 1); 
        
        shards.push({
          points: [p1, p2, p3],
          x: 0,
          y: 0,
          vx: (dx / dist) * speed,
          vy: (dy / dist) * speed - (Math.random() * 200),
          rot: 0,
          vrot: (Math.random() - 0.5) * 0.3,
          delay: Math.random() * 200,
        });
      };

      if (Math.random() > 0.5) {
        addShard(v1, v2, v3);
        addShard(v1, v3, v4);
      } else {
        addShard(v1, v2, v4);
        addShard(v2, v3, v4);
      }
    }
  }
  return shards;
}

export function ScreenBreakRuntime({
  reducedMotion,
  onComplete,
}: ScreenBreakRuntimeProps) {
  const completedRef = useRef(false);
  const [shatterDone, setShatterDone] = useState(reducedMotion);
  const canvasRef = useRef<HTMLCanvasElement>(null);
  
  const finish = () => {
    if (completedRef.current) return;
    completedRef.current = true;
    onComplete();
  };

  const soundsEnabled = useEchoMindLivingStore(s => s.preferences.signalSoundsEnabled);

  useEffect(() => {
    if (reducedMotion) {
      const timer = window.setTimeout(finish, 2000);
      return () => window.clearTimeout(timer);
    }
    const fallbackTimer = window.setTimeout(finish, 38000);
    return () => window.clearTimeout(fallbackTimer);
  }, [reducedMotion]);

  useEffect(() => {
    if (reducedMotion || !canvasRef.current) return;
    const canvas = canvasRef.current;
    const ctx = canvas.getContext('2d');
    if (!ctx) return;

    let animationFrame: number;
    let shards: any[] = [];
    let startTime: number;

    const img = new Image();
    img.src = COVER_IMAGE;
    img.onload = () => {
      canvas.width = window.innerWidth;
      canvas.height = window.innerHeight;
      shards = createShards(canvas.width, canvas.height);
      startTime = performance.now();
      
      const draw = (time: number) => {
        const elapsed = time - startTime;
        ctx.clearRect(0, 0, canvas.width, canvas.height);
        
        let allFallen = true;

        for (const shard of shards) {
          if (elapsed < shard.delay) {
            allFallen = false;
            ctx.save();
            ctx.beginPath();
            ctx.moveTo(shard.points[0].x, shard.points[0].y);
            ctx.lineTo(shard.points[1].x, shard.points[1].y);
            ctx.lineTo(shard.points[2].x, shard.points[2].y);
            ctx.closePath();
            ctx.clip();
            
            const imgRatio = img.width / img.height;
            const canvasRatio = canvas.width / canvas.height;
            let drawWidth = canvas.width;
            let drawHeight = canvas.height;
            let offsetX = 0;
            let offsetY = 0;
            if (canvasRatio > imgRatio) {
               drawHeight = canvas.width / imgRatio;
               offsetY = (canvas.height - drawHeight) / 2;
            } else {
               drawWidth = canvas.height * imgRatio;
               offsetX = (canvas.width - drawWidth) / 2;
            }
            ctx.drawImage(img, offsetX, offsetY, drawWidth, drawHeight);
            ctx.restore();
            continue;
          }

          const delta = 1 / 60;
          shard.vy += 2500 * delta;
          shard.x += shard.vx * delta;
          shard.y += shard.vy * delta;
          shard.rot += shard.vrot;

          if (shard.y < canvas.height * 2) {
            allFallen = false;
            const cx = (shard.points[0].x + shard.points[1].x + shard.points[2].x) / 3;
            const cy = (shard.points[0].y + shard.points[1].y + shard.points[2].y) / 3;

            ctx.save();
            ctx.translate(cx + shard.x, cy + shard.y);
            ctx.rotate(shard.rot);
            ctx.translate(-cx, -cy);

            ctx.beginPath();
            ctx.moveTo(shard.points[0].x, shard.points[0].y);
            ctx.lineTo(shard.points[1].x, shard.points[1].y);
            ctx.lineTo(shard.points[2].x, shard.points[2].y);
            ctx.closePath();
            ctx.clip();

            const imgRatio = img.width / img.height;
            const canvasRatio = canvas.width / canvas.height;
            let drawWidth = canvas.width;
            let drawHeight = canvas.height;
            let offsetX = 0;
            let offsetY = 0;
            if (canvasRatio > imgRatio) {
               drawHeight = canvas.width / imgRatio;
               offsetY = (canvas.height - drawHeight) / 2;
            } else {
               drawWidth = canvas.height * imgRatio;
               offsetX = (canvas.width - drawWidth) / 2;
            }
            ctx.drawImage(img, offsetX, offsetY, drawWidth, drawHeight);

            ctx.strokeStyle = 'rgba(255,255,255,0.4)';
            ctx.lineWidth = 1;
            ctx.stroke();

            ctx.restore();
          }
        }

        if (elapsed > 2500 || allFallen) {
          setShatterDone(true);
        } else {
          animationFrame = requestAnimationFrame(draw);
        }
      };
      
      animationFrame = requestAnimationFrame(draw);
    };

    return () => cancelAnimationFrame(animationFrame);
  }, [reducedMotion]);

  return (
    <div className="screen-break-runtime" role="dialog" aria-modal="true" aria-label="Screen break" style={{ position: 'fixed', inset: 0, zIndex: 100, backgroundColor: 'black' }}>
      {reducedMotion ? (
        <div
          className="screen-break-runtime__poster"
          style={{
            backgroundImage: 'url("/assets/cinematics/part-1-opening-poster.webp")',
            backgroundSize: 'cover',
            backgroundPosition: 'center',
            width: '100%',
            height: '100%',
            position: 'absolute',
          }}
        />
      ) : (
        <>
          <video
            className="screen-break-runtime__video"
            src="/assets/cinematics/part-1-opening.webm"
            poster="/assets/cinematics/part-1-opening-poster.webp"
            autoPlay
            muted={!soundsEnabled}
            playsInline
            onEnded={finish}
            style={{ width: '100%', height: '100%', objectFit: 'cover', position: 'absolute', top: 0, left: 0 }}
          />
          {!shatterDone && (
             <canvas
               ref={canvasRef}
               style={{ width: '100%', height: '100%', position: 'absolute', top: 0, left: 0, pointerEvents: 'none' }}
             />
          )}
        </>
      )}
      <div className="screen-break-runtime__hud" aria-hidden="true" style={{ position: 'absolute', top: 20, left: 20, color: 'crimson', fontFamily: 'monospace', zIndex: 101, textShadow: '0 0 4px rgba(0,0,0,0.8)' }}>
        <small>INTERFACE LAYER // FAILURE</small>
        <br />
        <strong>11:11</strong>
        <br />
        <span>DEPTH CHANNEL OPEN</span>
      </div>
      <button type="button" className="screen-break-runtime__skip" onClick={finish} style={{ position: 'absolute', bottom: 20, right: 20, zIndex: 101, background: 'rgba(0,0,0,0.5)', color: '#fff', border: '1px solid rgba(255,255,255,0.2)', padding: '8px 16px', cursor: 'pointer' }}>
        Skip transition
      </button>
    </div>
  );
}
