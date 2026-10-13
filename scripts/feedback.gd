extends Control

var correct := true
var progress := 0.0
var animation: Tween

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hide()

func show_result(success: bool, hold := 0.9) -> void:
	if animation and animation.is_valid():
		animation.kill()
	correct = success
	progress = 0.0
	modulate.a = 1.0
	show()
	animation = create_tween()
	animation.tween_method(_set_progress, 0.0, 1.0, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	animation.tween_interval(hold)
	animation.tween_property(self, "modulate:a", 0.0, 0.25)
	animation.tween_callback(hide)

func clear() -> void:
	if animation and animation.is_valid():
		animation.kill()
	hide()

func _set_progress(value: float) -> void:
	progress = value
	queue_redraw()

func _draw() -> void:
	var center := Vector2(size.x * 0.46, size.y * 0.40)
	var radius := 56.0 * maxf(progress, 0.01)
	var color := Color("58eda2") if correct else Color("ff5d66")
	draw_circle(center, radius + 10, Color(0.035, 0.09, 0.09, 0.87))
	draw_circle(center, radius, Color(color, 0.12))
	draw_arc(center, radius, -PI / 2, -PI / 2 + TAU * minf(progress, 1), 64, color, 3, true)
	var points: PackedVector2Array
	if correct:
		points = PackedVector2Array([Vector2(-26,0), Vector2(-7,19), Vector2(28,-20)])
	else:
		points = PackedVector2Array([Vector2(-21,-21), Vector2(21,21)])
	for i in range(points.size() - 1):
		draw_line(center + points[i] * progress, center + points[i+1] * progress, color, 8, true)
	if not correct:
		draw_line(center + Vector2(21,-21) * progress, center + Vector2(-21,21) * progress, color, 8, true)
