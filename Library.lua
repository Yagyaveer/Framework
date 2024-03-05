-- @Autor: ForeverDev (@d5vid_)
-- @Info: Make a framework!

-- Notes:
--[[
	Thank you so much David for teaching me this, this is a TRUE life-saver 
																	- Internal
]]--

local Modules = script.Modules
local Framework = {}
local priorityEntries = {}

local tick2 = tick() -- Get Current Tick
-- @Info: Gather Modules
local function AddScripts(parent)
	for _, child in ipairs(parent:GetChildren()) do
		if (not child:IsA('ModuleScript')) then
			continue
		end

		if (child.Name:find('CUSTOM')) then
			child.Name = child.Name:match('CUSTOM | (.+)')
		end

		local priorityString = child.Name:match('(%d+)%s')
		if (not priorityString) then
			error('No Priority Found for Module ' .. child.Name)
		end

		local ModuleName = child.Name:match('%d+%s*|%s*(.+)')
		if (not ModuleName) then
			error('Invalid Name For Module '.. child.name)
		end

		table.insert(priorityEntries, {
			module = child,
			moduleName = ModuleName,
			priority = tonumber(priorityString)
		})
	end
end

AddScripts(Modules)

table.sort(priorityEntries, function(a, b)
	return a.priority < b.priority
end) -- Sort The Modules

-- Load Modules in order of priority
local loadedModules = 0
for _, moduleEntry in ipairs(priorityEntries) do
	coroutine.wrap(function()
		Framework[moduleEntry.moduleName] = require(moduleEntry.module)
		loadedModules += 1
	end)()
	--wait()
end

while (loadedModules < #priorityEntries) do
	wait()
end

-- ALL SET
Framework.Loaded = true
if (math.floor((tick() - tick2)* 1000) >= 200) then
	print("\226\157\142 _L took " .. math.floor((tick() - tick2) * 1000) .. "ms to initialize server (unusual)")
else
	print("\226\156\133 _L took " .. math.floor((tick() - tick2) * 1000) .. "ms to initialize server!")
end

return Framework
