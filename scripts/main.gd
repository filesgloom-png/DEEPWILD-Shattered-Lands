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
# Fixed unit directions for the joystick bezel; avoid per-frame trigonometry.
const JOYSTICK_TICK_DIRECTIONS := [
	Vector2(1.0, 0.0),
	Vector2(0.7071067812, 0.7071067812),
	Vector2(0.0, 1.0),
	Vector2(-0.7071067812, 0.7071067812),
	Vector2(-1.0, 0.0),
	Vector2(-0.7071067812, -0.7071067812),
	Vector2(0.0, -1.0),
	Vector2(0.7071067812, -0.7071067812)
]
const SAVE_PATH := "user://deepwild_save.json"
# Immutable world-render palette: avoid rebuilding these colors on every frame.
const CAVE_VOID_COLOR := Color(0.045, 0.055, 0.075)
const CAVE_MARK_COLOR := Color(0.13, 0.16, 0.19)
const CAVE_MARK_SHADOW := Color(0.085, 0.11, 0.14)
const CAVE_SHARD_COLOR := Color(0.18, 0.62, 0.58, 0.82)
const CAVE_SHARD_HIGHLIGHT := Color(0.55, 0.94, 0.78, 0.8)
const CAVE_SPECK_COLOR := Color(0.15, 0.18, 0.21)
const GRASS_EDGE_COLOR := Color(0.57, 0.82, 0.43, 0.72)
const SAND_EDGE_COLOR := Color(0.88, 0.73, 0.45, 0.72)
const SNOW_EDGE_COLOR := Color(0.82, 0.94, 1.0, 0.78)
const EDGE_SHADOW_COLOR := Color(0.035, 0.06, 0.045, 0.24)
const CLOUD_BASE_COLOR := Color(0.87, 0.94, 0.97)
const CLOUD_HIGHLIGHT_COLOR := Color(0.98, 1.0, 1.0)
const CLOUD_SHADOW_COLOR := Color(0.24, 0.35, 0.48)
const TORCH_GLOW_COLOR := Color(1.0, 0.62, 0.20, 0.16)
const TORCH_WOOD_COLOR := Color(0.43, 0.28, 0.16)
const TORCH_FLAME_COLOR := Color(1.0, 0.56, 0.16)
const TORCH_CORE_COLOR := Color(1.0, 0.85, 0.35)
const CAMPFIRE_LOG_DARK_COLOR := Color(0.29, 0.19, 0.13)
const CAMPFIRE_LOG_LIGHT_COLOR := Color(0.45, 0.27, 0.15)
const CAMPFIRE_FLAME_COLOR := Color(1.0, 0.39, 0.10)
const CAMPFIRE_CORE_COLOR := Color(1.0, 0.78, 0.22)
# Scenery palette endpoints are immutable and reused across redraws.
const SKY_BAND_NIGHT_COLOR := Color(0.08, 0.13, 0.23)
const SKY_BAND_DAY_COLOR := Color(0.42, 0.72, 0.91)
const NIGHT_VEIL_COLOR := Color(0.025, 0.045, 0.12)
const STAR_BASE_COLOR := Color(0.82, 0.91, 1.0)
const FIREFLY_HALO_COLOR := Color(0.56, 1.0, 0.64)
const FIREFLY_CORE_COLOR := Color(0.72, 1.0, 0.68)
const PARALLAX_FAR_NIGHT_COLOR := Color(0.20, 0.35, 0.43)
const PARALLAX_FAR_DAY_COLOR := Color(0.52, 0.69, 0.72)
const PARALLAX_NEAR_NIGHT_COLOR := Color(0.15, 0.29, 0.34)
const PARALLAX_NEAR_DAY_COLOR := Color(0.34, 0.51, 0.50)
const HORIZON_GLOW_BASE_COLOR := Color(1.0, 0.49, 0.28)
const HORIZON_LINE_BASE_COLOR := Color(1.0, 0.68, 0.43)
const CELESTIAL_NIGHT_COLOR := Color(1.0, 0.79, 0.42)
const CELESTIAL_DAY_COLOR := Color(0.91, 0.94, 1.0)
# Shared flora palette: reuse immutable colors instead of constructing them per visible plant.
const FLORA_SAND_DARK := Color(0.56, 0.39, 0.22)
const FLORA_SAND_LIGHT := Color(0.72, 0.53, 0.30)
const FLORA_CACTUS_DARK := Color(0.52, 0.56, 0.27)
const FLORA_CACTUS_LIGHT := Color(0.62, 0.62, 0.31)
const FLORA_SNOW_DARK := Color(0.42, 0.68, 0.70)
const FLORA_SNOW_LIGHT := Color(0.56, 0.79, 0.78)
const FLORA_SNOW_BASE := Color(0.36, 0.61, 0.65)
const FLORA_FOREST_DARK := Color(0.20, 0.49, 0.28)
const FLORA_FOREST_MID := Color(0.29, 0.62, 0.32)
const FLORA_FOREST_LIGHT := Color(0.22, 0.53, 0.27)
const FLORA_FOREST_STEM := Color(0.27, 0.48, 0.25)
const FLORA_FLOWER_PINK := Color(0.88, 0.65, 0.75)
const FLORA_FLOWER_CENTER := Color(0.96, 0.84, 0.50)
const FLORA_PLAIN_DARK := Color(0.30, 0.58, 0.31)
const FLORA_PLAIN_LIGHT := Color(0.38, 0.66, 0.34)
const FLORA_PLAIN_STEM := Color(0.34, 0.57, 0.29)
const FLORA_FLOWER_GOLD := Color(0.92, 0.74, 0.42)
const FLORA_FLOWER_PALE := Color(0.98, 0.91, 0.64)

var player := Vector2(320.0, 240.0)
var velocity := Vector2.ZERO
var camera_offset := Vector2.ZERO
var on_ground := false
var facing := 1
var move_axis := 0.0
var walk_animation_time := 0.0
var player_was_moving := false
const CAMERA_ZOOM := 1.22
var joystick_id := -1
var joystick_origin := Vector2.ZERO
var joystick_current := Vector2.ZERO
var mouse_joystick := false
var action_touch_id := -1
var action_touch_origin := Vector2.ZERO
var action_touch_current := Vector2.ZERO
var action_hold_time := 0.0
var action_mouse_down := false
var radial_open := false
var radial_choice := ""
var radial_items: Array[String] = []
var context_action := ""
var jump_requested := false
var mine_requested := false
var attack_requested := false
const MAX_STACK := 99
const RECIPES := ["Torch", "Planks", "Stone Block", "Stone Pickaxe", "Stone Axe", "Campfire", "Healing Salve"]
var inventory := {"Wood": 0, "Stone": 0, "Copper": 0, "Dirt": 0, "Sand": 0, "Snow": 0, "Torch": 0, "Planks": 0, "Stone Block": 0, "Stone Pickaxe": 0, "Stone Axe": 0, "Campfire": 0, "Wild Essence": 0, "Healing Salve": 0}
var world_blocks: Dictionary = {}
var generated_tile_cache: Dictionary = {}
var harvested_trees: Dictionary = {}
var tree_health: Dictionary = {}
var placed_objects: Dictionary = {}
var craft_recipe_index := 0
var active_panel := ""
var selected_item := ""
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
var slime_health: Array[int] = []
var attack_cooldown := 0.0
var slime_spawn_timer := 0.0
var world_save_loaded := false
# Short-lived cosmetic feedback; these values never affect gameplay or saves.
var impact_timer := 0.0
var impact_position := Vector2.ZERO
var slime_hit_flash_timer := 0.0
var slime_hit_flash_position := Vector2.ZERO
var impact_kind := "mine"
var pressed_action := ""
var pressed_action_timer := 0.0

func _ready() -> void:
	randomize()
	world_seed = randi()
	_load_world()
	if slimes.is_empty() and not world_save_loaded:
		slimes = [Vector2(520, 0), Vector2(890, 0), Vector2(1260, 0)]
	_ensure_slime_health()
	if slimes.size() == 3 and not world_save_loaded:
		_save_world()
	for slime in slimes:
		slime.y = _ground_surface_y(int(floor(slime.x / TILE))) - 12
	set_process(true)

func _ensure_slime_health() -> void:
	while slime_health.size() < slimes.size():
		slime_health.append(2)
	while slime_health.size() > slimes.size():
		slime_health.remove_at(slime_health.size() - 1)
	for i in range(slime_health.size()):
		slime_health[i] = clampi(int(slime_health[i]), 1, 2)

