class_name DronePlatformConfig
extends RefCounted

const PLATFORM_QUAD := "quad"
const PLATFORM_HEXA := "hexa"
const PLATFORM_OCTO := "octo"

const _SLOT_PINS := ["D3", "D5", "D6", "D9", "D10", "D11", "A0", "A1"]

const _PLATFORM_DATA := {
	PLATFORM_QUAD: {
		"label": "Квадрокоптер",
		"default_frame": "Рама1",
		"frame_types": ["Рама1", "Рама2", "Рама3"],
		"frame_model_path": "",
		"frame_scale": Vector3(0.1, 0.1, 0.1),
		"board_attachment": Vector3(0.0, 0.30, 0.10),
		"propeller_attachment_offset": Vector3(0.0, 0.30, 0.0),
		"min_takeoff_motors": 2,
		"speed_multiplier": 1.00,
		"motor_slots": [
			{"label": "Передний", "position": Vector3(0.0, 0.48, -2.10)},
			{"label": "Правый", "position": Vector3(2.10, 0.48, 0.0)},
			{"label": "Задний", "position": Vector3(0.0, 0.48, 2.10)},
			{"label": "Левый", "position": Vector3(-2.10, 0.48, 0.0)}
		]
	},
	PLATFORM_HEXA: {
		"label": "Гексакоптер",
		"default_frame": "РамаГекса",
		"frame_types": ["РамаГекса"],
		"frame_model_path": "res://app/assembly/models/frame_hexa.obj",
		"frame_scale": Vector3.ONE,
		"board_attachment": Vector3(0.0, 0.06, 0.0),
		"propeller_attachment_offset": Vector3(0.0, 0.30, 0.0),
		"min_takeoff_motors": 3,
		"speed_multiplier": 1.15,
		"motor_slots": [
			{"label": "Правый", "position": Vector3(1.9260, 0.2240, 0.0)},
			{"label": "Передний правый", "position": Vector3(0.9607, 0.2240, -1.6687)},
			{"label": "Передний левый", "position": Vector3(-0.9607, 0.2240, -1.6687)},
			{"label": "Левый", "position": Vector3(-1.9260, 0.2240, 0.0)},
			{"label": "Задний левый", "position": Vector3(-0.9607, 0.2240, 1.6687)},
			{"label": "Задний правый", "position": Vector3(0.9607, 0.2240, 1.6687)}
		]
	},
	PLATFORM_OCTO: {
		"label": "Октокоптер",
		"default_frame": "РамаОкто",
		"frame_types": ["РамаОкто"],
		"frame_model_path": "res://app/assembly/models/frame_octo.obj",
		"frame_scale": Vector3.ONE,
		"board_attachment": Vector3(0.0, 0.58, 0.0),
		"propeller_attachment_offset": Vector3(0.0, 0.30, 0.0),
		"min_takeoff_motors": 3,
		"speed_multiplier": 1.30,
		"motor_slots": [
			{"label": "Правый", "position": Vector3(1.5360, 0.5550, 0.0)},
			{"label": "Передний правый", "position": Vector3(1.1080, 0.5550, -1.1080)},
			{"label": "Передний", "position": Vector3(0.0, 0.5550, -1.5360)},
			{"label": "Передний левый", "position": Vector3(-1.1080, 0.5550, -1.1080)},
			{"label": "Левый", "position": Vector3(-1.5360, 0.5550, 0.0)},
			{"label": "Задний левый", "position": Vector3(-1.1080, 0.5550, 1.1080)},
			{"label": "Задний", "position": Vector3(0.0, 0.5550, 1.5360)},
			{"label": "Задний правый", "position": Vector3(1.1080, 0.5550, 1.1080)}
		]
	}
}

static func normalize_platform_type(platform_type: String) -> String:
	var normalized: String = platform_type.strip_edges().to_lower()
	if _PLATFORM_DATA.has(normalized):
		return normalized
	return PLATFORM_QUAD

static func infer_platform_from_motor_count(motor_count: int) -> String:
	if motor_count >= 8:
		return PLATFORM_OCTO
	if motor_count >= 6:
		return PLATFORM_HEXA
	return PLATFORM_QUAD

