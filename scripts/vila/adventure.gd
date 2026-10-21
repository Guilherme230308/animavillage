class_name Adventure
extends Node
## Regras do jogo: moedas, escorpiões, lançadores Nerf, vida e fases (dia e noite).
## Os itens ficam espalhados por todas as telas e lembram o estado ao sair e voltar.

const SPAWN_POINTS := "res://assets/game/spawn_points.json"
const ProceduralSfx = preload("res://scripts/manus/procedural_sfx.gd")
## Níveis. Bases: dia = 100 moedas, 10 amarelos, 5 vermelhos; noite = 100 moedas, 15 amarelos, 10 vermelhos;
## 10 lançadores com 10 dardos. Nível 1: −70% moedas/escorpiões, +30% armas/dardos.
## Nível 2: −50% moedas/escorpiões, +10% armas/dardos. Nível 3: quantidades originais do dia.
const PHASES := [
	{"name": "Nível 1 · Dia (fácil)", "soakers": 1, "spreaders": 0, "short": "nível 1", "coins": 30, "yellow": 3, "red": 2, "guns": 13, "darts": 13,
		"dmg_yellow": 5, "dmg_red": 10, "night": false, "rain": false, "speed": 0.8, "aggro": 0.8,
		"hp_yellow": 1, "hp_red": 2, "heart_every": 2, "heart_heal": 30},
	{"name": "Nível 2 · Noite", "soakers": 1, "spreaders": 1, "short": "nível 2", "coins": 50, "yellow": 8, "red": 5, "guns": 11, "darts": 11,
		"dmg_yellow": 10, "dmg_red": 15, "night": true, "rain": false, "speed": 1.0, "aggro": 1.0,
		"hp_yellow": 2, "hp_red": 3, "heart_every": 3, "heart_heal": 20},
	{"name": "Nível 3 · Dia com chuva", "soakers": 2, "spreaders": 1, "short": "nível 3", "coins": 100, "yellow": 10, "red": 5, "guns": 10, "darts": 10,
		"dmg_yellow": 10, "dmg_red": 15, "night": false, "rain": true, "speed": 1.0, "aggro": 1.1,
		"hp_yellow": 2, "hp_red": 4, "heart_every": 4, "heart_heal": 15},
	{"name": "Nível 4 · Noite com chuva", "soakers": 1, "spreaders": 2, "short": "nível 4", "coins": 100, "yellow": 15, "red": 10, "guns": 12, "darts": 12,
		"dmg_yellow": 15, "dmg_red": 20, "night": true, "rain": true, "speed": 1.0, "aggro": 1.25,
		"hp_yellow": 3, "hp_red": 5, "heart_every": 5, "heart_heal": 10},
]
const FIRE_COOLDOWN := 0.28
const AIM_RANGE := 260.0
## Super Soaker: jato contínuo em cone curto; molha (lento 50%) e dá 1 de dano a cada SOAK_TICK.
const SOAK_RANGE := 95.0
const SOAK_HALF_ANGLE := 18.0
const SOAK_DRAIN := 22.0
const SOAK_TICK := 0.5
const SOAK_SFX_GAP := 0.22
const SOAK_SLOW := 2.0
const REFILL_POOL := 35.0
const REFILL_RAIN := 5.0
const WATER_MASK := "res://assets/game/areas/condominio/water.png"
## Espalhadora: 5 dardos em leque de 40°, alcance curto; cada tiro gasta 1 cartucho.
const SPREAD_COUNT := 5
const SPREAD_ANGLE := 40.0
const SPREAD_RANGE := 140.0
const SPREAD_CD := 0.6
const CARTRIDGES_PER_PICKUP := 4
const WEAPONS := ["nerf", "soaker", "espalhadora"]
const WEAPON_NAMES := {"nerf": "Nerf", "soaker": "Super Soaker", "espalhadora": "Espalhadora"}
## Chuva (níveis 3 e 4). Números de jogo, no mesmo lugar das outras regras da vila.
const PUDDLE_SLOW := 0.70
const DART_RAIN_RANGE := 0.70
const COAT_SECONDS := 20.0
const COAT_DAMAGE := 0.5
const SHELTER_HEAL := 5
const SLIP_BRAKE := 95.0
const PUDDLE_COUNT := 5
## Começa menor e cresce até a largura do passeio. O teto absoluto fica abaixo do antigo 38.
const PUDDLE_START_R := 10.0
const PUDDLE_MAX_R := 22.0
const PUDDLE_GROW := 1.8
const DRAIN_COUNT := 3
const DRAIN_INTERVAL := 8.0
const DRAIN_CAP := 6
const DRAIN_SEAL_TIME := 2.0
const DRAIN_NEAR := 28.0
const REVEAL_TIME := 1.0
const REVEAL_GAP := 8.0
const STRIKE_DELAY := 1.5
const STRIKE_DAMAGE := 10
const STRIKE_RADIUS := 46.0
const STRIKE_GAP := 11.0
const WEAPON_HELP := "Armas: Nerf (dardos), Super Soaker (molha e deixa lento), Espalhadora (cinco dardos em leque)."

var main: Node
var active := false
var phase := 0
var health := 100
var darts := 0
var weapon := "nerf"
var has_soaker := false
var water := 0.0
var has_spreader := false
var cartridges := 0
## Botão de atirar segurado (a Super Soaker atira enquanto segura) e ponto mirado com o mouse.
var fire_held := false
var aim_point := Vector2.INF
var soakers: Dictionary = {}
var spreaders: Dictionary = {}
var _soaker_nodes: Array = []
var _spreader_nodes: Array = []
var _jet: WaterJet
var _soak_tick := 0.0
var _soak_audio := 0.0
var _sfx_ready := false
var _burst := 0.0
var _empty_warned := false
var _water_img: Image
var _weapon_icon: TextureRect
var _weapons_label: Label
var coins_got := 0
var kills := 0
var overlay_open := false
## Estado por tela: posições das moedas e armas restantes e escorpiões vivos.
var coins: Dictionary = {}
var guns: Dictionary = {}
var scorps: Dictionary = {}
## Corações soltos por área (posições).
var hearts: Dictionary = {}
var _heart_nodes: Array = []
var _kills_to_heart := 0
var _points: Dictionary = {}
var _darts_at_phase_start := 0
var _coin_nodes: Array = []
var _gun_nodes: Array = []
var _scorp_nodes: Array = []
var _dart_nodes: Array = []
var _invuln := 0.0
var _fire_cd := 0.0
var _night_mod: CanvasModulate
var _light: PointLight2D
var _rain_mod: CanvasModulate
var _rain: RainLayer
var _rground: RainGround
## Poças, capa e bueiros por tela. A capa ativa conta em coat_t.
var puddles: Dictionary = {}
var coats: Dictionary = {}
var _coat_nodes: Array = []
var coat_t := 0.0
var drains: Array = []
var _drain_cd := 8.0
var _reveal_t := 0.0
var _reveal_cd := 8.0
var _bolt_cd := 11.0
var _bolt: Dictionary = {}
var _shelter_known := false
var _in_shelter := false
# Interface
var _stats: PanelContainer
var _phase_label: Label
var _hp_fill: ColorRect
var _hp_back: ColorRect
var _hp_label: Label
var _coin_label: Label
var _dart_label: Label
var _toast: Label
var _toast_tween: Tween
var _phase_screen: Control
var _phase_text: Label
var _phase_button: Button
var _over_screen: Control
var _over_text: Label
var _over_button: Button
var _win_screen: Control
var _win_text: Label
var _win_button: Button


func _ready() -> void:
	_points = JSON.parse_string(FileAccess.get_file_as_string(SPAWN_POINTS))
	_build_ui()
	_arm_sfx()


# ---------------------------------------------------------------- fases

func coins_goal() -> int:
	return int(PHASES[phase]["coins"])


