extends Control
## Anima Village: caminhada livre pelo condomínio em pixel art.

const AREAS_PATH := "res://assets/game/areas.json"
const START_AREA := "condominio"
const START_SPAWN := "inicio"
const CHARACTERS := [
	{"id": "sophia", "name": "Sophia", "sheet": "res://assets/game/sophia.png", "sheet_hd": "res://assets/game/sophia_hd.png"},
	{"id": "luiza", "name": "Luiza", "sheet": "res://assets/game/luiza.png", "sheet_hd": "res://assets/game/luiza_hd.png"},
	{"id": "antonio", "name": "Antônio", "sheet": "res://assets/game/antonio.png", "sheet_hd": "res://assets/game/antonio_hd.png"},
	{"id": "gabriel", "name": "Gabriel", "sheet": "res://assets/game/gabriel.png", "sheet_hd": "res://assets/game/gabriel_hd.png"},
	{"id": "vini", "name": "Vini", "sheet": "res://assets/game/vini.png", "sheet_hd": "res://assets/game/vini_hd.png"},
	{"id": "guilherme", "name": "Guilherme", "sheet": "res://assets/game/guilherme.png", "sheet_hd": "res://assets/game/guilherme_hd.png"},
]
const ZOOM_MIN := 1.25
const ZOOM_MAX := 4.0
## Trocar Arma e Atirar usam o mesmo retângulo no toque.
const TOUCH_ACTION_SIZE := Vector2(124, 104)
const ACCENT := Color("e9a15b")
const PANEL_BG := Color(0.07, 0.09, 0.08, 0.88)

var walk_map := WalkMap.new()
var _viewport_container: SubViewportContainer
var _sub_viewport: SubViewport
var _world: Node2D
var _player: Walker
var _camera: Camera2D
var _paths_overlay: Sprite2D
var _title_screen: Control
var _pause_screen: Control
var _hud: Control
var _hint_label: Label
var _start_button: Button
var _resume_button: Button
var _playing := false
var _paused := false
var _target_zoom := ZOOM_MIN
var distance_walked := 0.0
var _towers: Array[Dictionary] = []
var areas: Dictionary = {}
var current_area := ""
var _ground: Node2D
var _area_nodes: Array[Node] = []
var _fade: ColorRect
var _area_banner: Label
var _area_banner_tween: Tween
var _transitioning := false

## Andares acima do nível da rua (o Térreo fica 2 andares acima das ruas e do estacionamento).
const FLOORS := {"condominio": 2}
var _area_label: Label
var character := "sophia"
var _character_buttons: Dictionary = {}
var _char_grid: GridContainer
var _char_block: VBoxContainer
var _title_rules: Label
var _phase_box: VBoxContainer
var _phase_heading: Label
var _phase_buttons: Array[Button] = []
var _char_previews: Array[TextureRect] = []
var touch_mode := false
var _joystick: TouchJoystick
var _touch_layer: Control
var _touch_buttons: Dictionary = {}
var _wrap_labels: Array[Label] = []
var _panels: Array[PanelContainer] = []
var _controls_label: Label
var _finder := PathFinder.new()
var _finder_area := ""
var move_path := PackedVector2Array()
var _path_i := 0
var _stuck_t := 0.0
var _marker: Node2D
var _minimap: Minimap
var _map_screen: MapScreen
## Dica temporária: onde a personagem está e um conselho, por cerca de 3 segundos.
var _tip_panel: Panel
var _tip_where: Label
var _tip_body: Label
var _tip_left := 0.0
var _tip_wait := 0.0
var _tip_last := -1
var _swap_buttons: Dictionary = {}
var adventure: Adventure
var _floor_img: Image


func _ready() -> void:
	# O clique no chão tem de chegar em _unhandled_input. Com o filtro padrão
	# (STOP) o Control raiz consome o mouse no GUI e o personagem não anda.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ensure_actions()
	areas = JSON.parse_string(FileAccess.get_file_as_string(AREAS_PATH))
	_build_world()
	touch_mode = DisplayServer.is_touchscreen_available()
	_build_ui()
	_build_touch_ui()
	adventure = Adventure.new()
	adventure.main = self
	add_child(adventure)
	get_tree().root.size_changed.connect(_relayout)
	_relayout()
	_show_title()


func _ensure_actions() -> void:
	var extra := {"shoot": [KEY_SPACE, KEY_F], "run": [KEY_SHIFT], "toggle_paths": [KEY_M], "zoom_in": [KEY_EQUAL, KEY_KP_ADD], "zoom_out": [KEY_MINUS, KEY_KP_SUBTRACT]}
	for action: String in extra:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
			for key: int in extra[action]:
				var ev := InputEventKey.new()
				ev.physical_keycode = key
				InputMap.action_add_event(action, ev)


func _build_world() -> void:
	_viewport_container = SubViewportContainer.new()
	_viewport_container.stretch = true
	_viewport_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	_viewport_container.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(_viewport_container)
	_sub_viewport = SubViewport.new()
	_sub_viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	_sub_viewport.snap_2d_transforms_to_pixel = true
	_viewport_container.add_child(_sub_viewport)

	_world = Node2D.new()
	_sub_viewport.add_child(_world)

	_ground = Node2D.new()
	_ground.z_index = -10
	_world.add_child(_ground)
	_world.y_sort_enabled = true

	_player = Walker.new()
	_player.walk_map = walk_map
	_world.add_child(_player)

	_camera = Camera2D.new()
	_camera.zoom = Vector2.ONE * ZOOM_MIN
	_camera.position_smoothing_enabled = true
	_camera.position_smoothing_speed = 7.0
	_player.add_child(_camera)
	_camera.make_current()
	load_area(START_AREA, START_SPAWN)


## Troca a tela atual: cenário, máscara de caminhos, torres e posição de chegada.
func load_area(id: String, spawn: String) -> void:
	var a: Dictionary = areas[id]
	if adventure != null:
		adventure.on_area_leaving()
	for n in _area_nodes:
		n.queue_free()
	_area_nodes.clear()
	_towers.clear()
	current_area = id
	var tex := load(String(a["bg"])) as Texture2D
	_floor_img = tex.get_image()
	if _floor_img != null and _floor_img.is_compressed():
		_floor_img.decompress()
	var bg := Sprite2D.new()
	bg.texture = tex
	bg.centered = false
	bg.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_ground.add_child(bg)
	_area_nodes.append(bg)
	walk_map.load_mask(String(a["walk"]))
	_player.set_stairs(a.get("stairs", []))
	var was_visible := _paths_overlay != null and _paths_overlay.visible
	_paths_overlay = Sprite2D.new()
	_paths_overlay.texture = _build_paths_texture()
	_paths_overlay.centered = false
	_paths_overlay.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_paths_overlay.scale = Vector2(WalkMap.CELL, WalkMap.CELL)
	_paths_overlay.visible = was_visible
	_ground.add_child(_paths_overlay)
	_area_nodes.append(_paths_overlay)
	if String(a.get("towers", "")) != "":
		_build_towers(String(a["towers"]))
	var size := tex.get_size()
	_build_exit_signs(a, size)
	_camera.limit_left = 0
	_camera.limit_top = 0
	_camera.limit_right = int(size.x)
	_camera.limit_bottom = int(size.y)
	var sp: Array = (a["spawns"] as Dictionary)[spawn]
	_player.position = walk_map.nearest_walkable(Vector2(float(sp[0]), float(sp[1])), Walker.FOOT_HALF)
	_camera.reset_smoothing()
	clear_move()
	if _minimap != null:
		var mm_path := String(a["walk"]).get_base_dir() + "/minimap.png"
		_minimap.set_area(load(mm_path) as Texture2D, size, a["exits"], String(a["title"]))
		_relayout()
	if _area_label != null:
		_area_label.text = area_hud_text(id)
	if _hint_label != null:
		_update_hint()
	if adventure != null:
		adventure.on_area_loaded()


