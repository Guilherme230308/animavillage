extends SceneTree
## Testes de fonte: passeios carregados, caminhada e bloqueio por obstáculos.

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _check(ok: bool, label: String) -> void:
	if not ok:
		_failures.append(label)
		printerr("[vila-tests] FAIL: " + label)


func _run() -> void:
	var packed := load("res://scenes/main.tscn") as PackedScene
	_check(packed != null, "cena principal carrega")
	var main := packed.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	var map: WalkMap = main.walk_map
	_check(map.width > 100 and map.height > 100, "grade de passeios carregada")
	_check(map.walkable_count() > 10000, "rede de passeios extensa (%d)" % map.walkable_count())
	var player: Walker = main.get("_player")
	_check(map.is_footprint_walkable(player.position, Walker.FOOT_HALF), "nasce em passeio")
	_check(bool((main.get("_title_screen") as Control).visible), "abre na tela de título")
	# Escolha de personagem.
	var cbuttons: Dictionary = main.get("_character_buttons")
	_check(cbuttons.has("sophia") and cbuttons.has("luiza"), "dá para escolher Sophia ou Luiza")
	(cbuttons["luiza"] as Button).pressed.emit()
	_check(String(main.get("character")) == "luiza" and player.sheet_path.ends_with("luiza.png"), "jogar com Luiza usa a Luiza")
	_check(not bool((main.get("_title_screen") as Control).visible), "escolher personagem inicia o jogo")
	main.call("_back_to_title")
	(cbuttons["sophia"] as Button).pressed.emit()
	_check(String(main.get("character")) == "sophia" and player.sheet_path.ends_with("sophia.png"), "jogar com Sophia usa a Sophia")

	# Caminhar em cada direção nunca sai do passeio, e em pelo menos uma direção se move.
	var total := 0.0
	for dir: Vector2 in [Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT, Vector2.UP, Vector2(1, 1), Vector2(-1, 1)]:
		var moved: Vector2 = main.call("simulate_walk", dir, 1.5, true)
		total += moved.length()
		_check(map.is_footprint_walkable(player.position, Walker.FOOT_HALF), "permanece no passeio após andar " + str(dir))
	_check(total > 40.0, "o personagem se move pelos caminhos")

	# Andar muito tempo contra um lado acaba bloqueado por um obstáculo.
	var before := player.position
	main.call("simulate_walk", Vector2.LEFT, 30.0, true)
	var after_block := player.position
	var extra: Vector2 = main.call("simulate_walk", Vector2.LEFT, 1.0, true)
	_check(extra.length() < 0.5, "obstáculo bloqueia a passagem")
	_check(after_block.x < before.x or before.x - after_block.x == 0.0, "andou até a borda")
	_check(map.is_footprint_walkable(player.position, Walker.FOOT_HALF), "bloqueio mantém o personagem no passeio")

	# Torres: a base (prédio) bloqueia; o chão logo atrás é caminhável e fica escondido.
	_check(not map.is_point_walkable(Vector2(700, 620)), "piscina bloqueada")
	_check(not map.is_point_walkable(Vector2(30, 600)), "mata externa bloqueada")
	for fc: Vector2 in [Vector2(606, 277), Vector2(859, 278), Vector2(453, 423), Vector2(316, 567), Vector2(228, 782), Vector2(359, 923), Vector2(504, 1068), Vector2(737, 1091), Vector2(891, 933), Vector2(1060, 777)]:
		_check(not map.is_point_walkable(fc), "base da torre bloqueia " + str(fc))
	# Debaixo do telhado/fachada dá para andar, e a torre fica desenhada na frente.
	var under := 0
	for gy in range(0, map.height * WalkMap.CELL, 20):
		for gx in range(0, map.width * WalkMap.CELL, 20):
			var top := Vector2(gx, gy)
			if map.is_footprint_walkable(top, Walker.FOOT_HALF) and bool(main.call("is_occluded", top)):
				under += 1
	_check(under >= 20, "caminhos passam por baixo das torres, cobertos por elas (%d)" % under)
	var behind := _first_walkable_behind(main, map)
	_check(behind != Vector2.INF, "existe chão caminhável atrás de uma torre")
	if behind != Vector2.INF:
		_check(bool(main.call("is_occluded", behind)), "torre fica na frente de quem passa atrás")
	_check(not bool(main.call("is_occluded", Vector2(630, 790))), "praça não é coberta")
	_check(not map.is_point_walkable(Vector2(84, 700)), "rua não faz parte da tela do condomínio")

	# Telas separadas: cada saída leva a uma chegada válida e todas as saídas são alcançáveis.
	var areas: Dictionary = main.get("areas")
	for id: String in ["condominio", "oeste", "fundos", "direita", "estacionamento"]:
		_check(areas.has(id), "área existe: " + id)
	for id: String in areas:
		main.call("load_area", id, (areas[id]["spawns"] as Dictionary).keys()[0])
		var amap: WalkMap = main.walk_map
		for sp_name: String in areas[id]["spawns"]:
			var sp: Array = areas[id]["spawns"][sp_name]
			var spv := Vector2(float(sp[0]), float(sp[1]))
			_check(amap.is_footprint_walkable(spv, Walker.FOOT_HALF), "chegada caminhável %s/%s" % [id, sp_name])
			_check(main.call("exit_at", spv).is_empty(), "chegada fora de saída %s/%s" % [id, sp_name])
			for e: Dictionary in areas[id]["exits"]:
				_check(_reach_rect(amap, spv, e["rect"]), "%s/%s alcança saída para %s" % [id, sp_name, e["to"]])
		for e: Dictionary in areas[id]["exits"]:
			_check(areas.has(e["to"]) and (areas[e["to"]]["spawns"] as Dictionary).has(e["spawn"]), "saída %s -> %s/%s válida" % [id, e["to"], e["spawn"]])
	# Percurso real: descer a escada do condomínio leva à rua lateral.
	main.call("load_area", "condominio", "escada")
	main.call("simulate_walk", Vector2.LEFT, 3.0, false)
	_check(String(main.get("current_area")) == "oeste", "descer a escada abre a rua lateral")
	var order := ["oeste", "fundos", "direita", "estacionamento", "oeste"]
	for i in range(order.size() - 1):
		var found := false
		for e: Dictionary in areas[order[i]]["exits"]:
			if e["to"] == order[i + 1]:
				found = true
		_check(found, "%s liga com %s" % [order[i], order[i + 1]])
	# Caminhada real (mesmo movimento do jogador) até cada saída, trocando de tela.
	for route: Array in [["condominio", "inicio", "oeste"], ["oeste", "escada", "estacionamento"], ["oeste", "escada", "fundos"],
			["fundos", "norte", "direita"], ["direita", "oeste", "estacionamento"], ["estacionamento", "oeste", "direita"],
			["estacionamento", "sul", "oeste"], ["direita", "norte", "fundos"], ["fundos", "leste", "oeste"], ["oeste", "leste", "condominio"]]:
		_check(await _walk_route(main, route[0], route[1], route[2]), "caminhando: %s -> %s" % [route[0], route[2]])
	# Clicar para andar: a rota contorna obstáculos e leva até a saída clicada, trocando de tela.
	for route: Array in [["direita", "oeste", "estacionamento"], ["estacionamento", "sul", "oeste"], ["condominio", "inicio", "oeste"], ["fundos", "norte", "direita"]]:
		main.call("load_area", route[0], route[1])
		var er := Rect2()
		for e: Dictionary in (main.get("areas")[route[0]]["exits"] as Array):
			if e["to"] == route[2]:
				var r: Array = e["rect"]
				er = Rect2(float(r[0]), float(r[1]), float(r[2]), float(r[3]))
		var ok := bool(main.call("simulate_click_walk", er.get_center(), 90.0))
		_check(ok and String(main.get("current_area")) == route[2], "clique leva %s -> %s (está em %s)" % [route[0], route[2], main.get("current_area")])
	main.call("load_area", "estacionamento", "sul")
	main.call("simulate_click_walk", Vector2(1540, 862), 60.0)
	_check((main.get("_player") as Walker).position.distance_to(Vector2(1540, 862)) < 40.0, "clique chega à via do Ânima Clube")
	var mm: Minimap = main.get("_minimap")
	_check(mm != null and mm.title == "Estacionamento" and mm.size.x > 100.0, "minimapa mostra a tela atual")
	main.call("load_area", "condominio", "inicio")
	map = main.walk_map

	# Controles de toque: arrastar o joystick move o personagem.
	main.call("_back_to_title")
	main.call("_start")
	main.call("_enable_touch_mode")
	await process_frame
	var joy: TouchJoystick = main.get("_joystick")
	_check(bool((main.get("_touch_layer") as Control).visible), "controles de toque visíveis")
	var vs := root.get_visible_rect().size
	var origin := Vector2(vs.x * 0.2, vs.y * 0.7)
	var press := InputEventScreenTouch.new()
	press.index = 0
	press.position = origin
	press.pressed = true
	joy._input(press)
	await process_frame
	_check(joy.is_held(), "joystick capturou o toque")
	var tstart := (main.get("_player") as Walker).position
	var moved_any := 0.0
	for dir2: Vector2 in [Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT, Vector2.UP]:
		var drag := InputEventScreenDrag.new()
		drag.index = 0
		drag.position = origin + dir2 * 65.0
		joy._input(drag)
		_check(joy.running, "empurrar até a borda ativa corrida")
		for i in 30:
			await process_frame
		moved_any += (main.get("_player") as Walker).position.distance_to(tstart)
		tstart = (main.get("_player") as Walker).position
	var up := InputEventScreenTouch.new()
	up.index = 0
	up.position = origin
	up.pressed = false
	joy._input(up)
	await process_frame
	_check(not joy.is_held() and joy.vector == Vector2.ZERO, "soltar o dedo para o personagem")
	_check(moved_any > 3.0, "toque move o personagem")
	_check(map.is_footprint_walkable((main.get("_player") as Walker).position, Walker.FOOT_HALF), "toque mantém no passeio")
	var paths_btn: TouchButton = (main.get("_touch_buttons") as Dictionary)["paths"]
	paths_btn.tapped.emit()
	_check(bool((main.get("_paths_overlay") as Sprite2D).visible), "botão de caminhos funciona")

	await _adventure_tests(main)
	main.queue_free()
	await process_frame
	if _failures.is_empty():
		print("[vila-tests] PASS: caminhada, colisões e regras do jogo")
		quit(0)
	else:
		print("[vila-tests] FAILED: %d" % _failures.size())
		quit(1)


