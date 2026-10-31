local engine = minetest
local modpath = engine.get_modpath(engine.get_current_modname())
local dictionary = dofile(modpath .. "/dictionary.lua")
local storage = engine.get_mod_storage()
local language = storage:get_string("language") == "en" and "en" or "ru"
local forms, inventories, hud = {}, {}, {}
local dismiss_held = {}
local method_hooks = {}
local toggle_field = "barnacle_ru_toggle"
local dismiss_field = "barnacle_ru_dismiss_oldest"
local refresh_metadata, install_metadata_hook
local recent_chat
local native_get_translated_string = engine.get_translated_string

local function word_byte(value)
	return value ~= "" and (value:match("[%w_]") ~= nil or value:byte() >= 128)
end

local function boundary(text, start, finish, source)
	return not (word_byte(source:sub(1, 1)) and word_byte(text:sub(start - 1, start - 1)))
		and not (word_byte(source:sub(-1)) and word_byte(text:sub(finish + 1, finish + 1)))
end

local function pattern_escape(text)
	return (text:gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1"))
end

local function format_parts(text)
	local parts, count, position = {}, 0, 1
	while position <= #text do
		local start = text:find("%", position, true)
		if not start then parts[#parts + 1] = {literal = text:sub(position)}; break end
		parts[#parts + 1] = {literal = text:sub(position, start - 1)}
		if text:sub(start + 1, start + 1) == "%" then
			parts[#parts + 1] = {literal = "%"}
			position = start + 2
		else
			local spec = text:sub(start):match("^%%[-+ #0]*%d*%.?%d*([cdiouxXeEfgGqs])")
			local whole = text:sub(start):match("^%%[-+ #0]*%d*%.?%d*[cdiouxXeEfgGqs]")
			if not whole then return nil end
			count = count + 1
			parts[#parts + 1] = {argument = count, kind = spec}
			position = start + #whole
		end
	end
	return parts, count
end

local literals, templates = {}, {}
for source, target in pairs(dictionary) do
	if source ~= "" and source ~= target then
		local source_parts, count = format_parts(source)
		local target_parts, target_count = format_parts(target)
		if source_parts and count > 0 and target_parts and count == target_count then
			local pattern, specificity = {}, 0
			for i, part in ipairs(source_parts) do
				if part.literal then
					pattern[#pattern + 1] = pattern_escape(part.literal)
					specificity = specificity + #part.literal
				elseif part.kind == "d" or part.kind == "i" or part.kind == "u" then
					pattern[#pattern + 1] = "([+-]?%d+)"
				elseif part.kind == "s" or part.kind == "q" then
					pattern[#pattern + 1] = i == #source_parts and "([^\n]*)" or "(.-)"
				else
					pattern[#pattern + 1] = "([+-]?[%d%.]+)"
				end
			end
			templates[#templates + 1] = {source = source, pattern = table.concat(pattern), parts = target_parts, specificity = specificity}
		else
			literals[#literals + 1] = {source = source, target = target}
		end
	end
end
table.sort(literals, function(a, b) return a.source < b.source end)
table.sort(templates, function(a, b)
	if a.specificity ~= b.specificity then return a.specificity > b.specificity end
	return a.source < b.source
end)

local function template_text(entry, captures, offset)
	local output = {}
	for _, part in ipairs(entry.parts) do
		output[#output + 1] = part.literal or captures[part.argument + offset] or ""
	end
	return table.concat(output)
end

local function translate_plain(text)
	if dictionary[text] then return dictionary[text] end
	-- Match a complete formatted message before splitting it into smaller literals.
	for _, entry in ipairs(templates) do
		local captures = {text:match("^" .. entry.pattern .. "$")}
		if captures[1] then return template_text(entry, captures, 0) end
	end
	local matches = {}
	local function remember(start, finish, source, target)
		local previous = matches[start]
		if finish >= start and boundary(text, start, finish, source)
			and (not previous or finish > previous.finish) then
			matches[start] = {finish = finish, text = target}
		end
	end
	for _, entry in ipairs(templates) do
		local position = 1
		while position <= #text do
			local result = {text:find(entry.pattern, position)}
			local start, finish = result[1], result[2]
			if not start then break end
			remember(start, finish, entry.source, template_text(entry, result, 2))
			position = math.max(finish + 1, start + 1)
		end
	end
	for _, entry in ipairs(literals) do
		local position = 1
		while position <= #text do
			local start, finish = text:find(entry.source, position, true)
			if not start then break end
			remember(start, finish, entry.source, entry.target)
			position = finish + 1
		end
	end
	local output, position = {}, 1
	while position <= #text do
		local found = matches[position]
		if found then
			output[#output + 1], position = found.text, found.finish + 1
		else
			output[#output + 1], position = text:sub(position, position), position + 1
		end
	end
	return table.concat(output)
end

local function translate(text, target_language)
	if type(text) ~= "string" or text == "" then return text end
	local selected = target_language or language
	if native_get_translated_string and text:find("\27(T@", 1, true) then
		text = native_get_translated_string(selected, text)
	end
	if selected == "en" then return text end
	local output, position = {}, 1
	-- Luanti color/translation escapes contain technical fields, not visible words.
	while position <= #text do
		local start, finish = text:find("\27%b()", position)
		if not start then output[#output + 1] = translate_plain(text:sub(position)); break end
		output[#output + 1] = translate_plain(text:sub(position, start - 1))
		output[#output + 1] = text:sub(start, finish)
		position = finish + 1
	end
	return table.concat(output)
end

local function split_escaped(text, delimiter)
	local result, start, position = {}, 1, 1
	while position <= #text do
		local byte = text:sub(position, position)
		if byte == "\\" then position = position + 2
		elseif byte == delimiter then
			result[#result + 1], start = text:sub(start, position - 1), position + 1
			position = position + 1
		else position = position + 1 end
	end
	result[#result + 1] = text:sub(start)
	return result
end

-- The preloaded normal family is the original pixel font; mono holds the Russian font.
local function visible_field(text, hypertext, target_language)
	text = text:gsub("\\(.)", "%1")
	if hypertext then
		local output, position = {}, 1
		while position <= #text do
			local start, finish = text:find("<[^>]*>", position)
			if not start then output[#output + 1] = translate(text:sub(position), target_language); break end
			output[#output + 1] = translate(text:sub(position, start - 1), target_language)
			output[#output + 1] = text:sub(start, finish)
			position = finish + 1
		end
		local font = (target_language or language) == "ru" and "mono" or "normal"
		text = "<style font=" .. font .. ">" .. table.concat(output) .. "</style>"
	else text = translate(text, target_language) end
	return engine.formspec_escape(text)
end

local fields_to_translate = {
	label = 2, vertlabel = 2, button = 4, button_exit = 4,
	image_button = 5, image_button_exit = 5, item_image_button = 5,
	field = 4, pwdfield = 4, textarea = 4, checkbox = 3, hypertext = 4,
}

local function translate_formspec(spec, add_toggle, target_language)
	if type(spec) ~= "string" or spec == "" then return spec end
	local output, position = {}, 1
	local font = (target_language or language) == "ru" and "mono" or "normal"
	local font_styles = {}
	for element in ("label,vertlabel,button,button_exit,image_button,image_button_exit,item_image_button,field,pwdfield,textarea,table,textlist"):gmatch("[^,]+") do
		font_styles[#font_styles + 1] = "style_type[" .. element .. ";font=" .. font .. "]"
	end
	local font_inserted = false
	while position <= #spec do
		local start, body_start, element = spec:find("([%a_][%w_]*)%[", position)
		if not start then output[#output + 1] = spec:sub(position); break end
		local finish = body_start + 1
		while finish <= #spec do
			local byte = spec:sub(finish, finish)
			if byte == "\\" then finish = finish + 2
			elseif byte == "]" then break
			else finish = finish + 1 end
		end
		if finish > #spec then output[#output + 1] = spec:sub(position); break end
		output[#output + 1] = spec:sub(position, start - 1)
		local original = spec:sub(start, finish)
		local field = fields_to_translate[element]
		if not font_inserted and (field or element == "table" or element == "textlist") then
			-- Geometry must stay at the start: a style before size[] breaks native forms.
			output[#output + 1] = table.concat(font_styles)
			font_inserted = true
		end
		if (target_language or language) == "ru" and dictionary[original] then
			output[#output + 1] = dictionary[original]
		elseif field or element == "tooltip" then
			local fields = split_escaped(spec:sub(body_start + 1, finish - 1), ";")
			if element == "tooltip" then field = fields[1]:find(",", 1, true) and 3 or 2 end
			if fields[field] then fields[field] = visible_field(fields[field], element == "hypertext", target_language) end
			output[#output + 1] = element .. "[" .. table.concat(fields, ";") .. "]"
		else output[#output + 1] = original end
		position = finish + 1
	end
	local translated = table.concat(output)
	if add_toggle then
		local width, height = spec:match("size%[([%d%.]+),([%d%.]+)")
		width, height = tonumber(width), tonumber(height)
		if width and height and width >= 2 and height >= 0.6 then
			local button_width = width < 10 and 1.8 or 2.8
			translated = translated .. "style[" .. toggle_field .. ";border=true;bgcolor=#222222;textcolor=#ffffff;font_size=-2;font=" .. font .. "]"
				.. ("button[%.2f,0.10;%.2f,0.55;%s;RU / EN]"):format(math.max(0.1, width - button_width - 0.2), button_width, toggle_field)
			local controls_menu = spec:find(";btn_ctrl_back;", 1, true)
			local pause_menu = spec:find(";btn_pause_resume;", 1, true)
			local main_menu = spec:find(";btn_continue;", 1, true) or spec:find(";btn_apply_gui;", 1, true)
			if height >= 1.3 and (controls_menu or pause_menu or main_menu) then
				local clear_width = math.max(button_width, 2.2)
				local clear_x = width - clear_width - 0.2
				local clear_y = 0.75
				if controls_menu then clear_y = height - 0.8
				elseif pause_menu then clear_x, clear_y = width - button_width - clear_width - 0.4, 0.1 end
				translated = translated .. "style[" .. dismiss_field .. ";border=true;bgcolor=#222222;textcolor=#ffffff;font_size=-2;font=" .. font .. "]"
					.. ("button[%.2f,%.2f;%.2f,0.55;%s;%s]"):format(math.max(0.1, clear_x), clear_y, clear_width,
						dismiss_field, engine.formspec_escape(translate("Dismiss oldest", target_language)))
					.. "tooltip[" .. dismiss_field .. ";" .. engine.formspec_escape(translate("Dismiss oldest message (Shift+E)", target_language)) .. "]"
			end
		end
	end
	return translated
end

local original_show_formspec = engine.show_formspec
engine.show_formspec = function(name, formname, spec)
	forms[name] = spec ~= "" and {name = formname, source = spec} or nil
	return original_show_formspec(name, formname, translate_formspec(spec, true))
end
if engine.close_formspec then
	local original_close = engine.close_formspec
	engine.close_formspec = function(name, formname)
		if forms[name] and (formname == "" or forms[name].name == formname) then forms[name] = nil end
		return original_close(name, formname)
	end
end

local function translate_message(text, target_language, name_prefix)
	if type(text) ~= "string" or text:match("^<[^>]+>") then return text end
	local body = text:match("^Lia: (.*)$")
	if body then
		if name_prefix and body:sub(1, #name_prefix) == name_prefix then
			return translate("Lia", target_language) .. ": " .. name_prefix .. translate(body:sub(#name_prefix + 1), target_language)
		end
		return translate("Lia", target_language) .. ": " .. translate(body, target_language)
	end
	return translate(text, target_language)
end

for _, method in ipairs({"chat_send_player", "chat_send_all"}) do
	local original = engine[method]
	if method == "chat_send_player" then
		engine[method] = function(name, text, name_prefix)
			local result = original(name, translate_message(text, nil, name_prefix))
			if recent_chat then recent_chat.push(name, text, {name_prefix = name_prefix}) end
			return result
		end
	else
		engine[method] = function(text)
			local result = original(translate_message(text))
			if recent_chat then
				for _, player in ipairs(engine.get_connected_players()) do recent_chat.push(player:get_player_name(), text) end
			end
			return result
		end
	end
end

if engine.format_chat_message then
	local original_formatter = engine.format_chat_message
	engine.format_chat_message = function(name, message)
		local formatted = original_formatter(name, message)
		if recent_chat then recent_chat.push(name, formatted, {verbatim = true}) end
		return formatted
	end
end

local function player_methods(player)
	local methods = getmetatable(player)
	if type(methods) ~= "table" then return nil end
	return type(methods.__index) == "table" and methods.__index or methods
end

local function hud_style(style)
	style = tonumber(style) or 0
	if language == "ru" and style % 8 < 4 then return style + 4 end
	return style
end

local function hook_player(player)
	if install_metadata_hook then install_metadata_hook() end
	local methods = player_methods(player)
	if not methods or method_hooks[methods] then return end
	local originals = {}
	for _, name in ipairs({"hud_add", "hud_change", "hud_remove", "set_inventory_formspec"}) do
		if type(methods[name]) == "function" then originals[name] = methods[name] end
	end
	method_hooks[methods] = originals
	if originals.hud_add then methods.hud_add = function(object, definition)
		local visible = definition.hud_elem_type == "text" or definition.type == "text"
		local copy = {}
		for key, value in pairs(definition) do copy[key] = value end
		if visible then copy.text, copy.style = translate(copy.text), hud_style(copy.style) end
		local id = originals.hud_add(object, copy)
		if visible and id then
			hud[object] = hud[object] or {}
			hud[object][id] = {text = definition.text, style = definition.style or 0}
		end
		return id
	end end
	if originals.hud_change then methods.hud_change = function(object, id, stat, value)
		if stat == "text" and hud[object] and hud[object][id] then
			hud[object][id].text = value
			return originals.hud_change(object, id, stat, translate(value))
		end
		if stat == "style" and hud[object] and hud[object][id] then
			hud[object][id].style = value
			return originals.hud_change(object, id, stat, hud_style(value))
		end
		return originals.hud_change(object, id, stat, value)
	end end
	if originals.hud_remove then methods.hud_remove = function(object, id)
		if hud[object] then hud[object][id] = nil end
		return originals.hud_remove(object, id)
	end end
	if originals.set_inventory_formspec then methods.set_inventory_formspec = function(object, spec)
		inventories[object] = spec
		return originals.set_inventory_formspec(object, translate_formspec(spec, true))
	end end
end

local function toggle()
	language = language == "ru" and "en" or "ru"
	storage:set_string("language", language)
	for _, player in ipairs(engine.get_connected_players()) do
		local originals = method_hooks[player_methods(player)]
		if originals then
			for id, definition in pairs(hud[player] or {}) do
				if originals.hud_change then
					originals.hud_change(player, id, "style", hud_style(definition.style))
					originals.hud_change(player, id, "text", translate(definition.text))
				end
			end
			if inventories[player] and originals.set_inventory_formspec then
				originals.set_inventory_formspec(player, translate_formspec(inventories[player], true))
			end
		end
		local form = forms[player:get_player_name()]
		if form then original_show_formspec(player:get_player_name(), form.name, translate_formspec(form.source, true)) end
	end
	if refresh_metadata then refresh_metadata() end
	if recent_chat then recent_chat.refresh() end
end

engine.register_on_joinplayer(function(player)
	hook_player(player)
	if recent_chat then recent_chat.join(player) end
end)
engine.register_on_leaveplayer(function(player)
	if recent_chat then recent_chat.leave(player) end
	forms[player:get_player_name()], hud[player], inventories[player] = nil, nil, nil
	dismiss_held[player:get_player_name()] = nil
end)
local function language_fields(player, formname, fields)
	if fields[toggle_field] then toggle(); return true end
	local name = player:get_player_name()
	if fields[dismiss_field] then
		if recent_chat then recent_chat.dismiss_oldest(name) end
		return true
	end
	if fields.quit and forms[name] and forms[name].name == formname then forms[name] = nil end
	return false
end
engine.register_globalstep(function()
	for _, player in ipairs(engine.get_connected_players()) do
		local name = player:get_player_name()
		local control = player:get_player_control()
		local pressed = control.sneak and control.aux1
		local frontend = rawget(_G, "barnacle_frontend")
		local blocked = frontend and frontend.is_menu_blocking and frontend.is_menu_blocking(player)
		if pressed and not dismiss_held[name] and not blocked and recent_chat then recent_chat.dismiss_oldest(name) end
		dismiss_held[name] = pressed
	end
	if recent_chat then recent_chat.step() end
end)
engine.register_chatcommand("language", {
	description = "Переключить язык / Switch language (RU / EN)",
	func = function()
		toggle()
		return true, language == "ru" and "Язык: русский." or "Language: English."
	end,
})
engine.register_on_mods_loaded(function()
	-- Receive-field callbacks run newest first; menu handlers consume unknown buttons.
	engine.register_on_player_receive_fields(language_fields)
	if language ~= "ru" or not engine.override_item then return end
	for name, definition in pairs(engine.registered_items or {}) do
		if type(definition.description) == "string" then
			local description = definition.description
			if engine.get_translated_string then description = engine.get_translated_string("ru", description) end
			description = translate(description)
			if description ~= definition.description then engine.override_item(name, {description = description}) end
		end
	end
end)

barnacle_ru = {translate = translate, translate_formspec = translate_formspec,
	toggle = toggle, get_language = function() return language end}
barnacle_ru.metadata_sources = dofile(modpath .. "/metadata_sources.lua")
refresh_metadata, install_metadata_hook = dofile(modpath .. "/metadata.lua")(barnacle_ru)
recent_chat = dofile(modpath .. "/recent_chat.lua")({
	translate_message = translate_message, get_language = barnacle_ru.get_language, hud_style = hud_style,
	originals = function(player) return method_hooks[player_methods(player)] end,
})
