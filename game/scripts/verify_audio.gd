extends SceneTree
func _initialize() -> void:
    call_deferred("run")
func run() -> void:
    var game = load("res://main.tscn").instantiate()
    root.add_child(game)
    await process_frame
    var player = game.player
    player.set_physics_process(false)
    player.position.z = -20.0
    for i in range(2000): player._maybe_queue_ghost_step()
    assert(player.ghost_timer.is_stopped())
    player.position.z = -30.0
    player.step_rng.seed = 314159
    var hits := 0
    for i in range(1000):
        player._maybe_queue_ghost_step()
        if not player.ghost_timer.is_stopped():
            hits += 1
            player.ghost_timer.stop()
    assert(hits >= 75 and hits <= 145)
    print("PASS: shallow area excluded; fixed-seed 1000 eligible footsteps, ghost reservations=", hits)
    player._queue_ghost_step()
    var source_pos: Vector3 = player.ghost_step.global_position
    assert(source_pos.z > player.global_position.z)
    assert(is_equal_approx(player.ghost_timer.wait_time,0.25))
    player.position.x += 2.0
    player._queue_ghost_step()
    assert(player.ghost_step.global_position.is_equal_approx(source_pos))
    await create_timer(0.12).timeout
    assert(not player.ghost_step.playing)
    await create_timer(0.16).timeout
    assert(player.ghost_step.playing)
    assert(player.ghost_step.volume_db < player.foot.volume_db)
    assert(player.ghost_step.pitch_scale >= 0.78 and player.ghost_step.pitch_scale <= 0.86)
    await create_timer(0.6).timeout
    assert(not player.ghost_step.playing and player.ghost_timer.is_stopped())
    print("PASS: stopped player retains one delayed step, fixed rear source, quieter/lower pitch; no repetition")
    player._queue_ghost_step()
    player.stop_footstep_audio()
    await create_timer(0.3).timeout
    assert(not player.ghost_step.playing and player.ghost_timer.is_stopped())
    var before_wind: float = game.ambience.volume_linear
    var before_water: float = game.creek.volume_linear
    player.position.z = -44
    await create_timer(0.2).timeout
    assert(game.event_state == 1)
    assert(game.ambience.volume_linear < before_wind and game.ambience.volume_linear > 0)
    assert(game.creek.volume_linear < before_water and game.creek.volume_linear > 0)
    await create_timer(0.7).timeout
    assert(not game.ambience.playing and not game.creek.playing)
    print("PASS: both ambience sources fade then stop; ending cancels pending ghost")
    game.queue_free()
    await process_frame
    game = load("res://main.tscn").instantiate()
    root.add_child(game)
    await process_frame
    await create_timer(0.15).timeout
    print("RELOAD wind=",game.ambience.playing," water=",game.creek.playing," z=",game.player.position.z," event=",game.event_state," wind_len=",game.ambience.stream.get_length()," loop_end=",game.ambience.stream.loop_end)
    assert(game.ambience.playing and game.creek.playing)
    assert(game.player.ghost_timer.is_stopped() and not game.player.audio_ended)
    print("PASS: scene reload restores ambience and ghost state")
    game.queue_free()
    await process_frame
    quit()


