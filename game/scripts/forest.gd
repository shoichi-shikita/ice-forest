extends Node3D

const RunState = preload("res://scripts/run_state.gd")
const Player = preload("res://scripts/player.gd")
var state = RunState.new()
var player: CharacterBody3D
var playing := false
var paused := false
var elapsed := 0.0
var sigils: Array[Node3D] = []
var gate := Vector3(0, 0, -43)
var shade: Node3D
var hud: Label
var prompt: Label
var danger: Label
var stamina_bar: ProgressBar
var menu: Control
var heading: Label
var description: Label
var start_button: Button
var ambient: AudioStreamPlayer
var tone: AudioStreamPlayer
var smoke_seconds := 0.0
var capture_path := ""
var smoke_mode := false

func _ready() -> void:
	_setup_input()
	_environment()
	_world()
	_interface()
	_audio()
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture="):
			capture_path = argument.trim_prefix("--capture=")
		if argument == "--smoke":
			smoke_mode = true
	if smoke_mode or not capture_path.is_empty():
		_start()

func _setup_input() -> void:
	var keys := {"forward": [KEY_W, KEY_UP], "back": [KEY_S, KEY_DOWN], "left": [KEY_A, KEY_LEFT], "right": [KEY_D, KEY_RIGHT], "sprint": [KEY_SHIFT], "interact": [KEY_E], "flashlight": [KEY_F], "pause": [KEY_ESCAPE]}
	for action: String in keys:
		InputMap.add_action(action)
		for key: int in keys[action]:
			var event := InputEventKey.new()
			event.physical_keycode = key
			InputMap.action_add_event(action, event)

func _material(color: Color, glow := false) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.88
	if glow:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = 2.2
	return material

func _mesh(mesh: Mesh, position_: Vector3, material: Material, parent: Node = self) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = position_
	instance.material_override = material
	parent.add_child(instance)
	return instance

func _box(position_: Vector3, size_: Vector3, material: Material, collide := false) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size_
	_mesh(mesh, position_, material)
	if collide:
		var body := StaticBody3D.new()
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size_
		collision.shape = shape
		body.position = position_
		body.add_child(collision)
		add_child(body)

func _environment() -> void:
	var world := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.025, 0.05, 0.085)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.30, 0.43, 0.62)
	environment.ambient_light_energy = 0.55
	environment.fog_enabled = true
	environment.fog_light_color = Color(0.045, 0.08, 0.12)
	environment.fog_density = 0.023
	world.environment = environment
	add_child(world)
	var moon := DirectionalLight3D.new()
	moon.rotation_degrees = Vector3(-38, -30, 0)
	moon.light_color = Color(0.49, 0.68, 0.9)
	moon.light_energy = 0.8
	add_child(moon)

