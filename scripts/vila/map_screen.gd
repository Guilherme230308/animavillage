class_name MapScreen
extends Control
## Mapa em tela cheia: abas para cada cenário, com moedas, Nerfs, escorpiões e corações
## de cada um. "Voltar" (ou Esc/M) devolve ao jogo com o minimapa no tamanho normal.

signal closed

const ORDER := ["condominio", "oeste", "fundos", "direita", "estacionamento"]
var main: Node
var _map: Minimap
var _tabs: HBoxContainer
var _tab_buttons: Dictionary = {}
var _back: Button
var _title: Label
var _area := ""
var _bg: ColorRect


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_bg = ColorRect.new()
	_bg.color = Color(0.03, 0.05, 0.05, 0.96)
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bg)
	_title = main._label("Mapa", 26, main.ACCENT)
	add_child(_title)
	_tabs = HBoxContainer.new()
	_tabs.add_theme_constant_override("separation", 8)
	add_child(_tabs)
	for id: String in ORDER:
		if not (main.areas as Dictionary).has(id):
			continue
		var b: Button = main._make_button(String(main.areas[id]["title"]))
		b.toggle_mode = true
		b.custom_minimum_size = Vector2(0, 40)
		b.add_theme_font_size_override("font_size", 15)
		var cid := id
		b.pressed.connect(func() -> void: show_area(cid))
		_tabs.add_child(b)
		_tab_buttons[id] = b
	_map = Minimap.new()
	_map.interactive = false
	_map.marker_scale = 2.0
	add_child(_map)
	_back = main._make_button("Voltar")
	_back.custom_minimum_size = Vector2(150, 46)
	_back.pressed.connect(close)
	add_child(_back)


func open() -> void:
	visible = true
	move_to_front()
	show_area(String(main.current_area))
	_back.call_deferred("grab_focus")


func close() -> void:
	if not visible:
		return
	visible = false
	closed.emit()


func is_open() -> bool:
	return visible


func current_tab() -> String:
	return _area


func show_area(id: String) -> void:
	_area = id
	for k: String in _tab_buttons:
		(_tab_buttons[k] as Button).button_pressed = k == id
	var a: Dictionary = main.areas[id]
	var tex := load(String(a["walk"]).get_base_dir() + "/minimap.png") as Texture2D
	var wsize := (load(String(a["bg"])) as Texture2D).get_size()
	var vs := get_viewport_rect().size
	var tabs_h := _tabs.get_combined_minimum_size().y
	var room := Vector2(vs.x - 40.0, vs.y - tabs_h - 150.0)
	var k := minf(room.x / wsize.x, (room.y - 34.0 - Minimap.LEGEND_H) / wsize.y)
	_map.max_side = maxf(wsize.x, wsize.y) * k
	_map.set_area(tex, wsize, a["exits"], String(a["title"]))
	_refresh()
	_layout()


func _layout() -> void:
	var vs := get_viewport_rect().size
	position = Vector2.ZERO
	size = vs
	_bg.position = Vector2.ZERO
	_bg.size = vs
	_title.position = Vector2(20, 12)
	var tw := _tabs.get_combined_minimum_size()
	# Abas em várias linhas se a tela for estreita: reduz a fonte.
	var fs := 15 if tw.x < vs.x - 40 else 12
	for b: Button in _tab_buttons.values():
		b.add_theme_font_size_override("font_size", fs)
	tw = _tabs.get_combined_minimum_size()
	_tabs.size = tw
	_tabs.position = Vector2(maxf(20.0, (vs.x - tw.x) * 0.5), 52)
	_map.position = Vector2((vs.x - _map.size.x) * 0.5, _tabs.position.y + tw.y + 14)
	_back.position = Vector2((vs.x - _back.size.x) * 0.5, minf(vs.y - _back.size.y - 16, _map.position.y + _map.size.y + 14))


func _process(_delta: float) -> void:
	if visible:
		_refresh()


func _refresh() -> void:
	var adv: Adventure = main.adventure
	var data := adv.markers_for(_area) if adv != null else {"dots": [], "counts": {}}
	_map.dots = data["dots"]
	if adv != null and adv.active:
		_map.counts = data["counts"]
		_map.show_legend = true
	else:
		_map.show_legend = false
	_map.player_pos = main._player.position if _area == main.current_area else Vector2(-99999, -99999)
	_map.target_pos = Vector2.INF


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).keycode == KEY_M):
		close()
		get_viewport().set_input_as_handled()
