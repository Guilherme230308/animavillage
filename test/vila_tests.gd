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
	_check(map.walkable_count() > 3000, "rede de passeios extensa")
	var player: Walker = main.get("_player")
	_check(map.is_footprint_walkable(player.position, Walker.FOOT_HALF), "nasce em passeio")
	_check(bool((main.get("_title_screen") as Control).visible), "abre na tela de título")
	main.call("_start")

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

	# Pontos sabidamente bloqueados: piscina e telhado de uma torre.
	_check(not map.is_point_walkable(Vector2(700, 620)), "piscina bloqueada")
	_check(not map.is_point_walkable(Vector2(840, 180)), "torre bloqueada")
	_check(not map.is_point_walkable(Vector2(30, 600)), "mata externa bloqueada")

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

	main.queue_free()
	await process_frame
	if _failures.is_empty():
		print("[vila-tests] PASS: caminhada e colisões")
		quit(0)
	else:
		print("[vila-tests] FAILED: %d" % _failures.size())
		quit(1)