func scorpion_hp(kind: String) -> int:
	return int(PHASES[phase]["hp_yellow"] if kind == "amarelo" else PHASES[phase]["hp_red"])


func heart_every() -> int:
	return int(PHASES[phase]["heart_every"])


func heart_heal() -> int:
	return int(PHASES[phase]["heart_heal"])


func darts_per_gun() -> int:
	return int(PHASES[phase]["darts"])


func new_game(phase_idx: int = 0) -> void:
	darts = 0
	weapon = "nerf"
	has_soaker = false
	water = 0.0
	has_spreader = false
	cartridges = 0
	start_phase(clampi(phase_idx, 0, PHASES.size() - 1))


## Volta ao início do nível atual, com os dardos que havia ao começar.
func restart_phase() -> void:
	darts = _darts_at_phase_start
	start_phase(phase)


func start_phase(idx: int) -> void:
	phase = idx
	# Desliga durante a recarga para não sobrescrever o estado novo com o da tela anterior.
	active = false
	_clear_nodes()
	health = 100
	coins_got = 0
	kills = 0
	hearts = {}
	_kills_to_heart = heart_every()
	_darts_at_phase_start = darts
	_invuln = 0.0
	coat_t = 0.0
	_shelter_known = false
	_in_shelter = false
	_bolt = {}
	_reveal_t = 0.0
	_reveal_cd = REVEAL_GAP
	_bolt_cd = STRIKE_GAP
	_drain_cd = DRAIN_INTERVAL
	if main._player != null:
		main._player.set_weather_move(1.0, 0.0)
	_place_everything()
	_apply_rain(false)
	_apply_night(bool(PHASES[phase]["night"]))
	_apply_rain(bool(PHASES[phase]["rain"]))
	_hide_overlays()
	main.load_area(main.START_AREA, main.START_SPAWN)
	active = true
	on_area_loaded()
	_invuln = 1.5
	_refresh_stats()
	main._show_banner(level_banner(phase), 3.2)
	_show_toast("Colete as %d moedas!" % coins_goal(), 3.0)
	if main.has_method("arm_play_tips"):
		main.arm_play_tips()
	if main.has_method("_relayout"):
		main._relayout()


func stop() -> void:
	active = false
	_clear_nodes()
	_apply_night(false)
	_apply_rain(false)
	_hide_overlays()
	if main._minimap != null:
		main._minimap.dots = []
		main._minimap.show_legend = false
	if _stats != null:
		_stats.visible = false


func _place_everything() -> void:
	var ids: Array = (main.areas as Dictionary).keys()
	var weights := {}
	for id: String in ids:
		weights[id] = pow(float((_points.get(id, []) as Array).size()), 0.7)
	var cfg: Dictionary = PHASES[phase]
	var n_coins := _distribute(coins_goal(), weights, 3)
	var n_guns := _distribute(int(cfg["guns"]), weights, 1)
	var n_yel := _distribute(int(cfg["yellow"]), weights, 1)
	var n_red := _distribute(int(cfg["red"]), weights, 0)
	# Armas especiais ficam nas telas mais distantes (fora do Térreo).
	var far: Array = ids.filter(func(x: String) -> bool: return x != "condominio")
	if far.is_empty():
		far = ids
	var n_soak := _far_counts(int(cfg.get("soakers", 0)), far)
	var n_spread := _far_counts(int(cfg.get("spreaders", 0)), far)
	coins.clear()
	guns.clear()
	scorps.clear()
	soakers.clear()
	spreaders.clear()
	for id: String in ids:
		var pts: Array = (_points.get(id, []) as Array).duplicate()
		pts.shuffle()
		var taken: Array[Vector2] = []
		var safe: Array[Vector2] = []
		for s: Array in ((main.areas[id] as Dictionary)["spawns"] as Dictionary).values():
			safe.append(Vector2(float(s[0]), float(s[1])))
		var cl: Array[Vector2] = _pick(pts, int(n_coins[id]), 38.0, taken, safe, 45.0)
		coins[id] = cl
		taken.append_array(cl)
		var gl: Array[Vector2] = _pick(pts, int(n_guns[id]), 70.0, taken, safe, 45.0)
		guns[id] = gl
		taken.append_array(gl)
		var far_pts := _far_points(pts, safe)
		var sk: Array[Vector2] = _pick(far_pts, int(n_soak.get(id, 0)), 90.0, taken, safe, 120.0)
		soakers[id] = sk
		taken.append_array(sk)
		var sp: Array[Vector2] = _pick(far_pts, int(n_spread.get(id, 0)), 90.0, taken, safe, 120.0)
		spreaders[id] = sp
		taken.append_array(sp)
		var sl: Array = []
		for k: String in ["amarelo", "vermelho"]:
			var n := int((n_yel if k == "amarelo" else n_red)[id])
			for p: Vector2 in _pick(pts, n, 70.0, taken, safe, 170.0):
				sl.append({"kind": k, "pos": p})
				taken.append(p)
		scorps[id] = sl
	_place_rain()


## Reparte poucas armas especiais entre as telas distantes, uma por tela antes de repetir.
func _far_counts(total: int, far: Array) -> Dictionary:
	var out := {}
	var order := far.duplicate()
	order.shuffle()
	for i in total:
		var id: String = order[i % order.size()]
		out[id] = int(out.get(id, 0)) + 1
	return out


## Pontos mais afastados das entradas da tela (o terço mais distante, embaralhado).
func _far_points(pts: Array, safe: Array) -> Array:
	var scored: Array = []
	for p: Array in pts:
		var v := Vector2(float(p[0]), float(p[1]))
		var dmin := 1e9
		for q: Vector2 in safe:
			dmin = minf(dmin, v.distance_to(q))
		scored.append([dmin, p])
	scored.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])
	var out: Array = []
	for i in maxi(1, scored.size() / 3):
		if i < scored.size():
			out.append(scored[i][1])
	out.shuffle()
	return out


## Reparte `total` entre as telas proporcionalmente ao peso, com um mínimo por tela.
func _distribute(total: int, weights: Dictionary, min_each: int) -> Dictionary:
	var out := {}
	var ids: Array = weights.keys()
	var base := mini(min_each, total / maxi(1, ids.size()))
	var rest := total - base * ids.size()
	var sum := 0.0
	for id: String in ids:
		sum += float(weights[id])
	var fracs: Array = []
	var given := 0
	for id: String in ids:
		var exact := rest * float(weights[id]) / maxf(sum, 0.001)
		out[id] = base + int(floor(exact))
		given += int(floor(exact))
		fracs.append([exact - floor(exact), id])
	fracs.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])
	var i := 0
	while given < rest:
		out[fracs[i % fracs.size()][1]] += 1
		given += 1
		i += 1
	return out


func _pick(pts: Array, n: int, spacing: float, taken: Array[Vector2], avoid: Array, avoid_r: float) -> Array[Vector2]:
	var out: Array[Vector2] = []
	var gap := spacing
	while out.size() < n and gap >= 6.0:
		for p: Array in pts:
			if out.size() >= n:
				break
			var v := Vector2(float(p[0]), float(p[1]))
			var ok := true
			for q: Vector2 in taken + out:
				if v.distance_to(q) < gap:
					ok = false
					break
			if ok:
				for q: Vector2 in avoid:
					if v.distance_to(q) < avoid_r:
						ok = false
						break
			if ok:
				out.append(v)
		gap *= 0.6
	return out


# ---------------------------------------------------------------- telas

## Chamado antes de a tela atual ser descarregada: guarda onde os escorpiões estão.
func on_area_leaving() -> void:
	if not active or main.current_area == "":
		return
	var sl: Array = []
	for s: Scorpion in _scorp_nodes:
		if is_instance_valid(s):
			sl.append({"kind": s.kind, "pos": s.position, "hp": s.hp, "from_drain": s.from_drain})
	scorps[main.current_area] = sl
	_bolt = {}
	_clear_nodes()


