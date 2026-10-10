extends Node2D

const TILE := 24
const WORLD_WIDTH := 240
const WORLD_DEPTH := 46
const GRAVITY := 1150.0
const WALK_SPEED := 255.0
const JUMP_SPEED := -455.0
const SAVE_PATH := "user://deepwild_save.json"

var player := Vector2(320.0, 240.0)
var velocity := Vector2.ZERO
var camera_offset := Vector2.ZERO
var on_ground := false
var facing := 1
var move_axis := 0.0
var joystick_id := -1
var joystick_origin := Vector2.ZERO
var joystick_current := Vector2.ZERO
var mouse_joystick := false
var jump_requested := false
var mine_requested := false
var attack_requested := false
const MAX_STACK := 99
const RECIPES := ["Torch", "Planks", "Campfire"]
var inventory := {"Wood": 0, "Stone": 0, "Copper": 0, "Dirt": 0, "Sand": 0, "Snow": 0, "Torch": 0, "Planks": 0, "Campfire": 0, "Wild Essence": 0}
var world_blocks: Dictionary = {}
var harvested_trees: Dictionary = {}
var tree_health: Dictionary = {}
var placed_objects: Dictionary = {}
var craft_recipe_index := 0
var slimes: Array[Vector2] = []
var health := 100
var day_time := 0.0
var day_count := 1
var message := "Welcome to the Shattered Lands"
var message_timer := 4.0
var save_timer := 0.0
var world_seed := 0
var player_respawn := Vector2(320.0, 240.0)
var checkpoint_tile := -1
var campfire_heal_timer := 0.0

func _ready() -> void:
	randomize()
	world_seed = randi()
	_load_world()
	if slimes.is_empty():
		slimes = [Vector2(520, 0), Vector2(890, 0), Vector2(1260, 0)]
	for slime in slimes:
		slime.y = _ground_surface_y(int(floor(slime.x / TILE))) - 12
	set_process(true)

func _process(delta: float) -> void:
	var next_day_time: float = day_time + delta * 0.018
	if next_day_time >= TAU:
		day_count += 1
		message = "Day %d begins" % day_count
		message_timer = 2.0
	day_time = fmod(next_day_time, TAU)
	message_timer = maxf(0.0, message_timer - delta)
	save_timer += delta
	if save_timer >= 12.0:
		save_timer = 0.0
		_save_world()
	_update_player(delta)
	_update_slimes(delta)
	_update_campfire_rest(delta)
	if mine_requested:
		_mine_block()
		mine_requested = false
	if attack_requested:
		_attack()
		attack_requested = false
	if jump_requested and on_ground:
		velocity.y = JUMP_SPEED
		on_ground = false
	jump_requested = false
	camera_offset = player - get_viewport_rect().size * 0.5
	camera_offset.x = clampf(camera_offset.x, 0.0, WORLD_WIDTH * TILE - get_viewport_rect().size.x)
	camera_offset.y = clampf(camera_offset.y, -160.0, WORLD_DEPTH * TILE - get_viewport_rect().size.y)
	queue_redraw()

func _update_player(delta: float) -> void:
	var keyboard_axis := Input.get_axis("ui_left", "ui_right")
	if absf(keyboard_axis) > 0.1:
		move_axis = keyboard_axis
	velocity.x = move_axis * WALK_SPEED
	if absf(move_axis) > 0.1:
		facing = 1 if move_axis > 0.0 else -1
	velocity.y += GRAVITY * delta
	player += velocity * delta
	var ground := _ground_surface_y(int(floor(player.x / TILE)))
	if player.y >= ground:
		player.y = ground
		velocity.y = 0.0
		on_ground = true
	else:
		on_ground = false
	player.x = clampf(player.x, 24.0, WORLD_WIDTH * TILE - 24.0)
	if Input.is_action_just_pressed("ui_accept"):
		jump_requested = true
	if Input.is_key_pressed(KEY_E):
		if Input.is_action_just_pressed("ui_select"):
			mine_requested = true

