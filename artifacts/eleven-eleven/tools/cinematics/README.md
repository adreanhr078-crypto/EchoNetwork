# Signature editorial tools

Run from `artifacts/eleven-eleven`:

```powershell
python tools/cinematics/build_signature_packet.py
python tools/cinematics/render_signature_animatic.py
python tools/cinematics/validate_signature_packet.py
```

The builder verifies the approved publication manifest before writing the P01
matrix and 23-shot P05/P06 draft. `direct`, `support`, and `owner` relationships
are intentionally distinct; no missing literal page is invented.

The renderer uses installed Pillow and FFmpeg, including FFmpeg's native Arabic
text shaping. No new dependency is needed. Derivatives are cached by script,
font, timeline and source-lock hashes under `.tmp/signature-animatic/`. Source
pages are immutable. The silent linear export labels its provisional identity,
and its decision slates never substitute for native input or game authority.

The validator checks current source hashes, all existing events, phase and
requirement counts, crop/clock/consent boundaries, the encoded media and native
report source hashes. Integrity PASS does not accept art, acting, audio, contact,
gameplay, player enjoyment or a chapter.

The opt-in reviewer and its regression live in the existing Godot project:

- `godot/scenes/review/signature_animatic.tscn`
- `godot/tests/signature_animatic_review.gd`

The reviewer has no player, network, save, reward or contract dependency. Production
Boot, V31, School/Pact geometry, source motion keys and Golden remain unchanged.