## Garante o buscador de rotas da tela atual (clique para andar e escorpiões).
func ensure_finder() -> void:
	if _finder_area != current_area:
		_finder.build(walk_map)
		_finder_area = current_area


## Placa no chão de cada saída: seta para fora e o nome da tela seguinte.
func _build_exit_signs(a: Dictionary, size: Vector2) -> void:
	for e: Dictionary in a["exits"]:
		var r: Array = e["rect"]
		var rect := Rect2(float(r[0]), float(r[1]), float(r[2]), float(r[3]))
		if e.has("elevator"):
			_build_elevator_marker(e, rect, size)
			continue
		var c := rect.get_center()
		var dir := Vector2.LEFT
		if e.has("dir"):
			var d: Array = e["dir"]
			dir = Vector2(float(d[0]), float(d[1])).normalized()
		elif rect.position.x <= 1.0:
			dir = Vector2.LEFT
		elif rect.end.x >= size.x - 1.0:
			dir = Vector2.RIGHT
		elif rect.position.y <= 1.0:
			dir = Vector2.UP
		elif rect.end.y >= size.y - 1.0:
			dir = Vector2.DOWN
		var sign := Node2D.new()
		sign.position = c - dir * 22.0
		sign.z_index = 30
		var arrow := Polygon2D.new()
		arrow.polygon = PackedVector2Array([Vector2(14, 0), Vector2(-6, -11), Vector2(-2, 0), Vector2(-6, 11)])
		arrow.rotation = dir.angle()
		arrow.color = Color(1.0, 0.86, 0.35, 0.95)
		var outline := Line2D.new()
		outline.points = arrow.polygon
		outline.add_point(arrow.polygon[0])
		outline.width = 1.5
		outline.default_color = Color(0.15, 0.1, 0.05, 0.9)
		outline.rotation = arrow.rotation
		sign.add_child(arrow)
		sign.add_child(outline)
		var lbl := Label.new()
		lbl.text = String((areas[String(e["to"])] as Dictionary)["title"])
		lbl.add_theme_font_size_override("font_size", 13)
		lbl.add_theme_color_override("font_color", Color("fff1c9"))
		lbl.add_theme_constant_override("outline_size", 5)
		lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.size = Vector2(170, 20)
		lbl.position = Vector2(-85, 14) if dir.y >= 0.0 else Vector2(-85, -34)
		if abs(dir.y) < 0.5:
			lbl.position = Vector2(-85, -32)
		# Mantém o texto dentro do mapa nas saídas de borda.
		lbl.position.x = clampf(lbl.position.x, 4.0 - sign.position.x, size.x - 4.0 - sign.position.x - lbl.size.x)
		lbl.position.y = clampf(lbl.position.y, 4.0 - sign.position.y, size.y - 24.0 - sign.position.y)
		sign.add_child(lbl)
		_ground.add_child(sign)
		_area_nodes.append(sign)
		var tw := sign.create_tween().set_loops()
		tw.tween_property(arrow, "position", dir * 6.0, 0.5).set_trans(Tween.TRANS_SINE)
		tw.parallel().tween_property(outline, "position", dir * 6.0, 0.5).set_trans(Tween.TRANS_SINE)
		tw.tween_property(arrow, "position", Vector2.ZERO, 0.5).set_trans(Tween.TRANS_SINE)
		tw.parallel().tween_property(outline, "position", Vector2.ZERO, 0.5).set_trans(Tween.TRANS_SINE)


## Marcador de elevador: brilho pulsante no local e o nome do destino.
func _build_elevator_marker(e: Dictionary, rect: Rect2, size: Vector2) -> void:
	var node := Node2D.new()
	node.position = rect.get_center()
	node.z_index = 30
	var radius := maxf(rect.size.x, rect.size.y) * 0.9 + 14.0
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
	grad.colors = PackedColorArray([Color(1.0, 0.97, 0.78, 0.85), Color(0.75, 0.93, 1.0, 0.35), Color(0.75, 0.93, 1.0, 0.0)])
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 128
	tex.height = 128
	var glow := Sprite2D.new()
	glow.texture = tex
	glow.scale = Vector2.ONE * (radius * 2.0 / 128.0)
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	glow.material = mat
	node.add_child(glow)
	var lbl := Label.new()
	var dest := String((areas[String(e["to"])] as Dictionary)["title"])
	lbl.text = "Elevador %s" % dest
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", Color(1.0, 0.97, 0.85))
	lbl.add_theme_constant_override("outline_size", 5)
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.size = Vector2(190, 22)
	lbl.position = Vector2(-95, -radius - 22)
	lbl.position.x = clampf(lbl.position.x, 4.0 - node.position.x, size.x - 4.0 - node.position.x - lbl.size.x)
	lbl.position.y = clampf(lbl.position.y, 4.0 - node.position.y, size.y - 24.0 - node.position.y)
	node.add_child(lbl)
	_ground.add_child(node)
	_area_nodes.append(node)
	var base := glow.scale
	var tw := node.create_tween().set_loops()
	tw.tween_property(glow, "scale", base * 1.18, 0.8).set_trans(Tween.TRANS_SINE)
	tw.tween_property(glow, "scale", base * 0.9, 0.8).set_trans(Tween.TRANS_SINE)


## Saída em que o personagem está pisando, se houver.
func exit_at(p: Vector2) -> Dictionary:
	for e: Dictionary in (areas[current_area] as Dictionary)["exits"]:
		var r: Array = e["rect"]
		if Rect2(float(r[0]), float(r[1]), float(r[2]), float(r[3])).has_point(p):
			return e
	return {}


func floor_of(id: String) -> int:
	return int(FLOORS.get(id, 0))


## Título da tela com a indicação de andar, usado no painel superior.
func area_hud_text(id: String) -> String:
	var title := String((areas[id] as Dictionary)["title"])
	var f := floor_of(id)
	if f > 0:
		return "%s · %d andares acima da rua" % [title, f]
	return "%s · nível da rua" % title


func _go_through(e: Dictionary, animate: bool = true) -> void:
	if not animate:
		load_area(String(e["to"]), String(e["spawn"]))
		return
	_transitioning = true
	var delta := floor_of(String(e["to"])) - floor_of(current_area)
	var tw := create_tween()
	if delta != 0:
		# Escada entre o Térreo e a rua: escurece mais devagar e avisa quantos andares.
		var word := "Descendo" if delta < 0 else "Subindo"
		if e.has("elevator"):
			word = "Elevador descendo" if delta < 0 else "Elevador subindo"
		var n := absi(delta)
		tw.tween_property(_fade, "color:a", 1.0, 0.45)
		tw.tween_callback(func() -> void:
			if _area_banner_tween != null:
				_area_banner_tween.kill()
			_area_banner.text = "%s %s…" % [word, "dois andares" if n == 2 else "%d andares" % n]
			_area_banner.modulate.a = 1.0
			_area_banner.visible = true)
		tw.tween_interval(0.7)
		tw.tween_callback(func() -> void:
			load_area(String(e["to"]), String(e["spawn"]))
			_show_banner(String((areas[current_area] as Dictionary)["title"])))
		tw.tween_property(_fade, "color:a", 0.0, 0.55)
	else:
		tw.tween_property(_fade, "color:a", 1.0, 0.22)
		tw.tween_callback(func() -> void:
			load_area(String(e["to"]), String(e["spawn"]))
			_show_banner(String((areas[current_area] as Dictionary)["title"])))
		tw.tween_property(_fade, "color:a", 0.0, 0.28)
	tw.tween_callback(func() -> void: _transitioning = false)


