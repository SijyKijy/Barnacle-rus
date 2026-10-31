local modpath = assert(arg and arg[1], "Pass the barnacle_ru mod directory as arg[1]")
local language, time = "en", 0
local window = {size = {x = 800, y = 600}, real_hud_scaling = 1}
local calls = 0
local settings = {font_size = "16", mono_font_size = "16", recent_chat_messages = "6"}
minetest = {
	get_us_time = function() return time * 1000000 end,
	settings = {get = function(_, key) return settings[key] end},
	get_player_window_information = function() return window end,
	chat_send_player = function() error("Recent HUD must not replay native chat") end,
	chat_send_all = function() error("Recent HUD must not replay native chat") end,
}
local originals = {}
function originals.hud_add(player, definition)
	calls = calls + 1
	player.next_id = player.next_id + 1
	player.huds[player.next_id] = definition
	return player.next_id
end
function originals.hud_change(player, id, key, value)
	calls = calls + 1
	assert(player.huds[id], "Changing a removed HUD")
	player.huds[id][key] = value
end
function originals.hud_remove(player, id)
	calls = calls + 1
	player.huds[id] = nil
end
local player = {next_id = 0, huds = {}, flags = {chat = true, hotbar = true}}
function player:get_player_name() return "tester" end
function player:hud_get_flags() return self.flags end
function player:hud_set_flags(flags) for key, value in pairs(flags) do self.flags[key] = value end end
local api = {
	get_language = function() return language end,
	hud_style = function(style) return language == "ru" and style + 4 or style end,
	originals = function() return originals end,
	translate_message = function(text, target_language)
		if text:match("^<[^>]+>") then return text end
		return (target_language or language) == "ru" and text == "Hello" and "Привет" or text
	end,
}
local recent = dofile(modpath .. "/recent_chat.lua")(api)
local function rows()
	local result = {}
	for _, definition in pairs(player.huds) do result[#result + 1] = definition end
	table.sort(result, function(a, b) return a.offset.y < b.offset.y end)
	return result
end
local function visible()
	local result = {}
	for _, definition in ipairs(rows()) do result[#result + 1] = definition.text end
	return table.concat(result, "\n")
end
assert(recent.join(player) and player.flags.chat == false and player.flags.hotbar == true)
recent.push("tester", "Hello")
assert(visible() == "Hello" and rows()[1].style == 0)
time = 59; language = "ru"; recent.refresh()
assert(visible() == "Hello\nПривет" and rows()[1].style == 0 and rows()[2].style == 4,
	"The existing original must remain above its Russian translation, with separate fonts")
language = "en"; recent.refresh()
assert(visible() == "Hello" and rows()[1].style == 0, "English mode must hide the extra translation")
language = "ru"; recent.refresh()
time = 60; recent.step()
assert(visible() == "", "Toggle must not extend the original 60-second lifetime")
time = 70
recent.push("tester", "<tester> Hello")
assert(visible() == "<tester> Hello", "Player text must use translate_message unchanged")
recent.push("tester", "one\ntwo")
assert(visible():find("one\ntwo", 1, true), "Preserve explicit line breaks")
local previous_calls = calls
recent.step(); assert(calls == previous_calls, "Do not redraw an unchanged viewport")
window = {size = {x = 180, y = 500}, real_hud_scaling = 1}
recent.step()
assert(calls > previous_calls, "Resizing must recalculate wrapping")
recent.leave(player); recent.join(player)
local colored = "\27(c@#ff0000)абвгдеёжзийклмнопрстуфхцчшщъыьэюя\27(c@#ffffff)"
recent.push("tester", colored)
local joined = visible():gsub("\27%b()", ""):gsub("\n", "")
assert(joined == "абвгдеёжзийклмнопрстуфхцчшщъыьэюя", "Wrapping must preserve all UTF-8 characters")
for _, row in ipairs(rows()) do
	local plain = row.text:gsub("\27%b()", "")
	local count = 0
	for first in plain:gmatch(".") do
		local byte = first:byte()
		if byte < 128 or byte >= 192 then count = count + 1 end
	end
	assert(count <= 9, "Colors take zero columns and a long word must wrap")
	assert(row.offset.y + 30 <= window.size.y * 0.28 + 1, "Keep recent text in the top 28%")
end
recent.leave(player); recent.join(player)
window = {size = {x = 800, y = 1200}, real_hud_scaling = 1}
for index = 1, 8 do recent.push("tester", "message " .. index) end
assert(not visible():find("message 1", 1, true) and not visible():find("message 2", 1, true))
assert(visible():find("message 3", 1, true) and visible():find("message 8", 1, true))
window = nil
recent.step(); assert(#rows() > 0, "Use a conservative fallback without window information")
window = {size = {x = 80, y = 80}, real_hud_scaling = 1}
recent.step(); assert(#rows() == 0, "Hide the visible buffer when no line can fit; console history is unaffected")
recent.leave(player)
assert(player.flags.chat == true and next(player.huds) == nil)

language, time = "ru", 100
window = {size = {x = 800, y = 1200}, real_hud_scaling = 1}
recent.join(player)
assert(not recent.dismiss_oldest("tester"), "An empty recent buffer is safe")
recent.push("tester", "Hello")
recent.push("tester", "newer")
assert(recent.dismiss_oldest("tester"))
assert(visible() == "newer", "Remove the original and its translation together")
assert(recent.dismiss_oldest("tester") and visible() == "")
assert(not recent.dismiss_oldest("tester") and not recent.dismiss_oldest("offline"))
language = "en"
window = {size = {x = 800, y = 400}, real_hud_scaling = 1}
for index = 1, 6 do recent.push("tester", "old " .. index) end
assert(visible() == "old 4\nold 5\nold 6")
assert(recent.dismiss_oldest("tester"))
assert(visible() == "old 5\nold 6", "Dismiss the oldest visible message without resurrecting the hidden prefix")
time = 161
assert(not recent.dismiss_oldest("tester") and visible() == "", "Expire old entries before dismissing")
recent.leave(player)
print("recent chat checks passed")
language, time = "ru", 200
window = {size = {x = 800, y = 800}, real_hud_scaling = 1, real_gui_scaling = 2}
recent.join(player)
recent.push("tester", "one\ntwo")
assert(rows()[2].offset.y - rows()[1].offset.y >= 56, "Font line spacing must use GUI scaling")
window.real_hud_scaling = 2
recent.step()
assert((rows()[2].offset.y - rows()[1].offset.y) * 2 >= 56, "HUD offsets must compensate their separate scale")
recent.leave(player); recent.join(player)
recent.push("tester", "Hello", {verbatim = true})
assert(visible() == "Hello", "Player-origin text stays verbatim with a custom native formatter")
recent.leave(player)