func _process(delta: float) -> void:
	slime_damage_cooldown = maxf(0.0, slime_damage_cooldown - delta)
	impact_timer = maxf(0.0, impact_timer - delta)
	slime_hit_flash_timer = maxf(0.0, slime_hit_flash_timer - delta)
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
	if action_touch_id != -1 or action_mouse_down:
		action_hold_time += delta
		if action_hold_time >= 0.28 and not radial_open:
			_open_item_wheel()
	_update_context_hint()
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
	var target_speed := move_axis * WALK_SPEED
	var horizontal_response := 1850.0 if absf(move_axis) > 0.1 else 2350.0
	velocity.x = move_toward(velocity.x, target_speed, horizontal_response * delta)
	if absf(move_axis) > 0.1:
		facing = 1 if move_axis > 0.0 else -1
		walk_animation_time += delta * (9.0 if absf(velocity.x) > WALK_SPEED * 0.7 else 6.0)
	else:
		walk_animation_time = fposmod(walk_animation_time, TAU)
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
			slime_health.append(2)
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
			# A small immediate shove gives contact damage readable physical feedback.
			var knockback_direction := -1.0 if slime.x < player.x else 1.0
			player.x = clampf(player.x + knockback_direction * 26.0, 24.0, WORLD_WIDTH * TILE - 24.0)
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
	# Tree harvesting requires the player to face a tree within true melee reach.
	# Never search several tiles away: this was the source of remote tree chopping.
	var player_tile := int(floor(player.x / TILE))
	var target := player_tile + facing
	if target < 0 or target >= WORLD_WIDTH or not _tree_exists(target):
		message = "Face a tree and stand beside it"
		message_timer = 1.4
		return false
	var tree_center_x := float(target * TILE) + TILE * 0.5
	if absf(tree_center_x - player.x) > TILE * 1.6:
		message = "Move closer to the tree"
		message_timer = 1.4
		return false
	var player_ground := _ground_surface_y(player_tile)
	var tree_ground := _ground_surface_y(target)
	if absf(player_ground - tree_ground) > TILE * 1.5:
		message = "The tree is out of reach"
		message_timer = 1.4
		return false
	var best_tile := target
	var key := str(best_tile)
	var tree_damage := 2 if int(inventory.get("Stone Axe", 0)) > 0 else 1
	var hp := int(tree_health.get(key, 3)) - tree_damage
	if hp <= 0 and int(inventory.get("Wood", 0)) + 3 > MAX_STACK:
		message = "Need space for 3 Wood; tree not felled"
		message_timer = 1.8
		return true
	if hp > 0:
		tree_health[key] = hp
		message = "Tree chopped: %d/3" % (3 - maxi(hp, 0))
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
		elif kind == "stone" and str(world_blocks.get(str(cell.x) + ":" + str(cell.y), "")) == "stone":
			# Return crafted building material when the player dismantles their own block.
			drop = "Stone Block"
		var drop_amount := 2 if int(inventory.get("Stone Pickaxe", 0)) > 0 and (drop == "Stone" or drop == "Copper") and str(world_blocks.get(str(cell.x) + ":" + str(cell.y), "")) != "stone" else 1
		if int(inventory.get(drop, 0)) + drop_amount > MAX_STACK:
			message = drop + " stack full! Block not mined"
			message_timer = 1.5
			return
		impact_position = Vector2(float(cell.x * TILE + TILE / 2), float(cell.y * TILE + TILE / 2))
		impact_kind = "copper" if kind == "copper_ore" else "mine"
		impact_timer = 0.22
		world_blocks[str(cell.x) + ":" + str(cell.y)] = ""
		generated_tile_cache.erase(str(cell.x) + ":" + str(cell.y))
		var added := _add_item(drop, drop_amount)
		message = "+%d %s" % [added, drop]
		message_timer = 1.2
		_save_world()
		return
	message = "Move close to a block or tree"
	message_timer = 1.5

func _attack() -> void:
	_ensure_slime_health()
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
			var hp := slime_health[i] - 1
			impact_position = slimes[i]
			slime_hit_flash_position = slimes[i]
			slime_hit_flash_timer = 0.16
			# Push the slime away on contact with a successful melee strike.
			var slime_knockback_direction := 1.0 if slimes[i].x >= player.x else -1.0
			var pushed_slime := slimes[i]
			pushed_slime.x = clampf(pushed_slime.x + slime_knockback_direction * 22.0, 24.0, WORLD_WIDTH * TILE - 24.0)
			pushed_slime.y = _ground_surface_y(int(floor(pushed_slime.x / TILE))) - 12.0
			slimes[i] = pushed_slime
			impact_kind = "hit"
			impact_timer = 0.26
			if hp > 0:
				slime_health[i] = hp
				message = "Slime hit! %d/2" % (2 - hp)
				message_timer = 1.0
				_save_world()
				return
			slime_health.remove_at(i)
			slimes.remove_at(i)
			_add_item("Wild Essence", 1)
			message = "Slime defeated! +1 Wild Essence"
			message_timer = 2.0
			_save_world()
			return
	impact_position = player + Vector2(float(facing) * 22.0, -24.0)
	impact_kind = "swing_right" if facing > 0 else "swing_left"
	impact_timer = 0.20
	message = "Swing!"
	message_timer = 0.7

func _input(event: InputEvent) -> void:
	var size := get_viewport_rect().size
	if event is InputEventScreenTouch:
		if event.pressed:
			if active_panel != "":
				_handle_panel_touch(event.position)
			elif event.position.x < size.x * 0.46 and joystick_id == -1:
				joystick_id = event.index
				joystick_origin = event.position
				joystick_current = event.position
				_update_joystick_axis()
			else:
				_begin_action_touch(event.index, event.position)
		else:
			if event.index == joystick_id:
				joystick_id = -1
				move_axis = 0.0
			elif event.index == action_touch_id:
				_end_action_touch(event.position)
	elif event is InputEventScreenDrag:
		if event.index == joystick_id:
			joystick_current = event.position
			_update_joystick_axis()
		elif event.index == action_touch_id:
			action_touch_current = event.position
			if radial_open:
				_update_radial_choice(event.position)
			queue_redraw()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if active_panel != "":
				_handle_panel_touch(event.position)
			elif event.position.x < size.x * 0.46:
				mouse_joystick = true
				joystick_origin = event.position
				joystick_current = event.position
				_update_joystick_axis()
			else:
				action_mouse_down = true
				_begin_action_touch(-2, event.position)
		else:
			if action_mouse_down:
				_end_action_touch(event.position)
			mouse_joystick = false
			if not action_mouse_down:
				move_axis = 0.0
	elif event is InputEventMouseMotion:
		if mouse_joystick:
			joystick_current = event.position
			_update_joystick_axis()
		elif action_mouse_down:
			action_touch_current = event.position
			if radial_open:
				_update_radial_choice(event.position)
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F:
			mine_requested = true
		elif event.keycode == KEY_X:
			attack_requested = true
		elif event.keycode == KEY_SPACE:
			jump_requested = true
		elif event.keycode == KEY_I:
			active_panel = "inventory"
		elif event.keycode == KEY_C:
			active_panel = "craft"

func _begin_action_touch(touch_id: int, pos: Vector2) -> void:
	var size := get_viewport_rect().size
	if pos.distance_to(_menu_button_center(size, 0)) < 27.0:
		active_panel = "inventory"
		return
	if pos.distance_to(_menu_button_center(size, 1)) < 27.0:
		active_panel = "craft"
		return
	if context_action != "" and pos.distance_to(_context_rune_position()) < 38.0:
		_perform_context_action()
		return
	action_touch_id = touch_id
	action_touch_origin = pos
	action_touch_current = pos
	action_hold_time = 0.0
	radial_open = false
	radial_choice = ""
	queue_redraw()

func _end_action_touch(pos: Vector2) -> void:
	if radial_open:
		_update_radial_choice(pos)
		_commit_radial_choice()
	else:
		var drag := pos - action_touch_origin
		if drag.length() > 34.0:
			if absf(drag.y) > absf(drag.x):
				if drag.y < 0.0:
					jump_requested = true
				else:
					_use_selected_item()
			else:
				_perform_context_action()
		else:
			attack_requested = true
			_flash_control("attack")
	action_touch_id = -1
	action_mouse_down = false
	action_hold_time = 0.0
	radial_open = false
	radial_choice = ""
	queue_redraw()

func _open_item_wheel() -> void:
	radial_items.clear()
	for item in inventory.keys():
		if int(inventory[item]) > 0:
			radial_items.append(str(item))
	radial_open = true
	_update_radial_choice(action_touch_current)
	queue_redraw()

func _update_radial_choice(pos: Vector2) -> void:
	var delta := pos - action_touch_origin
	if delta.length() < 24.0:
		radial_choice = ""
		return
	var angle := fposmod(atan2(delta.y, delta.x) + PI * 0.5 + TAU, TAU)
	var index := int(floor((angle + PI / 8.0) / (TAU / 8.0))) % 8
	var actions := ["attack", "use", "inventory", "craft", "checkpoint", "interact", "jump", "item"]
	if index == 7 and not radial_items.is_empty():
		var slot := clampi(int(floor(float(radial_items.size()) * 0.5)), 0, radial_items.size() - 1)
		radial_choice = radial_items[slot]
	else:
		radial_choice = actions[index]

