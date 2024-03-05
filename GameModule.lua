local _L coroutine.wrap(function()_L = require(script.Parent.Library)end)()
local GameModule = {}
local PlayerModule = require(script.Parent.PlayerModule)
GameModule.Maid = _L.Maid.new()
local Milks = game.ServerStorage.Storage.Items.Milks.Milks

coroutine.wrap(function()
	task.wait(1)
	for _,milk in pairs(Milks:GetChildren()) do
		if milk:IsA("ObjectValue") then
			if milk.Value then
				GameModule.Maid:GiveTask(milk.Value.Touched:Connect(function(Hit)
					if Hit.Parent then
						local Player = game.Players:GetPlayerFromCharacter(Hit.Parent)
						if Player then
							local PlayerFunction = PlayerModule.PlayerFunctions[Player]
							if PlayerFunction then
								if PlayerFunction.TouchedMilk then
									PlayerFunction.TouchedMilk(milk.Name)
								end
							else
								warn("No PlayerFunction found for player " .. Player.Name)
							end
						end
					end
				end))
			end
		end
	end
end)()

local Secs = 0
coroutine.wrap(function()
	wait(2)if not workspace.Map:FindFirstChild("Builds") then return end
	workspace:GetPropertyChangedSignal("DistributedGameTime"):Connect(function()
		if math.floor(workspace.DistributedGameTime) ~= Secs then
			Secs = math.floor(workspace.DistributedGameTime)
			workspace.Map.Builds.SpawnArea.shaft.Shack["big room"].age.SurfaceGui.TextLabel.Text = "Server Age: ".. _L.Functions.FormatH_M(Secs)
		end
	end)
end)()

coroutine.wrap(function()
	require(game.ServerStorage.Storage.Assets.Modules.ItemsData):Init()
end)()

coroutine.wrap(function()
	wait(2)if not workspace.Map:FindFirstChild("Builds") then return end
	if not workspace:FindFirstChild("CoinsSpawners") or not workspace:FindFirstChild("Coins") then return end
	local TweenService = game:GetService('TweenService')
	local function SpawnCoin(pos)
		local newCoin = game.ServerStorage.Storage.Assets.Coin:Clone()
		newCoin.Position = pos
		newCoin.Center.Position = pos
		newCoin.Size = Vector3.new(0.4,0.054200000000000005,0.4)
		TweenService:Create(newCoin,TweenInfo.new(0.25,Enum.EasingStyle.Bounce,Enum.EasingDirection.In),{Size = Vector3.new(2, 0.271, 2)}):Play()
		newCoin.Parent = workspace.Coins
		return newCoin
	end
	for _,cSpawner in pairs(workspace.CoinsSpawners:GetDescendants()) do
		if cSpawner:IsA('Part') then
			coroutine.wrap(function()
				local CustomAmount = cSpawner:FindFirstChild("CustomAmount")
				local RespawnDelay = (cSpawner:FindFirstChild("RespawnDelay") or 35)

				local function Do()
					local newCoin = SpawnCoin(cSpawner.Position)
					local cd,con = false,nil
					con = newCoin.Touched:Connect(function(Hit)
						if Hit.Parent then
							local Player = game.Players:GetPlayerFromCharacter(Hit.Parent)
							if Player then
								if cd then return end
								cd = true
								con:Disconnect()
								local PlayerFunction = PlayerModule.PlayerFunctions[Player]
								if PlayerFunction then
									if CustomAmount then
										PlayerFunction.CollectedCoin(CustomAmount)
									else
										PlayerFunction.CollectedCoin()
									end
									TweenService:Create(newCoin,TweenInfo.new(0.25,Enum.EasingStyle.Back,Enum.EasingDirection.Out),{Size = Vector3.new(0,0,0)}):Play()
									game.Debris:AddItem(newCoin,0.69)
									delay(RespawnDelay,function()
										Do()
									end)
								else
									warn("No PlayerFunction found for player " .. Player.Name)
								end
							end
						end
					end)
				end
				Do()
			end)()
		end
	end
end)()

coroutine.wrap(function()
	wait(2)if not workspace.Map.InteractingParts.Milks:FindFirstChild("Cactus Milk Carton") then return end
	local cd_ = false
	workspace.Map.InteractingParts.Milks["Cactus Milk Carton"].Touched:Connect(function()
		if cd_ then return end
		cd_ = true
		workspace.Map.InteractingParts.Milks["Cactus Milk Carton"].Sound:Play()
		delay(1.5,function()
			cd_ = false
		end)
	end)
end)()

return GameModule