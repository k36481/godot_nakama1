extends Node

var pack_player = preload("res://scene/character/Player.tscn")
var _server_request_attempts := 0
const MAX_REQUEST_ATTEMPTS := 3


var characters := {}

func _ready() -> void:
	$Control/Panel/Button.connect("pressed",self,"_on_startBtn_Clicked")
#	create random username
	randomize()
	$Control/Panel/LineEdit.text = "User" + str(randi())

func request_auth(email:String, pwd:String, username:String) -> void:
	var result: int = yield(ServerConnection.auth_uid_async(email, pwd, username), "completed")
	if result == OK:
		print("request_auth_ok")
	else:
		print("request_auth_fail")
	return result

func connect_server() -> void:
	var result: int = yield(ServerConnection.connect_to_server_async(), "completed")
	if result == OK:
		print("connect_server_ok")
	else:
		print("connect_server_fail")
	return result

func join_world() -> void:
	var presences: Dictionary = yield(ServerConnection.join_world_async(), "completed")
	print("join_world_OK")
	print("other connected playes count: %s" % presences.size())
	
func spawn_player(uid, player_name, presences):
	var player_uids = []
	for p in $Player.get_children():
		player_uids.append(p.uid)
	for _uid in presences:
		if _uid in player_uids:
			pass
		else:
			var new_player = pack_player.instance()
			new_player.uid = _uid
#			new_player.name = presences[_uid]["username"]
			new_player.name = _uid
			new_player.get_node("Label").text = presences[_uid]["username"]
			$Player.add_child(new_player)
			new_player.global_position.x = rand_range(300, 600)
			new_player.global_position.y = 600
			if ServerConnection.IS_ADMIN:
				ServerConnection.send_position_update(_uid, new_player.global_position)


func _on_startBtn_Clicked():
	var player_name = $Control/Panel/LineEdit.text
	var result: int = yield(request_auth(player_name, player_name, player_name), "completed")
	if result != OK:
		return
	result = yield(connect_server(), "completed")
	if result != OK:
		return
	yield(join_world(), "completed")
#	broadcast presence change
	ServerConnection.send_spawn(player_name)
	$Control/Panel.hide()


func update_state():
	for p in $Player.get_children():
		p.update_state()

func update_kills(data):
	for p in $Player.get_children():
		p.update_kill_label(data[p.uid]["kill"])

func update_leaved_presence(presences):
	for p in presences:
		$Player.get_node(p).offline()