func _update_slimes(delta: float) -> void:
	for i in range(slimes.size()):
		var slime: Vector2 = slimes[i]
		var distance := player.x - slime.x
		if absf(distance) < 330.0:
			slime.x += signf(distance) * 42.0 * delta
		if absf(distance) < 30.0 and absf(player.y - slime.y) < 45.0:
			health = maxi(0, health - 1) if randf() < delta * 0.8 else health
		slime.y = _ground_surface_y(int(floor(slime.x / TILE))) - 12.0
		slimes[i] = slime
	if health <= 0:
		_respawn_player()

func _noise_value(x: int, salt: int) -> float:
	var value := sin(float(x * 127 + int(world_seed % 997) + salt * 31) * 12.9898) * 43758.5453
	return value - floor(value)

func biome_at(tile_x: int) -> String:
	var region := int(floor(float(tile_x) / 34.0))
	var roll := _noise_value(region, 17)
	if roll < 0.22:
		return "desert"
	if roll < 0.43:
		return "snow"
	if roll < 0.72:
		return "forest"
	return "plains"

func ground_y_at(tile_x: int) -> float:
	var biome := biome_at(tile_x)
	var hills := sin(float(tile_x) * 0.075) * 3.0 + sin(float(tile_x) * 0.021) * 5.0
	if biome == "forest":
		hills += sin(float(tile_x) * 0.21) * 1.8
	elif biome == "desert":
		hills += sin(float(tile_x) * 0.14) * 1.1
	elif biome == "snow":
		hills += sin(float(tile_x) * 0.12) * 2.2
	return 17.0 + hills

func _ground_surface_y(tile_x: int) -> float:
	var safe_x: int = clampi(tile_x, 0, WORLD_WIDTH - 1)
	for tile_y in range(WORLD_DEPTH):
		var kind: String = block_type(safe_x, tile_y)
		if kind != "":
			return float(tile_y * TILE) - 2.0
	return float(WORLD_DEPTH * TILE)

func block_type(tile_x: int, tile_y: int) -> String:
	var key := str(tile_x) + ":" + str(tile_y)
	if world_blocks.has(key):
		return str(world_blocks[key])
	var surface := int(round(ground_y_at(tile_x)))
	if tile_y < surface:
		return ""
	if tile_y == surface:
		var biome := biome_at(tile_x)
		if biome == "desert":
			return "sand"
		if biome == "snow":
			return "snow"
		return "grass"
	if tile_y > surface + 5 and tile_y < WORLD_DEPTH - 4 and _is_cave(tile_x, tile_y):
		return ""
	if tile_y < surface + 5:
		var biome := biome_at(tile_x)
		if biome == "desert":
			return "sandstone"
		if biome == "snow":
			return "permafrost"
		return "dirt"
	if tile_y < WORLD_DEPTH - 3:
		if _noise_value(tile_x * 3 + tile_y * 7, 41) > 0.965:
			return "copper_ore"
		return "stone"
	return "bedrock"

func _is_cave(tile_x: int, tile_y: int) -> bool:
	var a := sin(float(tile_x) * 0.31 + float(world_seed % 113) * 0.04)
	var b := sin(float(tile_y) * 0.57 + float(tile_x) * 0.13)
	var c := sin(float(tile_x + tile_y) * 0.19)
	return a + b + c > 1.55

func _add_item(item: String, amount: int) -> int:
	if amount <= 0:
		return 0
	if not inventory.has(item):
		inventory[item] = 0
	var current := int(inventory[item])
	var added := mini(amount, MAX_STACK - current)
	inventory[item] = current + added
	if added < amount:
		message = item + " stack full!"
		message_timer = 1.5
	return added

func _remove_item(item: String, amount: int) -> bool:
	if amount < 0 or int(inventory.get(item, 0)) < amount:
		return false
	inventory[item] = int(inventory.get(item, 0)) - amount
	return true

func _tree_exists(tx: int) -> bool:
	if harvested_trees.has(str(tx)):
		return false
	var biome := biome_at(tx)
	if biome == "desert":
		return tx % 11 == 4
	if biome == "snow":
		return tx % 8 == 2
	if biome == "forest":
		return tx % 5 == 2
	return tx % 9 == 2

