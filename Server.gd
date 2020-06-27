extends Node2D

const PORT = 9000
const MAX_PLAYERS = 30

var server: WebSocketServer = null

class Player:
	var id : int
	var player_number: int
	var room: String
	var pos : Vector2 
	var drawing: Array
	var laser: Dictionary

	func _init(player_number: int, room_name: String):
		self.player_number = player_number
		self.room = room_name
		reset()
	
	func reset(id = -1):
		self.id = id
		pos = Vector2.ZERO
		drawing = []
		laser = {'active': false, 'scale': Vector2(1,1)}

class Room:
	var name: String
	var players : Array 
	var slide_number: int

	func _init(name: String):
		self.name = name
		slide_number = 0
		players = []
		players.append(Player.new(0, name))
		players.append(Player.new(1, name))
		players.append(Player.new(2, name))

	func reset():
		_init(name)

	func active_count():
		var ret = 0
		for player in players:
			if player.id != -1:
				ret += 1
		return ret

	func add_player(id: int) -> Player:
		for player in players:
			if player.id == -1:
				player.reset(id)
				return player
		return null


class Rooms:
	var rooms: Dictionary
	var id2room = {}
	var id2player = {}

	func _init():
		rooms = {}
	
	func find_player_by_id(id: int):
		if id2player.has(id):
			return id2player[id]
		return null

	func find_room_by_id(id: int):
		if id2room.has(id):
			return id2room[id]
		return null

	func get_or_create_room(room: String):
		if not rooms.has(room):
			rooms[room] = Room.new(room)
		return rooms[room]

	func add_player(id: int, room_name: String) -> Player:
		var room = get_or_create_room(room_name)
		if room.active_count() < 3:
			var player = room.add_player(id)
			if player != null:
				id2room[id] = room
				id2player[id] = player
				return player
		return null

	func remove_player(player: Player):
		id2room.erase(player.id)
		id2player.erase(player.id)
		player.reset()

# we always ever have 3 players (per room).
# client side works like this:
#    - opens multiplayer dialog
#    - clicks connect
#    - receives connected
#    - sends enter_room
#    - receives its color / player number

# room management
var num_active = 0
var rooms: Rooms

func _init():
	print('[init] process started')
	rooms = Rooms.new()


####### CONNECTION MANAGEMENT
func _ready() -> void:
	server = WebSocketServer.new()
	var err = server.listen(PORT, PoolStringArray(), true)
	if err != OK:
		print('[server] Unable to listen on port %d' % PORT)
		set_process(false)
		return
	get_tree().set_network_peer(server)
	get_tree().connect("network_peer_connected", self, "_client_connected")
	get_tree().connect("network_peer_disconnected", self, "_client_disconnected")
	print('[server] Listening on port %d' % PORT)

func _process(delta: float) -> void:
	if server.is_listening():
		server.poll()

func _client_connected(id, proto='unk') -> void:
	print('[connect] Client %d connected to server with protocol %s!' % [id, proto])
	num_active += 1
	if num_active <= MAX_PLAYERS:
		# OK, nothing more to do, wait for enter_room
		return
	print('[connect] Client %d rejected, server is full!' % id)
	rpc_id(id, 'room_full')

func _exit_tree():
	server.stop()

func _client_disconnected(id, was_clean=false) -> void:
	print('[disconnect] Client %d disconnected (cleanly: %s)' % [id, str(was_clean)])
	var player: Player = rooms.find_player_by_id(id)
	if player != null:
		var room = rooms.find_room_by_id(id)
		num_active -= 1
		var player_number = player.player_number
		for other_player in room.players:
			if other_player.id != -1 and other_player.player_number != player_number:
				rpc_id(other_player.id, 'unintroduce_player', player_number, Vector2.ZERO, [], {'active': false, 'scale': Vector2(1,1)})
		rooms.remove_player(player)

remote func enter_room(room: String):
	var id = get_tree().get_rpc_sender_id()
	var player = rooms.add_player(id, room)
	if player != null:
		rpc_id(id, 'room_welcome', player.player_number)
		print('[connect] Client %d is now player %d in room %s!' % [id, player.player_number, room])
		send_players_to(player)
		return
	print('[connect] Client %d rejected, room %s is full!' % [id, room])
	rpc_id(id, 'room_full')

remote func change_slide(slide_number: int) -> void:
	var id = get_tree().get_rpc_sender_id()
	var player = rooms.find_player_by_id(id)
	var room = rooms.find_room_by_id(id)
	if room != null and player != null:
		room.slide_number = slide_number
		print('[player] ', player.player_number, ' changed to slide ', slide_number, ' in room ', room.name)
		for other_player in room.players:
			if other_player.id != -1 and other_player.id != id:
				rpc_id(other_player.id, 'change_slide', slide_number)

remote func update_player(pos, draw, laser):
	var id = get_tree().get_rpc_sender_id()
	var player = rooms.find_player_by_id(id)
	var room = rooms.find_room_by_id(id)
	if room != null and player != null:
		print('[player] %d room %s pos: %s ' % [player.player_number, player.room, str(pos)])
		player.pos = pos
		player.drawing = draw
		player.laser = laser
		for other_player in room.players:
			if other_player.id != -1 and other_player.id != id:
				rpc_id(other_player.id, 'update_player', player.player_number, pos, draw, laser)

func send_players_to(player) -> void:
	# send all other players to player
	# --> so the player can display the others immediately
	# also, send new player to all others
	var id = player.id
	var room = rooms.find_room_by_id(id)
	print('[server] sending players to player %d (id=%d) in room %s' % [player.player_number, id, room.name])
	# first, send the new player to the current slide number
	rpc_id(id, 'change_slide', room.slide_number)

	for other_player in room.players:
		if other_player.id != -1 and other_player.id != id:
			rpc_id(id, 'introduce_player', other_player.player_number, other_player.pos, other_player.drawing, other_player.laser)
			rpc_id(other_player.id, 'introduce_player', player.player_number, player.pos, player.drawing, player.laser)
	return

