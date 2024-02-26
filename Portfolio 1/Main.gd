extends Node2D

var Room = preload("res://room.tscn")
@onready var map = $TileMap

var tile_size = 32
var num_rooms = 25
var min_size = 4
var max_size = 10
var hspread = 400
var cull = 0.3

var path #pathfinder

func _ready():
	randomize()
	make_room()
	
func make_room():
	for i in range(num_rooms):
		var pos = Vector2(randf_range(-hspread, hspread), 0)
		var r = Room.instantiate() 
		var w =  min_size + randi() % (max_size - min_size)
		var h = min_size + randi() % (max_size - min_size)
		r.make_room(pos, Vector2(w, h) * tile_size)
		$Rooms.add_child(r)
		
	#wait for rooms
	$"Room Timer".start()
	await($"Room Timer".timeout)
	
	var room_position = []
	
	for room in $Rooms.get_children():
		if randf() < cull:
			room.queue_free()
		else:
			room.freeze = true
			room_position.append(Vector2(room.position.x, room.position.y))
	$"Path Timer".start()
	$"Path Timer".timeout
	path = find_mst(room_position)

func _draw():
	for room in $Rooms.get_children():
		draw_rect(Rect2(room.position - room.size, room.size * 2),
			Color(32, 288, 0), false)
			
	if path:
		for p in path.get_point_ids():
			for c in path.get_point_connections(p):
				var pp = path.get_point_position(p)
				var cp = path.get_point_position(c)
				draw_line(pp, cp, Color(1, 1, 0), 15) 
			
func _process(delta):
	queue_redraw()
	
func _input(event):
	if event.is_action_pressed("ui_select"):
		for n in $Rooms.get_children():
			n.queue_free()
		path = null
		make_room()
	if event.is_action_pressed('ui_focus_next'):
		make_map()

func find_mst(nodes):
	var path = AStar2D.new()
	path.add_point(path.get_available_point_id(), nodes.pop_front())
	
	#repeat till no nodes remain
	while nodes:
		var min_dist = INF #minimum distance so far (infinity)
		var min_p = null # position of that node
		var p = null #current position
		#loop through points in path
		for p1 in path.get_point_ids():
			var p_temp = p1
			p_temp = path.get_point_position(p_temp)
			#all other points loop
			for p2 in nodes:
				if p_temp.distance_to(p2) < min_dist: #see if the next node is smaller than the minimum distance
					min_dist = p_temp.distance_to(p2)
					min_p = p2
					p = p_temp
		var n = path.get_available_point_id() #next node
		path.add_point(n, min_p)
		path.connect_points(path.get_closest_point(p), n)
		nodes.erase(min_p)
	return path

func make_map():
	map.clear()
	
	var rec = Rect2()
	for room in $Rooms.get_children():
		var r = Rect2(room.position-room.size, room.get_node("CollisionShape2D").shape.extents*2)
		rec = rec.merge(r)
	var topleft = map.local_to_map(rec.position)
	var bottomr = map.local_to_map(rec.end)
	for x in range(topleft.x, bottomr.x):
		for y in range(topleft.y, bottomr.y):
			map.set_cell(0, Vector2i(x, y), 1, Vector2i(0,0), 0)
	
	var corridor = [] #one corridor per connection
	for room in $Rooms.get_children():
		var s = (room.size / tile_size).floor()
		var pos = map.local_to_map(room.position)
		var ul = (room.position / tile_size).floor() - s
		for x in range(2, s.x * 2 - 1):
			for y in range(2, s.y * 2 - 1):
				map.set_cell(0, Vector2i(ul.x + x, ul.y + y), 0, Vector2i(0, 0), 0)
		#carve connection
		var p = path.get_closest_point(room.position)
		
		for conn in path.get_point_connections(p):
			if not conn in corridor:
				var start = map.local_to_map(Vector2(path.get_point_position(p).x, path.get_point_position(p).y))
				var end = map.local_to_map(Vector2(path.get_point_position(conn).x, path.get_point_position(conn).y))
				
				carve_path(start, end)
		corridor.append(p)
		
func carve_path(p1, p2):
	var x_diff = sign(p2.x - p1.x)
	var y_diff = sign(p2.y - p1.y)
	
	if x_diff == 0: x_diff = pow(-1.0, randi() % 2)
	if y_diff == 0: y_diff = pow(-1.0, randi() % 2)
	
	var x_y = p1
	var y_x = p2
	if(randi() % 2) > 0:
		x_y = p2
		y_x = p2
		
	for x in range(p1.x, p2.x, x_diff):
		map.set_cell(0, Vector2i(x, x_y.y), 0, Vector2i(0, 0), 0);
		map.set_cell(0, Vector2i(x, x_y.y + y_diff), 0, Vector2i(0, 0), 0);
	for y in range(p1.y, p2.y, x_diff):
		map.set_cell(0, Vector2i(y_x.x, y), 0, Vector2i(0, 0), 0);
		map.set_cell(0, Vector2i(y_x.x + x_diff, y), 0, Vector2i(0, 0), 0);