func on_area_loaded() -> void:
	_clear_nodes()
	if not active:
		return
	var id: String = main.current_area
	main.ensure_finder()
	var world: Node2D = main._world
	for p: Vector2 in coins.get(id, []):
		_coin_nodes.append(_spawn_pickup("moeda", p, world))
	for p: Vector2 in guns.get(id, []):
		_gun_nodes.append(_spawn_pickup("arma", p, world))
	for p: Vector2 in soakers.get(id, []):
		_soaker_nodes.append(_spawn_pickup("soaker", p, world))
	for p: Vector2 in spreaders.get(id, []):
		_spreader_nodes.append(_spawn_pickup("espalhadora", p, world))
	for d: Dictionary in scorps.get(id, []):
		var s := Scorpion.new()
		s.setup(String(d["kind"]), main.walk_map, main._finder, main._player, float(PHASES[phase]["speed"]))
		s.hp = int(d["hp"]) if d.has("hp") else scorpion_hp(String(d["kind"]))
		s.aggro_mult = float(PHASES[phase]["aggro"])
		s.from_drain = bool(d.get("from_drain", false))
		s.avoid = Callable(self, "in_puddle")
		s.position = d["pos"]
		world.add_child(s)
		_scorp_nodes.append(s)
	for p: Vector2 in coats.get(id, []):
		_coat_nodes.append(_spawn_pickup("capa", p, world))
	_cull_sheltered_puddles(id)
	for p: Vector2 in hearts.get(id, []):
		_heart_nodes.append(_spawn_pickup("coracao", p, world))
	_invuln = maxf(_invuln, 1.0)
	_sync_rain_ground()
	_update_minimap()


func _spawn_pickup(kind: String, p: Vector2, world: Node2D) -> Pickup:
	var n := Pickup.new()
	n.kind = kind
	n.position = p
	world.add_child(n)
	return n


func _clear_nodes() -> void:
	if _jet != null:
		_jet.visible = false
	for arr: Array in [_coin_nodes, _gun_nodes, _scorp_nodes, _dart_nodes, _heart_nodes, _soaker_nodes, _spreader_nodes, _coat_nodes]:
		for n: Node in arr:
			if is_instance_valid(n):
				n.queue_free()
		arr.clear()


# ---------------------------------------------------------------- jogo

func tick(delta: float) -> void:
	if not active or overlay_open:
		return
	if is_raining():
		_audio().play_bed("vila.rain")
	var player: Walker = main._player
	var id: String = main.current_area
	_fire_cd = maxf(0.0, _fire_cd - delta)
	_invuln = maxf(0.0, _invuln - delta)
	player.modulate.a = 1.0 if _invuln <= 0.0 or int(_invuln * 12.0) % 2 == 0 else 0.35
	_update_weather(delta)
	if overlay_open:
		return
	# Moedas
	for i in range(_coin_nodes.size() - 1, -1, -1):
		var c: Pickup = _coin_nodes[i]
		if c.position.distance_to(player.position) < 13.0:
			(coins[id] as Array).erase(c.position)
			c.queue_free()
			_coin_nodes.remove_at(i)
			coins_got += 1
			_refresh_stats()
			if coins_got >= coins_goal():
				_phase_complete()
				return
	# Armas
	for i in range(_gun_nodes.size() - 1, -1, -1):
		var g: Pickup = _gun_nodes[i]
		if g.position.distance_to(player.position) < 15.0:
			(guns[id] as Array).erase(g.position)
			g.queue_free()
			_gun_nodes.remove_at(i)
			darts += darts_per_gun()
			_refresh_stats()
			_show_toast("Lançador Nerf! +%d dardos (Espaço ou F para atirar)" % darts_per_gun() if not main.touch_mode else "Lançador Nerf! +%d dardos (botão Atirar)" % darts_per_gun())
	# Super Soaker
	for i in range(_soaker_nodes.size() - 1, -1, -1):
		var w: Pickup = _soaker_nodes[i]
		if w.position.distance_to(player.position) < 15.0:
			(soakers[id] as Array).erase(w.position)
			w.queue_free()
			_soaker_nodes.remove_at(i)
			var first := not has_soaker
			has_soaker = true
			water = 100.0
			_empty_warned = false
			if first:
				weapon = "soaker"
				_show_toast("Super Soaker! Segure %s para molhar: escorpião molhado fica lento. Recarregue perto das piscinas e da fonte" % ("Atirar" if main.touch_mode else "Espaço/F ou o botão direito"), 3.2)
			else:
				_show_toast("Super Soaker: tanque cheio (100%)", 1.6)
			_refresh_stats()
	# Espalhadora
	for i in range(_spreader_nodes.size() - 1, -1, -1):
		var w: Pickup = _spreader_nodes[i]
		if w.position.distance_to(player.position) < 15.0:
			(spreaders[id] as Array).erase(w.position)
			w.queue_free()
			_spreader_nodes.remove_at(i)
			var first := not has_spreader
			has_spreader = true
			cartridges += CARTRIDGES_PER_PICKUP
			if first:
				weapon = "espalhadora"
				_show_toast("Espalhadora! 5 dardos em leque, de perto. +%d cartuchos (%s troca de arma)" % [CARTRIDGES_PER_PICKUP, "Trocar Arma" if main.touch_mode else "1/2/3 ou Q"], 3.0)
			else:
				_show_toast("Espalhadora: +%d cartuchos" % CARTRIDGES_PER_PICKUP, 1.6)
			_refresh_stats()
	# Capa de chuva (uma por nível chuvoso).
	for i in range(_coat_nodes.size() - 1, -1, -1):
		var coat: Pickup = _coat_nodes[i]
		if coat.position.distance_to(player.position) < 15.0:
			(coats[id] as Array).erase(coat.position)
			coat.queue_free()
			_coat_nodes.remove_at(i)
			coat_t = COAT_SECONDS
			_refresh_stats()
			_show_toast("Capa de chuva! %ds sem escorregar e com metade do dano" % int(COAT_SECONDS), 2.4)
	# Corações
	for i in range(_heart_nodes.size() - 1, -1, -1):
		var h: Pickup = _heart_nodes[i]
		if h.position.distance_to(player.position) < 14.0:
			(hearts[id] as Array).erase(h.position)
			h.queue_free()
			_heart_nodes.remove_at(i)
			var before := health
			health = mini(100, health + heart_heal())
			_refresh_stats()
			_show_toast("Coração! +%d%% de vida" % (health - before) if health > before else "Coração! A vida já está cheia", 1.6)
	# Escorpiões
	var hidden: bool = main.is_occluded(player.position)
	for s: Scorpion in _scorp_nodes:
		s.set_revealed(_reveal_t > 0.0 and _in_view(s.position))
		if s.tick(delta, hidden) and _invuln <= 0.0:
			_stung(s.kind)
			if overlay_open:
				return
	# Super Soaker (jato contínuo e recarga)
	_update_soaker(delta, player)
	if overlay_open:
		return
	# Dardos
	for i in range(_dart_nodes.size() - 1, -1, -1):
		var d: Dart = _dart_nodes[i]
		var alive := d.advance(delta)
		for j in range(_scorp_nodes.size() - 1, -1, -1):
			var s: Scorpion = _scorp_nodes[j]
			if d.position.distance_to(s.position + Vector2(0, -4)) < 11.0:
				alive = false
				if s.hit():
					_kill_scorpion(j)
				break
		if not alive:
			d.queue_free()
			_dart_nodes.remove_at(i)
	_update_minimap()


