extends Node3D

const PlayerScript = preload("res://scripts/player.gd")
const DoorScript = preload("res://scripts/door.gd")
const TeacherScript = preload("res://scripts/teacher.gd")
const QuizBank = preload("res://scripts/quiz_bank.gd")
const RoomScript = preload("res://scripts/room.gd")
const FeedbackScript = preload("res://scripts/feedback.gd")
const ROOM_COUNT := 100

const SoundScript = preload("res://scripts/sound.gd")
const CREAM := Color("f5eddb")
const MUTED := Color("a8bebd")
const GOLD := Color("edc17c")
const TEAL := Color("89d7c0")

enum Mode { MENU, PLAYING, TRANSITION, FAILED, PAUSED, COMPLETE }
var rooms: Dictionary = {}
var active_room: Node3D
var run_questions: Array = []
var feedback: Control
var completion_panel: PanelContainer
var completion_copy: Label
var result_heading: Label
var teacher_panel: PanelContainer
var mode := Mode.MENU
var bank = QuizBank.new()
var player: CharacterBody3D
var doors: Array = []
var question: Dictionary = {}
var streak := 0
var best := 0
var attempts := 0
var hints := 0
var hint_used := false
var focused := -1
var history: Array = []
var testing := false
var settings_path := ""
var ui: Control
var hud: Control
var menu: PanelContainer
var pause_panel: PanelContainer
var failure_panel: PanelContainer
var fade: ColorRect
var dim: ColorRect
var teacher: Control
var crosshair: Label
var interaction: Label
var topic_label: Label
var prompt_label: Label
var sentence_label: Label
var speech_label: Label
var streak_label: Label
var best_label: Label
var room_label: Label
var result_title: Label
var result_copy: Label
var menu_record: Label
var hint_button: Button
var sound: AudioStreamPlayer
var sensitivity := 1.0
var volume := 0.65

func _ready() -> void:
	testing = "--self-test" in OS.get_cmdline_user_args() or "--physics-test" in OS.get_cmdline_user_args() or "--layout-test" in OS.get_cmdline_user_args()
	_setup_input()
	_load_settings()
	_build_environment()
	player = PlayerScript.new()
	add_child(player)
	player.sensitivity = 0.0024 * sensitivity
	player.testing_input = testing
	player.reset_position()
	sound = SoundScript.new()
	add_child(sound)
	sound.volume_db = linear_to_db(maxf(volume, 0.001))
	_build_ui()
	if not bank.load_bank() or bank.questions.size() < ROOM_COUNT:
		result_title.text = "Não foi possível iniciar"
		result_copy.text = bank.error_message
		menu.hide()
		failure_panel.show()
		return
	_show_menu()
	if "--physics-test" in OS.get_cmdline_user_args():
		_run_physics_test.call_deferred()
	elif "--layout-test" in OS.get_cmdline_user_args():
		_run_layout_test.call_deferred()
	elif testing:
		_run_self_test.call_deferred()
	elif "--capture-game" in OS.get_cmdline_user_args():
		_start_run()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if "--capture-failure" in OS.get_cmdline_user_args():
		_capture_failure.call_deferred()
	if "--capture-door" in OS.get_cmdline_user_args():
		_capture_door.call_deferred()
	if "--capture-win" in OS.get_cmdline_user_args():
		_start_run()
		streak = ROOM_COUNT
		_complete_game()
	if "--capture-check" in OS.get_cmdline_user_args():
		_capture_feedback.call_deferred(true)
	if "--capture-cross" in OS.get_cmdline_user_args():
		_capture_feedback.call_deferred(false)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--screenshot="):
			_capture.call_deferred(arg.trim_prefix("--screenshot="))

func _setup_input() -> void:
	var mapping := {"move_forward": KEY_W, "move_back": KEY_S, "move_left": KEY_A, "move_right": KEY_D, "interact": KEY_E, "hint": KEY_Q}
	for action in mapping:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		var event := InputEventKey.new()
		event.physical_keycode = mapping[action]
		InputMap.action_add_event(action, event)

