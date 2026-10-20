class_name TouchButton
extends Control
## Botão de toque que funciona com vários dedos ao mesmo tempo
## (o joystick pode estar pressionado enquanto o botão é tocado).

signal tapped

var text := ""
var font_size := 22
var _finger := -1


func _init(label: String = "", size_px: Vector2 = Vector2(76, 76)) -> void:
	text = label
	custom_minimum_size = size_px
	size = size_px
	mouse_filter = Control.MOUSE_FILTER_STOP


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		if t.pressed and _finger == -1 and get_global_rect().has_point(t.position):
			_finger = t.index
			queue_redraw()
			get_viewport().set_input_as_handled()
		elif not t.pressed and t.index == _finger:
			_finger = -1
			queue_redraw()
			if get_global_rect().grow(24).has_point(t.position):
				tapped.emit()
			get_viewport().set_input_as_handled()


## Verdadeiro enquanto um dedo segura o botão (Super Soaker atira enquanto segura).
func is_held() -> bool:
	return _finger != -1


## Mouse (desktop) também funciona, útil para testes.
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		if not DisplayServer.is_touchscreen_available():
			tapped.emit()
			accept_event()


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	var pressed := _finger != -1
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.29, 0.38, 0.26, 0.92) if pressed else Color(0.07, 0.09, 0.08, 0.72)
	bg.border_color = Color("e9a15b")
	bg.set_border_width_all(3)
	bg.set_corner_radius_all(int(min(size.x, size.y) / 2.0))
	draw_style_box(bg, r)
	var font := get_theme_default_font()
	if font == null:
		return
	var ts := font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
	var pos := Vector2((size.x - ts.x) / 2.0, (size.y + font.get_ascent(font_size) - font.get_descent(font_size)) / 2.0)
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color("fff1c9"))
