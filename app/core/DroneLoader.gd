# DroneLoader.gd
extends Node

func load_drone() -> Node3D:
	var file = FileAccess.open("user://saved_drone.json", FileAccess.READ)
	if not file:
		print("❌ Файл saved_drone.json не найден")
		return create_default_drone()
	
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var error = json.parse(json_string)
	if error != OK:
		print("❌ Ошибка парсинга JSON: ", json.get_error_message())
		return create_default_drone()
	
	var drone_data = json.data
	return create_drone_from_data(drone_data)

func create_drone_from_data(data: Dictionary) -> Node3D:
	var drone = CharacterBody3D.new()
	drone.name = "Drone"
	
	# Загружаем компоненты из данных
	if data.has("components"):
		for comp_data in data["components"]:
			var component = create_component(comp_data)
			if component:
				drone.add_child(component)
				# Позиционируем компонент
				if comp_data.has("position"):
					component.position = Vector3(
						comp_data["position"]["x"],
						comp_data["position"]["y"],
						comp_data["position"]["z"]
					)
	
	# Коллизия для дрона
	var collision = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = Vector3(6, 1.5, 6)
	collision.shape = shape
	collision.position = Vector3(0, 0.75, 0)
	drone.add_child(collision)
	
	# Скрипт
	drone.script = load("res://app/flight/Drone.gd")
	
	return drone

func create_component(data: Dictionary) -> Node3D:
	var component = Node3D.new()
	
	# Создаем скрипт компонента
	var script = load("res://app/assembly/component.gd")
	component.set_script(script)
	
	# Устанавливаем свойства
	if data.has("type"):
		component.component_type = data["type"]
	if data.has("variant"):
		component.component_variant = data["variant"]
	if data.has("name"):
		component.component_name = data["name"]
	
	# Вызываем _ready для инициализации
	component.call("_ready")
	
	return component

func create_default_drone() -> Node3D:
	# Создаем дрон с 4 моторами и 4 пропеллерами по умолчанию
	var drone = CharacterBody3D.new()
	drone.name = "DefaultDrone"
	
	# Здесь можно создать полный дрон по умолчанию
	# или использовать существующую функцию create_default_character_drone()
	
	return drone
