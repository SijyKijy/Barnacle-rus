-- frontend menu gottlos ich hoff das geht so
-- main menu pause wake up und reset
-- esc lassen wir in ruhe engine macht ihr ding
-- new game setzt spieler und progress zeug zurück
-- map bleibt stehen also gebaute sachen bleiben
-- pause über aux1 meistens E
-- finale lock blockt wake new game und zurück ins menü
-- freeze fix damit man nicht nach oben wegfliegt
-- detach vorher falls spieler sitzt oder irgendwo dran hängt
-- optionen sind hier auch noch mit drin

local storage = minetest.get_mod_storage()

-- zeit setzen wie /time set ungefähr
local function set_time_24000(ticks)
	ticks = tonumber(ticks) or 0
	ticks = ticks % 24000
	minetest.set_timeofday(ticks / 24000)
end

-- gui scale beim start wieder rein
local GLOBAL_GUI_KEY = "opt.__global.gui_scale"

minetest.register_on_mods_loaded(function()
	local v = storage:get_string(GLOBAL_GUI_KEY)
	if v == "" then return end
	local scale = tonumber(v)
	if not scale then return end
	if scale < 0.80 then scale = 0.80 end
	if scale > 1.60 then scale = 1.60 end

	if minetest.settings and minetest.settings.set then
		pcall(minetest.settings.set, minetest.settings, "gui_scaling", string.format("%.2f", scale))
	end
	if minetest.settings and minetest.settings.write then
		pcall(minetest.settings.write, minetest.settings)
	end
end)

-- bisschen setup zeug
local START_POS = {x = -1, y = 11, z = 0}
local START_HP  = 20

local TEX_BLACK = "barnacle_black.png"
local TEX_LOGO  = "barnacle_logo.png"
local TEX_FRAME = "barnacle_frame.png"
local TEX_FRAME_OPTIONS = "barnacle_frame_options.png"
local TEX_CONTROLS = "barnacle_controls.png"

local LOGO_ASPECT = 1.308
local UI_W, UI_H = 18, 10
local MENU_START_Y = 0.54
local MENU_GAP_MULT = 1.12
local FRAME_SCALE = -80

local SAVE_KEY = "save_v1"

-- progress entities falls wir welche brauchen
local PROGRESS_SPAWNS = {
	-- beispiel falls später kisten oder rocks resetten sollen
	-- { id="crate_01", name="barnacle:breakable_crate", pos={x=10,y=2,z=5}, yaw=0 },
	-- { id="rock_01",  name="barnacle:breakable_rock",  pos={x=14,y=2,z=6}, yaw=0 },
}

local RESET_NODES = {}
local FIND_RADIUS = 6

-- wer hat was offen und so
local hud_ids    = {}
local menu_open  = {}
local menu_state = {}
local pause_open = {}
local pause_mode = {}
local notice     = {}
local menu_music = {}
local menu_music_gain = {}
local wake_open = {}
local waking = {}
local frozen_pos = {}
local controls_disabled = {}
local frozen_tick = 0

-- kleine helper
local function esc(s) return minetest.formspec_escape(tostring(s or "")) end
local function clamp(n, a, b)
	n = tonumber(n) or a
	if n < a then return a end
	if n > b then return b end
	return n
end
local function pname(player) return player and player:get_player_name() or "" end

local function finale_locked()
	return minetest.global_exists("barnacle_voice_ai")
		and barnacle_voice_ai.is_finale_locked
		and barnacle_voice_ai.is_finale_locked()
end

-- optionen pro spieler
local function opt_key(pn, k) return ("opt.%s.%s"):format(pn, k) end

local MOUSE_BASE_KEY = "opt.__global.mouse_sensitivity_base"

local function get_volume(pn)
	local v = storage:get_string(opt_key(pn, "volume"))
	if v == "" then return 100 end
	return clamp(tonumber(v), 0, 100)
end

local function set_volume(pn, v)
	v = clamp(v, 0, 100)
	storage:set_string(opt_key(pn, "volume"), tostring(v))
end

local function get_music_volume(pn)
	local v = storage:get_string(opt_key(pn, "music_volume"))
	if v == "" then return 80 end
	return clamp(tonumber(v), 0, 100)
end

local function set_music_volume(pn, v)
	v = clamp(v, 0, 100)
	storage:set_string(opt_key(pn, "music_volume"), tostring(v))

	if minetest.global_exists("barnacle_musicmanager")
		and barnacle_musicmanager.set_music_volume then
		barnacle_musicmanager.set_music_volume(v)
	end
end

local function get_mouse_base()
	local stored = storage:get_string(MOUSE_BASE_KEY)
	local v = tonumber(stored)
	if v and v > 0 then return v end

	local cur = 0.2
	if minetest.settings and minetest.settings.get then
		cur = tonumber(minetest.settings:get("mouse_sensitivity")) or cur
	end
	if cur <= 0 then cur = 0.2 end

	storage:set_string(MOUSE_BASE_KEY, tostring(cur))
	return cur
end

local function get_mouse_sensitivity(pn)
	local v = storage:get_string(opt_key(pn, "mouse_sensitivity"))
	if v == "" then return 100 end
	return clamp(tonumber(v), 50, 150)
end

local function set_mouse_sensitivity(pn, v)
	v = clamp(v, 50, 150)
	storage:set_string(opt_key(pn, "mouse_sensitivity"), tostring(v))

	if minetest.settings and minetest.settings.set then
		local base = get_mouse_base()
		pcall(minetest.settings.set, minetest.settings, "mouse_sensitivity", tostring(base * (v / 100)))
	end
	if minetest.settings and minetest.settings.write then
		pcall(minetest.settings.write, minetest.settings)
	end
end

local function get_pixelation(pn)
	local v = storage:get_string(opt_key(pn, "pixelation"))
	if v == "" then return 0 end
	v = tonumber(v) or 0
	if v <= 0 then return 0 end
	if v > 8 then v = 8 end
	return v
end

local function set_pixelation(pn, v)
	v = tonumber(v) or 0
	if v <= 0 then
		storage:set_string(opt_key(pn, "pixelation"), "0")
		return
	end
	v = clamp(v, 2, 8)
	v = math.floor(v / 2 + 0.5) * 2
	storage:set_string(opt_key(pn, "pixelation"), tostring(v))
end

local function get_gui_scale(pn)
	local v = storage:get_string(opt_key(pn, "gui_scale"))
	if v == "" then return 1.0 end
	v = tonumber(v) or 1.0
	if v < 0.80 then v = 0.80 end
	if v > 1.60 then v = 1.60 end
	return v
end

local function set_gui_scale(pn, v)
	v = tonumber(v) or 1.0
	if v < 0.80 then v = 0.80 end
	if v > 1.60 then v = 1.60 end
	storage:set_string(opt_key(pn, "gui_scale"), string.format("%.2f", v))
	storage:set_string(GLOBAL_GUI_KEY, string.format("%.2f", v))
end

