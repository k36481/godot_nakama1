extends KinematicBody2D

var uid = ""
var is_online = true
var spd_move = 15000
var spd_fall = 30000
var dir = 0
var prev_dir = 0
var pos_last = Vector2()
var forward_last = 1 #left or right
var is_ready = false
var kill = 0

func _ready():
	$Timer.connect("timeout",self,"_on_Timer_timeout")
#	ServerConnection.send_position_update(uid,global_position)
	if ServerConnection.get_user_id() == uid:
		$Camera2D.current = true
	is_ready = true
	$Pivot/HandPivot/MeleeArea.connect("body_entered",self, "_on_Melee_body_entered")
	
func _physics_process(delta):
	if not is_ready or uid == "":
		return
#	send input
#	send movement
	dir = 0
	if Input.is_action_pressed("a"):
		dir -= 1
	if Input.is_action_pressed("d"):
		dir += 1
#	if ServerConnection.get_user_id() == uid:
#		ServerConnection.send_input(uid, dir)
#	send action input
	var q = 0
	var w = 0
	var e = 0
	var r = 0
	var space = 0
	if Input.is_action_just_pressed("q"):
		q = 1
	if Input.is_action_just_pressed("w"):
		w = 1
	if Input.is_action_just_pressed("e"):
		e = 1
	if Input.is_action_just_pressed("r"):
		r = 1
	if Input.is_action_just_pressed("space"):
		space = 1
	if ServerConnection.get_user_id() == uid:
		ServerConnection.send_input(uid, dir, {"q":q,"w":w,"e":e,"r":r, "space":space})
#	process data from nakama server
	if ServerConnection.IS_ADMIN:
#		send movement input
		var inp = ServerConnection._data["inp"][uid]["dir"]
		move_and_slide(Vector2(float(inp)*spd_move*delta, spd_fall*delta))
		ServerConnection.send_position_update(uid, global_position)
		if forward_last != 0:
			$Pivot.scale.x = -forward_last
	else: 
		position.x = lerp(position.x, pos_last.x, .7)
		position.y = lerp(position.y, pos_last.y, .7)
		if forward_last != 0:
			$Pivot.scale.x = -forward_last
		
	var inp = ServerConnection._data["inp"][uid]["dir"]

	if ServerConnection._data["inp"][uid]["inputs"]["q"]:
		try_melee()

func _on_Timer_timeout():
	return
#	if ServerConnection.IS_ADMIN:
#		ServerConnection.send_position_update(uid, global_position)
#	else:
#		ServerConnection.send_input(uid, dir)
	
func update_state():
	var new_pos = ServerConnection._data["pos"][uid]
	pos_last = new_pos
	var new_dir = ServerConnection._data["inp"][uid]["dir"]
	forward_last = new_dir

func online():
	$LabelOffline.hide()
	$LabelOffline.text = "ONLINE"
	is_online = true

func offline():
	$LabelOffline.show()
	$LabelOffline.text = "OFFLINE"
	is_online = false
	queue_free()
	
func _on_Melee_body_entered(body):
	if ServerConnection.IS_ADMIN:
		if body.uid != null and body.uid != uid:
			kill += 1
			ServerConnection.send_kill_update(uid, {"kill": kill})
			respawn(body)

func try_melee():
	$AnimationPlayer.play("melee")

func respawn(body):
	if ServerConnection.IS_ADMIN:
		body.position.x = rand_range(-600, 600)
		body.position.y = 0

func update_kill_label(kill):
	var new_text = "Kill :" + str(kill)
	if new_text != $Label2.text:
		$AnimationUI.play("ui_kill_update")
		$Label2.text = "Kill :" + str(kill)
