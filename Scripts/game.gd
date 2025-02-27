extends Node2D

# This script manages the main game logic for the board game.

# Player data structure: {colornum, space, piece, dice, claimnum}
# 'dice' is the container object for the two dice (and also has the dice value)
# 'claimnum' is 0-5, or -1 if no active claim

class Player:
	var colornum: int
	var space: int
	var piece: Node2D
	var dice: Dice
	var claim: int = -1


enum GameState {
	PLAYING,
	GAME_OVER
}

var players: Array[Player] = []
var active_player_num: int = 0
var first_roll_this_player: bool = false
var game_state: GameState = GameState.PLAYING
var dx_active_player_pawns = 30

func _ready() -> void:
	prep_the_dice()
	new_game()


func new_game():
	players.clear()
	active_player_num = 0
	game_state = GameState.PLAYING
	$StartMenu.visible = true


func prep_the_dice():
	# Color the dice and register for dice roll complete signal

	var pieces = %PlayerPieces.get_children()
	var dice = %Dice.get_children()
	for i in 6:
		var image = pieces[i].texture.get_image()
		var texture_pos = pieces[i].texture.get_size() / 2
		var color = image.get_pixelv(texture_pos)
		dice[i].modulate = color
		dice[i].dice_roll_complete.connect(on_dice_roll_complete)


func move_dice(dice: Node, move_in: bool) -> void:
	var target_pos = %ActiveDice.position if move_in else %DeadDice.position
	var target_scale = Vector2.ONE * (.6 if move_in else .4)
	var tween = dice.create_tween()
	tween.tween_property(dice, "position", target_pos, 1)
	tween.tween_property(dice, "scale", target_scale, .3)
	await tween.finished


func on_dice_roll_complete(value):
	var ap = players[active_player_num]
	if value / 10 == value % 10:
		move_player(ap, value % 10)
		await wait(1)
	elif not first_roll_this_player:
		var moveback = 0
		if value % 10 == 0:
			moveback += 1
		if value == 100:
			moveback += 1
		if moveback > 0:
			var dice = ap.dice
			await wait(1)
			move_dice(dice, false)
			move_player(ap, -mini(moveback, ap.space))
			end_turn()
			return
	%RerollButton.visible = true
	show_available_select_buttons()


func show_available_select_buttons(hide_all = false):
	if game_state == GameState.GAME_OVER:
		hide_all = true
	var select_buttons = %SelectButtons.get_children()
	for i in select_buttons.size():
		select_buttons[i].visible = not hide_all
		for j in players.size():
			if players[j].claim == i:
				select_buttons[i].visible = false


func end_turn():
	%RerollButton.visible = false
	if game_state != GameState.GAME_OVER:
		go_player_n((active_player_num + 1) % players.size())


func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("Debug"):
		$DebugPane.visible = not $DebugPane.visible


func _on_start_menu_start_game(enabled_players: Array) -> void:
	$StartMenu.visible = false
	print(enabled_players)
	$DebugPane.ShowActivePlayers(enabled_players)

	for i in enabled_players.size():
		if enabled_players[i]:
			var player = Player.new()
			player.colornum = i
			player.space = 0
			player.piece = %PlayerPieces.get_children()[i]
			player.dice = %Dice.get_children()[i]
			players.append(player)
			player.piece.position = %Spaces.get_children()[0].position # position of feet

	players.shuffle()
	var numplayers = players.size()

	for i in numplayers:
		var piece_clone = %PlayerPieces.get_children()[players[i].colornum].duplicate()
		%ActivePlayers.add_child(piece_clone)
		piece_clone.position = Vector2.LEFT * dx_active_player_pawns * (numplayers / 2 - i)

	nudge_players_at(0)
	go_player_n(0)


func go_player_n(n):
	active_player_num = n
	var ap = players[n]
	
	# Skip players who have reached the end
	if ap.space == 21:
		end_turn()
		return
		
	first_roll_this_player = true
	var numplayers = players.size()

	# Popup the active player pawn in list of pawns at bottom
	for i in numplayers:
		var active_player = %ActivePlayers.get_children()[i]
		var tween: Tween = active_player.create_tween()
		tween.tween_property(active_player, "position", Vector2.LEFT * dx_active_player_pawns * (numplayers / 2 - i) + Vector2.UP * (20 if i == n else 0), 1.0)

	if ap.claim >= 0:
		move_player(ap, ap.claim)
		ap.claim = -1
		await wait(1)

	roll_active_players_dice()


