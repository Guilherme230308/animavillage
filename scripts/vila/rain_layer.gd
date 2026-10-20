class_name RainLayer
extends Control
## Chuva em tela cheia: riscos diagonais, respingos no chão e relâmpagos de vez em quando.
## Fica entre o cenário e a interface e não captura cliques.

const DROPS := 380
const SLANT := Vector2(-0.22, 1.0)
var _drops: Array = []
var _splashes: Array = []
var _flash := 0.0
var _next_flash := 8.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_rng.randomize()
	for i in DROPS:
		_drops.append(_new_drop(true))


func _new_drop(anywhere: bool) -> Dictionary:
	var sz := size if size.x > 0 else Vector2(1280, 720)
	var y := _rng.randf_range(-sz.y, sz.y) if anywhere else _rng.randf_range(-80.0, -10.0)
	return {
		"p": Vector2(_rng.randf_range(0.0, sz.x + sz.y * 0.25), y),
		"v": _rng.randf_range(650.0, 950.0),
		"len": _rng.randf_range(10.0, 20.0),
		"stop": _rng.randf_range(sz.y * 0.1, sz.y),
		"a": _rng.randf_range(0.45, 0.8),
	}


func _process(delta: float) -> void:
	if not visible:
		return
	var dir := SLANT.normalized()
	for i in _drops.size():
		var d: Dictionary = _drops[i]
		d["p"] += dir * float(d["v"]) * delta
		if (d["p"] as Vector2).y >= float(d["stop"]):
			if _splashes.size() < 90:
				_splashes.append({"p": d["p"], "t": 0.0})
			_drops[i] = _new_drop(false)
	for i in range(_splashes.size() - 1, -1, -1):
		_splashes[i]["t"] += delta
		if float(_splashes[i]["t"]) > 0.25:
			_splashes.remove_at(i)
	_next_flash -= delta
	if _next_flash <= 0.0:
		_flash = 1.0
		_next_flash = _rng.randf_range(9.0, 18.0)
	_flash = maxf(0.0, _flash - delta * 3.5)
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.1, 0.16, 0.26, 0.24))
	var dir := SLANT.normalized()
	for d: Dictionary in _drops:
		var p: Vector2 = d["p"]
		draw_line(p, p - dir * float(d["len"]), Color(0.82, 0.9, 1.0, float(d["a"])), 1.8)
	for s: Dictionary in _splashes:
		var k := float(s["t"]) / 0.25
		var r := 2.0 + k * 5.0
		draw_arc(s["p"], r, PI, TAU, 8, Color(0.85, 0.92, 1.0, 0.5 * (1.0 - k)), 1.0)
	if _flash > 0.0:
		var a := _flash * 0.55 if _flash > 0.6 or _flash < 0.35 else _flash * 0.15
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.95, 0.97, 1.0, a))
