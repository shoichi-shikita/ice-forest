extends SceneTree
var game: Node3D
func _initialize() -> void:
    call_deferred("run")
func frames() -> void:
    await process_frame
    await process_frame
func run() -> void:
    game = load("res://main.tscn").instantiate()
    root.add_child(game)
    await create_timer(0.2).timeout
    game.player.set_physics_process(false)
    var marker: Node3D = game.markers[0]
    var initial: Transform3D = marker.global_transform
    game.player.position = Vector3(-0.85,0,-6.3)
    game.player.pitch = -1.1
    game.player.flash.visible = false
    game._inspect(marker)
    assert(not game.player.inspection_active and game.studied.is_empty())
    game.player.flash.visible = true
    await frames()
    game._inspect(marker)
    assert(game.player.inspection_active and game.studied.size() == 1)
    await create_timer(0.65).timeout
    assert(is_equal_approx(game.player.inspection_blend,1.0))
    assert(is_equal_approx(game.player.camera.fov,40.0))
    assert(marker.global_transform.is_equal_approx(initial))
    assert(not game.story_label.text.contains("ポチ"))
    if DisplayServer.get_name() != "headless":
        root.get_texture().get_image().save_png("res://../inspection_close.png")
    game.player.flash.visible = false
    game.prompt_label.get_parent().hide()
    await create_timer(0.2).timeout
    if DisplayServer.get_name() != "headless":
        root.get_texture().get_image().save_png("res://../inspection_unlit.png")
    game.prompt_label.get_parent().show()
    game.player.flash.visible = true
    var event := InputEventKey.new()
    event.keycode = KEY_ESCAPE
    event.pressed = true
    game.player._unhandled_input(event)
    await create_timer(0.5).timeout
    assert(not game.player.inspection_active)
    assert(is_equal_approx(game.player.camera.fov,72.0))
    game._inspect(marker)
    assert(game.studied.size() == 1)
    game.player.end_inspection(true)
    game.player.position.z = -30
    await frames()
    game.player.position.z = 6
    await frames()
    assert(not game.game_finished and not game.finish_ready)
    game.player.position.z = -49
    await frames()
    assert(game.event_state == 1)
    game.player.position.z = 6
    await frames()
    assert(game.game_finished)
    assert(not game.player.inspection_active)
    print("PASS: lit physical inspection, no popup, stationary object, Esc exit/reinspect, shallow-return excluded, deep-return ending")
    game.queue_free()
    await frames()
    game = load("res://main.tscn").instantiate()
    root.add_child(game)
    await frames()
    game.player.set_physics_process(false)
    assert(game.studied.is_empty() and not game.game_finished)
    assert(game.get_node("ForestryDetails").get_child_count() == 7)
    game.player.position.z = -49
    await frames()
    game.player.position.z = 6
    await frames()
    assert(game.game_finished and game.studied.is_empty())
    print("PASS: clear with zero sticks; scene reset; 4 stakes + 2 ruts + pipe present")
    game.queue_free()
    await frames()
    quit()