func roll_active_players_dice():
	if game_state == GameState.GAME_OVER:
		return
	var dice = players[active_player_num].dice
	if players[active_player_num].dice.position != %ActiveDice.position:
		await move_dice(dice, true)

	dice.roll()


# Ensure no player pieces overlap at this space, and multiple pieces are reasonably spaced apart
func nudge_players_at(loc):
	var players_here = players.filter(func(p): return p.space == loc)
	var num_here = players_here.size()
	var player

	for i in num_here:
		player = players_here[i]
		var offset = Vector2.ZERO if num_here == 1 else Vector2.from_angle(PI / 6 + (2 * PI / num_here) * i) * 20
		offset += Vector2.UP * 25

		# Create a Tween node
		var tween: Tween = player.piece.create_tween()
		# Animate the position from the current position to the target position
		tween.tween_property(player.piece, "position", %Spaces.get_children()[loc].position + offset, 1) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)


func _on_debug_pane_player_move(colornum: int, is_forward: bool) -> void:
	for i in players.size():
		if players[i].colornum == colornum:
			move_player(players[i], 1 if is_forward else -1)


func winner(player):
	print("WINNER!!! Player ", player)
	game_state = GameState.GAME_OVER
	show_available_select_buttons()
	%RerollButton.visible = false
	%PlayAgain.visible = true
	%KeepPlaying.visible = true
	%Winner.visible = true
	var tween: Tween = %WinnerContainer.create_tween()
	tween.tween_property(%WinnerContainer, "scale", Vector2.ONE, .5).from(Vector2.ZERO)

	tween = player.piece.create_tween().set_loops(5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(player.piece, "scale", Vector2.ONE * 2, .5)
	tween.tween_property(player.piece, "scale", Vector2.ONE * 1, .5)


func move_player(player, spaces):
	var old_space = player.space
	var new_space = player.space + spaces
	if new_space < 0:
		player.space = 0
	elif new_space > 20:
		player.space = 21
		winner(player)
	else:
		player.space = new_space

	var tween = create_tween()
	tween.tween_property(player.piece, "scale", Vector2.ONE * 2, .5)
	tween.tween_property(player.piece, "scale", Vector2.ONE, .5)

	nudge_players_at(old_space)
	nudge_players_at(player.space)


func _on_reroll_button_pressed() -> void:
	first_roll_this_player = false
	%RerollButton.visible = false
	show_available_select_buttons(true)
	roll_active_players_dice()


func _on_claim_pressed(claim_num: int) -> void:
	var ap = players[active_player_num]
	ap.claim = claim_num
	show_available_select_buttons(true)
	%RerollButton.visible = false
	var tween = ap.dice.create_tween()
	tween.tween_property(ap.dice, "scale", Vector2.ONE * .4, .3).set_trans(Tween.TRANS_LINEAR)
	var hack_nudge = Vector2(25, 15)
	tween.tween_property(ap.dice, "position", %SelectButtons.get_children()[claim_num].position + hack_nudge, .7)
	await wait(1)
	await boot_weaker_claims(ap)
	end_turn()


func boot_weaker_claims(player):
	# Loop through all players once instead of nested loops
	for other_player in players:
		# Check if the other player has a higher claim number but lower or equal dice value
		if other_player.claim > player.claim and other_player.dice.dice_value <= player.dice.dice_value:
			other_player.claim = -1
			await move_dice(other_player.dice, false)


# Wait for a specified number of seconds
func wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _on_play_again_pressed() -> void:
	%PlayAgain.visible = false
	%KeepPlaying.visible = false
	%Winner.visible = false
	for child in %ActivePlayers.get_children():
		child.queue_free()
	for child in %Dice.get_children():
		child.position = %DeadDice.position
	for i in players.size():
		players[i].piece.position = %DeadDice.position
	new_game()


func _on_keep_playing_pressed() -> void:
	%PlayAgain.visible = false
	%KeepPlaying.visible = false
	%Winner.visible = false
	game_state = GameState.PLAYING
	await move_dice(players[active_player_num].dice, false)
	end_turn()
