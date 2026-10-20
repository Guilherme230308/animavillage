extends Node2D
## Marcador pulsante no ponto de destino do clique.

var _t := 0.0


func _process(delta: float) -> void:
	if visible:
		_t += delta
		queue_redraw()


func _draw() -> void:
	var r := 7.0 + sin(_t * 6.0) * 1.5
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.5))
	draw_arc(Vector2.ZERO, r + 1.0, 0, TAU, 24, Color(0, 0, 0, 0.5), 3.0)
	draw_arc(Vector2.ZERO, r, 0, TAU, 24, Color("fff1c9"), 2.0)
	draw_arc(Vector2.ZERO, r * 0.45, 0, TAU, 16, Color("e9a15b"), 2.0)