func _kill_scorpion(j: int) -> void:
	var s: Scorpion = _scorp_nodes[j]
	_puff(s.position, s.kind)
	_sfx("vila.scorpion")
	s.queue_free()
	_scorp_nodes.remove_at(j)
	kills += 1
	_on_kill(s.position)


## Perto das piscinas ou da fonte do Térreo (onde a Super Soaker recarrega).
func near_water(p: Vector2) -> bool:
	if String(main.current_area) != "condominio":
		return false
	if _water_img == null:
		var tex := load(WATER_MASK) as Texture2D
		if tex == null:
			return false
		_water_img = tex.get_image()
		if _water_img.is_compressed():
			_water_img.decompress()
	var x := int(p.x / 8.0)
	var y := int(p.y / 8.0)
	if x < 0 or y < 0 or x >= _water_img.get_width() or y >= _water_img.get_height():
		return false
	return _water_img.get_pixel(x, y).r > 0.5


func _update_soaker(delta: float, player: Walker) -> void:
	if not has_soaker:
		return
	var refill := 0.0
	if is_raining():
		refill += REFILL_RAIN
	if near_water(player.position):
		refill += REFILL_POOL
	if refill > 0.0 and water < 100.0:
		water = minf(100.0, water + refill * delta)
		if water > 5.0:
			_empty_warned = false
		_refresh_stats()
	_burst = maxf(0.0, _burst - delta)
	var spraying := weapon == "soaker" and (fire_held or _burst > 0.0) and water > 0.0
	if not spraying:
		if _jet != null:
			_jet.visible = false
		_soak_tick = 0.0
		_soak_audio = 0.0
		if weapon == "soaker" and fire_held and water <= 0.0 and not _empty_warned:
			_empty_warned = true
			_show_toast("Tanque vazio — encha perto das piscinas ou da fonte do Térreo", 2.0)
		return
	water = maxf(0.0, water - SOAK_DRAIN * delta)
	var origin := player.position + Vector2(0, -12)
	var dir := _aim_dir(origin, SOAK_RANGE + 30.0, aim_point)
	if _jet == null or not is_instance_valid(_jet):
		_jet = WaterJet.new()
		main._world.add_child(_jet)
	elif _jet.get_parent() != main._world:
		_jet.reparent(main._world)
	_jet.visible = true
	_jet.position = origin
	_jet.direction = dir
	_jet.length = SOAK_RANGE
	_soak_tick -= delta
	_soak_audio -= delta
	if _soak_audio <= 0.0:
		_soak_audio = SOAK_SFX_GAP
		_sfx("vila.soaker")
	var dmg_now := _soak_tick <= 0.0
	if dmg_now:
		_soak_tick = SOAK_TICK
	for j in range(_scorp_nodes.size() - 1, -1, -1):
		var sc: Scorpion = _scorp_nodes[j]
		var v := sc.position + Vector2(0, -4) - origin
		if v.length() < 14.0 or (v.length() <= SOAK_RANGE + 6.0 and absf(v.angle_to(dir)) <= deg_to_rad(SOAK_HALF_ANGLE)):
			sc.soak(SOAK_SLOW)
			if dmg_now and sc.hit():
				_kill_scorpion(j)
	_refresh_stats()


## Direção do tiro: o ponto mirado; senão o escorpião mais próximo no alcance; senão para onde olha.
func _aim_dir(origin: Vector2, rng: float, toward: Vector2) -> Vector2:
	if toward != Vector2.INF and toward.distance_to(origin) > 1.0:
		return (toward - origin).normalized()
	var player: Walker = main._player
	var best: Scorpion = null
	for sc: Scorpion in _scorp_nodes:
		var dd := sc.position.distance_to(player.position)
		if dd < rng and (best == null or dd < best.position.distance_to(player.position)):
			best = sc
	if best != null:
		return (best.position + Vector2(0, -4) - origin).normalized()
	return {"down": Vector2.DOWN, "up": Vector2.UP, "left": Vector2.LEFT, "right": Vector2.RIGHT}[player.facing]


func owns(w: String) -> bool:
	return w == "nerf" or (w == "soaker" and has_soaker) or (w == "espalhadora" and has_spreader)


func select_weapon(w: String) -> bool:
	if not owns(w):
		if active:
			_show_toast("Você ainda não tem a %s — procure no mapa" % WEAPON_NAMES[w], 1.6)
		return false
	weapon = w
	if _jet != null and w != "soaker":
		_jet.visible = false
	_refresh_stats()
	if active:
		_show_toast("Arma: %s (%s)" % [WEAPON_NAMES[w], _ammo_text(w)], 1.2)
	return true


func cycle_weapon() -> void:
	var i := WEAPONS.find(weapon)
	for k in range(1, WEAPONS.size() + 1):
		var w: String = WEAPONS[(i + k) % WEAPONS.size()]
		if owns(w):
			if w != weapon:
				select_weapon(w)
			return


func _ammo_text(w: String) -> String:
	match w:
		"soaker":
			return "Água %d%%" % int(round(water))
		"espalhadora":
			return "Cartuchos %d" % cartridges
	return "Dardos %d" % darts


## Conta as mortes; a cada heart_every() escorpiões, aparece um coração onde caiu o último.
func _on_kill(where: Vector2) -> void:
	_kills_to_heart -= 1
	if _kills_to_heart > 0:
		return
	_kills_to_heart = heart_every()
	var id: String = main.current_area
	var p: Vector2 = where
	var wm: WalkMap = main.walk_map
	if not wm.is_footprint_walkable(p, Walker.FOOT_HALF):
		p = wm.nearest_walkable(p, Walker.FOOT_HALF)
	if not hearts.has(id):
		hearts[id] = []
	(hearts[id] as Array).append(p)
	_heart_nodes.append(_spawn_pickup("coracao", p, main._world))
	_show_toast("Um coração apareceu! Pegue para recuperar %d%% de vida" % heart_heal(), 2.0)


func _scaled_damage(raw: int) -> int:
	if coat_t <= 0.0:
		return raw
	return maxi(1, roundi(float(raw) * COAT_DAMAGE))


func _stung(kind: String) -> void:
	var dmg := _scaled_damage(int(PHASES[phase]["dmg_yellow"] if kind == "amarelo" else PHASES[phase]["dmg_red"]))
	health = maxi(0, health - dmg)
	_sfx("vila.hit")
	_invuln = 1.0
	_refresh_stats()
	_show_toast("Picada pelo escorpião %s! −%d%%" % [kind, dmg], 1.4)
	var cam: Camera2D = main._camera
	var tw := create_tween()
	for k in 4:
		tw.tween_property(cam, "offset", Vector2(randf_range(-3, 3), randf_range(-3, 3)), 0.04)
	tw.tween_property(cam, "offset", Vector2.ZERO, 0.04)
	if health <= 0:
		_game_over()


## O autoload não entra no escopo de um class_name durante o teste em --script.
func _audio() -> Node:
	return get_node(^"/root/AudioDirector")


func _arm_sfx() -> void:
	if _sfx_ready:
		return
	_sfx_ready = true
	_audio().register_stream("vila.shot", ProceduralSfx.tone(1100.0, 0.045, 0.22, 620.0))
	_audio().register_stream("vila.soaker", ProceduralSfx.noise(0.24, 0.07, 0.5))
	_audio().register_stream("vila.hit", ProceduralSfx.tone(150.0, 0.11, 0.32, 62.0))
	_audio().register_stream("vila.scorpion", ProceduralSfx.tone(720.0, 0.07, 0.14, 240.0))
	_audio().register_stream("vila.thunder", ProceduralSfx.thunder())
	_audio().register_stream("vila.rain", ProceduralSfx.noise(1.6, 0.045, 0.38, true))


func _sfx(cue_id: String, pitch: float = 1.0) -> void:
	_arm_sfx()
	_audio().play_cue(cue_id, pitch)