func _commit_radial_choice() -> void:
	match radial_choice:
		"attack":
			attack_requested = true
		"jump":
			jump_requested = true
		"use":
			_use_selected_item()
		"interact":
			_perform_context_action()
		"inventory":
			active_panel = "inventory"
		"craft":
			active_panel = "craft"
		"checkpoint":
			_set_checkpoint()
		_:
			if inventory.has(radial_choice):
				selected_item = radial_choice
				message = "Selected: " + selected_item
				message_timer = 1.2

func _perform_context_action() -> void:
	if context_action == "enemy":
		attack_requested = true
	elif context_action == "tree" or context_action == "resource":
		mine_requested = true
	else:
		message = "Move beside a tree or resource"
		message_timer = 1.0

func _menu_button_center(size: Vector2, index: int) -> Vector2:
	return Vector2(size.x - 48.0 - float(index) * 58.0, 42.0)

func _context_rune_position() -> Vector2:
	return Vector2(player.x - camera_offset.x + float(facing) * 43.0 * CAMERA_ZOOM, player.y - camera_offset.y - 58.0 * CAMERA_ZOOM)

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
	# Three main controls plus all four utility controls (BAG, CRAFT, USE, POINT).
	# Keep POINT reachable so checkpoint creation is not silently lost.
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
			action = ["inventory", "craft", "use", "point"][i - 3]
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
		"inventory":
			_flash_control("inventory")
			active_panel = "inventory"
		"craft":
			_flash_control("craft")
			active_panel = "craft"
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
	var recipe: String = selected_item if selected_item != "" and int(inventory.get(selected_item, 0)) > 0 else str(RECIPES[craft_recipe_index])
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
	elif recipe == "Stone Block":
		if int(inventory.get("Stone Block", 0)) <= 0:
			message = "No Stone Blocks in inventory"
			message_timer = 1.5
			return
		var stone_block_key: String = str(target_tx) + ":" + str(target_ty)
		if block_type(target_tx, target_ty) != "":
			message = "Target block is occupied"
			message_timer = 1.5
			return
		if not _remove_item("Stone Block", 1):
			message = "No Stone Blocks available"
			message_timer = 1.5
			return
		world_blocks[stone_block_key] = "stone"
		generated_tile_cache.erase(stone_block_key)
		message = "Stone Block placed"
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
	elif recipe == "Stone Block":
		if int(inventory["Stone"]) >= 3:
			if int(inventory["Stone Block"]) + 2 > MAX_STACK:
				message = "Need space for 2 Stone Blocks"
			else:
				_remove_item("Stone", 3)
				_add_item("Stone Block", 2)
				message = "Crafted 2 Stone Blocks"
		else:
			message = "Stone Block: need 3 Stone"
	elif recipe == "Stone Pickaxe":
		if int(inventory["Stone Pickaxe"]) > 0:
			message = "You already have a Stone Pickaxe"
		elif int(inventory["Wood"]) >= 3 and int(inventory["Stone"]) >= 4:
			_remove_item("Wood", 3)
			_remove_item("Stone", 4)
			_add_item("Stone Pickaxe", 1)
			message = "Stone Pickaxe crafted: stone and copper yield doubled"
		else:
			message = "Stone Pickaxe: need 3 Wood + 4 Stone"
	elif recipe == "Stone Axe":
		if int(inventory["Stone Axe"]) > 0:
			message = "You already have a Stone Axe"
		elif int(inventory["Wood"]) >= 3 and int(inventory["Stone"]) >= 2:
			_remove_item("Wood", 3)
			_remove_item("Stone", 2)
			_add_item("Stone Axe", 1)
			message = "Stone Axe crafted: trees take half as many hits"
		else:
			message = "Stone Axe: need 3 Wood + 2 Stone"
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
	# Zoom the gameplay layer around the screen center while keeping HUD and touch controls fixed.
	var zoom_origin := size * (0.5 - CAMERA_ZOOM * 0.5)
	draw_set_transform(zoom_origin, 0.0, Vector2(CAMERA_ZOOM, CAMERA_ZOOM))
	_draw_world(size)
	_draw_player()
	_draw_slimes()
	_draw_effects()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_draw_hud(size)
	_draw_controls(size)
	if active_panel != "":
		_draw_panel(size)