func _load_settings() -> void:
	if testing:
		return
	var folder := ProjectSettings.globalize_path("res://.user-data") if OS.has_feature("editor") else OS.get_executable_path().get_base_dir().path_join("user-data")
	DirAccess.make_dir_recursive_absolute(folder)
	settings_path = folder.path_join("settings.cfg")
	var config := ConfigFile.new()
	if config.load(settings_path) == OK:
		best = maxi(0, int(config.get_value("progress", "best", 0)))
		sensitivity = clampf(float(config.get_value("settings", "sensitivity", 1)), 0.25, 2.5)
		volume = clampf(float(config.get_value("settings", "volume", 0.65)), 0, 1)

func _save_settings() -> void:
	if testing or settings_path.is_empty() or _is_capture():
		return
	var config := ConfigFile.new()
	config.set_value("progress", "best", best)
	config.set_value("settings", "sensitivity", sensitivity)
	config.set_value("settings", "volume", volume)
	var status := config.save(settings_path)
	if status != OK:
		push_warning("Não foi possível salvar configurações: " + str(status))

func _build_environment() -> void:
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("101c26")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("adc0cb")
	env.ambient_light_energy = 0.62
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.environment = env
	add_child(environment)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-65, -20, 0)
	fill.light_color = Color("b7d9e5")
	fill.light_energy = 0.6
	add_child(fill)

func _spawn_room(number: int) -> Node3D:
	var room = RoomScript.new()
	room.first_room = number == 0
	room.position.z = -number * RoomScript.SPACING
	add_child(room)
	rooms[number] = room
	for i in 3:
		var text: String = ["learn", "explore", "discover"][i]
		if not run_questions.is_empty() and number < ROOM_COUNT:
			text = str(run_questions[number].options[i])
		elif number == ROOM_COUNT:
			text = ["YOU", "DID", "IT!"][i]
		room.doors[i].reset(text)
	return room

func _reset_rooms() -> void:
	for room in rooms.values():
		remove_child(room)
		room.queue_free()
	rooms.clear()
	active_room = _spawn_room(0)
	doors = active_room.doors
	_spawn_room(1)

func _promote_room() -> void:
	active_room = rooms[streak]
	doors = active_room.doors
	_spawn_room(streak + 1)
	# Mantemos só a sala anterior, a atual e a seguinte.
	for number in rooms.keys():
		if number < streak - 1:
			var discarded: Node3D = rooms[number]
			remove_child(discarded)
			discarded.queue_free()
			rooms.erase(number)
	# Limite de retorno: nunca é possível caminhar até uma sala já descarregada.
	player.back_limit = -float(streak - 1) * RoomScript.SPACING + 9.2

func _style(color: Color, radius := 16, border := Color.TRANSPARENT) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(radius)
	box.border_color = border
	box.set_border_width_all(1)
	box.content_margin_left = 24
	box.content_margin_right = 24
	box.content_margin_top = 22
	box.content_margin_bottom = 22
	return box

