extends Node3D

const PlayerScript = preload("res://scripts/player.gd")
var player: CharacterBody3D
var markers: Array[Node3D] = []
var studied: Dictionary = {}
var stage: int = 0
var focus_dot: Label
var prompt_label: Label
var story_label: Label
var story_timer: float = 0.0
var game_finished: bool = false
var had_first_look: bool = false
var entered_deep: bool = false
var last_inspection_word: String = ""
var old_entrance_seen: bool = false
var event_state: int = 0
var finish_ready: bool = false
var creek: AudioStreamPlayer3D
var silence_tween: Tween
var ambience: AudioStreamPlayer
var help_label: Label
var debug_label: Label
var dialogue_queue: Array[Dictionary] = []
var dialogue_seen: Dictionary = {}
var dialogue_gap := 0.0
var subtitle_enabled := true
var entry_pos := Vector3(0, 0, 3)

func mat(color: Color, roughness: float = 1.0) -> StandardMaterial3D:
    var m := StandardMaterial3D.new()
    m.albedo_color = color
    m.roughness = roughness
    return m

func cube(parent: Node3D, size: Vector3, position: Vector3, material: Material) -> MeshInstance3D:
    var mesh := MeshInstance3D.new()
    var box := BoxMesh.new()
    box.size = size
    mesh.mesh = box
    mesh.position = position
    mesh.material_override = material
    parent.add_child(mesh)
    return mesh

func cylinder(parent: Node3D, radius: float, height: float, position: Vector3, material: Material, top_radius: float = -1.0) -> MeshInstance3D:
    var mesh := MeshInstance3D.new()
    var cyl := CylinderMesh.new()
    cyl.bottom_radius = radius
    cyl.top_radius = radius if top_radius < 0 else top_radius
    cyl.height = height
    mesh.mesh = cyl
    mesh.position = position
    mesh.material_override = material
    parent.add_child(mesh)
    return mesh

func label3d(parent: Node3D, words: String, height: float) -> void:
    var text_mesh := Label3D.new()
    text_mesh.text = words
    text_mesh.position = Vector3(0, height, 0)
    text_mesh.font_size = 38
    text_mesh.pixel_size = 0.0025
    text_mesh.modulate = Color(0.07, 0.04, 0.025)
    text_mesh.double_sided = true
    text_mesh.shaded = true
    parent.add_child(text_mesh)

func _ready() -> void:
    _build_world()
    _build_ui()
    _details()
    _build_night_post()
    _build_forestry_details()
    _queue_dialogue("arrival", [
        "航「袋、誰か持って。底、抜ける」",
        "真帆「私のだけちょうだい。……冷た」",
        "涼太「鍵、閉めた？」"
    ])

