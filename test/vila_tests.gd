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
	for cid: String in ["antonio", "gabriel", "vini", "guilherme"]:
		_check(cbuttons.has(cid), "dá para escolher " + cid)
		(cbuttons[cid] as Button).pressed.emit()
		_check(String(main.get("character")) == cid and player.sheet_path.ends_with(cid + ".png"), "jogar com %s usa o sprite certo" % cid)
		main.call("_back_to_title")
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
	_check(adv.active and adv.phase == 0 and adv.health == 100, "nível 1 começa com 100% de vida")
	_check(_count(adv, "coins") == 30, "nível 1: 30 moedas (%d)" % _count(adv, "coins"))
	_check(_count(adv, "guns") == 13, "nível 1: 13 lançadores")
	_check(_count(adv, "scorps", "amarelo") == 3 and _count(adv, "scorps", "vermelho") == 2, "nível 1: 3 amarelos e 2 vermelhos")
	_check(not adv.is_night() and not adv.is_raining(), "nível 1 é de dia sem chuva")
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
	_check(adv.darts == 13, "nível 1: lançador dá 13 dardos (%d)" % adv.darts)
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
	# Coletar todas as moedas do nível: abre o próximo.
	adv.coins_got = adv.coins_goal() - 1
	var area: String = main.current_area
	if (adv.coins[area] as Array).is_empty():
		(adv.coins[area] as Array).append(player.position)
		adv.on_area_loaded()
	player.position = (adv.coins[area] as Array)[0]
	adv.tick(0.016)
	_check(adv.overlay_open and (adv.get("_phase_screen") as Control).visible, "com todas as moedas o nível termina")
	(adv.get("_phase_button") as Button).pressed.emit()
	_check(adv.phase == 1 and adv.is_night() and not adv.is_raining(), "nível 2 é noturno")
	var lt: PointLight2D = adv.get("_light")
	_check(lt != null and absf(lt.texture_scale - 1.3 * 0.7) < 0.01, "lanterna 30%% menor (%.2f)" % (lt.texture_scale if lt != null else -1.0))
	_check(_count(adv, "coins") == 50 and adv.health == 100, "nível 2: 50 moedas e vida cheia")
	_check(_count(adv, "scorps", "amarelo") == 8 and _count(adv, "scorps", "vermelho") == 5, "nível 2: 8 amarelos e 5 vermelhos")
	_check(_count(adv, "guns") == 11 and adv.darts_per_gun() == 11, "nível 2: 11 lançadores com 11 dardos")
	adv._invuln = 0.0
	adv._stung("amarelo")
	_check(adv.health == 90, "nível 2: picada amarela tira 10%")
	adv._stung("vermelho")
	_check(adv.health == 75, "nível 2: picada vermelha tira 15%")
	adv.start_phase(2)
	_check(adv.phase == 2 and adv.is_raining() and not adv.is_night(), "nível 3 é de dia com chuva")
	_check(_count(adv, "coins") == 100 and _count(adv, "guns") == 10 and adv.darts_per_gun() == 10, "nível 3: 100 moedas e 10 lançadores com 10 dardos")
	_check(_count(adv, "scorps", "amarelo") == 10 and _count(adv, "scorps", "vermelho") == 5, "nível 3: 10 amarelos e 5 vermelhos")
	# Dificuldade por nível: dardos para matar, velocidade e coração.
	var P: Array = Adventure.PHASES
	_check(int(P[0]["hp_yellow"]) < int(P[2]["hp_yellow"]) or int(P[0]["hp_red"]) < int(P[2]["hp_red"]), "níveis difíceis pedem mais dardos")
	_check(float(P[0]["speed"]) < float(P[1]["speed"]) and float(P[1]["speed"]) < float(P[2]["speed"]), "escorpiões ficam mais rápidos a cada nível")
	_check(int(P[0]["heart_every"]) < int(P[2]["heart_every"]) and int(P[0]["heart_heal"]) > int(P[2]["heart_heal"]), "coração mais raro e fraco nos níveis difíceis")
	var hp_ok := true
	for scx: Scorpion in adv.get("_scorp_nodes"):
		if scx.hp != adv.scorpion_hp(scx.kind) or absf(scx.speed_mult - float(P[2]["speed"])) > 0.001:
			hp_ok = false
	_check(hp_ok, "escorpiões do nível 3 têm vida e velocidade do nível")
	# Nível 4: noite com chuva.
	adv.start_phase(3)
	_check(adv.phase == 3 and adv.is_night() and adv.is_raining(), "nível 4 é noite com chuva")
	_check(_count(adv, "coins") == 100 and _count(adv, "guns") == 12 and adv.darts_per_gun() == 12, "nível 4: 100 moedas e 12 lançadores com 12 dardos")
	_check(_count(adv, "scorps", "amarelo") == 15 and _count(adv, "scorps", "vermelho") == 10, "nível 4: 15 amarelos e 10 vermelhos")
	_check(adv.scorpion_hp("amarelo") == 3 and adv.scorpion_hp("vermelho") == 5 and adv.heart_every() == 5 and adv.heart_heal() == 10, "nível 4: 3/5 dardos e coração a cada 5 (+10%)")
	var ag_ok := true
	for scy: Scorpion in adv.get("_scorp_nodes"):
		if absf(scy.aggro_mult - 1.25) > 0.001 or absf(scy.speed_mult - 1.3) > 0.001:
			ag_ok = false
	_check(ag_ok, "nível 4: escorpiões 130% mais velozes e perseguem de mais longe")
	_check(adv.get("_rain") != null and adv.get("_night_mod") != null and adv.get("_rain_mod") == null, "noite com chuva usa a escuridão da noite e a chuva por cima")
	adv._invuln = 0.0
	var hb := adv.health
	adv._stung("vermelho")
	_check(adv.health == hb - 20, "nível 4: picada vermelha tira 20%")
	# Folga de munição diminui a cada nível.
	var prev_ratio := 1e9
	var ratio_ok := true
	for ph: Dictionary in Adventure.PHASES:
		var need := int(ph["yellow"]) * int(ph["hp_yellow"]) + int(ph["red"]) * int(ph["hp_red"])
		var ratio := float(int(ph["guns"]) * int(ph["darts"])) / float(need)
		if ratio >= prev_ratio:
			ratio_ok = false
		prev_ratio = ratio
	_check(ratio_ok and prev_ratio > 1.0, "folga de munição cai a cada nível e o nível 4 ainda dá conta (%.2f×)" % prev_ratio)
	adv.start_phase(2)
	adv.health = 50
	adv.set("_kills_to_heart", 1)
	var hearts_before := (adv.get("_heart_nodes") as Array).size()
	adv._on_kill(player.position)
	_check((adv.get("_heart_nodes") as Array).size() == hearts_before + 1, "coração aparece após as mortes necessárias")
	adv._update_minimap()
	var has_heart_dot := false
	for d: Array in (main.get("_minimap") as Minimap).dots:
		if String(d[1]) == "coracao":
			has_heart_dot = true
	_check(has_heart_dot, "minimapa mostra o coração")
	adv._invuln = 99.0
	adv.tick(0.016)
	_check(adv.health == 50 + adv.heart_heal(), "coração recupera %d%% (%d)" % [adv.heart_heal(), adv.health])
	_check((adv.get("_heart_nodes") as Array).size() == hearts_before, "coração some ao ser pego")
	adv._invuln = 0.0
	await process_frame
	adv.health = 10
	adv._stung("vermelho")
	_check(adv.health == 0 and (adv.get("_over_screen") as Control).visible, "vida em 0% mostra fim de jogo")
	var mm: Minimap = main.get("_minimap")
	adv._update_minimap()
	var kinds := {}
	for d: Array in mm.dots:
		kinds[String(d[1])] = true
	_check(mm.show_legend and int(mm.counts["moeda"]) == (adv.get("_coin_nodes") as Array).size(), "minimapa conta as moedas da tela")
	_check(int(mm.counts["moeda_total"]) == _count(adv, "coins") and int(mm.counts["arma_total"]) == _count(adv, "guns") + _count(adv, "soakers") + _count(adv, "spreaders"), "minimapa mostra o total do nível")
	_check(mm.dots.size() == (adv.get("_coin_nodes") as Array).size() + (adv.get("_gun_nodes") as Array).size() + (adv.get("_scorp_nodes") as Array).size(), "minimapa marca moedas, Nerfs e escorpiões")
	# Nome da tela e nova ligação estacionamento → rua direita.
	_check(String(main.areas["condominio"]["title"]) == "Térreo", "tela principal se chama Térreo")
	var ex_ok := false
	for e: Dictionary in main.areas["estacionamento"]["exits"]:
		if String(e["to"]) == "direita" and int((e["rect"] as Array)[1]) == 0 and int((e["rect"] as Array)[0]) > 450 and int((e["rect"] as Array)[0]) < 700:
			ex_ok = true
	_check(ex_ok, "estacionamento liga à rua direita pela borda de cima")
	# Troca de personagem sem reiniciar.
	adv.health = 70
	var pos_before: Vector2 = player.position
	var phase_before: int = adv.phase
	var coins_before: int = adv.coins_got
	main.swap_character("gabriel")
	_check(String(main.character) == "gabriel" and adv.phase == phase_before and adv.health == 70 and adv.coins_got == coins_before and adv.active, "troca de personagem mantém o nível")
	_check(player.position.distance_to(pos_before) < 0.1, "troca de personagem mantém a posição")
	# Mapa em tela cheia.
	adv.overlay_open = false
	main.set("_paused", false)
	main.open_map()
	var ms: MapScreen = main.get("_map_screen")
	_check(ms.is_open() and bool(main.get("_paused")), "clicar no minimapa abre o mapa em tela cheia e pausa")
	ms.show_area("estacionamento")
	var md: Dictionary = adv.markers_for("estacionamento")
	_check(ms.current_tab() == "estacionamento" and (ms.get("_map") as Minimap).dots.size() == (md["dots"] as Array).size(), "mapa troca de cenário e mostra os itens dele")
	ms.close()
	_check(not ms.is_open() and not bool(main.get("_paused")), "Voltar fecha o mapa e retoma o jogo")
	# Escada: mais devagar e a personagem desce visualmente.
	main.load_area("condominio", "inicio")
	var st_r := Rect2(100, 586, 52, 26)
	player.position = Vector2(146, 599)
	_check(player.on_stairs() and player.stair_progress() < 0.3, "topo da escada reconhecido (%.2f)" % player.stair_progress())
	var p0: Vector2 = player.position
	for i in 6:
		player.step(Vector2.LEFT, false, 1.0 / 60.0)
	var on_d := player.position.distance_to(p0)
	player.position = Vector2(630, 790)
	p0 = player.position
	for i in 6:
		player.step(Vector2.LEFT, false, 1.0 / 60.0)
	var off_d := player.position.distance_to(p0)
	_check(on_d > 0.0 and on_d < off_d * 0.7, "na escada anda mais devagar (%.1f vs %.1f)" % [on_d, off_d])
	player.position = Vector2(104, 599)
	for i in 40:
		player.step(Vector2.ZERO, false, 1.0 / 60.0)
	var spr: AnimatedSprite2D = player.get("_sprite")
	_check(player.stair_progress() > 0.8 and spr.scale.x < 0.92 and spr.position.y > 3.0, "no pé da escada a personagem fica mais baixa e menor")
	player.position = Vector2(630, 790)
	for i in 40:
		player.step(Vector2.ZERO, false, 1.0 / 60.0)
	_check(absf(spr.scale.x - 1.0) < 0.02 and absf(spr.position.y) < 0.5, "fora da escada volta ao normal")
	# Carros do estacionamento bloqueiam.
	main.load_area("estacionamento", "oeste")
	var car_ok := true
	for cp: Vector2 in [Vector2(716, 526), Vector2(766, 570), Vector2(825, 638), Vector2(902, 715)]:
		if main.walk_map.is_point_walkable(cp):
			car_ok = false
	_check(car_ok, "carros estacionados não são caminháveis")
	main.load_area("condominio", "inicio")
	# ---------------- Armas novas
	adv.new_game()
	var tot_so := 0
	var tot_sp := 0
	var in_terreo := 0
	for aid: String in adv.soakers:
		tot_so += (adv.soakers[aid] as Array).size()
		if aid == "condominio":
			in_terreo += (adv.soakers[aid] as Array).size()
	for aid: String in adv.spreaders:
		tot_sp += (adv.spreaders[aid] as Array).size()
		if aid == "condominio":
			in_terreo += (adv.spreaders[aid] as Array).size()
	_check(tot_so == 1 and tot_sp == 0 and in_terreo == 0, "nível 1: 1 Super Soaker, 0 Espalhadora, fora do Térreo (%d/%d)" % [tot_so, tot_sp])
	adv.start_phase(3)
	tot_so = 0
	tot_sp = 0
	for aid: String in adv.soakers:
		tot_so += (adv.soakers[aid] as Array).size()
	for aid: String in adv.spreaders:
		tot_sp += (adv.spreaders[aid] as Array).size()
	_check(tot_so == 1 and tot_sp == 2, "nível 4: 1 Super Soaker e 2 Espalhadoras (%d/%d)" % [tot_so, tot_sp])
	adv.start_phase(0)
	_check(not adv.select_weapon("soaker") and adv.weapon == "nerf", "não troca para arma que ainda não pegou")
	# Pegar a Soaker em outra tela.
	var sk_area := ""
	for aid: String in adv.soakers:
		if (adv.soakers[aid] as Array).size() > 0:
			sk_area = aid
	main.load_area(sk_area, (main.areas[sk_area]["spawns"] as Dictionary).keys()[0])
	player.position = (adv.soakers[sk_area] as Array)[0]
	adv._invuln = 99.0
	adv.tick(0.016)
	_check(adv.has_soaker and adv.weapon == "soaker" and is_equal_approx(adv.water, 100.0), "pegar a Super Soaker enche o tanque e equipa")
	# Jato: molha, deixa lento, dá dano e gasta água.
	for scx: Scorpion in adv.get("_scorp_nodes"):
		scx.position = player.position + Vector2(-400, -400)
	var sc0 := Scorpion.new()
	sc0.setup("vermelho", main.walk_map, main._finder, player, 1.0)
	sc0.hp = 2
	sc0.position = player.position + Vector2(50, 0)
	main._world.add_child(sc0)
	(adv.get("_scorp_nodes") as Array).append(sc0)
	adv.aim_point = sc0.position + Vector2(0, -4)
	adv.fire_held = true
	var w0: float = adv.water
	adv.tick(0.05)
	_check(sc0.slow_t > 1.5 and sc0.hp == 1, "jato molha (lento) e tira 1 de vida")
	for i in 12:
		adv.fire_held = true
		adv.aim_point = sc0.position + Vector2(0, -4) if is_instance_valid(sc0) else Vector2.INF
		adv.tick(0.05)
	_check(not (adv.get("_scorp_nodes") as Array).has(sc0), "jato contínuo elimina o escorpião")
	_check(adv.water < w0 - 10.0, "jato gasta água (%.0f%%)" % adv.water)
	adv.fire_held = false
	adv.aim_point = Vector2.INF
	adv.tick(0.016)
	var jet: WaterJet = adv.get("_jet")
	_check(jet != null and not jet.visible, "soltar o botão para o jato")
	# Recarga perto da piscina do Térreo.
	main.load_area("condominio", "inicio")
	player.position = Vector2(700, 640)
	var wp := Vector2.INF
	for yy in range(480, 820, 8):
		for xx in range(500, 840, 8):
			if wp == Vector2.INF and adv.near_water(Vector2(xx, yy)) and main.walk_map.is_footprint_walkable(Vector2(xx, yy), Walker.FOOT_HALF):
				wp = Vector2(xx, yy)
	_check(wp != Vector2.INF and not adv.near_water(Vector2(140, 599)), "há borda de piscina caminhável para recarregar")
	player.position = wp
	adv.water = 10.0
	adv.tick(1.0)
	_check(adv.water > 40.0, "perto da água o tanque recarrega (%.0f%%)" % adv.water)
	# Chuva recarrega devagar em qualquer lugar.
	adv.start_phase(2)
	adv.has_soaker = true
	player.position = Vector2(140, 599)
	adv.water = 0.0
	adv.tick(1.0)
	_check(adv.water > 3.0 and adv.water < 8.0, "na chuva a Soaker recarrega devagar (%.1f%%)" % adv.water)
	# Espalhadora: 5 dardos, 1 cartucho, alcance curto.
	adv.has_spreader = true
	adv.cartridges = 2
	_check(adv.select_weapon("espalhadora"), "troca para a Espalhadora")
	var nd := (adv.get("_dart_nodes") as Array).size()
	adv.set("_fire_cd", 0.0)
	adv.shoot(player.position + Vector2(100, 0))
	var darts_now: Array = adv.get("_dart_nodes")
	_check(darts_now.size() - nd == 5 and adv.cartridges == 1, "Espalhadora solta 5 dardos e gasta 1 cartucho")
	var ang_ok := true
	for dd: Dart in darts_now.slice(nd):
		var base_dir := (player.position + Vector2(100, 0) - (player.position + Vector2(0, -12))).normalized()
		if absf(dd.velocity.angle_to(base_dir)) > deg_to_rad(21) or dd.max_range > 150.0:
			ang_ok = false
	_check(ang_ok, "dardos em leque de 40° e alcance curto")
	adv.set("_fire_cd", 0.0)
	adv.cartridges = 0
	_check(not adv.shoot(player.position + Vector2(100, 0)), "sem cartuchos não atira")
	# Troca com Q (ciclo) e o painel mostra a arma.
	adv.select_weapon("nerf")
	adv.cycle_weapon()
	_check(adv.weapon == "soaker", "Q passa para a próxima arma que você tem")
	_check(String((adv.get("_dart_label") as Label).text).begins_with("Água"), "painel mostra a munição da arma atual")
	var mk: Dictionary = adv.markers_for(String(main.current_area))
	_check(mk.has("dots"), "minimapa aceita as armas novas")
	adv.start_phase(0)
	main.call("_back_to_title")
	_check(not adv.is_night() and not adv.is_raining() and not adv.active, "voltar ao início desliga noite, chuva e o jogo")