func _label(text: String, font_size := 18, color := CREAM) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func _wrapped(text: String, font_size := 18, color := CREAM) -> Label:
	var label := _label(text, font_size, color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label

func _button(text: String, callback: Callable, primary := false) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 46
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_stylebox_override("normal", _style(GOLD if primary else Color("23484d"), 9, Color("54716b")))
	button.add_theme_stylebox_override("hover", _style(Color("f5d8a7") if primary else Color("37645e"), 9, GOLD))
	button.add_theme_stylebox_override("pressed", _style(Color("caa467") if primary else Color("1b3c40"), 9))
	button.add_theme_stylebox_override("focus", _style(Color(0,0,0,0), 9, CREAM))
	button.add_theme_stylebox_override("disabled", _style(Color("263e43"), 9))
	button.add_theme_color_override("font_color", Color("203338") if primary else CREAM)
	button.add_theme_color_override("font_hover_color", Color("203338") if primary else CREAM)
	button.add_theme_color_override("font_pressed_color", Color("203338") if primary else CREAM)
	button.add_theme_font_size_override("font_size", 17)
	button.pressed.connect(callback)
	return button

func _panel(parent: Control, pos: Vector2, dimensions: Vector2, color := Color("122d35")) -> PanelContainer:
	var panel := PanelContainer.new()
	parent.add_child(panel)
	panel.position = pos
	panel.size = dimensions
	panel.add_theme_stylebox_override("panel", _style(color, 18, Color("486366")))
	return panel

func _column(parent: Control, separation := 12) -> VBoxContainer:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", separation)
	parent.add_child(column)
	return column

func _spacer(parent: Control, height: float) -> void:
	var space := Control.new()
	space.custom_minimum_size.y = height
	parent.add_child(space)

func _build_ui() -> void:
	var canvas := CanvasLayer.new()
	add_child(canvas)
	ui = Control.new()
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(ui)
	var theme := Theme.new()
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Segoe UI", "Arial"])
	theme.default_font = font
	theme.default_font_size = 18
	ui.theme = theme
	dim = ColorRect.new()
	dim.color = Color(0.015, 0.035, 0.045, 0.52)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(dim)
	hud = Control.new()
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(hud)
	var brand := _label("LEXI / DOORS", 25, CREAM)
	brand.position = Vector2(30, 25)
	hud.add_child(brand)
	room_label = _label("SALA 01  /  INGLÊS EM JOGO", 13, GOLD)
	room_label.position = Vector2(31, 62)
	hud.add_child(room_label)
	var instructions := _label("W A S D   mover     •     MOUSE   olhar     •     E   abrir\nQ   dica     •     TAB   liberar mouse     •     ESC   pausa", 14, CREAM)
	hud.add_child(instructions)
	instructions.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	instructions.offset_left = 30
	instructions.offset_right = 650
	instructions.offset_top = -76
	instructions.offset_bottom = -24
	var panel := _panel(hud, Vector2(-354, 24), Vector2(330, 580), Color(0.047, 0.13, 0.16, 0.97))
	teacher_panel = panel
	panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	panel.offset_left = -354
	panel.offset_right = -24
	panel.offset_top = 24
	panel.offset_bottom = 604
	var column := _column(panel, 12)
	var heading := HBoxContainer.new()
	column.add_child(heading)
	var avatar := TeacherScript.new()
	avatar.custom_minimum_size = Vector2(104, 110)
	teacher = avatar
	heading.add_child(avatar)
	var names := _column(heading, 5)
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_spacer(names, 17)
	names.add_child(_label("SEU PROFESSOR", 11, GOLD))
	names.add_child(_label("Prof. Atlas", 24, CREAM))
	names.add_child(_label("Aprenda a cada porta.", 12, MUTED))
	var line := HSeparator.new()
	line.modulate = Color("54716b")
	column.add_child(line)
	topic_label = _label("PRESENTE SIMPLES", 11, TEAL)
	column.add_child(topic_label)
	prompt_label = _wrapped("Complete a frase", 18, MUTED)
	column.add_child(prompt_label)
	sentence_label = _wrapped("She ___ to school\nevery day.", 27, CREAM)
	sentence_label.custom_minimum_size.y = 83
	column.add_child(sentence_label)
	var speech_box := PanelContainer.new()
	speech_box.add_theme_stylebox_override("panel", _style(Color("1d3c43"), 10))
	column.add_child(speech_box)
	speech_label = _wrapped("Leia com calma. A resposta certa abre o próximo caminho.", 15, MUTED)
	speech_label.custom_minimum_size.y = 65
	speech_box.add_child(speech_label)
	hint_button = _button("Q   Pedir uma dica", _show_hint)
	column.add_child(hint_button)
	var stats := HBoxContainer.new()
	stats.add_theme_constant_override("separation", 30)
	column.add_child(stats)
	var left := _column(stats, 1)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_child(_label("SEQUÊNCIA", 11, MUTED))
	streak_label = _label("00", 32, TEAL)
	left.add_child(streak_label)
	var right := _column(stats, 1)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_child(_label("RECORDE", 11, MUTED))
	best_label = _label("00", 32, GOLD)
	right.add_child(best_label)
	crosshair = _label("+", 24, Color(1,1,1,0.8))
	hud.add_child(crosshair)
	crosshair.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	crosshair.offset_left = -7
	crosshair.offset_right = 15
	crosshair.offset_top = -17
	crosshair.offset_bottom = 17
	interaction = _label("Escolha uma porta e aproxime-se", 18, CREAM)
	interaction.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hud.add_child(interaction)
	interaction.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	interaction.offset_left = -310
	interaction.offset_right = 310
	interaction.offset_top = -126
	interaction.offset_bottom = -86
	# Menu inicial; o salão continua visível ao fundo.
	menu = _panel(ui, Vector2(58, 58), Vector2(476, 628), Color(0.04,0.105,0.13,0.97))
	var menu_col := _column(menu, 12)
	menu_col.add_child(_label("UM DESAFIO ATRÁS DE CADA PORTA", 12, GOLD))
	_spacer(menu_col, 10)
	menu_col.add_child(_label("LEXI\nDOORS", 60, CREAM))
	menu_col.add_child(_wrapped("Seu inglês abre caminhos.", 24, TEAL))
	menu_col.add_child(_wrapped("Três portas. Uma resposta. Entre na certa para avançar — e aprenda com cada tentativa.", 18, MUTED))
	_spacer(menu_col, 8)
	menu_col.add_child(_button("Entrar no desafio   →", _start_run, true))
	menu_col.add_child(_button("Ajustes e controles", _open_settings))
	menu_col.add_child(_button("Sair", _quit))
	menu_record = _label("RECORDE PESSOAL  /  00", 12, GOLD)
	menu_col.add_child(menu_record)
	menu_col.add_child(_label("VERSÃO 0.2   •   100 SALAS   •   OFFLINE", 10, MUTED))
	# Pausa e configurações em uma única tela.
	pause_panel = _panel(ui, Vector2.ZERO, Vector2(440, 520))
	pause_panel.set_anchors_preset(Control.PRESET_CENTER)
	pause_panel.offset_left = -220
	pause_panel.offset_right = 220
	pause_panel.offset_top = -260
	pause_panel.offset_bottom = 260
	var pause_col := _column(pause_panel, 14)
	pause_col.add_child(_label("UMA PEQUENA PAUSA", 12, GOLD))
	pause_col.add_child(_label("No seu ritmo.", 34))
	pause_col.add_child(_label("Sensibilidade do mouse", 16, MUTED))
	var mouse_slider := HSlider.new()
	mouse_slider.min_value = 0.25
	mouse_slider.max_value = 2.5
	mouse_slider.step = 0.05
	mouse_slider.value = sensitivity
	mouse_slider.custom_minimum_size.y = 28
	mouse_slider.value_changed.connect(func(value: float):
		sensitivity = value
		player.sensitivity = 0.0024 * value
	)
	pause_col.add_child(mouse_slider)
	pause_col.add_child(_label("Volume dos efeitos", 16, MUTED))
	var volume_slider := HSlider.new()
	volume_slider.min_value = 0
	volume_slider.max_value = 1
	volume_slider.step = 0.05
	volume_slider.value = volume
	volume_slider.custom_minimum_size.y = 28
	volume_slider.value_changed.connect(func(value: float):
		volume = value
		sound.volume_db = linear_to_db(maxf(value, 0.001))
	)
	pause_col.add_child(volume_slider)
	pause_col.add_child(_wrapped("WASD: andar  •  Mouse: olhar\nE: abrir porta  •  Q: dica\nTab: cursor livre  •  Esc: pausa\nF11: alternar tela cheia", 16, MUTED))
	pause_col.add_child(_button("Voltar", _resume, true))
	pause_col.add_child(_button("Menu principal", _show_menu))
	# Resultado ocupa a esquerda, preservando o professor à direita.
	failure_panel = _panel(ui, Vector2(64, 172), Vector2(520, 440))
	var result_col := _column(failure_panel, 18)
	result_heading = _label("TENTATIVA ENCERRADA", 12, GOLD)
	result_col.add_child(result_heading)
	result_title = _label("Uma porta.\nUma nova lição.", 38)
	result_col.add_child(result_title)
	result_copy = _wrapped("", 18, MUTED)
	result_col.add_child(result_copy)
	result_col.add_child(_button("Tentar novamente   →", _start_run, true))
	result_col.add_child(_button("Voltar ao menu", _show_menu))
	fade = ColorRect.new()
	fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade.color = Color(0.035,0.06,0.07,0)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(fade)
	feedback = FeedbackScript.new()
	ui.add_child(feedback)
	completion_panel = _panel(ui, Vector2(64, 172), Vector2(530, 460))
	var win_col := _column(completion_panel, 18)
	win_col.add_child(_label("100 / 100   •   DESAFIO CONCLUÍDO", 13, TEAL))
	win_col.add_child(_label("Parabéns!", 48, TEAL))
	win_col.add_child(_wrapped("Você completou o jogo.", 28, CREAM))
	completion_copy = _wrapped("", 18, MUTED)
	win_col.add_child(completion_copy)
	win_col.add_child(_button("Jogar novamente   →", _start_run, true))
	win_col.add_child(_button("Voltar ao menu", _show_menu))
	completion_panel.hide()
	pause_panel.hide()
	failure_panel.hide()
	get_viewport().size_changed.connect(_on_resize)
	_on_resize()

func _on_resize() -> void:
	# Canvas de referência mantém os elementos proporcionais; mínimo prático 960x600.
	DisplayServer.window_set_min_size(Vector2i(960,600))

func _show_menu() -> void:
	_save_settings()
	mode = Mode.MENU
	player.enabled = false
	player.reset_position()
	run_questions.clear()
	_reset_rooms()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	menu.show()
	hud.hide()
	dim.show()
	pause_panel.hide()
	failure_panel.hide()
	completion_panel.hide()
	feedback.clear()
	fade.color.a = 0
	menu_record.text = "RECORDE PESSOAL  /  %02d" % best

func _start_run() -> void:
	streak = 0
	attempts = 0
	hints = 0
	history.clear()
	run_questions = bank.questions.duplicate(true)
	run_questions.shuffle()
	run_questions.resize(ROOM_COUNT)
	for item in run_questions:
		item.options.shuffle()
	_reset_rooms()
	player.reset_position()
	menu.hide()
	pause_panel.hide()
	failure_panel.hide()
	completion_panel.hide()
	feedback.clear()
	dim.hide()
	hud.show()
	_next_round()

func _next_round() -> void:
	question = run_questions[streak]
	hint_used = false
	focused = -1
	player.enabled = true
	mode = Mode.PLAYING
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	teacher.mood = "idle"
	topic_label.text = question.topic
	prompt_label.text = question.prompt
	sentence_label.text = question.sentence
	speech_label.text = "Abra uma porta e atravesse. O próximo salão está logo à frente."
	hint_button.text = "Q   Pedir uma dica"
	hint_button.disabled = false
	streak_label.text = "%02d" % streak
	best_label.text = "%02d" % best
	room_label.text = "SALA %03d / 100  •  INGLÊS EM JOGO" % (streak + 1)
	fade.color.a = 0
	crosshair.show()
	interaction.show()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F11:
			var fullscreen := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if fullscreen else DisplayServer.WINDOW_MODE_FULLSCREEN)
		elif event.keycode == KEY_ESCAPE:
			if mode == Mode.PLAYING:
				_pause()
			elif mode == Mode.PAUSED:
				_resume()
		elif event.keycode == KEY_TAB and mode == Mode.PLAYING:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED
		elif event.is_action_pressed("hint") and mode == Mode.PLAYING:
			_show_hint()
		elif event.is_action_pressed("interact") and mode == Mode.PLAYING and focused >= 0:
			if not doors[focused].opened:
				doors[focused].open()
				sound.play_cue("door")

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and mode == Mode.PLAYING and not testing and not _is_capture():
		_pause()