func _chop_tree() -> bool:
	var player_tile := int(floor(player.x / TILE))
	var target := player_tile + facing
	var best_tile := -1
	var best_distance := 999
	for tx in range(maxi(0, player_tile - 2), mini(WORLD_WIDTH, player_tile + 3)):
		if not _tree_exists(tx):
			continue
		var distance: int = absi(tx - target)
		if distance < best_distance and distance <= 2:
			best_distance = distance
			best_tile = tx
	if best_tile == -1:
		return false
	var key := str(best_tile)
	var hp := int(tree_health.get(key, 3)) - 1
	if hp > 0:
		tree_health[key] = hp
		message = "Tree chopped: %d/3" % (3 - hp)
		message_timer = 1.0
	else:
		tree_health.erase(key)
		harvested_trees[key] = true
		var wood_added := _add_item("Wood", 3)
		message = "Tree felled! +%d Wood" % wood_added
		message_timer = 1.8
	return true

func _mine_block() -> void:
	if _chop_tree():
		return
	var tx := int(floor((player.x + facing * 42.0) / TILE))
	var ty := int(floor((player.y + 10.0) / TILE))
	var candidates := [Vector2i(tx, ty), Vector2i(tx, ty - 1), Vector2i(tx, ty + 1), Vector2i(int(player.x / TILE), ty)]
	for cell in candidates:
		var kind := block_type(cell.x, cell.y)
		if kind == "" or kind == "bedrock":
			continue
		world_blocks[str(cell.x) + ":" + str(cell.y)] = ""
		var drop := "Stone"
		if kind == "copper_ore":
			drop = "Copper"
		elif kind == "grass" or kind == "dirt":
			drop = "Dirt"
		elif kind == "sand" or kind == "sandstone":
			drop = "Sand"
		elif kind == "snow":
			drop = "Snow"
		elif kind == "planks":
			drop = "Planks"
		var added := _add_item(drop, 1)
		message = "+%d %s" % [added, drop] if added > 0 else "Inventory stack full"
		message_timer = 1.2
		return
	message = "Move close to a block or tree"
	message_timer = 1.5

func _attack() -> void:
	for i in range(slimes.size() - 1, -1, -1):
		if absf(slimes[i].x - (player.x + facing * 28.0)) < 62.0 and absf(slimes[i].y - player.y) < 65.0:
			slimes.remove_at(i)
			var essence_added := _add_item("Wild Essence", 1)
			message = "Slime defeated! +%d Wild Essence" % essence_added
			message_timer = 2.0
			return
	message = "Swing!"
	message_timer = 0.7

func _input(event: InputEvent) -> void:
	var size := get_viewport_rect().size
	if event is InputEventScreenTouch:
		if event.pressed:
			if event.position.x < size.x * 0.48 and joystick_id == -1:
				joystick_id = event.index
				joystick_origin = event.position
				joystick_current = event.position
				_update_joystick_axis()
			else:
				_handle_action_touch(event.position)
		else:
			if event.index == joystick_id:
				joystick_id = -1
				move_axis = 0.0
	elif event is InputEventScreenDrag and event.index == joystick_id:
		joystick_current = event.position
		_update_joystick_axis()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if event.position.x < size.x * 0.48:
				mouse_joystick = true
				joystick_origin = event.position
				joystick_current = event.position
				_update_joystick_axis()
			else:
				_handle_action_touch(event.position)
		else:
			mouse_joystick = false
			move_axis = 0.0
	elif event is InputEventMouseMotion and mouse_joystick:
		joystick_current = event.position
		_update_joystick_axis()
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F:
			mine_requested = true
		elif event.keycode == KEY_X:
			attack_requested = true
		elif event.keycode == KEY_SPACE:
			jump_requested = true

func _update_joystick_axis() -> void:
	var delta := joystick_current.x - joystick_origin.x
	move_axis = clampf(delta / 62.0, -1.0, 1.0)
	if absf(delta) < 10.0:
		move_axis = 0.0

