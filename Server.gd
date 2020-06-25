extends Node2D

const PORT = 9000
const MAX_PLAYERS = 3

var server: WebSocketServer = null

# we always ever have 3 players (per room).
# client side works like this:
#    - opens multiplayer dialog
#    - clicks connect
#    - receives connected
#    - receives its color / player number

var id2player = {}

var player2id = {}
var player2pos = {}
var player2draw = {}
var player2laser = {}

var num_active = 0
var global_slide_number = 0

func _init():
	print('[init] process started')
	init_rooms()


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
		var player_number = add_player(id)
		if player_number >= 0:
			rpc_id(id, 'room_welcome', player_number)
			print('[connect] Client %d is now player %d!' % [id, player_number])
			send_players_to(player_number)
			return
	print('[connect] Client %d rejected, room is full!' % id)
	rpc_id(id, 'room_full')

func _exit_tree():
	server.stop()

func _client_disconnected(id, was_clean=false) -> void:
	print('[disconnect] Client %d disconnected (cleanly: %s)' % [id, str(was_clean)])
	if id2player.has(id):
		num_active -= 1
		var player_number = id2player[id]
		for i in range(MAX_PLAYERS):
			if player2id[i] != 0 and i != player_number:
				rpc_id(player2id[i], 'unintroduce_player', player_number, Vector2.ZERO, [], {'active': false, 'scale': 1})
		remove_player_by_id(id)

remote func change_slide(slide_number: int) -> void:
	var id = get_tree().get_rpc_sender_id()
	var player_number = id2player[id]
	global_slide_number = slide_number
	print('[player] ', player_number, ' changed to slide ', slide_number)
	for i in range(MAX_PLAYERS):
		if player2id[i] != 0 and i != player_number:
			var remote_id = player2id[i]
			rpc_id(remote_id, 'change_slide', slide_number)

remote func update_player(pos, draw, laser):
	var id = get_tree().get_rpc_sender_id()
	var player_number = id2player[id]
	print('[player] %d pos: %s ' % [player_number, str(pos)])
	player2pos[player_number] = pos
	player2draw[player_number] = draw
	player2laser[player_number] = laser
	for i in range(MAX_PLAYERS):
		if player2id[i] != 0 and i != player_number:
			var remote_id = player2id[i]
			rpc_id(remote_id, 'update_player', player_number, pos, draw, laser)

func send_players_to(player_number) -> void:
	# send all other players to player
	# --> so the player can display the others immediately
	# also, send new player to all others
	var id = player2id[player_number]
	print('[server] sending players to player %d (id=%d)' % [player_number, id])
	# first, send the new player to the current slide number
	rpc_id(id, 'change_slide', global_slide_number)

	for i in range(MAX_PLAYERS):
		if player2id[i] != 0 and i != player_number:
			rpc_id(id, 'introduce_player', i, player2pos[i], player2draw[i], player2laser[i])
			rpc_id(player2id[i], 'introduce_player', player_number, player2pos[player_number], player2draw[player_number], player2laser[player_number])
	return


####### ROOM MANAGEMENT
func init_rooms() -> void:
	for i in range(MAX_PLAYERS):
		init_player(i)

func init_player(i: int) -> void:
	player2pos[i] = Vector2.ZERO
	player2draw[i] = []
	player2laser[i] = {'active': false, 'scale': 1.0}
	player2id[i] = 0

func remove_player_by_id(id):
	if id2player.has(id):
		var player = id2player[id]
		init_player(player)
		id2player.erase(id)

func add_player(id) -> int:
	for player_number in range(MAX_PLAYERS):
		if player2id[player_number] == 0:
			# we found a free one!
			id2player[id] = player_number
			self.player2id[player_number] = id
			self.player2pos[player_number] = Vector2.ZERO
			self.player2draw[player_number] = []
			self.player2laser[player_number] = {'active': false, 'scale': 1.0}
			return player_number
	return -1


