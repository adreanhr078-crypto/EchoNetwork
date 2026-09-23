const fs = require('fs');
let code = fs.readFileSync('src/features/gameplay/components/ThirdPersonCamera.tsx', 'utf8');

const pointerLockReplace = `    const handlePointerDown = (event: PointerEvent) => {
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
    };`;

code = code.replace(/const handlePointerDown = \(event: PointerEvent\) => \{.*?const releasePointer =/s, pointerLockReplace + '\n\n    const releasePointer =');

fs.writeFileSync('src/features/gameplay/components/ThirdPersonCamera.tsx', code);