func _handle_action_touch(pos: Vector2) -> void:
	var size := get_viewport_rect().size
	var base := size - Vector2(105, 108)
	if pos.distance_to(base + Vector2(-110, -8)) < 54.0:
		jump_requested = true
	elif pos.distance_to(base + Vector2(0, -112)) < 54.0:
		attack_requested = true
	elif pos.distance_to(base + Vector2(-112, -112)) < 54.0:
		mine_requested = true
	elif pos.distance_to(Vector2(size.x - 72, 74)) < 55.0:
		_craft_selected()
	elif pos.distance_to(Vector2(size.x - 72, 158)) < 45.0:
		_next_recipe()
	elif pos.distance_to(Vector2(size.x - 72, 242)) < 45.0:
		_use_selected_item()
	elif pos.distance_to(Vector2(size.x - 72, 326)) < 45.0:
		_set_checkpoint()

func _next_recipe() -> void:
	craft_recipe_index = (craft_recipe_index + 1) % RECIPES.size()
	message = "Recipe: " + RECIPES[craft_recipe_index]
	message_timer = 1.4

func _use_selected_item() -> void:
	var recipe: String = str(RECIPES[craft_recipe_index])
	var player_tile: int = int(floor(player.x / TILE))
	var target_tx: int = clampi(player_tile + facing, 0, WORLD_WIDTH - 1)
	var target_ty: int = int(floor((player.y + 10.0) / TILE))
	if recipe == "Torch" or recipe == "Campfire":
		if int(inventory.get(recipe, 0)) <= 0:
			message = "No " + recipe + " in inventory"
			message_timer = 1.5
			return
		var object_key: String = str(target_tx)
		if placed_objects.has(object_key):
			message = "There is already an object here"
			message_timer = 1.5
			return
		_remove_item(recipe, 1)
		placed_objects[object_key] = recipe
		message = recipe + " placed"
		message_timer = 1.5
	elif recipe == "Planks":
		if int(inventory.get("Planks", 0)) <= 0:
			message = "No Planks in inventory"
			message_timer = 1.5
			return
		var block_key: String = str(target_tx) + ":" + str(target_ty)
		if block_type(target_tx, target_ty) != "":
			message = "Target block is occupied"
			message_timer = 1.5
			return
		_remove_item("Planks", 1)
		world_blocks[block_key] = "planks"
		message = "Plank placed"
		message_timer = 1.5
	message_timer = maxf(message_timer, 1.5)

func _update_campfire_rest(delta: float) -> void:
	if health >= 100:
		campfire_heal_timer = 0.0
		return
	var player_tile: int = int(floor(player.x / TILE))
	var near_fire := false
	for offset in range(-2, 3):
		var object_kind: String = str(placed_objects.get(str(player_tile + offset), ""))
		if object_kind == "Campfire" and absf(float(offset) * TILE) <= 48.0:
			near_fire = true
			break
	if not near_fire:
		campfire_heal_timer = 0.0
		return
	campfire_heal_timer += delta
	if campfire_heal_timer >= 3.0:
		campfire_heal_timer = 0.0
		health = mini(100, health + 5)
		message = "Resting by campfire: +5 HP"
		message_timer = 1.4

func _set_checkpoint() -> void:
	var tile_x: int = clampi(int(floor(player.x / TILE)), 0, WORLD_WIDTH - 1)
	checkpoint_tile = tile_x
	player_respawn = Vector2(float(tile_x * TILE) + TILE * 0.5, _ground_surface_y(tile_x))
	message = "Checkpoint set"
	message_timer = 1.5

func _respawn_player() -> void:
	var respawn_x: float = player_respawn.x
	if checkpoint_tile >= 0:
		respawn_x = float(checkpoint_tile * TILE) + TILE * 0.5
	player.x = clampf(respawn_x, 24.0, WORLD_WIDTH * TILE - 24.0)
	player.y = _ground_surface_y(int(floor(player.x / TILE)))
	velocity = Vector2.ZERO
	health = 100
	message = "Respawned at checkpoint"
	message_timer = 2.0

