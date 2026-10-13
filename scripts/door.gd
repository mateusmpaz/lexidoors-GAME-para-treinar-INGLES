extends Node3D

var index := 0
var opened := false
var pivot: Node3D
var blocker: CollisionShape3D
var answer_label: Label3D
var leaf_material: ShaderMaterial
var glow_material: StandardMaterial3D
var lamp: OmniLight3D
var swing: Tween
var answer := ""

func _ready() -> void:
	var stone := material(Color("30434a"))
	var gold := material(Color("aa8655"))
	leaf_material = wood_material(Color("9b6033"))
	glow_material = material(Color("8ecbb8"), true)
	for side in [-1, 1]:
		box(self, Vector3(0.3, 4.7, 0.5), Vector3(side * 1.47, 2.35, 0), stone)
		box(self, Vector3(0.07, 4.35, 0.54), Vector3(side * 1.29, 2.18, 0.01), gold)
	box(self, Vector3(3.22, 0.35, 0.6), Vector3(0, 4.62, 0), stone)
	box(self, Vector3(2.58, 0.07, 0.58), Vector3(0, 4.35, 0.02), gold)
	box(self, Vector3(2.6, 0.08, 0.8), Vector3(0, 0.04, 0.0), gold)
	pivot = Node3D.new()
	pivot.position = Vector3(-1.24, 0, 0)
	add_child(pivot)
	box(pivot, Vector3(2.48, 4.28, 0.18), Vector3(1.24, 2.16, 0), leaf_material)
	var moulding := wood_material(Color("794322"))
	var inset := wood_material(Color("8b502a"))
	for x in [0.22, 2.26]:
		box(pivot, Vector3(0.11, 4.05, 0.045), Vector3(x, 2.15, 0.12), moulding)
	for y in [0.2, 1.48, 2.77, 4.13]:
		box(pivot, Vector3(2.04, 0.11, 0.055), Vector3(1.24, y, 0.13), moulding)
	for x in [0.72, 1.76]:
		for y in [0.84, 2.13, 3.44]:
			box(pivot, Vector3(0.86, 1.02, 0.065), Vector3(x,y,0.125), moulding)
			box(pivot, Vector3(0.72, 0.88, 0.07), Vector3(x,y,0.16), inset)
	box(pivot, Vector3(0.58, 0.42, 0.04), Vector3(1.24, 3.68, 0.24), gold)
	box(pivot, Vector3(0.14, 0.34, 0.06), Vector3(2.2, 2.0, 0.23), gold)
	var knob := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.1
	sphere.height = 0.2
	knob.mesh = sphere
	knob.material_override = gold
	knob.position = Vector3(2.2, 2.0, 0.34)
	pivot.add_child(knob)
	var badge := Label3D.new()
	badge.text = ["I", "II", "III"][index]
	badge.font_size = 46
	badge.pixel_size = 0.008
	badge.position = Vector3(1.24, 3.68, 0.275)
	badge.modulate = Color("302119")
	badge.outline_size = 0
	pivot.add_child(badge)
	box(self, Vector3(2.8, 0.65, 0.15), Vector3(0, 5.17, 0.13), material(Color("102a32")))
	answer_label = Label3D.new()
	answer_label.position = Vector3(0, 5.17, 0.24)
	answer_label.font_size = 84
	answer_label.pixel_size = 0.0052
	answer_label.modulate = Color("fff1d6")
	answer_label.outline_size = 6
	answer_label.outline_modulate = Color("102a32")
	answer_label.no_depth_test = false
	add_child(answer_label)
	box(self, Vector3(2.35, 0.018, 0.035), Vector3(0, 4.9, 0.23), glow_material)
	var body := StaticBody3D.new()
	blocker = CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(2.5, 4.4, 0.3)
	blocker.shape = shape
	blocker.position.y = 2.2
	body.add_child(blocker)
	add_child(body)
	lamp = OmniLight3D.new()
	lamp.position = Vector3(0, 4.5, 1.2)
	lamp.light_color = Color("f5c588")
	lamp.light_energy = 1.3
	lamp.omni_range = 5.5
	add_child(lamp)

func reset(value: String) -> void:
	if swing and swing.is_valid():
		swing.kill()
	answer = value
	answer_label.text = value
	answer_label.font_size = 66 if value.length() > 10 else 84
	opened = false
	pivot.rotation.y = 0
	blocker.set_deferred("disabled", false)
	set_focus(false)

func set_focus(active: bool) -> void:
	leaf_material.set_shader_parameter("highlight", 1.0 if active else 0.0)
	lamp.light_energy = 2.0 if active else 1.3

func open() -> void:
	if opened:
		return
	opened = true
	blocker.set_deferred("disabled", true)
	swing = create_tween()
	swing.tween_property(pivot, "rotation:y", deg_to_rad(100), 0.55).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

static func wood_material(color: Color) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/wood.gdshader")
	mat.set_shader_parameter("wood_tint", color)
	return mat

static func material(color: Color, emissive := false) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.8
	if emissive:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = 1.8
	return mat

static func box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material, solid := false) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var cube := BoxMesh.new()
	cube.size = size
	mesh.mesh = cube
	mesh.material_override = mat
	mesh.position = pos
	parent.add_child(mesh)
	if solid:
		var body := StaticBody3D.new()
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		collision.shape = shape
		body.add_child(collision)
		mesh.add_child(body)
	return mesh
