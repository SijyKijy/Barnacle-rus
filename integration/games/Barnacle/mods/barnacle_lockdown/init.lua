local storage = minetest.get_mod_storage()

-- keybinds die wir killen wollen
local KEYMAPS_TO_DISABLE = {
	"keymap_dig",         -- linksklick aus
	"keymap_inventory",   -- I
	"keymap_drop",        -- Q
	"keymap_freemove",    -- fly
	"keymap_fastmove",    -- fast
	"keymap_noclip",      -- noclip
	"keymap_zoom",
	"keymap_camera_mode",
	"keymap_minimap",
	"keymap_mute",

	-- f tasten auch weg
	"keymap_f1",
	"keymap_f2",
	"keymap_f3",
	"keymap_f4",
	"keymap_f5",
	"keymap_f6",
	"keymap_f7",
	"keymap_f8",
	"keymap_f9",
	"keymap_f10",
	"keymap_f11",
	"keymap_f12",
}

-- visuelle sachen aus
local SETTINGS_TO_DISABLE_BOOL = {
	"enable_crosshair",
	"enable_node_highlighting",
	"enable_entity_highlighting",
	"enable_object_highlighting",
}

-- check creative
local function is_creative_enabled()
	return minetest.settings:get_bool("creative_mode", false)
		or minetest.settings:get_bool("creative", false)
end

-- lockdown nur wenn nicht creative
local function lockdown_active()
	return not is_creative_enabled()
end

-- shortcuts
local function sget(k)
	return minetest.settings:get(k)
end

local function sset(k, v)
	minetest.settings:set(k, v)
end

local function ssetb(k, v)
	minetest.settings:set_bool(k, v)
end

-- bisschen text sauber machen
local function trim(s)
	return (s or ""):match("^%s*(.-)%s*$")
end

local function collapse_spaces(s)
	return (s or ""):gsub("%s+", " ")
end

local function normalize_command(message)
	return trim(collapse_spaces(message or ""))
end

-- settings sichern einmal
local function backup_settings_once()
	if storage:get_string("lockdown_saved") == "1" then
		return
	end

	for _, k in ipairs(KEYMAPS_TO_DISABLE) do
		storage:set_string("bak_" .. k, sget(k) or "")
	end

	for _, k in ipairs(SETTINGS_TO_DISABLE_BOOL) do
		storage:set_string("bak_" .. k, sget(k) or "")
	end

	storage:set_string("bak_node_highlighting", sget("node_highlighting") or "")
	storage:set_string("bak_entity_highlighting", sget("entity_highlighting") or "")
	storage:set_string("bak_object_highlighting", sget("object_highlighting") or "")

	storage:set_string("lockdown_saved", "1")
end

-- alles aus machen
local function apply_client_lockdown()
	backup_settings_once()

	for _, k in ipairs(KEYMAPS_TO_DISABLE) do
		sset(k, "")
	end

	for _, k in ipairs(SETTINGS_TO_DISABLE_BOOL) do
		ssetb(k, false)
	end

	sset("node_highlighting", "0")
	sset("entity_highlighting", "0")
	sset("object_highlighting", "0")
end

-- wieder zurück
local function restore_client_settings()
	if storage:get_string("lockdown_saved") ~= "1" then
		return
	end

	for _, k in ipairs(KEYMAPS_TO_DISABLE) do
		local v = storage:get_string("bak_" .. k)

		if k == "keymap_dig" and (v == nil or v == "") then
			v = "KEY_LBUTTON"
		end

		sset(k, v)
	end

	for _, k in ipairs(SETTINGS_TO_DISABLE_BOOL) do
		local v = storage:get_string("bak_" .. k)
		if v ~= "" then
			local lower = string.lower(v)
			ssetb(k, (lower == "true" or lower == "1"))
		end
	end

	local nh = storage:get_string("bak_node_highlighting")
	if nh ~= "" then
		sset("node_highlighting", nh)
	end

	local eh = storage:get_string("bak_entity_highlighting")
	if eh ~= "" then
		sset("entity_highlighting", eh)
	end

	local oh = storage:get_string("bak_object_highlighting")
	if oh ~= "" then
		sset("object_highlighting", oh)
	end
end

-- alle privs holen
local function all_privs_table()
	local t = {}
	for privname, _ in pairs(minetest.registered_privileges) do
		t[privname] = true
	end
	return t
end

-- je nach mode privs setzen
local function set_privs_for_player(player)
	if not (player and player:is_player()) then
		return
	end

	local name = player:get_player_name()

	if is_creative_enabled() then
		minetest.set_player_privs(name, all_privs_table())
	else
		minetest.set_player_privs(name, { shout = true })
	end
end

-- läuft regelmäßig durch
local priv_timer = 0
minetest.register_globalstep(function(dtime)
	priv_timer = priv_timer + dtime
	if priv_timer < 1.0 then
		return
	end
	priv_timer = 0

	for _, player in ipairs(minetest.get_connected_players()) do
		set_privs_for_player(player)
	end
end)

-- block platzieren verhindern
minetest.register_on_placenode(function(pos, newnode, placer, oldnode, itemstack, pointed_thing)
	if not lockdown_active() then return end
	if not (placer and placer:is_player()) then return end

	minetest.set_node(pos, oldnode)
	return true
end)

-- survival check
local function is_survival_player(name)
	if is_creative_enabled() then
		return false
	end

	local player = minetest.get_player_by_name(name)
	return player and player:is_player()
end

-- nur diese commands erlauben
local function is_allowed_survival_command(message)
	local msg = normalize_command(message)

	if msg == "/openhub" then
		return true
	end

	if msg == "/opennight" then
		return true
	end

	return false
end

-- command runner
local function run_survival_whitelist_command(name, message)
	local msg = normalize_command(message)

	if msg == "/openhub" then
		local def = minetest.registered_chatcommands["openhub"]
		if not def or type(def.func) ~= "function" then
			return false, "Command /openhub is not available."
		end

		local ok, success, reply = pcall(def.func, name, "")
		if not ok then
			return false, "Command failed."
		end

		return success == true, reply or ""
	end

	if msg == "/opennight" then
		local def = minetest.registered_chatcommands["opennight"]
		if not def or type(def.func) ~= "function" then
			return false, "Command /opennight is not available."
		end

		local ok, success, reply = pcall(def.func, name, "")
		if not ok then
			return false, "Command failed."
		end

		return success == true, reply or ""
	end

	return false, "This command is disabled."
end

-- chat hook
minetest.register_on_chat_message(function(name, message)
	if type(message) ~= "string" then
		return false
	end

	if message:sub(1, 1) ~= "/" then
		return false
	end

	if message:match("^/language%s*$") then return false end

	if not is_survival_player(name) then
		return false
	end

	if not is_allowed_survival_command(message) then
		minetest.chat_send_player(name, "This command is disabled.")
		return true
	end

	local success, reply = run_survival_whitelist_command(name, message)

	if reply and reply ~= "" then
		minetest.chat_send_player(name, reply)
	end

	return true
end)

-- mode anwenden
local function apply_mode_now()
	if is_creative_enabled() then
		restore_client_settings()
	else
		apply_client_lockdown()
	end
end

minetest.register_on_joinplayer(function(player)
	minetest.after(0, function()
		set_privs_for_player(player)
		apply_mode_now()
	end)
end)

minetest.register_on_mods_loaded(function()
	apply_mode_now()
end)