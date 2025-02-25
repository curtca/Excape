@tool
extends Control

signal dice_roll_complete(value)


var _dice_value: int = 100

@export var dice_value: int: # the value when dice are combined (10*first + second)
	get:
		return _dice_value

var shakes_remaining = 0

#sprite indecies:
# X12356: 6 1 2 [blank] 5 3 x [blank]
# X12347: x 1 2 [blank] 7 3 4 [blank]
var dicevalues = [[6, 1, 2, 5, 3, 0], [0, 1, 2, 7, 3, 4]] # just what values each die has -- order doesn't matter
var frames_lookup = [[6, 1, 2, 5, -1, 4, 0], [0, 1, 2, 5, 6, -1, -1, 4]] # for a given die value, what is the corresponding sprite frame 

func colorize(color: Color):
	for die in %DiceContainer.get_children():
		die.modulate = color

func roll():
	shakes_remaining = 20
	%Shaking.start()

func oneroll(): 
	var d0 = randi_range(0, 5)
	var d1 = randi_range(0, 5)
	var v0 = dicevalues[0][d0]
	var v1 = dicevalues[1][d1]
	var reversed = false
	update_sprite_frames(v0, v1)

	if v1 > v0:
		var v3 = v1
		v1 = v0
		v0 = v3
		reversed = true
	var result = 0
	if v0 == 0 and v1 == 0:
		result = 100
	else:
		result = 10 * v0 + v1
	
	var first_die = %d0 if reversed else %d1
	%DiceContainer.move_child(first_die, 0)
	%DiceContainer.queue_sort()
	_dice_value = result
		
func update_sprite_frames(d0, d1):
	%d0.get_children()[0].frame = frames_lookup[0][d0]
	%d1.get_children()[0].frame = frames_lookup[1][d1]

func _on_shaking_timeout() -> void:
	shakes_remaining -= 1
	oneroll()
	if shakes_remaining == 0:
		%Shaking.stop()
		dice_roll_complete.emit(dice_value)
	
