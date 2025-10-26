extends Control
@export var score_label: Label  # Перетащите ноду в инспекторе

func _ready():
	$HBoxContainer/back_butt.pressed.connect(_on_back_pressed)
	if score_label:
		update_score_display()
	else:
		print("Перетащите Label в инспектор!")
func _on_back_pressed():
	get_tree().change_scene_to_file("main_scene.tscn")
func update_score_display():
	score_label.text = "Счет: " + str(Global.score)
