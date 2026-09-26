# ECHO NETWORK - FLAX MIGRATION

This file is the primary instruction file for:

- AntyGraffiti
- Codex
- Cline
- Claude Code
- Gemini CLI
- any other coding agent

============================================================
ZERO-INSTALL RULE
============================================================

DO NOT install anything into Windows.

Forbidden:

winget install
choco install
scoop install
MSI installers
EXE installers
Visual Studio Installer
.NET installer
Git installer
Git LFS installer
Flax Launcher installer

Do not modify:

Windows Registry
Machine PATH
User PATH

Use only existing local/project-contained tools.

============================================================
PATHS
============================================================

Repository:

C:\Users\yasmo\EchoNetwork

Godot reference:

C:\Users\yasmo\EchoNetwork\artifacts\eleven-eleven\godot\project.godot

Flax source:

C:\Users\yasmo\EchoNetwork\tools\FlaxEngine

Flax ZIP:

C:\Users\yasmo\EchoNetwork\tools\FlaxEngine.zip

Flax Editor:



Flax migration project directory:

C:\Users\yasmo\EchoNetwork\FlaxMigration\EchoNetworkFlax

============================================================
CRITICAL RULE
============================================================

Never delete or overwrite the Godot implementation.

Godot remains the behavioral and rollback reference.

============================================================
MIGRATION METHOD
============================================================

Do NOT blindly convert:

.gd
.tscn
.tres
.gdshader

Instead:

1. read the Godot implementation
2. understand its behavior
3. identify dependencies
4. design native Flax equivalent
5. implement using Flax C#
6. compile
7. launch
8. test
9. inspect logs
10. fix errors
11. validate behavior
12. document progress

============================================================
FIRST VERTICAL SLICE
============================================================

Implement:

Player
Input
Movement
Gravity
Jump
Sprint
Camera
Collision
Animation

Then validate.

Next implement:

Combat
Enemy
Health
Damage
Abilities
VFX
HUD
Audio

Then:

Japanese city benchmark environment
Lighting
Post-processing
Rendering improvements
Performance profiling

============================================================
QUALITY TARGET
============================================================

Aim for:

responsive controls
high-quality animation
strong combat feedback
professional stylized VFX
high-quality lighting
clean architecture
stable performance

Do not claim success merely because code compiles.

Complete means:

implemented
compiled
launched
tested
validated
documented

============================================================
ENGINE STATUS
============================================================

FlaxEditor.exe:



If this field is empty:

DO NOT pretend Flax can be executed.

Continue only with:
- architecture audit
- migration planning
- safe asset preparation

Do not begin engine-dependent implementation until
FlaxEditor.exe exists and launches successfully.

