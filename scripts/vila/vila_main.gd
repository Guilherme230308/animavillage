extends Control
## Vila Vista: caminhada livre pelo condomínio em pixel art.

const SCENE_PATH := "res://assets/game/scene.png"
const SPAWN_HINT := Vector2(630, 790)
const ZOOM_MIN := 1.25
const ZOOM_MAX := 4.0
const ZOOM_DEFAULT := 2.25
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
var _target_zoom := ZOOM_DEFAULT
var distance_walked := 0.0
var touch_mode := false
var _joystick: TouchJoystick
var _touch_layer: Control
var _touch_buttons: Dictionary = {}
var _wrap_labels: Array[Label] = []
var _panels: Array[PanelContainer] = []
var _controls_label: Label


func _ready() -> void:
	_ensure_actions()
	walk_map.load_mask()
	_build_world()
	touch_mode = DisplayServer.is_touchscreen_available()
	_build_ui()
	_build_touch_ui()
	get_tree().root.size_changed.connect(_relayout)
	_relayout()
	_show_title()


func _ensure_actions() -> void:
	var extra := {"run": [KEY_SHIFT], "toggle_paths": [KEY_M], "zoom_in": [KEY_EQUAL, KEY_KP_ADD], "zoom_out": [KEY_MINUS, KEY_KP_SUBTRACT]}
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

	var scene_sprite := Sprite2D.new()
	scene_sprite.texture = load(SCENE_PATH)
	scene_sprite.centered = false
	scene_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_world.add_child(scene_sprite)

	_paths_overlay = Sprite2D.new()
	_paths_overlay.texture = _build_paths_texture()
	_paths_overlay.centered = false
	_paths_overlay.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_paths_overlay.scale = Vector2(WalkMap.CELL, WalkMap.CELL)
	_paths_overlay.visible = false
	_world.add_child(_paths_overlay)

	_player = Walker.new()
	_player.walk_map = walk_map
	_player.position = walk_map.nearest_walkable(SPAWN_HINT, Walker.FOOT_HALF)
	_world.add_child(_player)

	_camera = Camera2D.new()
	_camera.zoom = Vector2.ONE * ZOOM_DEFAULT
	_camera.position_smoothing_enabled = true
	_camera.position_smoothing_speed = 7.0
	var size := (scene_sprite.texture as Texture2D).get_size()
	_camera.limit_left = 0
	_camera.limit_top = 0
	_camera.limit_right = int(size.x)
	_camera.limit_bottom = int(size.y)
	_player.add_child(_camera)
	_camera.make_current()


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
	hud_panel.add_child(_hint_label)
	_update_hint()

	# Título
	var t := _centered_panel()
	_title_screen = t[0]
	var tbox: VBoxContainer = t[1]
	tbox.add_child(_label("VILA VISTA", 56, ACCENT))
	tbox.add_child(_label("Passeie pelo condomínio em pixel art.", 20))
	tbox.add_child(_label("Os caminhos seguem os passeios reais da imagem:\nprédios, piscinas, jardins e muros bloqueiam a passagem.", 16, Color("cfd8c4")))
	_controls_label = _label("", 15, Color("cfd8c4"))
	tbox.add_child(_controls_label)
	_start_button = _make_button("Começar a caminhar")
	_start_button.pressed.connect(_start)
	tbox.add_child(_start_button)

	# Pausa
	var p := _centered_panel()
	_pause_screen = p[0]
	var pbox: VBoxContainer = p[1]
	pbox.add_child(_label("Pausado", 40, ACCENT))
	_resume_button = _make_button("Continuar")
	_resume_button.pressed.connect(_resume)
	pbox.add_child(_resume_button)
	var restart := _make_button("Voltar ao início")
	restart.pressed.connect(_back_to_title)
	pbox.add_child(restart)