func _world() -> void:
	var snow := _material(Color(0.31, 0.41, 0.49))
	var bark := _material(Color(0.055, 0.085, 0.1))
	var needles := _material(Color(0.09, 0.18, 0.21))
	_box(Vector3(0, -0.2, -14), Vector3(100, 0.4, 110), snow, true)
	# Invisible perimeter prevents walking off the small prototype world.
	var boundary := _material(Color(0.09, 0.14, 0.18))
	for x: float in [-49.0, 49.0]:
		_box(Vector3(x, 2, -14), Vector3(1, 5, 110), boundary, true)
	for z: float in [-68.0, 40.0]:
		_box(Vector3(0, 2, z), Vector3(100, 5, 1), boundary, true)
	var rng := RandomNumberGenerator.new()
	rng.seed = 4170
	for index in range(150):
		var p := Vector3(rng.randf_range(-44, 44), 0, rng.randf_range(-60, 32))
		if absf(p.x) < 4.0 or p.distance_to(Vector3(0, 0, 14)) < 7.0:
			continue
		var h := rng.randf_range(5.0, 9.5)
		_box(p + Vector3(0, h * 0.36, 0), Vector3(0.45, h * 0.72, 0.45), bark, true)
		for tier in range(3):
			var cone := CylinderMesh.new()
			cone.top_radius = 0.0
			cone.bottom_radius = 1.9 - tier * 0.38
			cone.height = h * 0.45
			cone.radial_segments = 7
			_mesh(cone, p + Vector3(0, h * (0.44 + tier * 0.18), 0), needles)
		var cap := CylinderMesh.new()
		cap.top_radius = 0.0
		cap.bottom_radius = 0.9
		cap.height = 2.0
		cap.radial_segments = 7
		_mesh(cap, p + Vector3(0, h * 0.91, 0), snow)
	var ice := _material(Color(0.15, 0.32, 0.42))
	for i in range(12):
		var stone := SphereMesh.new()
		stone.radius = 0.7
		stone.height = 0.8
		_mesh(stone, Vector3(rng.randf_range(-35, 35), 0.2, rng.randf_range(-50, 25)), ice)
	# The visible path and warm gate provide orientation without a minimap.
	var path := _material(Color(0.19, 0.28, 0.34))
	_box(Vector3(0, 0.015, -14), Vector3(3, 0.02, 65), path)
	var wood := _material(Color(0.15, 0.18, 0.18))
	_box(gate + Vector3(-2.3, 2.0, 0), Vector3(0.5, 4, 0.6), wood, true)
	_box(gate + Vector3(2.3, 2.0, 0), Vector3(0.5, 4, 0.6), wood, true)
	_box(gate + Vector3(0, 4.0, 0), Vector3(5.1, 0.5, 0.6), wood)
	var warm := OmniLight3D.new()
	warm.position = gate + Vector3(0, 2.8, 0)
	warm.light_color = Color(1.0, 0.48, 0.20)
	warm.light_energy = 2.8
	warm.omni_range = 12
	add_child(warm)
	var beacon := SphereMesh.new()
	beacon.radius = 0.18
	beacon.height = 0.36
	_mesh(beacon, warm.position, _material(Color(1.0, 0.5, 0.15), true))
	for p: Vector3 in [Vector3(-13, 1.2, -4), Vector3(14, 1.2, -17), Vector3(-11, 1.2, -32)]:
		var sigil := Node3D.new()
		sigil.position = p
		add_child(sigil)
		var crystal := PrismMesh.new()
		crystal.size = Vector3(0.45, 0.8, 0.45)
		_mesh(crystal, Vector3.ZERO, _material(Color(0.35, 0.88, 0.95), true), sigil)
		var light := OmniLight3D.new()
		light.light_color = Color(0.3, 0.8, 1.0)
		light.light_energy = 2.8
		light.omni_range = 8
		sigil.add_child(light)
		sigils.append(sigil)
	shade = Node3D.new()
	shade.position = Vector3(25, 0, -37)
	add_child(shade)
	var shadow_mesh := CapsuleMesh.new()
	shadow_mesh.radius = 0.45
	shadow_mesh.height = 2.8
	_mesh(shadow_mesh, Vector3(0, 1.4, 0), _material(Color(0.01, 0.017, 0.02)), shade)
	for x: float in [-0.15, 0.15]:
		var eye := SphereMesh.new()
		eye.radius = 0.045
		eye.height = 0.09
		_mesh(eye, Vector3(x, 2.1, 0.41), _material(Color(0.7, 0.2, 0.1), true), shade)
	shade.visible = false
	player = Player.new()
	player.position = Vector3(0, 0.1, 14)
	add_child(player)

