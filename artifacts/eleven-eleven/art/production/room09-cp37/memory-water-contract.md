# Playable memory water — scoped visual contract

Owner 18 October: improve rooms with memory screens and water inspired by the
supplied moon video, keeping the journey enjoyable, coherent and smooth.
Scope: existing laboratory subjective memory trial only, original room footprint,
approved Shizuka/Yuki pictures and their actual proximity interactions. Reuse
the four native room references under references/. No invented memories,
additional lore, early Zero/power, new puzzle, water hazard or collision change.

Add shallow reflective water over the existing lower floor during memories,
refusal and abyss/drowning. The existing raised theater remains the readable
route. Keep the two actual memory screens as the focal points. Reflect actual
room geometry/screens with a bounded planar reflection viewport; do not replace
the gameplay room with the title video or paint fake reflection images.
Gentle analytic ripples, local elapsed clock, optional foot ripples only when the
real player is at the water surface. Reduced Motion freezes decorative waves;
camera-dependent reflection remains correct while the player moves. Pause and
rollback freeze/remove owned presentation, never advance a decision.

Render budget: one768×960 reflection view, at most30updates/s, disabled outside
the memory phase/active room. An upward off-axis camera uses the water rectangle
as its near plane, clipping submerged geometry without changing world materials
or render layers. Exclude only the water from this camera. Main camera and all
physics/collisions/triggers/save fields remain unchanged. No additional lights,
shadow maps, particles, texture downloads, camera authority or character keys.
Review actual rendered room, then compare timing/frame cost and public input
before accepting. This contract does not claim matching the generated video or
final art/device acceptance before that inspection.
