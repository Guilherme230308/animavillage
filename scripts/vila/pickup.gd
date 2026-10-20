class_name Pickup
extends Node2D
## Item no chão: moeda (desenhada em pixel art, girando) ou lançador Nerf.
## Brilha também à noite (não é afetado pela escuridão).

var kind := "moeda"
var index := -1
var _t := 0.0
var _sprite: Sprite2D


func _ready() -> void:
	_t = randf() * TAU
	var mat := CanvasItemMaterial.new()
	mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	material = mat
	if kind == "arma":
		_sprite = Sprite2D.new()
		_sprite.texture = load("res://assets/game/nerf.png") as Texture2D
		_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_sprite.use_parent_material = true
		add_child(_sprite)


func _process(delta: float) -> void:
	_t += delta
	if _sprite != null:
		_sprite.position = Vector2(0, -9 + sin(_t * 3.0) * 1.5)
	queue_redraw()


func _draw() -> void:
	if kind == "arma":
		var r := 11.0 + sin(_t * 4.0) * 1.0
		draw_circle(Vector2(0, 0), r, Color(1.0, 0.85, 0.3, 0.18))
		draw_arc(Vector2(0, 0), r, 0, TAU, 20, Color(1.0, 0.9, 0.4, 0.7), 1.0)
		return
	# Moeda girando: largura varia com o cosseno do giro.
	var bob := sin(_t * 3.0) * 1.0
	var c := Vector2(0, -6 + bob)
	draw_circle(Vector2(0, 1), 3.5, Color(0, 0, 0, 0.25))
	var w := maxf(1.0, absf(cos(_t * 2.6)) * 5.0)
	var pts := PackedVector2Array()
	for i in 16:
		var a := TAU * i / 16.0
		pts.append(c + Vector2(cos(a) * w, sin(a) * 5.0))
	draw_colored_polygon(pts, Color("f2b632"))
	var inner := PackedVector2Array()
	for i in 16:
		var a := TAU * i / 16.0
		inner.append(c + Vector2(cos(a) * w * 0.62, sin(a) * 3.2))
	draw_colored_polygon(inner, Color("ffd85a"))
	pts.append(pts[0])
	draw_polyline(pts, Color("8a5a12"), 1.0)
	if w > 2.5:
		draw_rect(Rect2(c + Vector2(-0.5, -2.0), Vector2(1, 4)), Color("fff3b0"))
