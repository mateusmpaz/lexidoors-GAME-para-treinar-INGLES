extends CharacterBody3D

var camera: Camera3D
var enabled := false
var falling := false
var back_limit := 9.2
var testing_input := false
var sensitivity := 0.0024
var pitch := 0.0
var walk_clock := 0.0

func _ready() -> void:
	var collision := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.28
	capsule.height = 1.75
	collision.shape = capsule
	collision.position.y = 0.88
	add_child(collision)
	camera = Camera3D.new()
	camera.position.y = 1.7
	camera.fov = 76
	camera.near = 0.05
	add_child(camera)
	camera.make_current()

func reset_position() -> void:
	falling = false
	back_limit = 9.2
	position = Vector3(0, 0.08, 4.8)
	rotation = Vector3.ZERO
	pitch = 0.0
	camera.rotation = Vector3.ZERO
	camera.position = Vector3(0, 1.7, 0)
	velocity = Vector3.ZERO

func _unhandled_input(event: InputEvent) -> void:
	if enabled and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and event is InputEventMouseMotion:
		rotation.y -= event.relative.x * sensitivity
		pitch = clampf(pitch - event.relative.y * sensitivity, -1.15, 1.15)
		camera.rotation.x = pitch

func _physics_process(delta: float) -> void:
	if not enabled:
		return
	var axis := Vector2.ZERO
	if not falling and (Input.mouse_mode == Input.MOUSE_MODE_CAPTURED or testing_input):
		axis = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := (transform.basis * Vector3(axis.x, 0, axis.y)).normalized()
	velocity.x = move_toward(velocity.x, direction.x * 4.2, delta * 24)
	velocity.z = move_toward(velocity.z, direction.z * 4.2, delta * 24)
	velocity.y -= 18 * delta
	if is_on_floor():
		velocity.y = 0
	move_and_slide()
	position.z = minf(position.z, back_limit)
	if axis.length() > 0.1 and is_on_floor():
		walk_clock += delta * 9
		camera.position.y = lerpf(camera.position.y, 1.7 + sin(walk_clock) * 0.022, delta * 12)
	else:
		camera.position.y = lerpf(camera.position.y, 1.7, delta * 12)
