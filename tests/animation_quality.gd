extends SceneTree
var failures=[]
var checks=0
func _initialize():call_deferred("run")
func check(value:bool,text:String):
	checks+=1
	if not value:failures.append(text);push_error(text)
	else:print("PASS ",text)
func run():
	var game=load("res://scenes/range.tscn").instantiate();root.add_child(game)
	await process_frame
	var actor=game.actor;actor.action="inspection";actor.action_duration=100
	for clip in ["idle_bolter","idle_sword","walk_bolter","walk_sword","run_bolter","run_sword"]:
		var animation=actor.player.get_animation(clip)
		var gap=0.0
		for track in range(animation.get_track_count()):
			var count=animation.track_get_key_count(track)
			if count<2:continue
			var a=animation.track_get_key_value(track,0);var b=animation.track_get_key_value(track,count-1)
			if a is Quaternion:gap=maxf(gap,1-absf(a.dot(b)))
			elif a is Vector3:gap=maxf(gap,a.distance_to(b))
		check(gap<.001,"loop seam is continuous: "+clip)
		actor.player.play(clip,0);actor.player.seek(.01,true)
		var first=[];var first_position=[]
		for i in range(actor.skeleton.get_bone_count()):first.append(actor.skeleton.get_bone_pose_rotation(i));first_position.append(actor.skeleton.get_bone_pose_position(i))
		actor.player.seek(animation.length*.29,true)
		var changed=0
		for i in range(actor.skeleton.get_bone_count()):
			if absf(first[i].dot(actor.skeleton.get_bone_pose_rotation(i)))<.9999999 or first_position[i].distance_to(actor.skeleton.get_bone_pose_position(i))>.0001:changed+=1
		check(changed>=(6 if clip.begins_with("walk") or clip.begins_with("run") else 1),"clip changes actual bone poses: "+clip)
	# Foot planting must stay near the sole during the stance phase. Check in model
	# space, without CharacterBody translation or physics affecting the measurement.
	for clip in ["walk_bolter","run_bolter"]:
		actor.player.play(clip,0)
		var y_values=[];var z_values=[];var length=actor.player.get_animation(clip).length
		var end=.40 if clip.begins_with("run") else .60
		for u in [.02,.12,.25,end]:
			actor.player.seek(length*u,true)
			actor.skeleton.force_update_all_bone_transforms()
			var p=actor.skeleton.get_bone_global_pose(actor.skeleton.find_bone("footR")).origin
			y_values.append(p.y);z_values.append(p.z)
		var max_height=float(y_values.max())-float(y_values.min())
		check(max_height<.02,"stance foot remains planted vertically: "+clip)
		check(float(z_values.max())-float(z_values.min())>.08,"stance foot travels backwards relative to the moving body: "+clip)
	# Check the visible weapon at each damage event, not just the gameplay timer.
	actor._equip("sword")
	for entry in [["sword_slash_left",.43],["sword_slash_right",.36],["sword_overhead",.56]]:
		actor.player.play(entry[0],0);actor.player.seek(entry[1],true);actor.skeleton.force_update_all_bone_transforms()
		await process_frame
		var tip=actor.sword_tip.global_position-actor.global_position
		var reach=tip.dot(actor.global_basis.z.normalized())
		check(reach>1.3,"sword reaches forward at damage contact: "+entry[0])
		check(tip.y>.5 and tip.y<2.7,"sword crosses target body height: "+entry[0])
	print("ANIMATION QUALITY: ",checks," checks, ",failures.size()," failures")
	print(failures)
	game.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