func _label(text_: String, size_: int, color := Color(0.82, 0.9, 0.94)) -> Label:
	var label := Label.new()
	label.text = text_
	label.add_theme_font_size_override("font_size", size_)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func _interface() -> void:
	var canvas := CanvasLayer.new()
	add_child(canvas)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(root)
	var theme := Theme.new()
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Yu Gothic UI", "Meiryo", "sans-serif"])
	theme.default_font = font
	root.theme = theme
	var vignette := ColorRect.new()
	vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader := Shader.new()
	shader.code = "shader_type canvas_item; void fragment(){ float d=length((UV-vec2(0.5))*vec2(1.0,0.8)); COLOR=vec4(0.005,0.012,0.025,smoothstep(0.18,0.67,d)*0.8); }"
	var shader_material := ShaderMaterial.new()
	shader_material.shader = shader
	vignette.material = shader_material
	root.add_child(vignette)
	hud = _label("", 19)
	hud.position = Vector2(36, 30)
	root.add_child(hud)
	var crosshair := _label("·", 30, Color(0.7, 0.85, 0.9, 0.6))
	crosshair.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	root.add_child(crosshair)
	prompt = _label("", 21)
	prompt.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	prompt.offset_left = -320
	prompt.offset_right = 320
	prompt.offset_top = -110
	prompt.offset_bottom = -70
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(prompt)
	danger = _label("", 18, Color(1.0, 0.57, 0.36))
	danger.position = Vector2(36, 62)
	root.add_child(danger)
	stamina_bar = ProgressBar.new()
	stamina_bar.position = Vector2(36, 660)
	stamina_bar.size = Vector2(180, 5)
	stamina_bar.show_percentage = false
	stamina_bar.modulate = Color(0.5, 0.8, 0.85)
	root.add_child(stamina_bar)
	var help := _label("WASD  移動    SHIFT  走る    E  調べる    F  ライト    ESC  一時停止", 15, Color(0.57, 0.68, 0.75))
	help.position = Vector2(36, 684)
	root.add_child(help)
	menu = Control.new()
	menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(menu)
	var veil := ColorRect.new()
	veil.color = Color(0.018, 0.033, 0.05, 0.88)
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu.add_child(veil)
	var column := VBoxContainer.new()
	column.position = Vector2(105, 130)
	column.size = Vector2(920, 480)
	column.add_theme_constant_override("separation", 15)
	menu.add_child(column)
	column.add_child(_label("A SMALL EXPERIMENT IN THE COLD", 15, Color(0.42, 0.7, 0.75)))
	heading = _label("ICE FOREST", 74, Color(0.88, 0.95, 0.98))
	column.add_child(heading)
	description = _label("森の静けさには、近づいてはいけない。\n\n青い欠片を3つ集め、灯りのある門へ。\n最初の欠片に触れると、何かがあなたを追い始める。\nヘッドホン推奨。突然の大音量演出はありません。", 21)
	column.add_child(description)
	start_button = Button.new()
	start_button.text = "森に入る   →"
	start_button.custom_minimum_size = Vector2(260, 52)
	start_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	start_button.add_theme_font_size_override("font_size", 21)
	start_button.modulate = Color(0.75, 0.9, 0.95)
	start_button.pressed.connect(_menu_action)
	column.add_child(start_button)
	var quit_button := Button.new()
	quit_button.text = "終了"
	quit_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	quit_button.pressed.connect(func() -> void: get_tree().quit())
	column.add_child(quit_button)
	column.add_child(_label("WINDOWS PROTOTYPE 0.1   /   仮仕様・開発中", 14, Color(0.42, 0.54, 0.62)))
	start_button.grab_focus()

func _audio() -> void:
	ambient = AudioStreamPlayer.new()
	ambient.volume_db = -24
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_end = 88200
	var bytes := PackedByteArray()
	bytes.resize(176400)
	var rng := RandomNumberGenerator.new()
	rng.seed = 71
	var filtered := 0.0
	for i in range(88200):
		filtered = filtered * 0.96 + rng.randf_range(-1, 1) * 0.04
		var value := filtered * 0.6 + sin(float(i) / 22050 * TAU * 55) * 0.04
		bytes.encode_s16(i * 2, int(value * 20000))
	stream.data = bytes
	ambient.stream = stream
	add_child(ambient)
	tone = AudioStreamPlayer.new()
	tone.volume_db = -18
	add_child(tone)

func _chime() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	var bytes := PackedByteArray()
	bytes.resize(22050)
	for i in range(11025):
		var time := float(i) / 22050
		bytes.encode_s16(i * 2, int(sin(time * TAU * 660) * exp(-time * 8) * 6000))
	stream.data = bytes
	tone.stream = stream
	tone.play()

