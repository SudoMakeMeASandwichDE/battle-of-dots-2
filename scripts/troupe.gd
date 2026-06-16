extends CharacterBody2D

var waypoint: PackedScene = preload("res://scenes/waypoint.tscn")
var troupe_scene: PackedScene = preload("res://scenes/troupe.tscn")

@export var radius := 20.0 # circle texture radius
@export var color_unselected := Color(1, 0, 0, 1)
@export var color_selected := Color(0.8, 0.0, 0.0, 1.0)
var label: Label = null
var line: Line2D = null
var waypoints := [] # waypoind Vector2 coords
var selected := false # apply new waypoints if true
var target: Vector2 # next waypoint
var target_num := 0 # index of next target
var path_end := false # true when troupe reached last waypoint
var waypoint_objs := [] # collects waypoint game objects
var moving := false
var starting_pos: Vector2
var stacked_num := 1
var selected_num := 0

static var selected_troupe: Array[CharacterBody2D] = []

var color = color_unselected
func _draw():
	draw_circle(Vector2.ZERO, radius, color)

func _ready():
	queue_redraw()
	add_to_group("troupes")
	starting_pos = global_position
	relabel()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("waypoint_on_cursor"):
		# spawn waypoint on mouse click
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
		if self in selected_troupe and moving:
			var obj = waypoint.instantiate()
			waypoint_objs.append(obj)
			obj.global_position = get_global_mouse_position()
			print(obj.global_position)
			get_tree().get_current_scene().add_child(obj)
			waypoints.append(obj.global_position)
			continue_line()
		elif self in selected_troupe and selected_num < stacked_num:
			if waypoint_objs.size() == 0:
				var newtroupe = troupe_scene.instantiate()
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
	elif event.is_action_pressed("select"):
		var troupes = get_tree().get_nodes_in_group("troupes")
		for troupe in troupes:
			if troupe.moving:
				selected_troupe.erase(troupe)
				troupe.toggle_color()
		if global_position.distance_to(get_global_mouse_position()) <= 10: # select troupe with mouse click
			if moving:
				reset()
			if self not in selected_troupe:
				selected_troupe.append(self)
			if selected_num == 0:
				selected_num = 1
				relabel()
			elif selected_num < stacked_num:
				selected_num += 1
				relabel()
			toggle_color()
			get_viewport().set_input_as_handled()
			return
	elif event.is_action_pressed("cancel") and self in selected_troupe:
		reset()
			
func _process(delta: float) -> void:
	if waypoints:
		path_end = false
		if global_position.distance_to(waypoints[-1]) < 1.0: # when last waypoint is reached
			reset()
			var troupes = get_tree().get_nodes_in_group("troupes")
			for troupe in troupes:
				if global_position.distance_to(troupe.global_position) < 6 and troupe.moving == false and troupe != self:
					troupe.stacked_num += stacked_num
					troupe.relabel()
					queue_free()
					return
		if not path_end: # Move to next waypoint
			if target_num >= waypoints.size():
				moving = false
				return
			moving = true
			target = waypoints[target_num]
			if global_position.distance_to(waypoints[target_num]) < 1.0:
				target_num += 1
				line.remove_point(0)
			global_position = global_position.move_toward(target, 50*delta)
			if line:
				line.set_point_position(0, global_position)
func reset():
	# reset everything eg when last waypoint is reached
	path_end = true
	moving = false
	selected_num = 0
	waypoints.clear()
	print("Path ended")
	target_num = 0
	if self in selected_troupe:
		selected_troupe.erase(self)
		toggle_color()
	for obj in waypoint_objs:
		obj.queue_free()
	if line:
		line.queue_free()
	waypoint_objs.clear()
	starting_pos = global_position
	relabel()
	
func toggle_color():
	if self in selected_troupe:
		color = color_selected
	else:
		color = color_unselected
	queue_redraw()

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

func continue_line():
	if line:
		line.queue_free()
	line = Line2D.new()
	line.add_point(starting_pos)
	for point in waypoints:
		line.add_point(point)
	line.default_color = Color.DIM_GRAY
	line.width = 3
	get_tree().get_current_scene().add_child(line)
	var parent_node = line.get_parent()
	parent_node.move_child(line, 0)

		
