extends SceneTree
func _initialize() -> void:
    call_deferred("run")
func run() -> void:
    var game = load("res://main.tscn").instantiate()
    root.add_child(game)
    await create_timer(0.3).timeout
    game.player.set_physics_process(false)
    game.player.set_process(false)
    game.prompt_label.get_parent().hide()
    game.player.position = Vector3(-3.2,0,-6.2)
    game.player.camera.position = Vector3(0,1.1,0)
    game.player.camera.look_at(Vector3(-4.4,0.19,-8),Vector3.UP)
    await create_timer(0.3).timeout
    root.get_texture().get_image().save_png("res://../boundary_stake.png")
    game.player.position = Vector3(0.4,0,-16)
    game.player.camera.look_at(Vector3(1.9,-0.01,-20),Vector3.UP)
    await create_timer(0.3).timeout
    root.get_texture().get_image().save_png("res://../pipe_and_ruts.png")
    # 覗き込みの軌道に障害物があると開始しない。
    game.player.position = Vector3(-0.85,0,-6.3)
    game.player.camera.position = Vector3(0,1.6,0)
    var marker: Node3D = game.markers[0]
    var pose: Transform3D = game.player.inspection_view_pose(marker)
    var obstacle := StaticBody3D.new()
    var collision := CollisionShape3D.new()
    var shape := BoxShape3D.new()
    shape.size = Vector3(0.4,0.25,0.4)
    collision.shape = shape
    obstacle.add_child(collision)
    obstacle.position = (game.player.camera.global_position + pose.origin)*0.5
    game.add_child(obstacle)
    await physics_frame
    await physics_frame
    assert(not game.player.begin_inspection(marker))
    print("PASS: forestry rendered; blocked leaning path rejected")
    game.queue_free()
    await process_frame
    await process_frame
    quit()
