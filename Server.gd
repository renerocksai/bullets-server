extends Node2D

const PORT = 9000
const MAX_PLAYERS = 3

var server: WebSocketServer = null
var id2player = {}

class PlayerInfo:

func _ready() -> void:
	server = WebSocketServer.new()
	server.listen(PORT, PoolStringArray(), true)
	get_tree().set_network_peer(server)
	get_tree().connect("network_peer_connected", self, "_client_connected")
	get_tree().connect("network_peer_disconnected", self, "_client_disconnected")

func _process(delta: float) -> void:
	if server.is_listening():
		server.poll()

func _client_connected(id) -> void:
	print('Client %d connected to server!' % id)
	# TODO: create player scene

func _client_disconnected(id) -> void:
	pass

remote func change_slide(slide_number: int) -> void:
	var id = get_tree().get_rpc_sender_id()
	print('Player ', id, ' changed to slide ', slide_number)
	pass

func send_players() -> void:
	# send all players to all other players
	# this is so they can update their lobby
	# we use rpc_id() to send out individual configs
	pass
	rpc_id()