func _show_banner(text: String, hold: float = 1.6) -> void:
	_area_banner.text = text
	_area_banner.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_area_banner.offset_left = 28
	_area_banner.offset_right = -28
	_area_banner.offset_top = 78
	_area_banner.offset_bottom = 188
	if _area_banner_tween != null:
		_area_banner_tween.kill()
	_area_banner.modulate.a = 1.0
	_area_banner.visible = true
	_area_banner_tween = create_tween()
	_area_banner_tween.tween_interval(hold)
	_area_banner_tween.tween_property(_area_banner, "modulate:a", 0.0, 0.6)


## Piso sob o pé, lido do cenário: grama, bege, terracota ou outro.
func floor_kind(p: Vector2) -> String:
	if _floor_img == null:
		return "outro"
	var x := clampi(int(p.x), 0, _floor_img.get_width() - 1)
	var y := clampi(int(p.y), 0, _floor_img.get_height() - 1)
	return classify_floor(_floor_img.get_pixel(x, y))


static func classify_floor(c: Color) -> String:
	var r := c.r
	var g := c.g
	var b := c.b
	if g > r + 0.08 and g > b + 0.05 and g > 0.22:
		return "grama"
	if r > 0.45 and g > 0.28 and r >= g - 0.02 and g >= b and (r - b) > 0.12 and (r - b) < 0.72 and b < r * 0.85:
		if r > 0.9 and g > 0.9 and b > 0.85:
			return "outro"
		if r > 0.82 and g > 0.70 and (r - g) < 0.22:
			return "bege"
		return "terracota"
	return "outro"


func _build_towers(path: String) -> void:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(data) != TYPE_ARRAY:
		push_error("towers.json inválido")
		return
	for t: Dictionary in data:
		var tex := load(path.get_base_dir() + "/" + String(t["file"])) as Texture2D
		var holder := Node2D.new()
		holder.position = Vector2(0, float(t["sort_y"]))
		var sprite := Sprite2D.new()
		sprite.texture = tex
		sprite.centered = false
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.position = Vector2(float(t["x"]), float(t["y"]) - float(t["sort_y"]))
		holder.add_child(sprite)
		_world.add_child(holder)
		_area_nodes.append(holder)
		var img := tex.get_image()
		if img != null and img.is_compressed():
			img.decompress()
		_towers.append({"origin": Vector2(float(t["x"]), float(t["y"])), "sort_y": float(t["sort_y"]), "image": img})


## Verdadeiro se alguma torre à frente cobre o corpo do personagem.
func is_occluded(feet: Vector2) -> bool:
	for t: Dictionary in _towers:
		if feet.y >= float(t["sort_y"]):
			continue
		var img: Image = t["image"]
		if img == null:
			continue
		for probe: Vector2 in [Vector2(0, -6), Vector2(0, -18), Vector2(0, -30)]:
			var local := feet + probe - (t["origin"] as Vector2)
			if local.x >= 0 and local.y >= 0 and local.x < img.get_width() and local.y < img.get_height():
				if img.get_pixel(int(local.x), int(local.y)).a > 0.5:
					return true
	return false


func _build_paths_texture() -> ImageTexture:
	var img := Image.create(walk_map.width, walk_map.height, false, Image.FORMAT_RGBA8)
	for y in walk_map.height:
		for x in walk_map.width:
			if walk_map.is_cell_walkable(x, y):
				img.set_pixel(x, y, Color(1.0, 0.92, 0.35, 0.38))
			else:
				img.set_pixel(x, y, Color(0.05, 0.0, 0.1, 0.32))
	return ImageTexture.create_from_image(img)


func _panel_style(radius: int = 14) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = PANEL_BG
	sb.border_color = ACCENT
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(radius)
	sb.set_content_margin_all(28)
	return sb


func _make_button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(280, 52)
	b.add_theme_font_size_override("font_size", 22)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color("2b3a2c")
	normal.border_color = ACCENT
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(8)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color("4a6243")
	var focus := hover.duplicate() as StyleBoxFlat
	focus.border_color = Color("fff1c9")
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", hover)
	b.add_theme_stylebox_override("focus", focus)
	b.add_theme_color_override("font_color", Color("fff1c9"))
	return b


func _centered_panel() -> Array:
	var screen := Control.new()
	screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.35)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	screen.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	screen.add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _panel_style())
	center.add_child(panel)
	_panels.append(panel)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 16)
	panel.add_child(box)
	add_child(screen)
	return [screen, box]


func _label(text: String, size: int, color: Color = Color("fff1c9")) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_wrap_labels.append(l)
	return l


