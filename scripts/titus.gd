extends CharacterBody3D
signal attack_requested(target, point, melee)
signal footstep(point, running)
signal state_changed
signal weapon_changed

const Nav=preload("res://scripts/navigation.gd")
const MODEL=preload("res://assets/models/titus.glb")
const WALK_SPEED=3.0
const RUN_SPEED=6.4
var navigation
var model:Node3D
var skeleton:Skeleton3D
var player:AnimationPlayer
var bolter:Node3D
var sword:Node3D
var muzzle:Node3D
var sword_tip:Node3D
var hand_socket:Node3D
var back_socket:Node3D
var path=PackedVector3Array()
var target:Node3D
var running=false
var selected=true
var direct=false
var manual_move=Vector3.ZERO
var manual_aim=Vector3.ZERO
var manual_target:Node3D
var manual_fire=false
var weapon="bolter"
var pending_weapon=""
var ammo=30
var action=""
var action_time=0.0
var action_duration=0.0
var contact_time=0.0
var contact_done=false
var combo=0
var foot_time=0.0
var phase="ОЖИДАЕТ ПРИКАЗА"
var current_clip=""
var shots=0
var attacks=0

func _ready():
	navigation=Nav.new()
	collision_layer=4;collision_mask=1
	var collision=CollisionShape3D.new();var capsule=CapsuleShape3D.new();capsule.height=3.0;capsule.radius=.48;collision.shape=capsule;collision.position.y=1.5;add_child(collision)
	model=MODEL.instantiate();model.name="TitusModel";add_child(model);model.scale=Vector3.ONE*3.1
	skeleton=_find_type(model,"Skeleton3D") as Skeleton3D
	player=_find_type(model,"AnimationPlayer") as AnimationPlayer
	assert(skeleton!=null and player!=null,"Titus rig or animation library missing")
	bolter=model.find_child("Bolter",true,false);sword=model.find_child("Chainsword",true,false)
	assert(bolter!=null and sword!=null,"Extracted weapon meshes missing")
	muzzle=bolter.find_child("Muzzle",true,false);sword_tip=sword.find_child("SwordTip",true,false)
	hand_socket=_socket("handR","RightHandSocket")
	back_socket=_socket("spine","BackSocket")
	for clip in player.get_animation_list():
		var anim=player.get_animation(clip)
		if clip.begins_with("idle_") or clip.begins_with("walk_") or clip.begins_with("run_") or clip=="aim_bolter":anim.loop_mode=Animation.LOOP_LINEAR
	_equip("bolter")
	_play("idle_bolter",0)

func _find_type(node:Node,type_name:String)->Node:
	if node.is_class(type_name):return node
	for child in node.get_children():
		var found=_find_type(child,type_name)
		if found!=null:return found
	return null

func _socket(bone_name:String,socket_name:String)->Node3D:
	var attachment=BoneAttachment3D.new();attachment.name=socket_name+"Attachment";attachment.bone_name=bone_name;skeleton.add_child(attachment)
	var socket=Node3D.new();socket.name=socket_name;attachment.add_child(socket)
	var index=skeleton.find_bone(bone_name)
	socket.basis=skeleton.get_bone_global_rest(index).basis.inverse()
	return socket

func _equip(value:String):
	weapon=value
	if value=="bolter":
		bolter.reparent(hand_socket,false);bolter.transform=Transform3D.IDENTITY
		sword.reparent(back_socket,false);sword.position=Vector3(.16,-.15,-.17);sword.rotation=Vector3(0,0,-.35)
	else:
		sword.reparent(hand_socket,false);sword.position=Vector3.ZERO;sword.rotation=Vector3(1.8,0,0)
		bolter.reparent(back_socket,false);bolter.position=Vector3(-.12,.04,-.20);bolter.rotation=Vector3(.2,0,.6)
	weapon_changed.emit()

func switch_weapon(value:String):
	if value==weapon or action!="":return
	pending_weapon=value;_start_action("swap",1.05,.52,"draw_"+value);phase="СМЕНА ОРУЖИЯ"

func reload():
	if weapon!="bolter" or ammo==30 or action!="":return
	_start_action("reload",2.1,2.1,"reload_bolter");phase="ПЕРЕЗАРЯДКА"

func stop():
	path.clear();target=null;manual_fire=false

func order_move(point:Vector3,queue=false,run=false)->bool:
	var start=path[path.size()-1] if queue and not path.is_empty() else global_position
	var route=navigation.path_to(start,point)
	if route.is_empty():return false
	if not queue:path.clear()
	path.append_array(route);target=null;running=run;return true

func order_attack(victim:Node3D):
	stop();target=victim

func _play(clip:String,blend=.13):
	if current_clip==clip and player.is_playing():return
	if not player.has_animation(clip):push_error("Missing animation: "+clip);return
	current_clip=clip;player.play(clip,blend)

