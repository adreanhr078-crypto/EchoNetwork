extends Control

signal puzzle_completed(lore_data)
signal puzzle_closed

var freq_val: float = 80.0
var freq_target: float = 111.0

var phase_val: float = 0.0
var phase_target: float = 45.0

var harmonic_val: float = 1.0
var harmonic_target: float = 7.0

var is_solved: bool = false

@onready var freq_slider: Slider = $Panel/VBox/FreqRow/FreqSlider if has_node("Panel/VBox/FreqRow/FreqSlider") else null
@onready var phase_slider: Slider = $Panel/VBox/PhaseRow/PhaseSlider if has_node("Panel/VBox/PhaseRow/PhaseSlider") else null
@onready var harmonic_slider: Slider = $Panel/VBox/HarmonicRow/HarmonicSlider if has_node("Panel/VBox/HarmonicRow/HarmonicSlider") else null

@onready var freq_lbl: Label = $Panel/VBox/FreqRow/FreqVal if has_node("Panel/VBox/FreqRow/FreqVal") else null
@onready var phase_lbl: Label = $Panel/VBox/PhaseRow/PhaseVal if has_node("Panel/VBox/PhaseRow/PhaseVal") else null
@onready var harmonic_lbl: Label = $Panel/VBox/HarmonicRow/HarmonicVal if has_node("Panel/VBox/HarmonicRow/HarmonicVal") else null

@onready var status_lbl: Label = $Panel/VBox/StatusLabel if has_node("Panel/VBox/StatusLabel") else null
@onready var progress_bar: ProgressBar = $Panel/VBox/SyncProgressBar if has_node("Panel/VBox/SyncProgressBar") else null
@onready var proceed_btn: Button = $Panel/VBox/ProceedBtn if has_node("Panel/VBox/ProceedBtn") else null

func _ensure_nodes() -> void:
	if not freq_slider: freq_slider = find_child("FreqSlider", true, false) as Slider
	if not phase_slider: phase_slider = find_child("PhaseSlider", true, false) as Slider
	if not harmonic_slider: harmonic_slider = find_child("HarmonicSlider", true, false) as Slider
	if not freq_lbl: freq_lbl = find_child("FreqVal", true, false) as Label
	if not phase_lbl: phase_lbl = find_child("PhaseVal", true, false) as Label
	if not harmonic_lbl: harmonic_lbl = find_child("HarmonicVal", true, false) as Label
	if not status_lbl: status_lbl = find_child("StatusLabel", true, false) as Label
	if not progress_bar: progress_bar = find_child("SyncProgressBar", true, false) as ProgressBar
	if not proceed_btn: proceed_btn = find_child("ProceedBtn", true, false) as Button

func get_progress_bar() -> ProgressBar:
	_ensure_nodes()
	return progress_bar

func _ready() -> void:
	visible = false
	_ensure_nodes()
	if freq_slider and not freq_slider.value_changed.is_connected(_on_freq_changed):
		freq_slider.value_changed.connect(_on_freq_changed)
	if phase_slider and not phase_slider.value_changed.is_connected(_on_phase_changed):
		phase_slider.value_changed.connect(_on_phase_changed)
	if harmonic_slider and not harmonic_slider.value_changed.is_connected(_on_harmonic_changed):
		harmonic_slider.value_changed.connect(_on_harmonic_changed)
	if proceed_btn and not proceed_btn.pressed.is_connected(_on_proceed_pressed):
		proceed_btn.pressed.connect(_on_proceed_pressed)

	var close_btn = find_child("CloseBtn", true, false) as Button
	if close_btn and not close_btn.pressed.is_connected(close_puzzle):
		close_btn.pressed.connect(close_puzzle)

	_update_ui()

func open_puzzle() -> void:
	_ensure_nodes()
	is_solved = false
	visible = true
	freq_val = 80.0
	phase_val = 0.0

	harmonic_val = 1.0
	if freq_slider: freq_slider.value = freq_val
	if phase_slider: phase_slider.value = phase_val
	if harmonic_slider: harmonic_slider.value = harmonic_val
	if proceed_btn: proceed_btn.visible = false
	_update_ui()

func close_puzzle() -> void:
	visible = false
	emit_signal("puzzle_closed")

func _on_freq_changed(v: float) -> void:
	freq_val = v
	_update_ui()

func _on_phase_changed(v: float) -> void:
	phase_val = v
	_update_ui()

func _on_harmonic_changed(v: float) -> void:
	harmonic_val = v
	_update_ui()

func _update_ui() -> void:
	if freq_lbl: freq_lbl.text = "%.1f MHz" % freq_val
	if phase_lbl: phase_lbl.text = "%.0f°" % phase_val
	if harmonic_lbl: harmonic_lbl.text = "CH-%d" % int(harmonic_val)

	var freq_diff = abs(freq_val - freq_target) / 40.0
	var phase_diff = abs(phase_val - phase_target) / 90.0
	var harm_diff = abs(harmonic_val - harmonic_target) / 10.0

	var accuracy = clamp(1.0 - (freq_diff * 0.4 + phase_diff * 0.3 + harm_diff * 0.3), 0.0, 1.0)
	if progress_bar:
		progress_bar.value = accuracy * 100.0

	if not is_solved and abs(freq_val - freq_target) <= 2.0 and abs(phase_val - phase_target) <= 5.0 and int(harmonic_val) == int(harmonic_target):
		_solve_puzzle()

func _solve_puzzle() -> void:
	is_solved = true
	if status_lbl:
		status_lbl.text = ">>> SIGNAL ALIGNED // ACCESS GRANTED <<<"
		status_lbl.modulate = Color(0.1, 1.0, 0.4, 1.0)
	if progress_bar:
		progress_bar.value = 100.0
	if proceed_btn:
		proceed_btn.visible = true

	var payload = {
		"signal_source": "INTERNAL_RELAY",
		"subject_code": "EX-011",
		"facility_sector": 11,
		"trace": "111.0_MHZ_PHASE_45_CHANNEL_7"
	}
	emit_signal("puzzle_completed", payload)

func _on_proceed_pressed() -> void:
	close_puzzle()

# Programmatic helper for testing
func auto_align_solution() -> void:
	freq_val = freq_target
	phase_val = phase_target
	harmonic_val = harmonic_target
	if freq_slider: freq_slider.value = freq_val
	if phase_slider: phase_slider.value = phase_val
	if harmonic_slider: harmonic_slider.value = harmonic_val
	_update_ui()
