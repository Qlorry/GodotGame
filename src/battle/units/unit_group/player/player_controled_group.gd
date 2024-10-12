class_name PlayerControlledGroup
extends BaseUnitGroup


func _unhandled_input(event: InputEvent) -> void:
	if !current_unit:
		return
	if event is InputEventMouseMotion:
		var cell = Navigation.world_to_cell(get_global_mouse_position())
		var match_ac = null
		for ac in current_acs:
			if cell == ac.end_point:
				match_ac = ac
				break
		if !current_unit.has_moved:
			EventBus.show_move_path.emit(match_ac)
			
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var cell = Navigation.world_to_cell(get_global_mouse_position())
		
		for ac in current_acs:
			if cell == ac.end_point:
				if current_unit.has_moved:
					current_unit.has_attacked = true
					await units_container.process_attack(ac, current_unit)
					#await _process_attack(ac)
				else:
					current_unit.move_along_path(ac.path + [ac.end_point])
					await current_unit.movement_complete
					current_unit.has_moved = true
				_step()
				return
				
	if event is InputEventKey and event.pressed and event.keycode == KEY_TAB:
		_next_unit()
		return