func _craft_selected() -> void:
	var recipe: String = str(RECIPES[craft_recipe_index])
	if recipe == "Torch":
		if int(inventory["Wood"]) >= 2 and int(inventory["Stone"]) >= 1:
			if int(inventory["Torch"]) >= MAX_STACK:
				message = "Torch stack full"
			else:
				_remove_item("Wood", 2)
				_remove_item("Stone", 1)
				_add_item("Torch", 3)
				message = "Crafted 3 Torches"
		else:
			message = "Torch: need 2 Wood + 1 Stone"
	elif recipe == "Planks":
		if int(inventory["Wood"]) >= 2:
			if int(inventory["Planks"]) >= MAX_STACK:
				message = "Planks stack full"
			else:
				_remove_item("Wood", 2)
				_add_item("Planks", 4)
				message = "Crafted 4 Planks"
		else:
			message = "Planks: need 2 Wood"
	elif recipe == "Campfire":
		if int(inventory["Wood"]) >= 4 and int(inventory["Stone"]) >= 3:
			if int(inventory["Campfire"]) >= MAX_STACK:
				message = "Campfire stack full"
			else:
				_remove_item("Wood", 4)
				_remove_item("Stone", 3)
				_add_item("Campfire", 1)
				message = "Campfire crafted"
		else:
			message = "Campfire: need 4 Wood + 3 Stone"
	message_timer = 1.8

func _draw() -> void:
	var size := get_viewport_rect().size
	var sun := (sin(day_time) + 1.0) * 0.5
	var sky := Color(0.12, 0.18, 0.31).lerp(Color(0.38, 0.68, 0.88), sun)
	draw_rect(Rect2(Vector2.ZERO, size), sky)
	_draw_scenery(size, sun)
	_draw_world(size)
	_draw_player()
	_draw_slimes()
	_draw_hud(size)
	_draw_controls(size)

func _draw_scenery(size: Vector2, sun: float) -> void:
	for i in range(7):
		var x := fposmod(float(i * 260) - camera_offset.x * 0.18, size.x + 300.0) - 120.0
		var h := 95.0 + float((i * 37) % 70)
		var y := size.y * 0.52 - h - camera_offset.y * 0.08
		var c := Color(0.19, 0.35, 0.39).lerp(Color(0.32, 0.49, 0.47), sun)
		draw_colored_polygon(PackedVector2Array([Vector2(x - 130, y + h), Vector2(x, y), Vector2(x + 170, y + h)]), c)
	draw_circle(Vector2(size.x * 0.82, 92), 27.0, Color(1.0, 0.85, 0.53).lerp(Color(0.95, 0.95, 0.83), sun))

