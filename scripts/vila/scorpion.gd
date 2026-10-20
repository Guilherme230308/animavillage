class_name Scorpion
extends Node2D
## Escorpião visto de cima. Vagueia pelo caminho e persegue a personagem quando ela chega perto.
## A posição do nó é o centro do corpo no chão (ordenado em Y com as torres).

const SHEET := "res://assets/game/scorpions.png"
const FRAME := Vector2(24, 26)
const HALF := Vector2(2.0, 2.0)
## Velocidade (px/s), raio de alerta, raio em que desiste e resistência a dardos.
const KINDS := {
	"amarelo": {"speed": 44.0, "aggro": 170.0, "lose": 330.0, "hp": 1, "row": 0},
	"vermelho": {"speed": 56.0, "aggro": 215.0, "lose": 380.0, "hp": 2, "row": 1},
}

var kind := "amarelo"
var hp := 1
var walk_map: WalkMap
var finder: PathFinder
var target: Node2D
var speed_mult := 1.0
## Multiplica a distância em que começa (e desiste de) perseguir.
var aggro_mult := 1.0
var chasing := false
## Molhado pela Super Soaker: anda a 50% enquanto > 0.
var slow_t := 0.0
var sting_cd := 0.0
## Verdadeiro se este escorpião nasceu de um bueiro.
var from_drain := false
## Relâmpago: visível mesmo fora da lanterna.
var revealed := false
## Devolve verdadeiro se o ponto é poça (o escorpião não entra).
var avoid: Callable = Callable()
var _sprite: Sprite2D
var _anim_t := 0.0
var _path := PackedVector2Array()
var _path_i := 0
var _repath_t := 0.0
var _wander_to := Vector2.INF
var _wander_t := 0.0
var _flash := 0.0
var _heading := Vector2.DOWN
var _force_path_t := 0.0


func setup(k: String, map: WalkMap, pf: PathFinder, player: Node2D, mult: float) -> void:
	kind = k
	hp = int(KINDS[k]["hp"])
	walk_map = map
	finder = pf
	target = player
	speed_mult = mult
	_repath_t = randf() * 0.5


func _ready() -> void:
	var shadow := Polygon2D.new()
	var pts := PackedVector2Array()
	for i in 12:
		var a := TAU * i / 12.0
		pts.append(Vector2(cos(a) * 8.0, sin(a) * 4.0 + 2.0))
	shadow.polygon = pts
	shadow.color = Color(0, 0, 0, 0.3)
	add_child(shadow)
	_sprite = Sprite2D.new()
	var at := AtlasTexture.new()
	at.atlas = load(SHEET) as Texture2D
	at.region = Rect2(0, float(KINDS[kind]["row"]) * FRAME.y, FRAME.x, FRAME.y)
	_sprite.texture = at
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.position = Vector2(0, -4)
	add_child(_sprite)


func _set_frame(col: int) -> void:
	var at := _sprite.texture as AtlasTexture
	at.region = Rect2(col * FRAME.x, float(KINDS[kind]["row"]) * FRAME.y, FRAME.x, FRAME.y)