func _draw_scenery(size: Vector2, sun: float) -> void:
	var horizon := size.y * 0.54 - camera_offset.y * 0.04
	# Subtle atmospheric bands keep the sky from looking flat; reuse one color per frame.
	var band_color := SKY_BAND_NIGHT_COLOR.lerp(SKY_BAND_DAY_COLOR, sun)
	band_color.a = 0.035
	for band in range(6):
		draw_rect(Rect2(0, float(band) * size.y / 6.0, size.x, size.y / 6.0 + 1.0), band_color)
	# A subtle upper-sky night veil adds depth without textures, nodes, or extra scene state.
	var night_veil := clampf((0.48 - sun) / 0.48, 0.0, 1.0)
	var night_veil_color := NIGHT_VEIL_COLOR
	var star_base_color := STAR_BASE_COLOR
	var firefly_halo_color := FIREFLY_HALO_COLOR
	var firefly_core_color := FIREFLY_CORE_COLOR
	if night_veil > 0.0:
		for band in range(4):
			var veil_alpha := night_veil * (0.055 - float(band) * 0.010)
			var veil_color := night_veil_color
			veil_color.a = veil_alpha
			var veil_y := float(band) * size.y * 0.075
			draw_rect(Rect2(0.0, veil_y, size.x, size.y * 0.075 + 1.0), veil_color)
	# Sparse twinkling stars fade in at dusk; deterministic positions avoid random work each frame.
	var night_strength := clampf((0.42 - sun) / 0.42, 0.0, 1.0)
	if night_strength > 0.0:
		for i in range(34):
			var star_x := fposmod(float(i * 137 + 41) - camera_offset.x * 0.012, size.x)
			var star_y := float((i * 67 + 23) % maxi(1, int(size.y * 0.42))) + 8.0
			# Stars are at most 1.6 px wide; skip twinkle math for off-screen rows.
			if star_y + 1.6 < 0.0 or star_y - 1.6 > size.y:
				continue
			var twinkle := 0.45 + 0.55 * ((sin(day_time * 4.0 + float(i) * 2.13) + 1.0) * 0.5)
			var star_alpha := night_strength * twinkle * 0.78
			var star_color := star_base_color
			star_color.a = star_alpha
			var star_radius := 1.0 if i % 4 != 0 else 1.6
			draw_circle(Vector2(star_x, star_y), star_radius, star_color)
	# Two distant parallax layers add depth while keeping the game lightweight.
	# Their palette is identical across each layer, so calculate it once per frame.
	var far_color := PARALLAX_FAR_NIGHT_COLOR.lerp(PARALLAX_FAR_DAY_COLOR, sun)
	for i in range(9):
		var x := fposmod(float(i * 210) - camera_offset.x * 0.10, size.x + 300.0) - 150.0
		# Skip distant mountain triangles whose full horizontal span is off-screen.
		if x + 155.0 < 0.0 or x - 135.0 > size.x:
			continue
		var h := 80.0 + float((i * 43) % 95)
		var y := horizon - h - camera_offset.y * 0.035
		draw_colored_polygon(PackedVector2Array([Vector2(x - 135, horizon), Vector2(x, y), Vector2(x + 155, horizon)]), far_color)
	var near_color := PARALLAX_NEAR_NIGHT_COLOR.lerp(PARALLAX_NEAR_DAY_COLOR, sun)
	for i in range(7):
		var x := fposmod(float(i * 275 + 95) - camera_offset.x * 0.19, size.x + 360.0) - 180.0
		# Skip near mountain triangles whose full horizontal span is off-screen.
		if x + 170.0 < 0.0 or x - 130.0 > size.x:
			continue
		var h := 70.0 + float((i * 37) % 72)
		var y := horizon + 26.0 - h - camera_offset.y * 0.055
		draw_colored_polygon(PackedVector2Array([Vector2(x - 130, horizon + 26.0), Vector2(x, y), Vector2(x + 170, horizon + 26.0)]), near_color)
	# A faint horizon glow adds depth at dawn and dusk without extra scene nodes.
	var horizon_glow := clampf(1.0 - absf(sun - 0.5) * 3.2, 0.0, 1.0)
	if horizon_glow > 0.0:
		var glow_color := HORIZON_GLOW_BASE_COLOR
		glow_color.a = horizon_glow * 0.10
		draw_rect(Rect2(0.0, horizon - 34.0, size.x, 68.0), glow_color)
		var glow_line := HORIZON_LINE_BASE_COLOR
		glow_line.a = horizon_glow * 0.20
		draw_line(Vector2(0.0, horizon + 5.0), Vector2(size.x, horizon + 5.0), glow_line, 1.0)
	# Tiny fireflies drift through the distant night air; deterministic and draw-only.
	if night_strength > 0.18:
		for i in range(9):
			var fly_x := fposmod(float(i * 173 + 61) - camera_offset.x * 0.08, size.x + 60.0) - 30.0
			var fly_y := horizon + 18.0 + float((i * 31 + 13) % 74) - camera_offset.y * 0.02
			# Firefly halos have a 4 px radius; skip both glow draws when fully off-screen.
			if fly_x + 4.0 < 0.0 or fly_x - 4.0 > size.x or fly_y + 4.0 < 0.0 or fly_y - 4.0 > size.y:
				continue
			var flicker := 0.35 + 0.65 * ((sin(day_time * 3.4 + float(i) * 1.71) + 1.0) * 0.5)
			var glow_alpha := night_strength * flicker * 0.18
			var fly_halo := firefly_halo_color
			fly_halo.a = glow_alpha * 0.32
			var fly_core := firefly_core_color
			fly_core.a = glow_alpha
			draw_circle(Vector2(fly_x, fly_y), 4.0, fly_halo)
			draw_circle(Vector2(fly_x, fly_y), 1.4, fly_core)
	# Soft cloud clusters and a gently glowing sun/moon.
	var cloud_highlight := CLOUD_HIGHLIGHT_COLOR
	cloud_highlight.a = 0.22 if sun > 0.3 else 0.10
	var cloud_shadow := CLOUD_SHADOW_COLOR
	cloud_shadow.a = 0.12 if sun > 0.3 else 0.08
	for i in range(5):
		var cx := fposmod(float(i * 287) - camera_offset.x * 0.035 + 80.0, size.x + 240.0) - 120.0
		var cy := 105.0 + float((i * 29) % 90) - camera_offset.y * 0.015 + float((i % 3) - 1) * 5.0
		# Cloud clusters span roughly 60 px horizontally and 25 px vertically; skip fully off-screen clusters.
		if cx + 58.0 < 0.0 or cx - 17.0 > size.x or cy < -28.0 or cy > size.y + 28.0:
			continue
		# Small deterministic opacity differences make the cloud layer feel less repeated.
		var cloud_alpha := (0.25 + float(i % 3) * 0.025) if sun > 0.3 else (0.10 + float(i % 3) * 0.01)
		var cloud := CLOUD_BASE_COLOR
		cloud.a = cloud_alpha
		draw_circle(Vector2(cx, cy), 17.0, cloud)
		draw_circle(Vector2(cx + 20.0, cy - 7.0), 23.0, cloud)
		draw_circle(Vector2(cx + 43.0, cy + 1.0), 15.0, cloud)
		# Fine top highlights and a soft underside give each cloud more volume.
		draw_line(Vector2(cx - 8.0, cy - 10.0), Vector2(cx - 1.0, cy - 14.0), cloud_highlight, 1.5)
		draw_line(Vector2(cx + 12.0, cy - 22.0), Vector2(cx + 24.0, cy - 25.0), cloud_highlight, 1.5)
		draw_line(Vector2(cx + 27.0, cy + 9.0), Vector2(cx + 38.0, cy + 11.0), cloud_shadow, 2.0)
	# A few distant bird silhouettes add gentle daytime motion with only six short strokes.
	var bird_visibility := clampf((sun - 0.24) / 0.46, 0.0, 1.0)
	if bird_visibility > 0.0:
		var wing_color := Color(0.12, 0.20, 0.25, bird_visibility * 0.58)
		for i in range(3):
			var bird_x := fposmod(float(i * 211 + 37) + day_time * 95.0 - camera_offset.x * 0.025, size.x + 80.0) - 40.0
			var bird_y := size.y * 0.22 + float(i * 13) + sin(day_time * 1.4 + float(i)) * 4.0
			# Bird silhouettes span only 10 px; skip strokes when fully off-screen.
			if bird_x + 5.0 < 0.0 or bird_x - 5.0 > size.x or bird_y + 2.0 < 0.0 or bird_y - 1.0 > size.y:
				continue
			draw_line(Vector2(bird_x - 5.0, bird_y), Vector2(bird_x, bird_y + 2.0), wing_color, 1.5)
			draw_line(Vector2(bird_x, bird_y + 2.0), Vector2(bird_x + 5.0, bird_y), wing_color, 1.5)
	var celestial := CELESTIAL_NIGHT_COLOR.lerp(CELESTIAL_DAY_COLOR, sun)
	# Let the sun and moon travel across a simple arc; position is derived from day_time.
	var celestial_x := size.x * (0.5 + cos(day_time - PI * 0.5) * 0.36)
	var celestial_y := size.y * 0.31 - absf(sin(day_time)) * size.y * 0.20
	var celestial_position := Vector2(celestial_x, celestial_y)
	draw_circle(celestial_position, 31.0, Color(celestial.r, celestial.g, celestial.b, 0.10))
	draw_circle(celestial_position, 24.0, celestial)
	# Tiny celestial details add definition without textures, nodes, or gameplay state.
	if sun > 0.58:
		var ray_alpha := clampf((sun - 0.58) * 0.65, 0.0, 0.24)
		var ray_color := Color(1.0, 0.83, 0.55, ray_alpha)
		for ray in range(8):
			var ray_angle := float(ray) * TAU / 8.0 + day_time * 0.03
			var ray_direction := Vector2(cos(ray_angle), sin(ray_angle))
			draw_line(celestial_position + ray_direction * 28.0, celestial_position + ray_direction * 34.0, ray_color, 1.0)
	elif night_strength > 0.55:
		var crater_color := Color(0.45, 0.52, 0.66, 0.38)
		draw_circle(celestial_position + Vector2(-7.0, -3.0), 3.2, crater_color)
		draw_circle(celestial_position + Vector2(5.0, 4.0), 2.2, crater_color)
		draw_circle(celestial_position + Vector2(8.0, -7.0), 1.5, crater_color)

func _draw_world(size: Vector2) -> void:
	# Only evaluate cells that can actually appear on screen. The old loop
	# scanned the entire underground depth every frame, even for off-screen rows.
	var start_x := maxi(0, int(floor(camera_offset.x / TILE)) - 2)
	var end_x := mini(WORLD_WIDTH, int(ceil((camera_offset.x + size.x) / TILE)) + 2)
	var start_y := maxi(0, int(floor(camera_offset.y / TILE)) - 1)
	var end_y := mini(WORLD_DEPTH, int(ceil((camera_offset.y + size.y) / TILE)) + 1)
	# Seed offsets are constant for the world; calculate once instead of per visible tile.
	var cave_seed_offset := int(world_seed % 101)
	var flora_seed_offset := int(world_seed % 97)
	for tx in range(start_x, end_x):
		var surface := int(round(ground_y_at(tx)))
		var px := float(tx * TILE) - camera_offset.x
		for ty in range(start_y, end_y):
			var py := float(ty * TILE) - camera_offset.y
			if py < -TILE or py > size.y + TILE:
				continue
			# Resolve terrain only after the viewport check; this avoids cache lookups
			# and terrain generation work for candidate rows outside the visible area.
			var kind := block_type(tx, ty)
			# Cave voids are dark, not transparent holes showing the sky behind the world.
			if kind == "":
				if ty > surface + 5 and ty < WORLD_DEPTH - 4:
					draw_rect(Rect2(px, py, TILE, TILE), CAVE_VOID_COLOR)
					# Sparse deterministic cave details, evaluated only for visible cells.
					var cave_mark := posmod(tx * 37 + ty * 19 + cave_seed_offset, 23)
					if cave_mark == 0:
						draw_rect(Rect2(px + 3, py + 4, 7, 2), CAVE_MARK_COLOR)
						draw_rect(Rect2(px + 5, py + 6, 3, 2), CAVE_MARK_SHADOW)
					elif cave_mark == 7 and ty > surface + 8:
						var shard_color := CAVE_SHARD_COLOR
						draw_colored_polygon(PackedVector2Array([Vector2(px + 8, py + 18), Vector2(px + 12, py + 5), Vector2(px + 15, py + 18)]), shard_color)
						draw_line(Vector2(px + 12, py + 8), Vector2(px + 12, py + 17), CAVE_SHARD_HIGHLIGHT, 1.0)
					elif (tx * 11 + ty * 5) % 17 == 0:
						draw_rect(Rect2(px + 16, py + 3, 3, 2), CAVE_SPECK_COLOR)
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
			_draw_terrain_variation(px, py, tx, ty, kind, surface, flora_seed_offset)
			# Crisp biome-tinted surface edging adds tile definition with only two lightweight strokes.
			if ty == surface:
				var edge_color := GRASS_EDGE_COLOR
				if kind == "sand":
					edge_color = SAND_EDGE_COLOR
				elif kind == "snow":
					edge_color = SNOW_EDGE_COLOR
				draw_line(Vector2(px, py + 1.0), Vector2(px + TILE, py + 1.0), edge_color, 1.0)
				draw_line(Vector2(px + 2.0, py + 3.0), Vector2(px + TILE - 2.0, py + 3.0), EDGE_SHADOW_COLOR, 1.0)
		var ground_screen_y := float(surface * TILE) - camera_offset.y
		if ground_screen_y >= -120.0 and ground_screen_y <= size.y + 120.0:
			var biome := biome_at(tx)
			var has_tree := _tree_exists(tx) and surface > 0
			if has_tree:
				# Tree sprites are 48 px wide; skip atlas draws when fully beyond the viewport.
				if px + 47.0 >= 0.0 and px - 1.0 <= size.x:
					if biome == "desert":
						_draw_cactus(px, ground_screen_y)
					elif biome == "snow":
						_draw_pine(px, ground_screen_y)
					else:
						_draw_tree(px, ground_screen_y)
			elif ground_screen_y >= -12.0 and ground_screen_y <= size.y + 12.0 and px + 18.0 >= 0.0 and px + 4.0 <= size.x:
				# Small plant marks span about 4-18 px from the tile origin; skip off-screen flora.
				_draw_ground_flora(px, ground_screen_y, biome, tx, flora_seed_offset)
			# Placed lights and campfires extend at most 34 px above the surface.
			# Their widest horizontal footprint is the torch glow (px - 13 to px + 37).
			# Skip object lookups and draw calls when the full footprint is off-screen.
			if ground_screen_y >= -36.0 and ground_screen_y <= size.y + 36.0 and px + 37.0 >= 0.0 and px - 13.0 <= size.x:
				var object_key: String = str(tx)
				if placed_objects.has(object_key):
					var object_kind: String = str(placed_objects[object_key])
					if object_kind == "Torch":
						draw_circle(Vector2(px + 12, ground_screen_y - 24), 25.0, TORCH_GLOW_COLOR)
						draw_rect(Rect2(px + 10, ground_screen_y - 25, 4, 25), TORCH_WOOD_COLOR)
						draw_rect(Rect2(px + 9, ground_screen_y - 30, 6, 8), TORCH_FLAME_COLOR)
						draw_rect(Rect2(px + 11, ground_screen_y - 34, 3, 5), TORCH_CORE_COLOR)
					elif object_kind == "Campfire":
						draw_rect(Rect2(px + 2, ground_screen_y - 5, 20, 5), CAMPFIRE_LOG_DARK_COLOR)
						draw_rect(Rect2(px + 4, ground_screen_y - 10, 16, 4), CAMPFIRE_LOG_LIGHT_COLOR)
						draw_colored_polygon(PackedVector2Array([Vector2(px + 7, ground_screen_y - 8), Vector2(px + 12, ground_screen_y - 24), Vector2(px + 18, ground_screen_y - 8)]), CAMPFIRE_FLAME_COLOR)
						draw_colored_polygon(PackedVector2Array([Vector2(px + 10, ground_screen_y - 8), Vector2(px + 13, ground_screen_y - 18), Vector2(px + 16, ground_screen_y - 8)]), CAMPFIRE_CORE_COLOR)
	
	# Seed offset is computed once per frame in _draw_world, not per plant.
