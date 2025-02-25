extends PanelContainer

signal start_game(array_of_booleans_for_which_players_are_active_this_game)

func _on_button_pressed() -> void:
	var any_checked = false
	var i = 0
	var colors = %PlayerColors.get_children()
	var enabled_players: Array[bool] = []
	enabled_players.resize(colors.size())
	
	for child in colors:
		var cb: CheckButton = child
		if cb.button_pressed:
			any_checked = true	
			enabled_players[i] = true
		i += 1
	
	if any_checked:
		start_game.emit(enabled_players)