func _update_hint() -> void:
	var on := _paths_overlay != null and _paths_overlay.visible
	var paths := "ligado" if on else "desligado"
	if touch_mode:
		_hint_label.text = "Arraste à esquerda para andar · até a borda para correr"
	else:
		_hint_label.text = "Setas/WASD andar · Shift correr · M caminhos (%s) · Esc pausar" % paths
	if _touch_buttons.has("paths"):
		var b: TouchButton = _touch_buttons["paths"]
		b.text = "Ocultar" if on else "Caminhos"
		b.queue_redraw()
	if _controls_label != null:
		if touch_mode:
			_controls_label.text = "No celular: toque e arraste na metade esquerda da tela para andar; empurre até a borda para correr. Use os botões à direita para mostrar os caminhos, aproximar ou afastar, e pausar."
		else:
			_controls_label.text = "Setas ou WASD: andar  ·  Shift: correr  ·  M: mostrar caminhos\nRoda do mouse ou +/−: zoom  ·  Esc: pausar  ·  No celular, use os controles de toque."


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
	_layout_touch_buttons(vs)
	_update_hint()
	_refresh_touch_visibility()


func _layout_touch_buttons(vs: Vector2) -> void:
	if _touch_buttons.is_empty():
		return
	var m := 24.0
	var paths: TouchButton = _touch_buttons["paths"]
	var zin: TouchButton = _touch_buttons["zoom_in"]
	var zout: TouchButton = _touch_buttons["zoom_out"]
	var pause: TouchButton = _touch_buttons["pause"]
	paths.position = Vector2(vs.x - m - paths.size.x, vs.y - m - paths.size.y)
	zin.position = Vector2(vs.x - m - zin.size.x, paths.position.y - 16 - zin.size.y)
	zout.position = Vector2(zin.position.x - 14 - zout.size.x, zin.position.y)
	pause.position = Vector2(vs.x - m - pause.size.x, m)
	for b in _touch_buttons.values():
		(b as TouchButton).queue_redraw()
	_joystick.queue_redraw()


func _refresh_touch_visibility() -> void:
	if _touch_layer == null:
		return
	_touch_layer.visible = touch_mode and _playing and not _paused
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
	_resume_button.grab_focus()
	_refresh_touch_visibility()


func _show_title() -> void:
	_playing = false
	_paused = false
	_title_screen.visible = true
	_pause_screen.visible = false
	_hud.visible = false
	_target_zoom = 1.6
	_refresh_touch_visibility()
	_start_button.call_deferred("grab_focus")


func _start() -> void:
	_playing = true
	_paused = false
	_title_screen.visible = false
	_pause_screen.visible = false
	_hud.visible = true
	_target_zoom = ZOOM_DEFAULT
	_refresh_touch_visibility()


func _resume() -> void:
	_paused = false
	_pause_screen.visible = false
	_refresh_touch_visibility()


func _back_to_title() -> void:
	_player.position = walk_map.nearest_walkable(SPAWN_HINT, Walker.FOOT_HALF)
	_camera.reset_smoothing()
	distance_walked = 0.0
	_show_title()


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and not touch_mode:
		_enable_touch_mode()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		if _playing:
			if _paused:
				_resume()
			else:
				_open_pause()
			get_viewport().set_input_as_handled()
		return
	if not _playing or _paused:
		if event.is_action_pressed("ui_accept") and _title_screen.visible:
			_start()
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("toggle_paths"):
		_toggle_paths()
	elif event.is_action_pressed("zoom_in"):
		_target_zoom = clamp(_target_zoom * 1.2, ZOOM_MIN, ZOOM_MAX)
	elif event.is_action_pressed("zoom_out"):
		_target_zoom = clamp(_target_zoom / 1.2, ZOOM_MIN, ZOOM_MAX)
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_target_zoom = clamp(_target_zoom * 1.1, ZOOM_MIN, ZOOM_MAX)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_target_zoom = clamp(_target_zoom / 1.1, ZOOM_MIN, ZOOM_MAX)


func _process(delta: float) -> void:
	var z := lerpf(_camera.zoom.x, _target_zoom, clamp(delta * 8.0, 0.0, 1.0))
	_camera.zoom = Vector2(z, z)
	if not _playing or _paused:
		_player.step(Vector2.ZERO, false, delta)
		return
	var dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var running := Input.is_action_pressed("run")
	if _joystick != null and _joystick.is_held():
		dir = _joystick.vector
		running = _joystick.running
	var moved := _player.step(dir, running, delta)
	distance_walked += moved.length()


## Usado pelos testes automatizados.
func simulate_walk(direction: Vector2, seconds: float, running: bool = false) -> Vector2:
	var start := _player.position
	var t := 0.0
	while t < seconds:
		_player.step(direction, running, 1.0 / 60.0)
		t += 1.0 / 60.0
	return _player.position - start