## Busca em largura na grade, opcionalmente ignorando um retângulo (ex.: a escada).
func _reachable(map: WalkMap, from: Vector2, to: Vector2, blocked: Rect2) -> bool:
	var c := WalkMap.CELL
	var start := Vector2i(int(from.x / c), int(from.y / c))
	var goal := Vector2i(int(to.x / c), int(to.y / c))
	if not map.is_cell_walkable(start.x, start.y) or not map.is_cell_walkable(goal.x, goal.y):
		return false
	var seen := PackedByteArray()
	seen.resize(map.width * map.height)
	var queue: Array[Vector2i] = [start]
	seen[start.y * map.width + start.x] = 1
	var head := 0
	while head < queue.size():
		var cur: Vector2i = queue[head]
		head += 1
		if cur == goal:
			return true
		for dlt: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n := cur + dlt
			if not map.is_cell_walkable(n.x, n.y):
				continue
			if blocked.size != Vector2.ZERO and blocked.has_point(Vector2((n.x + 0.5) * c, (n.y + 0.5) * c)):
				continue
			var idx := n.y * map.width + n.x
			if seen[idx] == 0:
				seen[idx] = 1
				queue.append(n)
	return false


func _first_walkable_behind(main: Node, map: WalkMap) -> Vector2:
	for y in range(100, 1150, 4):
		for x in range(120, 1150, 4):
			var p := Vector2(x + 2, y + 2)
			if map.is_footprint_walkable(p, Walker.FOOT_HALF) and bool(main.call("is_occluded", p)):
				return p
	return Vector2.INF