## Atira com a arma atual. A Super Soaker atira enquanto o botão é segurado (um toque dá um jato curto).
func shoot(toward: Vector2 = Vector2.INF) -> bool:
	_audio().unlock_audio()
	if not active or overlay_open:
		return false
	match weapon:
		"soaker":
			if water <= 0.0:
				_show_toast("Tanque vazio — encha perto das piscinas ou da fonte do Térreo", 1.8)
				return false
			_burst = maxf(_burst, 0.35)
			if toward != Vector2.INF:
				aim_point = toward
			return true
		"espalhadora":
			return _shoot_spread(toward)
	return _shoot_nerf(toward)


func _shoot_spread(toward: Vector2) -> bool:
	if _fire_cd > 0.0:
		return false
	if cartridges <= 0:
		_show_toast("Sem cartuchos — pegue outra Espalhadora", 1.6)
		return false
	var player: Walker = main._player
	var origin := player.position + Vector2(0, -12)
	var dir := _aim_dir(origin, SPREAD_RANGE + 30.0, toward)
	for i in SPREAD_COUNT:
		var a := deg_to_rad(-SPREAD_ANGLE * 0.5 + SPREAD_ANGLE * i / float(SPREAD_COUNT - 1))
		var d := Dart.new()
		d.position = origin
		d.velocity = dir.rotated(a) * Dart.SPEED
		d.max_range = SPREAD_RANGE
		d.green = true
		main._world.add_child(d)
		_dart_nodes.append(d)
	cartridges -= 1
	_fire_cd = SPREAD_CD
	_refresh_stats()
	_sfx("vila.shot", 0.82)
	return true


## Lançador Nerf: um dardo reto, longo alcance.
func _shoot_nerf(toward: Vector2) -> bool:
	if _fire_cd > 0.0:
		return false
	if darts <= 0:
		_show_toast("Sem dardos — pegue um lançador Nerf", 1.6)
		return false
	var player: Walker = main._player
	var origin := player.position + Vector2(0, -12)
	var dir := Vector2.ZERO
	if toward != Vector2.INF:
		dir = (toward - origin).normalized()
	else:
		var best: Scorpion = null
		for s: Scorpion in _scorp_nodes:
			var dd := s.position.distance_to(player.position)
			if dd < AIM_RANGE and (best == null or dd < best.position.distance_to(player.position)):
				best = s
		if best != null:
			dir = (best.position + Vector2(0, -4) - origin).normalized()
		else:
			dir = {"down": Vector2.DOWN, "up": Vector2.UP, "left": Vector2.LEFT, "right": Vector2.RIGHT}[player.facing]
	if dir == Vector2.ZERO:
		return false
	var d := Dart.new()
	d.position = origin
	d.velocity = dir * Dart.SPEED
	d.max_range = Dart.RANGE * nerf_range_scale()
	main._world.add_child(d)
	_dart_nodes.append(d)
	darts -= 1
	_fire_cd = FIRE_COOLDOWN
	_refresh_stats()
	_sfx("vila.shot", 1.18)
	return true


func _puff(p: Vector2, kind: String) -> void:
	var n := Polygon2D.new()
	var pts := PackedVector2Array()
	for i in 10:
		var a := TAU * i / 10.0
		pts.append(Vector2(cos(a), sin(a)) * (7.0 if i % 2 == 0 else 4.0))
	n.polygon = pts
	n.color = Color("ffd23a") if kind == "amarelo" else Color("ff4a3a")
	n.position = p + Vector2(0, -4)
	n.z_index = 30
	main._world.add_child(n)
	var tw := n.create_tween()
	tw.parallel().tween_property(n, "scale", Vector2.ONE * 2.2, 0.35)
	tw.parallel().tween_property(n, "modulate:a", 0.0, 0.35)
	tw.tween_callback(n.queue_free)


func remaining_scorpions() -> int:
	var total := 0
	for id: String in scorps:
		if id == main.current_area:
			total += _scorp_nodes.size()
		else:
			total += (scorps[id] as Array).size()
	return total


# ---------------------------------------------------------------- noite

func _apply_night(on: bool) -> void:
	if on and _night_mod == null:
		_night_mod = CanvasModulate.new()
		_night_mod.color = Color(0.2, 0.24, 0.45)
		main._sub_viewport.add_child(_night_mod)
		_light = PointLight2D.new()
		var g := Gradient.new()
		g.set_color(0, Color(1, 0.95, 0.8, 1))
		g.set_color(1, Color(1, 0.95, 0.8, 0))
		g.add_point(0.55, Color(1, 0.95, 0.8, 0.55))
		var tex := GradientTexture2D.new()
		tex.gradient = g
		tex.fill = GradientTexture2D.FILL_RADIAL
		tex.fill_from = Vector2(0.5, 0.5)
		tex.fill_to = Vector2(1.0, 0.5)
		tex.width = 256
		tex.height = 256
		_light.texture = tex
		_light.texture_scale = 0.91  # 30% menor que o foco original (1.3)
		_light.energy = 1.25
		_light.position = Vector2(0, -10)
		main._player.add_child(_light)
	elif not on and _night_mod != null:
		_night_mod.queue_free()
		_night_mod = null
		_light.queue_free()
		_light = null


func _apply_rain(on: bool) -> void:
	if on and _rain == null:
		# Só um CanvasModulate vale por cena: à noite a escuridão já cobre, a chuva vem por cima.
		if _night_mod == null:
			_rain_mod = CanvasModulate.new()
			_rain_mod.color = Color(0.68, 0.74, 0.86)
			main._sub_viewport.add_child(_rain_mod)
		_rain = RainLayer.new()
		_rain.scripted = is_night()
		main.add_child(_rain)
		main.move_child(_rain, main._viewport_container.get_index() + 1)
		_audio().play_bed("vila.rain")
		if _rground == null:
			_rground = RainGround.new()
			main._world.add_child(_rground)
	elif not on and _rain != null:
		if _rain_mod != null:
			_rain_mod.queue_free()
		_rain_mod = null
		_rain.queue_free()
		_rain = null
		_audio().stop_bed()
		if _rground != null:
			_rground.queue_free()
			_rground = null


func is_raining() -> bool:
	return _rain != null


func is_night() -> bool:
	return _night_mod != null


func is_storm() -> bool:
	return is_raining() and is_night()


func level_banner(idx: int) -> String:
	match idx:
		0:
			return "Nível 1 — dia fácil. Junte as moedas e use o lançador Nerf"
		1:
			return "Nível 2 — a noite caiu. A lanterna ilumina pouco; a Espalhadora chegou"
		2:
			return "Nível 3 — dia de chuva. Poças, chão escorregadio e dardos molhados"
		3:
			return "Nível 4 — escorpiões saindo dos ralos! Tampe os bueiros"
	return ""


func level_debrief(idx: int) -> String:
	match idx:
		1:
			return "Muda no nível 2: fica noite (a lanterna não cobre tudo) e aparece a Espalhadora."
		2:
			return "Muda no nível 3: chuva. Poças deixam 30% mais lento; o chão bege e terracota escorrega, a grama não. Dardos molhados perdem 30% de alcance fora do abrigo. Sob a marquise e a torre coberta não chove: sem escorregar, alcance normal e +5% de vida. Uma capa de chuva dura 20s (sem escorregar e com metade do dano)."
		3:
			return "Muda no nível 4: a chuva segue, de noite. Escorpiões saem dos ralos — fique 2 segundos perto para tampar o bueiro. O relâmpago mostra todo escorpião na tela por 1 segundo, e o raio cai 1,5s depois do círculo (−10% de vida)."
	return ""


## Dentro de uma poça da tela atual.
func in_puddle(p: Vector2) -> bool:
	if not is_raining():
		return false
	for pud: Dictionary in puddles.get(main.current_area, []):
		if p.distance_to(pud["center"]) <= float(pud["radius"]):
			return true
	return false


