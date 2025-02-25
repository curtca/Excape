extends Control

signal on_debug_player_move(playernum, is_forward)

func ShowActivePlayers(actives):
	var numplayers = actives.size()
	for i in numplayers:
		var active_player = %Players.get_children()[i]
		active_player.visible = actives[i]

func _on_player_dir_pressed(playernum: int, is_forward: bool) -> void:
	on_debug_player_move.emit(playernum, is_forward)