## Avança a IA um passo. Devolve verdadeiro se picou a personagem neste passo.
func tick(delta: float, player_hidden: bool) -> bool:
	sting_cd = maxf(0.0, sting_cd - delta)
	_force_path_t = maxf(0.0, _force_path_t - delta)
	_flash = maxf(0.0, _flash - delta)
	slow_t = maxf(0.0, slow_t - delta)
	if revealed:
		_show_revealed()
	else:
		if _sprite.material != null:
			_sprite.material = null
		_sprite.modulate = Color(3, 3, 3, 1) if _flash > 0.0 else (Color(0.55, 0.8, 1.35, 1) if slow_t > 0.0 else Color(1, 1, 1, 1))
	var cfg: Dictionary = KINDS[kind]
	var to_p := target.position - position
	var d := to_p.length()
	if chasing:
		if d > float(cfg["lose"]) * aggro_mult:
			chasing = false
			_path = PackedVector2Array()
	elif d < float(cfg["aggro"]) * aggro_mult and not player_hidden:
		chasing = true
		_repath_t = 0.0
	var dir := Vector2.ZERO
	var speed := float(cfg["speed"]) * speed_mult * (0.5 if slow_t > 0.0 else 1.0)
	if chasing:
		if _force_path_t <= 0.0 and (d < 26.0 or (_clear_line(position, target.position) and d < 90.0)):
			dir = to_p.normalized()
		else:
			_repath_t -= delta
			if _repath_t <= 0.0 or _path_i >= _path.size():
				_repath_t = 0.45 + randf() * 0.2
				_path = finder.find(position, target.position) if finder != null and finder.is_ready() else PackedVector2Array()
				_path_i = 1
			while _path_i < _path.size() and position.distance_to(_path[_path_i]) < 3.0:
				_path_i += 1
			if _path_i < _path.size():
				dir = (_path[_path_i] - position).normalized()
	else:
		speed *= 0.4
		_wander_t -= delta
		if _wander_t <= 0.0 or _wander_to == Vector2.INF or position.distance_to(_wander_to) < 3.0:
			_wander_t = 1.5 + randf() * 2.0
			var cand := position + Vector2(randf_range(-45, 45), randf_range(-45, 45))
			var blocked: bool = avoid.is_valid() and bool(avoid.call(cand))
			_wander_to = cand if not blocked and walk_map.is_footprint_walkable(cand, HALF) and _clear_line(position, cand) else Vector2.INF
		if _wander_to != Vector2.INF:
			dir = (_wander_to - position).normalized()
	if dir != Vector2.ZERO:
		var before := position
		_try(Vector2(dir.x, 0) * speed * delta)
		_try(Vector2(0, dir.y) * speed * delta)
		if position.distance_to(before) < speed * delta * 0.2:
			if chasing:
				# Reta bloqueada (quina ou muro): usa a rota contornando por um tempo.
				if _force_path_t <= 0.0:
					_force_path_t = 1.0
					_repath_t = 0.0
			else:
				_wander_to = Vector2.INF
		_heading = _heading.lerp(dir, clampf(delta * 10.0, 0.0, 1.0)).normalized()
		_sprite.rotation = _heading.angle() + PI / 2.0
		_anim_t += delta * (10.0 if chasing else 6.0)
		_set_frame(int(_anim_t) % 2)
	if d < 13.0 and sting_cd <= 0.0:
		sting_cd = 1.3
		# Recua um pouco depois de picar.
		var back := -to_p.normalized() * 14.0
		_try(Vector2(back.x, 0))
		_try(Vector2(0, back.y))
		return true
	return false


## Molhado pela Super Soaker: fica lento por `secs` segundos.
func soak(secs: float) -> void:
	slow_t = maxf(slow_t, secs)
	chasing = true


## Leva um dardo. Devolve verdadeiro se morreu.
func hit() -> bool:
	hp -= 1
	_flash = 0.12
	chasing = true
	return hp <= 0


func set_revealed(on: bool) -> void:
	revealed = on
	if revealed:
		_show_revealed()
	elif _sprite != null:
		_sprite.material = null


func _show_revealed() -> void:
	if _sprite == null:
		return
	if _sprite.material == null:
		var mat := CanvasItemMaterial.new()
		mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
		_sprite.material = mat
	_sprite.modulate = Color(1.35, 1.35, 1.35, 1)


func _try(m: Vector2) -> void:
	if m == Vector2.ZERO:
		return
	var steps := int(ceil(m.length() / 2.0))
	var piece := m / steps
	for i in steps:
		var nxt := position + piece
		if avoid.is_valid() and bool(avoid.call(nxt)) and not bool(avoid.call(position)):
			break
		if walk_map.is_footprint_walkable(nxt, HALF):
			position += piece
		else:
			break


func _clear_line(a: Vector2, b: Vector2) -> bool:
	var n := int(ceil(a.distance_to(b) / 4.0))
	for k in range(1, n):
		if not walk_map.is_point_walkable(a.lerp(b, float(k) / n)):
			return false
	return true