func _process(_delta: float) -> void:
	if mode != Mode.PLAYING:
		return
	focused = -1
	var forward: Vector3 = -player.camera.global_transform.basis.z
	for i in 3:
		var door = doors[i]
		var to_door: Vector3 = door.global_position + Vector3(0,1.7,0) - player.camera.global_position
		var near := to_door.length() < 3.2 and forward.dot(to_door.normalized()) > 0.55
		door.set_focus(near)
		if near:
			focused = i
		if door.opened and player.position.z < door.global_position.z - 0.55 and absf(player.position.x - door.global_position.x) < 1.3:
			_resolve_door(i)
			return
	if Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
		interaction.text = "TAB   Voltar a olhar e andar"
		crosshair.hide()
	elif focused >= 0:
		interaction.text = "Atravesse para escolher: " + doors[focused].answer if doors[focused].opened else "E   Abrir a porta: " + doors[focused].answer
		crosshair.show()
	else:
		interaction.text = "Escolha uma porta e aproxime-se"
		crosshair.show()

func _show_hint() -> void:
	if mode != Mode.PLAYING or hint_used:
		return
	hint_used = true
	hints += 1
	teacher.mood = "think"
	speech_label.text = question.hint
	hint_button.text = "Dica recebida • sem penalidade"
	hint_button.disabled = true
	sound.play_cue("hint")

