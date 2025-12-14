extends Button
func _ready():
	$".".pressed.connect(_back_pressed)
func _back_pressed():
	get_tree().change_scene_to_file("main_scene.tscn")