local function get_dithering(pn)
	local v = storage:get_string(opt_key(pn, "dithering"))
	if v == "" then return true end
	return v == "true"
end

local function set_dithering(pn, v)
	storage:set_string(opt_key(pn, "dithering"), v and "true" or "false")
end

local function get_ca(pn)
	local v = storage:get_string(opt_key(pn, "ca"))
	if v == "" then return true end
	return v == "true"
end

local function set_ca(pn, v)
	storage:set_string(opt_key(pn, "ca"), v and "true" or "false")
end

local function get_brightness(pn)
	local v = storage:get_string(opt_key(pn, "brightness"))
	if v == "" then return 50 end
	return clamp(tonumber(v), 0, 100)
end

local function set_brightness(pn, v)
	storage:set_string(opt_key(pn, "brightness"), tostring(clamp(v, 0, 100)))
end

local function apply_visual_settings(player)
	local pn = pname(player)
	local dith = get_dithering(pn)
	local ca   = get_ca(pn)
	local bri  = get_brightness(pn)
	local dither_val = dith and "12.0" or "999.0"
	local ca_val     = ca   and "0.006" or "0.0"
	local bri_norm   = (bri / 100) * 2.0 - 1.0
	bri_norm = math.max(-1.0, math.min(1.0, bri_norm))
	if minetest.settings and minetest.settings.set then
		pcall(minetest.settings.set, minetest.settings, "barnacle_dither_strength", dither_val)
		pcall(minetest.settings.set, minetest.settings, "barnacle_ca_strength", ca_val)
		pcall(minetest.settings.set, minetest.settings, "exposure_compensation", string.format("%.2f", bri_norm))
	end
	if minetest.settings and minetest.settings.write then
		pcall(minetest.settings.write, minetest.settings)
	end
end

local function play_sound_for(player, soundname, gain, params, ephemeral)
	local pn = pname(player)
	local vol = get_volume(pn) / 100
	gain = (tonumber(gain) or 1) * vol
	params = params or {}
	params.gain = gain
	params.to_player = pn
	if ephemeral == nil then ephemeral = true end
	return minetest.sound_play(soundname, params, ephemeral)
end

local function play_music_for(player, soundname, gain, params)
	local pn = pname(player)
	gain = (tonumber(gain) or 1) * (get_music_volume(pn) / 100)
	return play_sound_for(player, soundname, gain, params, false)
end

-- musik im menü
local MENU_MUSIC_NAME = "barnacle_menu_music"
local MENU_MUSIC_BASE_GAIN = 0.35

local function stop_menu_music(pn, fade)
	local h = menu_music[pn]
	if not h then return end

	local current = menu_music_gain[pn] or 0

	local function really_stop()
		pcall(minetest.sound_stop, h)
		menu_music[pn] = nil
		menu_music_gain[pn] = nil
	end

	if fade then
		if minetest.sound_fade then
			local step = -math.max(current, 0.001) / 1.0
			pcall(minetest.sound_fade, h, step, 0.0)
			minetest.after(1.05, really_stop)
			return
		end

		if minetest.sound_set_gain then
			local steps, dt = 10, 0.1
			for i = 1, steps do
				minetest.after(i * dt, function()
					if menu_music[pn] ~= h then return end
					local g = current * (1 - i / steps)
					pcall(minetest.sound_set_gain, h, g)
					menu_music_gain[pn] = g
					if i == steps then really_stop() end
				end)
			end
			return
		end
	end

	really_stop()
end

local function start_menu_music(player)
	local pn = pname(player)

	if menu_music[pn] then return end

	local target_gain = (get_volume(pn) / 100) * (get_music_volume(pn) / 100) * MENU_MUSIC_BASE_GAIN
	menu_music_gain[pn] = 0

	local h = play_music_for(player, MENU_MUSIC_NAME, 0.0, {loop = true})
	menu_music[pn] = h
	if not h then return end

	if minetest.sound_fade then
		local step = math.max(target_gain, 0.001) / 1.0
		pcall(minetest.sound_fade, h, step, target_gain)
		menu_music_gain[pn] = target_gain
	elseif minetest.sound_set_gain then
		local steps, dt = 10, 0.1
		for i = 1, steps do
			minetest.after(i * dt, function()
				if menu_music[pn] ~= h then return end
				local g = target_gain * (i / steps)
				pcall(minetest.sound_set_gain, h, g)
				menu_music_gain[pn] = g
			end)
		end
	else
		pcall(minetest.sound_stop, h)
		menu_music[pn] = minetest.sound_play(MENU_MUSIC_NAME, {
			to_player = pn,
			gain = target_gain,
			loop = true,
		}, false)
		menu_music_gain[pn] = target_gain
	end
end

-- save nur vom spieler
local function has_save()
	return storage:get_string(SAVE_KEY) ~= ""
end

local function write_save(t)
	storage:set_string(SAVE_KEY, minetest.serialize(t))
end

local function read_save()
	local s = storage:get_string(SAVE_KEY)
	if s == "" then return nil end
	local ok, t = pcall(minetest.deserialize, s)
	if not ok or type(t) ~= "table" then return nil end
	return t
end

local function clear_save()
	storage:set_string(SAVE_KEY, "")
end

local function make_save_from_player(player)
	return { pos = player:get_pos(), hp = player:get_hp() }
end

local function apply_save_to_player(player, t)
	if type(t) ~= "table" then return false end
	if t.pos then player:set_pos(t.pos) end
	if t.hp  then player:set_hp(t.hp) end
	return true
end

-- progress entity reset zeug
local function broken_key(id) return "broken:" .. id end
local function is_broken(id) return storage:get_int(broken_key(id)) == 1 end
local function set_broken(id, v) storage:set_int(broken_key(id), v and 1 or 0) end

local function clear_all_broken_flags()
	for _, e in ipairs(PROGRESS_SPAWNS) do
		set_broken(e.id, false)
	end
end

local function find_entity_by_spawn_id_near(id, pos, radius)
	for _, obj in ipairs(minetest.get_objects_inside_radius(pos, radius)) do
		local lua = obj:get_luaentity()
		if lua and lua._spawn_id == id then
			return obj
		end
	end
	return nil
end

local function remove_all_progress_entities()
	for _, e in ipairs(PROGRESS_SPAWNS) do
		local obj = find_entity_by_spawn_id_near(e.id, e.pos, FIND_RADIUS)
		if obj then obj:remove() end
	end
end

local function spawn_progress_entities_fresh()
	for _, e in ipairs(PROGRESS_SPAWNS) do
		if not is_broken(e.id) then
			local obj = find_entity_by_spawn_id_near(e.id, e.pos, FIND_RADIUS)
			if not obj then
				local o = minetest.add_entity(e.pos, e.name)
				if o then
					local lua = o:get_luaentity()
					if lua then lua._spawn_id = e.id end
					if e.yaw then o:set_yaw(e.yaw) end
				end
			end
		end
	end
end

local function mark_progress_broken(id)
	set_broken(id, true)
end

