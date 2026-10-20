class_name WalkMap
extends RefCounted
## Grade de áreas caminháveis extraída do terreno da imagem do condomínio.
## Cada célula cobre CELL x CELL pixels do cenário; branco = passeio.

const CELL := 4
const MASK_PATH := "res://assets/game/walk_mask.png"

var width := 0
var height := 0
var _cells := PackedByteArray()


func load_mask(path: String = MASK_PATH) -> bool:
	var texture := load(path) as Texture2D
	if texture == null:
		push_error("Máscara de caminhos não encontrada: " + path)
		return false
	var image := texture.get_image()
	if image == null:
		return false
	if image.is_compressed():
		image.decompress()
	width = image.get_width()
	height = image.get_height()
	_cells.resize(width * height)
	for y in height:
		for x in width:
			_cells[y * width + x] = 1 if image.get_pixel(x, y).r > 0.5 else 0
	return true


func is_cell_walkable(cx: int, cy: int) -> bool:
	if cx < 0 or cy < 0 or cx >= width or cy >= height:
		return false
	return _cells[cy * width + cx] == 1


func is_point_walkable(p: Vector2) -> bool:
	return is_cell_walkable(int(floor(p.x / CELL)), int(floor(p.y / CELL)))


## O pé do personagem é um pequeno retângulo; todos os cantos precisam estar no passeio.
func is_footprint_walkable(center: Vector2, half: Vector2) -> bool:
	for offset: Vector2 in [Vector2(-half.x, -half.y), Vector2(half.x, -half.y), Vector2(-half.x, half.y), Vector2(half.x, half.y), Vector2.ZERO]:
		if not is_point_walkable(center + offset):
			return false
	return true


func walkable_count() -> int:
	var total := 0
	for v in _cells:
		total += v
	return total


## Célula caminhável mais próxima de um ponto (busca em anéis).
func nearest_walkable(p: Vector2, half: Vector2) -> Vector2:
	var cx := int(p.x / CELL)
	var cy := int(p.y / CELL)
	for radius in range(0, max(width, height)):
		for dy in range(-radius, radius + 1):
			for dx in range(-radius, radius + 1):
				if abs(dx) != radius and abs(dy) != radius:
					continue
				var c := Vector2((cx + dx + 0.5) * CELL, (cy + dy + 0.5) * CELL)
				if is_footprint_walkable(c, half):
					return c
	return p


func cell_size_px() -> Vector2:
	return Vector2(width * CELL, height * CELL)


## Largura do passeio em p, em pixels do mundo: a menor corda caminhável.
func path_width(p: Vector2) -> float:
	var cx := int(floor(p.x / float(CELL)))
	var cy := int(floor(p.y / float(CELL)))
	if not is_cell_walkable(cx, cy):
		return float(CELL)
	var narrow := 4096.0
	for step: Vector2i in [Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(1, -1)]:
		var n := _chord_cells(cx, cy, step)
		var step_px := float(CELL) * sqrt(float(step.x * step.x + step.y * step.y))
		narrow = minf(narrow, float(n) * step_px)
	return narrow


func _chord_cells(cx: int, cy: int, step: Vector2i) -> int:
	var n := 1
	var x := cx - step.x
	var y := cy - step.y
	var guard := 0
	while guard < 256 and is_cell_walkable(x, y):
		n += 1
		x -= step.x
		y -= step.y
		guard += 1
	x = cx + step.x
	y = cy + step.y
	guard = 0
	while guard < 256 and is_cell_walkable(x, y):
		n += 1
		x += step.x
		y += step.y
		guard += 1
	return n


## Distância de p até o primeiro pixel fora do passeio, limitada a `limit`.
func edge_clearance(p: Vector2, limit: float) -> float:
	if limit <= 0.0:
		return 0.0
	var max_cells := int(ceil(limit / float(CELL))) + 1
	var cx := int(floor(p.x / float(CELL)))
	var cy := int(floor(p.y / float(CELL)))
	var best := limit
	for dy in range(-max_cells, max_cells + 1):
		for dx in range(-max_cells, max_cells + 1):
			if is_cell_walkable(cx + dx, cy + dy):
				continue
			var left := float((cx + dx) * CELL)
			var top := float((cy + dy) * CELL)
			var qx := clampf(p.x, left, left + float(CELL))
			var qy := clampf(p.y, top, top + float(CELL))
			best = minf(best, p.distance_to(Vector2(qx, qy)))
	return best
