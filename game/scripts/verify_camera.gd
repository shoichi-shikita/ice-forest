extends SceneTree
func _initialize() -> void:
    call_deferred("run")
func run() -> void:
    var game = load("res://main.tscn").instantiate()
    root.add_child(game)
    await create_timer(0.2).timeout
    var player = game.player
    player.set_physics_process(false)
    player.set_process(false)
    var walk_extent := 0.0
    var run_extent := 0.0
    var footsteps := 0
    for i in range(180):
        if player._update_camera_motion(1.0/60.0,0.05,true,false): footsteps += 1
        player._process(1.0/60.0)
        walk_extent = maxf(walk_extent,absf(player.camera_offset_target.y))
    assert(footsteps == 5)
    for i in range(180):
        player._update_camera_motion(1.0/60.0,0.08,true,true)
        player._process(1.0/60.0)
        run_extent = maxf(run_extent,absf(player.camera_offset_target.y))
    assert(run_extent > walk_extent * 1.4)
    for i in range(300):
        assert(not player._update_camera_motion(1.0/60.0,0.0,true,false))
        player._process(1.0/60.0)
    assert(player.bob_weight == 0.0)
    assert(player.camera.position.distance_to(Vector3(0,1.6,0)) < 0.006)
    player.motion_strength = 0.0
    player.pitch = 0.3
    for i in range(180):
        player._update_camera_motion(1.0/60.0,0.0,true,false)
        player._process(1.0/60.0)
    assert(player.camera.position.distance_to(Vector3(0,1.6,0)) < 0.0001)
    assert(is_equal_approx(player.camera.rotation.x,0.3))
    assert(absf(player.camera.rotation.z) < 0.0001)
    print("PASS: distance-synced steps=",footsteps," walk_y=",walk_extent," run_y=",run_extent,"; stopped/wall idle, no accumulated drift, motion off preserves aim")
    game.queue_free()
    await process_frame
    await process_frame
    quit()
