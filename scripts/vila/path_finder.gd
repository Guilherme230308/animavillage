class_name PathFinder
extends RefCounted
## Rotas para "clicar e andar": A* na grade de caminhos, só por células onde o pé cabe.

var _astar: AStarGrid2D
var _map: WalkMap


func build(map: WalkMap) -> void:
	_map = map
	_astar = AStarGrid2D.new()
	_astar.region = Rect2i(0, 0, map.width, map.height)
	_astar.cell_size = Vector2.ONE
	_astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	_astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	_astar.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	_astar.update()
	var c := WalkMap.CELL
	for y in map.height:
		var run_start := -1
		for x in map.width + 1:
			var solid := true
			if x < map.width and map.is_cell_walkable(x, y):
				solid = not map.is_footprint_walkable(Vector2((x + 0.5) * c, (y + 0.5) * c), Walker.FOOT_HALF)
			if solid and run_start == -1:
				run_start = x
			elif not solid and run_start != -1:
				_astar.fill_solid_region(Rect2i(run_start, y, x - run_start, 1), true)
				run_start = -1
		if run_start != -1 and run_start < map.width:
			_astar.fill_solid_region(Rect2i(run_start, y, map.width - run_start, 1), true)


func is_ready() -> bool:
	return _astar != null


## Célula livre mais próxima de um ponto (procura em anéis até ~60 px).
func _nearest_free(cell: Vector2i) -> Vector2i:
	for r in range(0, 16):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if abs(dx) != r and abs(dy) != r:
					continue
				var p := cell + Vector2i(dx, dy)
				if _astar.is_in_boundsv(p) and not _astar.is_point_solid(p):
					return p
	return Vector2i(-1, -1)


## Lista de pontos (mundo) do ponto `from` até `to`; vazia se não houver caminho.
func find(from: Vector2, to: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	if _astar == null:
		return out
	var c := WalkMap.CELL
	var a := _nearest_free(Vector2i(int(from.x / c), int(from.y / c)))
	var b := _nearest_free(Vector2i(int(to.x / c), int(to.y / c)))
	if a.x < 0 or b.x < 0:
		return out
	var ids := _astar.get_id_path(a, b)
	if ids.is_empty():
		return out
	var raw := PackedVector2Array()
	for id in ids:
		raw.append(Vector2((id.x + 0.5) * c, (id.y + 0.5) * c))
	# Puxa a corda: pula pontos intermediários quando a linha reta está livre.
	var i := 0
	out.append(raw[0])
	while i < raw.size() - 1:
		var j := mini(raw.size() - 1, i + 40)
		while j > i + 1 and not _clear(raw[i], raw[j]):
			j -= 1
		out.append(raw[j])
		i = j
	return out


func _clear(p: Vector2, q: Vector2) -> bool:
	var n := int(ceil(p.distance_to(q) / 2.0))
	for k in range(1, n):
		if not _map.is_footprint_walkable(p.lerp(q, float(k) / n), Walker.FOOT_HALF):
			return false
	return true