func _menu_action() -> void:
	if paused:
		_pause(false)
	else:
		_start()

func _start() -> void:
	state.reset()
	player.position = Vector3(0, 0.1, 14)
	player.rotation = Vector3.ZERO
	player.pitch = 0.0
	player.camera.rotation = Vector3.ZERO
	player.velocity = Vector3.ZERO
	player.stamina = state.MAX_STAMINA
	player.sprinting = false
	player.lamp.visible = true
	shade.position = Vector3(25, 0, -37)
	shade.visible = false
	for sigil in sigils:
		sigil.visible = true
	playing = true
	paused = false
	elapsed = 0.0
	menu.visible = false
	prompt.text = ""
	danger.text = ""
	player.active = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if DisplayServer.get_name() != "headless":
		ambient.play()

func _exit_tree() -> void:
	if is_instance_valid(ambient):
		ambient.stop()
	if is_instance_valid(tone):
		tone.stop()

func _pause(value: bool) -> void:
	paused = value
	player.active = not value
	menu.visible = value
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if value else Input.MOUSE_MODE_CAPTURED
	if value:
		heading.text = "森は待っている"
		description.text = "一時停止中です。"
		start_button.text = "探索に戻る   →"
		start_button.grab_focus()
		ambient.stream_paused = true
	else:
		ambient.stream_paused = false

func _end(escaped: bool) -> void:
	playing = false
	player.active = false
	menu.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	heading.text = "夜明けの手前で" if escaped else "森に見つかった"
	description.text = "門の向こうに、かすかな朝の匂いがした。\n\n試作クリア。探索時間 %.0f 秒\nこの先の物語は、これから。" % elapsed if escaped else "足音を止めても、気配は消えなかった。\n\n走る力を残しながら、青い光を探してみよう。"
	start_button.text = "もう一度   →"
	start_button.grab_focus()
	ambient.stop()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and playing:
		_pause(not paused)
	if event.is_action_pressed("interact") and playing and not paused:
		for i in range(sigils.size()):
			if sigils[i].visible and player.position.distance_to(sigils[i].position) < 3.0:
				if state.collect_sigil(str(i)):
					sigils[i].visible = false
					_chime()
		if player.position.distance_to(gate) < 3.3 and state.try_escape():
			_end(true)

func _process(delta: float) -> void:
	if smoke_mode or not capture_path.is_empty():
		smoke_seconds += delta
		if smoke_seconds > 2.0:
			smoke_seconds = -100.0
			if not capture_path.is_empty():
				await RenderingServer.frame_post_draw
				var result := get_viewport().get_texture().get_image().save_png(capture_path)
				if result != OK:
					get_tree().quit(1)
					return
			print("ICE_FOREST_SMOKE_PASS")
			get_tree().quit(0)
			return
	if not playing or paused:
		return
	elapsed += delta
	state.tick(delta, player.sprinting)
	player.stamina = state.stamina
	stamina_bar.value = state.stamina
	var count: int = state.collected.size()
	hud.text = "欠片  %d / 3     |     ICE FOREST" % count
	prompt.text = ""
	for sigil in sigils:
		if sigil.visible:
			sigil.rotation.y += delta * 0.7
			if player.position.distance_to(sigil.position) < 3.0:
				prompt.text = "[ E ]   凍った欠片を拾う"
	if player.position.distance_to(gate) < 4.0:
		prompt.text = "[ E ]   門の向こうへ" if state.can_escape() else "門は閉ざされている。欠片を3つ探そう。"
	if count > 0:
		shade.visible = true
		var target := Vector3(player.position.x, 0, player.position.z)
		shade.position = shade.position.move_toward(target, delta * (1.65 + count * 0.20))
		if shade.position.distance_to(target) > 0.1:
			shade.look_at(target, Vector3.UP, true)
		var distance := shade.position.distance_to(target)
		danger.text = "背後で、雪が鳴る。" if distance < 16.0 else ""
		ambient.volume_db = -20 if distance < 16.0 else -24
		if distance < 1.25:
			state.catch_player()
			_end(false)
