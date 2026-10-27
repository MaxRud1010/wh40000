extends Node3D
signal hit(target, amount)
signal destroyed(target)
var hp=160
var alive=true
var reset_timer=0.0
var target_id=0
var visual: Node3D
var health: MeshInstance3D
var collider: StaticBody3D

func _ready():
	if has_node("Dummy"):
		visual=get_node("Dummy")
		collider=get_node("Hitbox")
		health=get_node("HealthRoot").find_child("Health",true,false)
		collider.set_meta("target",self)

func take_damage(amount:int):
	if not alive: return
	hp=maxi(0,hp-amount)
	health.scale.x=maxf(.001,float(hp)/160)
	health.position.x=-(1.0-float(hp)/160)*.8
	hit.emit(self,amount)
	if hp==0:
		alive=false; reset_timer=8; collider.collision_layer=0; health.visible=false
		destroyed.emit(self)

func restore():
	hp=160; alive=true; reset_timer=0
	visual.rotation=Vector3.ZERO; collider.collision_layer=2
	health.visible=true; health.scale.x=1; health.position.x=0

func _process(delta):
	if not alive:
		visual.rotation.x=lerp_angle(visual.rotation.x,-1.5,1-exp(-delta*8))
		reset_timer-=delta
		if reset_timer<=0: restore()
