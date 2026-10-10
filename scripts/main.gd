extends Node2D

const TILE := 24
const TERRAIN_ATLAS: Texture2D = preload("res://assets/terrain_atlas.svg")
const CREATURE_ATLAS: Texture2D = preload("res://assets/creature_atlas.svg")
const HERO_ATLAS: Texture2D = preload("res://assets/hero_atlas.svg")
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
const RECIPES := ["Torch", "Planks", "Campfire", "Healing Salve"]
var inventory := {"Wood": 0, "Stone": 0, "Copper": 0, "Dirt": 0, "Sand": 0, "Snow": 0, "Torch": 0, "Planks": 0, "Campfire": 0, "Wild Essence": 0, "Healing Salve": 0}
var world_blocks: Dictionary = {}
var generated_tile_cache: Dictionary = {}
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
var slime_damage_cooldown := 0.0
var attack_cooldown := 0.0
var slime_spawn_timer := 0.0
var world_save_loaded := false
# Short-lived cosmetic feedback; these values never affect gameplay or saves.
var impact_timer := 0.0
var impact_position := Vector2.ZERO
var impact_kind := "mine"
var pressed_action := ""
var pressed_action_timer := 0.0

func _ready() -> void:
	randomize()
	world_seed = randi()
	_load_world()
	if slimes.is_empty() and not world_save_loaded:
		slimes = [Vector2(520, 0), Vector2(890, 0), Vector2(1260, 0)]
		_save_world()
	for slime in slimes:
		slime.y = _ground_surface_y(int(floor(slime.x / TILE))) - 12
	set_process(true)

func _process(delta: float) -> void:
	slime_damage_cooldown = maxf(0.0, slime_damage_cooldown - delta)
	impact_timer = maxf(0.0, impact_timer - delta)
	pressed_action_timer = maxf(0.0, pressed_action_timer - delta)
	if pressed_action_timer <= 0.0:
		pressed_action = ""
	attack_cooldown = maxf(0.0, attack_cooldown - delta)
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
	if slimes.size() < 3:
		slime_spawn_timer += delta
		if slime_spawn_timer >= 12.0:
			slime_spawn_timer = 0.0
			var spawn_direction := 1.0 if player.x < WORLD_WIDTH * TILE * 0.5 else -1.0
			var spawn_x := clampf(player.x + spawn_direction * 360.0, 24.0, WORLD_WIDTH * TILE - 24.0)
			var spawn_tile := int(floor(spawn_x / TILE))
			var spawn_y := _ground_surface_y(spawn_tile) - 12.0
			slimes.append(Vector2(spawn_x, spawn_y))
			message = "A slime emerged nearby"
			message_timer = 1.8
			_save_world()
	else:
		slime_spawn_timer = 0.0
	for i in range(slimes.size()):
		var slime: Vector2 = slimes[i]
		var distance := player.x - slime.x
		if absf(distance) < 330.0:
			slime.x += signf(distance) * 42.0 * delta
		if absf(distance) < 30.0 and absf(player.y - slime.y) < 45.0 and slime_damage_cooldown <= 0.0:
			health = maxi(0, health - 8)
			impact_position = player
			impact_kind = "damage"
			impact_timer = 0.24
			slime_damage_cooldown = 1.0
			message = "Slime hit! -8 HP"
			message_timer = 1.0
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
	if tile_x < 0 or tile_x >= WORLD_WIDTH or tile_y < 0 or tile_y >= WORLD_DEPTH:
		return ""
	var key := str(tile_x) + ":" + str(tile_y)
	# Player edits override generated terrain; untouched cells are cached so
	# biome noise and cave math are not recalculated every rendered frame.
	if world_blocks.has(key):
		return str(world_blocks[key])
	if generated_tile_cache.has(key):
		return str(generated_tile_cache[key])
	var surface := int(round(ground_y_at(tile_x)))
	var generated := ""
	if tile_y < surface:
		generated = ""
	elif tile_y == surface:
		var surface_biome := biome_at(tile_x)
		if surface_biome == "desert":
			generated = "sand"
		elif surface_biome == "snow":
			generated = "snow"
		else:
			generated = "grass"
	elif tile_y > surface + 5 and tile_y < WORLD_DEPTH - 4 and _is_cave(tile_x, tile_y):
		generated = ""
	elif tile_y < surface + 5:
		var underground_biome := biome_at(tile_x)
		if underground_biome == "desert":
			generated = "sandstone"
		elif underground_biome == "snow":
			generated = "permafrost"
		else:
			generated = "dirt"
	elif tile_y < WORLD_DEPTH - 3:
		generated = "copper_ore" if _noise_value(tile_x * 3 + tile_y * 7, 41) > 0.965 else "stone"
	else:
		generated = "bedrock"
	generated_tile_cache[key] = generated
	return generated

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
	if hp <= 0 and int(inventory.get("Wood", 0)) + 3 > MAX_STACK:
		message = "Need space for 3 Wood; tree not felled"
		message_timer = 1.8
		return true
	if hp > 0:
		tree_health[key] = hp
		message = "Tree chopped: %d/3" % (3 - hp)
		message_timer = 1.0
	else:
		tree_health.erase(key)
		harvested_trees[key] = true
		_add_item("Wood", 3)
		message = "Tree felled! +3 Wood"
		message_timer = 1.8
	_save_world()
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
		if int(inventory.get(drop, 0)) >= MAX_STACK:
			message = drop + " stack full! Block not mined"
			message_timer = 1.5
			return
		impact_position = Vector2(float(cell.x * TILE + TILE / 2), float(cell.y * TILE + TILE / 2))
		impact_kind = "copper" if kind == "copper_ore" else "mine"
		impact_timer = 0.22
		world_blocks[str(cell.x) + ":" + str(cell.y)] = ""
		generated_tile_cache.erase(str(cell.x) + ":" + str(cell.y))
		var added := _add_item(drop, 1)
		message = "+%d %s" % [added, drop]
		message_timer = 1.2
		_save_world()
		return
	message = "Move close to a block or tree"
	message_timer = 1.5