func _resolve_door(index: int) -> void:
	if mode != Mode.PLAYING:
		return
	mode = Mode.TRANSITION
	interaction.hide()
	crosshair.hide()
	attempts += 1
	var chosen_answer: String = doors[index].answer
	var correct: bool = chosen_answer == question.answer
	history.append({"id": question.id, "answer": chosen_answer, "correct": correct, "hint": hint_used})
	feedback.show_result(correct)
	if correct:
		streak += 1
		best = maxi(best, streak)
		_save_settings()
		streak_label.text = "%02d" % streak
		best_label.text = "%02d" % best
		teacher.mood = "happy"
		speech_label.text = "Correto! Continue andando: a próxima sala já está à sua frente."
		sound.play_cue("success")
		if streak >= ROOM_COUNT:
			player.enabled = false
			if not testing:
				await get_tree().create_timer(1.2).timeout
			_complete_game()
			return
		# Não há reposicionamento ou tela preta no acerto.
		_promote_room()
		if not testing:
			await get_tree().create_timer(0.85).timeout
		_next_round()
	else:
		teacher.mood = "wrong"
		speech_label.text = "A resposta correta é “%s”.\n\n%s" % [question.answer, question.explanation]
		hint_button.disabled = true
		hint_button.text = "Cada erro também ensina"
		sound.play_cue("failure")
		active_room.collapse(index)
		player.falling = true
		player.enabled = true
		player.velocity = Vector3(0, -1.5, 0)
		if not testing:
			var fall := create_tween()
			fall.tween_property(player.camera, "rotation:z", 0.18, 0.65)
			fall.tween_property(fade, "color:a", 1.0, 0.45)
			await fall.finished
		var previous_streak := streak
		streak = 0
		streak_label.text = "00"
		mode = Mode.FAILED
		player.enabled = false
		player.reset_position()
		player.position.z = active_room.position.z + 4.8
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		dim.show()
		result_title.text = "Uma porta.\nUma nova lição."
		result_copy.text = "Você escolheu “%s”.\n\nSalas concluídas: %d / 100\nSeu recorde: %d\n\nLeia a correção e tente novamente." % [chosen_answer, previous_streak, best]
		failure_panel.show()
		fade.color.a = 0

