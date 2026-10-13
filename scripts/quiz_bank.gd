extends RefCounted

var questions: Array = []
var bag: Array = []
var last_id := ""
var error_message := ""

func load_bank() -> bool:
	var file := FileAccess.open("res://data/questions.json", FileAccess.READ)
	if file == null:
		error_message = "Não foi possível abrir o banco de perguntas."
		return false
	var data = JSON.parse_string(file.get_as_text())
	if not data is Array or data.is_empty():
		error_message = "O banco de perguntas está vazio ou inválido."
		return false
	var seen := {}
	for question in data:
		if not question is Dictionary:
			return false
		for key in ["id", "prompt", "sentence", "options", "answer", "hint", "explanation", "topic"]:
			if not question.has(key):
				error_message = "Pergunta sem campo obrigatório: " + key
				return false
		if seen.has(question.id) or question.options.size() != 3 or question.options.count(question.answer) != 1:
			error_message = "ID repetido ou alternativas inválidas: " + str(question.id)
			return false
		var unique := {}
		for option in question.options:
			unique[option] = true
		if unique.size() != 3:
			return false
		seen[question.id] = true
	questions = data
	return true

func next_question() -> Dictionary:
	if bag.is_empty():
		bag = questions.duplicate(true)
		bag.shuffle()
		if bag.size() > 1 and str(bag.back().id) == last_id:
			var first = bag[0]
			bag[0] = bag[bag.size() - 1]
			bag[bag.size() - 1] = first
	var question: Dictionary = bag.pop_back()
	last_id = question.id
	question.options.shuffle()
	return question