func _attack() -> void:
	if attack_cooldown > 0.0:
		message = "Recovering..."
		message_timer = 0.5
		return
	attack_cooldown = 0.45
	for i in range(slimes.size() - 1, -1, -1):
		if absf(slimes[i].x - (player.x + facing * 28.0)) < 62.0 and absf(slimes[i].y - player.y) < 65.0:
			if int(inventory.get("Wild Essence", 0)) >= MAX_STACK:
				message = "Wild Essence stack full; slime not defeated"
				message_timer = 1.8
				return
			impact_position = slimes[i]
			impact_kind = "hit"
			impact_timer = 0.26
			slimes.remove_at(i)
			_add_item("Wild Essence", 1)
			message = "Slime defeated! +1 Wild Essence"
			message_timer = 2.0
			_save_world()
			return
	message = "Swing!"
	message_timer = 0.7

func _input(event: InputEvent) -> void:
	var size := get_viewport_rect().size
	if event is InputEventScreenTouch:
		if event.pressed:
			if event.position.x < size.x * 0.46 and joystick_id == -1:
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
			if event.position.x < size.x * 0.46:
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
	var travel := clampf(delta, -52.0, 52.0)
	move_axis = travel / 52.0
	if absf(travel) < 10.0:
		move_axis = 0.0

func _handle_action_touch(pos: Vector2) -> void:
	var size := get_viewport_rect().size
	var nearest_action := ""
	var nearest_distance := INF
	# Use circular targets for the large action buttons and thumb-friendly
	# rectangular targets for utility chips; normalized distance resolves overlaps.
	for i in range(7):
		var center: Vector2
		var action: String
		var target_distance: float
		if i < 3:
			center = _main_button_center(size, i)
			action = ["jump", "hit", "mine"][i]
			var radius: float = [49.0, 53.0, 48.0][i]
			target_distance = pos.distance_to(center) / radius
		else:
			center = _utility_button_center(size, i - 3)
			action = ["craft", "recipe", "use", "point"][i - 3]
			var local_pos := pos - center
			target_distance = Vector2(local_pos.x / 55.0, local_pos.y / 25.0).length()
		if target_distance <= 1.0 and target_distance < nearest_distance:
			nearest_action = action
			nearest_distance = target_distance

	match nearest_action:
		"jump":
			_flash_control("jump")
			jump_requested = true
		"hit":
			_flash_control("hit")
			attack_requested = true
		"mine":
			_flash_control("mine")
			mine_requested = true
		"craft":
			_flash_control("craft")
			_craft_selected()
		"recipe":
			_flash_control("recipe")
			_next_recipe()
		"use":
			_flash_control("use")
			_use_selected_item()
		"point":
			_flash_control("point")
			_set_checkpoint()

