class_name ClassroomLessonQuizEngine
extends Node

## AAA Minato Academy Classroom Lesson & Academic Rank Quiz Engine
## Interactive academic mini-game in Class 2-B:
## - Questions on Cataclysm History, Resonance Physics, and Town Geography
## - Correct answers restore mental focus, elevate academic standing, and grant classmates' praise.

signal quiz_completed(score: int, total: int, academic_rank_gain: int)
signal answer_submitted(question_id: int, is_correct: bool)

const QUIZ_QUESTIONS: Array[Dictionary] = [
	{
		"question": "What primary anomaly triggered the Great Minato Bay Cataclysm?",
		"options": [
			"Tectonic Fault Rupture",
			"Neural Singularity Core Detonation",
			"Deep Ocean Trench Volcanism",
			"Atmospheric Solar Flare"
		],
		"correct_index": 1,
		"explanation": "Dr. Kinga's illicit Sector 11 Singularity Core detonated, fracturing the local dimensional barrier."
	},
	{
		"question": "Which resonance frequency stabilizes human cognitive sanity during Void distortion?",
		"options": [
			"60 Hz Grid Current",
			"528 Hz Solfeggio Shimmer",
			"2400 Hz Katana Edge Resonance",
			"15 Hz Infrasound"
		],
		"correct_index": 1,
		"explanation": "528 Hz harmonic frequency grounds neural pathways and counters reality glitch distortion."
	}
]

var academic_score: int = 0
var total_answered: int = 0

func get_questions_count() -> int:
	return QUIZ_QUESTIONS.size()

func get_question(index: int) -> Dictionary:
	if index >= 0 and index < QUIZ_QUESTIONS.size():
		return QUIZ_QUESTIONS[index]
	return {}

## Submits an answer to a classroom pop quiz question
func submit_answer(question_index: int, chosen_option: int, player: Node = null) -> Dictionary:
	if question_index < 0 or question_index >= QUIZ_QUESTIONS.size():
		return {"success": false, "error": "Invalid question index"}

	var q: Dictionary = QUIZ_QUESTIONS[question_index]
	var is_correct = (chosen_option == q["correct_index"])

	total_answered += 1
	var points_earned = 0
	if is_correct:
		academic_score += 15
		points_earned = 15
		if player and player.has_method("restore_stamina"):
			player.restore_stamina(20.0)

	emit_signal("answer_submitted", question_index, is_correct)

	return {
		"success": true,
		"question_index": question_index,
		"is_correct": is_correct,
		"points_earned": points_earned,
		"total_score": academic_score,
		"explanation": q["explanation"],
		"teacher_comment": "Excellent insight, Kasumi-kun!" if is_correct else "Review chapter 4 tonight, Kasumi-kun."
	}
