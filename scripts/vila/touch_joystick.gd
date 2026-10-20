class_name TouchJoystick
extends Control
## Joystick virtual flutuante: toque na metade direita da tela e arraste.
## Empurrar até a borda ativa a corrida.

signal touched

const RADIUS := 70.0
const KNOB_RADIUS := 30.0
const DEAD_ZONE := 0.15
const RUN_THRESHOLD := 0.85
## Folga entre a borda da tela e o círculo em repouso.
const EDGE := 50.0

var active := true
var vector := Vector2.ZERO
var running := false
var _finger := -1
var _origin := Vector2.ZERO
var _knob := Vector2.ZERO
var _rest := Vector2.ZERO


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _rest_position() -> Vector2:
	var s := get_viewport_rect().size
	return Vector2(s.x - RADIUS - EDGE, s.y - RADIUS - EDGE)


func _input(event: InputEvent) -> void:
	if not active or not visible:
		return
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		if t.pressed and _finger == -1 and _accepts(t.position):
			_finger = t.index
			_origin = t.position
			_update_knob(t.position)
			touched.emit()
			get_viewport().set_input_as_handled()
		elif not t.pressed and t.index == _finger:
			release()
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		var d := event as InputEventScreenDrag
		if d.index == _finger:
			_update_knob(d.position)
			get_viewport().set_input_as_handled()


func _accepts(pos: Vector2) -> bool:
	var s := get_viewport_rect().size
	# Metade direita, abaixo do HUD superior, fora dos outros botões.
	if pos.x < s.x * 0.5 or pos.y <= 90.0:
		return false
	if _over_sibling(pos):
		return false
	# Toque num escorpião atira, em vez de puxar o direcional.
	var n: Node = get_parent()
	while n != null:
		if n.has_method("scorpion_at_screen"):
			return n.scorpion_at_screen(pos) == null
		n = n.get_parent()
	return true


func _over_sibling(pos: Vector2) -> bool:
	var parent := get_parent()
	if parent == null:
		return false
	for c in parent.get_children():
		if c == self or not (c is Control):
			continue
		var control := c as Control
		if control.visible and control.get_global_rect().has_point(pos):
			return true
	return false


func _update_knob(pos: Vector2) -> void:
	var offset := pos - _origin
	if offset.length() > RADIUS:
		# O joystick acompanha o dedo quando ele passa da borda.
		_origin = pos - offset.normalized() * RADIUS
		offset = pos - _origin
	_knob = offset
	var strength := offset.length() / RADIUS
	if strength < DEAD_ZONE:
		vector = Vector2.ZERO
		running = false
	else:
		vector = offset / RADIUS
		running = strength >= RUN_THRESHOLD
	queue_redraw()


func release() -> void:
	_finger = -1
	vector = Vector2.ZERO
	running = false
	_knob = Vector2.ZERO
	queue_redraw()


func is_held() -> bool:
	return _finger != -1


func _draw() -> void:
	var center := _origin if _finger != -1 else _rest_position()
	var alpha := 0.9 if _finger != -1 else 0.45
	draw_circle(center, RADIUS, Color(0.07, 0.09, 0.08, 0.45 * alpha))
	draw_arc(center, RADIUS, 0, TAU, 48, Color(0.91, 0.63, 0.36, alpha), 3.0, true)
	draw_arc(center, RADIUS * RUN_THRESHOLD, 0, TAU, 48, Color(1, 0.95, 0.79, 0.25 * alpha), 1.5, true)
	var knob_color := Color("e9a15b") if running else Color("fff1c9")
	knob_color.a = alpha
	draw_circle(center + _knob, KNOB_RADIUS, knob_color)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()
