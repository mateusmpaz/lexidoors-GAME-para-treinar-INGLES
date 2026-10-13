extends Control

var mood := "idle"
var time := 0.0

func _ready() -> void:
	custom_minimum_size = Vector2(104, 106)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(delta: float) -> void:
	time += delta
	queue_redraw()

func _draw() -> void:
	var center := Vector2(size.x / 2, 52 + sin(time * 2.0) * 1.6)
	var teal := Color("4ba49d")
	var ink := Color("193b45")
	var skin := Color("e9b994")
	draw_circle(Vector2(size.x / 2, 55), 48, Color("213f46"))
	draw_arc(Vector2(size.x / 2, 55), 47, -2.7, 1.1, 32, Color("54857f"), 1.5, true)
	# Silhueta original, desenhada em vetores pelo próprio jogo.
	draw_style_box(_rounded(teal, 18), Rect2(center + Vector2(-30, 23), Vector2(60, 38)))
	draw_rect(Rect2(center + Vector2(-8, 12), Vector2(16, 18)), skin)
	draw_circle(center + Vector2(-26, -5), 6, skin)
	draw_circle(center + Vector2(26, -5), 6, skin)
	draw_circle(center + Vector2(0, -9), 29, Color("e1e5d9"))
	draw_style_box(_rounded(skin, 20), Rect2(center + Vector2(-24, -29), Vector2(48, 55)))
	for p in [Vector2(-21,-28), Vector2(-12,-34), Vector2(0,-36), Vector2(13,-33), Vector2(23,-27)]:
		draw_circle(center + p, 10, Color("ecebdd"))
	var blink := fmod(time, 4.8) > 4.64
	for side in [-1.0, 1.0]:
		var eye := center + Vector2(12 * side, -7)
		draw_arc(eye, 10, 0, TAU, 24, ink, 2.2, true)
		if blink:
			draw_line(eye + Vector2(-3, 0), eye + Vector2(3, 0), ink, 2, true)
		else:
			draw_circle(eye + Vector2(0, 0 if mood != "think" else -2), 2.5, ink)
	draw_line(center + Vector2(-2, -8), center + Vector2(2, -8), ink, 2)
	draw_line(center + Vector2(-23, -9), center + Vector2(-28, -13), ink, 2)
	draw_line(center + Vector2(23, -9), center + Vector2(28, -13), ink, 2)
	draw_line(center + Vector2(0, -3), center + Vector2(-2, 5), Color("b17e67"), 2, true)
	if mood == "wrong":
		draw_arc(center + Vector2(0, 20), 7, PI + 0.3, TAU - 0.3, 16, ink, 2, true)
	elif mood == "think":
		draw_line(center + Vector2(-4, 13), center + Vector2(5, 11), ink, 2, true)
	else:
		draw_arc(center + Vector2(0, 9), 8 if mood == "happy" else 6, 0.15, PI - 0.15, 16, ink, 2, true)
	var bow := PackedVector2Array([center + Vector2(-10, 29), center + Vector2(0, 33), center + Vector2(-10, 38)])
	draw_colored_polygon(bow, Color("edbe76"))
	draw_colored_polygon(PackedVector2Array([center + Vector2(10, 29), center + Vector2(0, 33), center + Vector2(10, 38)]), Color("edbe76"))
	draw_circle(center + Vector2(0, 33), 3, Color("fff0c4"))
	if mood == "happy":
		for side in [-1, 1]:
			var point := center + Vector2(side * 40, -25 + sin(time * 7) * 4)
			draw_line(point - Vector2(4, 0), point + Vector2(4, 0), Color("efc67f"), 2, true)
			draw_line(point - Vector2(0, 4), point + Vector2(0, 4), Color("efc67f"), 2, true)

func _rounded(color: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	return style
