class_name Minimap
extends Control
## Minimapa no canto inferior direito: caminhos da tela atual, saídas, personagem e destino.
## Clicar/tocar nele manda a personagem andar até o ponto.

## Clicar/tocar no minimapa pequeno pede o mapa em tela cheia.
signal open_requested

var max_side := 200.0
## Falso no mapa em tela cheia (não abre outro mapa).
var interactive := true
## Tamanho dos marcadores (maior no mapa em tela cheia).
var marker_scale := 1.0
var world_size := Vector2(1, 1)
var player_pos := Vector2.ZERO
var target_pos := Vector2.INF
var exits: Array = []
var title := ""
## Marcadores: [posição no mundo, tipo] com tipo "moeda", "arma", "amarelo" ou "vermelho".
var dots: Array = []
## Contagens para a legenda: nesta tela e no nível inteiro.
var counts := {"moeda": 0, "arma": 0, "escorpiao": 0, "moeda_total": 0, "arma_total": 0, "escorpiao_total": 0}
var show_legend := false
const LEGEND_H := 24.0
var _tex: Texture2D
var _t := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP


func set_area(tex: Texture2D, size_world: Vector2, area_exits: Array, area_title: String) -> void:
	_tex = tex
	world_size = size_world
	exits = area_exits
	title = area_title
	var k := max_side / maxf(size_world.x, size_world.y)
	custom_minimum_size = (size_world * k).round() + Vector2(12, 34 + LEGEND_H)
	size = custom_minimum_size
	queue_redraw()


func _map_rect() -> Rect2:
	return Rect2(Vector2(6, 28), size - Vector2(12, 34 + LEGEND_H))


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
	if pos != Vector2.INF and interactive:
		open_requested.emit()
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
	var pulse := 0.5 + 0.5 * sin(_t * 5.0)
	for d: Array in dots:
		_marker(_to_map(d[0]), String(d[1]), pulse)
	if not Rect2(Vector2.ZERO, world_size).has_point(player_pos):
		_legend()
		return
	var pp := _to_map(player_pos)
	draw_circle(pp, 5.5, Color(1, 1, 1, 0.9))
	draw_circle(pp, 4.0, Color("e0433a"))
	_legend()


func _marker(p: Vector2, kind: String, pulse: float = 0.0) -> void:
	draw_set_transform(p, 0.0, Vector2.ONE * marker_scale)
	p = Vector2.ZERO
	var dark := Color(0.05, 0.04, 0.02, 0.9)
	match kind:
		"moeda":
			draw_circle(p, 3.4, dark)
			draw_circle(p, 2.5, Color("ffd23a"))
			draw_circle(p + Vector2(-0.7, -0.7), 0.9, Color("fff3b0"))
		"coracao":
			draw_circle(p + Vector2(-1.8, -1.0), 2.6, dark)
			draw_circle(p + Vector2(1.8, -1.0), 2.6, dark)
			draw_colored_polygon(PackedVector2Array([p + Vector2(-4.4, -0.4), p + Vector2(4.4, -0.4), p + Vector2(0, 4.6)]), dark)
			draw_circle(p + Vector2(-1.8, -1.0), 1.9, Color("ff3b5c"))
			draw_circle(p + Vector2(1.8, -1.0), 1.9, Color("ff3b5c"))
			draw_colored_polygon(PackedVector2Array([p + Vector2(-3.6, -0.6), p + Vector2(3.6, -0.6), p + Vector2(0, 3.6)]), Color("ff3b5c"))
		"arma":
			var r := Rect2(p - Vector2(3.5, 3.5), Vector2(7, 7))
			draw_rect(r.grow(1.0), Color(1, 1, 1, 0.95))
			draw_rect(r, Color("2f7ff0"))
			draw_rect(Rect2(p - Vector2(2.5, 0.7), Vector2(5, 1.4)), Color("ff8a1a"))
		"soaker":
			draw_circle(p + Vector2(0, 1.0), 3.6, dark)
			draw_colored_polygon(PackedVector2Array([p + Vector2(0, -5.2), p + Vector2(3.2, 0.2), p + Vector2(-3.2, 0.2)]), dark)
			draw_circle(p + Vector2(0, 1.0), 2.7, Color("39b6ff"))
			draw_colored_polygon(PackedVector2Array([p + Vector2(0, -4.0), p + Vector2(2.4, 0.4), p + Vector2(-2.4, 0.4)]), Color("39b6ff"))
			draw_circle(p + Vector2(-0.9, 0.6), 0.8, Color("d8f3ff"))
		"espalhadora":
			var fan := PackedVector2Array([p + Vector2(-3.5, 2.5)])
			var fan_o := PackedVector2Array([p + Vector2(-4.8, 3.2)])
			for i in 6:
				var a := -PI * 0.5 - 0.75 + 1.5 * i / 5.0
				fan.append(p + Vector2(-3.5, 2.5) + Vector2(cos(a), sin(a)) * 6.5 + Vector2(2.6, 0))
				fan_o.append(p + Vector2(-4.8, 3.2) + Vector2(cos(a), sin(a)) * 8.4 + Vector2(3.2, 0))
			draw_colored_polygon(fan_o, dark)
			draw_colored_polygon(fan, Color("6fe03a"))
		_:
			var col := Color("ff2e1f") if kind == "vermelho" else Color("ff9a1a")
			var sz := 4.6 + pulse * 0.8
			var tri := PackedVector2Array([p + Vector2(0, -sz), p + Vector2(sz * 0.95, sz * 0.75), p + Vector2(-sz * 0.95, sz * 0.75)])
			var out := PackedVector2Array([p + Vector2(0, -sz - 1.6), p + Vector2(sz * 0.95 + 1.6, sz * 0.75 + 1.0), p + Vector2(-sz * 0.95 - 1.6, sz * 0.75 + 1.0)])
			draw_colored_polygon(out, dark)
			draw_colored_polygon(tri, col)

	draw_set_transform(Vector2.ZERO)

func _legend() -> void:
	if not show_legend:
		return
	var font := get_theme_default_font()
	var y0 := size.y - LEGEND_H - 2.0
	var col := Color("fff1c9")
	var dim := Color("cfd8c4")
	var items := [["moeda", int(counts["moeda"]), int(counts["moeda_total"])],
		["arma", int(counts["arma"]), int(counts["arma_total"])],
		["vermelho", int(counts["escorpiao"]), int(counts["escorpiao_total"])]]
	var w := (size.x - 12.0) / 3.0
	for k in items.size():
		var x := 6.0 + w * k
		_marker(Vector2(x + 6.0, y0 + 10.0), String(items[k][0]))
		# Nesta tela / no nível inteiro.
		draw_string(font, Vector2(x + 14.0, y0 + 15.0), str(items[k][1]), HORIZONTAL_ALIGNMENT_LEFT, w - 16.0, 14, col)
		var tw := font.get_string_size(str(items[k][1]), HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
		draw_string(font, Vector2(x + 14.0 + tw, y0 + 15.0), "/%d" % int(items[k][2]), HORIZONTAL_ALIGNMENT_LEFT, w - 16.0 - tw, 11, dim)
