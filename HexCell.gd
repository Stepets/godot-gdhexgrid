"""
	A single cell of a hexagonal grid.
	
	There are many ways to orient a hex grid, this library was written
	with the following assumptions:
	
	* The hexes use a flat-topped orientation;
	* Axial coordinates use +x => NE; +y => N;
	* Offset coords have odd rows shifted up half a step.
	
	Using x,y instead of the reference's preferred x,z for axial coords makes
	following along with the reference a little more tricky, but is less confusing
	when using Godot's Vector2(x, y) objects.
	
	
	## Usage:
	
	#### var cube_coords; var axial_coords; var offset_coords

		Cube coordinates are used internally as the canonical representation, but
		both axial and offset coordinates can be read and modified through these
		properties.
	
	#### func get_adjacent(direction)
	
		Returns the neighbouring HexCell in the given direction.
		
		The direction should be one of the DIR_N, DIR_NE, DIR_SE, DIR_S, DIR_SW, or
		DIR_NW constants provided by the HexCell class.
	
	#### func get_all_adjacent()
	
		Returns an array of the six HexCell instances neighbouring this one.
	
	#### func get_all_within(distance)
	
		Returns an array of all the HexCells within the given number of steps,
		including the current hex.
	
	#### func get_ring(distance)
	
		Returns an array of all the HexCells at the given distance from the current.
	
	#### func distance_to(target)
	
		Returns the number of hops needed to get from this hex to the given target.
		
		The target can be supplied as either a HexCell instance, cube or axial
		coordinates.
	
	#### func line_to(target)
	
		Returns an array of all the hexes crossed when drawing a straight line
		between this hex and another.
		
		The target can be supplied as either a HexCell instance, cube or axial
		coordinates.
		
		The items in the array will be in the order of traversal, and include both
		the start (current) hex, as well as the final target.

"""
extends Resource
class_name HexCell
#warning-ignore-all:unused_class_variable

# We use unit-size flat-topped hexes
const size := Vector2(1, sqrt(3)/2)
# Directions of neighbouring cells
const DIR_N := Vector3i(0, 1, -1)
const DIR_NE := Vector3i(1, 0, -1)
const DIR_SE := Vector3i(1, -1, 0)
const DIR_S := Vector3i(0, -1, 1)
const DIR_SW := Vector3i(-1, 0, 1)
const DIR_NW := Vector3i(-1, 1, 0)
const DIR_ALL : Array[Vector3i] = [DIR_N, DIR_NE, DIR_SE, DIR_S, DIR_SW, DIR_NW]


# Cube coords are canonical
var cube_coords := Vector3i(0, 0, 0) : set = set_cube_coords, get = get_cube_coords
# but other coord systems can be used
var axial_coords : Vector2i : set = set_axial_coords, get = get_axial_coords
var offset_coords : set = set_offset_coords, get = get_offset_coords


func _init(cube_coords : Vector3i = Vector3i.ZERO):
	self.cube_coords = cube_coords

static func from_axial(coords : Vector2i) -> HexCell:
	return HexCell.new(axial_to_cube_coords(coords))

static func obj_to_coords(val) -> Vector3i:
	if typeof(val) == TYPE_VECTOR3I:
		return val
	elif typeof(val) == TYPE_VECTOR2I:
		return axial_to_cube_coords(val)
	assert(false, "HexCell.obj_to_coords accepts only Vector2i|Vector3i")
	return Vector3i.ZERO
	
static func axial_to_cube_coords(val : Vector2i) -> Vector3i:
	var x = val.x
	var y = val.y
	return Vector3i(x, y, -x - y)
	
static func round_cube_coords(coords : Vector3) -> Vector3i:
	return axial_to_cube_coords(Vector2i(roundi(coords.x), roundi(coords.y)))

func get_cube_coords() -> Vector3i:
	return cube_coords
	
func set_cube_coords(val : Vector3i) -> void:
	cube_coords = val
	
func get_axial_coords() -> Vector2i:
	return Vector2i(cube_coords.x, cube_coords.y)
	
func set_axial_coords(val : Vector2i) -> void:
	set_cube_coords(axial_to_cube_coords(val))

func axial_with_height(height : int) -> Vector3i:
	return Vector3i(cube_coords.x, height, cube_coords.y)
	
func get_offset_coords() -> Vector2i:
	var x = cube_coords.x
	var y = cube_coords.y
	var off_y = y + (x - (x & 1)) / 2
	return Vector2i(x, off_y)
	
func set_offset_coords(val : Vector2i) -> void:
	# Sets position from a Vector2 of offset coordinates
	var x = val.x
	var y = val.y
	var cube_y = y - (x - (x & 1)) / 2
	self.set_axial_coords(Vector2i(x, cube_y))

func get_adjacent(dir : Vector3i) -> HexCell:
	return HexCell.new(self.cube_coords + dir)
	
func get_all_adjacent() -> Array[HexCell]:
	# Returns an array of HexCell instances representing adjacent locations
	var cells : Array[HexCell]
	for coord in DIR_ALL:
		cells.append(HexCell.new(self.cube_coords + coord))
	return cells
	
func get_all_within(distance : int) -> Array[HexCell]:
	# Returns an array of all HexCell instances within the given distance
	var cells : Array[HexCell]
	for dx in range(-distance, distance+1):
		for dy in range(max(-distance, -distance - dx), min(distance, distance - dx) + 1):
			cells.append(HexCell.new(axial_to_cube_coords(self.axial_coords + Vector2i(dx, dy))))
	return cells
	
func get_ring(distance : int) -> Array[HexCell]:
	# Returns an array of all HexCell instances at the given distance
	if distance < 1:
		return [self]
	# Start at the top (+y) and walk in a clockwise circle
	var cells : Array[HexCell]
	var current = HexCell.new(self.cube_coords + (DIR_N * distance))
	for dir in [DIR_SE, DIR_S, DIR_SW, DIR_NW, DIR_N, DIR_NE]:
		for _step in range(distance):
			cells.append(current)
			current = current.get_adjacent(dir)
	return cells
	
func distance_to(target) -> int:
	target = obj_to_coords(target)
	return int((
			abs(cube_coords.x - target.x)
			+ abs(cube_coords.y - target.y)
			+ abs(cube_coords.z - target.z)
			) / 2)
	
func line_to(target) -> Array[HexCell]:
	# Returns an array of HexCell instances representing
	# a straight path from here to the target, including both ends
	target = obj_to_coords(target)
	var steps = distance_to(target)
	var path = []
	var start := Vector3(cube_coords) + Vector3(1e-6, 2e-6, -3e-6)
	for dist in range(steps + 1):
		var lerped = start.lerp(target, float(dist) / steps)
		path.append(HexCell.new(round_cube_coords(lerped)))
	return path
	