func _reach_rect(map: WalkMap, from: Vector2, rect: Array) -> bool:
	var r := Rect2(float(rect[0]), float(rect[1]), float(rect[2]), float(rect[3]))
	var c := WalkMap.CELL
	var start := Vector2i(int(from.x / c), int(from.y / c))
	if not map.is_cell_walkable(start.x, start.y):
		return false
	var seen := PackedByteArray()
	seen.resize(map.width * map.height)
	var queue: Array[Vector2i] = [start]
	seen[start.y * map.width + start.x] = 1
	var head := 0
	while head < queue.size():
		var cur: Vector2i = queue[head]
		head += 1
		if r.has_point(Vector2((cur.x + 0.5) * c, (cur.y + 0.5) * c)):
			return true
		for dlt: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n := cur + dlt
			if map.is_cell_walkable(n.x, n.y) and seen[n.y * map.width + n.x] == 0:
				seen[n.y * map.width + n.x] = 1
				queue.append(n)
	return false


## Traça a rota (A* simples em largura) até a saída e conduz a personagem com o movimento do jogo.
func _walk_route(main: Node, from_area: String, spawn: String, to_area: String) -> bool:
	main.call("load_area", from_area, spawn)
	var areas: Dictionary = main.get("areas")
	var exit_rect := Rect2()
	for e: Dictionary in areas[from_area]["exits"]:
		if e["to"] == to_area:
			var r: Array = e["rect"]
			exit_rect = Rect2(float(r[0]), float(r[1]), float(r[2]), float(r[3]))
	if exit_rect.size == Vector2.ZERO:
		return false
	var map: WalkMap = main.walk_map
	var player: Walker = main.get("_player")
	var c := WalkMap.CELL
	var start := Vector2i(int(player.position.x / c), int(player.position.y / c))
	var prev := {}
	prev[start] = start
	var queue: Array[Vector2i] = [start]
	var head := 0
	var goal := Vector2i(-1, -1)
	while head < queue.size():
		var cur: Vector2i = queue[head]
		head += 1
		if exit_rect.grow(2.0).has_point(Vector2((cur.x + 0.5) * c, (cur.y + 0.5) * c)):
			goal = cur
			break
		for dlt: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n := cur + dlt
			if prev.has(n) or not map.is_footprint_walkable(Vector2((n.x + 0.5) * c, (n.y + 0.5) * c), Walker.FOOT_HALF):
				continue
			prev[n] = cur
			queue.append(n)
	if goal.x < 0:
		printerr("[route] sem rota %s/%s -> %s" % [from_area, spawn, to_area])
		return false
	var path: Array[Vector2] = []
	var k := goal
	while k != start:
		path.push_front(Vector2((k.x + 0.5) * c, (k.y + 0.5) * c))
		k = prev[k]
	var i := 0
	var guard := 0
	while i < path.size() and guard < 20000:
		guard += 1
		if String(main.get("current_area")) != from_area:
			break
		var target: Vector2 = path[i]
		var to := target - player.position
		if to.length() < 2.5:
			i += 1
			continue
		main.call("simulate_walk", to.normalized(), 1.0 / 60.0, false)
	if String(main.get("current_area")) == from_area:
		main.call("simulate_walk", (exit_rect.get_center() - player.position).normalized(), 0.5, false)
	if String(main.get("current_area")) != to_area:
		printerr("[route] travou %s/%s -> %s em %s (alvo %s, area %s, i=%d/%d)" % [from_area, spawn, to_area, player.position, exit_rect, main.get("current_area"), i, path.size()])
	return String(main.get("current_area")) == to_area