func _start_action(value:String,duration:float,contact:float,clip:String):
	action=value;action_duration=duration;action_time=0;contact_time=contact;contact_done=false
	_play(clip,.065)

func _face(point:Vector3,delta:float):
	var direction=point-global_position
	if direction.length_squared()>.01:rotation.y=lerp_angle(rotation.y,atan2(direction.x,direction.z),minf(1,delta*12))

func _attack(victim:Node3D,point:Vector3):
	if action!="":return
	if weapon=="bolter":
		if ammo<=0:reload();return
		ammo-=1;shots+=1;_start_action("fire",.22,.035,"fire_bolter")
	else:
		var clips=["sword_slash_left","sword_slash_right","sword_overhead"]
		var duration=1.1 if combo==2 else .85
		_start_action("melee",duration,.56 if combo==2 else (.36 if combo==1 else .43),clips[combo])
		combo=(combo+1)%3;attacks+=1
	# Capture the intended target at wind-up; contact is emitted once, at the clip event.
	set_meta("contact_target",victim);set_meta("contact_point",point)

func _firing_position(victim:Node3D,range_limit:float):
	var best=PackedVector3Array();var best_cost=INF
	for radius in [range_limit*.75,range_limit*.45,range_limit*.92]:
		for i in range(24):
			var candidate=victim.global_position+Vector3(cos(i*TAU/24.0),0,sin(i*TAU/24.0))*radius
			if navigation.blocked(candidate) or not navigation.clear_line(candidate,victim.global_position,.05):continue
			var route=navigation.path_to(global_position,candidate)
			if route.is_empty():continue
			var cost=0.0;var previous=global_position
			for p in route:cost+=previous.distance_to(p);previous=p
			if cost<best_cost:best=route;best_cost=cost
	path=best

func _physics_process(delta):
	if not is_instance_valid(player):return
	if target!=null and (not is_instance_valid(target) or not target.alive):target=null;path.clear()
	var desired=Vector3.ZERO
	var aiming=false
	if action!="":
		action_time+=delta
		if not contact_done and action_time>=contact_time:
			contact_done=true
			if action=="swap":_equip(pending_weapon);pending_weapon=""
			elif action in ["fire","melee"]:
				attack_requested.emit(get_meta("contact_target",null),get_meta("contact_point",global_position+Vector3.FORWARD*4),action=="melee")
		if action_time>=action_duration:
			if action=="reload":ammo=30
			action="";current_clip=""
	if direct:
		desired=manual_move*(RUN_SPEED if running else WALK_SPEED)
		if manual_fire:
			_face(manual_aim,delta);aiming=true
			if action=="":_attack(manual_target,manual_aim)
		elif desired.length()>.1:_face(global_position+desired,delta)
	elif target!=null:
		var range_limit=22.0 if weapon=="bolter" else 2.6
		var distance=Vector2(global_position.x-target.global_position.x,global_position.z-target.global_position.z).length()
		var fire_clear=weapon=="sword" or navigation.clear_line(global_position,target.global_position,.05)
		if distance>range_limit or not fire_clear:
			if path.is_empty():_firing_position(target,range_limit);running=true
		else:
			path.clear();_face(target.global_position,delta);aiming=true
			if action=="":_attack(target,target.global_position+Vector3.UP*1.5)
	if not direct and not path.is_empty():
		var direction=path[0]-global_position;direction.y=0
		if direction.length()<.24:path.remove_at(0)
		else:desired=direction.normalized()*minf(RUN_SPEED if running else WALK_SPEED,direction.length()/delta);_face(path[0],delta)
	if action in ["melee","swap","reload"]:desired=Vector3.ZERO
	var horizontal=Vector3(velocity.x,0,velocity.z).move_toward(desired,(22.0 if running else 15.0)*delta)
	velocity.x=horizontal.x;velocity.z=horizontal.z
	velocity.y-=20*delta
	if is_on_floor():velocity.y=-.1
	move_and_slide()
	var moving=horizontal.length()>.3
	if action=="":
		if moving:_play(("run_" if running else "walk_")+weapon);phase="ТЯЖЁЛЫЙ БЕГ" if running else "ВЫПОЛНЯЕТ ПРИКАЗ"
		elif aiming and weapon=="bolter":_play("aim_bolter");phase="ЦЕЛЬ НА ПРИЦЕЛЕ"
		else:_play("idle_"+weapon);phase="ОЖИДАЕТ ПРИКАЗА"
	elif action=="fire":phase="ОТКРЫВАЕТ ОГОНЬ"
	elif action=="melee":phase="БЛИЖНИЙ БОЙ"
	if moving and action=="":
		foot_time+=delta
		var interval=.29 if running else .4
		if foot_time>=interval:
			foot_time-=interval;footstep.emit(global_position+Vector3(0,.04,0),running)
	else:foot_time=0