func _build_world() -> void:
    var env := WorldEnvironment.new()
    var settings := Environment.new()
    _configure_night_environment(settings)
    env.name = "WorldEnvironment"
    env.environment = settings
    add_child(env)
    var dim_light := DirectionalLight3D.new()
    dim_light.rotation_degrees = Vector3(-45, 25, 0)
    dim_light.name = "Moonlight"
    dim_light.light_energy = 0.03
    dim_light.light_color = Color(0.02, 0.04, 0.06)
    dim_light.light_volumetric_fog_energy = 0.0
    dim_light.shadow_enabled = true
    add_child(dim_light)

    var ground := StaticBody3D.new()
    add_child(ground)
    cube(ground, Vector3(100, 0.2, 110), Vector3(0, -0.17, -30), mat(Color(0.045, 0.062, 0.046)))
    var gc := CollisionShape3D.new()
    var gs := BoxShape3D.new()
    gs.size = Vector3(100, 0.2, 110)
    gc.shape = gs
    gc.position = Vector3(0, -0.17, -30)
    ground.add_child(gc)
    var dirt := mat(Color(0.13, 0.112, 0.085))
    for i in range(34):
        cube(self, Vector3(2.1, 0.012, 2.2), Vector3(sin(i * 0.65) * 0.27, -0.05, 1.3 - i * 1.68), dirt)

    var trunk := mat(Color(0.105, 0.077, 0.058))
    var leaf := mat(Color(0.018, 0.055, 0.045))
    var rng := RandomNumberGenerator.new()
    rng.seed = 451711
    for i in range(390):
        var x := rng.randf_range(-39.0, 39.0)
        var z := rng.randf_range(-77.0, 16.0)
        if abs(x) < 2.8 and z < 5.0 and z > -62.0:
            continue
        _build_cedar(Vector3(x, 0, z), rng, trunk, leaf)
    var pole := mat(Color(0.23, 0.20, 0.14))
    for x in [-2.25, 2.25]:
        cube(self, Vector3(0.12, 2.4, 0.12), Vector3(x, 1.2, 2.7), pole)
    cube(self, Vector3(4.65, 0.8, 0.18), Vector3(0, 2.0, 2.7), mat(Color(0.25, 0.21, 0.14)))
    var board := Node3D.new()
    board.position = Vector3(0, 1.80, 2.82)
    board.rotation = Vector3.ZERO # +Z面を開始位置（Z=6.4）へ向ける
    add_child(board)
    label3d(board, "立入禁止", 0.15)
    var sign_text := board.get_child(0) as Label3D
    sign_text.name = "EntranceSignText"
    sign_text.double_sided = false
    sign_text.font_size = 64
    sign_text.pixel_size = 0.006
    sign_text.no_depth_test = false
    sign_text.modulate = Color(0.23, 0.16, 0.12, 1.0)
    sign_text.outline_modulate = Color(0.17, 0.12, 0.09, 1.0)
    sign_text.outline_size = 1

    var data := [
        ["ポチ", -7.0, -0.85], ["みー", -11.0, 0.9],
        ["どらいぶ", -17.0, -1.05], ["さんさいとり", -23.5, 1.1],
        ["橋の手前", -31.0, -0.85], ["5時半", -39.5, 0.75],
        ["運転席", -48.0, 0.1]
    ]
    for item in data:
        var stick := Node3D.new()
        stick.position = Vector3(item[2], -0.06, item[1])
        stick.set_meta("word", item[0])
        add_child(stick)
        _build_stick_surface(stick, str(item[0]), markers.size())
        markers.append(stick)
    player = CharacterBody3D.new()
    player.set_script(PlayerScript)
    player.position = Vector3(0, 0.2, 6.4)
    add_child(player)

func _build_ui() -> void:
    var ui := CanvasLayer.new()
    ui.layer = 2
    add_child(ui)
    var root := Control.new()
    root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.mouse_filter = Control.MOUSE_FILTER_IGNORE
    ui.add_child(root)
    prompt_label = Label.new()
    prompt_label.anchor_left = 0.5
    prompt_label.anchor_right = 0.5
    prompt_label.anchor_top = 0.67
    prompt_label.anchor_bottom = 0.67
    prompt_label.position = Vector2(-48, 0)
    prompt_label.modulate.a = 0.68
    prompt_label.add_theme_font_size_override("font_size", 18)
    root.add_child(prompt_label)
    story_label = Label.new()
    story_label.anchor_left = 0.1
    story_label.anchor_right = 0.9
    story_label.anchor_top = 0.79
    story_label.anchor_bottom = 0.98
    story_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    story_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    story_label.add_theme_font_size_override("font_size", 24)
    root.add_child(story_label)
    focus_dot = Label.new()
    focus_dot.text = "·"
    focus_dot.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
    focus_dot.position = Vector2(-5, -12)
    focus_dot.add_theme_font_size_override("font_size", 22)
    root.add_child(focus_dot)


func show_story(message: String, seconds: float = 5.0) -> void:
    story_label.text = message
    story_timer = seconds