## Marquise e parte coberta das torres: o sprite da torre já cobre o corpo.
func in_dry_shelter(p: Vector2) -> bool:
	if not is_raining():
		return false
	return bool(main.is_occluded(p))


func nerf_range_scale() -> float:
	if not is_raining() or in_dry_shelter(main._player.position):
		return 1.0
	return DART_RAIN_RANGE


## Poça, piso escorregadio, abrigo e capa. O passo lê isso antes de andar.
func apply_move_modifiers() -> void:
	var player: Walker = main._player
	if player == null or not is_raining() or not active:
		if player != null:
			player.set_weather_move(1.0, 0.0)
		return
	var scale := PUDDLE_SLOW if in_puddle(player.position) else 1.0
	var floor := String(main.floor_kind(player.position))
	var slip := coat_t <= 0.0 and not in_dry_shelter(player.position) and floor in ["bege", "terracota"]
	player.set_weather_move(scale, SLIP_BRAKE if slip else 0.0)


func drain_alive() -> int:
	var n := 0
	for s: Scorpion in _scorp_nodes:
		if s.from_drain:
			n += 1
	for id: String in scorps:
		if id == String(main.current_area):
			continue
		for d: Dictionary in scorps[id]:
			if bool(d.get("from_drain", false)):
				n += 1
	return n


func _update_weather(delta: float) -> void:
	var had_coat := coat_t > 0.0
	if had_coat:
		coat_t = maxf(0.0, coat_t - delta)
		if coat_t == 0.0:
			_show_toast("A capa de chuva acabou", 1.4)
			_refresh_stats()
	if not is_raining():
		_shelter_known = false
		return
	_grow_puddles(delta)
	_update_shelter()
	if is_storm():
		_update_drains(delta)
		_update_reveal(delta)
		_update_bolts(delta)
	_sync_rain_ground()


func _grow_puddles(delta: float) -> void:
	for id: String in puddles:
		for pud: Dictionary in puddles[id]:
			pud["radius"] = minf(float(pud["max_radius"]), float(pud["radius"]) + PUDDLE_GROW * delta)


func _update_shelter() -> void:
	var now := in_dry_shelter(main._player.position)
	if not _shelter_known:
		_shelter_known = true
		_in_shelter = now
		return
	if now and not _in_shelter and health < 100 and not overlay_open:
		var before := health
		health = mini(100, health + SHELTER_HEAL)
		if health > before:
			_refresh_stats()
			_show_toast("Abrigo seco! +%d%% de vida" % (health - before), 1.4)
	_in_shelter = now


func _update_drains(delta: float) -> void:
	var player: Walker = main._player
	for d: Dictionary in drains:
		if bool(d["sealed"]) or String(d["area"]) != String(main.current_area):
			continue
		if player.position.distance_to(d["pos"]) <= DRAIN_NEAR:
			d["near"] = float(d["near"]) + delta
			if float(d["near"]) >= DRAIN_SEAL_TIME:
				d["sealed"] = true
				_show_toast("Bueiro tampado. Esse ralo não solta mais escorpiões", 1.8)
		else:
			d["near"] = 0.0
	_drain_cd -= delta
	if _drain_cd <= 0.0:
		_drain_cd = DRAIN_INTERVAL
		_spawn_from_drain()


func _spawn_from_drain() -> void:
	if drains.is_empty() or drain_alive() >= DRAIN_CAP:
		return
	var open: Array = []
	for d: Dictionary in drains:
		if not bool(d["sealed"]):
			open.append(d)
	if open.is_empty():
		return
	var d: Dictionary = open[randi() % open.size()]
	var id := String(d["area"])
	var pos: Vector2 = d["pos"]
	var kind := "amarelo"
	if id == String(main.current_area):
		var s := Scorpion.new()
		s.setup(kind, main.walk_map, main._finder, main._player, float(PHASES[phase]["speed"]))
		s.hp = scorpion_hp(kind)
		s.aggro_mult = float(PHASES[phase]["aggro"])
		s.from_drain = true
		s.avoid = Callable(self, "in_puddle")
		s.position = pos
		main._world.add_child(s)
		_scorp_nodes.append(s)
	else:
		(scorps[id] as Array).append({"kind": kind, "pos": pos, "hp": scorpion_hp(kind), "from_drain": true})
	_show_toast("Um escorpião saiu do ralo!", 1.4)


func _update_reveal(delta: float) -> void:
	if _reveal_t > 0.0:
		_reveal_t = maxf(0.0, _reveal_t - delta)
		return
	_reveal_cd -= delta
	if _reveal_cd > 0.0:
		return
	_reveal_t = REVEAL_TIME
	_reveal_cd = REVEAL_GAP
	if _rain != null:
		_rain.pulse(REVEAL_TIME)


func _update_bolts(delta: float) -> void:
	if not _bolt.is_empty():
		_bolt["left"] = float(_bolt["left"]) - delta
		if float(_bolt["left"]) <= 0.0:
			_resolve_bolt()
			_bolt = {}
		return
	_bolt_cd -= delta
	if _bolt_cd <= 0.0:
		_bolt_cd = STRIKE_GAP
		_aim_bolt()


func _aim_bolt() -> void:
	var player: Walker = main._player
	var wm: WalkMap = main.walk_map
	var pos := player.position
	for i in 12:
		var ang := randf() * TAU
		var cand := player.position + Vector2(cos(ang), sin(ang)) * randf_range(40.0, 160.0)
		if wm.is_footprint_walkable(cand, Walker.FOOT_HALF):
			pos = cand
			break
	_bolt = {"pos": pos, "left": STRIKE_DELAY}


func _resolve_bolt() -> void:
	_sfx("vila.thunder")
	var p: Vector2 = _bolt["pos"]
	for j in range(_scorp_nodes.size() - 1, -1, -1):
		var s: Scorpion = _scorp_nodes[j]
		if not is_instance_valid(s):
			continue
		if s.position.distance_to(p) <= STRIKE_RADIUS:
			_kill_scorpion(j)
			if overlay_open:
				return
	if main._player.position.distance_to(p) <= STRIKE_RADIUS:
		var before := health
		var dmg := _scaled_damage(STRIKE_DAMAGE)
		health = maxi(0, health - dmg)
		if health < before:
			_sfx("vila.hit", 0.9)
		_refresh_stats()
		_show_toast("Raio! −%d%%" % dmg, 1.4)
		if health <= 0:
			_game_over()
	if _rain != null:
		_rain.pulse(0.25)


func _in_view(p: Vector2) -> bool:
	var cam: Camera2D = main._camera
	var vp: Vector2 = main._sub_viewport.get_visible_rect().size
	if cam == null or vp.x < 8.0 or vp.y < 8.0:
		return p.distance_to(main._player.position) < 420.0
	var zoom := cam.zoom.x if cam.zoom.x > 0.01 else 1.0
	var half: Vector2 = vp * 0.5 / zoom
	return Rect2(cam.global_position - half, half * 2.0).grow(8.0).has_point(p)


func _sync_rain_ground() -> void:
	if _rground == null or not is_instance_valid(_rground):
		return
	var id := String(main.current_area)
	_rground.puddles = puddles.get(id, [])
	var ds: Array = []
	for d: Dictionary in drains:
		if String(d["area"]) == id:
			ds.append(d)
	_rground.drains = ds
	if _bolt.is_empty():
		_rground.bolt_pos = Vector2.INF
	else:
		_rground.bolt_pos = _bolt["pos"]
		_rground.bolt_r = STRIKE_RADIUS
		_rground.bolt_k = clampf(1.0 - float(_bolt["left"]) / STRIKE_DELAY, 0.0, 1.0)


