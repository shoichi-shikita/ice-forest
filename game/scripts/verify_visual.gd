extends SceneTree
func _initialize() -> void:
    call_deferred("run")
func run() -> void:
    var game = load("res://main.tscn").instantiate()
    root.add_child(game)
    await create_timer(1.0).timeout
    var trees := get_nodes_in_group("cedar_trees")
    assert(not trees.is_empty())
    for tree in trees:
        var trunk := tree.get_child(0) as MeshInstance3D
        assert(trunk.mesh.height >= 12.0 and trunk.mesh.height <= 18.0)
        assert(trunk.mesh.bottom_radius >= 0.12 and trunk.mesh.bottom_radius <= 0.22)
        assert(tree.get_child(4) is StaticBody3D)
        for k in range(1,4):
            var foliage := tree.get_child(k) as MeshInstance3D
            assert(foliage.position.y - foliage.scale.y >= 9.9999)
    var sign_text := game.find_child("EntranceSignText",true,false) as Label3D
    assert(sign_text.global_position.z > 2.79)
    assert(sign_text.global_basis.z.dot(game.player.position-sign_text.global_position)>0)
    assert(is_equal_approx(game.player.flash.spot_angle,34.0))
    assert(is_equal_approx(game.player.flash.spot_angle_attenuation,4.5))
    await process_frame
    await process_frame
    root.get_texture().get_image().save_png("res://../entrance_adjusted.png")
    game.player.position = Vector3(0,0,-9)
    game.player.pitch = 0.52
    await create_timer(0.5).timeout
    root.get_texture().get_image().save_png("res://../canopy_adjusted.png")
    print("PASS: sign facing, ",trees.size()," cedar heights/radii/crown bases/collisions, flashlight settings")
    game.queue_free()
    await process_frame
    quit()


