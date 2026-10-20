class_name Walker
extends Node2D
## Personagem caminhável. A posição do nó é o ponto dos pés.

const SHEET_PATH := "res://assets/game/sophia.png"
const FRAME_W := 25
const FRAME_H := 40
const ROWS := {"down": 0, "left": 1, "right": 2, "up": 3}
const WALK_SPEED := 70.0
const RUN_SPEED := 125.0
const FOOT_HALF := Vector2(3.0, 2.0)

var walk_map: WalkMap
var sheet_path := SHEET_PATH
var facing := "down"
var moving := false
var _sprite: AnimatedSprite2D
var _shadow: Polygon2D


func _ready() -> void:
	_shadow = Polygon2D.new()
	var pts := PackedVector2Array()
	for i in 16:
		var a := TAU * i / 16.0
		pts.append(Vector2(cos(a) * 8.0, sin(a) * 3.0))
	_shadow.polygon = pts
	_shadow.color = Color(0, 0, 0, 0.35)
	add_child(_shadow)

	_sprite = AnimatedSprite2D.new()
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.sprite_frames = _build_frames(sheet_path)
	_sprite.offset = Vector2(0, -FRAME_H / 2.0 + 1)
	add_child(_sprite)
	_sprite.play("idle_down")


## Troca a personagem (folha de sprites 4x4: frente, esquerda, direita, costas).
func set_sheet(path: String) -> void:
	sheet_path = path
	if _sprite != null:
		_sprite.sprite_frames = _build_frames(path)
		_sprite.play(("walk_" if moving else "idle_") + facing)


static func _build_frames(path: String) -> SpriteFrames:
	var sheet := load(path) as Texture2D
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	for dir: String in ROWS:
		var row: int = ROWS[dir]
		var walk := "walk_" + dir
		frames.add_animation(walk)
		frames.set_animation_speed(walk, 8.0)
		frames.set_animation_loop(walk, true)
		for col in 4:
			var atlas := AtlasTexture.new()
			atlas.atlas = sheet
			atlas.region = Rect2(col * FRAME_W, row * FRAME_H, FRAME_W, FRAME_H)
			frames.add_frame(walk, atlas)
		var idle := "idle_" + dir
		frames.add_animation(idle)
		frames.set_animation_loop(idle, false)
		frames.add_frame(idle, frames.get_frame_texture(walk, 0))
	return frames


## Move tentando cada eixo separadamente para deslizar junto às bordas.
func step(direction: Vector2, running: bool, delta: float) -> Vector2:
	var before := position
	moving = direction.length() > 0.01
	if moving:
		var dir := direction.normalized() if direction.length() > 1.0 else direction
		var speed := RUN_SPEED if running else WALK_SPEED
		var motion := dir * speed * delta
		_try_axis(Vector2(motion.x, 0))
		_try_axis(Vector2(0, motion.y))
		if abs(direction.x) > abs(direction.y):
			facing = "right" if direction.x > 0 else "left"
		else:
			facing = "down" if direction.y > 0 else "up"
	moving = moving and position.distance_to(before) > 0.001
	var anim := ("walk_" if moving else "idle_") + facing
	if _sprite != null and _sprite.animation != anim:
		_sprite.play(anim)
	if _sprite != null:
		_sprite.speed_scale = 1.6 if running else 1.0
	return position - before


func _try_axis(motion: Vector2) -> void:
	if motion == Vector2.ZERO:
		return
	# Subdivide para nunca atravessar paredes finas.
	var steps := int(ceil(motion.length() / 2.0))
	var piece := motion / steps
	for i in steps:
		var target := position + piece
		if walk_map == null or walk_map.is_footprint_walkable(target, FOOT_HALF):
			position = target
		else:
			break