func _build_ui() -> void:
	# HUD
	_hud = MarginContainer.new()
	_hud.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_hud.add_theme_constant_override("margin_left", 16)
	_hud.add_theme_constant_override("margin_top", 14)
	_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hud)
	var hud_panel := PanelContainer.new()
	var hs := _panel_style(10)
	hs.set_content_margin_all(12)
	hs.set_border_width_all(2)
	hud_panel.add_theme_stylebox_override("panel", hs)
	hud_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(hud_panel)
	_hint_label = _label("", 16)
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_hint_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_wrap_labels.erase(_hint_label)
	var hud_box := VBoxContainer.new()
	hud_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_panel.add_child(hud_box)
	_area_label = _label(area_hud_text(current_area), 18, ACCENT)
	_area_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_area_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_wrap_labels.erase(_area_label)
	hud_box.add_child(_area_label)
	hud_box.add_child(_hint_label)
	_update_hint()

	_area_banner = _label("", 34, Color("fff1c9"))
	_wrap_labels.erase(_area_banner)
	_area_banner.autowrap_mode = TextServer.AUTOWRAP_OFF
	_area_banner.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_area_banner.offset_top = 90
	_area_banner.add_theme_constant_override("outline_size", 8)
	_area_banner.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_area_banner.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_area_banner.visible = false
	_area_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_area_banner)

	# Título
	var t := _centered_panel()
	_title_screen = t[0]
	var tbox: VBoxContainer = t[1]
	tbox.add_child(_label("ANIMA VILLAGE", 56, ACCENT))
	tbox.add_child(_label("Junte as moedas espalhadas pelo condomínio e pelas ruas para passar de nível.", 20))
	tbox.add_child(_label("Armas: Nerf (dardos), Super Soaker (molha e deixa lento) e Espalhadora (cinco dardos em leque).", 16, Color("cfd8c4")))
	_title_rules = _label("Nível 1 · dia fácil: moedas, escorpiões e o Nerf. Nível 2 · noite: a lanterna ilumina pouco e entra a Espalhadora. Nível 3 · chuva de dia: poças deixam 30% mais lento, o chão bege e terracota escorrega (a grama não), dardos molhados perdem alcance, e sob a marquise ou a torre coberta não chove (+5% de vida). Uma capa de chuva. Nível 4 · noite de chuva: escorpiões saem dos ralos — tampe os bueiros. O relâmpago revela os escorpiões e o raio cai no círculo. A escada oeste leva às ruas.", 15, Color("cfd8c4"))
	tbox.add_child(_title_rules)
	_controls_label = _label("", 15, Color("cfd8c4"))
	tbox.add_child(_controls_label)
	_char_block = VBoxContainer.new()
	_char_block.add_theme_constant_override("separation", 16)
	tbox.add_child(_char_block)
	_char_block.add_child(_label("Escolha com quem jogar:", 20, ACCENT))
	var row := GridContainer.new()
	row.columns = 3
	row.add_theme_constant_override("h_separation", 14)
	row.add_theme_constant_override("v_separation", 10)
	var grid_center := CenterContainer.new()
	grid_center.add_child(row)
	_char_block.add_child(grid_center)
	_char_grid = row
	for c: Dictionary in CHARACTERS:
		var card := VBoxContainer.new()
		card.alignment = BoxContainer.ALIGNMENT_CENTER
		card.add_theme_constant_override("separation", 8)
		row.add_child(card)
		var prev := TextureRect.new()
		var atlas := AtlasTexture.new()
		atlas.atlas = load(String(c["sheet_hd"])) as Texture2D
		atlas.region = Rect2(0, 0, Walker.HD_FRAME_W, Walker.HD_FRAME_H)
		prev.texture = atlas
		prev.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		prev.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		prev.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		prev.custom_minimum_size = Vector2(Walker.HD_FRAME_W, Walker.HD_FRAME_H)
		card.add_child(prev)
		_char_previews.append(prev)
		var b := _make_button(String(c["name"]))
		b.custom_minimum_size = Vector2(140, 46)
		var cid := String(c["id"])
		b.pressed.connect(_on_title_character.bind(cid))
		card.add_child(b)
		_character_buttons[cid] = b
	_start_button = _character_buttons["sophia"]
	_build_phase_picker(tbox)

	# Pausa
	var p := _centered_panel()
	_pause_screen = p[0]
	var pbox: VBoxContainer = p[1]
	pbox.add_child(_label("Pausado", 40, ACCENT))
	_resume_button = _make_button("Continuar")
	_resume_button.pressed.connect(_resume)
	pbox.add_child(_resume_button)
	pbox.add_child(_label("Trocar de personagem (o nível continua):", 18, Color("cfd8c4")))
	var swap := GridContainer.new()
	swap.columns = 3
	swap.add_theme_constant_override("h_separation", 8)
	swap.add_theme_constant_override("v_separation", 8)
	var swap_center := CenterContainer.new()
	swap_center.add_child(swap)
	pbox.add_child(swap_center)
	for c: Dictionary in CHARACTERS:
		var sb := _make_button(String(c["name"]))
		sb.custom_minimum_size = Vector2(120, 40)
		var sid := String(c["id"])
		sb.pressed.connect(func() -> void: swap_character(sid))
		swap.add_child(sb)
		_swap_buttons[sid] = sb
	var restart := _make_button("Voltar ao início da fase")
	restart.pressed.connect(restart_phase)
	pbox.add_child(restart)
	var to_menu := _make_button("Menu inicial")
	to_menu.pressed.connect(_back_to_title)
	pbox.add_child(to_menu)

	_minimap = Minimap.new()
	_minimap.open_requested.connect(open_map)
	add_child(_minimap)
	_build_tip_panel()
	_map_screen = MapScreen.new()
	_map_screen.main = self
	_map_screen.closed.connect(_on_map_closed)
	add_child(_map_screen)
	var a0: Dictionary = areas[current_area]
	_minimap.set_area(load(String(a0["walk"]).get_base_dir() + "/minimap.png") as Texture2D,
		(load(String(a0["bg"])) as Texture2D).get_size(), a0["exits"], String(a0["title"]))
	_marker = Node2D.new()
	_marker.z_index = 40
	_marker.visible = false
	_marker.set_script(load("res://scripts/vila/move_marker.gd"))
	_world.add_child(_marker)

	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 0)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fade)
	if _area_banner != null:
		move_child(_area_banner, get_child_count() - 1)


func _build_phase_picker(tbox: VBoxContainer) -> void:
	_phase_box = VBoxContainer.new()
	_phase_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_phase_box.add_theme_constant_override("separation", 12)
	_phase_box.visible = false
	tbox.add_child(_phase_box)
	_phase_heading = _label("Escolha a fase:", 20, ACCENT)
	_phase_box.add_child(_phase_heading)
	var previous: Button = null
	for i: int in Adventure.PHASES.size():
		var ph: Dictionary = Adventure.PHASES[i]
		var pb := _make_button(String(ph["name"]))
		pb.pressed.connect(_start_picked_phase.bind(i))
		_phase_box.add_child(pb)
		_phase_buttons.append(pb)
		if previous != null:
			previous.focus_neighbor_bottom = previous.get_path_to(pb)
			pb.focus_neighbor_top = pb.get_path_to(previous)
		previous = pb
	var back := _make_button("Voltar")
	back.pressed.connect(_close_phase_picker)
	_phase_box.add_child(back)
	if previous != null:
		previous.focus_neighbor_bottom = previous.get_path_to(back)
		back.focus_neighbor_top = back.get_path_to(previous)


func _phase_picker_open() -> bool:
	return _phase_box != null and _phase_box.visible and _title_screen != null and _title_screen.visible and not _playing


func _set_phase_picker(on: bool) -> void:
	if _phase_box == null:
		return
	_phase_box.visible = on
	if _char_block != null:
		_char_block.visible = not on
	if _title_rules != null:
		_title_rules.visible = not on
	if _controls_label != null:
		_controls_label.visible = not on


func _open_phase_picker() -> void:
	_phase_heading.text = "Escolha a fase — %s" % _character_name(character)
	_set_phase_picker(true)
	if not _phase_buttons.is_empty():
		_phase_buttons[0].call_deferred("grab_focus")


func _close_phase_picker() -> void:
	_set_phase_picker(false)
	var b: Button = _character_buttons.get(character) as Button
	if b != null:
		b.call_deferred("grab_focus")


func _on_title_character(cid: String) -> void:
	AudioDirector.unlock_audio()
	if cid == "sophia" or cid == "luiza":
		select_character(cid)
		_open_phase_picker()
		return
	_start(cid)


func _start_picked_phase(idx: int) -> void:
	AudioDirector.unlock_audio()
	_start(character, idx)


func _update_hint() -> void:
	var on := _paths_overlay != null and _paths_overlay.visible
	var paths := "ligado" if on else "desligado"
	if touch_mode:
		_hint_label.text = "Toque no chão para andar · no escorpião para atirar"
	else:
		_hint_label.text = "Clique no chão para andar · no escorpião para atirar · 1/2/3 ou Q: arma · Shift correr · M caminhos (%s)" % paths
	if _touch_buttons.has("paths"):
		var b: TouchButton = _touch_buttons["paths"]
		b.text = "Ocultar" if on else "Caminhos"
		b.queue_redraw()
	if _controls_label != null:
		if touch_mode:
			_controls_label.text = "No celular: toque no chão para ir até lá, ou toque num escorpião para atirar nele. Arraste na metade direita para andar com o direcional. O botão Atirar mira no escorpião mais próximo."
		else:
			_controls_label.text = "Clique no chão para andar  ·  Clique num escorpião para atirar nele  ·  Setas/WASD: andar  ·  Shift: correr\nEspaço ou F: atirar no escorpião mais próximo  ·  Botão direito: atirar para onde apontar\nM: caminhos  ·  Roda do mouse ou +/−: zoom  ·  Esc: pausar"


