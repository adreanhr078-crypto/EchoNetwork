import {
  useEffect,
  useMemo,
  useRef,
  type MutableRefObject,
} from 'react';
import { useFrame, useThree } from '@react-three/fiber';
import {
  MathUtils,
  Vector3,
  type Group,
} from 'three';

export interface ThirdPersonCameraConfig {
  distance: number;
  height: number;
  lookHeight: number;
  followSmoothing: number;
  pointerSensitivity: number;
  minPitch: number;
  maxPitch: number;
  bounds: {
    minX: number;
    maxX: number;
    minZ: number;
    maxZ: number;
    minY: number;
    maxY: number;
  };
}

interface ThirdPersonCameraProps {
  targetRef: MutableRefObject<Group | null>;
  yawRef: MutableRefObject<number>;
  traumaRef?: MutableRefObject<number>;
  enabled: boolean;
  config: ThirdPersonCameraConfig;
}

export function ThirdPersonCamera({
  targetRef,
  yawRef,
  traumaRef,
  enabled,
  config,
}: ThirdPersonCameraProps) {
  const { camera, gl } = useThree();
  const pitchRef = useRef(0.02);
  const initializedRef = useRef(false);
  const dragRef = useRef<{
    active: boolean;
    pointerId: number;
    x: number;
    y: number;
  }>({
    active: false,
    pointerId: -1,
    x: 0,
    y: 0,
  });
  const targetPosition = useMemo(() => new Vector3(), []);
  const desiredPosition = useMemo(() => new Vector3(), []);
  const lookTarget = useMemo(() => new Vector3(), []);

  const distanceRef = useRef(config.distance);

  useEffect(() => {
    const element = gl.domElement;

    const handlePointerDown = (event: PointerEvent) => {
      if (event.pointerType === 'mouse') {
        if (document.pointerLockElement !== element) {
          element.requestPointerLock().catch(() => {});
        }
      }

      dragRef.current = {
        active: true,
        pointerId: event.pointerId,
        x: event.clientX,
        y: event.clientY,
      };
      if (event.pointerType !== 'mouse') {
        element.setPointerCapture(event.pointerId);
      }
      element.classList.add('is-camera-dragging');
    };

    const handlePointerMove = (event: PointerEvent) => {
      const drag = dragRef.current;

      let deltaX = 0;
      let deltaY = 0;

      if (document.pointerLockElement === element) {
        deltaX = event.movementX;
        deltaY = event.movementY;
      } else {
        if (!drag.active || drag.pointerId !== event.pointerId) {
          return;
        }
        deltaX = event.clientX - drag.x;
        deltaY = event.clientY - drag.y;
        drag.x = event.clientX;
        drag.y = event.clientY;
      }

      yawRef.current -= deltaX * config.pointerSensitivity;
      pitchRef.current = MathUtils.clamp(
        pitchRef.current + deltaY * config.pointerSensitivity,
        config.minPitch,
        config.maxPitch,
      );
    };

    const releasePointer = (event: PointerEvent) => {
      const drag = dragRef.current;
      if (!drag.active || drag.pointerId !== event.pointerId) return;
      drag.active = false;
      element.classList.remove('is-camera-dragging');
      if (element.hasPointerCapture(event.pointerId)) {
        element.releasePointerCapture(event.pointerId);
      }
    };

    const handleWheel = (event: WheelEvent) => {
      event.preventDefault();
      distanceRef.current = MathUtils.clamp(
        distanceRef.current + event.deltaY * 0.002,
        1.6,
        3.4,
      );
    };

    const handleContextMenu = (event: MouseEvent) => {
      event.preventDefault(); // allow right-mouse dragging without browser menu
    };

    element.addEventListener('pointerdown', handlePointerDown);
    element.addEventListener('pointermove', handlePointerMove);
    element.addEventListener('pointerup', releasePointer);
    element.addEventListener('pointercancel', releasePointer);
    element.addEventListener('wheel', handleWheel, { passive: false });
    element.addEventListener('contextmenu', handleContextMenu);

    return () => {
      element.classList.remove('is-camera-dragging');
      element.removeEventListener('pointerdown', handlePointerDown);
      element.removeEventListener('pointermove', handlePointerMove);
      element.removeEventListener('pointerup', releasePointer);
      element.removeEventListener('pointercancel', releasePointer);
      element.removeEventListener('wheel', handleWheel);
      element.removeEventListener('contextmenu', handleContextMenu);
    };
  }, [
    config.maxPitch,
    config.minPitch,
    config.pointerSensitivity,
    gl,
    yawRef,
  ]);

  useFrame((_, delta) => {
    if (!enabled) return;
    const target = targetRef.current;
    if (!target) return;

    target.getWorldPosition(targetPosition);

    // GENSHIN IMPACT & THE LAST OF US 3RD PERSON CINEMATIC OVER-THE-SHOULDER FRAMING:
    const yaw = yawRef.current;
    const pitch = pitchRef.current;
    const distance = distanceRef.current;

    // Golden Ratio cinematic over-the-shoulder offset (Echo framed cleanly on left-third)
    const shoulderOffset = 0.36;
    const shoulderX = Math.cos(yaw) * shoulderOffset;
    const shoulderZ = -Math.sin(yaw) * shoulderOffset;

    // Focus target is Echo's upper chest / neck
    lookTarget.set(
      targetPosition.x - shoulderX * 0.2,
      targetPosition.y + config.lookHeight,
      targetPosition.z - shoulderZ * 0.2,
    );

    // Spherical orbit around lookTarget
    const cosPitch = Math.cos(pitch);
    const sinPitch = Math.sin(pitch);
    const armH = distance * cosPitch;
    const armV = distance * sinPitch + config.height;

    const armVec = new Vector3(
      Math.sin(yaw) * armH + shoulderX,
      armV,
      Math.cos(yaw) * armH + shoulderZ,
    );

    // Dynamic chamber bounds for interior divider partitions:
    let effectiveMinX = config.bounds.minX;
    let effectiveMaxX = config.bounds.maxX;
    let effectiveMinZ = config.bounds.minZ;
    let effectiveMaxZ = config.bounds.maxZ;

    // Eastern Sub-Chambers vs Main Corridor separation:
    if (targetPosition.x > 5.0) {
      effectiveMinX = 5.2; // Keep camera inside sub-labs, avoiding east corridor wall at x = 4.9
      if (targetPosition.z < -4.0) {
        // Deep Containment Vault (z: -14.5 to -4.0)
        effectiveMaxZ = -4.3; // Prevent clipping through Entrance 3 divider at z = -4.0
      } else if (targetPosition.z < 4.0) {
        // Sub-Chamber Beta (z: -4.0 to 4.0)
        effectiveMinZ = -3.7;
        effectiveMaxZ = 3.7;
      } else {
        // Sub-Lab Alpha (z: 4.0 to 11.0)
        effectiveMinZ = 4.3;
        effectiveMaxZ = 10.7;
      }
    } else {
      // Main Corridor (x <= 5.0)
      effectiveMaxX = 4.7; // Avoid clipping through the East dividing wall at x = 4.9
    }

    // Wall collision test: pull camera in along arm vector if hitting room or partition boundary
    let scaleFactor = 1.0;
    const testPos = new Vector3().addVectors(lookTarget, armVec);

    if (Math.abs(armVec.x) > 0.001) {
      if (testPos.x < effectiveMinX) {
        const sx = (effectiveMinX - lookTarget.x) / armVec.x;
        if (sx > 0) scaleFactor = Math.min(scaleFactor, sx);
      } else if (testPos.x > effectiveMaxX) {
        const sx = (effectiveMaxX - lookTarget.x) / armVec.x;
        if (sx > 0) scaleFactor = Math.min(scaleFactor, sx);
      }
    }
    if (Math.abs(armVec.z) > 0.001) {
      if (testPos.z < effectiveMinZ) {
        const sz = (effectiveMinZ - lookTarget.z) / armVec.z;
        if (sz > 0) scaleFactor = Math.min(scaleFactor, sz);
      } else if (testPos.z > effectiveMaxZ) {
        const sz = (effectiveMaxZ - lookTarget.z) / armVec.z;
        if (sz > 0) scaleFactor = Math.min(scaleFactor, sz);
      }
    }

    scaleFactor = MathUtils.clamp(scaleFactor, 0.35, 1.0);

    desiredPosition.set(
      lookTarget.x + armVec.x * scaleFactor,
      lookTarget.y + armVec.y * scaleFactor,
      lookTarget.z + armVec.z * scaleFactor,
    );

    desiredPosition.x = MathUtils.clamp(desiredPosition.x, effectiveMinX, effectiveMaxX);
    desiredPosition.y = MathUtils.clamp(desiredPosition.y, config.bounds.minY, config.bounds.maxY);
    desiredPosition.z = MathUtils.clamp(desiredPosition.z, effectiveMinZ, effectiveMaxZ);

    let shakePitchOffset = 0;
    let shakeYawOffset = 0;

    // Visceral Combat Trauma Shake (Rotational)
    if (traumaRef && traumaRef.current > 0.001) {
      traumaRef.current = Math.max(0, traumaRef.current - delta * 2.8);
      const shake = traumaRef.current * traumaRef.current;
      const shakeTime = performance.now() * 0.045;
      shakePitchOffset = Math.sin(shakeTime * 2.5) * 0.05 * shake;
      shakeYawOffset = Math.cos(shakeTime * 3.1) * 0.05 * shake;
    }

    if (!initializedRef.current) {
      camera.position.copy(desiredPosition);
      camera.lookAt(lookTarget);
      initializedRef.current = true;
    } else {
      const followAlpha = 1 - Math.exp(-config.followSmoothing * delta);
      camera.position.lerp(desiredPosition, followAlpha);
      camera.lookAt(lookTarget);
    }

    // Apply rotational shake directly to the camera orientation after lookAt
    if (shakePitchOffset !== 0 || shakeYawOffset !== 0) {
      camera.rotateX(shakePitchOffset);
      camera.rotateY(shakeYawOffset);
    }
  });

  return null;
}
