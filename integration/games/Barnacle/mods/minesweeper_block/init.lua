-- barnacle sweeper
-- minesweeper block mit textures
-- musik läuft über barnacle_musicmanager solange das spiel offen ist

local CONFIGS = {
	easy   = { rows = 9,  cols = 9,  mines = 10, label = "EASY" },
	medium = { rows = 12, cols = 12, mines = 20, label = "NORMAL" },
	hard   = { rows = 12, cols = 16, mines = 40, label = "HARD" },
}

local player_games = {}
local player_clears = {}

local TEXTURES = {
	bg     = "barnacle_sweeper_bg.png",
	hidden = "barnacle_cell_hidden.png",
	open   = "barnacle_cell_open.png",
	flag   = "barnacle_cell_flag.png",
	mine   = "barnacle_cell_mine.png",
	hit    = "barnacle_cell_hit.png",
}

local NUM_TEXTURES = {
	[1] = "barnacle_num_1.png",
	[2] = "barnacle_num_2.png",
	[3] = "barnacle_num_3.png",
	[4] = "barnacle_num_4.png",
	[5] = "barnacle_num_5.png",
	[6] = "barnacle_num_6.png",
	[7] = "barnacle_num_7.png",
	[8] = "barnacle_num_8.png",
}

local function start_sweeper_music(player)
	if barnacle_musicmanager and barnacle_musicmanager.start_minesweeper_music then
		barnacle_musicmanager.start_minesweeper_music(player)
	end
end

local function stop_sweeper_music(player)
	if barnacle_musicmanager and barnacle_musicmanager.stop_minesweeper_music then
		barnacle_musicmanager.stop_minesweeper_music(player)
	end
end

local function new_board(cfg)
	local board = {}

	for r = 1, cfg.rows do
		board[r] = {}
		for c = 1, cfg.cols do
			board[r][c] = 0
		end
	end

	return board
end

local function place_mines(game, sr, sc)
	local cfg = game.cfg
	local board = game.board
	local placed = 0

	math.randomseed(os.time() + math.random(1, 99999))

	while placed < cfg.mines do
		local r = math.random(cfg.rows)
		local c = math.random(cfg.cols)

		if board[r][c] ~= -1 and not (math.abs(r - sr) <= 1 and math.abs(c - sc) <= 1) then
			board[r][c] = -1
			placed = placed + 1
		end
	end

	for r = 1, cfg.rows do
		for c = 1, cfg.cols do
			if board[r][c] ~= -1 then
				local count = 0

				for dr = -1, 1 do
					for dc = -1, 1 do
						local nr = r + dr
						local nc = c + dc

						if nr >= 1 and nr <= cfg.rows and nc >= 1 and nc <= cfg.cols and board[nr][nc] == -1 then
							count = count + 1
						end
					end
				end

				board[r][c] = count
			end
		end
	end
end

local function flood_reveal(game, r, c)
	local cfg = game.cfg

	if r < 1 or r > cfg.rows or c < 1 or c > cfg.cols then
		return
	end

	if game.revealed[r][c] or game.flagged[r][c] then
		return
	end

	game.revealed[r][c] = true

	if game.board[r][c] == 0 then
		for dr = -1, 1 do
			for dc = -1, 1 do
				if not (dr == 0 and dc == 0) then
					flood_reveal(game, r + dr, c + dc)
				end
			end
		end
	end
end

local function check_win(game)
	local cfg = game.cfg
	local hidden = 0

	for r = 1, cfg.rows do
		for c = 1, cfg.cols do
			if not game.revealed[r][c] then
				hidden = hidden + 1
			end
		end
	end

	return hidden == cfg.mines
end

local function count_flags(game)
	local count = 0

	for r = 1, game.cfg.rows do
		for c = 1, game.cfg.cols do
			if game.flagged[r][c] then
				count = count + 1
			end
		end
	end

	return count
end

local function get_cleared_count(player_name, difficulty)
	if not player_clears[player_name] then
		return 0
	end

	return player_clears[player_name][difficulty] or 0
end

local function add_cleared_count(player_name, difficulty)
	player_clears[player_name] = player_clears[player_name] or {}
	player_clears[player_name][difficulty] = (player_clears[player_name][difficulty] or 0) + 1

	return player_clears[player_name][difficulty]
end

local function init_game(difficulty, player_name)
	difficulty = difficulty or "medium"

	local cfg = CONFIGS[difficulty] or CONFIGS.medium

	local game = {
		cfg = cfg,
		difficulty = difficulty,
		board = new_board(cfg),
		revealed = {},
		flagged = {},
		first_click = true,
		game_over = false,
		won = false,
		start_time = nil,
		hit_r = nil,
		hit_c = nil,
		cleared_count = player_name and get_cleared_count(player_name, difficulty) or 0,
	}

	for r = 1, cfg.rows do
		game.revealed[r] = {}
		game.flagged[r] = {}

		for c = 1, cfg.cols do
			game.revealed[r][c] = false
			game.flagged[r][c] = false
		end
	end

	return game