func _draw_world(size: Vector2) -> void:
	var start_x := maxi(0, int(floor(camera_offset.x / TILE)) - 2)
	var end_x := mini(WORLD_WIDTH, int(ceil((camera_offset.x + size.x) / TILE)) + 2)
	for tx in range(start_x, end_x):
		var surface := int(round(ground_y_at(tx)))
		var px := float(tx * TILE) - camera_offset.x
		for ty in range(maxi(0, int(floor(camera_offset.y / TILE)) - 1), WORLD_DEPTH):
			var kind := block_type(tx, ty)
			if kind == "":
				continue
			var py := float(ty * TILE) - camera_offset.y
			if py < -TILE or py > size.y + TILE:
				continue
			var rect := Rect2(px, py, TILE, TILE)
			var color := Color(0.35, 0.65, 0.29)
			if kind == "dirt":
				color = Color(0.43, 0.28, 0.19)
			elif kind == "sand":
				color = Color(0.83, 0.72, 0.43)
			elif kind == "sandstone":
				color = Color(0.63, 0.49, 0.29)
			elif kind == "snow":
				color = Color(0.83, 0.90, 0.94)
			elif kind == "permafrost":
				color = Color(0.49, 0.63, 0.68)
			elif kind == "copper_ore":
				color = Color(0.43, 0.36, 0.34)
			elif kind == "planks":
				color = Color(0.63, 0.39, 0.20)
			elif kind == "stone":
				color = Color(0.35, 0.37, 0.40)
			elif kind == "bedrock":
				color = Color(0.16, 0.18, 0.22)
			if kind == "copper_ore":
				draw_rect(Rect2(px + 4, py + 5, 7, 6), Color(0.78, 0.40, 0.22))
				draw_rect(Rect2(px + 14, py + 14, 6, 5), Color(0.78, 0.40, 0.22))
			if ty > surface and tx % 7 == 0 and ty > surface + 7:
				color = Color(0.32, 0.44, 0.49) if kind == "stone" else color
			draw_rect(rect, color)
			draw_rect(Rect2(px, py, TILE, 2), color.lightened(0.15))
			if kind == "stone" and (tx * 13 + ty * 7) % 11 == 0:
				draw_rect(Rect2(px + 6, py + 8, 5, 4), Color(0.71, 0.47, 0.27))
		var ground_screen_y := float(surface * TILE) - camera_offset.y
		var biome := biome_at(tx)
		if _tree_exists(tx) and surface > 0:
			if biome == "desert":
				_draw_cactus(px, ground_screen_y)
			elif biome == "snow":
				_draw_pine(px, ground_screen_y)
			else:
				_draw_tree(px, ground_screen_y)
		var object_key: String = str(tx)
		if placed_objects.has(object_key):
			var object_kind: String = str(placed_objects[object_key])
			if object_kind == "Torch":
				draw_circle(Vector2(px + 12, ground_screen_y - 24), 25.0, Color(1.0, 0.62, 0.20, 0.16))
				draw_rect(Rect2(px + 10, ground_screen_y - 25, 4, 25), Color(0.43, 0.28, 0.16))
				draw_rect(Rect2(px + 9, ground_screen_y - 30, 6, 8), Color(1.0, 0.56, 0.16))
				draw_rect(Rect2(px + 11, ground_screen_y - 34, 3, 5), Color(1.0, 0.85, 0.35))
			elif object_kind == "Campfire":
				draw_rect(Rect2(px + 2, ground_screen_y - 5, 20, 5), Color(0.29, 0.19, 0.13))
				draw_rect(Rect2(px + 4, ground_screen_y - 10, 16, 4), Color(0.45, 0.27, 0.15))
				draw_colored_polygon(PackedVector2Array([Vector2(px + 7, ground_screen_y - 8), Vector2(px + 12, ground_screen_y - 24), Vector2(px + 18, ground_screen_y - 8)]), Color(1.0, 0.39, 0.10))
				draw_colored_polygon(PackedVector2Array([Vector2(px + 10, ground_screen_y - 8), Vector2(px + 13, ground_screen_y - 18), Vector2(px + 16, ground_screen_y - 8)]), Color(1.0, 0.78, 0.22))

func _draw_cactus(x: float, y: float) -> void:
	draw_rect(Rect2(x + 9, y - 45, 7, 45), Color(0.18, 0.49, 0.29))
	draw_rect(Rect2(x + 1, y - 33, 8, 6), Color(0.21, 0.55, 0.32))
	draw_rect(Rect2(x + 1, y - 41, 6, 14), Color(0.21, 0.55, 0.32))
	draw_rect(Rect2(x + 16, y - 28, 7, 6), Color(0.21, 0.55, 0.32))
	draw_rect(Rect2(x + 17, y - 37, 6, 15), Color(0.21, 0.55, 0.32))

func _draw_pine(x: float, y: float) -> void:
	draw_rect(Rect2(x + 10, y - 62, 7, 62), Color(0.34, 0.25, 0.18))
	draw_colored_polygon(PackedVector2Array([Vector2(x - 10, y - 28), Vector2(x + 13, y - 91), Vector2(x + 35, y - 28)]), Color(0.12, 0.34, 0.31))
	draw_colored_polygon(PackedVector2Array([Vector2(x - 6, y - 48), Vector2(x + 13, y - 108), Vector2(x + 31, y - 48)]), Color(0.16, 0.43, 0.38))

func _draw_tree(x: float, y: float) -> void:
	var trunk := Color(0.31, 0.19, 0.12)
	draw_rect(Rect2(x + 8, y - 65, 9, 66), trunk)
	draw_rect(Rect2(x - 8, y - 87, 42, 38), Color(0.12, 0.39, 0.24))
	draw_rect(Rect2(x - 1, y - 103, 30, 32), Color(0.17, 0.49, 0.27))
	draw_rect(Rect2(x + 3, y - 94, 9, 8), Color(0.31, 0.62, 0.31))

