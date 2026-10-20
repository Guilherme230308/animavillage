class_name RainGround
extends Node2D
## Poças, bueiros e o círculo do raio, no chão do cenário.

var puddles: Array = []
var drains: Array = []
var bolt_pos := Vector2.INF
var bolt_r := 42.0
var bolt_k := 0.0


func _ready() -> void:
	z_index = -5


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	for pud: Dictionary in puddles:
		var c: Vector2 = pud["center"]
		var r := float(pud["radius"])
		draw_circle(c, r, Color(0.06, 0.28, 0.30, 0.92))
		draw_circle(c, maxf(r - 2.0, r * 0.72), Color(0.18, 0.58, 0.56, 0.78))
		var shine := clampf(r * 0.16, 1.2, 3.0)
		draw_circle(c + Vector2(-r * 0.22, -r * 0.18), shine, Color(0.78, 0.95, 0.90, 0.72))
	for d: Dictionary in drains:
		var p: Vector2 = d["pos"]
		var sealed := bool(d["sealed"])
		draw_rect(Rect2(p - Vector2(8, 5), Vector2(16, 10)), Color(0.05, 0.06, 0.07, 0.9))
		if sealed:
			draw_rect(Rect2(p - Vector2(7, 4), Vector2(14, 8)), Color(0.45, 0.32, 0.18, 0.95))
			draw_line(p + Vector2(-5, 0), p + Vector2(5, 0), Color(0.25, 0.16, 0.08), 1.5)
		else:
			for i in 3:
				var y := -3.0 + float(i) * 3.0
				draw_line(p + Vector2(-6, y), p + Vector2(6, y), Color(0.55, 0.62, 0.68), 1.2)
	if bolt_pos != Vector2.INF:
		var pulse := 0.55 + 0.45 * absf(sin(bolt_k * PI * 6.0))
		draw_circle(bolt_pos, bolt_r, Color(1.0, 0.92, 0.55, 0.16 * pulse))
		draw_arc(bolt_pos, bolt_r, 0.0, TAU, 28, Color(1.0, 0.85, 0.25, 0.9 * pulse), 2.0)
		draw_arc(bolt_pos, bolt_r * 0.55, 0.0, TAU, 20, Color(1.0, 0.95, 0.6, 0.45 * pulse), 1.2)