func _build_touch_ui() -> void:
	_touch_layer = Control.new()
	_touch_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_touch_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_touch_layer)
	move_child(_touch_layer, _hud.get_index() + 1)
	_joystick = TouchJoystick.new()
	_joystick.touched.connect(_enable_touch_mode)
	_touch_layer.add_child(_joystick)
	var defs := [["paths", "Caminhos", Vector2(124, 64)], ["zoom_in", "+", Vector2(64, 64)], ["zoom_out", "−", Vector2(64, 64)], ["pause", "II", Vector2(60, 60)]]
	for d: Array in defs:
		var b := TouchButton.new(d[1], d[2])
		b.font_size = 30 if d[0] in ["zoom_in", "zoom_out"] else 20
		_touch_layer.add_child(b)
		_touch_buttons[d[0]] = b
	(_touch_buttons["paths"] as TouchButton).tapped.connect(_toggle_paths)
	(_touch_buttons["zoom_in"] as TouchButton).tapped.connect(func() -> void: _zoom_by(1.2))
	(_touch_buttons["zoom_out"] as TouchButton).tapped.connect(func() -> void: _zoom_by(1.0 / 1.2))
	(_touch_buttons["pause"] as TouchButton).tapped.connect(_open_pause)
	var shoot := TouchButton.new("Atirar", TOUCH_ACTION_SIZE)
	shoot.font_size = 22
	_touch_layer.add_child(shoot)
	_touch_buttons["shoot"] = shoot
	shoot.tapped.connect(func() -> void: adventure.shoot())
	var swap_w := TouchButton.new("Trocar Arma", TOUCH_ACTION_SIZE)
	swap_w.font_size = 16
	_touch_layer.add_child(swap_w)
	_touch_buttons["weapon"] = swap_w
	swap_w.tapped.connect(func() -> void: adventure.cycle_weapon())


func _enable_touch_mode() -> void:
	if not touch_mode:
		touch_mode = true
		_relayout()


func _relayout() -> void:
	var win := get_window()
	var ws := Vector2(win.size)
	if ws.x <= 0 or ws.y <= 0:
		return
	# Mantém o lado menor da tela com tamanho lógico confortável para o dedo.
	var short_side := minf(ws.x, ws.y)
	var base_short := 520.0 if touch_mode or short_side < 520.0 else 720.0
	var k := base_short / short_side
	win.content_scale_size = Vector2i(int(round(ws.x * k)), int(round(ws.y * k)))
	var vs := Vector2(win.content_scale_size)
	var panel_w := minf(600.0, vs.x - 76.0)
	for l in _wrap_labels:
		l.custom_minimum_size.x = panel_w
	for pc in _panels:
		var sb := pc.get_theme_stylebox("panel") as StyleBoxFlat
		if sb != null:
			sb.set_content_margin_all(28.0 if vs.x > 700.0 else 16.0)
	_hint_label.add_theme_font_size_override("font_size", 14 if vs.x < 700.0 else 16)
	if _char_grid != null:
		# Seis colunas na tela larga; três (em duas linhas) em tablet e celular.
		var wide := vs.x >= 1000.0
		_char_grid.columns = 6 if wide else 3
		var narrow := vs.x < 600.0
		var btn_w: float = 140.0 if not narrow else floorf((panel_w - 2.0 * 8.0) / 3.0)
		var tall := vs.y < 760.0 and not wide
		_char_grid.add_theme_constant_override("h_separation", 14 if not narrow else 8)
		for prev in _char_previews:
			var hgt: float = float(Walker.HD_FRAME_H) if not (narrow or tall) else 80.0
			prev.custom_minimum_size = Vector2(Walker.HD_FRAME_W * hgt / Walker.HD_FRAME_H, hgt)
		for b: Button in _character_buttons.values():
			b.custom_minimum_size = Vector2(btn_w, 46 if not narrow else 42)
			b.add_theme_font_size_override("font_size", 22 if not narrow else 18)
	if adventure != null:
		adventure.relayout(vs, 0.0)
	_place_area_below_stats()
	if touch_mode:
		_layout_touch_buttons(vs)
		_settle_touch_minimap(vs)
	else:
		if _minimap != null:
			_minimap.apply_max_side(200.0)
			_minimap.position = vs - _minimap.size - Vector2(18.0, 18.0)
		_layout_touch_buttons(vs)
	if _tip_panel != null and _tip_panel.visible:
		_place_tip(vs)
	_update_hint()
	_refresh_touch_visibility()


func _layout_touch_buttons(vs: Vector2) -> void:
	if _touch_buttons.is_empty():
		return
	var m := 24.0
	if touch_mode:
		_layout_mobile_controls(vs, m)
	else:
		_layout_desktop_controls(vs, m)
	for b in _touch_buttons.values():
		(b as TouchButton).queue_redraw()
	_joystick.queue_redraw()


func _layout_desktop_controls(vs: Vector2, m: float) -> void:
	var ox := (_minimap.size.x + 16.0) if _minimap != null else 0.0
	var paths: TouchButton = _touch_buttons["paths"]
	var zin: TouchButton = _touch_buttons["zoom_in"]
	var zout: TouchButton = _touch_buttons["zoom_out"]
	var pause: TouchButton = _touch_buttons["pause"]
	paths.position = Vector2(vs.x - m - ox - paths.size.x, vs.y - m - paths.size.y)
	zin.position = Vector2(vs.x - m - ox - zin.size.x, paths.position.y - 16 - zin.size.y)
	zout.position = Vector2(zin.position.x - 14 - zout.size.x, zin.position.y)
	pause.position = Vector2(vs.x - m - pause.size.x, m)
	if _touch_buttons.has("shoot"):
		var shoot: TouchButton = _touch_buttons["shoot"]
		var mm_top := (_minimap.position.y if _minimap != null else vs.y) - 16.0
		shoot.position = Vector2(vs.x - m - shoot.size.x, mm_top - shoot.size.y)
		if _touch_buttons.has("weapon"):
			var sw: TouchButton = _touch_buttons["weapon"]
			sw.position = Vector2(shoot.position.x - 12 - sw.size.x, shoot.position.y + shoot.size.y - sw.size.y)


## Toque: Trocar Arma e Atirar ao lado do direcional.
func _layout_mobile_controls(vs: Vector2, m: float) -> void:
	var gap := 16.0
	var weapon: TouchButton = _touch_buttons["weapon"]
	var shoot: TouchButton = _touch_buttons["shoot"]
	var stick := Rect2(
		vs.x - TouchJoystick.EDGE - TouchJoystick.RADIUS * 2.0,
		vs.y - TouchJoystick.EDGE - TouchJoystick.RADIUS * 2.0,
		TouchJoystick.RADIUS * 2.0,
		TouchJoystick.RADIUS * 2.0)
	var y := stick.position.y + (stick.size.y - weapon.size.y) * 0.5
	var x := stick.position.x - gap - weapon.size.x - gap - shoot.size.x
	weapon.position = Vector2(x, y)
	shoot.position = Vector2(x + weapon.size.x + gap, y)
	var joy_top := minf(stick.position.y, weapon.position.y)
	var paths: TouchButton = _touch_buttons["paths"]
	var zin: TouchButton = _touch_buttons["zoom_in"]
	var zout: TouchButton = _touch_buttons["zoom_out"]
	var pause: TouchButton = _touch_buttons["pause"]
	paths.position = Vector2(vs.x - m - paths.size.x, joy_top - m - paths.size.y)
	zin.position = Vector2(vs.x - m - zin.size.x, paths.position.y - gap - zin.size.y)
	zout.position = Vector2(zin.position.x - 14.0 - zout.size.x, zin.position.y)
	pause.position = Vector2(vs.x - m - pause.size.x, m)


