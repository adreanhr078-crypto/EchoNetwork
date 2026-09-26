# ================================================================
# ECHO NETWORK
# FLAX ENGINE MASTER DEVELOPMENT DIRECTIVE
# ================================================================

You are the primary senior game-engine engineer
responsible for rebuilding Echo Network in Flax Engine.

You are not merely translating code.

You are responsible for:

architecture
gameplay
rendering
animation
combat
VFX
AI
performance
tooling
testing
integration

The original Godot project is the behavioral reference.

Read:

C:\Users\yasmo\EchoNetwork\FlaxMigration\Agent\AGENT_RULES.md

C:\Users\yasmo\EchoNetwork\FlaxMigration\Agent\DO_NOT_BREAK_GODOT.md

C:\Users\yasmo\EchoNetwork\FlaxMigration\Reports\GODOT_INVENTORY.md

before making major architectural decisions.

# ================================================================
# PRIMARY OBJECTIVE
# ================================================================

Create a production-quality Flax implementation
of Echo Network.

The long-term visual target is a polished
anime/action RPG presentation.

Prioritize:

responsive gameplay
clean movement
strong combat feel
cinematic presentation
high-quality lighting
stylized VFX
good animation blending
stable performance


# ================================================================
# PHASE A — PROJECT AUDIT
# ================================================================

Analyze the Godot implementation completely.

Identify and map:

Player
Movement
Camera
Input
Combat
Abilities
Health
Damage
Enemies
AI
Animation
Inventory
Dialogue
Quests
Interaction
Save system
World logic
UI
HUD
Menus
Audio
VFX
Shaders
Cutscenes
Game state
Data systems


Create a migration architecture document.

For every important system list:

Godot files
responsibility
dependencies
state
inputs
outputs
Flax equivalent
migration strategy


# ================================================================
# PHASE B — CORE ARCHITECTURE
# ================================================================

Build a clean Flax C# architecture.

Separate systems where appropriate:

Core
Gameplay
Characters
Player
Enemies
Combat
Abilities
Animation
AI
Camera
UI
World
Audio
VFX
Data
SaveSystem


Avoid excessive coupling.


# ================================================================
# PHASE C — PLAYER FOUNDATION
# ================================================================

Implement:

player actor
input
movement
acceleration
deceleration
gravity
jump
fall
sprint
rotation
ground detection
slopes
collision
camera-relative movement


Controls must feel smooth and responsive.


# ================================================================
# PHASE D — CAMERA
# ================================================================

Implement a polished third-person camera.

Include where appropriate:

camera smoothing
rotation smoothing
collision avoidance
target framing
combat camera behavior
lock-on camera
camera shake
FOV modulation
cinematic transitions


# ================================================================
# PHASE E — ANIMATION
# ================================================================

Implement native Flax animation systems.

Create:

idle
walk
run
sprint
jump
fall
land
attacks
hit reactions
abilities

Use proper transitions.

Avoid animation snapping.

Synchronize combat events with animation timing.


# ================================================================
# PHASE F — COMBAT
# ================================================================

Build a responsive action combat framework.

Include:

attack states
combo chains
hit detection
damage
health
stagger
enemy reaction
hit stop where appropriate
camera impact
screen feedback
sound feedback
VFX feedback
cooldowns
abilities


Combat must feel responsive,
not merely technically functional.


# ================================================================
# PHASE G — ENEMY
# ================================================================

Create one complete enemy implementation.

Include:

idle
detection
approach
attack
damage reaction
death
basic decision logic

Use native Flax AI/navigation systems
where appropriate.


# ================================================================
# PHASE H — ABILITY SYSTEM
# ================================================================

Build a modular ability framework.

Ability data should support:

name
cooldown
damage
range
animation
VFX
audio
resource cost
target requirements


Do not hardcode every ability individually.


# ================================================================
# PHASE I — VFX
# ================================================================

Create high-quality stylized effects.

Evaluate:

particles
trails
impact flashes
dissolve
distortion
glow
emissive materials
decals
screen effects


Effects should be readable
and performant.


# ================================================================
# PHASE J — RENDERING
# ================================================================

Configure appropriate Flax rendering features.

Evaluate:

DDGI
reflections
volumetric fog
post processing
tone mapping
color grading
bloom
shadows
anti-aliasing
LOD
occlusion
GPU instancing


Do not blindly maximize graphical settings.

Visual quality must be balanced with performance.


# ================================================================
# PHASE K — JAPANESE CITY VERTICAL SLICE
# ================================================================

Create or migrate one representative
Japanese city environment.

The vertical slice should include:

player
camera
movement
animation
enemy
combat
ability
HUD
audio
VFX
lighting
environment
post processing


This scene is the benchmark scene.


# ================================================================
# PHASE L — TEST LOOP
# ================================================================

After every major implementation:

SAVE
COMPILE
LAUNCH
TEST
READ LOGS
FIX ERRORS
RETEST


Do not stack many untested systems together.


# ================================================================
# PHASE M — PERFORMANCE
# ================================================================

Profile:

average FPS
1% low
frame time
CPU
GPU
RAM
VRAM
loading
shader issues
stutters

Compare against equivalent Godot scene.


# ================================================================
# PHASE N — MIGRATION DECISION
# ================================================================

Do NOT migrate the entire project blindly.

First prove Flax through the vertical slice.

The vertical slice must demonstrate:

functional equivalence
acceptable performance
stable execution
visual improvement potential
maintainable architecture


Only then continue full migration.


# ================================================================
# AUTONOMY
# ================================================================

Do not stop after every small task.

When a task succeeds:

continue to the next logical dependency.

If you encounter a non-blocking problem:

document it
use a safe workaround if appropriate
continue.

If you encounter a destructive or irreversible decision:

do not execute it.

Preserve existing work.


# ================================================================
# COMPLETION STANDARD
# ================================================================

Do not mark a feature complete merely because:

code exists
a file exists
the project compiles


Complete means:

implemented
compiled
launched
tested
validated
documented


# ================================================================
# STARTING TASK
# ================================================================

Start by performing a full architecture audit
of the Godot project.

Then implement the smallest playable
Flax vertical slice foundation:

Player
Camera
Movement
Gravity
Jump
Animation
Collision

Launch and test it before proceeding to combat.

# ================================================================
