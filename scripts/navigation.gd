extends RefCounted

const LIMITS = Rect2(-27, -23, 54, 45)
const COVER = [
	Rect2(-16, 1.4, 8, 1.2), Rect2(3.5, 2.4, 7, 1.2),
	Rect2(-21.4, -6.5, 2.8, 3), Rect2(17.4, 3.4, 3.2, 3.2),
	Rect2(-3.3, -5.1, 2.6, 2.2), Rect2(13.6, -16.1, 2.8, 2.2)]
var grid = AStarGrid2D.new()

func _init():
	grid.region = Rect2i(-27, -23, 55, 46)
	grid.cell_size = Vector2.ONE
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	grid.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	grid.update()
	for x in range(-27, 28):
		for z in range(-23, 23):
			grid.set_point_solid(Vector2i(x,z), blocked(Vector3(x,0,z)))

func blocked(p: Vector3, padding = .7) -> bool:
	if not LIMITS.grow(-padding).has_point(Vector2(p.x,p.z)): return true
	for cover in COVER:
		if cover.grow(padding).has_point(Vector2(p.x,p.z)): return true
	return false

func clear_line(a: Vector3, b: Vector3, padding = .7) -> bool:
	var count = maxi(1, ceili(a.distance_to(b) * 5))
	for i in range(count+1):
		if blocked(a.lerp(b,float(i)/count), padding): return false
	return true

func path_to(start: Vector3, target: Vector3) -> PackedVector3Array:
	var end = target
	end.x = clampf(end.x,-26,26); end.z = clampf(end.z,-22,21); end.y=0
	if blocked(end):
		var best = Vector3.INF
		var distance = INF
		for r in range(1,6):
			for i in range(24):
				var candidate = end+Vector3(cos(i*TAU/24.0),0,sin(i*TAU/24.0))*r
				if not blocked(candidate) and candidate.distance_squared_to(target)<distance:
					distance=candidate.distance_squared_to(target); best=candidate
		if best==Vector3.INF: return PackedVector3Array()
		end=best
	if clear_line(start,end): return PackedVector3Array([end])
	var from = Vector2i(roundi(start.x),roundi(start.z))
	var to = Vector2i(roundi(end.x),roundi(end.z))
	if grid.is_point_solid(to):
		for offset in [Vector2i(1,0),Vector2i(-1,0),Vector2i(0,1),Vector2i(0,-1)]:
			if grid.region.has_point(to+offset) and not grid.is_point_solid(to+offset): to+=offset; break
	var points = grid.get_point_path(from,to)
	var raw = PackedVector3Array()
	for point in points: raw.append(Vector3(point.x,0,point.y))
	if raw.is_empty(): return raw
	raw.append(end)
	var result = PackedVector3Array()
	var origin=start
	var index=0
	while index<raw.size():
		var far=raw.size()-1
		while far>index and not clear_line(origin,raw[far]): far-=1
		if not clear_line(origin,raw[far]): return PackedVector3Array()
		result.append(raw[far]); origin=raw[far]; index=far+1
	return result
