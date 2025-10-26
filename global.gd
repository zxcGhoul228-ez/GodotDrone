# global.gd
extends Node
var purchased_items = []
var score = 100
static var current_level = 1
static var drone_data = {}

func has_item(item_name):
	return item_name in purchased_items

func get_purchased_items():
	return purchased_items.duplicate() 
# Добавьте другие глобальные переменные по необходимости