func _process(delta: float) -> void:
    if story_timer > 0.0:
        story_timer -= delta
        if story_timer <= 0.0:
            story_label.text = ""
    debug_label.text = "Z %.1f | 奥 %s | 帰路 %s | 調査 %d | %.0f FPS" % [player.position.z, entered_deep, finish_ready, studied.size(), Engine.get_frames_per_second()]
    _update_dialogue(delta)
    if game_finished:
        return
    if player.global_position.z < -25.0 and not entered_deep:
        entered_deep = true
        _adjust_fog(0.034)
    if player.global_position.z < -43.0 and event_state == 0:
        event_state = 1
        _fade_environment_to_silence()
        _queue_dialogue("deep", ["真帆「先、見てくる。そこ濡れてるよ」"])
        _adjust_fog(0.045)
    if player.global_position.z > -2.0 and event_state == 1 and not old_entrance_seen:
        old_entrance_seen = true
        finish_ready = true
    if finish_ready and player.global_position.z > 4.0:
        _finish()
        return
    _route_dialogue()
    focus_dot.visible = not player.inspection_active
    if player.inspection_active:
        prompt_label.text = "E / Esc 戻る"
        return
    var nearest: Node3D = null
    var nearest_dist: float = 2.7
    var camera_forward: Vector3 = -player.camera.global_transform.basis.z
    for marker in markers:
        var direction: Vector3 = marker.global_position + Vector3(0, 0.22, 0) - player.camera.global_position
        var dist: float = direction.length()
        var query := PhysicsRayQueryParameters3D.create(player.camera.global_position, marker.global_position + Vector3(0,0.22,0))
        query.exclude = [player.get_rid()]
        var blocked := not get_world_3d().direct_space_state.intersect_ray(query).is_empty()
        var flat := marker.global_position - player.global_position
        flat.y = 0.0
        if player.flash.visible and flat.length() <= 1.3 and not blocked and dist < nearest_dist and camera_forward.dot(direction.normalized()) > 0.89:
            nearest = marker
            nearest_dist = dist
    prompt_label.text = "E" if nearest != null  else ""
    if nearest != null and Input.is_action_just_pressed("inspect"):
        _inspect(nearest)

func _adjust_fog(target: float) -> void:
    var environment_node := get_node_or_null("WorldEnvironment") as WorldEnvironment
    if environment_node != null:
        environment_node.environment.fog_density = target

func _inspect(marker: Node3D) -> void:
    if not player.begin_inspection(marker):
        return
    focus_dot.hide()
    var word: String = str(marker.get_meta("word"))
    studied[marker] = true
    last_inspection_word = word
    # 文字は木肌にのみ表示する。字幕や独白への転記はしない。
    if word == "さんさいとり" and studied.has(markers[2]):
        _adjust_fog(0.038)
    if word == "運転席":
        player.normal_flash_energy = 19.2

func _finish() -> void:
    game_finished = true
    story_label.show()
    focus_dot.hide()
    player.end_inspection(true)
    dialogue_queue.clear()
    player.stop_footstep_audio()
    player.set_physics_process(false)
    Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
    prompt_label.text = ""
    show_story("涼太「……鍵、誰が持ってる？」\n\n— 試作版 終 —\nEnter でもう一度", 999.0)

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo:
        if event.keycode == KEY_J:
            subtitle_enabled = not subtitle_enabled
            story_label.visible = subtitle_enabled or game_finished
        if event.keycode == KEY_H: help_label.visible = not help_label.visible
        if event.keycode == KEY_F3: debug_label.visible = not debug_label.visible
        if event.keycode == KEY_ENTER and game_finished: get_tree().reload_current_scene()