## Regras: moedas, armas, escorpiões, vida, tiros e fases.
func _count(adv: Adventure, dict_name: String, kind: String = "") -> int:
	var total := 0
	var d: Dictionary = adv.get(dict_name)
	for id: String in d:
		for e: Variant in d[id]:
			if kind == "" or String((e as Dictionary)["kind"]) == kind:
				total += 1
	return total


func _adventure_tests(main: Node) -> void:
	main.call("_back_to_title")
	main.call("_start", "sophia")
	await process_frame
	var adv: Adventure = main.get("adventure")
	var player: Walker = main.get("_player")
	_check(adv.active and adv.phase == 0 and adv.health == 100, "fase 1 começa com 100% de vida")
	_check(_count(adv, "coins") == 100, "100 moedas espalhadas (%d)" % _count(adv, "coins"))
	_check(_count(adv, "guns") == 10, "10 lançadores espalhados")
	_check(_count(adv, "scorps", "amarelo") == 10 and _count(adv, "scorps", "vermelho") == 5, "fase 1: 10 escorpiões amarelos e 5 vermelhos")
	var areas_with_coins := 0
	for id: String in adv.coins:
		if (adv.coins[id] as Array).size() > 0:
			areas_with_coins += 1
	_check(areas_with_coins == 5, "moedas em todos os cenários")
	var map: WalkMap = main.walk_map
	var all_ok := true
	for id: String in adv.coins:
		var wm := WalkMap.new()
		wm.load_mask(String((main.areas[id] as Dictionary)["walk"]))
		for p: Vector2 in adv.coins[id]:
			if not wm.is_footprint_walkable(p, Walker.FOOT_HALF):
				all_ok = false
	_check(all_ok, "moedas sempre sobre o caminho")
	# Pegar uma arma: +10 dardos.
	var area_with_gun := ""
	for id: String in adv.guns:
		if (adv.guns[id] as Array).size() > 0:
			area_with_gun = id
			break
	main.call("load_area", area_with_gun, String(((main.areas[area_with_gun] as Dictionary)["spawns"] as Dictionary).keys()[0]))
	await process_frame
	var gp: Vector2 = (adv.guns[area_with_gun] as Array)[0]
	player.position = gp
	adv._invuln = 99.0
	adv.tick(0.016)
	_check(adv.darts == 10, "lançador dá 10 dardos (%d)" % adv.darts)
	# Picadas: amarelo -5%, vermelho -10% na fase 1.
	adv._stung("amarelo")
	_check(adv.health == 95, "picada amarela tira 5%% (%d)" % adv.health)
	adv._stung("vermelho")
	_check(adv.health == 85, "picada vermelha tira 10%% (%d)" % adv.health)
	# Escorpião persegue e pica.
	var sc := Scorpion.new()
	sc.setup("amarelo", map, main.get("_finder"), player, 1.0)
	sc.position = player.position + Vector2(40, 0)
	if not map.is_footprint_walkable(sc.position, Scorpion.HALF):
		sc.position = player.position
	main.get("_world").add_child(sc)
	await process_frame
	var stung := false
	for i in 240:
		if sc.tick(1.0 / 60.0, false):
			stung = true
			break
	_check(sc.chasing, "escorpião persegue quando a personagem chega perto")
	_check(stung, "escorpião alcança e pica")
	sc.queue_free()
	# Atirar: dardo elimina o escorpião mais próximo.
	adv._invuln = 99.0
	var before_kills := adv.kills
	var target := Scorpion.new()
	target.setup("amarelo", map, main.get("_finder"), player, 0.0)
	target.position = player.position + Vector2(0, 30)
	main.get("_world").add_child(target)
	(adv.get("_scorp_nodes") as Array).append(target)
	await process_frame
	var darts_before := adv.darts
	_check(adv.shoot(), "atirar com dardos disponíveis")
	_check(adv.darts == darts_before - 1, "cada tiro gasta 1 dardo")
	for i in 60:
		adv.tick(1.0 / 60.0)
	_check(adv.kills == before_kills + 1, "dardo elimina o escorpião amarelo")
	adv.darts = 0
	adv._fire_cd = 0.0
	_check(not adv.shoot(), "sem dardos não atira")
	# Coletar todas as moedas: fase 2 noturna.
	adv.coins_got = 99
	var area: String = main.current_area
	var cp: Vector2
	if (adv.coins[area] as Array).is_empty():
		(adv.coins[area] as Array).append(player.position)
		adv.on_area_loaded()
	cp = (adv.coins[area] as Array)[0]
	player.position = cp
	adv.tick(0.016)
	_check(adv.overlay_open and (adv.get("_phase_screen") as Control).visible, "com 100 moedas a fase termina")
	adv.start_phase(1)
	_check(_count(adv, "coins") == 100 and adv.health == 100, "fase 2: 100 moedas novas e vida cheia")
	await process_frame
	_check(adv.phase == 1 and adv.is_night(), "fase 2 é noturna")
	_check(_count(adv, "scorps", "amarelo") == 15 and _count(adv, "scorps", "vermelho") == 10, "fase 2: 15 amarelos e 10 vermelhos")
	adv._stung("amarelo")
	_check(adv.health == 90, "fase 2: picada amarela tira 10%")
	adv._stung("vermelho")
	_check(adv.health == 75, "fase 2: picada vermelha tira 15%")
	adv.health = 10
	adv._stung("vermelho")
	_check(adv.health == 0 and (adv.get("_over_screen") as Control).visible, "vida em 0% mostra fim de jogo")
	main.call("_back_to_title")
	_check(not adv.is_night() and not adv.active, "voltar ao início desliga a noite e o jogo")
