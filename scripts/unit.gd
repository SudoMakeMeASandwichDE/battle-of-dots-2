extends CharacterBody2D

var waypoint: PackedScene = preload("res://scenes/waypoint.tscn")
var unit_scene: PackedScene = preload("res://scenes/unit.tscn")

@export var radius := 20.0 # circle texture radius
var color_unselected : Color
var color_selected : Color
var label: Label = null # label object for stack quantity
var line: Line2D = null # unit path
var waypoints := [] # waypoint Vector2 coords
var selected := false # apply new waypoints if true
var target: Vector2 # next waypoint
var target_num := 0 # index of next target
var path_end := false # true when unit reached last waypoint
var waypoint_objs := [] # collects waypoint game objects
var moving := false
var stacked_num := 1 # quantity of units in stack
var selected_num := 0 # quantity of selected troups of stack

var speed := 70

var health := 100

# dict team -> color with lists for colors, with first (index 0) color for unselected units and second (index 1) color for selected units
@export var team_colors := {"red": [Color(1, 0, 0, 1), Color(0.8, 0.0, 0.0, 1.0)], "green": [Color(0, 1, 0, 1), Color(0, 0.8, 0, 1)]}
@export var team := "green"
var bot := true


static var selected_unit: Array[CharacterBody2D] = []
static var latest_selected: CharacterBody2D

var color: Color
func _draw():
	draw_circle(Vector2.ZERO, radius, color)
	if health < 100:
		draw_rect(Rect2(-10, -30, health/2, 5), Color.GREEN)

func _ready():
	# color assignment
	color_unselected = team_colors[team][0]
	color_selected = team_colors[team][1]
	if self in selected_unit:
		color = color_selected
	else:
		color = color_unselected
	queue_redraw()
	add_to_group("units")
	if bot:
		var parent = get_parent()
		parent.move_child(self, 0)
	relabel()

func _unhandled_input(event: InputEvent) -> void:
	if !bot:
		# spawn waypoint on mouse click
		if event.is_action_pressed("waypoint_on_cursor"):
			spawn_waypoint()

		# select unit with mouse click
		elif event.is_action_pressed("select"):
			select()

		# stop selected unit and deselect all units
		elif event.is_action_pressed("cancel") and self in selected_unit:
			reset()

		# select whole stack
		elif event.is_action_pressed("select_all") and latest_selected == self and !moving and self in selected_unit:
			selected_num = stacked_num
			relabel()

		elif event.is_action_pressed("half") and latest_selected == self and !moving and self in selected_unit:
			if stacked_num > 1:
				selected_num = ceil(stacked_num/2)
				relabel()

#		elif event.is_action_pressed("remove_last_waypoint") and selected and moving: # (doesn't work for some reason)
#			waypoint_objs[-1].queue_free()
#			waypoint_objs.erase(waypoint_objs[-1])
#			continue_line()
#			print("backspace")

func _process(delta: float) -> void:
	if waypoints:
		path_end = false
		# when last waypoint is reached
		if global_position.distance_to(waypoints[-1]) < 1.0:
			reset()
			var units = get_tree().get_nodes_in_group("units")
			# stack units that land on same spot
			for unit in units:
				if global_position.distance_to(unit.global_position) < 6 and unit.moving == false and unit != self and unit.team == self.team:
					var parent = unit.get_parent()
					parent.move_child(unit, parent.get_child_count()-1)
					unit.stacked_num += stacked_num
					unit.relabel()
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
			global_position = global_position.move_toward(target, speed*delta)
			if line:
				line.set_point_position(0, global_position)

func spawn_waypoint():
			# new waypoint for whole stack
			if self in selected_unit and selected_num == stacked_num:
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
			if self in selected_unit and moving:
				var obj = waypoint.instantiate()
				waypoint_objs.append(obj)
				obj.global_position = get_global_mouse_position()
				print(obj.global_position)
				get_tree().get_current_scene().add_child(obj)
				waypoints.append(obj.global_position)
				continue_line()

			# send part of unit stack (spawns new unit stack)
			elif self in selected_unit and selected_num < stacked_num and selected_num != 0:
				if waypoint_objs.size() == 0:
					var newunit = unit_scene.instantiate()
					newunit.team = team
					newunit.stacked_num = selected_num
					newunit.global_position = global_position
					newunit.bot = false
					selected_unit.append(newunit)
					var obj = waypoint.instantiate()
					newunit.waypoint_objs.append(obj)
					obj.global_position = get_global_mouse_position()
					print(obj.global_position)
					get_tree().get_current_scene().add_child(obj)
					newunit.waypoints.append(obj.global_position)
					get_tree().get_current_scene().add_child(newunit)
					var parent = newunit.get_parent()
					parent.move_child(newunit, 0)
					newunit.relabel()
					newunit.continue_line()
					stacked_num = stacked_num - selected_num
					reset()

func select():
			var units = get_tree().get_nodes_in_group("units")
			for unit in units:
				if unit.moving:
					selected_unit.erase(unit)
					unit.toggle_color()
			if global_position.distance_to(get_global_mouse_position()) <= 10:
				if moving:
					reset() # stop moving unit if clicked on
				if self not in selected_unit:
					selected_unit.append(self)
				if selected_num == 0:
					selected_num = 1
					relabel()
				elif selected_num < stacked_num:
					selected_num += 1
					relabel()
				toggle_color()
				latest_selected = self
				get_viewport().set_input_as_handled() # important so that only one unit will be selected with one click
				return

# reset everything eg when last waypoint is reached
func reset():
	path_end = true
	moving = false
	selected_num = 0
	waypoints.clear()
	print("Path ended")
	target_num = 0
	if self in selected_unit:
		selected_unit.erase(self)
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
	if self in selected_unit:
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

# update unit path line
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

func health_bar():
	pass

func damage_or_heal(amount: int):
	if health + amount >= 100:
		health = 100
		queue_redraw()

	elif health + amount <= 0:
		kill()

	else:
		health = health + amount
		queue_redraw()


func kill():
	reset()
	queue_free()
