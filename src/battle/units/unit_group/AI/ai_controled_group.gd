class_name AIControlledGroup
extends BaseUnitGroup

func _start_turn():
	while _next_unit():
		await _handle_unit()

func _has_movement_to_this_loc(point: Vector2):
	var current = current_unit.cell
	var potential_positions = current_unit.get_move_paths().map(func (tr): return tr + current)
	var is_occupied = false
	for potential_position in potential_positions:
		if point.distance_to(potential_position) < 0.1:
			return true
	return false


func _is_valid_move_loc(pos: Vector2, enemy_positions: Array):
	if !Navigation.grid.region.has_point(pos) || Navigation.grid.is_point_solid(pos):
		return false
	var is_occupied = false
	for en_cell in enemy_positions:
		if pos.distance_to(en_cell) < 0.1:
			return false
	return true
			
func _handle_unit():
	_update_paths()
	var my_current_pos = current_unit.cell
	
	# find closest unit
	var enemies = units_container.get_enemy_units(self)
	enemies.sort_custom(func(a:Unit,b:Unit): return a.cell.distance_to(my_current_pos) < b.cell.distance_to(my_current_pos))
	var enemy_pos = enemies.map(func(a:Unit): return a.cell)
	
	# if we can not hit them -> move to first, hit any cell
	var final_strategy = null

	for e in enemies:		
		final_strategy = _calc_along_path_strat(e.cell, enemy_pos)
		if final_strategy != null:
			break

	if final_strategy == null:
		final_strategy = _get_default_move(enemies[0].cell)
	
	if final_strategy[0] != null:
		current_unit.move_along_path(final_strategy[0].path)
		await current_unit.movement_complete
	current_unit.has_moved = true
	
	_update_paths()

	await units_container.process_attack(final_strategy[1], current_unit)
	current_unit.has_attacked = true

# follow path in move strat and check if we can reach unit
func _calc_along_path_strat(selected_enemy_pos: Vector2, enemy_positions: Array):
	var current_pos = current_unit.cell
	var move_options = current_unit.get_move_paths()
	var attack_options = current_unit.get_attack_paths_raw()
	
	for move_option in move_options:
		var path = []
		for move_tr in move_option.path:
			path.append(move_tr)
			var next_pos = move_tr
			if !_is_valid_move_loc(next_pos, enemy_positions):
				continue
			
			for attack_option in attack_options:
				var attack_path = []
				for attack_transform in attack_option.path:
					attack_path.append(attack_transform)
					# may hit the wall
					if selected_enemy_pos != next_pos + attack_transform:
						continue
						
					var attack_instance = ActionInstance.new(attack_option, current_unit)
					attack_instance.path = attack_option.path.map(
						func (cell):
							return cell + next_pos
					)
					attack_instance.end_point = attack_path.back() + next_pos
					
					var move_instance: ActionInstance = ActionInstance.new(move_option.definition, current_unit)
					move_instance.path = path
					move_instance.end_point = path.back()
					
					return [move_instance, attack_instance]
					
	return null

func _get_default_move(selected_enemy_pos: Vector2):
	var current_pos = current_unit.cell
	var move_options = current_unit.get_move_paths()
	var attack_options = current_unit.get_attack_paths_raw()
	
	var closest_move_option: ActionInstance = null
	var smallest_dist = 1000000
	
	for move_option in move_options:
		var path = []
		for move_tr in move_option.path:
			path.append(move_tr)
			var navigation = Navigation.grid.get_point_path(move_tr, selected_enemy_pos)
			if smallest_dist > navigation.size():
				smallest_dist = navigation.size()
				closest_move_option = ActionInstance.new(move_option.definition, current_unit)
				closest_move_option.path = path
				closest_move_option.end_point = path.back()
	
	var comrades: Array[Unit] = get_active_units()
	comrades.erase(current_unit)
	
	for attack_option in attack_options:
		var hits_comrade = false
		for attack_transform in attack_option.path:
			for c in comrades:
				if c.cell == attack_transform + closest_move_option.end_point:
					hits_comrade = true;
					break;
		if !hits_comrade: 
			var attack_instance = ActionInstance.new(attack_option, current_unit)
			attack_instance.path = attack_option.path.map(
				func (cell):
					return cell + closest_move_option.end_point
			)
			attack_instance.end_point = attack_option.end_point + closest_move_option.end_point
			return [closest_move_option, attack_instance]
	var attack_instance = ActionInstance.new(attack_options[0], current_unit)
	attack_instance.path = attack_options[0].path.map(
		func (cell):
			return cell + closest_move_option.end_point
	)
	attack_instance.end_point = attack_options[0].end_point + closest_move_option.end_point
	return [closest_move_option, attack_instance]






# if we are close up to the enemy we must move somewhere -> check if we can hit it with any move position
func _calculate_close_up_attack(selected_enemy_pos: Vector2, enemy_positions: Array[Vector2]):
	var move_transforms = current_unit.get_move_paths()
	var attack_transforms = current_unit.get_attack_paths()
	
	var current_pos = current_unit.cell
	for move_tr in move_transforms:
		var next_pos = current_pos + move_tr.end_point
		if !_is_valid_move_loc(next_pos, enemy_positions):
			continue
		
		for attack_tr in attack_transforms:
			if selected_enemy_pos == next_pos + attack_tr.end_point:
				return [move_tr, attack_tr]
				
	return null
	
# if we are far from enemy -> use path from AStar +- 1 cell in all directions to check if we can hit enemy from it 
# Naive impl
func _calculate_path_attack(selected_enemy_pos: Vector2, enemy_positions: Array[Vector2]):
	var attack_transforms = current_unit.get_attack_paths()
	var move_transforms = current_unit.get_move_paths()

	const additional_move_transforms = [
		Vector2(0, 0), # main
		Vector2(-1, -1), Vector2(-1, 0), Vector2(0, -1), 
		Vector2(1, 1), Vector2(1, 0), Vector2(0, 1)
	]
	var current_pos = current_unit.cell
	var path = Navigation.grid.get_point_path(current_pos, selected_enemy_pos)
		
	for step in path:
		for tr in additional_move_transforms:
			var next_pos = step + tr
			if !_has_movement_to_this_loc(next_pos):
				continue
			if !_is_valid_move_loc(next_pos, enemy_positions):
				continue
			
			for attack_tr in attack_transforms:
				if selected_enemy_pos == next_pos + attack_tr:
					return [next_pos - current_pos, attack_tr]
	
	return null
