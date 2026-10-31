return function(api)
	local engine = minetest
	local nodenames = dofile(engine.get_modpath(engine.get_current_modname()) .. "/nodenames.lua")
	local tracked = {}
	local native_set_string
	local hook_installed = false
	local function key(pos) return ("%d,%d,%d"):format(pos.x, pos.y, pos.z) end
	local function rendered(field, source, selected)
		if field == "formspec" then return api.translate_formspec(source, false, selected) end
		return api.translate(source, selected)
	end
	local function entry_for(pos)
		local id = key(pos)
		tracked[id] = tracked[id] or {pos = {x = pos.x, y = pos.y, z = pos.z}, fields = {}}
		return tracked[id]
	end
	local function position_of(meta)
		local ok, location = pcall(function()
			if type(meta.get_inventory) ~= "function" then return nil end
			local inventory = meta:get_inventory()
			if not inventory or type(inventory.get_location) ~= "function" then return nil end
			return inventory:get_location()
		end)
		local pos = ok and type(location) == "table" and location.type == "node" and location.pos
		if type(pos) == "table" and type(pos.x) == "number" and type(pos.y) == "number" and type(pos.z) == "number" then
			return pos
		end
	end
	local function install_hook()
		if hook_installed then return end
		hook_installed = true
		local probe = engine.get_meta({x = 0, y = 0, z = 0})
		local methods = getmetatable(probe)
		if type(methods) == "table" then
			methods = type(methods.__index) == "table" and methods.__index or methods
			if type(methods.set_string) == "function" then
				native_set_string = methods.set_string
				methods.set_string = function(meta, field, source)
					if (field == "infotext" or field == "formspec") and type(source) == "string" then
						local pos = position_of(meta)
						if pos then
							local value = rendered(field, source)
							entry_for(pos).fields[field] = {source = source, last = value}
							return native_set_string(meta, field, value)
						end
					end
					return native_set_string(meta, field, source)
				end
			end
		end
	end
	local function update(entry)
		if engine.get_node_or_nil and not engine.get_node_or_nil(entry.pos) then return end
		local meta = engine.get_meta(entry.pos)
		for _, field in ipairs({"infotext", "formspec"}) do
			local current = meta:get_string(field)
			local state = entry.fields[field]
			if not state then
				local baseline = api.metadata_sources and api.metadata_sources[key(entry.pos)]
				local source = baseline and baseline[field]
				if source and current ~= source and current ~= rendered(field, source, "ru")
					and current ~= rendered(field, source, "en") then source = nil end
				state = {source = source or current}
				entry.fields[field] = state
			elseif current ~= state.last then
				-- A game callback changed the field since our last render.
				state.source = current
			end
			local value = rendered(field, state.source)
			if value ~= current then
				if native_set_string then native_set_string(meta, field, value)
				else meta:set_string(field, value) end
			end
			state.last = value
		end
	end
	engine.register_lbm({
		name = "barnacle_ru:localize_saved_text",
		label = "Localize saved node text",
		nodenames = nodenames,
		run_at_every_load = true,
		action = function(pos)
			local meta = engine.get_meta(pos)
			if meta:get_string("infotext") == "" and meta:get_string("formspec") == "" then return end
			update(entry_for(pos))
		end,
	})
	return function()
		for _, entry in pairs(tracked) do update(entry) end
	end, install_hook
end
