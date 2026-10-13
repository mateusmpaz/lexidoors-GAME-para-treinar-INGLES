extends Node3D

const DoorScript = preload("res://scripts/door.gd")
const SPACING := 18.0
var first_room := false
var doors: Array = []
var traps: Array = []

func _ready() -> void:
	var stone = DoorScript.material(Color("293d47"))
	var trim = DoorScript.material(Color("40565d"))
	var dark = DoorScript.material(Color("14282f"))
	var brass = DoorScript.material(Color("a58a61"))
	var emissive = DoorScript.material(Color("e9ba73"), true)
	# O piso termina depois dos portais; as paredes mantêm o jogador no salão.
	DoorScript.box(self, Vector3(17, 0.4, 16.2), Vector3(0, -0.2, 1.5), stone, true)
	DoorScript.box(self, Vector3(0.4, 7, 18.2), Vector3(-8.3, 3.5, 1.5), dark, true)
	DoorScript.box(self, Vector3(0.4, 7, 18.2), Vector3(8.3, 3.5, 1.5), dark, true)
	if first_room:
		DoorScript.box(self, Vector3(17, 7, 0.4), Vector3(0, 3.5, 9.8), dark, true)
	DoorScript.box(self, Vector3(17, 0.3, 18), Vector3(0, 6.6, 1.5), dark)
	for row in range(9):
		for col in range(-8, 8, 2):
			var shade := Color("394c52") if (row + col) % 4 == 0 else Color("32464e")
			DoorScript.box(self, Vector3(1.96, 0.025, 1.76), Vector3(col + 1, 0.015, -5.7 + row * 1.8), DoorScript.material(shade))
	# Passadeira central e linhas que conduzem às três opções.
	DoorScript.box(self, Vector3(3.0, 0.025, 15.8), Vector3(0, 0.045, 1.5), DoorScript.material(Color("254b50")))
	for x in [-1.45, 1.45]:
		DoorScript.box(self, Vector3(0.04, 0.03, 15.8), Vector3(x, 0.06, 1.5), brass)
	for x in [-7.1, -2.0, 2.0, 7.1]:
		var width := 2.0 if absf(x) > 7 else 1.4
		DoorScript.box(self, Vector3(width, 6.4, 0.65), Vector3(x, 3.2, -7), stone, true)
	DoorScript.box(self, Vector3(17, 0.8, 0.7), Vector3(0, 6.1, -7), stone, true)
	for i in 3:
		var door = DoorScript.new()
		door.index = i
		door.position = Vector3((i - 1) * 4.3, 0, -7)
		add_child(door)
		doors.append(door)
		_add_trap((i - 1) * 4.3)
		DoorScript.box(self, Vector3(0.85, 0.015, 1.2), Vector3((i - 1) * 4.3, 0.055, -5.1), DoorScript.material(Color("597073")))
	for z in [-5, 1, 7]:
		for side in [-1, 1]:
			DoorScript.box(self, Vector3(0.6, 6.4, 0.7), Vector3(side * 7.8, 3.2, z), trim)
			DoorScript.box(self, Vector3(0.76, 0.24, 0.88), Vector3(side * 7.8, 0.12, z), brass)
			DoorScript.box(self, Vector3(0.16, 1.05, 0.18), Vector3(side * 7.43, 3.6, z), emissive)
			var light := OmniLight3D.new()
			light.position = Vector3(side * 7.0, 3.9, z)
			light.light_color = Color("ffd2a0")
			light.light_energy = 1.5
			light.omni_range = 8
			add_child(light)
		DoorScript.box(self, Vector3(15.5, 0.3, 0.45), Vector3(0, 6.35, z), trim)
	# Pequenos conjuntos de livros nos nichos laterais.
	for side in [-1, 1]:
		for z in [-2, 4]:
			DoorScript.box(self, Vector3(0.8, 2.6, 2.9), Vector3(side * 7.65, 1.3, z), dark)
			for shelf in [0.3, 1.2, 2.1]:
				DoorScript.box(self, Vector3(1.0, 0.09, 3.0), Vector3(side * 7.45, shelf, z), brass)
				for k in 7:
					var colors := [Color("547877"), Color("926b55"), Color("aca078"), Color("47566b")]
					DoorScript.box(self, Vector3(0.62, 0.56 + (k % 3) * 0.07, 0.22), Vector3(side * 7.45, shelf + 0.35, z - 1.1 + k * 0.34), DoorScript.material(colors[k % 4]))

func _add_trap(x: float) -> void:
	var plate := Node3D.new()
	plate.position = Vector3(x, -0.01, -7.5)
	add_child(plate)
	DoorScript.box(plate, Vector3(4.28, 0.22, 1.8), Vector3(0,-0.11,0), DoorScript.material(Color("394c52")), true)
	traps.append(plate)
	# Paredes verticais do poço, invisíveis enquanto o piso está fechado.
	var pit = DoorScript.material(Color("16252c"))
	for side in [-1,1]:
		DoorScript.box(self, Vector3(0.14, 7, 1.8), Vector3(x + side * 2.14,-3.6,-7.5), pit)
	DoorScript.box(self, Vector3(4.28, 7, 0.14), Vector3(x,-3.6,-6.61), pit)
	DoorScript.box(self, Vector3(4.28, 7, 0.14), Vector3(x,-3.6,-8.39), pit)

func collapse(index: int) -> void:
	var plate: Node3D = traps[index]
	for mesh in plate.get_children():
		for body in mesh.get_children():
			if body is StaticBody3D:
				body.collision_layer = 0
	var fall := create_tween().set_parallel(true)
	fall.tween_property(plate, "position:y", -6.0, 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	fall.tween_property(plate, "rotation:x", 0.6, 0.7)