end

local function esc(text)
	return minetest.formspec_escape(text)
end

local function build_formspec(game)
	local cfg = game.cfg

	local cs = 0.55
	local board_oy = 2.0

	local board_w = cfg.cols * cs
	local board_h = cfg.rows * cs

	local fw = math.max(board_w + 0.9, 7.2)
	local fh = board_h + 2.85

	local ox = (fw - board_w) / 2
	local oy = board_oy

	local f = {}

	local function add(s)
		f[#f + 1] = s
	end

	add("formspec_version[4]")
	add("size[" .. fw .. "," .. fh .. "]")
	add("no_prepend[]")
	add("bgcolor[#05070a;true]")
	add("background[0,0;" .. fw .. "," .. fh .. ";" .. TEXTURES.bg .. "]")

	add("box[0,0;" .. fw .. ",1.55;#05070acc]")
	add("label[0.45,0.35;" .. minetest.colorize("#d8f4ff", esc("BARNACLE SWEEPER")) .. "]")

	local flags = count_flags(game)
	local barnacles_left = cfg.mines - flags
	local time_text = game.start_time and tostring(os.time() - game.start_time) or "0"
	local cleared = game.cleared_count or 0

	add("label[0.45,0.85;" ..
		minetest.colorize("#ffb0a0", esc("BARNACLES: " .. barnacles_left)) ..
		"   " ..
		minetest.colorize("#9fdcff", esc("TIME: " .. time_text .. "s")) ..
		"   " ..
		minetest.colorize("#8dffbb", esc("BOARDS CLEARED: " .. cleared)) ..
	"]")

	local diff_y = 1.35
	local dx = 0.45

	add("button[" .. dx .. "," .. diff_y .. ";1.35,0.42;diff_easy;" .. esc("Easy") .. "]")
	add("button[" .. (dx + 1.45) .. "," .. diff_y .. ";1.35,0.42;diff_medium;" .. esc("Normal") .. "]")
	add("button[" .. (dx + 2.9) .. "," .. diff_y .. ";1.35,0.42;diff_hard;" .. esc("Hard") .. "]")
	add("button[" .. (fw - 1.65) .. ",1.35;1.2,0.42;restart;" .. esc("Reset") .. "]")

	if game.game_over then
		add("box[0.35,1.78;" .. (fw - 0.7) .. ",0.45;" .. (game.won and "#003d25dd" or "#4a0000dd") .. "]")

		if game.won then
			add("label[" .. (fw / 2 - 1.75) .. ",1.9;" ..
				minetest.colorize("#8dffbb", esc("BOARD CLEARED. WELL DONE.")) ..
			"]")
		else
			add("label[" .. (fw / 2 - 1.55) .. ",1.9;" ..
				minetest.colorize("#ff8d8d", esc("BARNACLE TRIGGERED. GAME OVER.")) ..
			"]")
		end

		oy = 2.35
	end

	add("box[" .. (ox - 0.08) .. "," .. (oy - 0.08) .. ";" .. (board_w + 0.16) .. "," .. (board_h + 0.16) .. ";#000000aa]")

	for r = 1, cfg.rows do
		for c = 1, cfg.cols do
			local x = ox + (c - 1) * cs
			local y = oy + (r - 1) * cs

			local name = "cell_" .. r .. "_" .. c
			local tex = TEXTURES.hidden

			if game.revealed[r][c] then
				local value = game.board[r][c]

				if game.hit_r == r and game.hit_c == c then
					tex = TEXTURES.hit
				elseif value == -1 or value == "X" then
					tex = TEXTURES.mine
				elseif value == 0 then
					tex = TEXTURES.open
				else
					tex = NUM_TEXTURES[value] or TEXTURES.open
				end
			elseif game.flagged[r][c] then
				tex = TEXTURES.flag
				name = "flag_" .. r .. "_" .. c
			end

			if game.game_over then
				add("image[" .. x .. "," .. y .. ";" .. cs .. "," .. cs .. ";" .. tex .. "]")
			else
				add("image_button[" .. x .. "," .. y .. ";" .. cs .. "," .. cs .. ";" .. tex .. ";" .. name .. ";]")
			end
		end
	end

	local bottom_y = oy + board_h + 0.25

	add("box[0," .. bottom_y .. ";" .. fw .. ",0.55;#05070acc]")
	add("label[0.45," .. (bottom_y + 0.17) .. ";" ..
		minetest.colorize("#8da6ad", esc("Left click: reveal")) ..
	"]")

	return table.concat(f, "")
end

local function show_game(player_name, game)
	player_games[player_name] = game
	minetest.show_formspec(player_name, "minesweeper_block:game", build_formspec(game))
end

-- blocks hier
-- tile reihenfolge
-- top bottom seiten hinten vorne

minetest.register_node("minesweeper_block:minesweeper", {
	description = "Barnacle Sweeper\nRight-click to play",

	tiles = {
		"barnacle_sweeper_block_side.png",
		"barnacle_sweeper_block_side.png",
		"barnacle_sweeper_block_side.png",
		"barnacle_sweeper_block_side.png",
		"barnacle_sweeper_block_side.png",
		"barnacle_sweeper_block_top.png",
	},

	paramtype2 = "facedir",
	place_param2 = 0,

	groups = {
		cracky = 3,
		oddly_breakable_by_hand = 1,
	},

	sounds = default and default.node_sound_stone_defaults() or nil,

	on_rightclick = function(pos, node, clicker, itemstack, pointed_thing)
		if not clicker or not clicker:is_player() then
			return itemstack
		end

		local name = clicker:get_player_name()
		local game = player_games[name] or init_game("medium", name)

		game.cleared_count = get_cleared_count(name, game.difficulty)

		show_game(name, game)
		start_sweeper_music(clicker)

		return itemstack
	end,
})

minetest.register_node("minesweeper_block:minesweeper_block2", {
	description = "Barnacle Sweeper Cabinet Block",

	tiles = {
		"barnacle_sweeper_block_side.png",
		"barnacle_sweeper_block_side.png",
		"barnacle_sweeper_block_side.png",
		"barnacle_sweeper_block_side.png",
		"barnacle_sweeper_block_side.png",
		"barnacle_sweeper_block2_front.png",
	},

	paramtype2 = "facedir",
	place_param2 = 0,

	groups = {
		cracky = 3,
		oddly_breakable_by_hand = 1,
	},

	sounds = default and default.node_sound_stone_defaults() or nil,
})

minetest.register_on_player_receive_fields(function(player, formname, fields)
	if formname ~= "minesweeper_block:game" then
		return
	end

	local name = player:get_player_name()
	local game = player_games[name]

	if not game then
		stop_sweeper_music(player)
		return
	end

	if fields.quit then
		stop_sweeper_music(player)
		return
	end

	if fields.restart then
		game = init_game(game.difficulty, name)
		show_game(name, game)
		start_sweeper_music(player)
		return
	end

	for difficulty, _ in pairs(CONFIGS) do
		if fields["diff_" .. difficulty] then
			game = init_game(difficulty, name)
			show_game(name, game)
			start_sweeper_music(player)
			return
		end
	end

	if game.game_over then
		return
	end

	for key, _ in pairs(fields) do
		local fr, fc = key:match("^flag_(%d+)_(%d+)$")

		if fr and fc then
			fr = tonumber(fr)
			fc = tonumber(fc)

			game.flagged[fr][fc] = false
			show_game(name, game)
			start_sweeper_music(player)
			return
		end

		local cr, cc = key:match("^cell_(%d+)_(%d+)$")

		if cr and cc then
			cr = tonumber(cr)
			cc = tonumber(cc)

			if game.revealed[cr][cc] then
				return
			end

			if game.first_click then
				game.first_click = false
				game.start_time = os.time()
				place_mines(game, cr, cc)
			end

			if game.board[cr][cc] == -1 then
				for r = 1, game.cfg.rows do
					for c = 1, game.cfg.cols do
						if game.board[r][c] == -1 then
							game.revealed[r][c] = true
						end
					end
				end

				game.board[cr][cc] = "X"
				game.hit_r = cr
				game.hit_c = cc
				game.game_over = true
				game.won = false

				minetest.sound_play("default_dig_cracky", {
					to_player = name,
					gain = 1.0,
				}, true)
			else
				flood_reveal(game, cr, cc)

				if check_win(game) then
					game.game_over = true
					game.won = true
					game.cleared_count = add_cleared_count(name, game.difficulty)

					if game.difficulty == "hard" and barnacle_achivements then
						barnacle_achivements.unlock_barnacle_sweeper(player)
					end

					minetest.sound_play("default_place_node", {
						to_player = name,
						gain = 1.0,
					}, true)
				end
			end

			show_game(name, game)
			start_sweeper_music(player)
			return
		end
	end
end)

minetest.register_on_leaveplayer(function(player)
	stop_sweeper_music(player)
end)

if minetest.get_modpath("default") then
	minetest.register_craft({
		output = "minesweeper_block:minesweeper",
		recipe = {
			{ "default:steel_ingot", "default:obsidian", "default:steel_ingot" },
			{ "default:obsidian", "default:diamond", "default:obsidian" },
			{ "default:steel_ingot", "default:obsidian", "default:steel_ingot" },
		},
	})

	minetest.register_craft({
		output = "minesweeper_block:minesweeper_block2",
		recipe = {
			{ "group:stone", "group:stone", "group:stone" },
			{ "group:stone", "default:obsidian", "group:stone" },
			{ "group:stone", "group:stone", "group:stone" },
		},
	})
end

minetest.register_craft({
	output = "minesweeper_block:minesweeper",
	recipe = {
		{ "group:stone", "group:stone", "group:stone" },
		{ "group:stone", "",            "group:stone" },
		{ "group:stone", "group:stone", "group:stone" },
	},
})

minetest.log("action", "[minesweeper_block] Barnacle Sweeper loaded.")