static func get_platform_data(platform_type: String) -> Dictionary:
	var normalized: String = normalize_platform_type(platform_type)
	return (_PLATFORM_DATA.get(normalized, _PLATFORM_DATA[PLATFORM_QUAD]) as Dictionary).duplicate(true)

static func get_platform_label(platform_type: String) -> String:
	var data: Dictionary = get_platform_data(platform_type)
	return str(data.get("label", "Квадрокоптер"))

static func get_platform_ids() -> Array[String]:
	return [PLATFORM_QUAD, PLATFORM_HEXA, PLATFORM_OCTO]

static func get_default_frame_type(platform_type: String) -> String:
	var data: Dictionary = get_platform_data(platform_type)
	return str(data.get("default_frame", "Рама1"))

static func get_frame_types_for_platform(platform_type: String) -> Array[String]:
	var data: Dictionary = get_platform_data(platform_type)
	var result: Array[String] = []
	var frame_types_variant: Variant = data.get("frame_types", [])
	if typeof(frame_types_variant) == TYPE_ARRAY:
		for frame_variant in frame_types_variant:
			result.append(str(frame_variant))
	return result

static func get_platform_for_frame_type(frame_type: String) -> String:
	for platform_id in get_platform_ids():
		if frame_type in get_frame_types_for_platform(platform_id):
			return platform_id
	return PLATFORM_QUAD

static func get_slot_count(platform_type: String) -> int:
	return get_motor_slots(platform_type).size()

static func get_motor_slots(platform_type: String) -> Array[Dictionary]:
	var data: Dictionary = get_platform_data(platform_type)
	var result: Array[Dictionary] = []
	var slots_variant: Variant = data.get("motor_slots", [])
	if typeof(slots_variant) != TYPE_ARRAY:
		return result
	for slot_variant in slots_variant:
		if typeof(slot_variant) == TYPE_DICTIONARY:
			result.append((slot_variant as Dictionary).duplicate(true))
	return result

static func get_motor_slot_position(platform_type: String, slot: int) -> Vector3:
	var slots: Array[Dictionary] = get_motor_slots(platform_type)
	if slot >= 0 and slot < slots.size():
		return slots[slot].get("position", Vector3.ZERO)
	return Vector3.ZERO

static func get_board_attachment(platform_type: String) -> Vector3:
	var data: Dictionary = get_platform_data(platform_type)
	return data.get("board_attachment", Vector3.ZERO)

static func get_propeller_attachment_offset(platform_type: String) -> Vector3:
	var data: Dictionary = get_platform_data(platform_type)
	return data.get("propeller_attachment_offset", Vector3(0.0, 0.30, 0.0))

static func get_speed_multiplier(platform_type: String) -> float:
	var data: Dictionary = get_platform_data(platform_type)
	return float(data.get("speed_multiplier", 1.0))

static func get_min_takeoff_motors(platform_type: String) -> int:
	var data: Dictionary = get_platform_data(platform_type)
	return int(data.get("min_takeoff_motors", 2))

static func get_slot_label(platform_type: String, slot: int) -> String:
	var slots: Array[Dictionary] = get_motor_slots(platform_type)
	if slot >= 0 and slot < slots.size():
		return str(slots[slot].get("label", "Слот %d" % slot))
	return "Слот %d" % slot

static func get_slot_labels(platform_type: String) -> Array[String]:
	var result: Array[String] = []
	for slot_index in range(get_slot_count(platform_type)):
		result.append(get_slot_label(platform_type, slot_index))
	return result

static func get_recommended_motor_pins(platform_type: String) -> PackedStringArray:
	var slot_count: int = get_slot_count(platform_type)
	var pins := PackedStringArray()
	for index in range(slot_count):
		pins.append(_SLOT_PINS[index] if index < _SLOT_PINS.size() else "D%d" % (index + 2))
	return pins

static func get_frame_visual_settings(platform_type: String, component_variant: int) -> Dictionary:
	var normalized: String = normalize_platform_type(platform_type)
	if normalized == PLATFORM_QUAD:
		return {
			"path": "res://app/assembly/models/frame%d.obj" % component_variant,
			"scale": Vector3(0.1, 0.1, 0.1)
		}
	var data: Dictionary = get_platform_data(normalized)
	return {
		"path": str(data.get("frame_model_path", "")),
		"scale": data.get("frame_scale", Vector3.ONE)
	}