func _flash_control(action: String) -> void:
	pressed_action = action
	pressed_action_timer = 0.16
	queue_redraw()

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
		if not _remove_item(recipe, 1):
			message = "Could not use " + recipe
			message_timer = 1.5
			return
		placed_objects[object_key] = recipe
		message = recipe + " placed"
		message_timer = 1.5
	elif recipe == "Healing Salve":
		if int(inventory.get("Healing Salve", 0)) <= 0:
			message = "No Healing Salve in inventory"
			message_timer = 1.5
			return
		if health >= 100:
			message = "Health is already full"
			message_timer = 1.5
			return
		if not _remove_item("Healing Salve", 1):
			message = "No Healing Salve available"
			message_timer = 1.5
			return
		var old_health: int = health
		health = mini(100, health + 35)
		message = "Healing Salve: +%d HP" % (health - old_health)
		message_timer = 1.8
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
		if not _remove_item("Planks", 1):
			message = "No Planks available"
			message_timer = 1.5
			return
		world_blocks[block_key] = "planks"
		generated_tile_cache.erase(block_key)
		message = "Plank placed"
		message_timer = 1.5
	message_timer = maxf(message_timer, 1.5)
	_save_world()

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
		_save_world()

func _set_checkpoint() -> void:
	var tile_x: int = clampi(int(floor(player.x / TILE)), 0, WORLD_WIDTH - 1)
	checkpoint_tile = tile_x
	player_respawn = Vector2(float(tile_x * TILE) + TILE * 0.5, _ground_surface_y(tile_x))
	message = "Checkpoint set"
	message_timer = 1.5
	_save_world()

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
	_save_world()

func _craft_selected() -> void:
	var recipe: String = str(RECIPES[craft_recipe_index])
	if recipe == "Torch":
		if int(inventory["Wood"]) >= 2 and int(inventory["Stone"]) >= 1:
			if int(inventory["Torch"]) + 3 > MAX_STACK:
				message = "Need space for 3 Torches"
			else:
				_remove_item("Wood", 2)
				_remove_item("Stone", 1)
				_add_item("Torch", 3)
				message = "Crafted 3 Torches"
		else:
			message = "Torch: need 2 Wood + 1 Stone"
	elif recipe == "Planks":
		if int(inventory["Wood"]) >= 2:
			if int(inventory["Planks"]) + 4 > MAX_STACK:
				message = "Need space for 4 Planks"
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
	elif recipe == "Healing Salve":
		if int(inventory["Wild Essence"]) >= 2 and int(inventory["Wood"]) >= 1:
			if int(inventory["Healing Salve"]) >= MAX_STACK:
				message = "Healing Salve stack full"
			else:
				_remove_item("Wild Essence", 2)
				_remove_item("Wood", 1)
				_add_item("Healing Salve", 1)
				message = "Healing Salve crafted"
		else:
			message = "Salve: need 2 Essence + 1 Wood"
	message_timer = 1.8
	_save_world()

func _draw() -> void:
	var size := get_viewport_rect().size
	var sun := (sin(day_time) + 1.0) * 0.5
	var sky := Color(0.12, 0.18, 0.31).lerp(Color(0.38, 0.68, 0.88), sun)
	draw_rect(Rect2(Vector2.ZERO, size), sky)
	_draw_scenery(size, sun)
	_draw_world(size)
	_draw_player()
	_draw_slimes()
	_draw_effects()
	_draw_hud(size)
	_draw_controls(size)

func _draw_scenery(size: Vector2, sun: float) -> void:
	var horizon := size.y * 0.54 - camera_offset.y * 0.04
	# Subtle atmospheric bands keep the sky from looking like a flat solid color.
	for band in range(6):
		var band_color := Color(0.08, 0.13, 0.23).lerp(Color(0.42, 0.72, 0.91), sun)
		band_color.a = 0.035
		draw_rect(Rect2(0, float(band) * size.y / 6.0, size.x, size.y / 6.0 + 1.0), band_color)
	# Two distant parallax layers add depth while keeping the game lightweight.
	for i in range(9):
		var x := fposmod(float(i * 210) - camera_offset.x * 0.10, size.x + 300.0) - 150.0
		var h := 80.0 + float((i * 43) % 95)
		var y := horizon - h - camera_offset.y * 0.035
		var far_color := Color(0.20, 0.35, 0.43).lerp(Color(0.52, 0.69, 0.72), sun)
		draw_colored_polygon(PackedVector2Array([Vector2(x - 135, horizon), Vector2(x, y), Vector2(x + 155, horizon)]), far_color)
	for i in range(7):
		var x := fposmod(float(i * 275 + 95) - camera_offset.x * 0.19, size.x + 360.0) - 180.0
		var h := 70.0 + float((i * 37) % 72)
		var y := horizon + 26.0 - h - camera_offset.y * 0.055
		var near_color := Color(0.15, 0.29, 0.34).lerp(Color(0.34, 0.51, 0.50), sun)
		draw_colored_polygon(PackedVector2Array([Vector2(x - 130, horizon + 26.0), Vector2(x, y), Vector2(x + 170, horizon + 26.0)]), near_color)
	# Soft cloud clusters and a gently glowing sun/moon.
	for i in range(5):
		var cx := fposmod(float(i * 287) - camera_offset.x * 0.035 + 80.0, size.x + 240.0) - 120.0
		var cy := 105.0 + float((i * 29) % 90) - camera_offset.y * 0.015
		var cloud := Color(0.87, 0.94, 0.97, 0.28 if sun > 0.3 else 0.12)
		draw_circle(Vector2(cx, cy), 17.0, cloud)
		draw_circle(Vector2(cx + 20.0, cy - 7.0), 23.0, cloud)
		draw_circle(Vector2(cx + 43.0, cy + 1.0), 15.0, cloud)
	var celestial := Color(1.0, 0.79, 0.42).lerp(Color(0.91, 0.94, 1.0), sun)
	draw_circle(Vector2(size.x * 0.82, 92.0), 31.0, Color(celestial.r, celestial.g, celestial.b, 0.10))
	draw_circle(Vector2(size.x * 0.82, 92.0), 24.0, celestial)

