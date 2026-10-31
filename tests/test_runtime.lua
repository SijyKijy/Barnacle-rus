local modpath = assert(arg and arg[1], "Pass the barnacle_ru mod directory as arg[1]")
local dictionary = {
	["%s. Kept."] = "%s. Сохранено.",
	["Hello"] = "Привет", ["Long note.\nNext line."] = "Длинная записка.\nСледующая строка.",
	["Long note."] = "Короткая записка.", ["Next line."] = "Другая строка.",
	["No"] = "Нет", ["Locked"] = "Заперто", ["Lia"] = "Лия",
	["A"] = "B", ["B"] = "C", ["Hello; world]"] = "Привет; мир]",
	["Found %d notes for %s (100%%)."] = "Найдено записок: %d. Игрок: %s (100%%).",
	["Scale: %0.2f"] = "Масштаб: %0.2f", ["%ds"] = "%d с",
	["button_exit[0,0;1,1;close;Close]"] = "button_exit[0,0;1,1;close;Закрыть]",
}
local callbacks, players, chat, shown, stored = {}, {}, {}, {}, {}
local field_callbacks = {}
local function register(name)
	return function(callback) callbacks[name] = callback end
end
local function escape(text)
	return (text:gsub("([\\%[%];,])", "\\%1"))
end
minetest = {
	get_current_modname = function() return "barnacle_ru" end,
	get_modpath = function() return modpath end,
	get_worldpath = function() return modpath .. "/mock-world" end,
	get_us_time = function() return 0 end,
	get_mod_storage = function() return {
		get_string = function(_, key) return stored[key] or "" end,
		set_string = function(_, key, value) stored[key] = value end,
	} end,
	formspec_escape = escape,
	show_formspec = function(name, formname, spec) shown[name] = {name = formname, spec = spec} end,
	close_formspec = function(name) shown[name] = nil end,
	chat_send_player = function(name, text) chat[#chat + 1] = text end,
	chat_send_all = function(text) chat[#chat + 1] = text end,
	format_chat_message = function(name, message) return name .. ": " .. message end,
	get_connected_players = function() return players end,
	get_meta = function() return {} end,
	get_translated_string = function(selected, text)
		if text == "\27(T@default)Empty Bookshelf\27E" then
			return selected == "ru" and "Пустая книжная полка" or "Empty Bookshelf"
		end
		return text
	end,
	register_on_joinplayer = register("join"), register_on_leaveplayer = register("leave"),
	register_on_player_receive_fields = function(callback)
		field_callbacks[#field_callbacks + 1] = callback
		callbacks.fields = function(...)
			for i = #field_callbacks, 1, -1 do
				if field_callbacks[i](...) then return true end
			end
			return false
		end
	end,
	register_globalstep = register("step"),
	register_on_mods_loaded = register("loaded"),
	register_lbm = function() end,
	register_chatcommand = function(name, definition) callbacks.command = definition.func end,
	registered_items = {["barnacle_items:test"] = {description = "Locked"}},
	override_item = function(name, definition) minetest.registered_items[name].description = definition.description end,
}
local original_dofile = dofile
dofile = function(path)
	if path == modpath .. "/dictionary.lua" then return dictionary end
	if path == modpath .. "/nodenames.lua" then return {} end
	if path == modpath .. "/metadata_sources.lua" then return {} end
	return original_dofile(path)
end
original_dofile(modpath .. "/init.lua")
dofile = original_dofile
local T = barnacle_ru.translate
assert(T("Hello") == "Привет")
assert(T("Lia: Hello") == "Лия: Привет")
assert(T("Prefix Long note.\nNext line. Suffix") == "Prefix Длинная записка.\nСледующая строка. Suffix")
assert(T("No Nobody No!") == "Нет Nobody Нет!")
assert(T("КиноNo") == "КиноNo")
assert(T("A B") == "B C", "Replacement must not cascade")
assert(T("Found 007 notes for Hello (100%).") == "Найдено записок: 007. Игрок: Hello (100%).")
assert(T("Lia: Found 12 notes for A B (100%).") == "Лия: Найдено записок: 12. Игрок: A B (100%).")
assert(T("Scale: 1.20") == "Масштаб: 1.20")
assert(T("Time 12s.") == "Time 12 с.")
assert(T("\27(c@#fff)Hello\27(c@#000)") == "\27(c@#fff)Привет\27(c@#000)")
assert(T("\27(T@default)Empty Bookshelf\27E") == "Пустая книжная полка")
assert(T("\27(T@default)Empty Bookshelf\27E", "en") == "Empty Bookshelf")
local form = "formspec_version[4]size[8,5]button[0,0;1,1;Hello;Hello]"
	.. "field[0,1;2,1;Locked;Hello;Hello]label[0,2;Hello\\; world\\]]"
	.. "hypertext[0,3;2,1;Hello;<style color=Hello>Hello</style>]"
	.. "image[0,0;1,1;Hello.png]tooltip[Hello;Hello]"
local translated = barnacle_ru.translate_formspec(form, false)
assert(translated:find("button[0,0;1,1;Hello;Привет]", 1, true))
assert(translated:find("field[0,1;2,1;Locked;Привет;Hello]", 1, true), "Player input and field IDs must remain original")
assert(translated:find("label[0,2;Привет\\; мир\\]]", 1, true))
assert(translated:find("<style color=Hello>Привет</style>", 1, true))
assert(translated:find("image[0,0;1,1;Hello.png]", 1, true))
assert(translated:find("tooltip[Hello;Привет]", 1, true))
assert(translated:find("formspec_version[4]size[8,5]style_type[label;font=mono]", 1, true))
assert(translated:find("<style font=mono>", 1, true))
local geometry = "formspec_version[6]size[8,7]position[0.5,0.5]anchor[0.5,0.5]padding[0.1,0.1]no_prepend[]"
for _, selected in ipairs({"ru", "en"}) do
	local result = barnacle_ru.translate_formspec(geometry .. "bgcolor[#00000000;false]label[0,0;Hello]", true, selected)
	assert(result:sub(1, #geometry) == geometry, "Styles must not interrupt the geometry preamble")
	assert(result:find("style_type[", 1, true) > result:find("padding[", 1, true))
	assert(result:find("style_type[", 1, true) < result:find("label[0,0;", 1, true))
end
assert(barnacle_ru.translate_formspec("", true) == "", "Closing a form must remain an empty formspec")
local controls = barnacle_ru.translate_formspec("formspec_version[4]size[8,5.25]label[3.35,0.55;Hello]", true)
assert(controls:find("button[6.00,0.10;1.80,0.55;barnacle_ru_toggle;RU / EN]", 1, true),
	"The language selector must leave room for the centered heading on small forms")
local controls_buttons = barnacle_ru.translate_formspec("formspec_version[4]size[8,5.25]button_exit[2.75,4.45;2.5,0.7;btn_ctrl_back;Back]", true)
assert(controls_buttons:find("button[5.60,4.45;2.20,0.55;barnacle_ru_dismiss_oldest;", 1, true),
	"The dismiss control must stay beside Back and below the instruction lines")
local pause_buttons = barnacle_ru.translate_formspec("formspec_version[4]size[8,5.25]button[0.5,0.9;7,0.9;btn_pause_resume;Resume]", true)
assert(pause_buttons:find("button[3.60,0.10;2.20,0.55;barnacle_ru_dismiss_oldest;", 1, true),
	"The dismiss control must stay above the full-width Resume button")
assert(barnacle_ru.translate_formspec("button_exit[0,0;1,1;close;Close]", false)
	:find("button_exit[0,0;1,1;close;Закрыть]", 1, true))
local methods = {}
function methods:get_player_name() return "tester" end
function methods:get_player_control() return self.controls end
function methods:hud_get_flags() return self.flags end
function methods:hud_set_flags(flags) for key, value in pairs(flags) do self.flags[key] = value end end
function methods:hud_add(definition)
	self.next_id = self.next_id + 1; self.huds[self.next_id] = definition; return self.next_id
end
function methods:hud_change(id, stat, value) self.huds[id][stat] = value end
function methods:hud_remove(id) self.huds[id] = nil end
function methods:set_inventory_formspec(spec) self.inventory_formspec = spec end
local player = setmetatable({next_id = 0, huds = {}, controls = {}, flags = {chat = true}}, {__index = methods, __metatable = methods})
players[1] = player
callbacks.join(player)
callbacks.join(player)
local swallowed_toggles = 0
minetest.register_on_player_receive_fields(function(_, _, fields)
	if fields.barnacle_ru_toggle then swallowed_toggles = swallowed_toggles + 1; return true end
	return false
end)
callbacks.loaded()
assert(minetest.registered_items["barnacle_items:test"].description == "Заперто")
local hud_id = player:hud_add({hud_elem_type = "text", text = "Hello"})
local image_id = player:hud_add({hud_elem_type = "image", text = "Hello"})
assert(player.huds[hud_id].text == "Привет" and player.huds[image_id].text == "Hello")
assert(player.huds[hud_id].style == 4 and player.huds[image_id].style == nil)
local bold_id = player:hud_add({hud_elem_type = "text", text = "Hello", style = 1})
assert(player.huds[bold_id].style == 5, "Russian font must preserve the bold bit")
minetest.chat_send_all("<tester> Hello")
minetest.chat_send_player("tester", "<tester> Hello")
minetest.chat_send_player("tester", "Lia: Hello")
assert(chat[1] == "<tester> Hello" and chat[2] == "<tester> Hello" and chat[3] == "Лия: Привет")
minetest.chat_send_player("tester", "Lia: Alex. Kept.")
assert(chat[4] == "Лия: Alex. Сохранено.", "A leading template capture must not swallow the speaker prefix")
player:set_inventory_formspec(form)
minetest.show_formspec("tester", "original_form_id", form)
assert(shown.tester.spec:find("barnacle_ru_toggle", 1, true))
local chat_count = #chat
assert(callbacks.fields(player, "original_form_id", {barnacle_ru_toggle = true}) == true)
assert(barnacle_ru.get_language() == "en" and stored.language == "en")
assert(swallowed_toggles == 0, "The localization button must run before the game's menu handler")
assert(T("\27(T@default)Empty Bookshelf\27E") == "Empty Bookshelf")
assert(player.huds[hud_id].text == "Hello")
assert(player.huds[hud_id].style == 0 and player.huds[bold_id].style == 1)
assert(shown.tester.name == "original_form_id" and shown.tester.spec:find(";Hello]", 1, true))
assert(shown.tester.spec:find("style_type[label;font=normal]", 1, true))
assert(shown.tester.spec:find("<style font=normal>", 1, true))
assert(player.inventory_formspec:find(";Hello]", 1, true))
assert(#chat == chat_count, "Do not replay chat history")
local function recent_text()
	local texts = {}
	for _, definition in pairs(player.huds) do
		if definition.z_index == 1000 then texts[#texts + 1] = definition.text end
	end
	table.sort(texts)
	return table.concat(texts, "\n")
end
local before_dismiss = recent_text()
player.controls.sneak, player.controls.aux1 = true, true
barnacle_frontend = {is_menu_blocking = function() return true end}
callbacks.step(0.1)
assert(recent_text() == before_dismiss, "Game shortcuts must not run under a menu")
barnacle_frontend = nil
player.controls.aux1 = false; callbacks.step(0.1)
player.controls.aux1 = true
callbacks.step(0.1)
local after_dismiss = recent_text()
assert(after_dismiss ~= before_dismiss and #chat == chat_count, "Shift+E must hide a message without changing console history")
callbacks.step(0.1)
assert(recent_text() == after_dismiss, "Holding Shift+E must not repeat")
player.controls.aux1 = false; callbacks.step(0.1)
assert(callbacks.fields(player, "original_form_id", {barnacle_ru_dismiss_oldest = true}))
assert(recent_text() ~= after_dismiss and #chat == chat_count)
player.controls.sneak = false
player:hud_change(hud_id, "text", "Locked")
assert(player.huds[hud_id].text == "Locked")
player.controls.zoom = true; callbacks.step(0.1)
assert(barnacle_ru.get_language() == "en", "A game action must no longer trigger language switching")
barnacle_ru.toggle()
assert(barnacle_ru.get_language() == "ru" and player.huds[hud_id].text == "Заперто")
assert(player.huds[hud_id].style == 4 and player.huds[bold_id].style == 5)
assert(shown.tester.spec:find("style_type[label;font=mono]", 1, true))
callbacks.step(0.1); assert(barnacle_ru.get_language() == "ru")
player.controls.zoom = false; callbacks.step(0.1)
player.controls.zoom = true; callbacks.step(0.1)
assert(barnacle_ru.get_language() == "ru", "Zoom must stay unrelated to language switching")
barnacle_ru.toggle()
assert(barnacle_ru.get_language() == "en")
assert(callbacks.fields(player, "original_form_id", {unrelated = true}) == false)
callbacks.fields(player, "original_form_id", {quit = true})
shown.tester = nil
barnacle_ru.toggle()
assert(shown.tester == nil, "Closed forms must not reopen")
player:hud_remove(hud_id)
barnacle_ru.toggle()
assert(player.huds[hud_id] == nil)
local history_before = #chat
assert(minetest.format_chat_message("tester", "Hello") == "tester: Hello")
assert(#chat == history_before and recent_text():find("tester: Hello", 1, true),
	"Native player messages must enter the recent HUD once, without being translated or sent again")
barnacle_ru.toggle()
if barnacle_ru.get_language() ~= "ru" then barnacle_ru.toggle() end
for _, chosen in ipairs({"Hello", "Lia", "No", "A B", "A. B", "Александр"}) do
	local prefix = chosen .. ". "
	minetest.chat_send_player("tester", "Lia: " .. prefix .. "Hello", prefix)
	assert(chat[#chat] == "Лия: " .. prefix .. "Привет", "A chosen name must never be translated")
end
local names_ru = recent_text()
barnacle_ru.toggle(); barnacle_ru.toggle()
assert(recent_text() == names_ru, "Language refresh must preserve protected names in visible messages")
callbacks.leave(player)
local previous_language = barnacle_ru.get_language()
local ok, message = callbacks.command("tester")
assert(ok and type(message) == "string" and barnacle_ru.get_language() ~= previous_language)
print("runtime localization checks passed")
