# RuinGen.gd — procedural "broken architecture" mesh toolkit (static helpers, no scene deps).
# Everything the first-person world is made of comes from here, so nothing is a clean box:
#   spline / tube_mesh        lumpy tubes (arms, roots, cables, rebar)
#   irregular_polygon         ragged outlines with bites taken out
#   extrude_polygon           broken slabs and floating islands (optional jagged cone underside)
#   grid_mesh                 faceted terrain with ragged edges + jagged cliff skirts
#   wall_mesh                 leaning, gap-ridden, jagged-topped walls
#   chunk_mesh                low-poly rubble
# Winding: Godot front faces are clockwise; _tri() orients every triangle toward a hint
# direction so callers only think in terms of "which way is outside".
class_name RuinGen
extends RefCounted

# ── triangle helpers ────────────────────────────────────────────────────────
static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, outward: Vector3, smooth: bool) -> void:
	var n: Vector3 = (b - a).cross(c - a)
	var verts: Array[Vector3] = [a, b, c]
	if n.dot(outward) > 0.0:
		verts = [a, c, b]
	for v in verts:
		st.set_smooth_group(0 if smooth else -1)
		st.add_vertex(v)

static func _commit(st: SurfaceTool) -> ArrayMesh:
	st.generate_normals()
	return st.commit()

# ── curves and tubes ────────────────────────────────────────────────────────
## Catmull-Rom through the control points; returns ~`samples` points.
static func spline(ctrl: Array, samples: int) -> PackedVector3Array:
	var out := PackedVector3Array()
	var n: int = ctrl.size()
	if n < 2:
		return out
	var per: int = maxi(1, int(ceil(float(samples) / float(n - 1))))
	for i in n - 1:
		var p0: Vector3 = ctrl[maxi(i - 1, 0)]
		var p1: Vector3 = ctrl[i]
		var p2: Vector3 = ctrl[i + 1]
		var p3: Vector3 = ctrl[mini(i + 2, n - 1)]
		for s in per:
			var t: float = float(s) / float(per)
			var t2: float = t * t
			var t3: float = t2 * t
			out.append(0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3))
	out.append(ctrl[n - 1])
	return out

## Lumpy tube along `points`. radii is sampled per point (last value repeats).
static func tube_mesh(points: PackedVector3Array, radii: PackedFloat32Array, sides: int = 8, lump: float = 0.0, rng_seed: int = 1, cap_start: bool = false, cap_end: bool = true) -> ArrayMesh:
	var n: int = points.size()
	if n < 2:
		return null
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed
	var t0: Vector3 = (points[1] - points[0]).normalized()
	var ref: Vector3 = Vector3.UP if absf(t0.dot(Vector3.UP)) < 0.9 else Vector3.RIGHT
	var normal: Vector3 = t0.cross(ref).normalized()
	var memory := PackedFloat32Array()
	memory.resize(sides)
	var rings: Array = []
	for i in n:
		var t: Vector3
		if i == 0:
			t = points[1] - points[0]
		elif i == n - 1:
			t = points[n - 1] - points[n - 2]
		else:
			t = points[i + 1] - points[i - 1]
		t = t.normalized()
		normal = (normal - t * normal.dot(t)).normalized()   # parallel transport
		var binormal: Vector3 = t.cross(normal)
		var r_i: float = radii[mini(i, radii.size() - 1)]
		var ring := PackedVector3Array()
		for s in sides:
			var l: float = 0.0
			if lump > 0.0:
				memory[s] = lerpf(memory[s], rng.randf_range(-1.0, 1.0), 0.55)
				l = memory[s]
			var a: float = TAU * float(s) / float(sides)
			ring.append(points[i] + (normal * cos(a) + binormal * sin(a)) * r_i * (1.0 + lump * l))
		rings.append(ring)

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in n - 1:
		var a_ring: PackedVector3Array = rings[i]
		var b_ring: PackedVector3Array = rings[i + 1]
		var mid: Vector3 = (points[i] + points[i + 1]) * 0.5
		for s in sides:
			var s2: int = (s + 1) % sides
			_tri(st, a_ring[s], b_ring[s], b_ring[s2], ((a_ring[s] + b_ring[s2]) * 0.5) - mid, true)
			_tri(st, a_ring[s], b_ring[s2], a_ring[s2], ((a_ring[s] + b_ring[s2]) * 0.5) - mid, true)
	if cap_start:
		var r0: PackedVector3Array = rings[0]
		for s in sides:
			_tri(st, points[0], r0[s], r0[(s + 1) % sides], points[0] - points[1], true)
	if cap_end:
		var r1: PackedVector3Array = rings[n - 1]
		for s in sides:
			_tri(st, points[n - 1], r1[s], r1[(s + 1) % sides], points[n - 1] - points[n - 2], true)
	return _commit(st)

