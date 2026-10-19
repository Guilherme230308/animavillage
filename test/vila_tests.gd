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

	main.queue_free()
	await process_frame
	if _failures.is_empty():
		print("[vila-tests] PASS: caminhada e colisões")
		quit(0)
	else:
		print("[vila-tests] FAILED: %d" % _failures.size())
		quit(1)
