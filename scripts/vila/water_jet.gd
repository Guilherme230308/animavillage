class_name WaterJet
extends Node2D
## Jato contínuo da Super Soaker: gotas azuis saindo do bico até o alcance, com respingos na ponta.

var direction := Vector2.RIGHT
var length := 95.0
var _t := 0.0


func _ready() -> void:
	z_index = 30
	var mat := CanvasItemMaterial.new()
	mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	material = mat


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var d := direction.normalized()
	var side := Vector2(-d.y, d.x)
	var tip := d * length
	draw_line(Vector2.ZERO, tip, Color(0.45, 0.8, 1.0, 0.35), 5.0)
	draw_line(Vector2.ZERO, tip, Color(0.75, 0.95, 1.0, 0.75), 2.0)
	# Gotas correndo pelo jato.
	for i in 9:
		var k := fmod(_t * 3.2 + i / 9.0, 1.0)
		var wob := sin(_t * 20.0 + i * 1.7) * (1.0 + k * 3.0)
		var p := d * length * k + side * wob
		draw_circle(p, 1.4 + k * 1.2, Color(0.6, 0.9, 1.0, 0.9 - k * 0.3))
	# Respingos na ponta.
	for i in 5:
		var a := _t * 9.0 + i * TAU / 5.0
		var r := 3.0 + fmod(_t * 14.0 + i, 4.0)
		draw_circle(tip + Vector2(cos(a), sin(a) * 0.6) * r, 1.2, Color(0.8, 0.96, 1.0, 0.8))
