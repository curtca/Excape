extends Node2D


# indexed by 0-based turn order. 
# Player = {colornum, space, piece, dice, claimnum}
# dice is the container object for the two dice (and also has the dice value)
# claimnum is 0-5, or -1 if no active claim
var players = []
var active_player_num = 0
var first_roll_this_player = false
var game_over = false

var dx_active_player_pawns = 30

func _ready() -> void:
	prep_the_dice()
	new_game()

	
func new_game():	
	players = []
	active_player_num = 0
	game_over = false
	$StartMenu.visible = true


func prep_the_dice():
	#1: color the dice
	#2: Register for dice roll complete signal

	var pieces = %PlayerPieces.get_children()
	var dice = %Dice.get_children()
	for i in 6:
		var image = pieces[i].texture.get_image()
		var texture_pos = pieces[i].texture.get_size() / 2
		var color = image.get_pixelv(texture_pos)
		dice[i]. modulate = color
		dice[i].dice_roll_complete.connect(on_dice_roll_complete)


func on_dice_roll_complete(value):
	var ap = players[active_player_num]
	if value / 10 == value % 10:
		move_player(ap, value % 10)
		await wait (1)
	elif not first_roll_this_player:
		var moveback = 0;
		if value % 10 == 0:
			moveback += 1
		if value == 100:
			moveback += 1
		if moveback > 0:
			move_player(ap, -mini(moveback, ap.space))
			var dice = ap.dice
			var tween: Tween = create_tween()
			tween.tween_property(dice, "scale", Vector2.ONE * .4, 1).set_delay(2)
			tween.tween_property(dice, "position", %DeadDice.position, 1)
			await wait(3)
			end_turn()
			return
	%RerollButton.visible = true
	show_available_select_buttons()


func show_available_select_buttons(hide_all = false):
	if game_over:
		hide_all = true
	var select_buttons = %SelectButtons.get_children()
	for i in select_buttons.size():
		select_buttons[i].visible = not hide_all
		for j in players.size():
			if players[j].claim == i:
				select_buttons[i].visible = false
	
	
func end_turn():
	%RerollButton.visible = false
	if not game_over:
		go_player_n((active_player_num + 1) % players.size())
	
	
func _process(delta: float) -> void:
	if Input.is_action_just_pressed("Debug"):
		$DebugPane.visible = not $DebugPane.visible


func _on_start_menu_start_game(enabled_players) -> void:
	$StartMenu.visible = false
	print(enabled_players)
	$DebugPane.ShowActivePlayers(enabled_players)
	
	for i in enabled_players.size():
		if enabled_players[i]:
			var player = {"colornum": i, "space": 0, "piece": %PlayerPieces.get_children()[i], "dice": %Dice.get_children()[i], "claim": -1}
			players.append(player)
			player.piece.position = %Spaces.get_children()[0].position #position of feet
			
	players.shuffle()
	var numplayers = players.size()
	
	for i in numplayers:
		var piece_clone = %PlayerPieces.get_children()[players[i]["colornum"]].duplicate()
		%ActivePlayers.add_child(piece_clone)
		piece_clone.position = Vector2.LEFT * dx_active_player_pawns * (numplayers / 2 - i)
		
	nudge_players_at(0)
	go_player_n(0)
	
	
func go_player_n(n):
	active_player_num = n
	var ap = players[n]
	first_roll_this_player = true
	var numplayers = players.size()
	
	# Popup the active player p[awn in list of pawns at bottom
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
	if game_over:
		return
	var dice = players[active_player_num].dice
	if players[active_player_num].dice.position != %ActiveDice.position:
		var tween: Tween = dice.create_tween()
		tween.tween_property(dice, "position", %ActiveDice.position, 1)
		tween.tween_property(dice, "scale", Vector2.ONE * .6, .3)
		await tween.finished
	dice.roll()
	
	
# Make it so that no player pieces are overlapping at this space, and that multiple pieces here are reasonable spaced apart
func nudge_players_at(loc):
	var players_here = players.filter(func(player): return player["space"] == loc)
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
	game_over = true
	show_available_select_buttons()
	%RerollButton.visible = false
	%PlayAgain.visible = true
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
	await wait (1)
	await boot_weaker_claims(ap)
	end_turn()


func boot_weaker_claims(player):
	var select_buttons = %SelectButtons.get_children()
	for i in range(player.claim, select_buttons.size()):
		for j in players.size():
			if players[j].claim > player.claim and players[j].dice.dice_value <= player.dice.dice_value:
				players[j].claim = -1
				var tween = players[j].dice.create_tween()
				tween.tween_property(players[j].dice, "position", %DeadDice.position, 1)
				await wait(.5)
	
	
# Not sure if this actually works...
func wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _on_play_again_pressed() -> void:
	%PlayAgain.visible = false
	%Winner.visible = false
	for child in %ActivePlayers.get_children():
		child.queue_free()
	for child in %Dice.get_children():
		child.position = $"%DeadDice".position
	for i in players.size():
		players[i].piece.position = %DeadDice.position
	new_game()


func pulse_scale(node: Node2D, scale: float):
	var tween = create_tween().set_loops()  # Create a looping tween
	tween.tween_property(
		node,               # Target node
		"scale",            # Property to animate
		Vector2(scale, scale),  # Target scale (1.5x size)
		0.5                 # Duration of scaling up (0.5 seconds)
	).set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(
		node,               # Target node
		"scale",            # Property to animate
		Vector2(1, 1),      # Target scale (original size)
		0.5                 # Duration of scaling down (0.5 seconds)
	).set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN_OUT)
