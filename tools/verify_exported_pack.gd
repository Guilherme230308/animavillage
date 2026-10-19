extends SceneTree

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_verify")


func _check(ok: bool, label: String) -> void:
	if not ok:
		_failures.append(label)
		printerr("[exported-pack] FAIL: " + label)


func _verify() -> void:
	_check(ProjectSettings.get_setting("application/config/name") == "Vila Vista", "exported identity")
	for path: String in ["res://assets/game/scene.png", "res://assets/game/walk_mask.png", "res://assets/game/hero.png", "res://assets/game/towers.json", "res://assets/game/tower_01.png"]:
		_check(ResourceLoader.exists(path), "pack resource: " + path)
	_check(not ResourceLoader.exists("res://test/vila_tests.gd"), "tests excluded")
	_check(not ResourceLoader.exists("res://tools/capture_native.gd"), "native capture tool excluded")
	var packed := load("res://scenes/main.tscn") as PackedScene
	_check(packed != null, "exported main scene")
	if packed != null:
		var main := packed.instantiate()
		root.add_child(main)
		await process_frame
		await process_frame
		_check(bool((main.get("_title_screen") as Control).visible), "pack boots to title")
		var map: WalkMap = main.walk_map
		_check(map.walkable_count() > 25000, "pack walk mask loaded")
		main.call("_start")
		var moved: Vector2 = main.call("simulate_walk", Vector2.RIGHT, 1.0, false)
		moved += main.call("simulate_walk", Vector2.DOWN, 1.0, false)
		_check(moved.length() > 5.0, "pack player walks")
		main.queue_free()
		await process_frame
	if _failures.is_empty():
		print("[exported-pack] PASS: Vila Vista")
		quit(0)
	else:
		print("[exported-pack] FAILED: %d" % _failures.size())
		quit(1)