# ── outlines ────────────────────────────────────────────────────────────────
## Ragged closed outline around the origin (x, z). `bites` = number of deep notches.
static func irregular_polygon(rx: float, rz: float, count: int, jitter: float, rng_seed: int, bites: int = 2) -> PackedVector2Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed
	var radii := PackedFloat32Array()
	for i in count:
		radii.append(1.0 + rng.randf_range(-jitter, jitter))
	for b in bites:
		radii[rng.randi_range(0, count - 1)] *= rng.randf_range(0.45, 0.7)
	var poly := PackedVector2Array()
	for i in count:
		var ang: float = TAU * (float(i) + rng.randf_range(-0.3, 0.3)) / float(count)
		poly.append(Vector2(cos(ang) * rx * radii[i], sin(ang) * rz * radii[i]))
	return poly

# ── slabs and islands ───────────────────────────────────────────────────────
## Extrudes an outline (x, z) into a chunk of broken concrete. Top is at y = top_y (with
## per-vertex jitter). With apex_depth > 0 the underside narrows to a jagged cone (floating
## island); otherwise the bottom is flat-ish. Returns null if the outline cannot be triangulated.
static func extrude_polygon(poly: PackedVector2Array, top_y: float, thickness: float, rng_seed: int, apex_depth: float = 0.0, top_jitter: float = 0.04) -> ArrayMesh:
	var tris: PackedInt32Array = Geometry2D.triangulate_polygon(poly)
	if tris.is_empty():
		return null
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed
	var n: int = poly.size()
	var top: Array[Vector3] = []
	var bot: Array[Vector3] = []
	var center2 := Vector2.ZERO
	for p in poly:
		center2 += p
	center2 /= float(n)
	for p in poly:
		top.append(Vector3(p.x, top_y + rng.randf_range(-top_jitter, top_jitter), p.y))
		var inset: float = 0.0 if apex_depth <= 0.0 else 0.18
		var q: Vector2 = p.lerp(center2, inset)
		bot.append(Vector3(q.x, top_y - thickness * rng.randf_range(0.7, 1.3), q.y))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var c3 := Vector3(center2.x, top_y - thickness * 0.5, center2.y)
	for i in range(0, tris.size(), 3):
		_tri(st, top[tris[i]], top[tris[i + 1]], top[tris[i + 2]], Vector3.UP, false)
	for i in n:
		var j: int = (i + 1) % n
		var side_mid: Vector3 = (top[i] + bot[j]) * 0.5
		_tri(st, top[i], top[j], bot[j], side_mid - c3, false)
		_tri(st, top[i], bot[j], bot[i], side_mid - c3, false)
	if apex_depth > 0.0:
		var apex := Vector3(center2.x + rng.randf_range(-0.4, 0.4), top_y - thickness - apex_depth, center2.y + rng.randf_range(-0.4, 0.4))
		for i in n:
			var j: int = (i + 1) % n
			_tri(st, bot[i], bot[j], apex, (bot[i] + bot[j] + apex) / 3.0 - c3, false)
	else:
		var bt: PackedInt32Array = Geometry2D.triangulate_polygon(poly)
		for i in range(0, bt.size(), 3):
			_tri(st, bot[bt[i]], bot[bt[i + 1]], bot[bt[i + 2]], Vector3.DOWN, false)
	return _commit(st)

# ── terrain ─────────────────────────────────────────────────────────────────
## Faceted ground. `height(ix, iz)` gives vertex heights, `solid(ix, iz)` says whether the
## CELL (ix, iz) exists (cells outside leave ragged holes/edges). Boundary edges get a jagged
## skirt hanging down so the ground reads as a solid chunk, not a paper sheet.
static func grid_mesh(height: Callable, solid: Callable, x0: float, z0: float, cell: float, nx: int, nz: int, rng_seed: int, skirt: float = 1.2) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var made: int = 0
	for iz in nz:
		for ix in nx:
			if not solid.call(ix, iz):
				continue
			var p00 := Vector3(x0 + ix * cell, height.call(ix, iz), z0 + iz * cell)
			var p10 := Vector3(x0 + (ix + 1) * cell, height.call(ix + 1, iz), z0 + iz * cell)
			var p01 := Vector3(x0 + ix * cell, height.call(ix, iz + 1), z0 + (iz + 1) * cell)
			var p11 := Vector3(x0 + (ix + 1) * cell, height.call(ix + 1, iz + 1), z0 + (iz + 1) * cell)
			# Alternate the diagonal so facets do not line up like a grid
			if (ix + iz + rng.randi_range(0, 1)) % 2 == 0:
				_tri(st, p00, p10, p11, Vector3.UP, false)
				_tri(st, p00, p11, p01, Vector3.UP, false)
			else:
				_tri(st, p00, p10, p01, Vector3.UP, false)
				_tri(st, p10, p11, p01, Vector3.UP, false)
			made += 1
			# Skirts on open sides
			var edges: Array = [
				[Vector2i(0, -1), p00, p10],
				[Vector2i(0, 1), p01, p11],
				[Vector2i(-1, 0), p00, p01],
				[Vector2i(1, 0), p10, p11],
			]
			for e in edges:
				var d: Vector2i = e[0]
				var nxi: int = ix + d.x
				var nzi: int = iz + d.y
				var open: bool = nxi < 0 or nzi < 0 or nxi >= nx or nzi >= nz or not solid.call(nxi, nzi)
				if open:
					var a: Vector3 = e[1]
					var b: Vector3 = e[2]
					var da: float = skirt * rng.randf_range(0.4, 1.3)
					var db: float = skirt * rng.randf_range(0.4, 1.3)
					var out_dir := Vector3(d.x, 0.0, d.y)
					_tri(st, a, b, b + Vector3(0, -db, 0), out_dir, false)
					_tri(st, a, b + Vector3(0, -db, 0), a + Vector3(0, -da, 0), out_dir, false)
	if made == 0:
		return null
	return _commit(st)

