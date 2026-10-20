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
		_draw_puddle(pud["center"], float(pud["radius"]))
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
	_draw_bolt()


func _draw_puddle(c: Vector2, r: float) -> void:
	# Mancha irregular, da largura do caminho. 12 colunas por 8 linhas, 1 = água.
	var bits := PackedInt32Array([
		0, 0, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0,
		0, 1, 1, 1, 1, 1, 1, 0, 1, 1, 0, 0,
		1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0,
		1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0,
		0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0,
		0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0,
		0, 0, 0, 1, 1, 1, 1, 1, 1, 0, 0, 0,
		0, 0, 0, 0, 1, 1, 1, 1, 0, 0, 0, 0,
	])
	var w := 12
	var h := 8
	var cell := maxf((r * 2.0) / float(w), 2.0)
	var flip := (int(c.x) + int(c.y)) % 2 == 1
	var origin := c - Vector2(float(w), float(h)) * cell * 0.5
	var dark := Color(0.05, 0.18, 0.48, 0.96)
	var fill := Color(0.42, 0.78, 0.98, 0.96)
	var deep := Color(0.20, 0.52, 0.90, 0.96)
	var shine := Color(0.86, 0.96, 1.0, 0.98)
	for y in h:
		for x in w:
			if bits[y * w + x] == 0:
				continue
			var px := x
			if flip:
				px = w - 1 - x
			var p := origin + Vector2(float(px), float(y)) * cell
			draw_rect(Rect2(p - Vector2(cell, cell) * 0.45, Vector2(cell, cell) * 1.9), dark)
			var col := fill
			if y >= h - 3 or (x + y) % 4 == 0:
				col = deep
			draw_rect(Rect2(p, Vector2(cell, cell)), col)
	var hx := 3
	if flip:
		hx = w - 5
	draw_rect(Rect2(origin + Vector2(float(hx), 2.0) * cell, Vector2(cell, cell)), shine)
	draw_rect(Rect2(origin + Vector2(float(hx + 1), 3.0) * cell, Vector2(cell, cell) * 0.7), shine)


func _draw_bolt() -> void:
	if bolt_pos != Vector2.INF:
		var pulse := 0.55 + 0.45 * absf(sin(bolt_k * PI * 6.0))
		draw_circle(bolt_pos, bolt_r, Color(1.0, 0.92, 0.55, 0.16 * pulse))
		draw_arc(bolt_pos, bolt_r, 0.0, TAU, 28, Color(1.0, 0.85, 0.25, 0.9 * pulse), 2.0)
		draw_arc(bolt_pos, bolt_r * 0.55, 0.0, TAU, 20, Color(1.0, 0.95, 0.6, 0.45 * pulse), 1.2)
