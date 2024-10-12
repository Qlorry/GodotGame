class_name BaseUnitGroup
extends Node2D

@onready var units_container: UnitsContainer = %units

var current_unit_index: int = 0
var current_unit: Unit
var current_acs: Array

func activate_group():
	var next_unit = _get_next_unacted_unit()
	if next_unit == null:
		_finish_turn()
		return
	current_unit = next_unit[0]
	current_unit_index = next_unit[1]
	_start_turn()
	
func get_active_units() -> Array[Unit]:
	var units: Array[Unit] = []

	for child: Unit in get_children():
		if child.alive:
			units.append(child)
	return units
	
func _get_next_unacted_unit():
	var next_index = current_unit_index
	var next_unit: Unit
	
	while true:
		next_index = wrapi(next_index + 1, 0, get_child_count())
		next_unit = get_child(next_index)
		if (next_unit.has_moved && next_unit.has_attacked) || !next_unit.alive:
			if current_unit_index == next_index:
				return null
			next_unit = null
			continue

		return [next_unit, next_index]

func _start_turn():
	_update_paths()

func _finish_turn():
	for unit: Unit in get_children():
		unit.finish_turn()
	current_unit = null
	current_unit_index = 0
	units_container.group_done()

func _next_unit():
	var next_unit = _get_next_unacted_unit()
	if next_unit == null:
		_finish_turn()
		return
	current_unit = next_unit[0]
	current_unit_index = next_unit[1]
	_update_paths()
	
func _step():
	if current_unit.has_attacked and current_unit.has_moved:
		_next_unit()
	else:
		_update_paths()

func _update_paths() -> void:
	EventBus.show_move_path.emit(null)
	if current_unit.has_moved:
		current_acs = current_unit.get_attack_paths()
		EventBus.show_attack_acs.emit(current_acs)
		EventBus.show_move_acs.emit([])
		return
	
	current_acs = current_unit.get_move_paths()
	EventBus.show_move_acs.emit(current_acs)
	EventBus.show_attack_acs.emit([])
