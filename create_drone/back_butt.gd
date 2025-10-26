extends Control
func _ready():
	$back_butt.pressed.connect(_back_pressed)
func _back_pressed():
	get_tree().change_scene_to_file("main_scene.tscn")
