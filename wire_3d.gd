@tool
class_name Wire3D
extends Node3D

@export var start_node: NodePath
@export var end_node: NodePath
@export var start_offset: Vector3 = Vector3.ZERO
@export var end_offset: Vector3 = Vector3.ZERO
@export var radius: float = 0.02
@export var wire_color: Color = Color(0.2, 0.6, 1.0)
@export var curve_strength: float = 0.3
@export var segments: int = 32          # smoothness along length
@export var radial_segments: int = 12   # roundness of tube cross-section

var start_obj: Node3D
var end_obj: Node3D
var mesh_inst: MeshInstance3D
var material: StandardMaterial3D

func _ready():
	mesh_inst = MeshInstance3D.new()
	add_child(mesh_inst)
	
	material = StandardMaterial3D.new()
	material.albedo_color = wire_color
	material.roughness = 0.3
	material.metallic = 0.8
	mesh_inst.material_override = material

	if not Engine.is_editor_hint():
		start_obj = get_node_or_null(start_node) as Node3D
		end_obj = get_node_or_null(end_node) as Node3D
		if start_obj and end_obj:
			set_process(true)
		else:
			set_process(false)

func _process(_delta):
	update_wire()

func update_wire():
	if not start_obj or not end_obj:
		return
	
	var p0 = start_obj.global_position + start_offset
	var p3 = end_obj.global_position + end_offset
	
	global_position = (p0 + p3) * 0.5  # center wire for cleaner transform
	
	var rel_p0 = to_local(p0)
	var rel_p3 = to_local(p3)
	
	var dir = (rel_p3 - rel_p0).normalized()
	var length = rel_p3.distance_to(rel_p0)
	
	# Perpendicular vector for curve (fallback to RIGHT if UP is parallel)
	var perp = dir.cross(Vector3.UP).normalized()
	if perp.length_squared() < 0.001:
		perp = dir.cross(Vector3.RIGHT).normalized()
	
	var rel_p1 = rel_p0 + perp * length * curve_strength
	var rel_p2 = rel_p3 - perp * length * curve_strength
	
	# Generate centerline points
	var center_points: Array[Vector3] = []
	center_points.resize(segments + 1)
	for i in range(segments + 1):
		var t = float(i) / segments
		center_points[i] = _bezier_cubic(rel_p0, rel_p1, rel_p2, rel_p3, t)

	# Build tube geometry using SurfaceTool
	var rings: Array = []
	for i in range(segments + 1):
		var p = center_points[i]
		# Tangent: prefer forward, else backward
		var tangent = Vector3.ZERO
		if i < segments:
			tangent = (center_points[i + 1] - p).normalized()
		else:
			tangent = (p - center_points[i - 1]).normalized()
		# Build local frame
		var right = tangent.cross(Vector3.UP).normalized()
		if right.length_squared() < 0.001:
			right = tangent.cross(Vector3.RIGHT).normalized()
		var up = right.cross(tangent).normalized()
		var ring: Array = []
		for j in range(radial_segments):
			var theta = float(j) / radial_segments * TAU
			var offset = right * cos(theta) * radius + up * sin(theta) * radius
			ring.append(p + offset)
		rings.append(ring)

	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	# Connect rings with quads (two triangles each)
	for i in range(segments):
		for j in range(radial_segments):
			var jn = (j + 1) % radial_segments
			var v0 = rings[i][j]
			var v1 = rings[i + 1][j]
			var v2 = rings[i + 1][jn]
			var v3 = rings[i][jn]
			st.add_vertex(v0)
			st.add_vertex(v1)
			st.add_vertex(v2)
			st.add_vertex(v0)
			st.add_vertex(v2)
			st.add_vertex(v3)

	# Optional: add end caps if desired

	st.generate_normals()
	mesh_inst.mesh = st.commit()

# Cubic Bezier
func _bezier_cubic(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, t: float) -> Vector3:
	var omt = 1.0 - t
	return omt*omt*omt*p0 + 3*omt*omt*t*p1 + 3*omt*t*t*p2 + t*t*t*p3

func refresh():
	if start_node and start_node != NodePath():
		start_obj = get_node_or_null(start_node) as Node3D
	if end_node and end_node != NodePath():
		end_obj = get_node_or_null(end_node) as Node3D
	if start_obj and end_obj:
		set_process(true)
		update_wire()
	else:
		set_process(false)


func set_ends(a: Node3D, b: Node3D) -> void:
	start_obj = a
	end_obj = b
	add_to_group("wires")
	set_process(true)
	refresh()