func _details() -> void:
    help_label = Label.new()
    help_label.text = "WASD 移動 / マウス 視点 / Shift 早歩き / E 調べる / F 灯り\nEsc 一時停止 / H 操作表示 / V 揺れ切替 / J 会話字幕 / F3 開発情報"
    help_label.position = Vector2(26,25)
    help_label.add_theme_font_size_override("font_size",18)
    prompt_label.get_parent().add_child(help_label)
    get_tree().create_timer(12.0).timeout.connect(func(): help_label.hide())
    debug_label = Label.new()
    debug_label.position = Vector2(26,90)
    debug_label.hide()
    prompt_label.get_parent().add_child(debug_label)
    var shader := Shader.new()
    shader.code = "shader_type spatial; void fragment(){ float grain=sin(UV.x*195.0+sin(UV.y*67.0)*2.0)*0.5+0.5; ALBEDO=mix(vec3(0.055,0.040,0.027),vec3(0.19,0.14,0.10),grain); ROUGHNESS=1.0; }"
    var bark := ShaderMaterial.new()
    bark.shader = shader
    var rng := RandomNumberGenerator.new()
    rng.seed = 28041
    for child in get_children():
        if child is Node3D and child.is_in_group("cedar_trees"):
            var trunk = child.get_child(0)
            if trunk is MeshInstance3D and trunk.mesh is CylinderMesh:
                trunk.material_override = bark
                var body := StaticBody3D.new()
                child.add_child(body)
                var shape := CollisionShape3D.new()
                var cylinder_shape := CylinderShape3D.new()
                cylinder_shape.radius = trunk.mesh.bottom_radius
                cylinder_shape.height = trunk.mesh.height
                shape.shape = cylinder_shape
                shape.position = trunk.position
                body.add_child(shape)
    var needle := mat(Color(0.12,0.14,0.065))
    for i in range(700):
        var debris := cube(self,Vector3(rng.randf_range(0.04,0.16),0.018,rng.randf_range(0.12,0.35)),Vector3(rng.randf_range(-19,19),-0.035,rng.randf_range(-65,10)),needle)
        debris.rotation.y = rng.randf_range(-PI,PI)
    for i in range(65):
        var x := rng.randf_range(-20,20)
        if absf(x) < 1.6: continue
        cylinder(self,rng.randf_range(0.15,0.5),rng.randf_range(0.12,0.42),Vector3(x,0,rng.randf_range(-62,5)),mat(Color(0.18,0.20,0.17)),0.08)
    cube(self,Vector3(1,0.03,65),Vector3(3.1,-0.04,-26),mat(Color(0.025,0.045,0.041)))
    for z in [-17.0,-17.9,-18.8,-19.7]:
        var log_mesh := cylinder(self,0.19,3,Vector3(-4,0.18,z),mat(Color(0.24,0.17,0.10)))
        log_mesh.rotation.z = PI/2
    cube(self,Vector3(0.55,0.035,0.35),Vector3(1.8,0.01,-12),mat(Color(0.19,0.25,0.29)))
    for marker in markers:
        marker.rotation.y = rng.randf_range(-0.3, 0.3)
        marker.rotation.z = rng.randf_range(-0.10, 0.10)
    for side in [-1.0,1.0]: _boundary(Vector3(side*24,2,-28),Vector3(0.3,5,85))
    _boundary(Vector3(0,2,-67),Vector3(48,5,0.3))
    _boundary(Vector3(0,2,12),Vector3(48,5,0.3))
    ambience = AudioStreamPlayer.new()
    ambience.stream = load("res://audio/wind.wav")
    ambience.stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
    ambience.stream.loop_end = int(ambience.stream.get_length() * ambience.stream.mix_rate)
    ambience.volume_db = -21
    add_child(ambience)
    ambience.play()
    creek = AudioStreamPlayer3D.new()
    creek.stream = load("res://audio/water.wav")
    creek.stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
    creek.stream.loop_end = int(creek.stream.get_length() * creek.stream.mix_rate)
    creek.position = Vector3(5,0,-29)
    creek.max_distance = 32
    creek.unit_size = 5
    creek.volume_db = -19
    add_child(creek)
    creek.play()

func _boundary(pos: Vector3, size: Vector3) -> void:
    var body := StaticBody3D.new()
    add_child(body)
    var collision := CollisionShape3D.new()
    var box := BoxShape3D.new()
    box.size = size
    collision.shape = box
    collision.position = pos
    body.add_child(collision)


