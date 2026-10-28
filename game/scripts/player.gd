extends CharacterBody3D

var speed: float = 3.1
var sensitivity: float = 0.0022
var gravity: float = 18.0
var pitch: float = 0.0
var camera: Camera3D
var foot: AudioStreamPlayer3D
@export_range(0.0, 1.0, 0.05) var motion_strength: float = 1.0
const EYE_HEIGHT := 1.6
var gait_phase := 0.0
var breath_phase := 0.0
var bob_weight := 0.0
var run_weight := 0.0
var camera_offset_target := Vector3.ZERO
var camera_angles_target := Vector3.ZERO
var camera_angles := Vector3.ZERO
const GHOST_CHANCE := 0.11
const GHOST_DELAY := 0.25
var ghost_step: AudioStreamPlayer3D
var ghost_timer: Timer
var step_rng := RandomNumberGenerator.new()
var audio_ended := false
var inspection_active := false
var inspection_blend := 0.0
var inspection_pose := Transform3D.IDENTITY
var inspection_tween: Tween
var normal_flash_energy := 32.0
var flash_rest := Vector3(0.18, -0.15, -0.15)
var flash: SpotLight3D

func _ready() -> void:
    camera = Camera3D.new()
    camera.position.y = EYE_HEIGHT
    camera.fov = 72.0
    camera.current = true
    camera.near = 0.08
    camera.far = 90.0
    var attributes := CameraAttributesPractical.new()
    attributes.auto_exposure_enabled = false
    camera.attributes = attributes
    add_child(camera)
    flash = SpotLight3D.new()
    flash.position = Vector3(0.18, -0.15, -0.15)
    flash.spot_range = 19.0
    flash.spot_angle = 34.0
    flash.spot_angle_attenuation = 4.5
    flash.spot_attenuation = 1.1
    flash.light_energy = 32.0
    flash.light_color = Color(1.0, 0.95, 0.86)
    flash.light_volumetric_fog_energy = 0.65
    flash.shadow_enabled = true
    camera.add_child(flash)
    var collision := CollisionShape3D.new()
    var capsule := CapsuleShape3D.new()
    capsule.radius = 0.35
    capsule.height = 1.8
    collision.shape = capsule
    collision.position.y = 0.95
    add_child(collision)
    foot = AudioStreamPlayer3D.new()
    foot.stream = load("res://audio/step.wav")
    foot.volume_db = -15
    add_child(foot)
    step_rng.randomize()
    ghost_step = AudioStreamPlayer3D.new()
    ghost_step.stream = foot.stream
    ghost_step.volume_db = -26.0
    ghost_step.pitch_scale = 0.82
    ghost_step.unit_size = 1.0
    ghost_step.max_distance = 9.0
    add_child(ghost_step)
    ghost_step.top_level = true
    ghost_timer = Timer.new()
    ghost_timer.one_shot = true
    ghost_timer.wait_time = GHOST_DELAY
    add_child(ghost_timer)
    ghost_timer.timeout.connect(_play_ghost_step)
    Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not inspection_active:
        rotate_y(-event.relative.x * sensitivity)
        pitch = clamp(pitch - event.relative.y * sensitivity, -1.35, 1.35)
    if event is InputEventKey and event.pressed and not event.echo and inspection_active and (event.keycode == KEY_E or event.keycode == KEY_ESCAPE):
        end_inspection()
        get_viewport().set_input_as_handled()
        return
    if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
        Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED
    if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_V:
        motion_strength = 0.0 if motion_strength > 0.0 else 1.0
    if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F:
        flash.visible = not flash.visible

func _physics_process(delta: float) -> void:
    if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
        return
    if inspection_active:
        velocity = Vector3.ZERO
        return
    if not is_on_floor():
        velocity.y -= gravity * delta
    var input_vector := Vector2.ZERO
    if Input.is_key_pressed(KEY_W): input_vector.y -= 1.0
    if Input.is_key_pressed(KEY_S): input_vector.y += 1.0
    if Input.is_key_pressed(KEY_A): input_vector.x -= 1.0
    if Input.is_key_pressed(KEY_D): input_vector.x += 1.0
    input_vector = input_vector.normalized()
    var direction := (transform.basis * Vector3(input_vector.x, 0.0, input_vector.y)).normalized()
    var target_speed := 4.8 if Input.is_key_pressed(KEY_SHIFT) else speed
    velocity.x = direction.x * target_speed
    velocity.z = direction.z * target_speed
    move_and_slide()
    var travel := Vector2(get_position_delta().x, get_position_delta().z).length()
    var step_landed := _update_camera_motion(delta, travel, is_on_floor(),
        Input.is_key_pressed(KEY_SHIFT))
    if step_landed:
        foot.pitch_scale = step_rng.randf_range(0.88, 1.12)
        foot.play()
        _maybe_queue_ghost_step()

func _maybe_queue_ghost_step() -> void:
    if audio_ended or global_position.z >= -25.0:
        return
    if not ghost_timer.is_stopped() or ghost_step.playing:
        return
    # 通常の足音が鳴った時だけ11%。フレームごとの抽選はしない。
    if step_rng.randf() < GHOST_CHANCE:
        _queue_ghost_step()

