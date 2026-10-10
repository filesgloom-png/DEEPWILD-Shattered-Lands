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
var inventory := {"Wood": 0, "Stone": 0, "Copper": 0}
var world_blocks: Dictionary = {}
var slimes: Array[Vector2] = []
var health := 100
var day_time := 0.0
var message := "Welcome to the Shattered Lands"
var message_timer := 4.0
var save_timer := 0.0
var world_seed := 0

func _ready() -> void:
	randomize()
	world_seed = randi()
	_load_world()
	if slimes.is_empty():
		slimes = [Vector2(520, 0), Vector2(890, 0), Vector2(1260, 0)]
	for slime in slimes:
		slime.y = ground_y_at(int(slime.x / TILE)) - 16
	set_process(true)

func _process(delta: float) -> void:
	day_time = fmod(day_time + delta * 0.018, TAU)
	message_timer = maxf(0.0, message_timer - delta)
	save_timer += delta
	if save_timer >= 12.0:
		save_timer = 0.0
		_save_world()
	_update_player(delta)
	_update_slimes(delta)
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
	var ground := ground_y_at(int(floor(player.x / TILE))) - 38.0
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
		slime.y = ground_y_at(int(slime.x / TILE)) - 16.0
		slimes[i] = slime
	if health <= 0:
		health = 100
		player = Vector2(320, ground_y_at(13) - 38)
		velocity = Vector2.ZERO
		message = "You recovered at the camp"
		message_timer = 3.0

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

func _mine_block() -> void:
	var tx := int(floor((player.x + facing * 42.0) / TILE))
	var ty := int(floor((player.y + 10.0) / TILE))
	var candidates := [Vector2i(tx, ty), Vector2i(tx, ty - 1), Vector2i(tx, ty + 1), Vector2i(int(player.x / TILE), ty)]
	for cell in candidates:
		var kind := block_type(cell.x, cell.y)
		if kind == "" or kind == "bedrock":
			continue
		world_blocks[str(cell.x) + ":" + str(cell.y)] = ""
		if kind == "grass" or kind == "dirt":
			inventory["Stone"] = int(inventory["Stone"]) + 1
		elif kind == "stone":
			inventory["Stone"] = int(inventory["Stone"]) + 1
		if cell.y > 23 and cell.x % 7 == 0:
			inventory["Copper"] = int(inventory["Copper"]) + 1
		message = "+1 " + ("Copper" if cell.y > 23 and cell.x % 7 == 0 else "Stone")
		message_timer = 1.2
		return
	message = "Move close to a block to mine"
	message_timer = 1.5

func _attack() -> void:
	for i in range(slimes.size() - 1, -1, -1):
		if absf(slimes[i].x - (player.x + facing * 28.0)) < 62.0 and absf(slimes[i].y - player.y) < 65.0:
			slimes.remove_at(i)
			inventory["Wood"] = int(inventory["Wood"]) + 1
			message = "Slime defeated! +1 wild essence"
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
		_craft_torch()

func _craft_torch() -> void:
	if int(inventory["Wood"]) >= 1:
		inventory["Wood"] = int(inventory["Wood"]) - 1
		message = "Torch crafted"
	else:
		message = "Need wood to craft a torch"
	message_timer = 1.5

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
			elif kind == "stone":
				color = Color(0.35, 0.37, 0.40)
			elif kind == "bedrock":
				color = Color(0.16, 0.18, 0.22)
			if ty > surface and tx % 7 == 0 and ty > surface + 7:
				color = Color(0.32, 0.44, 0.49) if kind == "stone" else color
			draw_rect(rect, color)
			draw_rect(Rect2(px, py, TILE, 2), color.lightened(0.15))
			if kind == "stone" and (tx * 13 + ty * 7) % 11 == 0:
				draw_rect(Rect2(px + 6, py + 8, 5, 4), Color(0.71, 0.47, 0.27))
		if tx % 9 == 2 and surface > 0:
			_draw_tree(px, float(surface * TILE) - camera_offset.y)

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
	draw_rect(Rect2(16, 16, 330, 102), Color(0.055, 0.08, 0.10, 0.84))
	draw_string(ThemeDB.fallback_font, Vector2(30, 42), "DEEPWILD", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(0.91, 0.83, 0.57))
	draw_string(ThemeDB.fallback_font, Vector2(30, 65), "HP", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)
	draw_rect(Rect2(62, 52, 150, 15), Color(0.28, 0.15, 0.16))
	draw_rect(Rect2(62, 52, 150.0 * float(health) / 100.0, 15), Color(0.84, 0.25, 0.26))
	draw_string(ThemeDB.fallback_font, Vector2(30, 91), "WOOD %d   STONE %d   COPPER %d" % [inventory["Wood"], inventory["Stone"], inventory["Copper"]], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.88, 0.90, 0.82))
	draw_string(ThemeDB.fallback_font, Vector2(size.x - 18, 28), "DAY 1  •  EXPLORER", HORIZONTAL_ALIGNMENT_RIGHT, -1, 14, Color.WHITE)
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
	_draw_button(Vector2(size.x - 72, 74), "CRAFT", Color(0.32, 0.56, 0.39))

func _draw_button(center: Vector2, label: String, color: Color) -> void:
	draw_circle(center, 36, Color(0.04, 0.06, 0.07, 0.52))
	draw_circle(center, 29, color.darkened(0.1))
	draw_string(ThemeDB.fallback_font, center + Vector2(0, 5), label, HORIZONTAL_ALIGNMENT_CENTER, 72, 12, Color.WHITE)

func _save_world() -> void:
	var data := {"world_seed": world_seed, "player_x": player.x, "player_y": player.y, "health": health, "inventory": inventory, "blocks": world_blocks, "slimes": []}
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
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	world_seed = int(parsed.get("world_seed", world_seed))
	player = Vector2(float(parsed.get("player_x", 320.0)), float(parsed.get("player_y", 240.0)))
	health = int(parsed.get("health", 100))
	var saved_inventory = parsed.get("inventory", {})
	for key in inventory:
		inventory[key] = int(saved_inventory.get(key, inventory[key]))
	world_blocks = parsed.get("blocks", {})
	slimes.clear()
	for item in parsed.get("slimes", []):
		if item is Array and item.size() >= 2:
			slimes.append(Vector2(float(item[0]), float(item[1])))