func _draw_terrain_variation(px: float, py: float, tx: int, ty: int, kind: String, surface: int, seed_offset: int) -> void:
	# Tiny deterministic accents break up repeated atlas tiles without introducing noise or per-frame randomness.
	var mark := posmod(tx * 37 + ty * 19 + seed_offset * 13, 11)
	if kind == "grass":
		if mark == 1:
			draw_rect(Rect2(px + 4.0, py + 10.0, 3.0, 1.0), Color(0.66, 0.48, 0.31, 0.85))
			draw_rect(Rect2(px + 17.0, py + 16.0, 2.0, 2.0), Color(0.34, 0.23, 0.18, 0.8))
		elif mark == 5:
			draw_rect(Rect2(px + 11.0, py + 12.0, 2.0, 1.0), Color(0.80, 0.59, 0.37, 0.75))
	elif kind == "dirt":
		if mark == 2:
			draw_rect(Rect2(px + 3.0, py + 5.0, 3.0, 1.0), Color(0.68, 0.47, 0.31, 0.75))
			draw_rect(Rect2(px + 15.0, py + 17.0, 2.0, 2.0), Color(0.27, 0.18, 0.15, 0.65))
		elif mark == 7:
			draw_rect(Rect2(px + 9.0, py + 20.0, 4.0, 1.0), Color(0.59, 0.39, 0.28, 0.75))
	elif kind == "stone" or kind == "bedrock":
		if mark == 3:
			draw_line(Vector2(px + 4.0, py + 7.0), Vector2(px + 8.0, py + 5.0), Color(0.70, 0.75, 0.78, 0.45), 1.0)
		elif mark == 8:
			draw_rect(Rect2(px + 16.0, py + 17.0, 3.0, 1.0), Color(0.10, 0.13, 0.17, 0.55))
	elif kind == "sand":
		if mark == 4:
			draw_rect(Rect2(px + 4.0, py + 13.0, 2.0, 1.0), Color(0.98, 0.85, 0.57, 0.85))
		elif mark == 9:
			draw_rect(Rect2(px + 16.0, py + 18.0, 3.0, 1.0), Color(0.67, 0.52, 0.31, 0.65))
	elif kind == "snow" or kind == "permafrost":
		if mark == 2:
			draw_rect(Rect2(px + 4.0, py + 10.0, 3.0, 1.0), Color(0.86, 0.96, 0.98, 0.75))
		elif mark == 6:
			draw_rect(Rect2(px + 17.0, py + 18.0, 2.0, 1.0), Color(0.29, 0.49, 0.58, 0.55))
	elif kind == "sandstone":
		if mark == 5:
			draw_rect(Rect2(px + 5.0, py + 15.0, 4.0, 1.0), Color(0.86, 0.68, 0.43, 0.72))
	elif kind == "copper_ore":
		if mark == 4:
			draw_rect(Rect2(px + 18.0, py + 4.0, 2.0, 2.0), Color(0.91, 0.60, 0.34, 0.85))
	# At biome borders, soften the hard vertical seam with a few pixel-sized accents on the top layer.
	if ty == surface:
		var current_biome := biome_at(tx)
		var left_biome := biome_at(tx - 1) if tx > 0 else current_biome
		var right_biome := biome_at(tx + 1) if tx < WORLD_WIDTH - 1 else current_biome
		if left_biome != current_biome:
			_draw_biome_seam(px, py, current_biome, true, mark)
		if right_biome != current_biome:
			_draw_biome_seam(px, py, current_biome, false, mark)

func _draw_biome_seam(px: float, py: float, biome: String, left_edge: bool, mark: int) -> void:
	var edge_x := px + (0.0 if left_edge else TILE - 2.0)
	var accent := Color(0.36, 0.63, 0.34, 0.85)
	if biome == "desert":
		accent = Color(0.91, 0.75, 0.46, 0.9)
	elif biome == "snow":
		accent = Color(0.84, 0.94, 0.98, 0.9)
	if mark % 3 == 0:
		draw_rect(Rect2(edge_x, py + 5.0, 2.0, 2.0), accent)
		draw_rect(Rect2(edge_x + (1.0 if left_edge else -1.0), py + 8.0, 1.0, 2.0), accent.darkened(0.22))
	else:
		draw_rect(Rect2(edge_x, py + 6.0, 2.0, 1.0), accent)

func _draw_ground_flora(x: float, y: float, biome: String, tx: int, flora_seed_offset: int) -> void:
	# Deterministic, sparse surface plants: no nodes or per-frame allocations.
	var mark := posmod(tx * 17 + flora_seed_offset, 19)
	if biome == "desert":
		if mark == 2 or mark == 11:
			draw_rect(Rect2(x + 5, y - 4, 5, 3), FLORA_SAND_DARK)
			draw_rect(Rect2(x + 8, y - 6, 3, 2), FLORA_SAND_LIGHT)
		elif mark == 6:
			draw_line(Vector2(x + 12, y - 2), Vector2(x + 9, y - 9), FLORA_CACTUS_DARK, 2.0)
			draw_line(Vector2(x + 12, y - 3), Vector2(x + 16, y - 8), FLORA_CACTUS_LIGHT, 2.0)
		return
	if biome == "snow":
		if mark == 1 or mark == 9:
			draw_line(Vector2(x + 8, y - 2), Vector2(x + 6, y - 8), FLORA_SNOW_DARK, 2.0)
			draw_line(Vector2(x + 12, y - 2), Vector2(x + 15, y - 7), FLORA_SNOW_LIGHT, 2.0)
			draw_rect(Rect2(x + 7, y - 4, 7, 2), FLORA_SNOW_BASE)
		return
	if biome == "forest":
		if mark % 5 == 0:
			draw_line(Vector2(x + 7, y - 2), Vector2(x + 5, y - 8), FLORA_FOREST_DARK, 2.0)
			draw_line(Vector2(x + 11, y - 2), Vector2(x + 13, y - 10), FLORA_FOREST_MID, 2.0)
			draw_line(Vector2(x + 15, y - 2), Vector2(x + 18, y - 7), FLORA_FOREST_LIGHT, 2.0)
		elif mark == 3:
			draw_line(Vector2(x + 12, y - 2), Vector2(x + 12, y - 9), FLORA_FOREST_STEM, 1.5)
			draw_circle(Vector2(x + 12, y - 10), 2.5, FLORA_FLOWER_PINK)
			draw_circle(Vector2(x + 12, y - 10), 1.0, FLORA_FLOWER_CENTER)
	else:
		if mark % 4 == 0:
			draw_line(Vector2(x + 6, y - 2), Vector2(x + 4, y - 7), FLORA_PLAIN_DARK, 2.0)
			draw_line(Vector2(x + 11, y - 2), Vector2(x + 13, y - 9), FLORA_PLAIN_LIGHT, 2.0)
		elif mark == 2:
			draw_line(Vector2(x + 12, y - 2), Vector2(x + 12, y - 8), FLORA_PLAIN_STEM, 1.5)
			draw_circle(Vector2(x + 12, y - 9), 2.5, FLORA_FLOWER_GOLD)
			draw_circle(Vector2(x + 12, y - 9), 1.0, FLORA_FLOWER_PALE)