func _cull_sheltered_puddles(id: String) -> void:
	if not puddles.has(id):
		return
	var kept: Array = []
	for pud: Dictionary in puddles[id]:
		if not main.is_occluded(pud["center"]):
			kept.append(pud)
	if not kept.is_empty():
		puddles[id] = kept


## Diâmetro no máximo a largura do passeio, e o disco não atravessa a máscara.
## Teto absoluto: PUDDLE_MAX_R (22), menor que o antigo 38.
func _puddle_cap(wm: WalkMap, p: Vector2) -> float:
	var half := wm.path_width(p) * 0.5
	var inside := wm.edge_clearance(p, minf(half, PUDDLE_MAX_R + 2.0))
	var cap := minf(half, inside) - 1.0
	var floor_r := minf(4.0, maxf(inside, 2.0))
	return clampf(cap, floor_r, PUDDLE_MAX_R)


func _place_rain() -> void:
	puddles.clear()
	coats.clear()
	drains.clear()
	if not bool(PHASES[phase]["rain"]):
		return
	var ids: Array = (main.areas as Dictionary).keys()
	var weights := {}
	for id: String in ids:
		weights[id] = pow(float((_points.get(id, []) as Array).size()), 0.7)
	var n_coat: Dictionary = _distribute(1, weights, 0)
	for id: String in ids:
		var pts: Array = (_points.get(id, []) as Array).duplicate()
		var rng := RandomNumberGenerator.new()
		rng.seed = 9100 + phase * 17 + id.hash()
		for i in range(pts.size() - 1, 0, -1):
			var j := rng.randi() % (i + 1)
			var tmp: Variant = pts[i]
			pts[i] = pts[j]
			pts[j] = tmp
		var safe: Array[Vector2] = []
		for s: Array in ((main.areas[id] as Dictionary)["spawns"] as Dictionary).values():
			safe.append(Vector2(float(s[0]), float(s[1])))
		var taken: Array[Vector2] = []
		var spots: Array[Vector2] = _pick(pts, PUDDLE_COUNT, 90.0, taken, safe, 70.0)
		var wm := WalkMap.new()
		var have_mask := wm.load_mask(String((main.areas[id] as Dictionary)["walk"]))
		var list: Array = []
		for p: Vector2 in spots:
			var cap := _puddle_cap(wm, p) if have_mask else PUDDLE_MAX_R
			var start := minf(PUDDLE_START_R, cap * 0.65)
			list.append({"center": p, "radius": start, "max_radius": cap})
			taken.append(p)
		puddles[id] = list
		var coat_spots: Array[Vector2] = []
		if int(n_coat.get(id, 0)) > 0:
			coat_spots = _pick(pts, 1, 80.0, taken, safe, 80.0)
			if coat_spots.is_empty() and not pts.is_empty():
				var raw: Array = pts[0]
				coat_spots.append(Vector2(float(raw[0]), float(raw[1])))
		coats[id] = coat_spots
	if bool(PHASES[phase]["night"]):
		_place_drains()


func _place_drains() -> void:
	var cands: Array = []
	for id: String in (main.areas as Dictionary).keys():
		var safe: Array[Vector2] = []
		for s: Array in ((main.areas[id] as Dictionary)["spawns"] as Dictionary).values():
			safe.append(Vector2(float(s[0]), float(s[1])))
		var pts: Array = _points.get(id, [])
		var pool: Array = pts.duplicate()
		var rng := RandomNumberGenerator.new()
		rng.seed = 4400 + id.hash()
		for i in range(pool.size() - 1, 0, -1):
			var j := rng.randi() % (i + 1)
			var tmp: Variant = pool[i]
			pool[i] = pool[j]
			pool[j] = tmp
		var none: Array[Vector2] = []
		var picked: Array[Vector2] = _pick(pool, 4, 140.0, none, safe, 160.0)
		for p: Vector2 in picked:
			cands.append({"area": id, "pos": p})
	var chosen: Array = []
	var used := {}
	for c: Dictionary in cands:
		if chosen.size() >= DRAIN_COUNT:
			break
		if used.has(c["area"]):
			continue
		used[c["area"]] = true
		chosen.append({"area": c["area"], "pos": c["pos"], "sealed": false, "near": 0.0})
	if chosen.size() < DRAIN_COUNT:
		for c: Dictionary in cands:
			if chosen.size() >= DRAIN_COUNT:
				break
			var dup := false
			for o: Dictionary in chosen:
				if o["area"] == c["area"] and (o["pos"] as Vector2).distance_to(c["pos"]) < 80.0:
					dup = true
			if not dup:
				chosen.append({"area": c["area"], "pos": c["pos"], "sealed": false, "near": 0.0})
	if chosen.size() < DRAIN_COUNT:
		for id: String in (main.areas as Dictionary).keys():
			for raw: Array in _points.get(id, []):
				if chosen.size() >= DRAIN_COUNT:
					break
				var pos := Vector2(float(raw[0]), float(raw[1]))
				var dup := false
				for o: Dictionary in chosen:
					if o["area"] == id and (o["pos"] as Vector2).distance_to(pos) < 40.0:
						dup = true
				if not dup:
					chosen.append({"area": id, "pos": pos, "sealed": false, "near": 0.0})
	drains = chosen


func _append_rain_dots(dots: Array, id: String) -> void:
	for pud: Dictionary in puddles.get(id, []):
		dots.append([pud["center"], "poca"])
	for d: Dictionary in drains:
		if String(d["area"]) == id:
			dots.append([d["pos"], "bueiro_tampado" if bool(d["sealed"]) else "bueiro"])


# ---------------------------------------------------------------- interface

func _build_ui() -> void:
	_stats = PanelContainer.new()
	var sb: StyleBoxFlat = main._panel_style(10)
	sb.set_content_margin_all(10)
	sb.set_border_width_all(2)
	_stats.add_theme_stylebox_override("panel", sb)
	_stats.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stats.visible = false
	main.add_child(_stats)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stats.add_child(box)
	_phase_label = _small("", 16, main.ACCENT)
	box.add_child(_phase_label)
	var hp := Control.new()
	hp.custom_minimum_size = Vector2(190, 20)
	hp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(hp)
	_hp_back = ColorRect.new()
	_hp_back.color = Color(0.25, 0.08, 0.08)
	_hp_back.size = Vector2(190, 20)
	_hp_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hp.add_child(_hp_back)
	_hp_fill = ColorRect.new()
	_hp_fill.color = Color("e0433a")
	_hp_fill.size = Vector2(190, 20)
	_hp_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hp.add_child(_hp_fill)
	_hp_label = _small("", 14)
	_hp_label.size = Vector2(190, 20)
	_hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hp_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_hp_label.add_theme_constant_override("outline_size", 4)
	_hp_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	hp.add_child(_hp_label)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(row)
	_coin_label = _small("", 16, Color("ffd85a"))
	row.add_child(_coin_label)
	var icon := TextureRect.new()
	icon.texture = load("res://assets/game/nerf_hd.png") as Texture2D
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(30, 21)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon)
	_weapon_icon = icon
	_dart_label = _small("", 16, Color("9cc8ff"))
	row.add_child(_dart_label)
	_weapons_label = _small("", 13, Color("cfd8c4"))
	_weapons_label.visible = false
	box.add_child(_weapons_label)

	_toast = _small("", 22)
	_toast.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_toast.offset_top = 140
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.add_theme_constant_override("outline_size", 7)
	_toast.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_toast.visible = false
	main.add_child(_toast)

	var a: Array = main._centered_panel()
	_phase_screen = a[0]
	var b1: VBoxContainer = a[1]
	b1.add_child(main._label("Nível concluído!", 40, main.ACCENT))
	_phase_text = main._label("", 18)
	b1.add_child(_phase_text)
	_phase_button = main._make_button("Começar o próximo nível")
	_phase_button.pressed.connect(func() -> void: start_phase(phase + 1))
	b1.add_child(_phase_button)

	var o: Array = main._centered_panel()
	_over_screen = o[0]
	var b2: VBoxContainer = o[1]
	b2.add_child(main._label("Você foi picada demais!", 36, Color("ff6a5a")))
	_over_text = main._label("", 18)
	b2.add_child(_over_text)
	_over_button = main._make_button("Tentar o nível de novo")
	_over_button.pressed.connect(func() -> void:
		darts = _darts_at_phase_start
		start_phase(phase))
	b2.add_child(_over_button)
	var back: Button = main._make_button("Menu inicial")
	back.pressed.connect(func() -> void: main._back_to_title())
	b2.add_child(back)

	var w: Array = main._centered_panel()
	_win_screen = w[0]
	var b3: VBoxContainer = w[1]
	b3.add_child(main._label("Você venceu!", 44, main.ACCENT))
	_win_text = main._label("", 18)
	b3.add_child(_win_text)
	_win_button = main._make_button("Jogar de novo")
	_win_button.pressed.connect(func() -> void: new_game())
	b3.add_child(_win_button)
	var back2: Button = main._make_button("Menu inicial")
	back2.pressed.connect(func() -> void: main._back_to_title())
	b3.add_child(back2)
	_hide_overlays()


