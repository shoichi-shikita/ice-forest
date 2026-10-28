extends SceneTree

var failures := 0
var checks := 0

func _init() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func run() -> void:
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	check(scene.menu.visible and not scene.playing, "Initial title menu")
	scene._start()
	await physics_frame
	var start_position: Vector3 = scene.player.position
	Input.action_press("forward")
	for frame in range(30):
		await physics_frame
	Input.action_release("forward")
	check(scene.player.position.z < start_position.z - 0.4, "Forward input moves first-person character")
	scene._pause(true)
	var stopped: Vector3 = scene.player.position
	var time_before: float = scene.elapsed
	Input.action_press("forward")
	for frame in range(10):
		await physics_frame
	Input.action_release("forward")
	check(scene.player.position.is_equal_approx(stopped), "Pause freezes movement")
	check(is_equal_approx(scene.elapsed, time_before), "Pause freezes chase timer")
	scene._pause(false)
	var event := InputEventAction.new()
	event.action = "interact"
	event.pressed = true
	scene.player.position = scene.gate
	scene._unhandled_input(event)
	check(not scene.state.escaped, "Gate rejects missing collectibles")
	for sigil in scene.sigils:
		scene.player.position = sigil.position
		scene._unhandled_input(event)
	check(scene.state.collected.size() == 3, "Interaction collects all three distinct sigils")
	scene.player.position = scene.gate
	scene._unhandled_input(event)
	check(scene.state.escaped and not scene.playing and scene.menu.visible, "Collectibles allow escape ending")
	scene._start()
	check(scene.state.collected.is_empty() and not scene.state.is_finished(), "Restart resets progress")
	check(scene.danger.text.is_empty() and scene.player.stamina == 100.0, "Restart clears old danger and exhaustion")
	for sigil in scene.sigils:
		check(sigil.visible, "Restart restores a collectible")
	scene.state.collect_sigil("activate")
	scene.shade.position = Vector3(scene.player.position.x, 0, scene.player.position.z)
	scene._process(0.01)
	check(scene.state.caught and not scene.playing and scene.menu.visible, "Nearby pursuing shade triggers caught ending")
	scene.queue_free()
	await process_frame
	print("Scene integration: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
