# Echo Network — AI Agent Rules

These rules apply to:

- AntyGraffiti
- Codex
- Cline
- Claude Code
- Gemini CLI
- other coding agents

---

# ENGINE STRATEGY

Godot = behavioral reference.

Flax = new parallel implementation.

Never destroy the reference implementation.

---

# ZERO-INSTALL RULE

Do NOT install software into Windows.

Forbidden:

winget install
choco install
scoop install
MSI installation
EXE installer execution
Visual Studio Installer
.NET installer
Git installer
Git LFS installer

Do not modify:

registry
machine PATH
user PATH

Use only tools already available
or project-contained portable tools.

---

# ENGINE ACCESS

Flax Editor:



Flax project:

C:\Users\yasmo\EchoNetwork\FlaxMigration\EchoNetworkFlax

Godot project:

C:\Users\yasmo\EchoNetwork

---

# WORKING METHOD

Before modifying a system:

1. locate its Godot implementation
2. understand its behavior
3. document dependencies
4. identify native Flax equivalent
5. design clean C# architecture
6. implement
7. compile
8. launch
9. test
10. inspect logs
11. fix
12. compare behavior
13. document completion

Never guess how an existing feature behaves.

Read the existing implementation first.

---

# IMPLEMENTATION PRIORITY

Prefer:

native Flax APIs
C#
component-based design
data-driven configuration
modular systems
clear dependencies

Avoid:

temporary hacks
giant scripts
duplicated systems
hardcoded scene assumptions
blind Godot-to-C# translation

---

# QUALITY TARGET

The Flax version must aim for:

cleaner architecture
strong visual presentation
stable frame pacing
responsive controls
high-quality combat feedback
professional VFX
high-quality lighting
proper animation transitions
maintainable systems

But do not invent improvements before matching
existing intended functionality.

---

# NEVER CLAIM SUCCESS JUST BECAUSE CODE COMPILES

A system is complete only when:

it compiles
it launches
it behaves correctly
it produces no critical runtime errors
it has been tested