func _draw_cactus(x: float, y: float) -> void:
	draw_texture_rect_region(CREATURE_ATLAS, Rect2(x - 1, y - 120, 48, 120), Rect2(96, 0, 48, 120))

func _draw_pine(x: float, y: float) -> void:
	draw_texture_rect_region(CREATURE_ATLAS, Rect2(x - 1, y - 120, 48, 120), Rect2(48, 0, 48, 120))

func _draw_tree(x: float, y: float) -> void:
	draw_texture_rect_region(CREATURE_ATLAS, Rect2(x - 1, y - 120, 48, 120), Rect2(0, 0, 48, 120))

func _draw_player() -> void:
	var p := player - camera_offset
	var moving := absf(velocity.x) > 18.0 and on_ground
	var stride := sin(walk_animation_time) if moving else 0.0
	var bob := absf(stride) * 1.5 if moving else 0.0
	# Keep the pixel-art silhouette crisp; add a restrained step cycle and body bob.
	draw_set_transform(p + Vector2(0.0, -bob), 0.0, Vector2(float(facing), 1.0))
	draw_texture_rect_region(HERO_ATLAS, Rect2(-20, -60, 40, 60), Rect2(0, 0, 32, 48))
	if moving:
		# Animated boot pixels make the stride readable instead of looking like ice-skating.
		var rear_foot := Vector2(-5.0 + stride * 3.0, -3.0 + maxf(0.0, -stride) * 2.0)
		var front_foot := Vector2(5.0 - stride * 3.0, -3.0 + maxf(0.0, stride) * 2.0)
		draw_rect(Rect2(rear_foot.x - 3.0, rear_foot.y - 2.0, 6.0, 3.0), Color(0.09, 0.14, 0.16), true)
		draw_rect(Rect2(front_foot.x - 3.0, front_foot.y - 2.0, 6.0, 3.0), Color(0.09, 0.14, 0.16), true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_effects() -> void:
	if impact_timer <= 0.0:
		return
	var p := impact_position - camera_offset
	var viewport_size := get_viewport_rect().size
	# All impact variants fit inside this generous screen-space bound; skip fully invisible effects.
	if p.x + 40.0 < 0.0 or p.x - 40.0 > viewport_size.x or p.y + 50.0 < 0.0 or p.y - 50.0 > viewport_size.y:
		return
	var effect_duration := 0.20 if impact_kind.begins_with("swing_") else 0.26
	var strength := clampf(impact_timer / effect_duration, 0.0, 1.0)
	if impact_kind.begins_with("swing_"):
		var swing_direction := 0.0 if impact_kind == "swing_right" else PI
		var swing_radius := 19.0 + (1.0 - strength) * 9.0
		draw_arc(p + Vector2(0.0, 7.0), swing_radius, swing_direction - 0.95, swing_direction + 0.85, 16, Color(1.0, 0.88, 0.57, strength), 4.0, true)
		draw_line(p + Vector2(cos(swing_direction - 0.85), sin(swing_direction - 0.85)) * 15.0, p + Vector2(cos(swing_direction - 0.85), sin(swing_direction - 0.85)) * 27.0, Color(1.0, 0.97, 0.78, strength), 2.0)
		return
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
	var viewport_size := get_viewport_rect().size
	for i in range(slimes.size()):
		var p := slimes[i] - camera_offset
		# Slime sprites are 48x48; skip the texture draw when fully outside the viewport.
		if p.x + 24.0 < 0.0 or p.x - 24.0 > viewport_size.x or p.y + 18.0 < 0.0 or p.y - 30.0 > viewport_size.y:
			continue
		if slime_hit_flash_timer > 0.0 and slimes[i].distance_to(slime_hit_flash_position) < 0.1:
			var flash_strength := clampf(slime_hit_flash_timer / 0.16, 0.0, 1.0)
			draw_set_transform(p, 0.0, Vector2.ONE)
			draw_texture_rect_region(CREATURE_ATLAS, Rect2(-24, -30, 48, 48), Rect2(144, 68, 48, 48), Color(1.0, 0.58 + flash_strength * 0.35, 0.48 + flash_strength * 0.4, 1.0))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		else:
			draw_texture_rect_region(CREATURE_ATLAS, Rect2(p.x - 24, p.y - 30, 48, 48), Rect2(144, 68, 48, 48))
		# Two compact segments make the slime's two-hit health readable at a glance.
		var hp := clampi(slime_health[i], 1, 2)
		var bar_position := Vector2(p.x - 11.0, p.y - 35.0)
		draw_rect(Rect2(bar_position - Vector2(2.0, 2.0), Vector2(26.0, 7.0)), Color(0.025, 0.04, 0.045, 0.88), true)
		for segment in range(2):
			var segment_color := Color(0.35, 0.86, 0.49) if segment < hp else Color(0.20, 0.25, 0.24)
			if hp == 1 and segment == 0:
				segment_color = Color(0.98, 0.63, 0.25)
			draw_rect(Rect2(bar_position + Vector2(float(segment) * 12.0, 0.0), Vector2(10.0, 3.0)), segment_color, true)

func _draw_hud(size: Vector2) -> void:
	# Minimal exploration HUD; full resource counts live in the inventory panel.
	var hp_ratio := clampf(float(health) / 100.0, 0.0, 1.0)
	var hp_color := Color(0.28, 0.78, 0.48) if health > 60 else (Color(0.94, 0.63, 0.24) if health > 25 else Color(0.84, 0.25, 0.26))
	draw_rect(Rect2(16, 16, 194, 52), Color(0.025, 0.05, 0.06, 0.54), true, 10.0)
	draw_arc(Vector2(37, 38), 12.0, 0.0, TAU, 24, Color(0.88, 0.76, 0.47, 0.9), 1.5, true)
	draw_string(ThemeDB.fallback_font, Vector2(33, 43), "✦", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.98, 0.87, 0.59))
	draw_rect(Rect2(56, 28, 136, 12), Color(0.01, 0.025, 0.03, 0.88), true, 5.0)
	draw_rect(Rect2(58, 30, 132.0 * hp_ratio, 8), hp_color, true, 4.0)
	draw_string(ThemeDB.fallback_font, Vector2(57, 56), "%d HP" % health, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.90, 0.95, 0.88))
	draw_string(ThemeDB.fallback_font, Vector2(size.x - 18, 28), "DAY %d" % day_count, HORIZONTAL_ALIGNMENT_RIGHT, -1, 14, Color(0.98, 0.88, 0.63))
	draw_string(ThemeDB.fallback_font, Vector2(size.x - 18, 48), biome_at(int(player.x / TILE)).to_upper(), HORIZONTAL_ALIGNMENT_RIGHT, -1, 11, Color(0.81, 0.91, 0.83))
	if selected_item != "" and int(inventory.get(selected_item, 0)) > 0:
		draw_string(ThemeDB.fallback_font, Vector2(size.x - 18, 67), "%s ×%d" % [selected_item.to_upper(), int(inventory[selected_item])], HORIZONTAL_ALIGNMENT_RIGHT, -1, 11, Color(0.98, 0.83, 0.49))
	if message_timer > 0.0:
		var width := minf(size.x - 40.0, 440.0)
		draw_rect(Rect2((size.x - width) * 0.5, 24, width, 32), Color(0.025, 0.05, 0.06, 0.78), true, 8.0)
		draw_string(ThemeDB.fallback_font, Vector2(size.x * 0.5, 45), message, HORIZONTAL_ALIGNMENT_CENTER, width - 18, 14, Color(1.0, 0.91, 0.69))

