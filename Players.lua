local _L coroutine.wrap(function()_L = require(game.ServerScriptService.Server.Library)end)()
local PlayerModule = require(script.Parent.Parent.PlayerModule)
local Players = game.Players

local ProfilesSaved = {}
local ProfileStore = _L.ProfileService.GetProfileStore(_L.DataIndex.PlayerDataStore,_L.DataIndex.ProfileTemplate)

Players.PlayerAdded:Connect(function(Player)
	local _PlayerName_ = Player.Name
	
	if Player.AccountAge <= -1 then
		Player:Kick() --"Your Account Is Too Young To Play This Game!"
	else
		local sucpro,errpro = pcall(function()
			if ProfilesSaved[Player] then
				warn(_PlayerName_ .. " profile wasn't released when they left in this session, relesing and loading their profile to follow order.")
				ProfilesSaved[Player]:Release()
			end
		end)if not sucpro then warn(errpro) end
		
		local profile = ProfileStore:LoadProfileAsync(Player.UserId .. "_KEY_43H5YEH","ForceLoad")
		if profile ~= nil then
			profile:Reconcile() -- Fill in missing variables from ProfileTemplate (optional)
			ProfilesSaved[Player] = profile
			
			if not game.Players:FindFirstChild(_PlayerName_) then
				ProfilesSaved[Player]:Release()
				return
			end
			
			local NewPlrFunction = PlayerModule.new(Player, profile)
			PlayerModule.PlayerFunctions[Player] = NewPlrFunction

			profile:ListenToRelease(function()
				if NewPlrFunction then
					NewPlrFunction.Disconnect()
					NewPlrFunction = nil
					pcall(function()
						if Player then
							Player:Kick("Same profile was loaded in another game instance!\nPlease report this issue with steps to reproduce in our server!")
						end
					end)
				end
			end)
		else
			--warn("Unable to load player " .. _PlayerName_ .. " Profile.")
			--Player:Kick("Unable to process your data for unknown reasons.\n| Please try rejoining. |\nIf the problem continues to occur then please report it in our discord server.")
		end
	end
end)

local function awaitProfile(Plr, _name_)
	local t = tick()
	repeat until ProfilesSaved[Plr] ~= nil or game.Players:FindFirstChild(_name_) or (tick()-t) >= 5
	return ProfilesSaved[Plr] or nil
end
game.Players.PlayerRemoving:Connect(function(Player)
	local profile = awaitProfile(Player, Player.Name)
	if ProfilesSaved[Player] then
		ProfilesSaved[Player]:Release()
	else
		warn("Unable to save data for " .. Player.Name .. "! (maybe because player left too soon before the data could even load)\nAttepmting to disconnect PlayerFunction if created..")
		local PlrFunc = PlayerModule.GetPlayerFunction(Player)
		if PlrFunc then
			PlrFunc.Disconnect()
			warn("Successfully disconnected PlayerFunction for " .. Player.Name .. ".")
		else
			warn("No PlayerFunction found for " .. Player.Name .. ".")
		end
	end
end)