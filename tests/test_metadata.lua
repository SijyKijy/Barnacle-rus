local modpath = assert(arg and arg[1], "Pass the barnacle_ru mod directory as arg[1]")
local language, lbm = "ru", nil
local data = {infotext = "Locked", formspec = "label[0,0;Locked]", owner = "Hello", state = "locked"}
local pos = {x = -2, y = 3, z = 7}
local function key(p) return ("%d,%d,%d"):format(p.x, p.y, p.z) end
local all_data = {[key(pos)] = data}
local loaded = true
local script_init = true
local writes = 0
local methods = {}
function methods:get_string(field) return self.fields[field] or "" end
function methods:set_string(field, value)
	self.fields[field], writes = value, writes + 1
end
function methods:get_inventory()
	return {get_location = function() return {type = "node", pos = self.pos} end}
end
minetest = {
	get_current_modname = function() return "barnacle_ru" end,
	get_modpath = function() return modpath end,
	register_lbm = function(definition) lbm = definition end,
	get_node_or_nil = function() return loaded and {name = "test:door"} or nil end,
	get_meta = function(p)
		assert(not script_init, "Node metadata must not be accessed during script initialization")
		all_data[key(p)] = all_data[key(p)] or {}
		return setmetatable({fields = all_data[key(p)], pos = p}, {__index = methods, __metatable = methods})
	end,
}
local api = {
	translate = function(text, selected) return (selected or language) == "ru" and text:gsub("Locked", "Заперто") or text end,
	translate_formspec = function(text, add_toggle, selected)
		assert(add_toggle == false)
		return (selected or language) == "ru" and text:gsub("Locked", "Заперто") or text
	end,
	get_language = function() return language end,
	metadata_sources = {
		["-2,3,7"] = {infotext = "Locked", formspec = "label[0,0;Locked]"},
		["1,2,3"] = {infotext = "Locked", formspec = "label[0,0;Locked]"},
	},
}
local original_dofile = dofile
dofile = function(path)
	if path == modpath .. "/nodenames.lua" then return {"test:door"} end
	return original_dofile(path)
end
local refresh, install_hook = original_dofile(modpath .. "/metadata.lua")(api)
dofile = original_dofile
script_init = false
install_hook()
local installed_setter = methods.set_string
install_hook()
assert(methods.set_string == installed_setter, "Install the metadata hook only once")
assert(lbm.run_at_every_load and lbm.nodenames[1] == "test:door")
lbm.action(pos)
assert(data.infotext == "Заперто" and data.formspec == "label[0,0;Заперто]")
assert(data.owner == "Hello" and data.state == "locked")
assert(writes == 2)
refresh(); assert(writes == 2, "Do not rewrite unchanged node data")
language = "en"; refresh()
assert(data.infotext == "Locked" and data.formspec == "label[0,0;Locked]")
language = "ru"; refresh()
assert(data.infotext == "Заперто")
data.infotext = "New text"
language = "en"; refresh()
assert(data.infotext == "New text", "A newer game callback wins over the old baseline")
data.infotext = ""
refresh(); assert(data.infotext == "", "Removed metadata must not resurrect")
loaded = false; data.infotext = "Locked"; language = "ru"; refresh()
assert(data.infotext == "Locked", "Do not force-load node blocks")
loaded = true; refresh(); assert(data.infotext == "Заперто")
local meta = minetest.get_meta(pos)
meta:set_string("infotext", "Locked")
assert(data.infotext == "Заперто", "New game setters are translated immediately")
language = "en"; refresh(); assert(data.infotext == "Locked")
meta:set_string("owner", "Locked")
assert(data.owner == "Locked", "Technical fields must not be translated")
local reloaded = {infotext = "Заперто", formspec = "label[0,0;Заперто]"}
all_data["1,2,3"] = reloaded
lbm.action({x = 1, y = 2, z = 3})
assert(reloaded.infotext == "Locked" and reloaded.formspec == "label[0,0;Locked]",
	"Saved Russian fields must restore English from the shipped baseline")
print("saved metadata checks passed")
local original_formspec = api.translate_formspec
api.translate_formspec = function(text, add_toggle, selected)
	return "style[" .. (selected or language) .. "]" .. original_formspec(text, add_toggle, selected)
end
all_data["1,2,4"] = {formspec = "style[en]label[0,0;Locked]"}
api.metadata_sources["1,2,4"] = {formspec = "label[0,0;Locked]"}
language = "ru"
lbm.action({x = 1, y = 2, z = 4})
assert(all_data["1,2,4"].formspec == "style[ru]label[0,0;Заперто]",
	"An English form saved on a previous run must use the raw baseline, without nested styles")
