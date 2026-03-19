extends MeshInstance3D

var rotation_speed = 360.0

func _process(delta):
	rotate_y(deg_to_rad(rotation_speed * delta))

func set_rotation_speed(speed: float):
	rotation_speed = speed
