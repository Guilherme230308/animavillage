class_name Dart
extends Node2D
## Dardo de espuma disparado pelo lançador Nerf.

const SPEED := 340.0
const RANGE := 300.0
var velocity := Vector2.ZERO
var travelled := 0.0


func _ready() -> void:
	z_index = 30
	var mat := CanvasItemMaterial.new()
	mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	material = mat


func _draw() -> void:
	var d := velocity.normalized()
	draw_line(-d * 5.0, d * 2.0, Color("2f6fe0"), 3.0)
	draw_line(d * 2.0, d * 4.5, Color("f07a1a"), 3.0)


## Avança; devolve falso quando o dardo acaba o alcance.
func advance(delta: float) -> bool:
	var m := velocity * delta
	position += m
	travelled += m.length()
	queue_redraw()
	return travelled < RANGE
