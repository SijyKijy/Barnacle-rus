for _, path in ipairs(arg) do
 assert(loadfile(path))
end
print("Lua syntax passed: " .. #arg)