func _draw_world(size: Vector2) -> void:
	# Only evaluate cells that can actually appear on screen. The old loop
	# scanned the entire underground depth every frame, even for off-screen rows.
	var start_x := maxi(0, int(floor(camera_offset.x / TILE)) - 2)
	var end_x := mini(WORLD_WIDTH, int(ceil((camera_offset.x + size.x) / TILE)) + 2)
	var start_y := maxi(0, int(floor(camera_offset.y / TILE)) - 1)
	var end_y := mini(WORLD_DEPTH, int(ceil((camera_offset.y + size.y) / TILE)) + 1)
	for tx in range(start_x, end_x):
		var surface := int(round(ground_y_at(tx)))
		var px := float(tx * TILE) - camera_offset.x
		for ty in range(start_y, end_y):
			var kind := block_type(tx, ty)
			var py := float(ty * TILE) - camera_offset.y
			if py < -TILE or py > size.y + TILE:
				continue
			# Cave voids are dark, not transparent holes showing the sky behind the world.
			if kind == "":
				if ty > surface + 5 and ty < WORLD_DEPTH - 4:
					draw_rect(Rect2(px, py, TILE, TILE), Color(0.045, 0.055, 0.075))
					# Sparse deterministic cave details, evaluated only for visible cells.
					var cave_mark := posmod(tx * 37 + ty * 19 + int(world_seed % 101), 23)
					if cave_mark == 0:
						draw_rect(Rect2(px + 3, py + 4, 7, 2), Color(0.13, 0.16, 0.19))
						draw_rect(Rect2(px + 5, py + 6, 3, 2), Color(0.085, 0.11, 0.14))
					elif cave_mark == 7 and ty > surface + 8:
						var shard_color := Color(0.18, 0.62, 0.58, 0.82)
						draw_colored_polygon(PackedVector2Array([Vector2(px + 8, py + 18), Vector2(px + 12, py + 5), Vector2(px + 15, py + 18)]), shard_color)
						draw_line(Vector2(px + 12, py + 8), Vector2(px + 12, py + 17), Color(0.55, 0.94, 0.78, 0.8), 1.0)
					elif (tx * 11 + ty * 5) % 17 == 0:
						draw_rect(Rect2(px + 16, py + 3, 3, 2), Color(0.15, 0.18, 0.21))
				continue
			# A single atlas blit replaces many per-tile draw calls and provides
			# hand-authored pixel texture while retaining the original tile grid.
			var atlas_index := 4
			if kind == "grass":
				atlas_index = 0
			elif kind == "dirt":
				atlas_index = 1
			elif kind == "sand":
				atlas_index = 2
			elif kind == "snow":
				atlas_index = 3
			elif kind == "stone":
				atlas_index = 4
			elif kind == "copper_ore":
				atlas_index = 5
			elif kind == "sandstone":
				atlas_index = 6
			elif kind == "permafrost":
				atlas_index = 7
			elif kind == "planks":
				atlas_index = 8
			elif kind == "bedrock":
				atlas_index = 9
			draw_texture_rect_region(TERRAIN_ATLAS, Rect2(px, py, TILE, TILE), Rect2(atlas_index * TILE, 0, TILE, TILE))
		var ground_screen_y := float(surface * TILE) - camera_offset.y
		var biome := biome_at(tx)
		var has_tree := _tree_exists(tx) and surface > 0
		if has_tree:
			if biome == "desert":
				_draw_cactus(px, ground_screen_y)
			elif biome == "snow":
				_draw_pine(px, ground_screen_y)
			else:
				_draw_tree(px, ground_screen_y)
		else:
			_draw_ground_flora(px, ground_screen_y, biome, tx)
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