func _complete_game() -> void:
	mode = Mode.COMPLETE
	player.enabled = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	teacher.mood = "happy"
	topic_label.text = "DESAFIO CONCLUÍDO"
	prompt_label.text = "Todas as portas foram abertas."
	sentence_label.text = "You did it!"
	speech_label.text = "Você atravessou as 100 salas! Continue praticando: cada palavra abre um novo caminho."
	hint_button.disabled = true
	hint_button.text = "Desafio concluído!"
	room_label.text = "100 / 100  •  JOGO COMPLETO"
	streak_label.text = "100"
	best = maxi(best, ROOM_COUNT)
	best_label.text = "%02d" % best
	_save_settings()
	crosshair.hide()
	interaction.hide()
	dim.show()
	completion_copy.text = "100 salas. 100 respostas corretas.\n\nDicas utilizadas: %d\nRecorde pessoal: %d\n\nSeu inglês abriu todos os caminhos." % [hints, best]
	completion_panel.show()

func _pause() -> void:
	mode = Mode.PAUSED
	player.enabled = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	pause_panel.show()
	dim.show()

func _open_settings() -> void:
	menu.hide()
	_pause()

func _resume() -> void:
	_save_settings()
	if not hud.visible:
		_show_menu()
		return
	mode = Mode.PLAYING
	player.enabled = true
	pause_panel.hide()
	dim.hide()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _quit() -> void:
	_save_settings()
	get_tree().quit()