barnacle_progress = {
	play_sound_for = play_sound_for,
	mark_broken = mark_progress_broken,
	is_broken = is_broken,
}

local function restore_reset_nodes()
	for _, r in ipairs(RESET_NODES) do
		if r.pos and r.name and r.name ~= "" then
			minetest.set_node(r.pos, {name = r.name, param2 = r.param2 or 0})
		end
	end
end

-- hud overlay fürs menü
local function hud_remove_all(player)
	local pn = pname(player)
	local ids = hud_ids[pn]
	if not ids then return end
	for _, id in pairs(ids) do
		pcall(player.hud_remove, player, id)
	end
	hud_ids[pn] = nil
end

local function hud_show_menu_overlay(player)
	local pn = pname(player)
	hud_remove_all(player)

	local black_id = player:hud_add({
		hud_elem_type = "image",
		position  = {x = 0.5, y = 0.5},
		alignment = {x = 0,   y = 0},
		offset    = {x = 0,   y = 0},
		scale     = {x = -100, y = -100},
		text      = TEX_BLACK .. "^[opacity:255",
		z_index   = -300,
	})

	local frame_id = nil
	if TEX_FRAME and TEX_FRAME ~= "" then
		frame_id = player:hud_add({
			hud_elem_type = "image",
			position  = {x = 0.5, y = 0.5},
			alignment = {x = 0,   y = 0},
			offset    = {x = 0,   y = 0},
			scale     = {x = FRAME_SCALE, y = FRAME_SCALE},
			text      = TEX_FRAME,
			z_index   = -200,
		})
	end

	hud_ids[pn] = { black = black_id, frame = frame_id }
end

-- spieler einfrieren ohne komisches ruckeln
local function zero_player_motion(player)
	if not (player and player:is_player()) then return end
	pcall(function() player:set_velocity({x = 0, y = 0, z = 0}) end)
	pcall(function() player:set_acceleration({x = 0, y = 0, z = 0}) end)
end

local function set_controls_disabled(player, disabled)
	if not (player and player:is_player()) then return end
	local pn = pname(player)
	controls_disabled[pn] = disabled and true or nil

	if player.set_control_override then
		local allow = not disabled
		pcall(function()
			player:set_control_override({
				up = allow,
				down = allow,
				left = allow,
				right = allow,
				jump = allow,
				sneak = allow,
				aux1 = allow,
				LMB = allow,
				RMB = allow,
				zoom = allow,
				dig = allow,
				place = allow,
			})
		end)
	end
end

local function detach_player(player)
	if not (player and player:is_player()) then return end
	pcall(function() player:set_detach() end)
	zero_player_motion(player)
end

local function freeze_player(player, freeze)
	local pn = pname(player)

	if freeze then
		detach_player(player)
		set_controls_disabled(player, true)

		frozen_pos[pn] = player:get_pos()
		zero_player_motion(player)

		player:set_physics_override({
			speed = 0,
			jump = 0,
			gravity = 0,
			sneak = false,
			sneak_glitch = false,
		})
	else
		frozen_pos[pn] = nil

		player:set_physics_override({
			speed = 1,
			jump = 1,
			gravity = 1,
			sneak = true,
			sneak_glitch = true,
		})

		set_controls_disabled(player, false)
		detach_player(player)
	end
end

local function dist_sq(a, b)
	local dx = (a.x or 0) - (b.x or 0)
	local dy = (a.y or 0) - (b.y or 0)
	local dz = (a.z or 0) - (b.z or 0)
	return dx * dx + dy * dy + dz * dz
end

minetest.register_globalstep(function(dtime)
	frozen_tick = frozen_tick + (dtime or 0)

	for _, player in ipairs(minetest.get_connected_players()) do
		local pn = pname(player)

		if frozen_pos[pn] and (menu_open[pn] or pause_open[pn] or wake_open[pn] or waking[pn]) then
			zero_player_motion(player)

			if frozen_tick >= 0.10 then
				local cur = player:get_pos()
				if cur and frozen_pos[pn] then
					local d2 = dist_sq(cur, frozen_pos[pn])

					if d2 > 0.0009 and d2 < 9 then
						pcall(function()
							player:set_pos(frozen_pos[pn])
						end)
					elseif d2 >= 9 then
						frozen_pos[pn] = cur
						zero_player_motion(player)
					end
				end
			end
		end
	end

	if frozen_tick >= 0.10 then
		frozen_tick = 0
	end
end)

-- formspec vom main menu
local function fs_base()
	return table.concat({
		"formspec_version[6]",
		("size[%0.2f,%0.2f]"):format(UI_W, UI_H),
		"no_prepend[]",
		"bgcolor[#00000000;false]",
		"style_type[label;textcolor=#e9eef5]",
		"style_type[button;border=false;bgcolor=#00000000;bgimg=;fgimg=;textcolor=#e9eef5;content_offset=0]",
		"style_type[button:hovered;textcolor=#ffffff]",
		"style_type[button:pressed;textcolor=#cfcfcf]",
		"style_type[scrollbar;border=false;bgcolor=#00000000;arrows=hide]",
	})
end

local function fs_logo()
	local cx = UI_W / 2
	local logo_w = UI_W * 0.68
	local logo_h = logo_w / LOGO_ASPECT
	local x = cx - logo_w / 2
	local y = UI_H * 0.03
	return ("image[%0.2f,%0.2f;%0.2f,%0.2f;%s]"):format(x, y, logo_w, logo_h, TEX_LOGO)
end

local function fs_stack(buttons, y0)
	local cx = UI_W / 2
	local bw = UI_W * 0.22
	local bh = UI_H * 0.085
	local x  = cx - bw / 2
	local gap = bh * MENU_GAP_MULT

	local out = {}
	for i, b in ipairs(buttons) do
		out[#out + 1] = ("button[%0.2f,%0.2f;%0.2f,%0.2f;%s;%s]"):format(
			x, y0 + (i - 1) * gap, bw, bh, b.name, esc(b.label)
		)
	end
	return out
end