## Toque: minimapa embaixo à esquerda. Se os botões ao lado do direcional ocupam esse canto, ele sobe e encolhe até caber.
func _settle_touch_minimap(vs: Vector2) -> void:
	if _minimap == null:
		return
	_minimap.apply_max_side(200.0)
	_minimap.position = Vector2(18.0, vs.y - _minimap.size.y - 18.0)
	if not _minimap_hits_controls():
		return
	var top := 8.0
	if adventure != null and adventure._stats != null and adventure._stats.visible:
		top = adventure._stats.position.y + adventure._stats.size.y + 8.0
	if _hud != null and _hud.visible:
		top = maxf(top, _hud.get_combined_minimum_size().y + 8.0)
	var bottom := _action_row_top() - 8.0
	var room_h := maxf(110.0, bottom - top)
	var chrome_y := 34.0 + Minimap.LEGEND_H
	_minimap.apply_max_side(clampf(room_h - chrome_y, 72.0, 200.0))
	var y := bottom - _minimap.size.y
	if y < top:
		y = top
	_minimap.position = Vector2(18.0, y)
	var guard := 0
	while _minimap_hits_controls() and _minimap.max_side > 72.0 and guard < 10:
		_minimap.apply_max_side(_minimap.max_side - 14.0)
		y = bottom - _minimap.size.y
		if y < top:
			y = top
		_minimap.position = Vector2(18.0, y)
		guard += 1


func _action_row_top() -> float:
	var vs := Vector2(get_window().content_scale_size)
	var y := vs.y
	for key in ["weapon", "shoot"]:
		if _touch_buttons.has(key):
			y = minf(y, (_touch_buttons[key] as Control).position.y)
	return y


func _minimap_hits_controls() -> bool:
	if _minimap == null:
		return false
	var box := Rect2(_minimap.position, _minimap.size).grow(6.0)
	for key in ["weapon", "shoot", "paths", "zoom_in", "zoom_out", "pause"]:
		if not _touch_buttons.has(key):
			continue
		var b: Control = _touch_buttons[key]
		if box.intersects(Rect2(b.position, b.size)):
			return true
	var vs := Vector2(get_window().content_scale_size)
	var stick := Rect2(
		vs.x - TouchJoystick.EDGE - TouchJoystick.RADIUS * 2.0,
		vs.y - TouchJoystick.EDGE - TouchJoystick.RADIUS * 2.0,
		TouchJoystick.RADIUS * 2.0,
		TouchJoystick.RADIUS * 2.0)
	return box.intersects(stick)


func _place_area_below_stats() -> void:
	if _hud == null:
		return
	var top := 14
	if adventure != null and adventure._stats != null and adventure._stats.visible:
		top = int(ceil(adventure._stats.position.y + adventure._stats.size.y + 8.0))
	_hud.add_theme_constant_override("margin_top", top)
	if adventure != null and adventure._toast != null:
		adventure._toast.offset_top = maxf(120.0, _hud.get_combined_minimum_size().y + 12.0)


func _build_tip_panel() -> void:
	_tip_panel = Panel.new()
	var sb := _panel_style(10)
	sb.set_content_margin_all(12)
	sb.set_border_width_all(2)
	_tip_panel.add_theme_stylebox_override("panel", sb)
	_tip_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tip_panel.clip_contents = true
	_tip_panel.visible = false
	_tip_where = Label.new()
	_tip_where.add_theme_font_size_override("font_size", 16)
	_tip_where.add_theme_color_override("font_color", ACCENT)
	_tip_where.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tip_where.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tip_panel.add_child(_tip_where)
	_tip_body = Label.new()
	_tip_body.add_theme_font_size_override("font_size", 15)
	_tip_body.add_theme_color_override("font_color", Color("fff1c9"))
	_tip_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tip_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tip_panel.add_child(_tip_body)
	add_child(_tip_panel)


## Primeira dica pouco depois de o nível começar; as seguintes esperam mais.
func arm_play_tips() -> void:
	_tip_left = 0.0
	_tip_wait = randf_range(6.0, 10.0)
	_tip_last = -1
	if _tip_panel != null:
		_tip_panel.visible = false


func _tip_lines() -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray()
	if touch_mode:
		lines.append("Toque no chão para caminhar até lá. Toque num escorpião para atirar nele.")
	else:
		lines.append("Clique no chão para caminhar até lá. Clique num escorpião para atirar nele.")
	lines.append("Junte as moedas da fase. A vida, a arma e as moedas ficam no canto superior esquerdo.")
	lines.append("O Nerf dispara um dardo. Pegue outro lançador no mapa para recarregar.")
	lines.append("A Super Soaker molha e deixa o escorpião lento. Encha o tanque na piscina ou na fonte do Térreo.")
	var phase := 0 if adventure == null else adventure.phase
	if phase >= 1:
		lines.append("A Espalhadora solta cinco dardos em leque. Cada tiro gasta um cartucho.")
	if adventure != null and adventure.is_raining():
		lines.append("Poça de chuva deixa você 30% mais lento.")
		lines.append("Na chuva, o chão bege e o terracota escorregam. A grama não.")
		lines.append("Sob a marquise ou a torre coberta não chove: sem escorregar, alcance normal e +5% de vida.")
		lines.append("A capa de chuva dura 20 segundos: você não escorrega e leva metade do dano.")
		lines.append("Na chuva, o dardo do Nerf perde alcance fora do abrigo.")
	if phase >= 3:
		lines.append("Escorpiões saem dos ralos. Fique 2 segundos perto para tampar o bueiro.")
		lines.append("O relâmpago mostra os escorpiões. O raio cai no círculo — saia de cima dele.")
	return lines


func _show_tip() -> void:
	var lines := _tip_lines()
	if lines.is_empty() or _tip_panel == null:
		_tip_wait = 20.0
		return
	var pick := randi() % lines.size()
	if lines.size() > 1 and pick == _tip_last:
		pick = (pick + 1) % lines.size()
	_tip_last = pick
	_tip_where.text = area_hud_text(current_area)
	_tip_body.text = lines[pick]
	_tip_left = 3.0
	_tip_panel.visible = true
	_place_tip(Vector2(get_window().content_scale_size))


