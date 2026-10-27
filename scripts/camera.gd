extends Camera3D
var focus_point=Vector3(0,0,-4.5)
var yaw=.32
var pitch=.83
var zoom=43.0
var follow=false
var actor:Node3D
var shake=0.0

func _ready():
	projection=Camera3D.PROJECTION_ORTHOGONAL
	current=true
	near=.1;far=240
	update_camera(0)

func update_camera(delta:float):
	if follow and is_instance_valid(actor):
		focus_point=focus_point.lerp(actor.global_position,minf(1,delta*7));focus_point.y=0
		if focus_point.distance_to(Vector3(actor.position.x,0,actor.position.z))<.03:follow=false
	size=zoom
	position=focus_point+Vector3(sin(yaw)*cos(pitch),sin(pitch),cos(yaw)*cos(pitch))*65
	look_at(focus_point)
	if shake>0:
		h_offset=sin(Time.get_ticks_msec()*.15)*shake;v_offset=cos(Time.get_ticks_msec()*.11)*shake*.5;shake=maxf(0,shake-delta*.5)
	else:h_offset=0;v_offset=0

func ground_point(screen:Vector2)->Vector3:
	var origin=project_ray_origin(screen);var direction=project_ray_normal(screen)
	if absf(direction.y)<.001:return focus_point
	return origin+direction*(-origin.y/direction.y)

func _process(delta):
	update_camera(delta)
