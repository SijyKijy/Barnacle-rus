local modpath = assert(arg and arg[1])
local dictionary = dofile(modpath .. "/dictionary.lua")
local sent
minetest = {
 get_current_modname = function() return "barnacle_ru" end,
 get_modpath = function() return modpath end,
 get_mod_storage = function() return {get_string = function() return "ru" end} end,
 register_on_joinplayer = function() end, register_on_leaveplayer = function() end,
 register_on_mods_loaded = function() end, register_on_player_receive_fields = function() end,
 register_globalstep = function() end, register_lbm = function() end, register_chatcommand = function() end,
 show_formspec = function() end, chat_send_all = function() end,
 chat_send_player = function(_, text) sent = text end,
}
dofile(modpath .. "/init.lua")
local checked = 0
for source, target in pairs(dictionary) do
 for _, text_value in ipairs({"PLAYER_47", "Hello. No", "Лия. Нет"}) do
 local arguments = {}
 for spec in source:gmatch("%%[-+ #0]*%d*%.?%d*[%%cdiouxXeEfgGqs]") do
  local kind = spec:sub(-1)
  if kind ~= "%" then
   arguments[#arguments + 1] = (kind == "s" or kind == "q") and text_value or (kind == "c" and 65 or 12)
  end
 end
 if #arguments > 0 then
  local input, expected = string.format(source, unpack(arguments)), string.format(target, unpack(arguments))
  assert(barnacle_ru.translate(input) == expected, "Catalog template mismatch: " .. source)
  minetest.chat_send_player("tester", "Lia: " .. input)
  assert(sent == barnacle_ru.translate("Lia") .. ": " .. expected, "Speaker/template mismatch: " .. source)
  checked = checked + 1
 end
 end
end
assert(checked > 0, "No real catalog templates checked")
print("real catalog templates passed: " .. checked)