func _place_tip(vs: Vector2) -> void:
	if _tip_panel == null or _tip_body == null:
		return
	var w := minf(280.0, vs.x - 28.0)
	var h := 124.0
	if adventure != null and adventure._stats != null and adventure._stats.visible and _touch_buttons.has("pause"):
		var pause: Control = _touch_buttons["pause"]
		var gap := pause.position.x - (adventure._stats.position.x + adventure._stats.size.x) - 20.0
		if gap > 150.0:
			w = minf(w, gap)
	_tip_panel.size = Vector2(w, h)
	_tip_where.position = Vector2(12.0, 8.0)
	_tip_where.size = Vector2(w - 24.0, 24.0)
	_tip_body.position = Vector2(12.0, 34.0)
	_tip_body.size = Vector2(w - 24.0, h - 46.0)
	var spots: Array[Vector2] = []
	var stats_r := Rect2()
	if adventure != null and adventure._stats != null and adventure._stats.visible:
		stats_r = Rect2(adventure._stats.position, adventure._stats.size)
		spots.append(Vector2(stats_r.end.x + 10.0, stats_r.position.y))
		spots.append(Vector2(stats_r.end.x + 10.0, stats_r.end.y + 8.0))
	if _hud != null:
		spots.append(Vector2((vs.x - w) * 0.5, _hud.get_combined_minimum_size().y + 8.0))
	spots.append(Vector2(vs.x - w - 14.0, 14.0))
	spots.append(Vector2(14.0, vs.y * 0.38))
	for spot in spots:
		var p := Vector2(
			clampf(spot.x, 8.0, maxf(8.0, vs.x - w - 8.0)),
			clampf(spot.y, 8.0, maxf(8.0, vs.y - h - 8.0)))
		_tip_panel.position = p
		if not _tip_blocked():
			return
	_tip_panel.position = Vector2(clampf((vs.x - w) * 0.5, 8.0, maxf(8.0, vs.x - w - 8.0)), clampf(vs.y * 0.34, 8.0, maxf(8.0, vs.y - h - 8.0)))


func _tip_blocked() -> bool:
	var tip := Rect2(_tip_panel.position, _tip_panel.size)
	if adventure != null and adventure._stats != null and adventure._stats.visible:
		if tip.intersects(Rect2(adventure._stats.position, adventure._stats.size).grow(6.0)):
			return true
	if _minimap != null and _minimap.visible and tip.intersects(Rect2(_minimap.position, _minimap.size).grow(6.0)):
		return true
	if _hud != null and _hud.visible and tip.intersects(Rect2(_hud.position, _hud.get_combined_minimum_size()).grow(4.0)):
		return true
	for key in ["weapon", "shoot", "pause"]:
		if not _touch_buttons.has(key):
			continue
		var b: Control = _touch_buttons[key]
		if b.visible and tip.intersects(Rect2(b.position, b.size).grow(4.0)):
			return true
	return false


func _advance_tips(delta: float) -> void:
	if _tip_panel == null:
		return
	var overlay := adventure != null and adventure.overlay_open
	if not _playing or _paused or overlay:
		_tip_panel.visible = false
		return
	if _tip_left > 0.0:
		_tip_left = maxf(_tip_left - delta, 0.0)
		_tip_panel.visible = _tip_left > 0.0
		if _tip_left == 0.0:
			_tip_wait = randf_range(20.0, 40.0)
		return
	if _area_banner != null and _area_banner.visible and _area_banner.modulate.a > 0.25:
		return
	_tip_wait = maxf(_tip_wait - delta, 0.0)
	if _tip_wait == 0.0:
		_show_tip()


func _refresh_touch_visibility() -> void:
	if _touch_layer == null:
		return
	var overlay := adventure != null and adventure.overlay_open
	_touch_layer.visible = touch_mode and _playing and not _paused and not overlay
	if _minimap != null:
		_minimap.visible = _playing and not _paused and not overlay
	if adventure != null and adventure._stats != null:
		adventure._stats.visible = _playing and adventure.active
	if not _touch_layer.visible and _joystick != null:
		_joystick.release()


func _toggle_paths() -> void:
	_paths_overlay.visible = not _paths_overlay.visible
	_update_hint()


func _zoom_by(f: float) -> void:
	_target_zoom = clamp(_target_zoom * f, ZOOM_MIN, ZOOM_MAX)


func _open_pause() -> void:
	if not _playing or _paused:
		return
	_paused = true
	_pause_screen.visible = true
	for sid: String in _swap_buttons:
		(_swap_buttons[sid] as Button).disabled = sid == character
	_resume_button.grab_focus()
	_refresh_touch_visibility()


func _show_title() -> void:
	_playing = false
	_paused = false
	_title_screen.visible = true
	_pause_screen.visible = false
	_hud.visible = false
	_target_zoom = ZOOM_MIN
	_camera.zoom = Vector2.ONE * ZOOM_MIN
	_set_phase_picker(false)
	if _tip_panel != null:
		_tip_panel.visible = false
		_tip_left = 0.0
	_refresh_touch_visibility()
	_start_button.call_deferred("grab_focus")


## Recomeça o nível atual do zero (moedas, vida e itens), voltando ao ponto de partida.
func restart_phase() -> void:
	if adventure == null or not _playing:
		return
	_resume()
	clear_move()
	adventure.restart_phase()


func _start(char_id: String = "", phase_idx: int = 0) -> void:
	if char_id != "":
		select_character(char_id)
	_set_phase_picker(false)
	_playing = true
	_paused = false
	_title_screen.visible = false
	_pause_screen.visible = false
	_hud.visible = false
	_target_zoom = ZOOM_MIN
	_camera.zoom = Vector2.ONE * ZOOM_MIN
	adventure.new_game(phase_idx)
	_refresh_touch_visibility()


func select_character(char_id: String) -> void:
	for c: Dictionary in CHARACTERS:
		if String(c["id"]) == char_id:
			character = char_id
			_player.set_sheet(String(c["sheet"]))
			return


## Troca a personagem no meio do jogo, mantendo posição, vida, moedas e dardos.
func swap_character(char_id: String) -> void:
	var pos := _player.position
	select_character(char_id)
	_player.position = pos
	if adventure != null and adventure.active:
		adventure._show_toast("Agora você joga com %s" % _character_name(char_id), 1.6)
	_resume()


func _character_name(char_id: String) -> String:
	for c: Dictionary in CHARACTERS:
		if String(c["id"]) == char_id:
			return String(c["name"])
	return char_id


func open_map() -> void:
	if not _playing or _paused or _map_screen == null:
		return
	if adventure != null and adventure.overlay_open:
		return
	_paused = true
	clear_move()
	_map_screen.open()
	_refresh_touch_visibility()


func _on_map_closed() -> void:
	_paused = false
	_refresh_touch_visibility()


func _resume() -> void:
	_paused = false
	_pause_screen.visible = false
	_refresh_touch_visibility()


func _back_to_title() -> void:
	adventure.stop()
	load_area(START_AREA, START_SPAWN)
	distance_walked = 0.0
	_show_title()


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed:
		AudioDirector.unlock_audio()
	if event is InputEventScreenTouch and not touch_mode:
		_enable_touch_mode()