func _draw_ground_flora(x: float, y: float, biome: String, tx: int) -> void:
	# Deterministic, sparse surface plants: no nodes or per-frame allocations.
	var mark := posmod(tx * 17 + int(world_seed % 97), 19)
	if biome == "desert":
		if mark == 2 or mark == 11:
			draw_rect(Rect2(x + 5, y - 4, 5, 3), Color(0.56, 0.39, 0.22))
			draw_rect(Rect2(x + 8, y - 6, 3, 2), Color(0.72, 0.53, 0.30))
		elif mark == 6:
			draw_line(Vector2(x + 12, y - 2), Vector2(x + 9, y - 9), Color(0.52, 0.56, 0.27), 2.0)
			draw_line(Vector2(x + 12, y - 3), Vector2(x + 16, y - 8), Color(0.62, 0.62, 0.31), 2.0)
		return
	if biome == "snow":
		if mark == 1 or mark == 9:
			draw_line(Vector2(x + 8, y - 2), Vector2(x + 6, y - 8), Color(0.42, 0.68, 0.70), 2.0)
			draw_line(Vector2(x + 12, y - 2), Vector2(x + 15, y - 7), Color(0.56, 0.79, 0.78), 2.0)
			draw_rect(Rect2(x + 7, y - 4, 7, 2), Color(0.36, 0.61, 0.65))
		return
	if biome == "forest":
		if mark % 5 == 0:
			draw_line(Vector2(x + 7, y - 2), Vector2(x + 5, y - 8), Color(0.20, 0.49, 0.28), 2.0)
			draw_line(Vector2(x + 11, y - 2), Vector2(x + 13, y - 10), Color(0.29, 0.62, 0.32), 2.0)
			draw_line(Vector2(x + 15, y - 2), Vector2(x + 18, y - 7), Color(0.22, 0.53, 0.27), 2.0)
		elif mark == 3:
			draw_line(Vector2(x + 12, y - 2), Vector2(x + 12, y - 9), Color(0.27, 0.48, 0.25), 1.5)
			draw_circle(Vector2(x + 12, y - 10), 2.5, Color(0.88, 0.65, 0.75))
			draw_circle(Vector2(x + 12, y - 10), 1.0, Color(0.96, 0.84, 0.50))
	else:
		if mark % 4 == 0:
			draw_line(Vector2(x + 6, y - 2), Vector2(x + 4, y - 7), Color(0.30, 0.58, 0.31), 2.0)
			draw_line(Vector2(x + 11, y - 2), Vector2(x + 13, y - 9), Color(0.38, 0.66, 0.34), 2.0)
		elif mark == 2:
			draw_line(Vector2(x + 12, y - 2), Vector2(x + 12, y - 8), Color(0.34, 0.57, 0.29), 1.5)
			draw_circle(Vector2(x + 12, y - 9), 2.5, Color(0.92, 0.74, 0.42))
			draw_circle(Vector2(x + 12, y - 9), 1.0, Color(0.98, 0.91, 0.64))

func _draw_cactus(x: float, y: float) -> void:
	draw_texture_rect_region(CREATURE_ATLAS, Rect2(x - 1, y - 120, 48, 120), Rect2(96, 0, 48, 120))

func _draw_pine(x: float, y: float) -> void:
	draw_texture_rect_region(CREATURE_ATLAS, Rect2(x - 1, y - 120, 48, 120), Rect2(48, 0, 48, 120))

func _draw_tree(x: float, y: float) -> void:
	draw_texture_rect_region(CREATURE_ATLAS, Rect2(x - 1, y - 120, 48, 120), Rect2(0, 0, 48, 120))

