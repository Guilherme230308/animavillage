class_name Adventure
extends Node
## Regras do jogo: moedas, escorpiões, lançadores Nerf, vida e fases (dia e noite).
## Os itens ficam espalhados por todas as telas e lembram o estado ao sair e voltar.

const SPAWN_POINTS := "res://assets/game/spawn_points.json"
## Níveis. Bases: dia = 100 moedas, 10 amarelos, 5 vermelhos; noite = 100 moedas, 15 amarelos, 10 vermelhos;
## 10 lançadores com 10 dardos. Nível 1: −70% moedas/escorpiões, +30% armas/dardos.
## Nível 2: −50% moedas/escorpiões, +10% armas/dardos. Nível 3: quantidades originais do dia.
const PHASES := [
	{"name": "Nível 1 · Dia (fácil)", "short": "nível 1", "coins": 30, "yellow": 3, "red": 2, "guns": 13, "darts": 13,
		"dmg_yellow": 5, "dmg_red": 10, "night": false, "rain": false, "speed": 1.0},
	{"name": "Nível 2 · Noite", "short": "nível 2", "coins": 50, "yellow": 8, "red": 5, "guns": 11, "darts": 11,
		"dmg_yellow": 10, "dmg_red": 15, "night": true, "rain": false, "speed": 1.1},
	{"name": "Nível 3 · Dia com chuva", "short": "nível 3", "coins": 100, "yellow": 10, "red": 5, "guns": 10, "darts": 10,
		"dmg_yellow": 10, "dmg_red": 15, "night": false, "rain": true, "speed": 1.1},
]
const FIRE_COOLDOWN := 0.28
const AIM_RANGE := 260.0

var main: Node
var active := false
var phase := 0
var health := 100
var darts := 0
var coins_got := 0
var kills := 0
var overlay_open := false
## Estado por tela: posições das moedas e armas restantes e escorpiões vivos.
var coins: Dictionary = {}
var guns: Dictionary = {}
var scorps: Dictionary = {}
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


# ---------------------------------------------------------------- fases

func coins_goal() -> int:
	return int(PHASES[phase]["coins"])


func darts_per_gun() -> int:
	return int(PHASES[phase]["darts"])


func new_game() -> void:
	darts = 0
	start_phase(0)


func start_phase(idx: int) -> void:
	phase = idx
	# Desliga durante a recarga para não sobrescrever o estado novo com o da tela anterior.
	active = false
	_clear_nodes()
	health = 100
	coins_got = 0
	kills = 0
	_darts_at_phase_start = darts
	_invuln = 0.0
	_place_everything()
	_apply_night(bool(PHASES[phase]["night"]))
	_apply_rain(bool(PHASES[phase]["rain"]))
	_hide_overlays()
	main.load_area(main.START_AREA, main.START_SPAWN)
	active = true
	on_area_loaded()
	_invuln = 1.5
	_refresh_stats()
	_show_toast("%s — colete as %d moedas!" % [String(PHASES[phase]["name"]), coins_goal()], 3.0)


func stop() -> void:
	active = false
	_clear_nodes()
	_apply_night(false)
	_apply_rain(false)
	_hide_overlays()
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
	coins.clear()
	guns.clear()
	scorps.clear()
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
		var sl: Array = []
		for k: String in ["amarelo", "vermelho"]:
			var n := int((n_yel if k == "amarelo" else n_red)[id])
			for p: Vector2 in _pick(pts, n, 70.0, taken, safe, 170.0):
				sl.append({"kind": k, "pos": p})
				taken.append(p)
		scorps[id] = sl


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
			sl.append({"kind": s.kind, "pos": s.position, "hp": s.hp})
	scorps[main.current_area] = sl
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
	for d: Dictionary in scorps.get(id, []):
		var s := Scorpion.new()
		s.setup(String(d["kind"]), main.walk_map, main._finder, main._player, float(PHASES[phase]["speed"]))
		if d.has("hp"):
			s.hp = int(d["hp"])
		s.position = d["pos"]
		world.add_child(s)
		_scorp_nodes.append(s)
	_invuln = maxf(_invuln, 1.0)
	_update_minimap()


func _spawn_pickup(kind: String, p: Vector2, world: Node2D) -> Pickup:
	var n := Pickup.new()
	n.kind = kind
	n.position = p
	world.add_child(n)
	return n


func _clear_nodes() -> void:
	for arr: Array in [_coin_nodes, _gun_nodes, _scorp_nodes, _dart_nodes]:
		for n: Node in arr:
			if is_instance_valid(n):
				n.queue_free()
		arr.clear()