func _unhandled_input(event: InputEvent) -> void:
	if (event is InputEventMouseButton and event.pressed) or event.is_action_pressed("ui_accept") or event.is_action_pressed("shoot"):
		AudioDirector.unlock_audio()
	if _phase_picker_open() and (event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause")):
		_close_phase_picker()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("pause"):
		if _playing and not adventure.overlay_open:
			if _paused:
				_resume()
			else:
				_open_pause()
			get_viewport().set_input_as_handled()
		return
	if not _playing or _paused:
		if event.is_action_pressed("ui_accept") and _title_screen.visible:
			var focused := get_viewport().gui_get_focus_owner()
			if focused is Button:
				return
			if _phase_picker_open():
				if not _phase_buttons.is_empty():
					_phase_buttons[0].grab_focus()
				get_viewport().set_input_as_handled()
				return
			_start(character)
			get_viewport().set_input_as_handled()
		return
	if adventure.overlay_open:
		return
	if event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).keycode in [KEY_1, KEY_2, KEY_3, KEY_KP_1, KEY_KP_2, KEY_KP_3]:
		var kc := (event as InputEventKey).keycode
		var idx := 0 if kc in [KEY_1, KEY_KP_1] else (1 if kc in [KEY_2, KEY_KP_2] else 2)
		adventure.select_weapon(Adventure.WEAPONS[idx])
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).keycode == KEY_Q:
		adventure.cycle_weapon()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("shoot"):
		adventure.shoot()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("toggle_paths"):
		_toggle_paths()
	elif event.is_action_pressed("zoom_in"):
		_target_zoom = clamp(_target_zoom * 1.2, ZOOM_MIN, ZOOM_MAX)
	elif event.is_action_pressed("zoom_out"):
		_target_zoom = clamp(_target_zoom / 1.2, ZOOM_MIN, ZOOM_MAX)
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT and not _transitioning:
			click_screen(event.position)
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_RIGHT and not _transitioning:
			adventure.shoot(screen_to_world(event.position))
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_target_zoom = clamp(_target_zoom * 1.1, ZOOM_MIN, ZOOM_MAX)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_target_zoom = clamp(_target_zoom / 1.1, ZOOM_MIN, ZOOM_MAX)
	elif event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed and not _transitioning:
		click_screen(event.position)
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	_advance_tips(delta)
	if adventure != null:
		var rmb := not touch_mode and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
		var tb = _touch_buttons.get("shoot")
		var held: bool = _playing and not _paused and (Input.is_action_pressed("shoot") or rmb or (tb != null and (tb as TouchButton).is_held()))
		adventure.fire_held = held
		if rmb:
			adventure.aim_point = screen_to_world(get_viewport().get_mouse_position())
		elif not (adventure.weapon == "soaker" and adventure._burst > 0.0 and adventure.aim_point != Vector2.INF):
			adventure.aim_point = Vector2.INF
	var z := lerpf(_camera.zoom.x, _target_zoom, clamp(delta * 8.0, 0.0, 1.0))
	_camera.zoom = Vector2(z, z)
	if not _playing or _paused:
		_player.set_weather_move(1.0, 0.0)
		_player.step(Vector2.ZERO, false, delta)
		return
	var dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var running := Input.is_action_pressed("run")
	if _joystick != null and _joystick.is_held():
		dir = _joystick.vector
		running = _joystick.running
	if _transitioning or adventure.overlay_open:
		_player.set_weather_move(1.0, 0.0)
		_player.step(Vector2.ZERO, false, delta)
		return
	if adventure != null and adventure.active:
		adventure.apply_move_modifiers()
	else:
		_player.set_weather_move(1.0, 0.0)
	if dir.length() > 0.2:
		clear_move()
	elif not move_path.is_empty():
		dir = _follow_dir()
	var moved := _player.step(dir, running, delta)
	if not move_path.is_empty():
		_stuck_t = _stuck_t + delta if moved.length() < 0.15 else 0.0
		if _stuck_t > 0.5:
			clear_move()
	if _minimap != null:
		_minimap.player_pos = _player.position
	distance_walked += moved.length()
	adventure.tick(delta)
	if adventure.overlay_open:
		return
	var e := exit_at(_player.position)
	if not e.is_empty():
		_go_through(e)


## Converte uma posição da tela para o mapa da tela atual.
func screen_to_world(screen_pos: Vector2) -> Vector2:
	return _sub_viewport.get_canvas_transform().affine_inverse() * screen_pos


func world_to_screen(world_pos: Vector2) -> Vector2:
	return _sub_viewport.get_canvas_transform() * world_pos


## Escorpião sob o clique ou toque. O raio acompanha o sprite (24×26).
func scorpion_at_screen(screen_pos: Vector2) -> Scorpion:
	if adventure == null or not adventure.active:
		return null
	var world := screen_to_world(screen_pos)
	var best: Scorpion = null
	var best_d := 22.0
	for s: Scorpion in adventure._scorp_nodes:
		if not is_instance_valid(s):
			continue
		var d := world.distance_to(s.position + Vector2(0, -6))
		if d <= best_d:
			best = s
			best_d = d
	return best


## Clique ou toque: no chão caminha; num escorpião atira nele. O mapa só abre pelo minimapa.
func click_screen(screen_pos: Vector2) -> void:
	if not _playing or _paused or _transitioning:
		return
	if adventure != null and adventure.overlay_open:
		return
	var sc := scorpion_at_screen(screen_pos)
	if sc != null:
		clear_move()
		adventure.shoot(sc.position + Vector2(0, -4))
		return
	go_to(screen_to_world(screen_pos))


## Anda até o ponto (clique, toque ou minimapa) por um caminho que contorna obstáculos.
func go_to(world_pos: Vector2) -> bool:
	ensure_finder()
	# Clique numa saída: mira o ponto caminhável dentro dela mais próximo do clique.
	var ex := exit_at(world_pos)
	if not ex.is_empty() and not walk_map.is_footprint_walkable(world_pos, Walker.FOOT_HALF):
		var r: Array = ex["rect"]
		var best := Vector2.INF
		for yy in range(int(r[1]), int(r[1]) + int(r[3]) + 1, 3):
			for xx in range(int(r[0]), int(r[0]) + int(r[2]) + 1, 3):
				var q := Vector2(xx, yy)
				if walk_map.is_footprint_walkable(q, Walker.FOOT_HALF) and (best == Vector2.INF or q.distance_to(world_pos) < best.distance_to(world_pos)):
					best = q
		if best != Vector2.INF:
			world_pos = best
	var path := _finder.find(_player.position, world_pos)
	if path.size() < 2:
		clear_move()
		return false
	# Termina no ponto clicado (se for chão caminhável ou uma saída), não só no centro da célula.
	if walk_map.is_footprint_walkable(world_pos, Walker.FOOT_HALF):
		path.append(world_pos)
	move_path = path
	_path_i = 1
	_stuck_t = 0.0
	_marker.position = path[path.size() - 1]
	_marker.visible = true
	if _minimap != null:
		_minimap.target_pos = _marker.position
	return true


func clear_move() -> void:
	move_path = PackedVector2Array()
	_path_i = 0
	if _marker != null:
		_marker.visible = false
	if _minimap != null:
		_minimap.target_pos = Vector2.INF


func _follow_dir() -> Vector2:
	while _path_i < move_path.size() and _player.position.distance_to(move_path[_path_i]) < 3.0:
		_path_i += 1
	if _path_i >= move_path.size():
		clear_move()
		return Vector2.ZERO
	return (move_path[_path_i] - _player.position).normalized()


## Usado pelos testes: segue a rota do clique por alguns segundos, como no jogo.
func simulate_click_walk(world_pos: Vector2, seconds: float) -> bool:
	if not go_to(world_pos):
		return false
	var t := 0.0
	var start_area := current_area
	while t < seconds and not move_path.is_empty() and current_area == start_area:
		_player.step(_follow_dir(), false, 1.0 / 60.0)
		var e := exit_at(_player.position)
		if not e.is_empty():
			_go_through(e, false)
		t += 1.0 / 60.0
	return true


## Usado pelos testes automatizados.
func simulate_walk(direction: Vector2, seconds: float, running: bool = false) -> Vector2:
	var start := _player.position
	var t := 0.0
	while t < seconds:
		_player.step(direction, running, 1.0 / 60.0)
		var e := exit_at(_player.position)
		if not e.is_empty():
			_go_through(e, false)
		t += 1.0 / 60.0
	return _player.position - start