func _draw_player() -> void:
	var p := player - camera_offset
	# Draw a single crisp pixel-art sprite; horizontal mirroring follows movement.
	# One atlas draw replaces many per-frame rectangles and keeps mobile rendering light.
	draw_set_transform(p, 0.0, Vector2(float(facing), 1.0))
	draw_texture_rect_region(HERO_ATLAS, Rect2(-16, -48, 32, 48), Rect2(0, 0, 32, 48))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_effects() -> void:
	if impact_timer <= 0.0:
		return
	var p := impact_position - camera_offset
	var strength := clampf(impact_timer / 0.26, 0.0, 1.0)
	if impact_kind == "damage":
		var pulse := 1.0 - strength
		draw_colored_polygon(PackedVector2Array([
			Vector2(p.x - 20, p.y - 36), Vector2(p.x - 11, p.y - 43),
			Vector2(p.x - 5, p.y - 32), Vector2(p.x + 4, p.y - 45),
			Vector2(p.x + 9, p.y - 31), Vector2(p.x + 19, p.y - 37),
			Vector2(p.x + 14, p.y - 18), Vector2(p.x - 14, p.y - 18)
		]), Color(1.0, 0.22, 0.19, 0.24 + pulse * 0.3))
		return
	if impact_kind == "hit":
		var radius := 13.0 + (1.0 - strength) * 17.0
		draw_arc(p, radius, -0.9, 1.0, 8, Color(1.0, 0.88, 0.55, strength), 3.0, true)
		draw_line(p + Vector2(-14, -8), p + Vector2(-6, -15), Color(1.0, 0.96, 0.75, strength), 2.0)
		draw_line(p + Vector2(9, -12), p + Vector2(16, -5), Color(1.0, 0.96, 0.75, strength), 2.0)
		return
	var shard := Color(0.38, 0.91, 0.83, strength) if impact_kind == "copper" else Color(0.87, 0.76, 0.55, strength)
	var spread := (1.0 - strength) * 10.0
	for i in range(4):
		var angle := float(i) * TAU / 4.0 + 0.4
		var direction := Vector2(cos(angle), sin(angle))
		var origin := p + direction * spread
		draw_line(origin, origin + direction * 4.0, shard, 2.0)
	if impact_kind == "copper":
		draw_circle(p, 7.0 + (1.0 - strength) * 5.0, Color(0.16, 0.78, 0.69, 0.12 * strength))

func _draw_slimes() -> void:
	for slime in slimes:
		var p := slime - camera_offset
		draw_texture_rect_region(CREATURE_ATLAS, Rect2(p.x - 24, p.y - 30, 48, 48), Rect2(144, 68, 48, 48))

func _draw_hud(size: Vector2) -> void:
	draw_rect(Rect2(16, 16, 350, 178), Color(0.055, 0.08, 0.10, 0.84))
	draw_string(ThemeDB.fallback_font, Vector2(30, 42), "DEEPWILD", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(0.91, 0.83, 0.57))
	draw_string(ThemeDB.fallback_font, Vector2(30, 65), "HP", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)
	draw_rect(Rect2(62, 52, 150, 15), Color(0.28, 0.15, 0.16))
	draw_rect(Rect2(62, 52, 150.0 * float(health) / 100.0, 15), Color(0.84, 0.25, 0.26))
	draw_string(ThemeDB.fallback_font, Vector2(30, 91), "WOOD %d STONE %d COPPER %d" % [inventory["Wood"], inventory["Stone"], inventory["Copper"]], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.88, 0.90, 0.82))
	draw_string(ThemeDB.fallback_font, Vector2(30, 108), "DIRT %d SAND %d SNOW %d TORCH %d" % [inventory["Dirt"], inventory["Sand"], inventory["Snow"], inventory["Torch"]], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.88, 0.90, 0.82))
	draw_string(ThemeDB.fallback_font, Vector2(30, 126), "PLANKS %d  CAMPFIRE %d  ESSENCE %d" % [inventory["Planks"], inventory["Campfire"], inventory["Wild Essence"]], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.88, 0.90, 0.82))
	draw_string(ThemeDB.fallback_font, Vector2(30, 145), "SALVE %d" % inventory["Healing Salve"], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.88, 0.90, 0.82))
	draw_string(ThemeDB.fallback_font, Vector2(30, 165), "Campfires restore 5 HP every 3 seconds nearby", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.98, 0.75, 0.42))
	draw_string(ThemeDB.fallback_font, Vector2(size.x - 18, 49), "RECIPE: " + RECIPES[craft_recipe_index].to_upper(), HORIZONTAL_ALIGNMENT_RIGHT, -1, 12, Color(1.0, 0.91, 0.69))
	draw_string(ThemeDB.fallback_font, Vector2(size.x - 18, 28), "DAY %d  •  %s" % [day_count, biome_at(int(player.x / TILE)).to_upper()], HORIZONTAL_ALIGNMENT_RIGHT, -1, 14, Color.WHITE)
	draw_string(ThemeDB.fallback_font, Vector2(size.x - 18, 68), "SLIMES %d/3" % slimes.size(), HORIZONTAL_ALIGNMENT_RIGHT, -1, 12, Color(0.70, 1.0, 0.75))
	var hit_status := "HIT READY" if attack_cooldown <= 0.0 else "HIT RECOVERY %.1fs" % attack_cooldown
	draw_string(ThemeDB.fallback_font, Vector2(size.x - 18, 86), hit_status, HORIZONTAL_ALIGNMENT_RIGHT, -1, 11, Color(0.96, 0.78, 0.55) if attack_cooldown > 0.0 else Color(0.80, 0.95, 0.80))
	if message_timer > 0.0:
		var width := minf(size.x - 40.0, 510.0)
		draw_rect(Rect2((size.x - width) * 0.5, 34, width, 38), Color(0.05, 0.07, 0.08, 0.82))
		draw_string(ThemeDB.fallback_font, Vector2(size.x * 0.5, 59), message, HORIZONTAL_ALIGNMENT_CENTER, width - 16, 16, Color(1.0, 0.91, 0.69))

