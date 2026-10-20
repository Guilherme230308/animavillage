class_name Minimap
extends Control
## Minimapa no canto inferior direito: caminhos da tela atual, saídas, personagem e destino.
## Clicar/tocar nele manda a personagem andar até o ponto.

signal picked(world_pos: Vector2)

const MAX_SIDE := 200.0
var world_size := Vector2(1, 1)
var player_pos := Vector2.ZERO
var target_pos := Vector2.INF
var exits: Array = []
var title := ""
var _tex: Texture2D
var _t := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP


func set_area(tex: Texture2D, size_world: Vector2, area_exits: Array, area_title: String) -> void:
	_tex = tex
	world_size = size_world
	exits = area_exits
	title = area_title
	var k := MAX_SIDE / maxf(size_world.x, size_world.y)
	custom_minimum_size = (size_world * k).round() + Vector2(12, 34)
	size = custom_minimum_size
	queue_redraw()


func _map_rect() -> Rect2:
	return Rect2(Vector2(6, 28), size - Vector2(12, 34))


func _to_map(p: Vector2) -> Vector2:
	var r := _map_rect()
	return r.position + p / world_size * r.size


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	var pos := Vector2.INF
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		pos = event.position
	elif event is InputEventScreenTouch and event.pressed:
		pos = event.position
	if pos != Vector2.INF:
		var r := _map_rect()
		if r.has_point(pos):
			picked.emit((pos - r.position) / r.size * world_size)
		accept_event()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.07, 0.09, 0.08, 0.86))
	draw_rect(Rect2(Vector2.ZERO, size), Color("e9a15b"), false, 2.0)
	var font := get_theme_default_font()
	draw_string(font, Vector2(8, 19), title, HORIZONTAL_ALIGNMENT_LEFT, size.x - 16, 13, Color("fff1c9"))
	var r := _map_rect()
	if _tex != null:
		draw_texture_rect(_tex, r, false)
	for e: Dictionary in exits:
		var er: Array = e["rect"]
		var a := _to_map(Vector2(float(er[0]), float(er[1])))
		var b := _to_map(Vector2(float(er[0]) + float(er[2]), float(er[1]) + float(er[3])))
		var rr := Rect2(a, (b - a).max(Vector2(4, 4)))
		rr = rr.grow(1.5)
		draw_rect(rr, Color("f08a24"))
		draw_rect(rr, Color(0.25, 0.12, 0.04), false, 1.0)
	if target_pos != Vector2.INF:
		var tp := _to_map(target_pos)
		draw_arc(tp, 4.0 + sin(_t * 6.0) * 1.0, 0, TAU, 16, Color("fff1c9"), 1.5)
	var pp := _to_map(player_pos)
	draw_circle(pp, 5.5, Color(1, 1, 1, 0.9))
	draw_circle(pp, 4.0, Color("e0433a"))
