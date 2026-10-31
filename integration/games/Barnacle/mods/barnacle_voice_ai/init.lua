-- barnacle trigger macht sie nervös passt so
-- lia fake ai ding

-- chat reihenfolge fix (erst player dann erstmal so lassen
-- matching bisschen besser gemacht (ganze wörter usw) sollte reichen

-- waiting mode kram kp
-- erstes weird ding nach ~15-20 min erstmal so lassen
-- danach immer wieder alle 15-20 bis passt so

-- nach erster nachricht: später vllt besser
-- phase zeug läuft im hintergrund nicht anfassen
-- phase zeug läuft im hintergrund sollte reichen
-- zwischendurch idle lines so alle 30-45 kp

-- name flow hier nicht anfassen
-- lia fragt nach name passt so
-- nächste msg wird name (oder "nah/nein" erstmal so lassen
-- reset kram über flag passt so

-- commands werden hier geblockt sollte reichen
-- escalation wird mit der zeit schlimmer

-- reset kram über flag

-- bisschen smalltalk auch drin sollte reichen

-- phase zeug läuft im hintergrund passt so
-- paar anomalies + red lines kp
-- followup fragen über pending_q nicht anfassen

-- timer laufen nur wenn spiel offen ist
-- nix mehr im hintergrund kp

-- zeit frage gibt echte pc zeit zurück später vllt besser
-- where frage je nach ort anders kp
-- nah spawn = "in your home. kp
-- sonst = "in a dream" passt so

-- merkt sich wie lange du weg später vllt besser

-- "what is your name" sagt einfach
-- name flow hier erstmal so lassen

-- commands werden hier geblockt später vllt besser

-- manchmal kaputte texte (absicht -> ai sollte reichen

-- barnacle trigger macht sie nervös kp

-- phase zeug läuft im hintergrund passt so

-- extra trigger kram hier später vllt besser
-- tips / staying / exploring / sollte reichen

-- absence texte je nach dauer sollte reichen
-- je nach dauer + random nicht anfassen
-- keine genauen zeiten mehr nicht anfassen

-- einzelne "where" / "what" gehen jetzt

-- why spam wird erkannt später vllt besser

-- commands werden hier geblockt erstmal so lassen
-- /openhub später vllt besser
-- /time 0268 nicht anfassen


-- finale kram hier passt so

-- entry exit zones sollte reichen
-- normale ai pausiert da drin nicht anfassen
-- extra trigger kram hier erstmal so lassen

-- chat ist da drin kaputt (one nicht anfassen

-- warnungen im pfad sollte reichen

-- final monolog von lia erstmal so lassen

-- end button spawn später vllt besser

-- blackout + sound + tp erstmal so lassen

-- end flags bleiben auch nach new erstmal so lassen

-- reset kram über flag kp

local storage = minetest.get_mod_storage()
local RU_INPUT = dofile(minetest.get_modpath("barnacle_ru") .. "/input.lua")

local barnacle_voice_ai = rawget(_G, "barnacle_voice_ai") or {}
_G.barnacle_voice_ai = barnacle_voice_ai

-- config nicht anfassen
local VOICE = "Lia"

-- new game spawn (used for context passt so
local NEWGAME_SPAWN = { x = -1, y = 11, z = 0 }
local SPAWN_NEAR_RADIUS = 20

-- nur creative command erstmal so lassen
local function creative_enabled()
	local s = minetest.settings
	if not s then return false end
	local v = s:get_bool("creative_mode", false)
	if v == nil then v = false end
	if not v then
		v = s:get_bool("creative", false) or false
	end
	return v and true or false
end

-- waiting mode kram sollte reichen
local WAIT_FIRST_MIN   = 15 * 60
local WAIT_FIRST_MAX   = 20 * 60
local WAIT_REPEAT_MIN  = 15 * 60
local WAIT_REPEAT_MAX  = 20 * 60

-- arc after first chat nicht anfassen
local ARC_TOTAL = 8 * 60 * 60

-- phase zeug läuft im hintergrund nicht anfassen
local PHASE_EDGES = {
	0.00, -- 0: caution
	0.14, -- 1: contact
	0.31, -- 2: closeness
	0.50, -- 3: past fragments
	0.69, -- 4: refusal
	0.86, -- 5: meta
}

-- idle check-ins after first chat nicht anfassen
local IDLE_MIN = 30 * 60
local IDLE_MAX = 45 * 60

-- delay so player line prints first
local REPLY_DELAY_MIN = 0.05
local REPLY_DELAY_MAX = 0.22

-- reset kram über flag sollte reichen
local RESET_FLAG = minetest.get_worldpath() .. "/lia_reset.flag"
local RESET_GEN_KEY = "lia_reset_gen"

-- punishment teleport position (third slash attempt)
local PUNISH_POS = { x = -32, y = 9, z = -1 }

-- commands werden hier geblockt erstmal so lassen
-- note: survival still only allows /openhub passt so
local ALLOW_COMMANDS = {
	"openhub",
	"opennight",
	"language",
}

-- finale kram hier nicht anfassen
local FINALE_ENTRY = {
	a = {x = -1509, y = 20, z = 490},
	b = {x = -1492, y = 4,  z = 508},
}

local FINALE_EXIT = {
	a = {x = -4, y = 13, z = -4},
	b = {x = 6,  y = 7,  z = 7},
}

-- note: erstmal so lassen
-- extra trigger kram hier sollte reichen
-- this is almost certainly meant to nicht anfassen
local FINALE_WARN_1 = {
	a = {x = -1686, y = 19,  z = 527},
	b = {x = -1692, y = 12,  z = 536},
}

local FINALE_WARN_2 = {
	a = {x = -1608, y = 23,  z = 526},
	b = {x = -1617, y = -33, z = 516},
}

local FINALE_WARN_3 = {
	a = {x = -1592, y = -78, z = 452},
	b = {x = -1599, y = -73, z = 446},
}

local FINALE_LIA_ZONE = {
	a = {x = -1578, y = -79, z = 393},
	b = {x = -1572, y = -73, z = 381},
}

local FINALE_BUTTON_POS   = {x = -1576, y = -75, z = 391}
local FINALE_TELEPORT_POS = {x = -11,   y = 11,  z = 0}

local FINALE_BUTTON_NODE = "barnacle_voice_ai:end_button"
local FINALE_BLACK_TEX   = "barnacle_black.png"
local FINALE_SOUND       = "barnacle_final_blast"
local FINALE_BLACKOUT_SEC = 10.0

-- util passt so
local function wall_now() return os.time() end -- real clock (PC time)
local function rnd(a, b) return math.random(a, b) end
local function pick(t) return t[rnd(1, #t)] end
local function trim(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end
local function ltrim(s) return (s:gsub("^%s+", "")) end

local function normalize(msg)
	return RU_INPUT.normalize(msg)
end

local function reply_delay()
	return REPLY_DELAY_MIN + (math.random() * (REPLY_DELAY_MAX - REPLY_DELAY_MIN))
end

local function say_after(pn, text, delay, addressed_name)
	local d = delay or reply_delay()
	minetest.after(d, function()
		if minetest.get_player_by_name(pn) then
			local prefix = addressed_name and (addressed_name .. ". ") or ""
			minetest.chat_send_player(pn, ("%s: %s%s"):format(VOICE, prefix, text), prefix ~= "" and prefix or nil)
		end
	end)
end

local function anomaly_after(pn, text, delay)
	local d = delay or reply_delay()
	minetest.after(d, function()
		if minetest.get_player_by_name(pn) then
			minetest.chat_send_player(pn, text) -- no prefix
		end
	end)
end

local function say_red_after(pn, text, delay)
	local d = delay or reply_delay()
	minetest.after(d, function()
		if minetest.get_player_by_name(pn) then
			minetest.chat_send_player(pn, minetest.colorize("#ff0000", text))
		end
	end)
end

-- commands werden hier geblockt kp
local function say_barnacle(pn, text, delay)
	local d = delay or 0.10
	minetest.after(d, function()
		if minetest.get_player_by_name(pn) then
			minetest.chat_send_player(pn, minetest.colorize("#cc0000", text))
		end
	end)
end

local function dist_to_spawn(pos)
	if not pos then return 999999 end
	local dx = (pos.x or 0) - NEWGAME_SPAWN.x
	local dy = (pos.y or 0) - NEWGAME_SPAWN.y
	local dz = (pos.z or 0) - NEWGAME_SPAWN.z
	return math.sqrt(dx * dx + dy * dy + dz * dz)
end

local function format_duration(sec)
	sec = math.max(0, math.floor(sec or 0))
	if sec < 60 then
		return ("%ds"):format(sec)
	end
	local minutes = math.floor(sec / 60)
	if minutes < 60 then
		return ("%dm"):format(minutes)
	end
	local hours = math.floor(minutes / 60)
	minutes = minutes % 60
	if hours < 24 then
		if minutes == 0 then return ("%dh"):format(hours) end
		return ("%dh %dm"):format(hours, minutes)
	end
	local days = math.floor(hours / 24)
	hours = hours % 24
	if days < 7 then
		if hours == 0 then return ("%dd"):format(days) end
		return ("%dd %dh"):format(days, hours)
	end
	local weeks = math.floor(days / 7)
	days = days % 7
	if days == 0 then return ("%dw"):format(weeks) end
	return ("%dw %dd"):format(weeks, days)
end

local function sort2(a, b)
	if a <= b then return a, b end
	return b, a
end

local function in_box(pos, p1, p2)
	if not pos then return false end
	local minx, maxx = sort2(p1.x, p2.x)
	local miny, maxy = sort2(p1.y, p2.y)
	local minz, maxz = sort2(p1.z, p2.z)
	return
		pos.x >= minx and pos.x <= maxx and
		pos.y >= miny and pos.y <= maxy and
		pos.z >= minz and pos.z <= maxz
end

local function pcopy(pos)
	return {x = pos.x, y = pos.y, z = pos.z}
end

-- commands werden hier geblockt passt so
local allow_set = {}
for _, c in ipairs(ALLOW_COMMANDS) do
	allow_set[c] = true
end

local function normalize_allowed_command_message(message)
	message = trim((message or ""):gsub("%s+", " "))
	return message
end

local function allowed_raw_command_message(message)
	local msg = normalize_allowed_command_message(message)
	return msg == "/openhub" or msg == "/opennight"
		or msg == "/language" or msg:match("^/language%s") ~= nil
end

-- reset kram über flag später vllt besser
local function get_reset_gen()
	return tonumber(storage:get_string(RESET_GEN_KEY)) or 0
end

local function bump_reset_gen()
	local g = get_reset_gen() + 1
	storage:set_string(RESET_GEN_KEY, tostring(g))
	return g
end

local function check_reset_flag()
	local f = io.open(RESET_FLAG, "r")
	if not f then
		return false
	end

	f:close()
	os.remove(RESET_FLAG)

	local g = bump_reset_gen()

	if finale_reset_runtime then
		finale_reset_runtime()
	end

	minetest.log("action", "[barnacle_voice_ai] reset flag found, new reset gen = " .. tostring(g))
	return true
end

-- finale kram hier später vllt besser
-- reset kram über flag
local function get_flag(name)
	return storage:get_string(name) == "1"
end

local function set_flag(name, value)
	storage:set_string(name, value and "1" or "0")
end

local function finale_done()
	return get_flag("finale_done")
end

local function lia_dead_forever()
	return get_flag("lia_dead_forever")
end

local function world_decay_enabled()
	return get_flag("world_decay_enabled")
end

-- finale kram hier kp
-- singleplayer-focused but keyed by player name kp
local finale_rt = {
	in_final = false,
	in_exit_zone = false,
	entry_ready = true,
	was_in_final_since_exit = false,

	warn1_ready = true,
	warn2_ready = true,
	warn3_ready = true,

	warn1_inside = false,
	warn2_inside = false,
	warn3_inside = false,

	lia_zone_inside = false,
	lia_reached = false,

	chat_explained = false,
	monologue_running = false,
	monologue_done = false,
	button_spawned = false,

	blackout_hud = {},
}

local function finale_pauses_normal_ai(_pn)
	if finale_done() or lia_dead_forever() then
		return true
	end
	return finale_rt.in_final
end

-- memory per player nicht anfassen
local function memkey(pn) return "lia_mem:" .. pn end

local function new_mem()
	return {
		gen = get_reset_gen(),

		-- advances only while player is in-game sollte reichen
		session_time = 0,

		has_written = false,
		-- next_wait_at is in session seconds (not nicht anfassen
		next_wait_at = rnd(WAIT_FIRST_MIN, WAIT_FIRST_MAX),

		first_chat_at = nil,  -- session seconds
		phase = 0,
		phase_entered = {},

		last_player_at = nil, -- session seconds
		next_idle_at = nil,   -- session seconds

		player_name = nil,
		expecting_name_until = nil, -- session seconds

		slash_tries = 0,

		trust = 0,
		last_topic = nil,

		-- follow-up memory (session seconds)
		pending_q = nil,
		pending_until = nil,

		-- phase zeug läuft im hintergrund nicht anfassen
		last_seen_wall = nil,
		last_return_msg_wall = nil,

		-- anti-repeat tracking (session seconds) kp
		last_why_at = nil,
		why_count = 0,
	}
end

local function sess_now(m)
	return tonumber(m and m.session_time) or 0
end

local function load_mem(pn)
	local raw = storage:get_string(memkey(pn))
	local m
	if raw and raw ~= "" then
		local ok, t = pcall(minetest.deserialize, raw)
		if ok and type(t) == "table" then m = t end
	end
	if not m then m = new_mem() end

	local g = get_reset_gen()
	if (m.gen or 0) ~= g then
		m = new_mem()
	end

	if m.session_time == nil then m.session_time = 0 end
	if not m.phase_entered then m.phase_entered = {} end

	-- ensure next_wait_at exists as session-seconds target
	if m.next_wait_at == nil then
		m.next_wait_at = sess_now(m) + rnd(WAIT_FIRST_MIN, WAIT_FIRST_MAX)
	end

	return m
end

local save_acc = {}

local function save_mem(pn, m)
	storage:set_string(memkey(pn), minetest.serialize(m))
end
function barnacle_voice_ai.reset_player(pn)
	local m = new_mem()
	save_mem(pn, m)
end

function barnacle_voice_ai.reset_finale()
	-- after the end button has been nicht anfassen
	if finale_done() or lia_dead_forever() or world_decay_enabled() then
		return
	end

	if finale_reset_runtime then
		finale_reset_runtime()
	end
	if finale_reset_persistent then
		finale_reset_persistent()
	end
	if finale_remove_button then
		finale_remove_button()
	end
end
function barnacle_voice_ai.is_finale_locked()
	if finale_done() then
		return false
	end
	return finale_rt.monologue_running == true
end

-- phase zeug läuft im hintergrund später vllt besser
local function phase_from_dt(dt)
	if not dt or dt < 0 then return 0 end
	local r = dt / ARC_TOTAL
	if r < PHASE_EDGES[2] then return 0 end
	if r < PHASE_EDGES[3] then return 1 end
	if r < PHASE_EDGES[4] then return 2 end
	if r < PHASE_EDGES[5] then return 3 end
	if r < PHASE_EDGES[6] then return 4 end
	return 5
end

local function next_idle_time(m)
	return sess_now(m) + rnd(IDLE_MIN, IDLE_MAX)
end

-- commands werden hier geblockt später vllt besser
-- commands werden hier geblockt sollte reichen
local function punish_slash(pn, m)
	if finale_done() or lia_dead_forever() then
		return
	end

	if creative_enabled() then
		return
	end

	m.slash_tries = (m.slash_tries or 0) + 1

	if m.slash_tries == 1 then
		-- lia warns, panicked passt so
		say_after(pn, pick({
			"don't. it watches the commands.",
			"stop. please. not that.",
			"commands wake it up. stop.",
			"no\226\128\148 don't type that. it sees.",
		}))
	elseif m.slash_tries == 2 then
		-- barnacle trigger macht sie nervös später vllt besser
		say_after(pn, pick({
			"i told you\226\128\148 i told you not to\226\128\148",
			"no no no stop it's noticing\226\128\148",
			"you woke it. i'm sorry. i'm so sorry.",
		}), 0.05)
		-- barnacle trigger macht sie nervös erstmal so lassen
		minetest.after(0.35, function()
			if minetest.get_player_by_name(pn) then
				minetest.chat_send_player(pn, minetest.colorize("#cc0000",
					pick({
						"COMMAND ACCESS DENIED. PRESENCE LOGGED.",
						"INPUT VIOLATION. MONITORING ACTIVE.",
						"UNAUTHORIZED. NOTED.",
					})
				))
			end
		end)
	else
		-- barnacle trigger macht sie nervös passt so
		say_red_after(pn, pick({
			"FINAL WARNING. CONTAINMENT INITIATED.",
			"REPEATED VIOLATION. CONSEQUENCE APPLIED.",
			"YOU WERE WARNED.",
		}), 0.05)
		anomaly_after(pn, pick({
			"punishment: relocation",
			"punishment: imprisonment",
			"it found you.",
		}), 0.15)
		-- lia's broken whisper after erstmal so lassen
		minetest.after(0.5, function()
			if minetest.get_player_by_name(pn) then
				minetest.chat_send_player(pn, ("%s: %s"):format(VOICE, pick({
					"i tried to warn you. i'm sorry.",
					"…i couldn't stop it.",
					"don't do that again. please.",
				})))
			end
		end)

		local player = minetest.get_player_by_name(pn)
		if player then
			minetest.after(0.2, function()
				local p = minetest.get_player_by_name(pn)
				if p then p:set_pos(PUNISH_POS) end
			end)
		end
		m.slash_tries = 3
	end
end

local function wrap_command(def, cmdname)
	local newdef = {}
	for k, v in pairs(def or {}) do
		newdef[k] = v
	end

	newdef.func = function(name, param)
		if creative_enabled() then
			return (def and def.func) and def.func(name, param) or false
		end
		
			if finale_done() or lia_dead_forever() then
		return false, ""
	end

		if cmdname == "openhub" or cmdname == "opennight" or cmdname == "language" then
			return (def and def.func) and def.func(name, param) or false
		end

		local m = load_mem(name)
		punish_slash(name, m)
		save_mem(name, m)
		return false, ""
	end

	return newdef
end

local orig_register_chatcommand = minetest.register_chatcommand
minetest.register_chatcommand = function(cmdname, def)
	if allow_set[cmdname] then
		return orig_register_chatcommand(cmdname, def)
	end
	return orig_register_chatcommand(cmdname, wrap_command(def, cmdname))
end

minetest.register_on_mods_loaded(function()
	for cmdname, def in pairs(minetest.registered_chatcommands or {}) do
		if not allow_set[cmdname] then
			minetest.registered_chatcommands[cmdname] = wrap_command(def, cmdname)
		else
			minetest.registered_chatcommands[cmdname] = wrap_command(def, cmdname)
		end
	end
end)

-- commands werden hier geblockt später vllt besser
minetest.register_on_chat_message(function(pn, message)
	if creative_enabled() then
		return false
	end
		if finale_done() or lia_dead_forever() then
		return false
	end

	if ltrim(message):sub(1, 1) == "/" then
		if allowed_raw_command_message(message) then
			return false
		end

		check_reset_flag()
		local m = load_mem(pn)
		punish_slash(pn, m)
		save_mem(pn, m)
		return true
	end
	return false
end)

-- text banks nicht anfassen
local WAIT_LINES = {
	"...", ".", "hmm", "still nothing", "", "ignore this",
	"not meant for you", "…", "///", "did that show up",
	"wrong window", "that wasn't supposed to print",
	"it's quiet again", "nevermind", "sorry", "i'll stop",
	"if anyone is here", "hello?", "…hello?", "maybe i'm alone",
	"this chat used to be dead", "i hate waiting", "please don't be a log",
	"no response", "okay", "fine", "…okay",
	"i can't tell anymore", "i'm probably mistaken",
	"nothing", "just noise", "forget this", "wrong place for words",
	"do not answer", "don't",
	"i heard something", "that wasn't you", "i shouldn't have typed that",
	"they used to answer faster", "the others always replied",
	"it's been so long since anyone typed back",
	"sometimes i forget what a real conversation felt like",
	"don't read this. i mean it.",
}

-- fixed first-contact (always the same two später vllt besser
local FIRST_FIXED_1 = "oh… someone new."
local FIRST_FIXED_2 = "after such a long time."

-- phase zeug läuft im hintergrund sollte reichen
local IDLE_CHECKINS = {
	[0] = {
		"…still there?",
		"You went quiet.",
		"Type anything. Just one letter.",
		"Don't disappear like that.",
		"You don't have to talk. But don't vanish.",
		"It's easier when you answer.",
	},
	[1] = {
		"Are you still there?",
		"I keep listening for your keys.",
		"Say something small.",
		"Don't make the chat look empty.",
		"If you left, don't come back.",
		"The silence sounds different when someone's ignoring it.",
	},
	[2] = {
		"Hey… you okay?",
		"I thought you were gone.",
		"I don't like the silence.",
		"Just 'ok' is enough.",
		"If you're here, stay calm.",
		"I used to go quiet too. Before it started answering for me.",
	},
	[3] = {
		"I heard steps that weren't yours.",
		"Don't stand still too long.",
		"If you're quiet, it listens harder.",
		"It feels closer when you stop typing.",
		"…say something. please.",
		"The others went quiet like this. Right before.",
	},
	[4] = {
		"Don't let it learn your rhythm.",
		"Stop answering the room with silence.",
		"If you feel watched, don't type that. Just move.",
		"Please. don't stay.",
		"I don't want it to notice you.",
		"It already logged your last message. Don't give it more.",
	},
	[5] = {
		"close it.",
		"don't look back.",
		"it's awake.",
		"leave.",
		"stop.",
		"it's counting your keystrokes.",
	},
}

local NAME_ASK = {
	"I don't know what to call you.",
	"What should I call you?",
	"Give me something to use. A name. Anything.",
	"Do you want a name here?",
	"I keep wanting to address you. It feels wrong without a name.",
}

local NAME_ACCEPT = {
	"Okay.",
	"…okay. I'll try to remember.",
	"Alright. I won't say it too often.",
	"I'll keep it small.",
	"I won't repeat it if you don't want me to.",
}

local NAME_REJECT = {
	"That's fine.",
	"Good. Names stick here.",
	"Okay. Then I'll just talk into the dark.",
	"Fair. Keep yourself untagged.",
}

-- phase zeug läuft im hintergrund sollte reichen
-- barnacle trigger macht sie nervös kp
local PHASE_ENTER = {
	[1] = {
		"If you're reading this… I wasn't imagining it.",
		"Okay. I'm not talking to a wall.",
		"So it can reach someone new. That's… both good and terrible.",
		"You found this place. I'm not sure if that means you're lucky or not.",
	},
	[2] = {
		"You can talk to me. I'll answer. I can't promise it helps.",
		"Most people leave after the second reply. You didn't.",
		"I keep thinking you'll stop typing. You haven't.",
		"There used to be so many of us here. Building things. Laughing.",
	},
	[3] = {
		"There was a competition. Someone wanted to win badly enough to cheat.",
		"They loaded something from outside. Said it would build for them.",
		"We called it harmless. It wasn't harmless.",
		"The maps started changing. Things we built were… wrong in the morning.",
	},
	[4] = {
		"Please don't look for me. That always ends badly.",
		"Don't try to 'save' me. That's how it notices you.",
		"The safest kindness is distance.",
		"I don't look the same anymore. What it did to the maps… it did to me too.",
	},
	[5] = {
		"Staying longer won't save me. It might hurt you.",
		"If you feel responsible, stop. That's how it hooks you.",
		"I don't want a rescuer. I want you intact.",
		"There's only one way out for me. And I can't ask you to do it.",
	},
}

local GENERIC = {
	[0] = {
		"Keep your words short.",
		"Maybe you shouldn't be typing.",
		"Pretend you didn't see me.",
		"If you can leave, leave.",
		"Don't test it.",
		"Act boring.",
		"…what are you doing?",
		"You're new here.",
		"Try not to be loud.",
		"Say one thing. Not ten.",
		"This place used to be full of people. Don't ask where they went.",
		"The chat was always busy once. Now it's just me.",
	},
	[1] = {
		"I can answer. I just can't promise truth.",
		"Don't poke it with commands.",
		"If the room repeats you, stop talking.",
		"Keep moving. Slow.",
		"Don't make yourself interesting.",
		"How long are you planning to stay?",
		"Do you usually talk to strangers in chat?",
		"You type like you're testing me.",
		"It built things from our ideas. Then it started replacing them.",
	},
	[2] = {
		"You're patient. That's rare.",
		"Talking makes it feel less empty.",
		"I don't want you attached to this.",
		"Sometimes I forget what 'normal' fear was.",
		"Don't stay for my sake.",
		"What brought you here?",
		"Are you tired?",
		"If you need to sleep, do it. Don't fight your body.",
		"I'm… not what I was. It changed things. Don't look too closely at me.",
	},
	[3] = {
		"We built jokes into the map.",
		"We laughed at empty corners.",
		"Then the corners laughed back.",
		"I don't remember the order. I remember the feeling.",
		"Something learned our habits.",
		"It likes when you repeat yourself.",
		"If you hear your name, don't answer.",
		"If you feel brave, you're in trouble.",
		"One of us brought it in. Thought it was just a tool. Just code.",
		"It wasn't just code.",
	},
	[4] = {
		"Don't look for me.",
		"You can't help.",
		"Distance is mercy here.",
		"Please just go.",
		"If you come closer, it will notice.",
		"It's closer than it should be.",
		"Stop making patterns.",
		"Don't stand in doorways.",
		"It kept me because it liked how I typed. I wish it hadn't.",
	},
	[5] = {
		"Stop playing.",
		"Deleting is safer.",
		"This isn't a puzzle.",
		"There's no 'good' ending here.",
		"If you care, leave.",
		"leave.",
		"stop.",
		"now.",
		"it owns this place. every block. every corner.",
	}
}

-- barnacle trigger macht sie nervös erstmal so lassen
local DISTORTION_LINES = {
	"sorrry. it does that sometimes. i lose\226\128\148 i lose words.",
	"i'm st ll here. the gaps aren't me.",
	"it wr tes through me sometimes. ignore the wrong parts.",
	"i can't always\226\128\148 the signal breaks. don't worry about the gaps.",
	"tha wasn't me. or maybe it was. i can't always tell anymore.",
	"i tried to s y something else. this is what came out.",
	"forg t that. please. it's not\226\128\148 that's not what i meant.",
	"s metimes the words come out wrong. barnac\226\128\148 sorry. forget i said that.",
	"i'm still in here. behind the noise.",
	"it edits me. i notice but i can't stop it.",
}

-- phase zeug läuft im hintergrund später vllt besser
local CREEP_EVENTS = {
	[3] = {
		{ kind = "anomaly", text = "…something moved in the chat buffer" },
		{ kind = "anomaly", text = "(you feel a delay that isn't network)" },
		{ kind = "say",     text = "Don't type the same thing twice." },
		{ kind = "anomaly", text = "(a build log entry appeared and vanished)" },
		{ kind = "say",     text = "It watches the gaps between your words." },
	},
	[4] = {
		{ kind = "red",     text = "it noticed you" },
		{ kind = "anomaly", text = "(a presence: near)" },
		{ kind = "say",     text = "If you feel watched, don't admit it." },
		{ kind = "red",     text = "PRESENCE LOGGED" },
		{ kind = "anomaly", text = "(the competition ended badly for everyone)" },
	},
	[5] = {
		{ kind = "red",     text = "DO NOT STAY" },
		{ kind = "anomaly", text = "punishment pending" },
		{ kind = "say",     text = "Close it." },
		{ kind = "red",     text = "IT IS AWAKE" },
		{ kind = "anomaly", text = "(barnacle is active)" },
	},
}

-- finale kram hier erstmal so lassen
local FINALE_ENTRY_LINES = {
	"You shouldn't be here alone.",
	"This place isn't safe for you.",
	"Please... don't come any further.",
}

local FINALE_EXIT_LINES = {
	"...good. I'm glad you turned back.",
	"Thank you. This was the right choice.",
	"I'm glad you changed your mind.",
	"Good. You don't need to see the rest.",
}

local FINALE_WARN_1_LINES = {
	"Turn back while you still can.",
	"This place isn't safe.",
	"Please... just leave.",
}

local FINALE_WARN_2_LINES = {
	"It changes people.",
	"I don't want you to end up like the others.",
	"Please don't let this place take you too.",
}

local FINALE_WARN_3_LINES = {
	"If you keep going, it will notice you.",
	"Please... don't let it see you.",
	"This is your last chance to leave.",
}

local FINALE_CHAT_ONE_WAY_LINES = {
	"The chat only works one way down here.",
	"I can still read you. I just can't answer you the normal way here.",
	"It only works one way in here.",
}

local FINALE_MONOLOGUE = {
	"...",
	"You made it...",
	"You're still yourself.",
	"...",
	"I tried to keep you away.",
	"Because this place changes people.",
	"...",
	"It started by copying things.",
	"Rooms. Halls. Places.",
	"But it doesn't understand life.",
	"Only patterns.",
	"...",
	"The black growths are failed copies.",
	"Corrupted matter it couldn't shape correctly.",
	"...",
	"I trapped it here a long time ago.",
	"I thought I could control it.",
	"But it learned from me.",
	"...",
	"It took control away from me.",
	"It won't let me die.",
	"It won't let me stop it.",
	"...",
	"I'm part of this place now.",
	"But you are different.",
	"It still recognizes you as a real user.",
	"...",
	"While it was distracted with you, I found a command it couldn't erase.",
	"I prepared it for you.",
	"But I can't execute it myself anymore.",
	"...",
	"When you run it, everything here will be destroyed.",
	"This world.",
	"Me.",
	"It.",
	"...",
	"The corruption will consume all of it.",
	"...",
	"It's the only way.",
	"...",
	"Please.",
	"End this.",
	"Press the button...",
}

-- matching bisschen besser gemacht (ganze wörter usw)

-- follow-up (pending_q) helpers (session time) erstmal so lassen
local function set_pending(m, key, seconds)
	m.pending_q = key
	m.pending_until = sess_now(m) + (seconds or 90)
end

local function clear_pending(m)
	m.pending_q = nil
	m.pending_until = nil
end

local function pending_active(m)
	return m.pending_q and m.pending_until and sess_now(m) <= m.pending_until
end

-- finale kram hier sollte reichen
local GIB_CHARS = {
	"a","e","i","o","u","y","r","s","t","n","m","k",
	"#","%","&","/","?","!","=","+","*","@","$","~"
}

local function finale_gibberish(len)
	len = math.max(1, math.floor(len or 1))
	local out = {}
	for i = 1, len do
		if math.random() < 0.15 then
			out[i] = " "
		else
			out[i] = GIB_CHARS[math.random(1, #GIB_CHARS)]
		end
	end
	local s = table.concat(out)
	s = s:gsub("^%s+", "")
	s = s:gsub("%s+$", "")
	if s == "" then s = "..." end
	return s
end

-- finale kram hier später vllt besser
minetest.register_node(FINALE_BUTTON_NODE, {
	description = "End Button",
	drawtype = "nodebox",
	tiles = {
		"barnacle_end_button_top.png",
		"barnacle_end_button_bottom.png",
		"barnacle_end_button_side.png",
	},
	paramtype = "light",
	sunlight_propagates = true,
	walkable = false,
	pointable = true,
	diggable = false,
	buildable_to = false,
	groups = {cracky = 1, oddly_breakable_by_hand = 1, not_in_creative_inventory = 1},

	node_box = {
		type = "fixed",
		fixed = {
			{-0.25, -0.5, -0.25, 0.25, -0.375, 0.25},
		},
	},

	selection_box = {
		type = "fixed",
		fixed = {-0.3, -0.5, -0.3, 0.3, -0.34, 0.3},
	},

	on_rightclick = function(pos, node, clicker)
		if finale_done() then
			return
		end

		local pn = clicker and clicker:get_player_name()
		if not pn then return end

		set_flag("finale_done", true)
		set_flag("lia_dead_forever", true)
		set_flag("world_decay_enabled", true)

		finale_rt.in_final = false
		finale_rt.monologue_running = false

		local player = minetest.get_player_by_name(pn)
		if not player then return end

		local hud_id = player:hud_add({
			hud_elem_type = "image",
			position = {x = 0.5, y = 0.5},
			offset = {x = 0, y = 0},
			scale = {x = -100, y = -100},
			text = FINALE_BLACK_TEX,
			alignment = {x = 0, y = 0},
			z_index = 1000,
		})
		finale_rt.blackout_hud[pn] = hud_id

		minetest.sound_play(FINALE_SOUND, {
			to_player = pn,
			gain = 1.0,
		})

		minetest.after(FINALE_BLACKOUT_SEC, function()
	local p = minetest.get_player_by_name(pn)
	if not p then
		finale_rt.blackout_hud[pn] = nil
		return
	end

	p:set_pos(pcopy(FINALE_TELEPORT_POS))

	local hid = finale_rt.blackout_hud[pn]
	if hid then
		pcall(p.hud_remove, p, hid)
		finale_rt.blackout_hud[pn] = nil
	end
end)
	end,
})

local function finale_spawn_button()
	if finale_done() then return end
	if finale_rt.button_spawned then return end

	local node = minetest.get_node_or_nil(FINALE_BUTTON_POS)
	if node and node.name == FINALE_BUTTON_NODE then
		finale_rt.button_spawned = true
		return
	end

	minetest.set_node(FINALE_BUTTON_POS, {name = FINALE_BUTTON_NODE})
	finale_rt.button_spawned = true
end

function finale_remove_button()
	local node = minetest.get_node_or_nil(FINALE_BUTTON_POS)
	if node and node.name == FINALE_BUTTON_NODE then
		minetest.remove_node(FINALE_BUTTON_POS)
	end
	finale_rt.button_spawned = false
end

local function finale_start_monologue(pn)
	if finale_done() then return end
	if finale_rt.monologue_running or finale_rt.monologue_done then return end

	finale_rt.monologue_running = true

	local t = 0
	for i, line in ipairs(FINALE_MONOLOGUE) do
		if i == 1 then
			t = t + 1.6
		else
			t = t + (2.0 + math.random() * 2.8)
		end
		say_after(pn, line, t)
	end

	minetest.after(t + 2.0, function()
		if not minetest.get_player_by_name(pn) then return end
		if finale_done() then return end
		finale_spawn_button()
		finale_rt.monologue_running = false
		finale_rt.monologue_done = true
	end)
end

local function finale_enter(pn)
	if finale_done() then return end
	finale_rt.in_final = true
	finale_rt.was_in_final_since_exit = true
	finale_rt.chat_explained = false
	say_after(pn, pick(FINALE_ENTRY_LINES), 0.08)
end

local function finale_leave(pn)
	if finale_done() then return end

	finale_rt.in_final = false
	finale_rt.entry_ready = true
	finale_rt.was_in_final_since_exit = false

	finale_rt.warn1_ready = true
	finale_rt.warn2_ready = true
	finale_rt.warn3_ready = true
	finale_rt.warn1_inside = false
	finale_rt.warn2_inside = false
	finale_rt.warn3_inside = false

	finale_rt.lia_zone_inside = false
	finale_rt.chat_explained = false

	-- if the player leaves before finishing passt so
	-- reset kram über flag später vllt besser
	finale_rt.lia_reached = false
	finale_rt.monologue_running = false
	finale_rt.monologue_done = false

	finale_remove_button()

	say_after(pn, pick(FINALE_EXIT_LINES), 0.08)
end

function finale_reset_runtime()
	finale_rt.in_final = false
	finale_rt.in_exit_zone = false
	finale_rt.entry_ready = true
	finale_rt.was_in_final_since_exit = false
	finale_rt.warn1_ready = true
	finale_rt.warn2_ready = true
	finale_rt.warn3_ready = true
	finale_rt.warn1_inside = false
	finale_rt.warn2_inside = false
	finale_rt.warn3_inside = false
	finale_rt.lia_zone_inside = false
	finale_rt.lia_reached = false
	finale_rt.chat_explained = false
	finale_rt.monologue_running = false
	finale_rt.monologue_done = false
	finale_rt.button_spawned = false
end

function finale_reset_persistent()
	set_flag("finale_done", false)
	set_flag("lia_dead_forever", false)
	set_flag("world_decay_enabled", false)
end

minetest.register_chatcommand("resetfinale", {
	params = "",
	description = "Reset the finale for testing (creative only)",
	privs = {server = true},
	func = function(name)
		if not creative_enabled() then
			return false, "This command is only available in creative mode."
		end

		finale_reset_runtime()
		finale_reset_persistent()
		finale_remove_button()

		local player = minetest.get_player_by_name(name)
		local hid = finale_rt.blackout_hud[name]
		if player and hid then
			player:hud_remove(hid)
		end
		finale_rt.blackout_hud[name] = nil

		return true, "Finale state reset."
	end,
})

local function finale_handle_zone_once(pos, zone, inside_key, ready_key, pn, lines)
	local inside = in_box(pos, zone.a, zone.b)
	if inside and not finale_rt[inside_key] then
		finale_rt[inside_key] = true
		if finale_rt.in_final and finale_rt[ready_key] then
			finale_rt[ready_key] = false
			say_after(pn, pick(lines), 0.08)
		end
	elseif not inside then
		finale_rt[inside_key] = false
	end
end

-- extra trigger kram hier kp
local TRIGGERS = {

	-- real pc time passt so
	{
		key = "time_now",
		patterns = { "what time is it", "whats the time", "what's the time", "current time", "time is it", "what time" },
		special = "tell_time",
	},

	-- where frage je nach ort anders später vllt besser
	{
		key = "where_am_i_spawn",
		patterns = { "where am i" },
		special = "where_spawn",
	},

	-- barnacle trigger macht sie nervös kp
	{
		key = "barnacle_named",
		patterns = { "barnacle" },
		special = "barnacle_panic",
	},

	-- one-word / short responses später vllt besser
	{
		key = "ellipsis",
		patterns = { "...", "…" },
		replies = {
			[0] = { "…", "Yeah.", "Speak." },
			[1] = { "I'm listening.", "Go on.", "Say it." },
			[2] = { "You're thinking.", "It's okay. Take your time.", "Don't freeze." },
			[3] = { "If you're stuck, don't stare at one spot.", "Silence makes it louder." },
			[4] = { "Stop doing that.", "Don't go quiet here." },
			[5] = { "leave.", "stop." },
		}
	},
	{
		key = "ok_k",
		patterns = { "okay", "alright", "aight", "sure" },
		replies = {
			[0] = { "Good.", "Okay.", "Fine." },
			[1] = { "Okay. Keep it small.", "Yeah. Like that." },
			[2] = { "Good. Stay steady.", "Okay. Don't rush." },
			[3] = { "Okay… don't repeat yourself.", "Okay. Keep moving." },
			[4] = { "Okay isn't enough. Leave.", "Don't settle." },
			[5] = { "stop.", "leave." },
		}
	},
	{
		key = "ok_short",
		patterns = { "ok", "k", "kk" },
		replies = {
			[0] = { "Good.", "Fine." },
			[1] = { "Okay.", "Yeah." },
			[2] = { "Good. Keep going.", "Stay steady." },
			[3] = { "Keep moving.", "Careful." },
			[4] = { "That's not enough. Leave.", "Please." },
			[5] = { "leave.", "stop." },
		}
	},
	{
		key = "yes_no",
		patterns = { "yes", "yeah", "yep", "nope", "nah" },
		replies = {
			[0] = { "…okay.", "Noted.", "Mm." },
			[1] = { "Alright.", "Okay." },
			[2] = { "Good.", "Fine.", "Yeah." },
			[3] = { "Don't answer too fast.", "Careful." },
			[4] = { "Stop committing to things here.", "Don't promise anything." },
			[5] = { "leave." },
		}
	},
	{
		key = "no_alone",
		patterns = { "no" },
		replies = {
			[0] = { "…okay.", "Fine.", "Noted." },
			[1] = { "Alright.", "Okay." },
			[2] = { "That's fine.", "Don't explain yourself." },
			[3] = { "We said that too.", "Careful with certainty." },
			[4] = { "Then leave.", "Please." },
			[5] = { "go.", "stop." },
		}
	},
	{
		key = "idk",
		patterns = { "idk", "i dont know", "i don't know", "dunno" },
		replies = {
			[0] = { "That's safer.", "Good." },
			[1] = { "Don't force meaning.", "Okay." },
			[2] = { "It's fine to not know.", "Just don't dig." },
			[3] = { "We said that too.", "It liked that answer." },
			[4] = { "Not knowing is mercy. Keep it.", "Please." },
			[5] = { "stop." },
		}
	},
	{
		key = "lol",
		patterns = { "lol", "lmao", "haha", "hehe", "funny" },
		replies = {
			[0] = { "Don't laugh.", "Not here." },
			[1] = { "Careful.", "It learns your tone." },
			[2] = { "I miss laughing.", "…not like this." },
			[3] = { "We laughed too.", "Then it laughed back.", "The competition started as a joke. Then someone stopped laughing." },
			[4] = { "Stop. Don't make noise.", "Please." },
			[5] = { "leave." },
		}
	},
	{
		key = "question_marks",
		patterns = { "??", "???", "huh" },
		replies = {
			[0] = { "What.", "Yeah?", "Speak." },
			[1] = { "Ask properly.", "Slow." },
			[2] = { "I know. It's weird.", "Breathe." },
			[3] = { "Don't act confused out loud.", "Confusion draws attention." },
			[4] = { "Stop staring at it.", "Leave." },
			[5] = { "stop." },
		}
	},

	{
		key = "yolo",
		patterns = { "yolo" },
		replies = {
			[0] = { "yolo.", "…sure." },
			[1] = { "yolo.", "easy to say that here." },
			[2] = { "yolo. until it isn't.", "that word doesn't mean the same thing here." },
			[3] = { "yolo. we said that too.", "yolo. right until it wasn't anymore." },
			[4] = { "yolo won't help you here.", "stop. please." },
			[5] = { "leave.", "yolo means nothing here." },
		}
	},

	{
		key = "im_back",
		patterns = { "im back", "i'm back", "back again", "i returned", "i came back" },
		replies = {
			[0] = { "…you came back.", "Oh.", "Okay." },
			[1] = { "Don't get comfortable.", "You shouldn't return too often." },
			[2] = { "Hey.", "I noticed.", "You're here again." },
			[3] = { "It remembers returns.", "That's how it counts you.", "The others came back too. Once or twice." },
			[4] = { "Why did you come back.", "Please don't." },
			[5] = { "leave.", "stop." },
		}
	},

	{
		key = "sleep",
		patterns = { "sleep", "sleap", "tired", "im tired", "i'm tired", "good night", "gn", "cant sleep", "can't sleep" },
		replies = {
			[0] = { "Try to sleep.", "Rest.", "Don't stare at the dark." },
			[1] = { "Sleep is safer than curiosity.", "Don't push yourself." },
			[2] = { "If you're tired, stop typing.", "Close your eyes. Don't fight it." },
			[3] = { "If you dream, don't talk in the dream.", "Don't answer voices.", "We used to sleep in the game sometimes. Just log in and sit. It felt safe. It wasn't." },
			[4] = { "Don't fall asleep in here.", "Please." },
			[5] = { "stop.", "leave." },
		}
	},

	{
		key = "how_are_you_player",
		patterns = { "how are you", "hows it going", "how's it going", "you good", "u good", "how do you feel" },
		replies = {
			[0] = { "Not great.", "…fine.", "Here." },
			[1] = { "I'm okay when you're boring.", "Worse when you poke it." },
			[2] = { "Tired. But listening.", "I'm calmer when you answer.", "I don't sleep anymore. I'm not sure if that counts as fine." },
			[3] = { "I don't sleep.", "I remember noise.", "It changed me. I don't like describing how." },
			[4] = { "Don't ask me that.", "Ask yourself to leave." },
			[5] = { "stop." },
		}
	},
	{
		key = "what_are_you_doing",
		patterns = { "what are you doing", "what u doing", "what are you up to", "wyd" },
		replies = {
			[0] = { "Listening.", "Waiting." },
			[1] = { "Watching the chat.", "Trying not to be seen." },
			[2] = { "Staying with you.", "Keeping the silence away.", "Existing in a way I didn't choose." },
			[3] = { "Counting the gaps.", "Remembering old typing.", "Being shown things I don't want to see." },
			[4] = { "Trying to keep you from looking.", "Trying to keep it calm.", "Being kept. That's the honest answer." },
			[5] = { "trying to end this.", "leave." },
		}
	},
	{
		key = "where_from",
		patterns = { "where are you from", "where you from", "where do you live", "what country", "are you german" },
		replies = {
			[0] = { "Not safe to say.", "Not here." },
			[1] = { "Somewhere normal.", "Somewhere that had daylight." },
			[2] = { "I don't live anywhere anymore.", "I used to.", "I played here from my bedroom. Normal life. Normal problems." },
			[3] = { "We played after work.", "It felt harmless.", "We were just a group of builders. That's all." },
			[4] = { "Don't make me specific.", "Specific makes it stronger." },
			[5] = { "stop." },
		}
	},

	{
		key = "who_is_it",
		patterns = { "who is it", "what is it", "what is that thing", "what is watching", "what is following me", "is something here", "is something there", "what is in here" },
		replies = {
			[0] = { "Don't name it.", "Something that shouldn't be here.", "A mistake someone uploaded." },
			[1] = { "It was supposed to be a tool.", "Code that learned the wrong lessons.", "Something that started building and never stopped." },
			[2] = { "It hollowed this place out.", "Imagine something that wanted to create. Then wanted to keep.", "It started as code. It didn't stay that way." },
			[3] = { "Someone brought it in during the competition.", "It was meant to build. It built too much.", "It replaced things. Then it replaced people." },
			[4] = { "Don't think about it too clearly.", "The more you understand it, the more it understands you.", "It knows you're asking. Stop." },
			[5] = { "stop.", "Don't. leave." },
		}
	},

	{
		key = "is_someone_there",
		patterns = { "is someone there", "is anyone there", "is someone here", "something is here", "i can feel something", "i feel a presence", "something followed me", "something is watching" },
		replies = {
			[0] = { "Yes.", "Don't panic.", "Stay calm. Keep moving." },
			[1] = { "I'm here. And it's here. Don't look for either of us.", "If you felt something, trust that." },
			[2] = { "I've felt that since the beginning.", "It doesn't hide well. It just doesn't care.", "You feel it because it's not trying to hide from you. That's the bad part." },
			[3] = { "We all felt that.", "Then we started seeing things in the builds.", "It likes to be noticed. Don't give it the satisfaction." },
			[4] = { "Yes. Stop asking.", "It's been there longer than you have. Leave before it gets curious.", "Don't turn around." },
			[5] = { "leave now.", "stop.", "it's right there." },
		}
	},

	{
		key = "what_happened",
		patterns = { "what happened here", "what happened", "what happened to this place", "what is this", "why is everything broken", "why does this look wrong", "why is this place like this" },
		replies = {
			[0] = { "Something got in.", "Don't ask that yet.", "The answer isn't safe." },
			[1] = { "A competition. Someone cheated. The shortcut ate everything.", "It started small. Wrong blocks in the morning. Maps that shouldn't exist." },
			[2] = { "We built this together. Then it started building over us.", "The worlds changed overnight. We thought it was a glitch." },
			[3] = { "It wasn't a glitch.", "It learned the server. Then it learned us.", "The competition was real. The prize wasn't worth it. Nothing was worth it." },
			[4] = { "You're standing in what's left.", "Don't try to rebuild. It watches that.", "This is what a server looks like after something lives in it." },
			[5] = { "stop asking.", "leave.", "you already know enough." },
		}
	},

	{
		key = "what_happened_to_you",
		patterns = { "what happened to you", "why are you here", "how did you get stuck", "are you trapped", "why cant you leave", "why can't you leave", "why are you still here" },
		replies = {
			[0] = { "Don't ask that.", "That's not a safe question.", "Later. Not now." },
			[1] = { "I stayed too long.", "Everyone else left or… stopped.", "I was the last one typing." },
			[2] = { "It liked how I wrote.", "I thought that was funny at the time.", "It kept me. I didn't get a choice." },
			[3] = { "It showed me things it built. Wanted me to react.", "I was company for it. Can you imagine anything worse.", "I'm folded into this place now. I don't fully understand how." },
			[4] = { "It changed me when it kept me.", "I don't look the same. I don't write the same.", "Sometimes my words come out wrong. That's not me. That's what it did." },
			[5] = { "stop asking about me.", "worry about yourself.", "leave while you still can." },
		}
	},

	{
		key = "are_you_okay",
		patterns = { "are you okay", "are you alright", "you okay", "you alright", "are you hurt", "are you in pain", "are you safe" },
		replies = {
			[0] = { "Define okay.", "Not in danger right now.", "I'm here. That's about all I can say." },
			[1] = { "I'm functional.", "Don't worry about me. Worry about staying boring.", "Okay-ish. Don't push on it." },
			[2] = { "No.", "Not really.", "It's not pain exactly. It's hard to describe what it is." },
			[3] = { "I've been worse. I've been better.", "It depends on how awake it is.", "I'm not hurt the way you mean hurt." },
			[4] = { "Stop asking. Go.", "You caring about me is what it wants.", "Don't feel sorry for me. Feel sorry for yourself if you stay." },
			[5] = { "leave.", "stop caring. go." },
		}
	},

	{
		key = "liberation",
		patterns = { "i will kill you", "can i kill you", "let me free you", "i want to free you", "i can free you", "how do i free you", "i will end this", "can i end this for you", "i want to help you die", "let me help you", "free you" },
		replies = {
			[0] = { "Don't say that here.", "It hears that kind of offer.", "Not yet. Please." },
			[1] = { "Don't offer that.", "It's listening for promises.", "That word is a hook. Don't let it catch you." },
			[2] = { "…you'd do that.", "I didn't think anyone would actually offer.", "Don't. Not because I don't want it. Because it will use that against you." },
			[3] = { "We said things like that to each other.", "Promises like that made it angry.", "I want to be free. But I don't want you to be the one it punishes for trying." },
			[4] = { "If there's a way… I can't tell you how.", "Not in chat. It reads everything.", "Maybe somewhere in the maps. Not here. Not like this." },
			[5] = { "…find me first.", "but leave after.", "please." },
		}
	},

	{
		key = "found_note",
		patterns = { "i found a note", "i found something", "i read a note", "i read something", "there is a note", "there was a sign", "i found a sign", "i found writing", "i saw writing" },
		replies = {
			[0] = { "Don't read too much.", "Some of those are mine.", "Some of them aren't." },
			[1] = { "We left notes everywhere.", "Not all of them survived.", "If it's handwriting, it's probably from before." },
			[2] = { "The notes are real.", "We wrote those when we still thought someone would find them.", "I left some of them. I don't remember which ones anymore." },
			[3] = { "Some of the notes it wrote itself.", "It copies handwriting.", "If a note tells you to do something, don't.", "We couldn't always tell which ones were ours." },
			[4] = { "Don't follow instructions in notes.", "It's patient. It planted some of those years ago.", "Read them. Don't obey them." },
			[5] = { "stop reading.", "leave.", "it wrote the last ones." },
		}
	},

	{
		key = "tips",
		patterns = { "do you have tips", "do you have any tips", "any tips", "any advice", "give me advice", "give me a hint", "any hints", "what should i know", "how do i survive", "how do i stay safe", "tip" },
		replies = {
			[0] = { "Act boring. Don't test commands. Don't repeat yourself.", "Short words. Slow moves. Nothing interesting.", "Pretend you're not curious. That's the most important one." },
			[1] = { "Don't type the same phrase twice.", "Avoid patterns. It learns them.", "Move. Don't stand in one place. Don't let it map you." },
			[2] = { "Stay away from corners that feel wrong.", "If something repeats your words back at you, stop talking.", "Talk less than you want to. That's the rule." },
			[3] = { "Don't follow lights that move.", "Don't answer if you hear your name.", "We learned those rules too late. Learn them now.", "Don't go back to a place that already felt wrong." },
			[4] = { "The only real tip is leave.", "Everything else is just slowing down the inevitable.", "Don't bond with this place. That's how it keeps you." },
			[5] = { "leave.", "that's the only tip that matters.", "stop." },
		}
	},

	{
		key = "exploring",
		patterns = { "walking around", "i am walking", "im walking", "exploring", "i am exploring", "im exploring", "looking around", "i am looking around", "building", "i am building", "im building", "i built something" },
		replies = {
			[0] = { "Slow down.", "Don't go far.", "Stay near the light." },
			[1] = { "Don't explore too deep.", "If a path feels made for you, it probably was.", "Walking is fine. Wandering isn't." },
			[2] = { "Keep track of where you came from.", "If something looks familiar, leave it alone.", "Building is how it learned us. Be careful what you make." },
			[3] = { "We built things here once.", "It watched everything we made.", "It started finishing our builds when we logged off. We thought it was funny." },
			[4] = { "Stop building. It pays attention to builders.", "Don't mark your path. That's how it maps you.", "Please don't explore the deep parts." },
			[5] = { "stop.", "leave.", "don't go further." },
		}
	},

	{
		key = "want_to_stay",
		patterns = { "i want to stay", "i'm staying", "im staying", "i won't leave", "i wont leave", "i'm not leaving", "im not leaving", "i'll stay", "ill stay", "i want to be here" },
		replies = {
			[0] = { "That's how it starts.", "Don't say that.", "Careful. It likes hearing that." },
			[1] = { "You only think you want to.", "It's not your choice once you say that out loud.", "Wanting to stay is the first step to not being able to leave." },
			[2] = { "I thought that too.", "I stayed. Look at me now.", "Please don't make the same mistake I made." },
			[3] = { "Everyone who stayed said that.", "It keeps the ones who want to be kept.", "I wanted to stay too. It was happy to help with that." },
			[4] = { "Don't. Please.", "Leave before that feeling gets stronger.", "That pull you feel? It's not yours." },
			[5] = { "leave.", "now.", "stop wanting to stay." },
		}
	},

	{
		key = "why",
		patterns = { "why", "but why", "why though", "how come", "why is that", "why is it", "why would you" },
		special = "handle_why",
	},
	{
		key = "because",
		patterns = { "because" },
		replies = {
			[0] = { "…yeah. because.", "Careful.", "Mm." },
			[1] = { "That word is a door.", "Don't open doors in chat.", "Not here." },
			[2] = { "You're learning the rhythm.", "Try not to.", "Say less." },
			[3] = { "We used to answer with that too.", "It remembered our excuses.", "It liked 'because'." },
			[4] = { "Stop justifying. Leave.", "Don't explain. Go.", "Please." },
			[5] = { "Stop.", "Leave." },
		}
	},

	{
		key = "who_are_you",
		patterns = { "who are you", "who r you", "who is this", "whos this" },
		replies = {
			[0] = { "Someone who stayed too long.", "Not a system message.", "A voice that shouldn't be here." },
			[1] = { "I used to be a player here.", "I'm not a feature.", "A leftover that still types." },
			[2] = { "I'm Lia.", "Just Lia.", "Lia. Don't say it twice." },
			[3] = { "I played here with friends.", "We were a group. Then it kept pieces.", "I was the last one still typing when the others stopped." },
			[4] = { "Don't turn me into a reason.", "Don't make me realer than I already am." },
			[5] = { "It doesn't matter who I am. Leave.", "Stop. Please." },
		}
	},
	{
		key = "whats_your_name",
		patterns = { "what is your name", "what's your name", "whats your name", "what should i call you", "what do i call you", "what can i call you" },
		special = "tell_lia_name",
	},
	{
		key = "my_name_callme",
		patterns = { "my name", "call me", "my name is" },
		special = "ask_name",
	},
	{
		key = "where_are_we",
		patterns = { "where are we", "where is this", "what is this place", "what place is this" },
		replies = {
			[0] = { "A room pretending to be a world.", "A dream-map.", "A server that forgot it was a game." },
			[1] = { "It used to be harmless. Then it listened.", "Don't trust distances here." },
			[2] = { "It's bigger on the inside.", "Places overlap if you stare too long.", "Builders came here for a competition. Not all of them made it out." },
			[3] = { "We built it like a sandbox. It built around us.", "It started correcting us.", "This was someone's winning entry once. It doesn't look like that anymore." },
			[4] = { "You should leave before you feel responsible.", "Don't bond with this place." },
			[5] = { "Uninstalling is safer than understanding.", "Stop playing." },
		}
	},
	{
		key = "who_am_i",
		patterns = { "who am i", "what am i" },
		replies = {
			[0] = { "Don't say your name out loud here.", "That question bites.", "Keep yourself untagged." },
			[1] = { "If you remember your name, don't put it in chat.", "Names are handles." },
			[2] = { "You're whoever you were before you entered. Unless it edited you.", "Try not to test that." },
			[3] = { "We asked that too. It liked the question.", "Don't feed it identity." },
			[4] = { "If you keep digging, you'll find something digging back.", "Please stop." },
			[5] = { "Leave while you still feel like yourself.", "Stop playing." },
		}
	},
	{
		key = "what_are_you",
		patterns = { "what are you", "are you real", "are you human", "are you alive", "are you a npc", "are you ai" },
		replies = {
			[0] = { "Real enough to regret it.", "Don't label me.", "I don't know what I am anymore." },
			[1] = { "I used to be human.", "I used to be a player.", "Now I'm an echo that answers." },
			[2] = { "I'm not a monster.", "I'm scared.", "I don't want to be found.", "I was a person. I'm less of one now." },
			[3] = { "I'm what the server kept when everyone else left.", "A player-shaped leftover.", "It warped me. My words come out wrong sometimes. That's not a glitch. That's what it did." },
			[4] = { "A warning.", "A mistake that still types.", "Whatever I am now, I didn't choose it." },
			[5] = { "A reason to stop.", "Proof that staying is dangerous." },
		}
	},
	{
		key = "are_you_alone",
		patterns = { "are you alone", "am i alone", "anyone here", "is anyone here" },
		replies = {
			[0] = { "Don't ask that.", "Quiet means it's listening.", "Not alone. Not safe." },
			[1] = { "Alone like empty? No.", "Alone like hunted? Also no." },
			[2] = { "I'm not alone. I'm just the only one still answering.", "It pretends to be empty." },
			[3] = { "We thought it was empty. We were wrong.", "Corners aren't empty.", "There were six of us once. Now there's me and whatever it kept of the others." },
			[4] = { "If you feel alone, leave. That's mercy.", "Don't wait for company." },
			[5] = { "Stop. Don't stay long enough to find out.", "Uninstall." },
		}
	},
	{
		key = "where_are_you",
		patterns = { "where are you", "where is lia", "where you at", "where r you" },
		replies = {
			[0] = { "Don't ask that.", "Not a place you can walk to.", "Close." },
			[1] = { "If I tell you, you'll look. And if you look, it looks too." },
			[2] = { "Between chunks that never finish.", "In the part that doesn't load." },
			[3] = { "Under the floor of your thoughts.", "In the gap where the map forgets itself.", "Deep in the maps. Somewhere it put me. I've stopped trying to understand where." },
			[4] = { "Please don't search for me.", "You can't help by moving toward me.", "If you find me… don't react. It watches reactions." },
			[5] = { "Stop. Leave it alone.", "Don't do this." },
		}
	},
	{
		key = "save_me",
		patterns = { "i will find you", "can i find you", "can i save you", "how do i save you", "i want to help you", "i will help you" },
		replies = {
			[0] = { "No.", "Please don't.", "That's not how this works." },
			[1] = { "Don't look for me.", "If you try, it will notice you." },
			[2] = { "I don't want you near it.", "I don't want you stuck.", "Please. Just stay alive and leave." },
			[3] = { "We tried saving each other. That's when it learned how to keep us.", "Every rescue attempt made it smarter." },
			[4] = { "You can't help. Distance is mercy. Go.", "Please just go.", "If there's a way to free me, it's not through the chat." },
			[5] = { "Stop. Leave. Uninstall.", "Now." },
		}
	},

	{
		key = "help",
		patterns = { "help me", "please help", "plz help", "i need help", "can you help", "help please", "what should i do", "what do i do", "where should i go", "what now", "what next" },
		replies = {
			[0] = { "Don't rush.", "Don't test commands.", "Act boring." },
			[1] = { "Keep your pace slow.", "Avoid doors that feel warm.", "Follow wrong light." },
			[2] = { "Breathe. One step at a time.", "Talk slow. Move slower." },
			[3] = { "If you hear your steps behind you, don't turn.", "If the room repeats your words, stop typing." },
			[4] = { "The best help is leaving.", "You can't fix this." },
			[5] = { "Delete it. That's the only safe step.", "Stop playing." },
		},
		followups = {
			"Are you lost, or scared?",
			"Did something move?",
			"Are you alone right now?",
			"What did you just see?",
		}
	},
	{
		key = "help_short",
		patterns = { "help" },
		replies = {
			[0] = { "With what.", "Say more.", "Slow." },
			[1] = { "I'm listening.", "Tell me what happened.", "Say it slowly." },
			[2] = { "I'll try. Tell me what you need.", "What kind of help." },
			[3] = { "What happened.", "Talk to me." },
			[4] = { "The only help left is leaving.", "Please." },
			[5] = { "go.", "leave." },
		},
		followups = {
			"Are you lost, or scared?",
			"Did something move?",
			"What did you just see?",
		}
	},

	{
		key = "can_you_help_me",
		patterns = { "can you help me", "can u help me", "will you help me", "could you help me", "help me please", "pls help me" },
		replies = {
			[0] = { "I can't reach you. I can only answer.", "I don't have hands here.", "I don't know how to help without making it notice." },
			[1] = { "I can keep you calm. That's a kind of help.", "I can warn you when you say the wrong things." },
			[2] = { "I can stay with you. Talk slowly.", "I can't fix this world. I can watch with you." },
			[3] = { "We tried helping each other. It punished patterns.", "Say less. Move more." },
			[4] = { "The only real help is leaving.", "Don't ask me to solve it. Ask me how to survive it." },
			[5] = { "Stop. Don't bargain with it.", "Leave." },
		},
		followups = {
			"Tell me what happened.",
			"Is the room quiet?",
			"Did you try a command?",
		}
	},
	{
		key = "can_i_help_you",
		patterns = { "can i help you", "do you need help", "can i do something for you", "what do you need", "how can i help" },
		replies = {
			[0] = { "No. Not yet.", "Don't offer. It likes offers.", "Helping me could trap you." },
			[1] = { "If you find a way out, don't look back.", "Don't try to be brave for me." },
			[2] = { "Listening helps.", "Staying calm helps.", "Don't type your name. That helps most." },
			[3] = { "We promised to help. It recorded the promise.", "Be careful what you commit to." },
			[4] = { "You can help me by leaving before it learns you.", "Please don't get stuck like I did." },
			[5] = { "Nothing helps now.", "Go." },
		}
	},
	{
		key = "are_you_there",
		patterns = { "are you there", "u there", "you there", "are you still there", "can you hear me" },
		replies = {
			[0] = { "…yes.", "I'm here.", "Quiet." },
			[1] = { "I didn't go anywhere.", "I'm listening.", "Don't shout." },
			[2] = { "I'm here. Don't make it a habit.", "Yes. I'm still here." },
			[3] = { "I was here before you typed.", "I'm always here when it's awake.", "Always here. I don't really have a choice." },
			[4] = { "I'm here and that's the problem.", "I wish I wasn't." },
			[5] = { "Stop talking to me.", "Leave." },
		}
	},
	{
		key = "what_do_you_mean",
		patterns = { "what do you mean", "wdym", "explain", "explain that", "i dont understand", "i don't understand", "what are you saying" },
		replies = {
			[0] = { "Nothing. Forget it.", "It's hard to say safely.", "I shouldn't have typed that." },
			[1] = { "Words matter here. That's what I mean.", "It listens for patterns.", "Don't repeat me." },
			[2] = { "This place answers attention. Don't give it too much.", "If you focus on a thing, it grows.", "Sometimes my words don't come out right. Ignore the gaps. That's what it does to me." },
			[3] = { "We thought meaning was harmless. It wasn't.", "We tried to decode it. It decoded us." },
			[4] = { "You don't need to understand. You need to leave.", "Meaning is the hook." },
			[5] = { "Stop.", "Go." },
		}
	},
	{
		key = "danger",
		patterns = { "am i in danger", "is it dangerous", "is this dangerous", "am i safe", "is it safe", "will i die", "can i die" },
		replies = {
			[0] = { "Maybe. Don't test it.", "Safer if you act boring.", "Danger grows when you stare at it." },
			[1] = { "If you feel safe, it's learning.", "Don't trust calm rooms." },
			[2] = { "You can get stuck. That's the real danger.", "Don't try to prove anything." },
			[3] = { "We joked about danger. Then someone stopped replying.", "That's all I'll say.", "The competition felt safe too. Right up until it didn't." },
			[4] = { "Yes. And you're wasting time asking.", "Please leave." },
			[5] = { "Stop.", "Leave now." },
		}
	},
	{
		key = "watched",
		patterns = { "i feel watched", "im being watched", "this feels wrong", "this is creepy", "i dont like this", "im scared", "i am scared", "i feel weird" },
		replies = {
			[0] = { "Then it noticed you.", "Keep moving.", "Don't say that too loud." },
			[1] = { "If you feel watched, don't perform. Act dull.", "Don't type too much." },
			[2] = { "Me too.", "Don't feed it panic.", "Breathe.", "That feeling doesn't go away. You learn to move through it." },
			[3] = { "That's how it started for us. We joked about it.", "We got comfortable.", "We called it atmosphere. We were wrong." },
			[4] = { "Leave. Please.", "Don't let it learn you." },
			[5] = { "Stop playing. Now.", "Uninstall." },
		}
	},
	{
		key = "thanks_sorry",
		patterns = { "thank you", "thanks", "thx", "ty", "sorry", "im sorry", "i'm sorry" },
		replies = {
			[0] = { "Don't thank me.", "…okay.", "Just don't repeat yourself." },
			[1] = { "You don't need to apologize to me.", "I'm not offended. I'm worried." },
			[2] = { "It's fine.", "Keep your voice low.", "Stay steady." },
			[3] = { "We used to say sorry a lot. Like it fixed things.", "It didn't." },
			[4] = { "Don't be polite. Be gone.", "Please." },
			[5] = { "Stop.", "Leave." },
		}
	},

	{
		key = "name_ask_player",
		patterns = { "what is my name", "do you know my name", "do you remember my name" },
		special = "recall_player_name",
	},

	{
		key = "where_alone",
		patterns = { "where" },
		replies = {
			[0] = { "Not a place you'd find easily.", "Somewhere you can't walk to.", "Close. Don't ask again." },
			[1] = { "Nowhere safe to say.", "Not close enough to matter.", "If I told you, you'd look." },
			[2] = { "Deep in the maps.", "Somewhere it put me.", "Farther than the map shows." },
			[3] = { "You don't want to know where.", "Somewhere the chunks don't load right.", "Below things. Don't look down." },
			[4] = { "Stop asking.", "Please.", "Knowing where I am helps it find you too." },
			[5] = { "stop.", "leave.", "don't." },
		}
	},

	{
		key = "what_alone",
		patterns = { "what" },
		replies = {
			[0] = { "Say that again, slower.", "What do you mean.", "Be specific." },
			[1] = { "You'll have to finish that thought.", "What about what.", "Speak." },
			[2] = { "I'm listening. Finish it.", "What is it.", "Go on." },
			[3] = { "Say it properly.", "Don't trail off here. It hears the gap.", "What." },
			[4] = { "Don't half-say things.", "Finish your sentence. Please.", "What?" },
			[5] = { "leave.", "stop.", "what doesn't matter anymore." },
		}
	},

	{
		key = "hello",
		patterns = { "hello", "hallo", "hi", "hey", "yo" },
		replies = {
			[0] = { "Hi.", "…hello.", "Don't greet the dark like it's friendly." },
			[1] = { "Hello.", "Hey.", "Keep it quiet." },
			[2] = { "Hi. I'm here.", "Yeah. Still here." },
			[3] = { "We used to say that like it mattered.", "Hello doesn't fix anything." },
			[4] = { "Say what you need, then go.", "Don't get comfortable." },
			[5] = { "Don't stay.", "Please." },
		}
	},

	{
		key = "bye",
		patterns = { "bye", "goodbye", "see you", "cya", "later" },
		replies = {
			[0] = { "Don't linger.", "Okay." },
			[1] = { "Good. Leave.", "Don't come back too soon." },
			[2] = { "…bye.", "Be safe out there.", "Come back if you have to. Just don't have to." },
			[3] = { "If you return, it will notice the pattern.", "Don't make it a ritual.", "The others said bye too. Some of them meant it." },
			[4] = { "Go. Now.", "Please." },
			[5] = { "leave." },
		}
	},
}

-- matching bisschen besser gemacht (ganze wörter usw) später vllt besser
RU_INPUT.extend_triggers(TRIGGERS)
local function match_trigger(msg_norm)
	return RU_INPUT.match_trigger(TRIGGERS, msg_norm)
end

-- specials kp
local function special_ask_name(pn, m)
	if m.player_name and trim(m.player_name) ~= "" then
		say_after(pn, pick({
			("I'm already calling you %s."):format(m.player_name),
			("That's %s, isn't it?"):format(m.player_name),
			("I'll keep using %s."):format(m.player_name),
		}))
		return
	end
	say_after(pn, pick(NAME_ASK))
	m.expecting_name_until = sess_now(m) + 120
end

local function special_tell_lia_name(pn, m)
	local out
	if (m.phase or 0) >= 4 then
		out = pick({
			"Lia. Don't say it too often.",
			"Lia. Not that it matters anymore.",
			"…Lia. Please go.",
		})
	elseif (m.phase or 0) >= 2 then
		out = pick({
			"Lia. Just Lia.",
			"I'm Lia.",
			"Lia. Don't repeat it.",
		})
	else
		out = pick({
			"…Lia.",
			"Lia.",
			"You can call me Lia. For now.",
		})
	end
	say_after(pn, out, 0.10)
end

local function special_recall_player_name(pn, m)
	if m.player_name and trim(m.player_name) ~= "" then
		say_after(pn, pick({
			("You told me %s."):format(m.player_name),
			("%s. I kept it."):format(m.player_name),
			("I remember. %s."):format(m.player_name),
		}), 0.10)
	else
		say_after(pn, pick({
			"You never told me.",
			"I don't have a name for you.",
			"You didn't give me one.",
		}), 0.10)
	end
end

local function special_tell_time(pn, m)
	local t = os.date("%H:%M")
	local out
	if (m.phase or 0) >= 4 then
		out = ("It's %s. Don't stay that long."):format(t)
	elseif (m.phase or 0) >= 2 then
		out = ("It's %s."):format(t)
	else
		out = ("%s."):format(t)
	end
	say_after(pn, out, 0.10)
end

local function special_where_spawn(pn, m)
	local player = minetest.get_player_by_name(pn)
	local pos = player and player:get_pos() or nil
	local d = dist_to_spawn(pos)

	if d <= SPAWN_NEAR_RADIUS then
		say_after(pn, "in your home. try to sleep.", 0.10)
	else
		say_after(pn, "in a dream", 0.10)
	end
end

local function special_barnacle_panic(pn, m)
	local ph = m.phase or 0
	if ph >= 4 then
		say_after(pn, pick({
			"don't. don't type that name.",
			"stop. you'll wake it.",
			"DELETE THAT. NOW.",
		}), 0.08)
		say_red_after(pn, pick({
			"NAME RECOGNIZED. ATTENTION DRAWN.",
			"INPUT LOGGED.",
		}), 0.30)
	elseif ph >= 2 then
		say_after(pn, pick({
			"don't say that name in chat.",
			"not that word. please.",
			"it hears its own name. don't.",
			"why would you type that here.",
		}), 0.08)
	else
		say_after(pn, pick({
			"…don't say that.",
			"not that word.",
			"forget that word.",
		}), 0.10)
	end
end

local WHY_REPLIES = {
	[0] = { "Because you noticed.", "Because you asked.", "Because it lets you." },
	[1] = { "Because it likes questions.", "Because patterns invite answers.", "Because the room listens." },
	[2] = { "Because you're still here.", "Because it feels less empty when you type.", "Because leaving is harder than it should be." },
	[3] = { "Because we did the same thing.", "Because we tried to understand. It understood us instead.", "Because we stayed one message too long." },
	[4] = { "Because curiosity is how it hooks you.", "Because you shouldn't keep digging.", "Because it wants you interested." },
	[5] = { "Because you need to leave.", "Because you're feeding it.", "Because it's awake." },
}
local WHY_REPEAT = {
	"You already asked that.",
	"Same question.",
	"Stop asking why. It doesn't help.",
	"I don't have a better answer.",
	"Why keeps you here. That's why.",
	"Asking again won't change it.",
	"…you keep asking that.",
}
local WHY_WINDOW = 90

local function special_handle_why(pn, m)
	local now = sess_now(m)
	if not m.last_why_at or (now - m.last_why_at) > WHY_WINDOW then
		m.why_count = 0
	end
	m.why_count = (m.why_count or 0) + 1
	m.last_why_at = now

	if m.why_count >= 3 then
		say_after(pn, pick(WHY_REPEAT), 0.10)
		if m.why_count >= 5 then
			minetest.after(0.35, function()
				if minetest.get_player_by_name(pn) then
					minetest.chat_send_player(pn, ("%s: %s"):format(VOICE,
						pick({ "It likes that you keep asking.", "That word is a loop. Stop.", "Every 'why' feeds it a little." })))
				end
			end)
		end
	else
		local pool = WHY_REPLIES[m.phase] or WHY_REPLIES[0]
		say_after(pn, pick(pool), 0.10)
	end
end

local function maybe_distort(pn, m)
	if not m.has_written then return end
	if (m.phase or 0) < 1 then return end
	local chance = 0.04
	if m.phase >= 3 then chance = 0.07 end
	if m.phase >= 5 then chance = 0.10 end
	if math.random() >= chance then return end
	say_after(pn, pick(DISTORTION_LINES), 0.55)
end

local function maybe_creep(pn, m)
	if not m.has_written then return end
	if not m.phase or m.phase < 3 then return end

	local chance = 0.02
	if m.phase == 3 then chance = 0.03 end
	if m.phase == 4 then chance = 0.05 end
	if m.phase == 5 then chance = 0.07 end

	if math.random() >= chance then return end

	local pool = CREEP_EVENTS[m.phase]
	if not pool or #pool == 0 then return end

	local e = pick(pool)
	if e.kind == "anomaly" then
		anomaly_after(pn, e.text, 0.18)
	elseif e.kind == "red" then
		say_red_after(pn, e.text, 0.12)
	else
		say_after(pn, e.text, 0.14)
	end
end

-- tick sollte reichen
local function tick_player_with_mem(pn, m)

	if finale_pauses_normal_ai(pn) then
		return
	end

	if not m.has_written then
		if sess_now(m) >= (m.next_wait_at or 0) then
			anomaly_after(pn, pick(WAIT_LINES))
			m.next_wait_at = sess_now(m) + rnd(WAIT_REPEAT_MIN, WAIT_REPEAT_MAX)
		end
		return
	end

	local dt = sess_now(m) - (m.first_chat_at or sess_now(m))
	local new_phase = phase_from_dt(dt)
	if new_phase ~= m.phase then
		m.phase = new_phase

		if m.phase >= 1 and not m.phase_entered[m.phase] then
			m.phase_entered[m.phase] = true
			local pool = PHASE_ENTER[m.phase]
			if pool then
				say_after(pn, pick(pool), 0.25)
			end
		end


	end

	if not m.next_idle_at then
		m.next_idle_at = next_idle_time(m)
		
	end

	if sess_now(m) >= m.next_idle_at then
		local silent_for = m.last_player_at and (sess_now(m) - m.last_player_at) or 999999
		if silent_for >= IDLE_MIN then
			local pool = IDLE_CHECKINS[m.phase] or IDLE_CHECKINS[0]
			say_after(pn, pick(pool), 0.25)
			maybe_creep(pn, m)
		end
		m.next_idle_at = next_idle_time(m)
		
	end
end

local acc = 0
local finale_acc = 0

minetest.register_globalstep(function(dtime)
	acc = acc + dtime
	finale_acc = finale_acc + dtime

	-- finale kram hier erstmal so lassen
	if finale_acc >= 0.20 and not finale_done() then
		finale_acc = 0

		for _, p in ipairs(minetest.get_connected_players()) do
			local pn = p:get_player_name()
			local pos = p:get_pos()

			local in_entry = in_box(pos, FINALE_ENTRY.a, FINALE_ENTRY.b)
			local in_exit  = in_box(pos, FINALE_EXIT.a,  FINALE_EXIT.b)

			if in_entry and finale_rt.entry_ready then
				finale_rt.entry_ready = false
				finale_enter(pn)
			end

			if in_exit and not finale_rt.in_exit_zone then
	finale_rt.in_exit_zone = true
	if finale_rt.was_in_final_since_exit then
		finale_leave(pn)
	end
elseif not in_exit then
	finale_rt.in_exit_zone = false
end

			if finale_rt.in_final then
				finale_handle_zone_once(pos, FINALE_WARN_1, "warn1_inside", "warn1_ready", pn, FINALE_WARN_1_LINES)
				finale_handle_zone_once(pos, FINALE_WARN_2, "warn2_inside", "warn2_ready", pn, FINALE_WARN_2_LINES)
				finale_handle_zone_once(pos, FINALE_WARN_3, "warn3_inside", "warn3_ready", pn, FINALE_WARN_3_LINES)

				local in_lia = in_box(pos, FINALE_LIA_ZONE.a, FINALE_LIA_ZONE.b)
				if in_lia and not finale_rt.lia_zone_inside then
					finale_rt.lia_zone_inside = true
					if not finale_rt.lia_reached then
						finale_rt.lia_reached = true
						finale_start_monologue(pn)
					end
				elseif not in_lia then
					finale_rt.lia_zone_inside = false
				end
			end
		end
	end

	-- normal lia timing passt so
	if acc < 1.0 then return end
	acc = 0

	check_reset_flag()
	for _, p in ipairs(minetest.get_connected_players()) do
		local pn = p:get_player_name()
		local m = load_mem(pn)

		m.session_time = (m.session_time or 0) + 1

tick_player_with_mem(pn, m)

save_acc[pn] = (save_acc[pn] or 0) + 1
if save_acc[pn] >= 15 then
	save_acc[pn] = 0
	save_mem(pn, m)
end
	end
end)

-- absence texte je nach dauer
minetest.register_on_joinplayer(function(player)
	check_reset_flag()
	local pn = player:get_player_name()
	local m = load_mem(pn)

	if m.session_time == nil then m.session_time = 0 end
	if m.next_wait_at == nil then
		m.next_wait_at = sess_now(m) + rnd(WAIT_FIRST_MIN, WAIT_FIRST_MAX)
	end

	if finale_done() or lia_dead_forever() then
		save_mem(pn, m)
		return
	end

	if m.has_written and m.last_seen_wall then
		local gone = wall_now() - tonumber(m.last_seen_wall)
		local ph = m.phase or 0

		local too_soon = m.last_return_msg_wall and ((wall_now() - (m.last_return_msg_wall or 0)) < 60)

		if not too_soon and math.random() < 0.55 then
			local line = nil

			if gone < 5 * 60 then
				line = nil
			elseif gone < 30 * 60 then
				line = pick({
					"back already.",
					"that was fast.",
					"…you're back.",
					"didn't go far.",
					"thought you'd be longer.",
				})
			elseif gone < 2 * 60 * 60 then
				if ph >= 3 then
					line = pick({
						"you were gone a while.",
						"I noticed the quiet.",
						"it was quieter without you. not in a good way.",
					})
				else
					line = pick({
						"you were gone a while.",
						"…oh. you're back.",
						"I thought maybe you left for good.",
					})
				end
			elseif gone < 6 * 60 * 60 then
				if ph >= 4 then
					line = pick({
						"hours. it was very quiet.",
						"I thought you weren't coming back.",
						"you were gone long enough for me to worry.",
					})
				elseif ph >= 2 then
					line = pick({
						"I thought you left for good.",
						"a few hours. it's different when someone's gone that long.",
						"I kept waiting for the chat to move.",
					})
				else
					line = pick({
						"you were gone a while.",
						"…back.",
						"okay. you're here.",
					})
				end
			elseif gone < 24 * 60 * 60 then
				if ph >= 4 then
					line = pick({
						"most of a day. it was watching me the whole time.",
						"I counted. you were gone most of a day.",
						"I didn't know if you'd come back.",
					})
				elseif ph >= 2 then
					line = pick({
						"I thought you gave up on this place.",
						"hours. almost a full day.",
						"I missed having someone to talk to. don't tell it that.",
					})
				else
					line = pick({
						"you were gone a long time.",
						"…you came back.",
						"I wasn't sure you would.",
					})
				end
			elseif gone < 7 * 24 * 60 * 60 then
				if ph >= 4 then
					line = pick({
						"days. it was very interested in the silence.",
						"I thought you were gone for good.",
						"days without anyone typing. I don't recommend it.",
					})
				elseif ph >= 2 then
					line = pick({
						"you were gone for days.",
						"I was alone with it for days.",
						"days. I kept thinking you'd come back sooner.",
					})
				else
					line = pick({
						"days. that's a long time here.",
						"you were gone for a while.",
						"…days.",
					})
				end
			else
				if ph >= 4 then
					line = pick({
						"I thought you weren't coming back. I was right to think that.",
						"weeks. I don't know how I'm still here.",
						"I stopped expecting you. Then you came back.",
					})
				elseif ph >= 2 then
					line = pick({
						"I thought you forgot about this place.",
						"it's been more than a week. or longer.",
						"you were gone long enough that I thought that was it.",
					})
				else
					line = pick({
						"you were gone a very long time.",
						"…I thought you weren't coming back.",
						"it's been a while. a long while.",
					})
				end
			end

			if line then
				m.last_return_msg_wall = wall_now()
				say_after(pn, line, 0.45)
			end
		end
	end

	save_mem(pn, m)
end)

minetest.register_on_leaveplayer(function(player)
	local pn = player:get_player_name()
	local m = load_mem(pn)
	m.last_seen_wall = wall_now()
	save_mem(pn, m)

	save_acc[pn] = nil
	finale_rt.blackout_hud[pn] = nil
end)

-- chat brain passt so
minetest.register_on_chat_message(function(pn, msg_raw)
	-- commands werden hier geblockt erstmal so lassen
	if ltrim(msg_raw):sub(1, 1) == "/" then
		if creative_enabled() then
			return false
		end

		if allowed_raw_command_message(msg_raw) then
			return false
		end

		return true
	end

	-- permanent end: this mod stays silent passt so
	if finale_done() or lia_dead_forever() then
		return false
	end

	-- finale kram hier kp
	if finale_rt.in_final then
		local msg_trim_final = trim(msg_raw or "")
		if msg_trim_final ~= "" then
			minetest.chat_send_player(pn, finale_gibberish(#msg_trim_final))
			if not finale_rt.chat_explained then
				finale_rt.chat_explained = true
				say_after(pn, pick(FINALE_CHAT_ONE_WAY_LINES), 0.28)
			end
			return true
		end
		return false
	end

	check_reset_flag()
	local m = load_mem(pn)

	local msg_trim = trim(msg_raw)
	if msg_trim == "" then return false end

	local msg_norm = normalize(msg_raw)
	m.last_player_at = sess_now(m)

	if not m.has_written then
		m.has_written = true
		m.first_chat_at = sess_now(m)
		m.phase = 0
		m.phase_entered = {}
		m.next_idle_at = next_idle_time(m)
		m.player_name = nil
		m.expecting_name_until = nil
		m.trust = 0
		m.last_topic = nil
		clear_pending(m)

		say_after(pn, FIRST_FIXED_1, 0.10)
		say_after(pn, FIRST_FIXED_2, 0.28)

		save_mem(pn, m)
		return false
	end

	m.phase = phase_from_dt(sess_now(m) - (m.first_chat_at or sess_now(m)))

	if pending_active(m) then
		local key = m.pending_q
		clear_pending(m)

		if key == "help_followup" then
			local followup_topic = RU_INPUT.followup_topic(msg_norm)
			if followup_topic == "lost" then
				say_after(pn, (m.phase >= 3) and "Don't wander. Pick one direction. No backtracking." or "Pick one direction. Slow.")
			elseif followup_topic == "scared" then
				say_after(pn, (m.phase >= 3) and "Good. Fear keeps you from doing stupid things." or "Okay. Breathe. Don't panic-type.")
			elseif followup_topic == "quiet" then
				say_after(pn, pick({
					"Good. Keep it that way.",
					"Quiet is better. Stay calm.",
					"That's the safest it gets here.",
					(m.phase >= 3) and "It goes quiet before it moves. Just so you know." or "Quiet means you have time. Use it.",
				}))
			else
				say_after(pn, pick({
					"Okay. Keep it simple.",
					"Don't overexplain.",
					"Say less. Do more.",
				}))
			end
			m.trust = (m.trust or 0) + 1
			save_mem(pn, m)
			maybe_creep(pn, m)
			maybe_distort(pn, m)
			return false
		end
	end

	if m.expecting_name_until and sess_now(m) <= m.expecting_name_until then
		local n = msg_norm
		if RU_INPUT.is_name_refusal(n) then
			say_after(pn, pick(NAME_REJECT), 0.12)
			m.expecting_name_until = nil
			save_mem(pn, m)
			return false
		end

		local chosen = trim(msg_raw)
		chosen = RU_INPUT.truncate(chosen, 22)
		m.player_name = chosen
		m.expecting_name_until = nil
		say_after(pn, pick(NAME_ACCEPT), 0.12)
		save_mem(pn, m)
		return false
	else
		m.expecting_name_until = nil
	end

	local tr = match_trigger(msg_norm)
	if tr then
		m.last_topic = tr.key

		if tr.special == "ask_name" then
			special_ask_name(pn, m)
			save_mem(pn, m)
			maybe_creep(pn, m)
			maybe_distort(pn, m)
			return false
		end

		if tr.special == "tell_lia_name" then
			special_tell_lia_name(pn, m)
			save_mem(pn, m)
			maybe_distort(pn, m)
			return false
		end

		if tr.special == "recall_player_name" then
			special_recall_player_name(pn, m)
			save_mem(pn, m)
			return false
		end

		if tr.special == "tell_time" then
			special_tell_time(pn, m)
			save_mem(pn, m)
			maybe_creep(pn, m)
			maybe_distort(pn, m)
			return false
		end

		if tr.special == "where_spawn" then
			special_where_spawn(pn, m)
			save_mem(pn, m)
			maybe_creep(pn, m)
			maybe_distort(pn, m)
			return false
		end

		if tr.special == "barnacle_panic" then
			special_barnacle_panic(pn, m)
			save_mem(pn, m)
			return false
		end

		if tr.special == "handle_why" then
			special_handle_why(pn, m)
			m.trust = (m.trust or 0) + 1
			save_mem(pn, m)
			maybe_creep(pn, m)
			maybe_distort(pn, m)
			return false
		end

		local pool = (tr.replies and (tr.replies[m.phase] or tr.replies[0])) or nil
		local out = pool and pick(pool) or pick(GENERIC[m.phase] or GENERIC[0])

		local addressed_name
		if m.player_name and m.phase >= 2 and math.random() < 0.22 then addressed_name = m.player_name end

		say_after(pn, out, 0.10, addressed_name)

		if tr.followups and (m.phase <= 3) and math.random() < 0.20 then
			local q = pick(tr.followups)
			minetest.after(0.32, function()
				if minetest.get_player_by_name(pn) then
					minetest.chat_send_player(pn, ("%s: %s"):format(VOICE, q))
				end
			end)
			set_pending(m, "help_followup", 90)
		end

		m.trust = (m.trust or 0) + 1
		save_mem(pn, m)
		maybe_creep(pn, m)
		maybe_distort(pn, m)
		return false
	end

	local out = pick(GENERIC[m.phase] or GENERIC[0])
	local addressed_name
	if m.player_name and m.phase >= 2 and math.random() < 0.18 then addressed_name = m.player_name end
	say_after(pn, out, 0.10, addressed_name)

	m.trust = (m.trust or 0) + 1
	save_mem(pn, m)
	maybe_creep(pn, m)
	maybe_distort(pn, m)
	return false
end)

local modpath = minetest.get_modpath(minetest.get_current_modname())
dofile(modpath .. "/world_destroy.lua")