func _draw_controls(size: Vector2) -> void:
	# Floating joystick appears beneath the left thumb instead of forcing a fixed touch point.
	var center := _joystick_center(size)
	var active := joystick_id != -1 or mouse_joystick
	if active:
		center = joystick_origin
	draw_circle(center, 57.0, Color(0.025, 0.045, 0.055, 0.48))
	draw_arc(center, 51.0, 0.0, TAU, 48, Color(0.55, 0.72, 0.72, 0.38), 2.0, true)
	draw_circle(center, 35.0, Color(0.16, 0.24, 0.26, 0.72))
	draw_arc(center, 34.0, 0.0, TAU, 36, Color(0.69, 0.80, 0.76, 0.34), 1.5, true)
	for tick in range(8):
		var angle := float(tick) * TAU / 8.0
		var inner := center + Vector2(cos(angle), sin(angle)) * 43.0
		var outer := center + Vector2(cos(angle), sin(angle)) * 48.0
		draw_line(inner, outer, Color(0.72, 0.84, 0.79, 0.45), 2.0)
	var knob := center
	if active:
		var drag := joystick_current - joystick_origin
		drag.x = clampf(drag.x, -30.0, 30.0)
		drag.y = clampf(drag.y, -30.0, 30.0)
		knob += drag
	draw_circle(knob + Vector2(0, 3), 22.0, Color(0.0, 0.0, 0.0, 0.25))
	draw_circle(knob, 21.0, Color(0.66, 0.83, 0.77, 0.88))
	draw_arc(knob, 16.0, 3.4, 6.0, 20, Color(0.93, 1.0, 0.92, 0.58), 1.5, true)

	# Three primary actions form one compact cluster, with different silhouettes.
	_draw_action_button(_main_button_center(size, 0), "JUMP", Color(0.22, 0.56, 0.78), 39.0, "jump")
	var hit_color := Color(0.78, 0.25, 0.23) if attack_cooldown <= 0.0 else Color(0.36, 0.39, 0.40)
	_draw_action_button(_main_button_center(size, 1), "HIT", hit_color, 44.0, "hit")
	_draw_action_button(_main_button_center(size, 2), "MINE", Color(0.68, 0.49, 0.23), 36.0, "mine")

	# Utility actions stay small and readable; the last one marks a respawn checkpoint.
	_draw_utility_chip(_utility_button_center(size, 0), "CRAFT", Color(0.29, 0.62, 0.43))
	_draw_utility_chip(_utility_button_center(size, 1), "RECIPE", Color(0.42, 0.53, 0.61))
	_draw_utility_chip(_utility_button_center(size, 2), "USE", Color(0.76, 0.48, 0.25))
	_draw_utility_chip(_utility_button_center(size, 3), "POINT", Color(0.40, 0.63, 0.43))

func _joystick_center(size: Vector2) -> Vector2:
	return Vector2(91.0, size.y - 92.0)

func _main_button_center(size: Vector2, index: int) -> Vector2:
	var anchor := Vector2(size.x - 92.0, size.y - 91.0)
	if index == 0:
		return anchor + Vector2(-65.0, -66.0)
	if index == 1:
		return anchor
	return anchor + Vector2(-76.0, 12.0)

func _utility_button_center(size: Vector2, index: int) -> Vector2:
	var step := clampf(size.y * 0.115, 39.0, 48.0)
	return Vector2(size.x - 63.0, size.y * 0.24 + float(index) * step)