func _small(text: String, size: int, color: Color = Color("fff1c9")) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _hide_overlays() -> void:
	overlay_open = false
	for s: Control in [_phase_screen, _over_screen, _win_screen]:
		if s != null:
			s.visible = false
	if main != null and main.has_method("_refresh_touch_visibility"):
		main._refresh_touch_visibility()


func _open_overlay(screen: Control, button: Button) -> void:
	overlay_open = true
	main.clear_move()
	screen.visible = true
	main._refresh_touch_visibility()
	button.call_deferred("grab_focus")


func _phase_complete() -> void:
	if phase + 1 < PHASES.size():
		var nx: Dictionary = PHASES[phase + 1]
		_phase_text.text = "%s\n%s\nVocê juntou as %d moedas e eliminou %d escorpiões.\nPróximo: %s — %d moedas, %d escorpiões amarelos e %d vermelhos; picadas −%d%% e −%d%%; %d lançadores com %d dardos; amarelo cai com %d dardo(s) e vermelho com %d; coração a cada %d escorpiões (+%d%%)." % [
			WEAPON_HELP, level_debrief(phase + 1),
			coins_goal(), kills, String(nx["name"]), int(nx["coins"]), int(nx["yellow"]), int(nx["red"]),
			int(nx["dmg_yellow"]), int(nx["dmg_red"]), int(nx["guns"]), int(nx["darts"]),
			int(nx["hp_yellow"]), int(nx["hp_red"]), int(nx["heart_every"]), int(nx["heart_heal"])]
		_phase_button.text = "Começar o %s" % String(nx["short"])
		_open_overlay(_phase_screen, _phase_button)
	else:
		_win_text.text = "Você completou os %d níveis, terminando com %d%% de vida." % [PHASES.size(), health]
		_open_overlay(_win_screen, _win_button)


func _game_over() -> void:
	_over_text.text = "A vida chegou a 0%%. Você tinha %d de %d moedas neste nível." % [coins_got, coins_goal()]
	_open_overlay(_over_screen, _over_button)


func _refresh_stats() -> void:
	if _stats == null:
		return
	_stats.visible = active and main._playing
	_phase_label.text = String(PHASES[phase]["name"])
	_hp_fill.size.x = 190.0 * health / 100.0
	_hp_fill.color = Color("e0433a") if health > 30 else Color("ff2a1a")
	_hp_label.text = "Vida %d%%" % health
	if coat_t > 0.0:
		_hp_label.text += "  Capa %ds" % int(ceil(coat_t))
	_coin_label.text = "Moedas %d/%d" % [coins_got, coins_goal()]
	_dart_label.text = _ammo_text(weapon)
	if _weapon_icon != null:
		_weapon_icon.texture = load({"nerf": "res://assets/game/nerf_hd.png", "soaker": "res://assets/game/soaker_hd.png", "espalhadora": "res://assets/game/spread_hd.png"}[weapon]) as Texture2D
	var owned: Array = []
	for k in WEAPONS.size():
		var w: String = WEAPONS[k]
		if owns(w):
			var t := "%d %s" % [k + 1, WEAPON_NAMES[w]] if not main.touch_mode else String(WEAPON_NAMES[w])
			owned.append("[%s]" % t if w == weapon else t)
	_weapons_label.visible = owned.size() > 1
	_weapons_label.text = " · ".join(owned)


func _show_toast(text: String, secs: float = 2.0) -> void:
	_toast.text = text
	_toast.visible = true
	_toast.modulate.a = 1.0
	if _toast_tween != null:
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_interval(secs)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.5)


func relayout(_vs: Vector2, _top_right_reserved: float) -> void:
	if _stats == null:
		return
	_refresh_stats()
	_stats.reset_size()
	_stats.position = Vector2(16.0, 14.0)


func _update_minimap() -> void:
	var mm: Minimap = main._minimap
	if mm == null:
		return
	var data := markers_for(String(main.current_area))
	mm.dots = data["dots"]
	mm.counts = data["counts"]
	mm.show_legend = active


## Marcadores e contagens de uma área (a atual usa os itens vivos; as outras, o estado salvo).
func markers_for(id: String) -> Dictionary:
	var dots: Array = []
	var nc := 0
	var ng := 0
	var ns := 0
	if id == String(main.current_area):
		for c: Pickup in _coin_nodes:
			dots.append([c.position, "moeda"])
		for g: Pickup in _gun_nodes:
			dots.append([g.position, "arma"])
		for w: Pickup in _soaker_nodes:
			dots.append([w.position, "soaker"])
		for w: Pickup in _spreader_nodes:
			dots.append([w.position, "espalhadora"])
		for h: Pickup in _heart_nodes:
			dots.append([h.position, "coracao"])
		for w: Pickup in _coat_nodes:
			dots.append([w.position, "capa"])
		_append_rain_dots(dots, id)
		for sc: Scorpion in _scorp_nodes:
			dots.append([sc.position, sc.kind])
		nc = _coin_nodes.size(); ng = _gun_nodes.size() + _soaker_nodes.size() + _spreader_nodes.size(); ns = _scorp_nodes.size()
	elif active:
		for p: Vector2 in coins.get(id, []):
			dots.append([p, "moeda"])
		for p: Vector2 in guns.get(id, []):
			dots.append([p, "arma"])
		for p: Vector2 in soakers.get(id, []):
			dots.append([p, "soaker"])
		for p: Vector2 in spreaders.get(id, []):
			dots.append([p, "espalhadora"])
		for p: Vector2 in hearts.get(id, []):
			dots.append([p, "coracao"])
		for p: Vector2 in coats.get(id, []):
			dots.append([p, "capa"])
		_append_rain_dots(dots, id)
		for d: Dictionary in scorps.get(id, []):
			dots.append([d["pos"], String(d["kind"])])
		nc = (coins.get(id, []) as Array).size(); ng = (guns.get(id, []) as Array).size() + (soakers.get(id, []) as Array).size() + (spreaders.get(id, []) as Array).size(); ns = (scorps.get(id, []) as Array).size()
	var tc := 0
	var tg := 0
	for a: String in coins:
		tc += (coins[a] as Array).size()
	for a: String in guns:
		tg += (guns[a] as Array).size()
	for a: String in soakers:
		tg += (soakers[a] as Array).size()
	for a: String in spreaders:
		tg += (spreaders[a] as Array).size()
	return {"dots": dots, "counts": {"moeda": nc, "arma": ng, "escorpiao": ns,
		"moeda_total": tc, "arma_total": tg, "escorpiao_total": remaining_scorpions()}}