func _build_cedar(pos: Vector3, rng: RandomNumberGenerator,
        trunk_material: Material, leaf_material: Material) -> void:
    var h := rng.randf_range(12.0, 18.0)
    var radius := rng.randf_range(0.12, 0.22)
    var tree := Node3D.new()
    tree.position = pos
    add_child(tree)
    tree.add_to_group("cedar_trees")
    cylinder(tree, radius, h, Vector3(0, h * 0.5, 0),
        trunk_material, radius * 0.38)

    # 全ての葉の下端を10m以上に保つ。段状の円錐は使用しない。
    var crown_base := maxf(10.0, h * 0.70)
    var crown_height := h - crown_base
    var width := rng.randf_range(2.0, 2.8)
    for k in range(3):
        var mesh := SphereMesh.new()
        mesh.radius = 1.0
        mesh.height = 2.0
        mesh.radial_segments = 12
        mesh.rings = 6
        var foliage := MeshInstance3D.new()
        foliage.mesh = mesh
        foliage.material_override = leaf_material
        var half_height := crown_height * rng.randf_range(0.36, 0.50)
        foliage.scale = Vector3(width * rng.randf_range(0.65, 1.0),
            half_height, width * rng.randf_range(0.65, 1.0))
        foliage.position = Vector3(rng.randf_range(-0.55, 0.55),
            crown_base + half_height, rng.randf_range(-0.55, 0.55))
        foliage.rotation.y = rng.randf_range(-PI, PI)
        tree.add_child(foliage)

func _fade_environment_to_silence() -> void:
    if silence_tween != null and silence_tween.is_valid():
        silence_tween.kill()
    # 線形振幅で0へ落とし、最後に停止して完全無音にする。
    silence_tween = create_tween().set_parallel(true)
    silence_tween.tween_property(ambience, "volume_linear", 0.0, 0.75)
    silence_tween.tween_property(creek, "volume_linear", 0.0, 0.75)
    silence_tween.chain().tween_callback(func():
        ambience.stop()
        creek.stop()
    )


func _configure_night_environment(settings: Environment) -> void:
    settings.background_mode = Environment.BG_COLOR
    settings.background_color = Color(0.0003, 0.0005, 0.0008)
    settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    settings.ambient_light_color = Color(0.025, 0.04, 0.06)
    settings.ambient_light_energy = 0.02
    settings.ambient_light_sky_contribution = 0.0
    settings.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
    settings.fog_enabled = true
    settings.fog_density = 0.028
    settings.fog_light_color = Color(0.006, 0.009, 0.013)
    settings.fog_light_energy = 0.15
    settings.fog_sun_scatter = 0.0
    settings.fog_aerial_perspective = 0.0
    settings.tonemap_mode = Environment.TONE_MAPPER_FILMIC
    settings.tonemap_exposure = 0.95
    settings.tonemap_white = 4.0
    settings.adjustment_enabled = true
    settings.adjustment_brightness = 1.0
    settings.adjustment_contrast = 1.14
    settings.adjustment_saturation = 0.72
    settings.glow_enabled = false
    # Compatibility実行時には通常霧のみ。ライトシャフトはForward+専用。
    if RenderingServer.get_current_rendering_method() == "forward_plus":
        settings.volumetric_fog_enabled = true
        settings.volumetric_fog_density = 0.008
        settings.volumetric_fog_albedo = Color(0.72, 0.78, 0.83)
        settings.volumetric_fog_emission = Color.BLACK
        settings.volumetric_fog_emission_energy = 0.0
        settings.volumetric_fog_ambient_inject = 0.0
        settings.volumetric_fog_gi_inject = 0.0
        settings.volumetric_fog_anisotropy = 0.25
        settings.volumetric_fog_length = 24.0
        settings.volumetric_fog_temporal_reprojection_enabled = false