func _capture(path: String) -> void:
	await get_tree().create_timer(3.0).timeout
	await RenderingServer.frame_post_draw
	var picture := get_viewport().get_texture().get_image()
	var result := picture.save_png(path)
	print("SCREENSHOT: ", result, " ", path)
	get_tree().quit()

func _capture_failure() -> void:
	_start_run()
	await get_tree().create_timer(0.3).timeout
	for i in 3:
		if doors[i].answer != question.answer:
			_resolve_door(i)
			return


func _is_capture() -> bool:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-") or arg.begins_with("--screenshot="):
			return true
	return false

func _capture_door() -> void:
	_start_run()
	player.position = Vector3(0,0.08,-4.4)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	doors[1].open()

func _capture_feedback(success: bool) -> void:
	_start_run()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	await get_tree().create_timer(2.3).timeout
	feedback.show_result(success, 2.0)

func _test_finish(errors: Array[String], label: String) -> void:
	if errors.is_empty():
		print(label + "_PASS")
		get_tree().quit(0)
	else:
		for error in errors:
			push_error(error)
		get_tree().quit(1)

func _run_self_test() -> void:
	var errors: Array[String] = []
	if bank.questions.size() < ROOM_COUNT:
		errors.append("Banco com menos de 100 perguntas.")
	_start_run()
	var ids := {}
	for item in run_questions:
		ids[item.id] = true
	if ids.size() != ROOM_COUNT:
		errors.append("Campanha repete perguntas.")
	_show_hint()
	_show_hint()
	if hints != 1:
		errors.append("Dica duplicada.")
	_pause()
	if player.enabled or mode != Mode.PAUSED:
		errors.append("Pausa incorreta.")
	_resume()
	# Percorre as cem respostas, exercitando promoção de salas e conclusão.
	for number in ROOM_COUNT:
		var correct_index: int = question.options.find(question.answer)
		player.position = doors[correct_index].global_position + Vector3(0,0.08,-0.6)
		var before := player.position
		await _resolve_door(correct_index)
		if player.position.distance_to(before) > 0.01:
			errors.append("Acerto reposicionou o jogador na sala " + str(number + 1))
		if streak != number + 1:
			errors.append("Contagem de salas incorreta.")
		if rooms.size() > 3:
			errors.append("Salas antigas não foram descarregadas.")
		await get_tree().process_frame
	if mode != Mode.COMPLETE or not completion_panel.visible or player.enabled:
		errors.append("A sala 100 não concluiu a campanha.")
	var count := history.size()
	await _resolve_door(0)
	if history.size() != count:
		errors.append("Conclusão aceitou resposta duplicada.")
	_start_run()
	if streak != 0 or mode != Mode.PLAYING or completion_panel.visible:
		errors.append("Reinício após conclusão incorreto.")
	var wrong_index := 0 if doors[0].answer != question.answer else 1
	await _resolve_door(wrong_index)
	if mode != Mode.FAILED or streak != 0 or best != ROOM_COUNT:
		errors.append("Derrota não preserva recorde.")
	if not speech_label.text.contains(question.answer):
		errors.append("Correção sem gabarito.")
	_start_run()
	if player.falling or not player.enabled or rooms.size() != 2:
		errors.append("Reinício após queda incorreto.")
	_show_menu()
	await get_tree().process_frame
	_test_finish(errors, "CAMPAIGN_TEST_100_ROOMS")

