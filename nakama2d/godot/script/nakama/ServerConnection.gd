extends Node

#onready var ServerConnection = $ServerConnection
const IS_ADMIN = true
var uid = ""

signal presences_changed
signal state_updated(positions)
signal initial_state_received(positions)
const KEY := "nakama_godot2d_demo"

var _session: NakamaSession
var _client := Nakama.create_client(KEY, "218.55.137.221", 7350, "http")
#var _client := Nakama.create_client(KEY, "127.0.0.1", 7350, "https")

var _exception_handler := ExceptionHandler.new()
#var _authenticator := Authenticator.new(_client, _exception_handler)
#var _storage_worker: StorageWorker
var _socket: NakamaSocket
var _world_id : String
var _presences := {}
var _positions := {}
var _data := {}

enum OpCodes {
	UPDATE_POSITION = 1,
	UPDATE_INPUT,
	UPDATE_STATE,
	UPDATE_JUMP,
	DO_SPAWN,
	UPDATE_KILL,
	PRESENCE_LEAVE,
}

func auth_uid_async(email:String, pwd:String, username:String) -> int:
	# Unique ID is not supported by Godot in HTML5, use a different way to generate an id, or a different authentication option.
#	var deviceid = OS.get_unique_id()
#	var new_session: NakamaSession = yield(_client.authenticate_device_async(deviceid), "completed")
	var new_session: NakamaSession = yield(_client.authenticate_email_async(email+"@test.com", "password", username, true), "completed")
	print(email)
	if new_session.is_exception():
		print("An error occured: %s" % _session)
		return _session.get_exception().status_code
	else:
		_session = new_session
		return OK

func connect_to_server_async() -> int:
	_socket = Nakama.create_socket_from(_client)
	var result: NakamaAsyncResult = yield(_socket.connect_async(_session), "completed")
	var parsed_result := _exception_handler.parse_exception(result)

	if parsed_result == OK:
		#warning-ignore: return_value_discarded
		_socket.connect("connected", self, "_on_socket_connected")
		#warning-ignore: return_value_discarded
		_socket.connect("closed", self, "_on_socket_closed")
		#warning-ignore: return_value_discarded
		_socket.connect("received_error", self, "_on_socket_error")
		#warning-ignore: return_value_discarded
#		_socket.connect("received_match_presence", self, "_on_new_match_presence")
		#warning-ignore: return_value_discarded
		_socket.connect("received_match_state", self, "_on_Received_Match_State")
		#warning-ignore: return_value_discarded
		_socket.connect("received_channel_message", self, "_on_Received_Channel_message")
		
	return parsed_result
	

	
func join_world_async() -> Dictionary:
	var world: NakamaAPI.ApiRpc = yield(_client.rpc_async(_session, "get_world_id", ""), "completed")
	if not world.is_exception():
		_world_id = world.payload
	else:
		print("_world_id exception: %s" % world.get_exception().message)
#
	var match_join_result: NakamaRTAPI.Match = yield(_socket.join_match_async(_world_id), "completed")
	if match_join_result.is_exception():
		var exception: NakamaException = match_join_result.get_exception()
		printerr("join exception %s, %s" % [exception.status_code, exception.message])
		return {}

	for presence in match_join_result.presences:
		_presences[presence.user_id] = presence
#
	ServerConnection.connect("initial_state_received", self, "_on_ServerConnection_initial_state_received")
	ServerConnection.connect("state_updated", self, "_on_ServerConnection_state_updated")
	ServerConnection.connect("presences_changed", self, "_on_ServerConnection_presences_changed")
	
	return _presences

func get_user_id() -> String:
	if _session:
		return _session.user_id
	return ""

func send_input(uid: String, _dir: int, skill_input: Dictionary) -> void:
	if _socket:
		var payload := {id = uid, inp = {dir = _dir, inputs = skill_input}}
		_socket.send_match_state_async(_world_id, OpCodes.UPDATE_INPUT, JSON.print(payload))

func send_position_update(uid: String, pos: Vector2) -> void:
	if _socket:
		var payload := {id = uid, pos = {x = pos.x, y = pos.y}}
		_socket.send_match_state_async(_world_id, OpCodes.UPDATE_POSITION, JSON.print(payload))
		
func send_spawn(name: String) -> void:
	if _socket:
		var payload := {id = get_user_id(), nm = name}
		_socket.send_match_state_async(_world_id, OpCodes.DO_SPAWN, JSON.print(payload))
		
func send_kill_update(uid: String, _kill: Dictionary) -> void:
	if _socket:
		var payload := {id = uid, kill = _kill}
		_socket.send_match_state_async(_world_id, OpCodes.UPDATE_KILL, JSON.print(payload))
		
func _on_Received_Match_State(match_state: NakamaRTAPI.MatchData) -> void:
	var code := match_state.op_code
	var raw := match_state.data

	match code:
		OpCodes.UPDATE_STATE:
			var decoded: Dictionary = JSON.parse(raw).result
			var positions: Dictionary = decoded.pos
#			var inputs: Dictionary = decoded.inp
			_data = decoded
			emit_signal("state_updated", positions)
			
		OpCodes.DO_SPAWN:
			var decoded: Dictionary = JSON.parse(raw).result
			var id: String = decoded.id
			var nm: String = decoded.nm
			var presences: Dictionary = decoded.presences
			get_node("/root/Game").spawn_player(id, nm, presences)

		OpCodes.UPDATE_INPUT:
			var decoded: Dictionary = JSON.parse(raw).result
			
		OpCodes.PRESENCE_LEAVE:
			var decoded: Dictionary = JSON.parse(raw).result
			get_node("/root/Game").update_leaved_presence(decoded)
				
		OpCodes.UPDATE_KILL:
			var decoded: Dictionary = JSON.parse(raw).result
			get_node("/root/Game").update_kills(decoded)
#			print(decoded)
				
	
func _on_ServerConnection_state_updated(positions: Dictionary) -> void:
	var update := false
	get_node("/root/Game").update_state()
	
	
#	for key in characters:
#		update = false
#		if key in positions:
#			var next_position: Dictionary = positions[key]
#			characters[key].next_position = Vector2(next_position.x, next_position.y)
#			update = true
#		if key in inputs:
#			characters[key].next_input = inputs[key].dir
#			characters[key].next_jump = inputs[key].jmp == 1
#			update = true
#		if update:
#			characters[key].update_state()

#not connected now
func _on_ServerConnection_initial_state_received(positions: Dictionary, inputs: Dictionary, colors: Dictionary, names: Dictionary) -> void:
	#warning-ignore: return_value_discarded
	ServerConnection.disconnect(
		"initial_state_received", self, "_on_ServerConnection_initial_state_received"
	)
	print("_on_ServerConnection_initial_state_received")
	
	
func _on_ServerConnection_presences_changed() -> void:
	print(_presences)

func _on_socket_closed() -> void:
	_socket = null