func _draw_player() -> void:
	var p := player - camera_offset
	# Pixel-art explorer: scarf, tunic, boots, hair and tool.
	draw_rect(Rect2(p.x - 10, p.y - 34, 20, 25), Color(0.20, 0.48, 0.76))
	draw_rect(Rect2(p.x - 11, p.y - 12, 9, 14), Color(0.26, 0.22, 0.20))
	draw_rect(Rect2(p.x + 2, p.y - 12, 9, 14), Color(0.26, 0.22, 0.20))
	draw_rect(Rect2(p.x - 11, p.y - 47, 22, 17), Color(0.87, 0.66, 0.46))
	draw_rect(Rect2(p.x - 12, p.y - 50, 24, 8), Color(0.27, 0.17, 0.12))
	draw_rect(Rect2(p.x + facing * 3, p.y - 41, 3, 3), Color(0.13, 0.12, 0.11))
	draw_rect(Rect2(p.x + facing * 13, p.y - 26, 13 * facing, 4), Color(0.72, 0.75, 0.77))

func _draw_slimes() -> void:
	for slime in slimes:
		var p := slime - camera_offset
		draw_rect(Rect2(p.x - 15, p.y - 13, 30, 23), Color(0.25, 0.78, 0.46))
		draw_rect(Rect2(p.x - 10, p.y - 18, 20, 8), Color(0.31, 0.89, 0.55))
		draw_rect(Rect2(p.x - 7, p.y - 5, 4, 5), Color(0.08, 0.15, 0.12))
		draw_rect(Rect2(p.x + 4, p.y - 5, 4, 5), Color(0.08, 0.15, 0.12))

func _draw_hud(size: Vector2) -> void:
	draw_rect(Rect2(16, 16, 350, 164), Color(0.055, 0.08, 0.10, 0.84))
	draw_string(ThemeDB.fallback_font, Vector2(30, 42), "DEEPWILD", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(0.91, 0.83, 0.57))
	draw_string(ThemeDB.fallback_font, Vector2(30, 65), "HP", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)
	draw_rect(Rect2(62, 52, 150, 15), Color(0.28, 0.15, 0.16))
	draw_rect(Rect2(62, 52, 150.0 * float(health) / 100.0, 15), Color(0.84, 0.25, 0.26))
	draw_string(ThemeDB.fallback_font, Vector2(30, 91), "WOOD %d STONE %d COPPER %d" % [inventory["Wood"], inventory["Stone"], inventory["Copper"]], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.88, 0.90, 0.82))
	draw_string(ThemeDB.fallback_font, Vector2(30, 108), "DIRT %d SAND %d SNOW %d TORCH %d" % [inventory["Dirt"], inventory["Sand"], inventory["Snow"], inventory["Torch"]], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.88, 0.90, 0.82))
	draw_string(ThemeDB.fallback_font, Vector2(30, 126), "PLANKS %d  CAMPFIRE %d  ESSENCE %d" % [inventory["Planks"], inventory["Campfire"], inventory["Wild Essence"]], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.88, 0.90, 0.82))
	draw_string(ThemeDB.fallback_font, Vector2(30, 151), "Campfires restore 5 HP every 3 seconds nearby", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.98, 0.75, 0.42))
	draw_string(ThemeDB.fallback_font, Vector2(size.x - 18, 49), "RECIPE: " + RECIPES[craft_recipe_index].to_upper(), HORIZONTAL_ALIGNMENT_RIGHT, -1, 12, Color(1.0, 0.91, 0.69))
	draw_string(ThemeDB.fallback_font, Vector2(size.x - 18, 28), "DAY %d  •  %s" % [day_count, biome_at(int(player.x / TILE)).to_upper()], HORIZONTAL_ALIGNMENT_RIGHT, -1, 14, Color.WHITE)
	if message_timer > 0.0:
		var width := minf(size.x - 40.0, 510.0)
		draw_rect(Rect2((size.x - width) * 0.5, 34, width, 38), Color(0.05, 0.07, 0.08, 0.82))
		draw_string(ThemeDB.fallback_font, Vector2(size.x * 0.5, 59), message, HORIZONTAL_ALIGNMENT_CENTER, width - 16, 16, Color(1.0, 0.91, 0.69))