local function fs_main(player)
	local pn = pname(player)
	local parts = {fs_base(), fs_logo()}

	local msg = notice[pn] or ""
	if msg ~= "" then
		parts[#parts + 1] = ("label[%0.2f,%0.2f;%s]"):format(UI_W * 0.06, UI_H * 0.95, esc(msg))
	end

	local buttons = {
		{name = "btn_new",      label = "NEW GAME"},
		{name = "btn_continue", label = has_save() and "CONTINUE" or "CONTINUE (NO SAVE)"},
		{name = "btn_options",  label = "OPTIONS"},
		{name = "btn_exit",     label = "EXIT"},
	}

	for _, v in ipairs(fs_stack(buttons, UI_H * MENU_START_Y)) do
		parts[#parts + 1] = v
	end
	return table.concat(parts)
end

local function fs_confirm_new(player)
	local parts = {fs_base(), fs_logo()}
	local y_title = UI_H * 0.60

	local function centered_hyper(y, text)
		return ("hypertext[%0.2f,%0.2f;%0.2f,%0.2f;_;%s]"):format(
			0.0, y, UI_W, 0.8,
			esc("<style color=#e9eef5 font_size=20><center>" .. text .. "</center></style>")
		)
	end

	parts[#parts + 1] = centered_hyper(y_title, "START NEW GAME?")
	parts[#parts + 1] = centered_hyper(y_title + UI_H * 0.06, "THIS WILL RESET YOUR PROGRESS.")

	local cx = UI_W / 2
	local bw = UI_W * 0.22
	local bh = UI_H * 0.085
	local x  = cx - bw / 2
	local y0 = y_title + UI_H * 0.16
	local gap = bh * 1.15

	parts[#parts + 1] = ("button[%0.2f,%0.2f;%0.2f,%0.2f;btn_new_yes;%s]"):format(x, y0, bw, bh, esc("YES"))
	parts[#parts + 1] = ("button[%0.2f,%0.2f;%0.2f,%0.2f;btn_new_no;%s]"):format(x, y0 + gap, bw, bh, esc("NO"))

	return table.concat(parts)
end

local function fs_options(player)
	local pn = pname(player)
	local parts = {fs_base()}

	-- options hat eigenen frame
	parts[#parts + 1] = ("background[0,0;%0.2f,%0.2f;%s;false]"):format(UI_W, UI_H, esc(TEX_FRAME_OPTIONS))

	local vol       = get_volume(pn)
	local music_vol = get_music_volume(pn)
	local pix       = get_pixelation(pn)
	local gui       = get_gui_scale(pn)
	local mouse_val = get_mouse_sensitivity(pn)
	local dith_on   = get_dithering(pn)
	local ca_on     = get_ca(pn)
	local bri_val   = get_brightness(pn)

	local x0   = UI_W * 0.08
	local bw   = UI_W * 0.105
	local bh   = UI_H * 0.058
	local xgap = UI_W * 0.010

	local function sel_btn(name, label, x, y, w, h, active)
		if active then
			parts[#parts + 1] = ("style[%s;bgcolor=#55000088;textcolor=#ff6666]"):format(name)
			parts[#parts + 1] = ("button[%0.2f,%0.2f;%0.2f,%0.2f;%s;%s]"):format(x, y, w, h, name, esc(label))
			parts[#parts + 1] = ("style[%s;bgcolor=;textcolor=]"):format(name)
		else
			parts[#parts + 1] = ("button[%0.2f,%0.2f;%0.2f,%0.2f;%s;%s]"):format(x, y, w, h, name, esc(label))
		end
	end

	local presets = {0, 20, 40, 60, 80, 100}

	local y = UI_H * 0.010
	parts[#parts + 1] = ("label[%0.2f,%0.2f;%s]"):format(x0, y + UI_H * 0.020, esc("MASTER VOLUME: " .. vol .. "%"))
	local y_vol = y + UI_H * 0.045

	for i, p in ipairs(presets) do
		local x = x0 + (i - 1) * (bw + xgap)
		sel_btn("vol_" .. p, tostring(p) .. "%", x, y_vol, bw, bh, p == vol)
	end

	local y_music_label = y_vol + bh + UI_H * 0.022
	parts[#parts + 1] = ("label[%0.2f,%0.2f;%s]"):format(x0, y_music_label, esc("MUSIC VOLUME: " .. music_vol .. "%"))
	local y_music = y_music_label + UI_H * 0.045

	for i, p in ipairs(presets) do
		local x = x0 + (i - 1) * (bw + xgap)
		sel_btn("music_" .. p, tostring(p) .. "%", x, y_music, bw, bh, p == music_vol)
	end

	local after_vol_y = y_music + bh + UI_H * 0.030

	local pix_label = (pix == 0) and "OFF" or (tostring(pix) .. "x")
	parts[#parts + 1] = ("label[%0.2f,%0.2f;%s]"):format(x0, after_vol_y, esc("PIXELATION: " .. pix_label))
	local pix_vals = {0, 2, 4, 6, 8}
	local bw2 = UI_W * 0.085
	local y_pix = after_vol_y + UI_H * 0.045
	for i, v in ipairs(pix_vals) do
		local x = x0 + (i - 1) * (bw2 + xgap)
		local name = "pix_" .. v
		local label = (v == 0) and "OFF" or tostring(v)
		sel_btn(name, label, x, y_pix, bw2, bh, v == pix)
	end
	parts[#parts + 1] = ("label[%0.2f,%0.2f;%s]"):format(x0, y_pix + bh + UI_H * 0.006, esc("(requires restart)"))

	local after_pix_y = y_pix + bh + UI_H * 0.045
	local gui_label = string.format("GUI SCALE: %d%%", math.floor(gui * 100 + 0.5))
	parts[#parts + 1] = ("label[%0.2f,%0.2f;%s]"):format(x0, after_pix_y, esc(gui_label))
	local gui_vals = {0.80, 1.00, 1.20, 1.40, 1.60}
	local bw3 = UI_W * 0.10
	local y_gui = after_pix_y + UI_H * 0.045
	for i, v in ipairs(gui_vals) do
		local x = x0 + (i - 1) * (bw3 + xgap)
		local name = ("gui_%d"):format(math.floor(v * 100 + 0.5))
		local label = ("%d%%"):format(math.floor(v * 100 + 0.5))
		sel_btn(name, label, x, y_gui, bw3, bh, math.abs(v - gui) < 0.001)
	end
	parts[#parts + 1] = ("label[%0.2f,%0.2f;%s]"):format(x0, y_gui + bh + UI_H * 0.006, esc("(requires restart)"))

	local after_gui_y = y_gui + bh + UI_H * 0.045
	parts[#parts + 1] = ("label[%0.2f,%0.2f;%s]"):format(x0, after_gui_y, esc("MOUSE SENSITIVITY: " .. mouse_val .. "%"))
	local mouse_vals = {50, 75, 100, 125, 150}
	local bw_mouse = UI_W * 0.10
	local y_mouse = after_gui_y + UI_H * 0.045
	for i, v in ipairs(mouse_vals) do
		local x = x0 + (i - 1) * (bw_mouse + xgap)
		sel_btn("mouse_" .. v, tostring(v) .. "%", x, y_mouse, bw_mouse, bh, v == mouse_val)
	end

	local y_vis = y_mouse + bh + UI_H * 0.045
	local lbl_w = UI_W * 0.15
	local btn_w = UI_W * 0.09
	local col_gap = UI_W * 0.10

	parts[#parts + 1] = ("label[%0.2f,%0.2f;%s]"):format(x0, y_vis + UI_H * 0.010, esc("DITHERING"))
	sel_btn("dith_on",  "ON",  x0 + lbl_w,                y_vis, btn_w, bh, dith_on)
	sel_btn("dith_off", "OFF", x0 + lbl_w + btn_w + xgap, y_vis, btn_w, bh, not dith_on)

	local ca_x = x0 + lbl_w + btn_w * 2 + xgap + col_gap
	parts[#parts + 1] = ("label[%0.2f,%0.2f;%s]"):format(ca_x, y_vis + UI_H * 0.010, esc("COLOR ABERR."))
	sel_btn("ca_on",  "ON",  ca_x + lbl_w,                y_vis, btn_w, bh, ca_on)
	sel_btn("ca_off", "OFF", ca_x + lbl_w + btn_w + xgap, y_vis, btn_w, bh, not ca_on)

	local y_bri = y_vis + bh + UI_H * 0.026
	parts[#parts + 1] = ("label[%0.2f,%0.2f;%s]"):format(x0, y_bri + UI_H * 0.010, esc("BRIGHTNESS"))
	local bri_presets = {0, 25, 50, 75, 100}
	local bw_bri = UI_W * 0.10
	for i, v in ipairs(bri_presets) do
		local x = x0 + lbl_w + (i - 1) * (bw_bri + xgap)
		sel_btn("bri_" .. v, tostring(v) .. "%", x, y_bri, bw_bri, bh, v == bri_val)
	end

	local yb = UI_H * 0.92
	parts[#parts + 1] = ("button[%0.2f,%0.2f;%0.2f,%0.2f;btn_apply_gui;%s]"):format(UI_W * 0.10, yb, UI_W * 0.38, UI_H * 0.075, esc("APPLY & RESTART"))
	parts[#parts + 1] = ("label[%0.2f,%0.2f;%s]"):format(UI_W * 0.505, yb + UI_H * 0.015, esc("|"))
	parts[#parts + 1] = ("button[%0.2f,%0.2f;%0.2f,%0.2f;btn_opt_back;%s]"):format(UI_W * 0.54, yb, UI_W * 0.20, UI_H * 0.075, esc("BACK"))

	return table.concat(parts)
end

local function current_formspec(player)
	local pn = pname(player)
	local st = menu_state[pn] or "main"
	if st == "confirm_new" then return fs_confirm_new(player) end
	if st == "options" then return fs_options(player) end
	return fs_main(player)
end

-- menü auf und zu
local function force_close_menu_formspec(pn)
	if minetest.close_formspec then
		pcall(minetest.close_formspec, pn, "barnacle:mainmenu")
	end
	pcall(minetest.show_formspec, pn, "", "")
end

local function show_menu(player)
	local pn = pname(player)
	if waking[pn] then return end
	if not menu_open[pn] and player:get_pos() then
		local pos = player:get_pos()
		local dx = math.abs((pos.x or 0) - START_POS.x)
		local dy = math.abs((pos.y or 0) - START_POS.y)
		local dz = math.abs((pos.z or 0) - START_POS.z)
		if not (dx < 2 and dy < 2 and dz < 2) then
			write_save(make_save_from_player(player))
		end
	end
	menu_open[pn] = true
	menu_state[pn] = menu_state[pn] or "main"

	hud_show_menu_overlay(player)
	freeze_player(player, true)
	start_menu_music(player)

	if minetest.global_exists("barnacle_musicmanager")
		and barnacle_musicmanager.on_menu_open then
		barnacle_musicmanager.on_menu_open(player)
	end

	minetest.show_formspec(pn, "barnacle:mainmenu", current_formspec(player))
end

barnacle_frontend = barnacle_frontend or {}

function barnacle_frontend.is_menu_blocking(player_or_name)
	local pn = type(player_or_name) == "string" and player_or_name or pname(player_or_name)
	if pn == "" then return false end
	return menu_open[pn] or pause_open[pn] or wake_open[pn] or waking[pn] or false
end

local function hide_menu(player)
	local pn = pname(player)
	menu_open[pn] = false
	menu_state[pn] = "main"
	notice[pn] = ""

	force_close_menu_formspec(pn)
	stop_menu_music(pn, true)

	if minetest.global_exists("barnacle_musicmanager")
		and barnacle_musicmanager.on_menu_close then
		barnacle_musicmanager.on_menu_close(player)
	end

	hud_remove_all(player)
	freeze_player(player, false)
end

-- eigenes pause menü
local function fs_pause_menu()
	return table.concat({
		"formspec_version[4]",
		"size[8,5.25]",
		"no_prepend[]",
		"bgcolor[#00000000;true]",
		"style_type[button;border=false;bgimg=;bgimg_middle=0]",
		"style_type[button_exit;border=false;bgimg=;bgimg_middle=0]",
		"background[0,0;8,5.25;" .. esc("barnacle_pause_panel.png") .. ";false]",
		"label[0.3,0.25;" .. esc("PAUSED") .. "]",
		"button[0.5,0.9;7,0.9;btn_pause_resume;" .. esc("Resume") .. "]",
		"button[0.5,1.95;7,0.9;btn_pause_wake;" .. esc("Wake Up") .. "]",
		"button[0.5,3.0;7,0.9;btn_pause_controls;" .. esc("Controls") .. "]",
		"button[0.5,4.05;7,0.9;btn_pause_main;" .. esc("Back to Main Menu") .. "]",
	})
end

local function fs_controls()
	return table.concat({
		"formspec_version[4]",
		"size[8,5.25]",
		"no_prepend[]",
		"bgcolor[#00000000;true]",
		"style_type[label;textcolor=#e9eef5]",
		"style_type[button;border=false;bgimg=;bgimg_middle=0;textcolor=#e9eef5]",
		"style_type[button_exit;border=false;bgimg=;bgimg_middle=0;textcolor=#e9eef5]",
		"background[0,0;8,5.25;" .. esc("barnacle_pause_panel.png") .. ";false]",

		"label[3.35,0.55;" .. esc("CONTROLS") .. "]",

		"label[1.20,1.20;" .. esc("W / A / S / D  - Move") .. "]",
		"label[1.20,1.60;" .. esc("Mouse  - Look") .. "]",
		"label[1.20,2.00;" .. esc("Space  - Jump") .. "]",
		"label[1.20,2.40;" .. esc("E  - Pause / Wake") .. "]",
		"label[1.20,2.80;" .. esc("Mouse Wheel  - Switch Items") .. "]",
		"label[1.20,3.20;" .. esc("Shift  - Crouch / Go Down Ladders") .. "]",
		"label[1.20,3.60;" .. esc("Right Click  - Use Items / Interact") .. "]",

		"button_exit[2.75,4.45;2.5,0.7;btn_ctrl_back;" .. esc("Back") .. "]",
	})
end

local function force_close_pause_formspec(pn, formname)
	if minetest.close_formspec then
		pcall(minetest.close_formspec, pn, formname or "barnacle:pause")
	end
	pcall(minetest.show_formspec, pn, "", "")
end

local function show_pause(player)
	local pn = pname(player)
	if waking[pn] then return end
	if menu_open[pn] then return end
	if pause_open[pn] then return end
	write_save(make_save_from_player(player))
	pause_open[pn] = true
	pause_mode[pn] = "pause"
	freeze_player(player, true)
	minetest.show_formspec(pn, "barnacle:pause", fs_pause_menu())
end

local function show_controls(player)
	local pn = pname(player)
	if waking[pn] then return end
	pause_open[pn] = true
	pause_mode[pn] = "controls"
	freeze_player(player, true)
	minetest.show_formspec(pn, "barnacle:controls", fs_controls())
end

local function resume_from_pause(player)
	local pn = pname(player)
	pause_open[pn] = false
	pause_mode[pn] = nil
	force_close_pause_formspec(pn, "barnacle:pause")
	force_close_pause_formspec(pn, "barnacle:controls")
	freeze_player(player, false)
end

local last_aux1 = {}
minetest.register_globalstep(function()
	for _, player in ipairs(minetest.get_connected_players()) do
		local pn = pname(player)
		local c = player:get_player_control()
		if waking[pn] then
			last_aux1[pn] = (c.aux1 and true) or false
		elseif menu_open[pn] or pause_open[pn] then
			last_aux1[pn] = (c.aux1 and true) or false
		else
			local now = (c.aux1 and true) or false
			local prev = last_aux1[pn] or false
			if now and not prev and not c.sneak then
				show_pause(player)
			end
			last_aux1[pn] = now
		end
	end
end)

-- schwarzer fade über hud
local fade_hud = {}

local function fade_set(player, alpha)
	local pn = pname(player)
	local id = fade_hud[pn]
	if not id then
		id = player:hud_add({
			hud_elem_type = "image",
			position  = {x = 0.5, y = 0.5},
			alignment = {x = 0, y = 0},
			offset    = {x = 0, y = 0},
			scale     = {x = -100, y = -100},
			text      = TEX_BLACK .. "^[opacity:0",
			z_index   = 999,
		})
		fade_hud[pn] = id
	end
	player:hud_change(id, "text", TEX_BLACK .. "^[opacity:" .. tostring(alpha))
end

local function fade_remove(player)
	local pn = pname(player)
	local id = fade_hud[pn]
	if id then
		pcall(player.hud_remove, player, id)
		fade_hud[pn] = nil
	end
end

local function fade_to_black(player, duration, on_done)
	duration = tonumber(duration) or 2.0
	local steps = 20
	local dt = duration / steps
	for i = 0, steps do
		minetest.after(i * dt, function()
			if not (player and player:is_player()) then return end
			local a = math.floor(255 * (i / steps))
			fade_set(player, a)
			if i == steps and on_done then
				on_done()
			end
		end)
	end
end

local function fade_from_black(player, duration, on_done)
	duration = tonumber(duration) or 2.0
	local steps = 20
	local dt = duration / steps
	for i = 0, steps do
		minetest.after(i * dt, function()
			if not (player and player:is_player()) then return end
			local a = math.floor(255 * (1 - i / steps))
			fade_set(player, a)
			if i == steps then
				fade_remove(player)
				if on_done then on_done() end
			end
		end)
	end
end

local notice_hud = {}

local function show_notice(player, msg, seconds)
	seconds = tonumber(seconds) or 3
	if not (player and player:is_player()) then return end
	local pn = player:get_player_name()

	local old = notice_hud[pn]
	if old then
		pcall(player.hud_remove, player, old)
		notice_hud[pn] = nil
	end

	local id = player:hud_add({
		hud_elem_type = "text",
		position      = {x = 0.02, y = 0.15},
		offset        = {x = 0, y = 0},
		text          = tostring(msg or ""),
		number        = 0xFFFFFF,
		alignment     = {x = 1, y = 1},
		scale         = {x = 100, y = 100},
		z_index       = 10000,
	})
	notice_hud[pn] = id

	minetest.after(seconds, function()
		local p = minetest.get_player_by_name(pn)
		if p and notice_hud[pn] then
			pcall(p.hud_remove, p, notice_hud[pn])
			notice_hud[pn] = nil
		end
	end)
end

-- wake up menü
local last_aux  = {}
local SPAWN_POS = {x = -1, y = 11, z = 0}
local WAKE_POS  = {x = -1, y = 11, z = 2}
local WAKE_RADIUS = 20

local function can_wake(player)
	local p = player:get_pos()
	local dx = p.x - SPAWN_POS.x
	local dy = p.y - SPAWN_POS.y
	local dz = p.z - SPAWN_POS.z
	return (dx * dx + dy * dy + dz * dz) > (WAKE_RADIUS * WAKE_RADIUS)
end

local function fs_wake()
	return table.concat({
		"formspec_version[4]",
		"size[8,3.2]",
		"no_prepend[]",
		"style_type[button;border=false;bgimg=;bgimg_middle=0]",
		"style_type[button_exit;border=false;bgimg=;bgimg_middle=0]",
		"bgcolor[#000000CC;true]",
		"background[0,0;8,3.2;" .. esc("barnacle_pause_panel.png") .. ";false]",
		"label[3.05,0.45;" .. esc("WAKE UP?") .. "]",
		"button[0.8,1.35;6.4,0.9;btn_wake_yes;" .. esc("YES") .. "]",
		"button[0.8,2.25;6.4,0.9;btn_wake_no;" .. esc("NO") .. "]",
	})
end

local function open_wake_menu(player)
	local pn = pname(player)
	if waking[pn] then return end
	if menu_open[pn] or pause_open[pn] or wake_open[pn] then return end
	wake_open[pn] = true
	freeze_player(player, true)
	minetest.show_formspec(pn, "barnacle:wake", fs_wake())
end

local function close_wake_menu(player)
	local pn = pname(player)
	wake_open[pn] = nil
	if minetest.close_formspec then
		pcall(minetest.close_formspec, pn, "barnacle:wake")
	end
	pcall(minetest.show_formspec, pn, "", "")
	freeze_player(player, false)
end

local function do_wake(player, on_done)
	local pn = pname(player)
	waking[pn] = true

	frozen_pos[pn] = nil
	set_controls_disabled(player, false)
	player:set_physics_override({
		speed = 1,
		jump = 1,
		gravity = 1,
		sneak = true,
		sneak_glitch = true,
	})
	detach_player(player)

	fade_to_black(player, 2.0, function()
		if not (player and player:is_player()) then
			waking[pn] = nil
			return
		end

		detach_player(player)
		player:set_pos(WAKE_POS)
		zero_player_motion(player)

		set_time_24000(19000)

		fade_from_black(player, 2.0, function()
			waking[pn] = nil
			frozen_pos[pn] = nil
			set_controls_disabled(player, false)
			if on_done then on_done() end
		end)
	end)
end

-- spieler richtig zurücksetzen
local function reset_player_state(player)
	detach_player(player)
	player:set_hp(START_HP)
	player:set_pos(START_POS)

	local inv = player:get_inventory()
	if inv then
		if inv:get_list("main") then inv:set_list("main", {}) end
		if inv:get_list("craft") then inv:set_list("craft", {}) end
		if inv:get_list("craftpreview") then inv:set_list("craftpreview", {}) end
	end

	local meta = player:get_meta()
	if meta then
		meta:from_table({fields = {}, inventory = nil})
	end
end

-- new game und continue
local function start_new_game(player)
	fade_to_black(player, 0.2, function()
		clear_save()

		local pn = player:get_player_name()

		if minetest.global_exists("barnacle_voice_ai") and barnacle_voice_ai.reset_player then
			barnacle_voice_ai.reset_player(pn)
		end

		if minetest.global_exists("barnacle_voice_ai") and barnacle_voice_ai.reset_finale then
			barnacle_voice_ai.reset_finale()
		end

		local wp = minetest.get_worldpath()

		local ok1 = minetest.safe_file_write(wp .. "/lia_reset.flag", "1")
		local ok2 = minetest.safe_file_write(wp .. "/barnacle_new_game.flag", "1")
		local ok3 = minetest.safe_file_write(wp .. "/barnacle_blocks_new_game.flag", "1")
		local ok4 = minetest.safe_file_write(wp .. "/barnacle_notes_new_game.flag", "1")

		minetest.log("action", "[frontend] New Game worldpath = " .. wp)
		minetest.log("action", "[frontend] wrote lia_reset.flag = " .. tostring(ok1))
		minetest.log("action", "[frontend] wrote barnacle_new_game.flag = " .. tostring(ok2))
		minetest.log("action", "[frontend] wrote barnacle_blocks_new_game.flag = " .. tostring(ok3))
		minetest.log("action", "[frontend] wrote barnacle_notes_new_game.flag = " .. tostring(ok4))

		if minetest.global_exists("barnacle_items") and barnacle_items.reset_new_game then
			barnacle_items.reset_new_game()
		end

		if minetest.global_exists("barnacle_blocks") and barnacle_blocks.reset_new_game then
			barnacle_blocks.reset_new_game()
		end

		remove_all_progress_entities()
		clear_all_broken_flags()
		spawn_progress_entities_fresh()

		restore_reset_nodes()
		reset_player_state(player)

		set_time_24000(0)

		write_save(make_save_from_player(player))
		hide_menu(player)

		fade_from_black(player, 3.0)
	end)
end

local function continue_game(player)
	local pn = pname(player)
	local t = read_save()
	if not t then
		notice[pn] = "NO SAVE FOUND"
		show_menu(player)
		return
	end

	spawn_progress_entities_fresh()

	detach_player(player)
	apply_save_to_player(player, t)
	hide_menu(player)
end

-- callbacks und button zeug
minetest.register_on_joinplayer(function(player)
	minetest.after(2.0, function()
		if player and player:is_player() then
			apply_visual_settings(player)
		end
	end)

	menu_state[pname(player)] = "main"
	local pn = pname(player)

	if minetest.settings and minetest.settings.set then
		pcall(minetest.settings.set, minetest.settings, "sound_volume", tostring(get_volume(pn) / 100))
		local pix = get_pixelation(pn)
		local engine_val = (pix <= 0) and 1 or clamp(pix, 1, 8)
		pcall(minetest.settings.set, minetest.settings, "undersampling", tostring(engine_val))
		if minetest.settings.write then
			pcall(minetest.settings.write, minetest.settings)
		end
	end

	set_mouse_sensitivity(pn, get_mouse_sensitivity(pn))
	set_music_volume(pn, get_music_volume(pn))

	spawn_progress_entities_fresh()
	show_menu(player)
end)

minetest.register_on_leaveplayer(function(player)
	local pn = pname(player)
	hud_ids[pn] = nil
	menu_open[pn] = nil
	menu_state[pn] = nil
	notice[pn] = nil
	pause_open[pn] = nil
	pause_mode[pn] = nil
	last_aux1[pn] = nil
	last_aux[pn] = nil
	wake_open[pn] = nil
	waking[pn] = nil
	frozen_pos[pn] = nil
	controls_disabled[pn] = nil
	stop_menu_music(pn, true)
	menu_music[pn] = nil
end)

minetest.register_on_player_receive_fields(function(player, formname, fields)
	local pn = pname(player)

	if waking[pn] then
		return true
	end

	if formname == "barnacle:wake" then
		if fields.quit or fields.btn_wake_no then
			if pause_open[pn] then
				minetest.show_formspec(pn, "barnacle:pause", fs_pause_menu())
			else
				close_wake_menu(player)
			end
			return true
		end

		if fields.btn_wake_yes then
			if finale_locked() then
				show_notice(player, "You cannot wake up now.", 3)
				if pause_open[pn] then
					minetest.after(0, function()
						if player and player:is_player() then
							minetest.show_formspec(pn, "barnacle:pause", fs_pause_menu())
						end
					end)
				end
				return true
			end

			if minetest.close_formspec then
				pcall(minetest.close_formspec, pn, "barnacle:wake")
			end
			pcall(minetest.show_formspec, pn, "", "")

			wake_open[pn] = nil

			if pause_open[pn] then
				pause_open[pn] = false
				pause_mode[pn] = nil
				force_close_pause_formspec(pn, "barnacle:pause")
				force_close_pause_formspec(pn, "barnacle:controls")
			end

			do_wake(player)
			return true
		end

		return true
	end

	if formname == "barnacle:pause" then
		if fields.quit or fields.btn_pause_resume then
			resume_from_pause(player)
			return true
		end
		if fields.btn_pause_controls then
			show_controls(player)
			return true
		end
		if fields.btn_pause_wake then
			if can_wake(player) then
				wake_open[pn] = true
				minetest.show_formspec(pn, "barnacle:wake", fs_wake())
			else
				show_notice(player, "You are not sleeping.", 3)
				minetest.after(0, function()
					if player and player:is_player() then
						minetest.show_formspec(pn, "barnacle:pause", fs_pause_menu())
					end
				end)
			end
			return true
		end
		if fields.btn_pause_main then
			if finale_locked() then
				show_notice(player, "You cannot leave now.", 3)
				minetest.after(0, function()
					if player and player:is_player() then
						minetest.show_formspec(pn, "barnacle:pause", fs_pause_menu())
					end
				end)
				return true
			end

			resume_from_pause(player)
			show_menu(player)
			return true
		end
		return true
	end

	if formname == "barnacle:controls" then
		if fields.quit or fields.btn_ctrl_back then
			resume_from_pause(player)
			return true
		end
		return true
	end

	if formname ~= "barnacle:mainmenu" then
		return false
	end

	local function any_button_pressed(f)
		for k, v in pairs(f) do
			if k ~= "quit" and k ~= "vol_bar" and k ~= "key_enter" and k ~= "key_up" and k ~= "key_down" then
				if type(v) == "string" then
					if v ~= "" then return true end
				elseif v == true then
					return true
				end
			end
		end
		return false
	end

	if any_button_pressed(fields) then
		play_sound_for(player, "barnacle_click", 1.0, {}, true)
	end

	if fields.quit and menu_open[pn] then
		hide_menu(player)
		return true
	end

	if fields.btn_new then
		menu_state[pn] = "confirm_new"
		show_menu(player)
		return true
	end

	if fields.btn_continue then
		if has_save() then
			continue_game(player)
		else
			notice[pn] = "NO SAVE FOUND"
			show_menu(player)
		end
		return true
	end

	if fields.btn_options then
		menu_state[pn] = "options"
		show_menu(player)
		return true
	end

	if fields.btn_exit then
		pcall(minetest.disconnect_player, pn, "Quit")
		return true
	end

	if fields.btn_new_yes then
		if finale_locked() then
			notice[pn] = "YOU CANNOT RESET NOW"
			menu_state[pn] = "main"
			show_menu(player)
			return true
		end

		menu_state[pn] = "main"
		start_new_game(player)
		return true
	end

	if fields.btn_new_no then
		menu_state[pn] = "main"
		show_menu(player)
		return true
	end

	for _, p in ipairs({0, 20, 40, 60, 80, 100}) do
		local key = "vol_" .. p
		if fields[key] then
			set_volume(pn, p)

			if minetest.settings and minetest.settings.set then
				pcall(minetest.settings.set, minetest.settings, "sound_volume", tostring(p / 100))
			end
			if minetest.settings and minetest.settings.write then
				pcall(minetest.settings.write, minetest.settings)
			end

			stop_menu_music(pn, true)
			minetest.after(1.05, function()
				if player and player:is_player() and menu_open[pn] then
					start_menu_music(player)
					show_menu(player)
				end
			end)
			return true
		end
	end

	for _, p in ipairs({0, 20, 40, 60, 80, 100}) do
		local key = "music_" .. p
		if fields[key] then
			set_music_volume(pn, p)

			stop_menu_music(pn, true)
			minetest.after(1.05, function()
				if player and player:is_player() and menu_open[pn] then
					start_menu_music(player)
					show_menu(player)
				end
			end)
			return true
		end
	end

	for _, v in ipairs({0, 2, 4, 6, 8}) do
		local key = "pix_" .. v
		if fields[key] then
			set_pixelation(pn, v)
			local engine_val = (v <= 0) and 1 or clamp(v, 1, 8)
			if minetest.settings and minetest.settings.set then
				pcall(minetest.settings.set, minetest.settings, "undersampling", tostring(engine_val))
			end
			if minetest.settings and minetest.settings.write then
				pcall(minetest.settings.write, minetest.settings)
			end
			show_menu(player)
			return true
		end
	end

	for _, v in ipairs({0.80, 1.00, 1.20, 1.40, 1.60}) do
		local key = ("gui_%d"):format(math.floor(v * 100 + 0.5))
		if fields[key] then
			set_gui_scale(pn, v)
			notice[pn] = "GUI SCALE SAVED (RESTART TO APPLY)"
			if minetest.settings and minetest.settings.write then
				pcall(minetest.settings.write, minetest.settings)
			end
			show_menu(player)
			return true
		end
	end

	for _, v in ipairs({50, 75, 100, 125, 150}) do
		local key = "mouse_" .. v
		if fields[key] then
			set_mouse_sensitivity(pn, v)
			show_menu(player)
			return true
		end
	end

	if fields.btn_apply_gui then
		local scale = get_gui_scale(pn)
		if minetest.settings and minetest.settings.set then
			pcall(minetest.settings.set, minetest.settings, "gui_scaling", string.format("%.2f", scale))
		end
		if minetest.settings and minetest.settings.write then
			pcall(minetest.settings.write, minetest.settings)
		end
		minetest.request_shutdown("Applying GUI scale…", true, 0)
		return true
	end

	if fields.dith_on then
		set_dithering(pn, true)
		apply_visual_settings(player)
		show_menu(player)
		return true
	end
	if fields.dith_off then
		set_dithering(pn, false)
		apply_visual_settings(player)
		show_menu(player)
		return true
	end

	if fields.ca_on then
		set_ca(pn, true)
		apply_visual_settings(player)
		show_menu(player)
		return true
	end
	if fields.ca_off then
		set_ca(pn, false)
		apply_visual_settings(player)
		show_menu(player)
		return true
	end

	for _, v in ipairs({0, 25, 50, 75, 100}) do
		local key = "bri_" .. v
		if fields[key] then
			set_brightness(pn, v)
			apply_visual_settings(player)
			show_menu(player)
			return true
		end
	end

	if fields.btn_opt_back then
		menu_state[pn] = "main"
		show_menu(player)
		return true
	end

	return true
end)

minetest.register_globalstep(function()
	for _, player in ipairs(minetest.get_connected_players()) do
		local pn = pname(player)
		local ctrl = player:get_player_control() or {}
		local aux = ctrl.aux1 and true or false
		local prev = last_aux[pn] and true or false

		if waking[pn] then
			last_aux[pn] = aux
		else
			if aux and not prev and not ctrl.sneak then
				if menu_open[pn] or pause_open[pn] then
				else
					if not can_wake(player) then
						show_notice(player, "You are not sleeping.", 3)
					else
						open_wake_menu(player)
					end
				end
			end

			last_aux[pn] = aux
		end
	end
end)

local timer = 0
minetest.register_globalstep(function(dtime)
	timer = timer + dtime
	if timer < 20 then return end
	timer = 0

	for _, player in ipairs(minetest.get_connected_players()) do
		local pn = pname(player)
		if not menu_open[pn] and not pause_open[pn] and not wake_open[pn] and not waking[pn] then
			local pos = player:get_pos()
			local dx = math.abs((pos.x or 0) - START_POS.x)
			local dy = math.abs((pos.y or 0) - START_POS.y)
			local dz = math.abs((pos.z or 0) - START_POS.z)
			if not (dx < 2 and dy < 2 and dz < 2) then
				write_save(make_save_from_player(player))
			end
		end
	end
end)

minetest.register_chatcommand("wake", {
	description = "Open Wake Up menu (same as Aux1/F)",
	privs = {},
	func = function(name)
		local player = minetest.get_player_by_name(name)
		if player then
			local pn = pname(player)
			if not waking[pn] then
				open_wake_menu(player)
			end
		end
		return true, ""
	end
})

local notice_hud2 = {}
local function show_notice_bottom(player, msg, seconds)
	seconds = tonumber(seconds) or 3
	if not (player and player:is_player()) then return end
	local pn = pname(player)
	if notice_hud2[pn] then
		player:hud_remove(notice_hud2[pn])
		notice_hud2[pn] = nil
	end
	local id = player:hud_add({
		hud_elem_type = "text",
		position  = {x = 0.5, y = 0.92},
		offset    = {x = 0, y = 0},
		alignment = {x = 0, y = 0},
		text      = msg,
		number    = 0xFFFFFF,
		scale     = {x = 200, y = 40},
		z_index   = 1001,
	})
	notice_hud2[pn] = id
	minetest.after(seconds, function()
		local p2 = minetest.get_player_by_name(pn)
		if p2 and notice_hud2[pn] then
			p2:hud_remove(notice_hud2[pn])
			notice_hud2[pn] = nil
		end
	end)
end

dofile(minetest.get_modpath("barnacle_frontend") .. "/disable_selectionbox.lua")