# ── walls ───────────────────────────────────────────────────────────────────
## Wall along a ground path. heights[i] <= 0.12 means "collapsed here": the wall is broken
## into separate runs with a gap, each run capped. Lean tips the top sideways; vertices are
## jittered so no edge is straight.
static func wall_mesh(path: PackedVector3Array, heights: PackedFloat32Array, thickness: float, lean: float, rng_seed: int) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed
	var n: int = path.size()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# per-sample corners: [front_bottom, front_top, back_top, back_bottom]
	var corners: Array = []
	for i in n:
		var d: Vector3
		if i == 0:
			d = path[1] - path[0]
		elif i == n - 1:
			d = path[n - 1] - path[n - 2]
		else:
			d = path[i + 1] - path[i - 1]
		d.y = 0.0
		d = d.normalized()
		var side := Vector3(-d.z, 0.0, d.x)
		var g: Vector3 = path[i]
		var h: float = heights[i]
		var th: float = thickness * rng.randf_range(0.8, 1.2)
		var tip: Vector3 = side * lean * h + Vector3(rng.randf_range(-0.06, 0.06), rng.randf_range(-0.12, 0.12), rng.randf_range(-0.06, 0.06))
		var low := Vector3(0.0, -0.35, 0.0)
		corners.append([
			g + side * th * 0.5 + low,
			g + side * th * 0.5 * rng.randf_range(0.7, 1.0) + Vector3(0, h, 0) + tip,
			g - side * th * 0.5 * rng.randf_range(0.7, 1.0) + Vector3(0, h, 0) + tip,
			g - side * th * 0.5 + low,
		])
	var i: int = 0
	while i < n - 1:
		if heights[i] <= 0.12:
			i += 1
			continue
		# a run of solid samples [start, end]
		var start: int = i
		var stop: int = i
		while stop + 1 < n and heights[stop + 1] > 0.12:
			stop += 1
		if stop > start:
			for k in range(start, stop):
				var a: Array = corners[k]
				var b: Array = corners[k + 1]
				var mid: Vector3 = (path[k] + path[k + 1]) * 0.5 + Vector3(0, 0.5 * (heights[k] + heights[k + 1]) * 0.5, 0)
				# front, back, top
				_quad(st, a[0], a[1], b[1], b[0], (a[0] + b[1]) * 0.5 - mid)
				_quad(st, a[3], a[2], b[2], b[3], (a[3] + b[2]) * 0.5 - mid)
				_quad(st, a[1], a[2], b[2], b[1], Vector3.UP)
			var c0: Array = corners[start]
			var c1: Array = corners[stop]
			_quad(st, c0[0], c0[1], c0[2], c0[3], path[start] - path[mini(start + 1, n - 1)])
			_quad(st, c1[0], c1[1], c1[2], c1[3], path[stop] - path[maxi(stop - 1, 0)])
		i = stop + 1
	return _commit(st)

static func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, outward: Vector3) -> void:
	_tri(st, a, b, c, outward, false)
	_tri(st, a, c, d, outward, false)

# ── rubble ──────────────────────────────────────────────────────────────────
## Low-poly broken lump: a coarse sphere with jittered, non-uniformly scaled vertices.
static func chunk_mesh(size: Vector3, rng_seed: int) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed
	var sph := SphereMesh.new()
	sph.radial_segments = 7
	sph.rings = 4
	sph.radius = 1.0
	sph.height = 2.0
	var arrays: Array = sph.get_mesh_arrays()
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var moved: Dictionary = {}
	var out_v := PackedVector3Array()
	for v in verts:
		var key := Vector3i(roundi(v.x * 100.0), roundi(v.y * 100.0), roundi(v.z * 100.0))
		if not moved.has(key):
			var k: float = rng.randf_range(0.65, 1.25)
			moved[key] = Vector3(v.x * size.x, maxf(v.y, -0.25) * size.y, v.z * size.z) * k
		out_v.append(moved[key])
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(0, idx.size(), 3):
		var a: Vector3 = out_v[idx[i]]
		var b: Vector3 = out_v[idx[i + 1]]
		var c: Vector3 = out_v[idx[i + 2]]
		if (b - a).cross(c - a).length_squared() < 1e-7:
			continue
		_tri(st, a, b, c, (a + b + c) / 3.0, false)
	return _commit(st)