func _handle_panel_touch(pos: Vector2) -> void:
	var size := get_viewport_rect().size
	var panel_size := Vector2(minf(size.x - 36.0, 720.0), minf(size.y - 48.0, 500.0))
	var panel_origin := (size - panel_size) * 0.5
	if Rect2(panel_origin.x + panel_size.x - 58.0, panel_origin.y + 12.0, 42.0, 36.0).has_point(pos):
		active_panel = ""
		return
	if active_panel == "inventory":
		var items: Array = inventory.keys()
		var col_width := (panel_size.x - 48.0) * 0.5
		for i in range(items.size()):
			var col := i % 2
			var line := int(i / 2)
			var item_rect := Rect2(panel_origin.x + 18.0 + float(col) * col_width, panel_origin.y + 72.0 + float(line) * 45.0, col_width - 10.0, 38.0)
			if item_rect.has_point(pos):
				selected_item = str(items[i])
				message = "Selected: " + selected_item
				message_timer = 1.2
				return
	elif active_panel == "craft":
		var list_left := panel_origin.x + 18.0
		var list_top := panel_origin.y + 72.0
		for i in range(RECIPES.size()):
			var recipe_rect := Rect2(list_left, list_top + float(i) * 44.0, minf(290.0, panel_size.x * 0.45), 40.0)
			if recipe_rect.has_point(pos):
				craft_recipe_index = i
				return
		var craft_rect := Rect2(panel_origin.x + panel_size.x - 190.0, panel_origin.y + panel_size.y - 70.0, 160.0, 48.0)
		if craft_rect.has_point(pos):
			_craft_selected()

func _draw_panel(size: Vector2) -> void:
	var panel_size := Vector2(minf(size.x - 36.0, 720.0), minf(size.y - 48.0, 500.0))
	var panel_origin := (size - panel_size) * 0.5
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.01, 0.025, 0.035, 0.68))
	draw_rect(Rect2(panel_origin + Vector2(5.0, 6.0), panel_size), Color(0.0, 0.0, 0.0, 0.42))
	draw_rect(Rect2(panel_origin, panel_size), Color(0.055, 0.085, 0.095, 0.98))
	draw_rect(Rect2(panel_origin, panel_size), Color(0.48, 0.63, 0.56), false, 3.0)
	draw_rect(Rect2(panel_origin + Vector2(4.0, 4.0), Vector2(panel_size.x - 8.0, 48.0)), Color(0.12, 0.20, 0.20))
	var title := "INVENTORY" if active_panel == "inventory" else "CRAFTING"
	draw_string(ThemeDB.fallback_font, panel_origin + Vector2(22.0, 35.0), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color(0.94, 0.82, 0.55))
	draw_rect(Rect2(panel_origin.x + panel_size.x - 58.0, panel_origin.y + 12.0, 42.0, 36.0), Color(0.43, 0.19, 0.17))
	draw_string(ThemeDB.fallback_font, panel_origin + Vector2(panel_size.x - 47.0, 37.0), "X", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color.WHITE)
	if active_panel == "inventory":
		var items: Array = inventory.keys()
		var col_width := (panel_size.x - 48.0) * 0.5
		for i in range(items.size()):
			var col := i % 2
			var line := int(i / 2)
			var item_rect := Rect2(panel_origin.x + 18.0 + float(col) * col_width, panel_origin.y + 72.0 + float(line) * 45.0, col_width - 10.0, 38.0)
			draw_rect(item_rect, Color(0.22, 0.34, 0.25) if str(items[i]) == selected_item else (Color(0.12, 0.17, 0.17) if int(inventory[items[i]]) > 0 else Color(0.075, 0.11, 0.12)))
			draw_rect(item_rect, Color(0.88, 0.75, 0.42) if str(items[i]) == selected_item else Color(0.31, 0.43, 0.40), false, 2.0 if str(items[i]) == selected_item else 1.0)
			draw_string(ThemeDB.fallback_font, item_rect.position + Vector2(10.0, 24.0), str(items[i]), HORIZONTAL_ALIGNMENT_LEFT, col_width - 70.0, 13, Color(0.91, 0.93, 0.85))
			draw_string(ThemeDB.fallback_font, item_rect.position + Vector2(item_rect.size.x - 38.0, 24.0), "x%d" % int(inventory[items[i]]), HORIZONTAL_ALIGNMENT_RIGHT, 30.0, 14, Color(0.98, 0.80, 0.43))
	else:
		var list_left := panel_origin.x + 18.0
		var list_top := panel_origin.y + 72.0
		for i in range(RECIPES.size()):
			var recipe_rect := Rect2(list_left, list_top + float(i) * 44.0, minf(290.0, panel_size.x * 0.45), 40.0)
			var chosen := i == craft_recipe_index
			draw_rect(recipe_rect, Color(0.26, 0.36, 0.30) if chosen else Color(0.10, 0.15, 0.16))
			draw_rect(recipe_rect, Color(0.82, 0.68, 0.39) if chosen else Color(0.27, 0.39, 0.37), false, 2.0 if chosen else 1.0)
			draw_string(ThemeDB.fallback_font, recipe_rect.position + Vector2(10.0, 25.0), str(RECIPES[i]), HORIZONTAL_ALIGNMENT_LEFT, recipe_rect.size.x - 18.0, 14, Color(0.98, 0.91, 0.70) if chosen else Color(0.86, 0.91, 0.85))
		var detail_x := panel_origin.x + minf(330.0, panel_size.x * 0.51)
		var detail_width := panel_origin.x + panel_size.x - detail_x - 20.0
		draw_string(ThemeDB.fallback_font, Vector2(detail_x, panel_origin.y + 105.0), str(RECIPES[craft_recipe_index]), HORIZONTAL_ALIGNMENT_LEFT, detail_width, 21, Color(0.98, 0.82, 0.48))
		draw_string(ThemeDB.fallback_font, Vector2(detail_x, panel_origin.y + 142.0), "REQUIRED MATERIALS", HORIZONTAL_ALIGNMENT_LEFT, detail_width, 13, Color(0.63, 0.81, 0.72))
		var requirement_lines := _recipe_requirements(str(RECIPES[craft_recipe_index]))
		for i in range(requirement_lines.size()):
			draw_string(ThemeDB.fallback_font, Vector2(detail_x, panel_origin.y + 170.0 + float(i) * 28.0), requirement_lines[i], HORIZONTAL_ALIGNMENT_LEFT, detail_width, 15, Color(0.88, 0.91, 0.82))
		var craft_rect := Rect2(panel_origin.x + panel_size.x - 190.0, panel_origin.y + panel_size.y - 70.0, 160.0, 48.0)
		draw_rect(craft_rect, Color(0.20, 0.52, 0.34))
		draw_rect(craft_rect, Color(0.62, 0.85, 0.62), false, 2.0)
		draw_string(ThemeDB.fallback_font, craft_rect.position + Vector2(22.0, 30.0), "CRAFT ITEM", HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color.WHITE)

func _recipe_requirements(recipe: String) -> Array[String]:
	match recipe:
		"Torch":
			return ["Wood: %d / 2" % int(inventory["Wood"]), "Stone: %d / 1" % int(inventory["Stone"]), "Output: 3 Torches"]
		"Planks":
			return ["Wood: %d / 2" % int(inventory["Wood"]), "Output: 4 Planks"]
		"Stone Block":
			return ["Stone: %d / 3" % int(inventory["Stone"]), "Output: 2 Stone Blocks"]
		"Stone Pickaxe":
			return ["Wood: %d / 3" % int(inventory["Wood"]), "Stone: %d / 4" % int(inventory["Stone"]), "Output: 1 Pickaxe"]
		"Stone Axe":
			return ["Wood: %d / 3" % int(inventory["Wood"]), "Stone: %d / 2" % int(inventory["Stone"]), "Output: 1 Axe"]
		"Campfire":
			return ["Wood: %d / 4" % int(inventory["Wood"]), "Stone: %d / 3" % int(inventory["Stone"]), "Output: 1 Campfire"]
		"Healing Salve":
			return ["Wild Essence: %d / 2" % int(inventory["Wild Essence"]), "Wood: %d / 1" % int(inventory["Wood"]), "Output: 1 Salve"]
	return ["No recipe data"]