func _draw_action_button(center: Vector2, label: String, color: Color, radius: float, kind: String) -> void:
	var pressed_strength := clampf(pressed_action_timer / 0.16, 0.0, 1.0) if pressed_action == kind else 0.0
	var visual_radius := radius - 3.0 * pressed_strength
	var visual_center := center + Vector2(0.0, 2.0 * pressed_strength)
	draw_circle(center + Vector2(0, 4), radius + 4.0, Color(0.0, 0.0, 0.0, 0.32))
	draw_circle(visual_center, visual_radius + 2.0, Color(0.76, 0.88, 0.82, lerpf(0.20, 0.28, pressed_strength)))
	draw_circle(visual_center, visual_radius, Color(0.055, 0.085, 0.09, 0.90))
	draw_circle(visual_center, visual_radius - 4.0, color.darkened(0.28).lerp(color.lightened(0.12), pressed_strength * 0.65))
	draw_arc(visual_center, visual_radius - 5.0, -2.55, -0.55, 18, color.lightened(lerpf(0.25, 0.35, pressed_strength)), 2.0, true)
	if kind == "jump":
		draw_colored_polygon(PackedVector2Array([center + Vector2(0, -17), center + Vector2(-10, -4), center + Vector2(-4, -4), center + Vector2(-4, 7), center + Vector2(4, 7), center + Vector2(4, -4), center + Vector2(10, -4)]), Color(0.93, 0.98, 0.98))
	elif kind == "hit":
		draw_line(center + Vector2(-11, -12), center + Vector2(10, 9), Color(1.0, 0.95, 0.83), 5.0)
		draw_line(center + Vector2(-4, -15), center + Vector2(14, 3), Color(1.0, 0.95, 0.83), 2.0)
		draw_line(center + Vector2(-15, 8), center + Vector2(-8, 1), Color(1.0, 0.86, 0.63), 2.0)
	else:
		draw_rect(Rect2(center.x - 10, center.y - 13, 20, 22), Color(0.94, 0.88, 0.72), false, 2.5)
		draw_line(center + Vector2(-7, -7), center + Vector2(7, -7), Color(0.94, 0.88, 0.72), 2.0)
		draw_line(center + Vector2(-7, 0), center + Vector2(4, 0), Color(0.94, 0.88, 0.72), 2.0)
	draw_string(ThemeDB.fallback_font, center + Vector2(0, radius - 7.0), label, HORIZONTAL_ALIGNMENT_CENTER, radius * 2.2, 10, Color(0.96, 0.98, 0.94))

func _draw_utility_chip(center: Vector2, label: String, accent: Color) -> void:
	var pressed_strength := clampf(pressed_action_timer / 0.16, 0.0, 1.0) if pressed_action == label.to_lower() else 0.0
	var rect := Rect2(center.x - 49.0, center.y - 16.0, 98.0, 32.0)
	var visual_rect := rect.grow(-2.0 * pressed_strength)
	var base_color := Color(0.035, 0.065, 0.07, 0.78)
	var pressed_color := Color(0.09, 0.14, 0.13, 0.94)
	draw_rect(rect.grow(2.0), Color(0.0, 0.0, 0.0, 0.25), true, 8.0)
	draw_rect(visual_rect, base_color.lerp(pressed_color, pressed_strength), true, 8.0)
	draw_rect(Rect2(visual_rect.position.x + 4.0, visual_rect.position.y + 5.0, 3.0, visual_rect.size.y - 10.0), accent.lerp(accent.lightened(0.25), pressed_strength), true, 2.0)
	draw_string(ThemeDB.fallback_font, center + Vector2(4.0, 4.0), label, HORIZONTAL_ALIGNMENT_CENTER, 86.0, 11, Color(0.91, 0.95, 0.90).lerp(Color(1.0, 1.0, 0.92), pressed_strength))

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
	world_save_loaded = true
	world_seed = int(parsed.get("world_seed", world_seed))
	player = Vector2(float(parsed.get("player_x", 320.0)), float(parsed.get("player_y", 240.0)))
	health = int(parsed.get("health", 100))
	day_count = maxi(1, int(parsed.get("day_count", 1)))
	day_time = fposmod(float(parsed.get("day_time", day_time)), TAU)
	checkpoint_tile = int(parsed.get("checkpoint_tile", -1))
	var saved_inventory = parsed.get("inventory", {})
	for key in inventory:
		inventory[key] = int(saved_inventory.get(key, inventory[key]))
	world_blocks = parsed.get("blocks", {})
	if checkpoint_tile >= 0:
		checkpoint_tile = clampi(checkpoint_tile, 0, WORLD_WIDTH - 1)
		player_respawn = Vector2(float(checkpoint_tile * TILE) + TILE * 0.5, _ground_surface_y(checkpoint_tile))
	harvested_trees = parsed.get("harvested_trees", {})
	tree_health = parsed.get("tree_health", {})
	placed_objects = parsed.get("placed_objects", {})
	craft_recipe_index = clampi(int(parsed.get("craft_recipe_index", 0)), 0, RECIPES.size() - 1)
	slimes.clear()
	for item in parsed.get("slimes", []):
		if item is Array and item.size() >= 2:
			slimes.append(Vector2(float(item[0]), float(item[1])))
