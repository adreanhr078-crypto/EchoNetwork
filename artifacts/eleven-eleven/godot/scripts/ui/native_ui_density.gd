extends RefCounted

## Desktop/browser coordinates remain unchanged. Native Android widgets use
## density-independent units, so 48px in the layout is a 48dp touch target.
static func pixel_ratio() -> float:
	if not OS.has_feature("android"): return 1.0
	return maxf(1.0, float(DisplayServer.screen_get_dpi()) / 160.0)