# ---------------------------------------------------------------- jogo

func tick(delta: float) -> void:
	if not active or overlay_open:
		return
	var player: Walker = main._player
	var id: String = main.current_area
	_fire_cd = maxf(0.0, _fire_cd - delta)
	_invuln = maxf(0.0, _invuln - delta)
	player.modulate.a = 1.0 if _invuln <= 0.0 or int(_invuln * 12.0) % 2 == 0 else 0.35
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
	# Escorpiões
	var hidden: bool = main.is_occluded(player.position)
	for s: Scorpion in _scorp_nodes:
		if s.tick(delta, hidden) and _invuln <= 0.0:
			_stung(s.kind)
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
					_puff(s.position, s.kind)
					s.queue_free()
					_scorp_nodes.remove_at(j)
					kills += 1
				break
		if not alive:
			d.queue_free()
			_dart_nodes.remove_at(i)
	_update_minimap()


func _stung(kind: String) -> void:
	var dmg := int(PHASES[phase]["dmg_yellow"] if kind == "amarelo" else PHASES[phase]["dmg_red"])
	health = maxi(0, health - dmg)
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


## Atira um dardo: mira o escorpião mais próximo; sem alvo, para onde a personagem olha.
func shoot(toward: Vector2 = Vector2.INF) -> bool:
	if not active or overlay_open or _fire_cd > 0.0:
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
	main._world.add_child(d)
	_dart_nodes.append(d)
	darts -= 1
	_fire_cd = FIRE_COOLDOWN
	_refresh_stats()
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
		_light.texture_scale = 1.3
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
		_rain_mod = CanvasModulate.new()
		_rain_mod.color = Color(0.68, 0.74, 0.86)
		main._sub_viewport.add_child(_rain_mod)
		_rain = RainLayer.new()
		main.add_child(_rain)
		main.move_child(_rain, main._viewport_container.get_index() + 1)
	elif not on and _rain != null:
		_rain_mod.queue_free()
		_rain_mod = null
		_rain.queue_free()
		_rain = null


func is_raining() -> bool:
	return _rain != null


func is_night() -> bool:
	return _night_mod != null


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
	_dart_label = _small("", 16, Color("9cc8ff"))
	row.add_child(_dart_label)

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
	var back: Button = main._make_button("Voltar ao início")
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
	var back2: Button = main._make_button("Voltar ao início")
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
		var extra := "A noite caiu no condomínio." if bool(nx["night"]) else ("Começou a chover." if bool(nx["rain"]) else "")
		_phase_text.text = "Você juntou as %d moedas e eliminou %d escorpiões.\n%s Próximo: %s — %d moedas, %d escorpiões amarelos e %d vermelhos; picadas −%d%% e −%d%%; %d lançadores com %d dardos." % [
			coins_goal(), kills, extra, String(nx["name"]), int(nx["coins"]), int(nx["yellow"]), int(nx["red"]),
			int(nx["dmg_yellow"]), int(nx["dmg_red"]), int(nx["guns"]), int(nx["darts"])]
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
	_coin_label.text = "Moedas %d/%d" % [coins_got, coins_goal()]
	_dart_label.text = "Dardos %d" % darts


func _show_toast(text: String, secs: float = 2.0) -> void:
	_toast.text = text
	_toast.visible = true
	_toast.modulate.a = 1.0
	if _toast_tween != null:
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_interval(secs)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.5)


func relayout(vs: Vector2, top_right_reserved: float) -> void:
	if _stats == null:
		return
	_stats.reset_size()
	_stats.position = Vector2(vs.x - _stats.size.x - 16.0 - top_right_reserved, 14.0)
	# Tela estreita: sem espaço ao lado da ajuda, fica logo abaixo dela.
	var hud: Control = main._hud
	var hud_rect := Rect2(hud.position, hud.get_combined_minimum_size())
	if _stats.position.x < hud_rect.end.x + 8.0:
		_stats.position = Vector2(16.0, hud_rect.end.y + 8.0)
	_toast.offset_top = maxf(120.0, _stats.position.y + _stats.size.y + 14.0)
	_refresh_stats()


func _update_minimap() -> void:
	var mm: Minimap = main._minimap
	if mm == null:
		return
	var dots: Array = []
	for c: Pickup in _coin_nodes:
		dots.append([c.position, Color("ffd23a")])
	for g: Pickup in _gun_nodes:
		dots.append([g.position, Color("4aa8ff")])
	for s: Scorpion in _scorp_nodes:
		dots.append([s.position, Color("ff3a2a") if s.kind == "vermelho" else Color("ff9a2a")])
	mm.dots = dots
