class_name MapScreen
extends Control
## Mapa em tela cheia: carrossel dos cenários, com moedas, Nerfs, escorpiões e corações
## de cada um. Setas trocam a tela e o nome aparece no topo. "Voltar" (ou Esc/M)
## devolve ao jogo com o minimapa no tamanho normal.

signal closed

const ORDER := ["condominio", "oeste", "fundos", "direita", "estacionamento"]
const ARROW_SIZE := Vector2(64, 64)
var main: Node
var _map: Minimap
var _prev: Button
var _next: Button
var _back: Button
var _title: Label
var _area := ""
var _ids: Array[String] = []
var _bg: ColorRect


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_bg = ColorRect.new()
	_bg.color = Color(0.03, 0.05, 0.05, 0.96)
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bg)
	_title = main._label("", 26, main.ACCENT)
	main._wrap_labels.erase(_title)
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_title)
	for id: String in ORDER:
		if (main.areas as Dictionary).has(id):
			_ids.append(id)
	_map = Minimap.new()
	_map.interactive = false
	_map.marker_scale = 2.0
	add_child(_map)
	_prev = _arrow_button("←", -1)
	_next = _arrow_button("→", 1)
	_back = main._make_button("Voltar")
	_back.custom_minimum_size = Vector2(150, 46)
	_back.pressed.connect(close)
	add_child(_back)


func _arrow_button(glyph: String, delta: int) -> Button:
	var b: Button = main._make_button(glyph)
	b.custom_minimum_size = ARROW_SIZE
	b.size = ARROW_SIZE
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 28)
	b.pressed.connect(_shift.bind(delta))
	add_child(b)
	return b


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
	if _ids.is_empty():
		return
	if not _ids.has(id):
		id = _ids[0]
	_area = id
	var a: Dictionary = main.areas[id]
	_title.text = String(a["title"])
	var tex := load(String(a["walk"]).get_base_dir() + "/minimap.png") as Texture2D
	var wsize := (load(String(a["bg"])) as Texture2D).get_size()
	var vs := get_viewport_rect().size
	var header := _title_block(vs)
	var side := ARROW_SIZE.x + 28.0
	var room := Vector2(maxf(80.0, vs.x - side * 2.0), maxf(80.0, vs.y - header - 76.0))
	var k := minf(room.x / wsize.x, (room.y - 34.0 - Minimap.LEGEND_H) / wsize.y)
	_map.max_side = maxf(wsize.x, wsize.y) * k
	_map.set_area(tex, wsize, a["exits"], String(a["title"]))
	_refresh()
	_layout()


func _shift(delta: int) -> void:
	if _ids.is_empty():
		return
	var i := _ids.find(_area)
	if i < 0:
		i = 0
	show_area(_ids[posmod(i + delta, _ids.size())])


func _title_block(vs: Vector2) -> float:
	var w := maxf(40.0, vs.x - 32.0)
	_title.custom_minimum_size = Vector2(w, 0)
	return 14.0 + _title.get_minimum_size().y + 12.0


func _layout() -> void:
	var vs := get_viewport_rect().size
	position = Vector2.ZERO
	size = vs
	_bg.position = Vector2.ZERO
	_bg.size = vs
	var title_w := maxf(40.0, vs.x - 32.0)
	_title.custom_minimum_size = Vector2(title_w, 0)
	_title.size = Vector2(title_w, _title.get_minimum_size().y)
	_title.position = Vector2(16.0, 14.0)
	var header := 14.0 + _title.size.y + 12.0
	_map.position = Vector2((vs.x - _map.size.x) * 0.5, header)
	_prev.size = ARROW_SIZE
	_next.size = ARROW_SIZE
	var map_body := maxf(ARROW_SIZE.y, _map.size.y - Minimap.LEGEND_H)
	var ay := clampf(_map.position.y + map_body * 0.5 - ARROW_SIZE.y * 0.5, header, maxf(header, vs.y - ARROW_SIZE.y - 16.0))
	_prev.position = Vector2(12.0, ay)
	_next.position = Vector2(vs.x - 12.0 - ARROW_SIZE.x, ay)
	_back.size = _back.custom_minimum_size
	_back.position = Vector2((vs.x - _back.size.x) * 0.5, minf(vs.y - _back.size.y - 16.0, _map.position.y + _map.size.y + 14.0))


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


func _input(event: InputEvent) -> void:
	if not visible:
		return
	var dir := _carousel_dir(event)
	if dir == 0:
		return
	_shift(dir)
	get_viewport().set_input_as_handled()


## Setas (e o foco padrão ui_left/ui_right). WASD fica de fora: no jogo elas andam.
func _carousel_dir(event: InputEvent) -> int:
	if not event.is_pressed() or event.is_echo():
		return 0
	if event is InputEventKey:
		var key := event as InputEventKey
		var code := key.keycode if key.keycode != KEY_NONE else key.physical_keycode
		if code == KEY_A or code == KEY_D or code == KEY_W or code == KEY_S:
			return 0
		if code == KEY_LEFT:
			return -1
		if code == KEY_RIGHT:
			return 1
	if event.is_action_pressed("ui_left"):
		return -1
	if event.is_action_pressed("ui_right"):
		return 1
	return 0


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).keycode == KEY_M):
		close()
		get_viewport().set_input_as_handled()
