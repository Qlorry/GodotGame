class_name UnitsContainer
extends Node2D

var groups: Array[BaseUnitGroup] = []
	
var current_group: BaseUnitGroup
var current_group_index: int = 0
var battle_in_progress = true

func _ready() -> void:
	for child in get_children():
		if child.get_child_count() > 0:
			groups.append(child)

func start_battle() -> void:
	current_group = groups[current_group_index]
	current_group.activate_group()

func get_active_units() -> Array[Unit]:
	var units: Array[Unit] = []
	
	for group in groups:
		units.append_array(group.get_active_units())
	
	return units

func process_attack(ac: ActionInstance, attacker: Unit):
	attacker.attack(ac)
	await attacker.attack_complete
	var children = []
	for group in groups:
		children.append_array(group.get_active_units())
	for cell in ac.path:
		for child: Unit in children:
			if child.cell != cell:
				continue
			if child != attacker:
				child.health -= 1

func group_done() -> void:
	if !battle_in_progress:
		print('Game over!')
		return
		
	var prev_group_index = current_group_index
	
	while true:
		current_group_index = wrapi(current_group_index + 1, 0, groups.size())
		current_group = groups[current_group_index]
		if current_group_index == prev_group_index:
			print('cycle')
			current_group = null
			break;
		if !current_group.get_active_units().is_empty():
			break;

	if current_group != null:
		current_group.activate_group()
	else:
		print('Game over!')
		EventBus.game_over.emit()