func _run_physics_test() -> void:
	var errors: Array[String] = []
	_start_run()
	for correct in [true, true, false]:
		var chosen := 0
		for i in 3:
			if (doors[i].answer == question.answer) == correct:
				chosen = i
				break
		var selected = doors[chosen]
		var door_position: Vector3 = selected.global_position
		player.position = door_position + Vector3(0,0.1,2.2)
		Input.action_press("move_forward")
		await get_tree().create_timer(0.9).timeout
		Input.action_release("move_forward")
		if player.position.z < door_position.z + 0.3 or player.position.z > door_position.z + 1.4:
			errors.append("Colisão ou movimento incorreto.")
		if focused != chosen:
			errors.append("Foco não identifica a porta.")
		var key := InputEventKey.new()
		key.physical_keycode = KEY_E
		key.keycode = KEY_E
		key.pressed = true
		Input.parse_input_event(key)
		await get_tree().create_timer(0.65).timeout
		if not selected.opened:
			errors.append("E não abriu a porta.")
		var previous := streak
		Input.action_press("move_forward")
		await get_tree().create_timer(0.65).timeout
		Input.action_release("move_forward")
		if correct:
			if streak != previous + 1 or mode != Mode.PLAYING or player.position.z > door_position.z:
				errors.append("Travessia correta não mantém continuidade.")
			if player.position.y < -0.1:
				errors.append("Passagem correta contém buraco no chão.")
		else:
			if streak != 0 or mode != Mode.FAILED:
				errors.append("Passagem errada não dispara derrota.")
	# Queda física isolada: a plataforma perde colisão e o corpo desce.
	_start_run()
	player.position = Vector3(0,0.1,-7.8)
	mode = Mode.TRANSITION
	active_room.collapse(1)
	player.falling = true
	await get_tree().create_timer(0.6).timeout
	if player.position.y > -1.0:
		errors.append("Alçapão não permite queda física.")
	_test_finish(errors, "PHYSICS_CONTINUITY_AND_TRAP")

func _run_layout_test() -> void:
	var errors: Array[String] = []
	_start_run()
	for number in ROOM_COUNT:
		streak = number
		_next_round()
		player.enabled = false
		for message in ["Leia com calma.", question.hint, "A resposta correta é “%s”.\n\n%s" % [question.answer, question.explanation]]:
			speech_label.text = message
			await get_tree().process_frame
			await get_tree().process_frame
			if teacher_panel.get_global_rect().end.y > ui.size.y - 12:
				errors.append("Painel fora da tela: " + str(question.id))
	_test_finish(errors, "LAYOUT_100_QUESTIONS")