func _build_night_post() -> void:
    var layer := CanvasLayer.new()
    layer.name = "NightPost"
    layer.layer = 1
    add_child(layer)
    var rect := ColorRect.new()
    rect.name = "NightGrade"
    rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var material := ShaderMaterial.new()
    material.shader = load("res://shaders/night_post.gdshader")
    rect.material = material
    layer.add_child(rect)


func _build_stick_surface(stick: Node3D, word: String, index: int) -> void:
    var shader := Shader.new()
    shader.code = "shader_type spatial; void fragment(){ float grain=sin(UV.x*173.0 + sin(UV.y*29.0)*1.2)*0.5+0.5; ALBEDO=mix(vec3(0.34,0.28,0.19),vec3(0.50,0.42,0.29),grain*0.16+0.5); ROUGHNESS=0.95; }"
    var wood := ShaderMaterial.new()
    wood.shader = shader
    var body := MeshInstance3D.new()
    var capsule := CapsuleMesh.new()
    capsule.radius = 0.016
    capsule.height = 0.22
    capsule.radial_segments = 16
    capsule.rings = 8
    body.mesh = capsule
    body.position.y = 0.11
    body.scale.z = 0.25
    body.material_override = wood
    stick.add_child(body)
    var writing := Node3D.new()
    writing.name = "Writing"
    stick.add_child(writing)
    var pen_font := SystemFont.new()
    pen_font.font_names = PackedStringArray(["UD Digi Kyokasho N-R", "UD デジタル 教科書体 N-R", "Yu Mincho"])
    var rng := RandomNumberGenerator.new()
    rng.seed = 8200 + index
    for i in range(word.length()):
        var ink := Label3D.new()
        ink.text = word.substr(i, 1)
        ink.font = pen_font
        ink.font_size = 64
        ink.pixel_size = 0.00021
        ink.position = Vector3(rng.randf_range(-0.002, 0.002), 0.180 - i * 0.023, 0.005)
        ink.rotation.z = rng.randf_range(-0.07, 0.07)
        ink.modulate = Color(0.105, 0.068, 0.040, rng.randf_range(0.80, 0.97))
        ink.outline_size = 0
        ink.shaded = true
        ink.double_sided = false
        writing.add_child(ink)

func _queue_dialogue(id: String, lines: Array) -> void:
    if dialogue_seen.has(id):
        return
    dialogue_seen[id] = true
    # 次の区間では、まだ発話していない前区間の台詞を持ち越さない。
    dialogue_queue.clear()
    for line in lines:
        dialogue_queue.append({"text": str(line), "duration": 3.8 if str(line).length() < 22 else 4.8})

func _update_dialogue(delta: float) -> void:
    if game_finished or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
        return
    dialogue_gap = maxf(0.0, dialogue_gap - delta)
    if story_timer <= 0.0 and dialogue_gap <= 0.0 and not dialogue_queue.is_empty() and not player.inspection_active:
        var line := dialogue_queue.pop_front() as Dictionary
        show_story(str(line["text"]), float(line["duration"]))
        dialogue_gap = float(line["duration"]) + 1.6

func _route_dialogue() -> void:
    var z := player.global_position.z
    if z < -6 and event_state == 0:
        _queue_dialogue("signal", ["航「さっきまで一本あったのに」", "真帆「送れてる。既読つかないだけ」"])
    if z < -17 and event_state == 0:
        _queue_dialogue("mud", ["涼太「うわ、靴ん中入った」", "航「だからそっち歩くなって」"])
    if z < -30 and event_state == 0:
        _queue_dialogue("missing", ["真帆「航、先行った？」", "涼太「車じゃないの」"])
    if z < -38 and event_state == 0:
        _queue_dialogue("cold", ["真帆「上、持ってくればよかった」"])
    if z > -18 and event_state == 1:
        _queue_dialogue("return", ["涼太「鍵、航に渡したっけ」", "真帆「ポケット見たら」"])

func _build_forestry_details() -> void:
    var details := Node3D.new()
    details.name = "ForestryDetails"
    details.set_script(load("res://scripts/forestry_details.gd"))
    add_child(details)
