extends CharacterBody3D

var active := false
var sprinting := false
var stamina := 100.0
var camera: Camera3D
var lamp: SpotLight3D
var pitch := 0.0
var sensitivity := 0.0022
var distance_walked := 0.0

func _ready() -> void:
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.32
	capsule.height = 1.75
	shape.shape = capsule
	shape.position.y = 0.875
	add_child(shape)
	camera = Camera3D.new()
	camera.position.y = 1.6
	camera.fov = 77.0
	camera.far = 100.0
	add_child(camera)
	camera.current = true
	lamp = SpotLight3D.new()
	lamp.light_color = Color(0.75, 0.85, 1.0)
	lamp.light_energy = 3.7
	lamp.spot_range = 24.0
	lamp.spot_angle = 30.0
	lamp.spot_attenuation = 1.4
	lamp.position = Vector3(0.15, -0.13, -0.2)
	camera.add_child(lamp)

func _unhandled_input(event: InputEvent) -> void:
	if active and event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * sensitivity)
		pitch = clampf(pitch - event.relative.y * sensitivity, -1.3, 1.3)
		camera.rotation.x = pitch
	if active and event.is_action_pressed("flashlight"):
		lamp.visible = not lamp.visible

func _physics_process(delta: float) -> void:
	if not active:
		sprinting = false
		return
	var input := Input.get_vector("left", "right", "forward", "back")
	var direction := (transform.basis * Vector3(input.x, 0, input.y)).normalized()
	sprinting = Input.is_action_pressed("sprint") and input.length() > 0.1 and stamina > 0.5
	var speed := 5.7 if sprinting else 3.4
	velocity.x = direction.x * speed
	velocity.z = direction.z * speed
	if not is_on_floor():
		velocity.y -= 18.0 * delta
	else:
		velocity.y = 0.0
	move_and_slide()
	if input.length() > 0.1:
		distance_walked += delta * speed
		camera.position.y = 1.6 + sin(distance_walked * 3.0) * 0.025
	else:
		camera.position.y = lerpf(camera.position.y, 1.6, delta * 6.0)
