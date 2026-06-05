extends SpringArm3D
class_name CameraArm

@export var shoulder_offset: Vector3 = Vector3(0.65, 1.65, 0.0)
@export var default_pitch_angle: float = -18.0
@export_range(5.0, 80.0) var x_min_limit_angle: float = 8.0
@export_range(5.0, 80.0) var x_max_limit_angle: float = 55.0
@export var x_speed: float = 5.0
@export var y_speed: float = 5.0
@export var distance: float = 4.8
@export var min_distance: float = 3.2
@export var max_distance: float = 7.0
@export var distance_speed: float = 0.8
@export var need_damping: bool = true
@export var damping: float = 12.0
@export var follow_damping: float = 14.0
@export var zoom_damping: float = 10.0
@export var capture_mouse_on_ready: bool = true

var mouse_right_press: bool = false
var x: float = 0.0
var y: float = 0.0
var follow_target: Node3D


func _ready() -> void:
	follow_target = get_parent() as Node3D

	var start_transform := global_transform
	top_level = true
	global_transform = start_transform

	var start_euler := global_transform.basis.get_euler()
	x = _clamp_pitch(deg_to_rad(default_pitch_angle))
	y = start_euler.y
	distance = clamp(distance, min_distance, max_distance)

	if capture_mouse_on_ready:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	var camera: Camera3D = get_node_or_null("Camera3D") as Camera3D
	if camera:
		camera.current = true


func _process(delta: float) -> void:
	if follow_target == null:
		return

	var desired_position := _get_desired_position()
	var desired_rotation := Quaternion.from_euler(Vector3(x, y, 0.0))

	if need_damping:
		global_position = global_position.lerp(desired_position, _smooth_weight(follow_damping, delta))

		var current_rotation := global_transform.basis.get_rotation_quaternion()
		_set_global_rotation(current_rotation.slerp(desired_rotation, _smooth_weight(damping, delta)))
		spring_length = lerp(spring_length, distance, _smooth_weight(zoom_damping, delta))
	else:
		global_position = desired_position
		_set_global_rotation(desired_rotation)
		spring_length = distance


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseButton:
		if capture_mouse_on_ready and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

		if event.button_index == MOUSE_BUTTON_RIGHT:
			mouse_right_press = event.pressed
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
			distance = clamp(distance - distance_speed, min_distance, max_distance)
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			distance = clamp(distance + distance_speed, min_distance, max_distance)
	elif event is InputEventMouseMotion and _can_rotate_with_mouse():
		x = _clamp_pitch(x - event.relative.y * x_speed * 0.001)
		y = wrapf(y - event.relative.x * y_speed * 0.001, -PI, PI)


func get_camera_yaw() -> float:
	return y


func _get_desired_position() -> Vector3:
	var yaw_basis := Basis(Vector3.UP, y)
	return follow_target.global_position + yaw_basis * shoulder_offset


func _set_global_rotation(rotation_quaternion: Quaternion) -> void:
	var next_transform := global_transform
	next_transform.basis = Basis(rotation_quaternion)
	global_transform = next_transform


func _clamp_pitch(value: float) -> float:
	var min_pitch := deg_to_rad(x_min_limit_angle)
	var max_pitch := deg_to_rad(x_max_limit_angle)
	return -clamp(-value, min_pitch, max_pitch)


func _smooth_weight(rate: float, delta: float) -> float:
	if rate <= 0.0:
		return 1.0
	return 1.0 - exp(-rate * delta)


func _can_rotate_with_mouse() -> bool:
	return Input.mouse_mode == Input.MOUSE_MODE_CAPTURED or mouse_right_press