func _draw_controls(size: Vector2) -> void:
	var center := Vector2(100, size.y - 112)
	draw_circle(center, 62, Color(0.04, 0.07, 0.08, 0.36))
	draw_circle(center, 34, Color(0.68, 0.76, 0.76, 0.18))
	var knob := center
	if joystick_id != -1 or mouse_joystick:
		knob = center + Vector2(clampf(move_axis, -1.0, 1.0) * 27.0, 0)
	draw_circle(knob, 23, Color(0.83, 0.89, 0.84, 0.58))
	var base := size - Vector2(105, 108)
	_draw_button(base + Vector2(-110, -8), "JUMP", Color(0.28, 0.58, 0.78))
	_draw_button(base + Vector2(0, -112), "HIT", Color(0.77, 0.35, 0.28))
	_draw_button(base + Vector2(-112, -112), "MINE", Color(0.68, 0.53, 0.25))
	_draw_button(Vector2(size.x - 72, 74), "MAKE", Color(0.32, 0.56, 0.39))
	_draw_button(Vector2(size.x - 72, 158), "NEXT", Color(0.40, 0.48, 0.57))
	_draw_button(Vector2(size.x - 72, 242), "USE", Color(0.68, 0.46, 0.25))
	_draw_button(Vector2(size.x - 72, 326), "CAMP", Color(0.43, 0.58, 0.35))

func _draw_button(center: Vector2, label: String, color: Color) -> void:
	draw_circle(center, 36, Color(0.04, 0.06, 0.07, 0.52))
	draw_circle(center, 29, color.darkened(0.1))
	draw_string(ThemeDB.fallback_font, center + Vector2(0, 5), label, HORIZONTAL_ALIGNMENT_CENTER, 72, 12, Color.WHITE)

func _save_world() -> void:
	var data := {"world_seed": world_seed, "player_x": player.x, "player_y": player.y, "health": health, "day_count": day_count, "day_time": day_time, "checkpoint_tile": checkpoint_tile, "inventory": inventory, "blocks": world_blocks, "harvested_trees": harvested_trees, "tree_health": tree_health, "placed_objects": placed_objects, "craft_recipe_index": craft_recipe_index, "slimes": []}
	for slime in slimes:
		data["slimes"].append([slime.x, slime.y])
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data))

func _load_world() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	world_seed = int(parsed.get("world_seed", world_seed))
	player = Vector2(float(parsed.get("player_x", 320.0)), float(parsed.get("player_y", 240.0)))
	health = int(parsed.get("health", 100))
	day_count = maxi(1, int(parsed.get("day_count", 1)))
	day_time = fposmod(float(parsed.get("day_time", day_time)), TAU)
	checkpoint_tile = int(parsed.get("checkpoint_tile", -1))
	if checkpoint_tile >= 0:
		checkpoint_tile = clampi(checkpoint_tile, 0, WORLD_WIDTH - 1)
		player_respawn = Vector2(float(checkpoint_tile * TILE) + TILE * 0.5, _ground_surface_y(checkpoint_tile))
	var saved_inventory = parsed.get("inventory", {})
	for key in inventory:
		inventory[key] = int(saved_inventory.get(key, inventory[key]))
	world_blocks = parsed.get("blocks", {})
	harvested_trees = parsed.get("harvested_trees", {})
	tree_health = parsed.get("tree_health", {})
	placed_objects = parsed.get("placed_objects", {})
	craft_recipe_index = clampi(int(parsed.get("craft_recipe_index", 0)), 0, RECIPES.size() - 1)
	slimes.clear()
	for item in parsed.get("slimes", []):
		if item is Array and item.size() >= 2:
			slimes.append(Vector2(float(item[0]), float(item[1])))
