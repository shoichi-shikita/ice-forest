extends SceneTree
func _initialize() -> void:
    call_deferred("run")
func run() -> void:
    var game = load("res://main.tscn").instantiate()
    root.add_child(game)
    await create_timer(0.5).timeout
    game.player.set_physics_process(false)
    game.player.position = Vector3(0,0,-12)
    game.player.pitch = -0.16
    game.prompt_label.get_parent().hide()
    var env: Environment = game.get_node("WorldEnvironment").environment
    assert(is_equal_approx(env.ambient_light_energy,0.02))
    assert(not game.player.camera.attributes.auto_exposure_enabled)
    assert(game.find_child("NightPost",true,false) != null)
    if RenderingServer.get_current_rendering_method() == "forward_plus":
        assert(env.volumetric_fog_enabled)
    var suffix := RenderingServer.get_current_rendering_method()
    await create_timer(1.5).timeout
    root.get_texture().get_image().save_png("res://../night_on_"+suffix+".png")
    game.player.flash.visible = false
    await create_timer(0.5).timeout
    root.get_texture().get_image().save_png("res://../night_off_"+suffix+".png")
    game.player.flash.visible = true
    game.prompt_label.get_parent().show()
    await create_timer(0.2).timeout
    root.get_texture().get_image().save_png("res://../night_play_"+suffix+".png")
    print("PASS: night renderer=",suffix," auto exposure off; capture on/off")
    game.queue_free()
    await process_frame
    await process_frame
    quit()