func _queue_ghost_step() -> void:
    if audio_ended or not ghost_timer.is_stopped() or ghost_step.playing:
        return
    # +Zは身体の後方。予約時の位置に固定して、追従させない。
    ghost_step.global_position = global_position + global_basis.z * 1.4 + Vector3.UP * 0.12
    ghost_step.pitch_scale = step_rng.randf_range(0.78, 0.86)
    ghost_timer.start()

func _play_ghost_step() -> void:
    # 停止時も、すでに予約された1歩は残す。
    if not audio_ended:
        ghost_step.play()

func stop_footstep_audio() -> void:
    audio_ended = true
    ghost_timer.stop()
    ghost_step.stop()
    foot.stop()

func _update_camera_motion(delta: float, travel: float,
        grounded: bool, sprinting: bool) -> bool:
    var moving := grounded and travel > 0.0002
    bob_weight = move_toward(bob_weight, 1.0 if moving else 0.0, delta * 5.0)
    run_weight = move_toward(run_weight, 1.0 if moving and sprinting else 0.0, delta * 4.0)
    breath_phase = fposmod(breath_phase + delta * TAU * 0.23, TAU * 100.0)
    var step_landed := false
    if moving:
        # phaseの半周が1歩。移動距離で進めるため、壁では足踏みしない。
        var step_distance := lerpf(1.65, 1.85, run_weight)
        var next_phase := gait_phase + travel / step_distance * PI
        step_landed = floori(next_phase / PI) > floori(gait_phase / PI)
        gait_phase = fposmod(next_phase, TAU)
    var side := lerpf(0.018, 0.034, run_weight)
    var vertical := lerpf(0.014, 0.027, run_weight)
    var idle := Vector3(sin(breath_phase * 0.63) * 0.0015,
        sin(breath_phase) * 0.0025, 0.0)
    var bob := Vector3(sin(gait_phase) * side,
        cos(gait_phase * 2.0) * vertical, 0.0) * bob_weight
    camera_offset_target = (idle + bob) * motion_strength
    camera_angles_target = Vector3(
        sin(gait_phase * 2.0) * 0.0018 * bob_weight + sin(breath_phase) * 0.0008,
        0.0, sin(gait_phase) * lerpf(0.003, 0.007, run_weight) * bob_weight
    ) * motion_strength
    return moving and step_landed

func _process(delta: float) -> void:
    if audio_ended or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
        return
    flash.light_energy = lerpf(normal_flash_energy, 1.1, inspection_blend)
    flash.position = flash_rest.lerp(Vector3(0.025, -0.015, -0.02), inspection_blend)
    camera.fov = lerpf(72.0, 40.0, inspection_blend)
    if inspection_active:
        var resting := global_transform * Transform3D(Basis.from_euler(Vector3(pitch, 0.0, 0.0)), Vector3(0, EYE_HEIGHT, 0))
        camera.global_transform = resting.interpolate_with(inspection_pose, inspection_blend)
        return
    # 描画フレーム側で補間し、物理フレームの段付きと揺れの累積を防ぐ。
    var blend := 1.0 - exp(-14.0 * delta)
    camera.position = camera.position.lerp(
        Vector3(0.0, EYE_HEIGHT, 0.0) + camera_offset_target, blend)
    camera_angles = camera_angles.lerp(camera_angles_target, blend)
    camera.rotation = Vector3(pitch + camera_angles.x, 0.0, camera_angles.z)

func inspection_view_pose(marker: Node3D) -> Transform3D:
    var focus: Vector3 = marker.to_global(Vector3(0, 0.12, 0.005))
    var away := global_position - marker.global_position
    away.y = 0.0
    if away.length_squared() < 0.001:
        away = marker.global_basis.z
    var view_pos := focus + away.normalized() * 0.36 + Vector3.UP * 0.32
    return Transform3D(Basis.IDENTITY, view_pos).looking_at(focus, Vector3.UP)

func begin_inspection(marker: Node3D) -> bool:
    if inspection_active or audio_ended or not flash.visible:
        return false
    var flat := global_position - marker.global_position
    flat.y = 0.0
    if flat.length() > 1.3:
        return false
    var pose := inspection_view_pose(marker)
    var query := PhysicsRayQueryParameters3D.create(camera.global_position, pose.origin)
    query.exclude = [get_rid()]
    if not get_world_3d().direct_space_state.intersect_ray(query).is_empty():
        return false
    inspection_active = true
    inspection_pose = pose
    velocity = Vector3.ZERO
    camera_offset_target = Vector3.ZERO
    camera_angles_target = Vector3.ZERO
    camera_angles = Vector3.ZERO
    inspection_tween = create_tween()
    inspection_tween.tween_property(self, "inspection_blend", 1.0, 0.48).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
    return true

func end_inspection(immediate: bool = false) -> void:
    if inspection_tween != null and inspection_tween.is_valid():
        inspection_tween.kill()
    if immediate:
        inspection_blend = 0.0
        inspection_active = false
        camera.position = Vector3(0, EYE_HEIGHT, 0)
        camera.rotation = Vector3(pitch, 0, 0)
        camera.fov = 72.0
        flash.position = flash_rest
        flash.light_energy = normal_flash_energy
        return
    if not inspection_active:
        return
    inspection_tween = create_tween()
    inspection_tween.tween_property(self, "inspection_blend", 0.0, 0.34).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
    inspection_tween.tween_callback(func(): inspection_active = false)
