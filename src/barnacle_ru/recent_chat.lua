return function(api)
	local engine = minetest
	local players = {}
	local function now() return engine.get_us_time() / 1000000 end
	local function setting(name, fallback)
		local value = engine.settings and tonumber(engine.settings:get(name))
		return value and value > 0 and value or fallback
	end
	local limit = math.max(1, math.min(20, math.floor(setting("recent_chat_messages", 6))))
	local function layout(name)
		local info = engine.get_player_window_information and engine.get_player_window_information(name)
		local width = info and info.size and tonumber(info.size.x) or 640
		local height = info and info.size and tonumber(info.size.y) or 480
		local scaling = info and tonumber(info.real_hud_scaling) or setting("hud_scaling", 1)
		scaling = scaling and scaling > 0 and scaling or 1
		local gui_scaling = info and tonumber(info.real_gui_scaling)
		gui_scaling = gui_scaling and gui_scaling > 0 and gui_scaling
			or setting("gui_scaling", 1) * scaling / setting("hud_scaling", 1)
		width, height = math.max(0, width or 640), math.max(0, height or 480)
		-- Native text size follows GUI scaling; only HUD offsets follow HUD scaling.
		local pixels = setting("font_size", 16) * gui_scaling
		if api.get_language() == "ru" then pixels = math.max(pixels, setting("mono_font_size", 16) * gui_scaling) end
		local margin, line_height = 10 * scaling, math.ceil(pixels * 1.7 + 2)
		return {
			columns = math.max(1, math.floor((width - margin * 2) / (pixels + 1))),
			rows = math.max(0, math.floor((height * 0.28 - margin) / line_height)),
			x = margin / scaling, y = margin / scaling, step = line_height / scaling,
			style = api.hud_style(0),
		}
	end
	local function same_layout(a, b)
		return a and a.columns == b.columns and a.rows == b.rows and a.x == b.x
			and a.y == b.y and a.step == b.step and a.style == b.style
	end

	local function wrap(text, columns)
		local lines, line, word = {}, {}, {}
		local used, word_width, pending = 0, 0, 0
		local active_color = ""
		local function newline()
			lines[#lines + 1] = table.concat(line)
			line, used = {active_color}, 0
		end
		local function flush_word()
			if #word == 0 then return end
			if used > 0 and used + pending + word_width > columns then newline() end
			if used > 0 and pending > 0 then
				line[#line + 1] = string.rep(" ", pending)
				used = used + pending
			end
			pending = 0
			for _, token in ipairs(word) do
				if token.width > 0 and used >= columns then newline() end
				line[#line + 1] = token.text
				used = used + token.width
				if token.text:match("^\27%(c@") then active_color = token.text end
			end
			word, word_width = {}, 0
		end
		local position = 1
		while position <= #text do
			local first = text:byte(position)
			if first == 10 or first == 13 then
				flush_word(); pending = 0; newline()
				if first == 13 and text:byte(position + 1) == 10 then position = position + 1 end
				position = position + 1
			elseif first == 32 or first == 9 then
				flush_word(); pending = pending + (first == 9 and 4 or 1)
				position = position + 1
			else
				local length, visible = 1, 1
				if first == 27 then
					local finish = text:sub(position + 1, position + 1) == "(" and text:find(")", position + 2, true)
					length, visible = finish and finish - position + 1 or math.min(2, #text - position + 1), 0
				elseif first >= 194 and first <= 244 then
					local expected = first < 224 and 2 or first < 240 and 3 or 4
					local valid = position + expected - 1 <= #text
					for offset = 1, expected - 1 do
						local byte = text:byte(position + offset)
						if not byte or byte < 128 or byte > 191 then valid = false end
					end
					if valid then length = expected end
				end
				word[#word + 1] = {text = text:sub(position, position + length - 1), width = visible}
				word_width = word_width + visible
				position = position + length
			end
		end
		flush_word()
		if used > 0 or #lines == 0 or text:sub(-1):match("[\r\n]") then newline() end
		return lines
	end

	local function expire(state, time)
		local changed = false
		while state.queue[1] and state.queue[1].expires <= time do
			table.remove(state.queue, 1)
			changed = true
		end
		return changed
	end
	local function render(state, geometry)
		local originals = api.originals(state.player)
		if not originals then return end
		local lines = {}
		local function append(text, style, message_index)
			for _, line in ipairs(wrap(text, geometry.columns)) do
				lines[#lines + 1] = {text = line, style = style, message = message_index}
			end
		end
		for message_index, message in ipairs(state.queue) do
			local source = message.verbatim and message.source or api.translate_message(message.source, "en", message.name_prefix)
			append(source, 0, message_index)
			if api.get_language() == "ru" then
				local translated = message.verbatim and message.source or api.translate_message(message.source, "ru", message.name_prefix)
				if translated ~= source then append(translated, api.hud_style(0), message_index) end
			end
		end
		local first = math.max(1, #lines - geometry.rows + 1)
		local count = math.min(#lines, geometry.rows)
		state.oldest_visible = count > 0 and lines[first].message or nil
		for index = 1, count do
			local text, style = lines[first + index - 1].text, lines[first + index - 1].style
			local offset = {x = geometry.x, y = geometry.y + (index - 1) * geometry.step}
			local id = state.ids[index]
			local previous = state.rendered[index]
			if id then
				if not previous or previous.text ~= text then originals.hud_change(state.player, id, "text", text) end
				if not previous or previous.style ~= style then originals.hud_change(state.player, id, "style", style) end
				if not previous or previous.x ~= offset.x or previous.y ~= offset.y then
					originals.hud_change(state.player, id, "offset", offset)
				end
			else
				id = originals.hud_add(state.player, {
					hud_elem_type = "text", position = {x = 0, y = 0}, alignment = {x = 1, y = 1},
					offset = offset, scale = {x = 100, y = 100}, size = {x = 1, y = 1},
					text = text, style = style, number = 0xFFFFFF, z_index = 1000,
				})
				state.ids[index] = id
			end
			state.rendered[index] = {text = text, style = style, x = offset.x, y = offset.y}
		end
		for index = #state.ids, count + 1, -1 do
			originals.hud_remove(state.player, state.ids[index])
			state.ids[index], state.rendered[index] = nil, nil
		end
		state.geometry = geometry
	end
	local function leave(player)
		local name = player:get_player_name()
		local state = players[name]
		if not state then return end
		local originals = api.originals(player)
		if originals then
			for _, id in ipairs(state.ids) do originals.hud_remove(player, id) end
		end
		player:hud_set_flags({chat = state.was_chat})
		players[name] = nil
	end
	local function join(player)
		local originals = api.originals(player)
		if not originals or not originals.hud_add or not originals.hud_change or not originals.hud_remove then return false end
		local name = player:get_player_name()
		if players[name] then leave(player) end
		local flags = player:hud_get_flags()
		players[name] = {player = player, queue = {}, ids = {}, rendered = {}, was_chat = flags.chat ~= false}
		player:hud_set_flags({chat = false})
		return true
	end
	local function push(name, source, context)
		local state = players[name]
		if not state or type(source) ~= "string" or source == "" then return end
		local time = now()
		expire(state, time)
		state.queue[#state.queue + 1] = {source = source, expires = time + 60,
			verbatim = context and context.verbatim, name_prefix = context and context.name_prefix}
		while #state.queue > limit do table.remove(state.queue, 1) end
		render(state, layout(name))
	end
	local function refresh()
		local time = now()
		for name, state in pairs(players) do
			expire(state, time)
			render(state, layout(name))
		end
	end
	local function dismiss_oldest(name)
		local state = players[name]
		if not state then return false end
		expire(state, now())
		local geometry = layout(name)
		render(state, geometry)
		if #state.queue == 0 then return false end
		-- Drop the hidden prefix too, so dismissed messages cannot reveal older ones again.
		for _ = 1, state.oldest_visible or 1 do table.remove(state.queue, 1) end
		render(state, geometry)
		return true
	end
	local function step()
		local time = now()
		for name, state in pairs(players) do
			local expired = expire(state, time)
			local geometry = layout(name)
			if expired or not same_layout(state.geometry, geometry) then render(state, geometry) end
		end
	end
	return {join = join, leave = leave, push = push, refresh = refresh, step = step, dismiss_oldest = dismiss_oldest}
end
