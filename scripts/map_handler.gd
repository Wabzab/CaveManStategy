extends Node

@onready var map_node: Node2D = $MapNode
@onready var map_size_node: SpinBox = $Camera2D/UI/VBC/HBC/PC/VBC/MapSize/SpinBox
@onready var noise_type_node: SpinBox = $Camera2D/UI/VBC/HBC/PC/VBC/NoiseType/SpinBox
@onready var fractal_type_node: SpinBox = $Camera2D/UI/VBC/HBC/PC/VBC/FractalType/SpinBox
@onready var freqeuncy_node: SpinBox = $Camera2D/UI/VBC/HBC/PC/VBC/Frequency/SpinBox
@onready var globals = get_node("/root/Globals")

@onready var hex_scene = preload("res://scenes/hex_tile.tscn")

@export var map_size : int = 10
@export var map_scale : float = 1
@export_group("Height Map Settings")
@export_range(0,1) var deep_water : float = 0.1 
@export_range(0,1) var mid_water : float = 0.3 
@export_range(0,1) var shallow_water : float = 0.45
@export_range(0,100) var flower_chance : int = 25
@export_range(0,5) var noise_type : int = 0
@export_range(0,3) var fractal_type : int = 0
@export_range(1, 100) var frequency : int = 1
@export_group("Temperature Map Settings")
@export_range(0,1) var snow: float = 0.1
@export_range(0,1) var tundra: float = 0.3
@export_range(0,1) var grassland: float = 0.7
@export_group("Hexagon Settings")
@export var tile_width: int = 126
@export var tile_height: int = 144

var map = []


###
# Create a pool of hextiles that are used to build the map and reused on regeneration
###


func _ready():
	#Initial map generation
	InitialiseMap(map_size)

func _input(event):
	#Regenerate map on demand
	if event.is_action_pressed("reload"):
		_on_button_pressed()

func InitialiseMap(size: int):
	for x in range(size):
		map.append([])
		for y in range(size):
			map[x].append(null)
	
	var world_map = await GenerateNewMap(size)
	SetMap(world_map)
	DrawMap()
	map_node.scale = Vector2(map_scale, map_scale)

func GenerateNewMap(size: int):
	var height_map: Image = await GenerateHeightMap(size)
	var temp_map: Image = await GenerateTemperatureMap(size)
	var world_map: Array = EvaluateWorldMap(height_map, temp_map, size)
	return world_map

func GenerateHeightMap(size: int):
	# ----- || Gen Height Map || ----- #
	var height_map = NoiseTexture2D.new()
	height_map.noise = FastNoiseLite.new()
	height_map.noise.seed = randi()
	height_map.noise.set_noise_type(noise_type)
	height_map.noise.set_fractal_type(fractal_type)
	height_map.noise.set_frequency(frequency/100.0)
	height_map.width = size
	height_map.height = size
	await height_map.changed
	var height_image = height_map.get_image()
	return height_image
	# ----- ||    Complete    || ----- #

func GenerateTemperatureMap(size: int):
	# ----- || Gen Temp Map || ----- #
	var temp_map = NoiseTexture2D.new()
	temp_map.noise = FastNoiseLite.new()
	temp_map.noise.seed = randi()
	temp_map.width = size
	temp_map.height = size
	await temp_map.changed # causing freed object emitting signal error? prob engine issue
	var temp_image = temp_map.get_image()
	return temp_image
	# ----- ||   Complete   || ----- #

func EvaluateWorldMap(height_map: Image, temp_map: Image, size: int):
	# ----- World Map ----- #
	var world_map: Array = []
	for x in range(size):
		world_map.append([])
		for y in range(size):
			world_map[x].append(0)
	# ----- | Done! | ----- #
	
	# ----- Evaluate World ----- #
	for x in range(size):
		for y in range(size):
			var height = height_map.get_pixel(x, y).r
			var temp = temp_map.get_pixel(x, y).r
			
			if height < deep_water:
				world_map[x][y] = globals.TileType.OCEAN_DEEP
			elif height < mid_water:
				world_map[x][y] = globals.TileType.OCEAN_MID
			elif height < shallow_water:
				world_map[x][y] = globals.TileType.OCEAN_SHALLOW
			elif temp < snow:
				world_map[x][y] = globals.TileType.SNOW
			elif temp < tundra:
				world_map[x][y] = globals.TileType.TUNDRA
			elif temp < grassland:
				if randi()%100 < flower_chance:
					world_map[x][y] = globals.TileType.GRASSLAND_FLOWER
				else:
					world_map[x][y] = globals.TileType.GRASSLAND
			else:
				world_map[x][y] = globals.TileType.DESERT
	return world_map
	# ----- |    Done    | ----- #

func SetMap(world_map: Array):
	for x in range(world_map.size()):
		for y in range(world_map.size()):
			var new_tile = hex_scene.instantiate()
			new_tile.SetTile(world_map[x][y], globals)
			map[x][y] = new_tile

func DrawMap():
	for y in range(map.size()):
		for x in range(map.size()):
			var delta_x: int = (tile_width * x) + (tile_width/2 * (y%2))
			var delta_y: int = (tile_height/1.3 * y)
			var pos = Vector2i(delta_x, delta_y)
			map[x][y].position = pos
			map_node.add_child(map[x][y])

func ClearMap():
	map.clear()
	for child in map_node.get_children():
		child.free()


func _on_button_pressed():
	map_size = map_size_node.value
	noise_type = noise_type_node.value
	fractal_type = fractal_type_node.value
	frequency = freqeuncy_node.value
	ClearMap()
	InitialiseMap(map_size)