func _draw_controls(size: Vector2) -> void:
	# Floating left-hand movement pad fades when idle.
	var center := _joystick_center(size)
	var active := joystick_id != -1 or mouse_joystick
	if active:
		center = joystick_origin
	var alpha := 0.62 if active else 0.27
	draw_circle(center, 49.0, Color(0.035, 0.07, 0.08, alpha))
	draw_arc(center, 45.0, 0.0, TAU, 48, Color(0.45, 0.84, 0.77, alpha), 2.0, true)
	var knob := center
	if active:
		var drag := joystick_current - joystick_origin
		drag.x = clampf(drag.x, -25.0, 25.0)
		drag.y = clampf(drag.y, -25.0, 25.0)
		knob += drag
	draw_circle(knob + Vector2(0, 3), 19.0, Color(0, 0, 0, 0.20))
	draw_circle(knob, 17.0, Color(0.29, 0.66, 0.59, 0.76 if active else 0.38))
	draw_arc(knob, 13.0, 3.4, 6.0, 20, Color(0.86, 1.0, 0.88, 0.62), 1.5, true)

	# One large ancient rune replaces the seven-button cluster.
	var rune := _main_button_center(size, 1)
	var pressed := action_touch_id != -1 or action_mouse_down
	draw_circle(rune + Vector2(0, 5), 48.0, Color(0, 0, 0, 0.24))
	draw_circle(rune, 46.0, Color(0.025, 0.055, 0.06, 0.50 if pressed else 0.30))
	draw_arc(rune, 43.0, 0.0, TAU, 64, Color(0.42, 0.88, 0.77, 0.82 if pressed else 0.50), 2.0, true)
	draw_arc(rune, 35.0, 0.0, TAU, 8, Color(0.86, 0.69, 0.39, 0.72), 1.5, true)
	for i in range(8):
		var angle := float(i) * TAU / 8.0 - PI * 0.5
		var direction := Vector2(cos(angle), sin(angle))
		draw_line(rune + direction * 36.0, rune + direction * 40.0, Color(0.81, 0.91, 0.76, 0.82), 2.0)
	draw_colored_polygon(PackedVector2Array([rune + Vector2(0, -19), rune + Vector2(7, -2), rune + Vector2(2, 2), rune + Vector2(4, 17), rune + Vector2(-4, 17), rune + Vector2(-2, 2), rune + Vector2(-7, -2)]), Color(0.95, 0.88, 0.65, 0.90))
	for p in [Vector2(0, 25), Vector2(25, 0), Vector2(0, -25), Vector2(-25, 0)]:
		draw_circle(rune + p, 2.5, Color(0.47, 0.94, 0.78, 0.85))
	_draw_menu_sigil(_menu_button_center(size, 0), "bag", Color(0.43, 0.82, 0.59))
	_draw_menu_sigil(_menu_button_center(size, 1), "craft", Color(0.63, 0.78, 0.87))
	if context_action != "" and active_panel == "":
		_draw_context_rune(_context_rune_position(), context_action)
	if radial_open:
		_draw_item_wheel()

func _update_context_hint() -> void:
	context_action = ""
	var player_tile := int(floor(player.x / TILE))
	var target := player_tile + facing
	if target >= 0 and target < WORLD_WIDTH and _tree_exists(target):
		if absf(float(target * TILE + TILE / 2) - player.x) <= TILE * 1.6 and absf(_ground_surface_y(target) - _ground_surface_y(player_tile)) <= TILE * 1.5:
			context_action = "tree"
			return
	var tx := int(floor((player.x + float(facing) * 42.0) / TILE))
	var ty := int(floor((player.y + 10.0) / TILE))
	for cell in [Vector2i(tx, ty), Vector2i(tx, ty - 1), Vector2i(tx, ty + 1)]:
		var kind := block_type(cell.x, cell.y)
		if kind != "" and kind != "bedrock":
			context_action = "resource"
			return
	for slime in slimes:
		if absf(slime.x - player.x) < 74.0 and absf(slime.y - player.y) < 54.0:
			context_action = "enemy"
			return

func _draw_context_rune(center: Vector2, kind: String) -> void:
	var accent := Color(0.47, 0.91, 0.71)
	if kind == "enemy":
		accent = Color(1.0, 0.47, 0.35)
	elif kind == "resource":
		accent = Color(0.83, 0.77, 0.48)
	draw_circle(center, 17.0, Color(0.02, 0.05, 0.06, 0.62))
	draw_arc(center, 15.0, 0.0, TAU, 24, accent, 2.0, true)
	if kind == "tree":
		draw_colored_polygon(PackedVector2Array([center + Vector2(0, -9), center + Vector2(-7, 0), center + Vector2(-3, 0), center + Vector2(-3, 7), center + Vector2(3, 7), center + Vector2(3, 0), center + Vector2(7, 0)]), accent)
	elif kind == "enemy":
		draw_line(center + Vector2(-6, -6), center + Vector2(6, 6), accent, 3.0)
		draw_line(center + Vector2(6, -6), center + Vector2(-6, 6), accent, 3.0)
	else:
		draw_colored_polygon(PackedVector2Array([center + Vector2(0, -8), center + Vector2(7, 0), center + Vector2(0, 8), center + Vector2(-7, 0)]), accent)

func _draw_menu_sigil(center: Vector2, kind: String, accent: Color) -> void:
	draw_circle(center, 22.0, Color(0.025, 0.055, 0.06, 0.56))
	draw_arc(center, 20.0, 0.0, TAU, 32, accent, 1.5, true)
	if kind == "bag":
		draw_rect(Rect2(center + Vector2(-7, -4), Vector2(14, 13)), accent, false, 2.0)
		draw_arc(center + Vector2(0, -4), 5.0, PI, TAU, 12, accent, 2.0, true)
	else:
		draw_line(center + Vector2(-8, -6), center + Vector2(8, -6), accent, 2.0)
		draw_line(center + Vector2(-6, -1), center + Vector2(6, -1), accent, 2.0)
		draw_line(center + Vector2(-4, 4), center + Vector2(4, 4), accent, 2.0)

func _draw_item_wheel() -> void:
	var center := action_touch_origin
	draw_circle(center, 116.0, Color(0.015, 0.035, 0.04, 0.86))
	draw_arc(center, 112.0, 0.0, TAU, 64, Color(0.47, 0.85, 0.72, 0.86), 2.0, true)
	var labels := ["HIT", "USE", "BAG", "CRAFT", "CHECK", "ACT", "JUMP", "ITEM"]
	var actions := ["attack", "use", "inventory", "craft", "checkpoint", "interact", "jump", "item"]
	for i in range(8):
		var angle := float(i) * TAU / 8.0 - PI * 0.5
		var p := center + Vector2(cos(angle), sin(angle)) * 76.0
		var selected := actions[i] == radial_choice or (actions[i] == "item" and inventory.has(radial_choice))
		draw_circle(p, 25.0, Color(0.16, 0.33, 0.28, 0.96) if selected else Color(0.06, 0.12, 0.13, 0.94))
		draw_arc(p, 23.0, 0.0, TAU, 24, Color(0.92, 0.76, 0.46, 0.92) if selected else Color(0.44, 0.68, 0.61, 0.78), 1.5, true)
		var label := labels[i]
		if actions[i] == "item" and not radial_items.is_empty():
			label = str(radial_items[clampi(int(floor(float(radial_items.size()) * 0.5)), 0, radial_items.size() - 1)]).substr(0, 5).to_upper()
		draw_string(ThemeDB.fallback_font, p + Vector2(0, 4), label, HORIZONTAL_ALIGNMENT_CENTER, 46.0, 8, Color(0.94, 0.96, 0.85))
	draw_circle(center, 22.0, Color(0.12, 0.24, 0.22, 0.98))
	draw_arc(center, 20.0, 0.0, TAU, 24, Color(0.76, 0.91, 0.76), 1.5, true)

func _joystick_center(size: Vector2) -> Vector2:
	return Vector2(82.0, size.y - 82.0)

func _main_button_center(size: Vector2, index: int) -> Vector2:
	return Vector2(size.x - 82.0, size.y - 82.0)

func _save_world() -> void:
	var data := {"save_version": 2, "world_seed": world_seed, "player_x": player.x, "player_y": player.y, "health": health, "day_count": day_count, "day_time": day_time, "checkpoint_tile": checkpoint_tile, "inventory": inventory, "blocks": world_blocks, "harvested_trees": harvested_trees, "tree_health": tree_health, "placed_objects": placed_objects, "craft_recipe_index": craft_recipe_index, "slime_health": slime_health, "slimes": []}
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
	var saved_recipe_index := int(parsed.get("craft_recipe_index", 0))
	# Save version 1 used index 4 for Campfire and 5 for Healing Salve.
	# Stone Axe was inserted at index 4 in version 2, so migrate old saves.
	if int(parsed.get("save_version", 1)) < 2 and saved_recipe_index >= 4:
		saved_recipe_index += 1
	craft_recipe_index = clampi(saved_recipe_index, 0, RECIPES.size() - 1)
	var saved_slime_health: Variant = parsed.get("slime_health", [])
	slime_health.clear()
	# Older builds stored HP in a coordinate-keyed dictionary. Ignore it because
	# slime coordinates move; old saves safely restore each slime at 2 HP.
	if saved_slime_health is Array:
		for saved_hp in saved_slime_health:
			slime_health.append(clampi(int(saved_hp), 1, 2))
	slimes.clear()
	for item in parsed.get("slimes", []):
		if item is Array and item.size() >= 2:
			slimes.append(Vector2(float(item[0]), float(item[1])))
	_ensure_slime_health()
