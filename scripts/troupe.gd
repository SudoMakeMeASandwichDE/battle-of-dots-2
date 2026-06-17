extends CharacterBody2D

var waypoint: PackedScene = preload("res://scenes/waypoint.tscn")
var troupe_scene: PackedScene = preload("res://scenes/troupe.tscn")

@export var radius := 20.0 # circle texture radius
var color_unselected : Color
var color_selected : Color
var label: Label = null
var line: Line2D = null
var waypoints := [] # waypoint Vector2 coords
var selected := false # apply new waypoints if true
var target: Vector2 # next waypoint
var target_num := 0 # index of next target
var path_end := false # true when troupe reached last waypoint
var waypoint_objs := [] # collects waypoint game objects
var moving := false
var stacked_num := 1 # quantity of troupes in stack
var selected_num := 0 # quantity of selected troups of stack

# dict team -> color with lists for colors, with first (index 0) color for unselected troupes and second (index 1) color for selected troupes
@export var team_colors := {"red": [Color(1, 0, 0, 1), Color(0.8, 0.0, 0.0, 1.0)], "green": [Color(0, 1, 0, 1), Color(0, 0.8, 0, 1)]}
@export var team := "green"

static var selected_troupe: Array[CharacterBody2D] = []

var color: Color
func _draw():
	draw_circle(Vector2.ZERO, radius, color)

func _ready():
	# color assignment
	color_unselected = team_colors[team][0]
	color_selected = team_colors[team][1]
	if self in selected_troupe:
		color = color_selected
	else:
		color = color_unselected
	queue_redraw()
	add_to_group("troupes")
	relabel()

func _unhandled_input(event: InputEvent) -> void:
	# spawn waypoint on mouse click
	if event.is_action_pressed("waypoint_on_cursor"):

		# new waypoint for whole stack
		if self in selected_troupe and selected_num == stacked_num:
			var obj = waypoint.instantiate()
			waypoint_objs.append(obj)
			obj.global_position = get_global_mouse_position()
			print(obj.global_position)
			get_tree().get_current_scene().add_child(obj)
			waypoints.append(obj.global_position)
			selected_num = 0
			relabel()
			continue_line()

		# set new waypoint while moving
		if self in selected_troupe and moving:
			var obj = waypoint.instantiate()
			waypoint_objs.append(obj)
			obj.global_position = get_global_mouse_position()
			print(obj.global_position)
			get_tree().get_current_scene().add_child(obj)
			waypoints.append(obj.global_position)
			continue_line()

		# send part of troupe stack (spawns new troupe stack)
		elif self in selected_troupe and selected_num < stacked_num:
			if waypoint_objs.size() == 0:
				var newtroupe = troupe_scene.instantiate()
				newtroupe.team = team
				newtroupe.stacked_num = selected_num
				newtroupe.global_position = global_position
				selected_troupe.append(newtroupe)
				var obj = waypoint.instantiate()
				newtroupe.waypoint_objs.append(obj)
				obj.global_position = get_global_mouse_position()
				print(obj.global_position)
				get_tree().get_current_scene().add_child(obj)
				newtroupe.waypoints.append(obj.global_position)
				get_tree().get_current_scene().add_child(newtroupe)
				newtroupe.relabel()
				newtroupe.continue_line()
				stacked_num = stacked_num - selected_num
				reset()

	# select troupe with mouse click
	elif event.is_action_pressed("select"):
		var troupes = get_tree().get_nodes_in_group("troupes")
		for troupe in troupes:
			if troupe.moving:
				selected_troupe.erase(troupe)
				troupe.toggle_color()
		if global_position.distance_to(get_global_mouse_position()) <= 10:
			if moving:
				reset() # stop moving troupe if clicked on
			if self not in selected_troupe:
				selected_troupe.append(self)
			if selected_num == 0:
				selected_num = 1
				relabel()
			elif selected_num < stacked_num:
				selected_num += 1
				relabel()
			toggle_color()
			get_viewport().set_input_as_handled() # important so that only one troupe will be selected with one click
			return
			
	# stop selected troupe and deselect all troupes
	elif event.is_action_pressed("cancel") and self in selected_troupe:
		reset()
			
func _process(delta: float) -> void:
	if waypoints:
		path_end = false
		# when last waypoint is reached
		if global_position.distance_to(waypoints[-1]) < 1.0:
			reset()
			var troupes = get_tree().get_nodes_in_group("troupes")
			# stack troupes that land on same spot
			for troupe in troupes:
				if global_position.distance_to(troupe.global_position) < 6 and troupe.moving == false and troupe != self and troupe.team == self.team:
					troupe.stacked_num += stacked_num
					troupe.relabel()
					queue_free()
					return

		# Move to next waypoint
		if not path_end:
			if target_num >= waypoints.size():
				moving = false
				return
			moving = true
			target = waypoints[target_num]
			# when a waypoint is reached
			if global_position.distance_to(waypoints[target_num]) < 1.0:
				if waypoint_objs.size() > 1:
					waypoint_objs[0].queue_free()
					waypoint_objs.erase(waypoint_objs[0])
				target_num += 1
				line.remove_point(0)
			global_position = global_position.move_toward(target, 50*delta)
			if line:
				line.set_point_position(0, global_position)

# reset everything eg when last waypoint is reached
func reset():
	path_end = true
	moving = false
	selected_num = 0
	waypoints.clear()
	print("Path ended")
	target_num = 0
	if self in selected_troupe:
		selected_troupe.erase(self)
		toggle_color()
	if waypoint_objs:
		for obj in waypoint_objs:
			obj.queue_free()
	if line:
		line.queue_free()
	waypoint_objs.clear()
	relabel()

# update color for current state selected or unselected
func toggle_color():
	if self in selected_troupe:
		color = color_selected
	else:
		color = color_unselected
	queue_redraw()

# update number (for stack size and selected quantity of stack)
func relabel():
	if label:
		label.queue_free()
	if stacked_num > 1:
		label = Label.new()
		if selected_num > 0:
			label.text = str(selected_num) + "/" + str(stacked_num)
		else:
			label.text = str(stacked_num)
		add_child(label)

# update troupe path line
func continue_line():
	if line:
		line.queue_free()
	line = Line2D.new()
	line.add_point(global_position)
	for point in waypoint_objs:
		line.add_point(point.global_position)
	line.default_color = Color.DIM_GRAY
	line.width = 3
	get_tree().get_current_scene().add_child(line)
	var parent_node = line.get_parent()
	parent_node.move_child(line, 0)
	
