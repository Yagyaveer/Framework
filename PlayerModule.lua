local _L coroutine.wrap(function()_L = require(script.Parent.Library)end)()

local MarketplaceService = game:GetService('MarketplaceService')
local TweenService = game:GetService('TweenService')
local MilksByZoneData = require(game.ServerStorage.Storage.Items.Milks.MilksByZone)
local PlayerModule = {}
PlayerModule.PlayerFunctions = {}

function PlayerModule.new(Player_Object, Profile_Table)
	if Player_Object == nil then return error("PlayerModule:Create New PFunc: Player Object nil") end
	if Profile_Table == nil then return error("PlayerModule:Create New PFunc: Profile_Table nil") end
	local self = {}
	self.Player = Player_Object
	self.Profile = Profile_Table
	self.Maid = _L.Maid.new()
	self.Disconnected = false
	self.UIFunctions = {}
	self.TempData = {
		CurrentOverHeadUI = nil,
		InventoryTemps = {},
		Sprint = false,
		SpawnCooldown = false,
		TouchCoolDown = false,
		PrevSec_ = 0,
		CurrentDonationLBHeader = nil,
		CurrentTimePlayedLBHeader = nil,
		TempMilkData = {CanCollect_SleepyMilk = false,CanCollectMushroomMilk = false},
		LBFolder = nil,
		CurrentDialogSelectPrompt = nil,
		StrawberryMilkCounter = nil,
		DoorTouchCoolDown = false,
		InventoryData = {Functions = {}, InventoryDisplayTemps = {}},
		GamepassData = {
			OwnsGravityCoil = false,
			OwnsSpeedCoil = false,
			OwnsFusionCoil = false,
			OwnsFlingGlove = false,
			OwnsBlower = false,
			OwnsGrappleHook = false,
			OwnsMagicCarpet = false,
			OwnsDoubleCoins = false,
			OwnsHandGun = false,
			OwnsTp = false
		},
		CurrentToolEquipped = nil,
		CanCollectMushroomMilk = false,
		ItemsEquipUnEquipData = {Functions = {}, Cooldowns = {}},
		ItemsBuyingInProcess = {Common = nil, Rare = nil, Epic = nil, Legendary = nil},
		TrailAttachments = {one = nil, two = nil},
		MinsPassed = 0,
		CollectRewardButtonInited = {}
	}
	self.PlayerStoredData = self.Profile.Data

	--// Functions
	function self.Disconnect()
		if self == nil then return end
		if self.Disconnected == nil then return end
		if self.Disconnected == true then return end
		self.Disconnected = true
		self.Maid:Destroy()
		PlayerModule.PlayerFunctions[self.Player] = nil
		table.clear(self)
		self = nil
	end

	local function awaitObj(ObjectToSearchIn,InstanceToSearch, Timeout)
		local found = nil
		local t = tick()
		repeat
			found = (ObjectToSearchIn:FindFirstChild(InstanceToSearch) or nil)
		until found ~= nil or ObjectToSearchIn == nil or (tick()-t) >= (Timeout or 2.5) or self==nil or self.Disconnected or self.Player == nil
		return found
	end

	function self.LoadCharacterUtils(Character, attempt)
		local succ,err = pcall(function()
			if Character == nil then
				if attempt == nil then
					attempt = 1
				end
				if attempt <=20 then
					attempt += 1
					self.LoadCharacterUtils(Character, attempt)
				end
				return
			end
			if not Character:FindFirstChild("HumanoidRootPart") then
				if attempt == nil then
					attempt = 1
				end
				if attempt <=20 then
					attempt += 1
					self.LoadCharacterUtils(Character, attempt)
				end
				return
			end
			Character:WaitForChild("HumanoidRootPart")
			if self.TempData.CurrentOverHeadUI ~= nil and typeof(self.TempData.CurrentOverHeadUI) == 'Instance' then
				self.TempData.CurrentOverHeadUI:Destroy()
			end
			self.TempData.CurrentOverHeadUI = _L.PlrUtils.CharacterUtils.AddOverHeadUI(self, Character)
			_L.Functions.Network.Fire("CHANGESKY_QGNQ", self.Player, "Default_Sky")
			local TrailAttachments = game.ServerStorage.Storage.Assets.TrailAttachments
			local _One = TrailAttachments._trailone:Clone()
			local _Two = TrailAttachments._trailtwo:Clone()
			self.Maid:GiveTask(_One)
			self.Maid:GiveTask(_Two)
			self.TempData.TrailAttachments.one = _One
			self.TempData.TrailAttachments.two = _Two
			_One.Parent = Character['HumanoidRootPart']
			_Two.Parent = Character['HumanoidRootPart']
			delay(0.420,function() if self==nil or self.Disconnected or self.Player == nil then return end
				self.ForceEquipItems()
			end)
		end)
		if not succ then print(err) end
	end

	--// UI
	function self.InitUI()
		local PlayerGui = self.Player:WaitForChild("PlayerGui", 10)
		if self==nil or self.Disconnected or self.Player == nil then return end
		local UI = PlayerGui:WaitForChild("UI",10)
		if self==nil or self.Disconnected or self.Player == nil then return end

		self.UI = UI

		-- Milk Inventory
		local MilkFrame = UI.MilkFrame
		coroutine.wrap(function()
			local Milks = game.ServerStorage.Storage.Items.Milks.Milks
			self.TempData.RarityData = {
				Easy = Color3.fromRGB(116, 251, 76),
				Normal = Color3.fromRGB(0, 170, 255),
				Medium = Color3.fromRGB(255, 255, 0),
				Hard = Color3.fromRGB(255, 0, 0),
				Extreme = Color3.fromRGB(170, 85, 255),
				EasyLayoutOrder = 1,
				NormalLayoutOrder = 2,
				MediumLayoutOrder = 3,
				HardLayoutOrder = 4,
				ExtremeLayoutOrder = 5,}
			local RarityData = self.TempData.RarityData
			self.TempData.CurrentMilkSelected = {
				Easy = nil,
				Normal = nil,
				Medium = nil,
				Hard = nil,
				Extreme = nil,
				Current = nil,
			}

			function self.GetMilkVal(MilkName)
				local Milk_ = nil
				for _,v in pairs(Milks:GetChildren()) do
					if v:IsA("ObjectValue") then
						if v.Name == MilkName then
							Milk_ = v
							break
						end
					end
				end
				return Milk_
			end
			function self.PlayerHasMilk(MilkStr)
				local Has_ = false
				for _,v in pairs(self.Profile.Data.MilkFound) do
					if tostring(v) == tostring(MilkStr) then
						Has_ = true
						break
					end
				end
				return Has_
			end

			local CurrentMilkSelected_dat = nil
			local ClickCooldown,CurrentMaidId = false,nil
			local function ClickedMilkTemp(NewTemp, Milk)
				if ClickCooldown then return end
				ClickCooldown = true
				CurrentMilkSelected_dat = {NewTemp,Milk}
				for _,v in pairs(self.TempData.InfoFrame.Container:GetChildren()) do if v:IsA('ImageButton') then v:Destroy() end end
				local ClonnedTemp = NewTemp:Clone()
				CurrentMaidId = self.Maid:GiveTask(ClonnedTemp)
				ClonnedTemp.Size = UDim2.new(1,0,1,0)
				ClonnedTemp.Parent = self.TempData.InfoFrame.Container
				MilkFrame.InfoFrame.HintLabel.Text = "Hint: [Click to reveal]"
				self.TempData.InfoFrame.NameLabel.Text = ClonnedTemp.NameLabel.Text
				self.TempData.InfoFrame.HintLabel.hint.Value = Milk.Hint.Value
				self.TempData.InfoFrame.DescLabel.Text = Milk.Desc.Value
				self.TempData.InfoFrame.DiffLabel.Text = "Difficulty: <font color='rgb("..( ( tostring(math.floor(tonumber(RarityData[Milk.Rarity.Value].R)*255))..","..tostring(math.floor(tonumber(RarityData[Milk.Rarity.Value].G)*255))..","..tostring(math.floor(tonumber(RarityData[Milk.Rarity.Value].B)*255))) or "255,255,255") ..")'>" .. Milk.Rarity.Value .. "</font>"
				self.TempData.InfoFrame.Visible = true
				self.TempData.CurrentMilkSelected.Current = Milk --<<
				if self.PlayerHasMilk(Milk.Name) then
					self.TempData.InfoFrame.Buy.Text = "[Owned]"
					self.TempData.InfoFrame.Buy.BackgroundColor3 = Color3.fromRGB(69, 69, 69)
				else
					local RarityPrices = {Easy = "50",Normal = "100",Medium = "250",Hard = "500",Extreme = "1,000",}
					self.TempData.InfoFrame.Buy.Text = "Buy R$" .. (RarityPrices[Milk.Rarity.Value] or "[failed to load]")
					self.TempData.InfoFrame.Buy.BackgroundColor3 = Color3.fromRGB(0, 255, 0)
				end
				MilkFrame.InfoFrame.HintLabel.Text = "Hint: [Click to reveal]"
				delay(1,function()  if self==nil or self.Disconnected or self.Player == nil then return end
					ClickCooldown = false
				end)
			end

			function self.UpdateInvUI()
				for _,data in pairs(self.TempData.InventoryTemps) do
					local Has_ = self.PlayerHasMilk(data.Name)
					data.Temp.Owned.Visible = not Has_
				end
				MilkFrame.Found.Text = "(" .. tostring(math.min(#self.Profile.Data.MilkFound,(#Milks:GetChildren()))).. "/" .. tostring(#Milks:GetChildren())..") FOUND"
				if CurrentMilkSelected_dat ~= nil then
					ClickedMilkTemp(CurrentMilkSelected_dat[1], CurrentMilkSelected_dat[2])
				end
				if self.UpdateProgressUI then self.UpdateProgressUI() end
			end

			self.TempData.InfoFrame = MilkFrame.InfoFrame

			function self.MakeMilkUI()
				for _,Milk in pairs(Milks:GetChildren()) do
					local suc,err = pcall(function()
						--if Milk.Value ~= nil then
						local NewTemp = game.ServerStorage.Storage.Assets.Template:Clone()
						self.Maid:GiveTask(NewTemp)
						NewTemp.NameLabel.Text = Milk.Name
						NewTemp.RarityColor.BackgroundColor3 = (RarityData[Milk.Rarity.Value] or Color3.new(1,1,1))
						NewTemp.RarityColor.rarityname.Value = Milk.Rarity.Value
						NewTemp.ImageLabel.Image = Milk.Image.Value
						--NewTemp.LayoutOrder = (RarityData[Milk.Rarity.Value .. "LayoutOrder"] or 0)
						local succX, errR = pcall(function()
							NewTemp:SetAttribute("rarity", (Milk.Rarity.Value or 0))
							NewTemp:SetAttribute("zone", (_L.Functions.FindMilkZoneByName(MilksByZoneData, Milk.Name) or "nil"))
						end)
						if not succX then print(errR) end
						table.insert(self.TempData.InventoryTemps, {Name = Milk.Name, Temp = NewTemp})
						NewTemp.Parent = MilkFrame.Container
						self.Maid:GiveTask(NewTemp.MouseButton1Click:Connect(function() ClickedMilkTemp(NewTemp,Milk) end))
						--end
					end) if not suc then warn("Unable to make milk template for player " .. Player_Object.Name .. ",\nError:",err, "\nMilkName:", (Milk.Name or "unable to get Milk.Name")) end
				end
				coroutine.wrap(function()
					local suc,err = pcall(function()
						for zone,value in pairs(MilksByZoneData) do
							local remainder = (4 - (#value % 4)) % 4
							if remainder ~= 0 then
								for i = 1, remainder do
									local BlankTemp = game.ServerStorage.Storage.Assets.Blank:Clone()
									self.Maid:GiveTask(BlankTemp)
									BlankTemp.Parent = MilkFrame.Container
									BlankTemp:SetAttribute("zone", zone)
								end
							end
						end
					end)
					if not suc then warn("Unable to make blank milk template for player") end
				end)()
				self.UpdateInvUI()
			end

			coroutine.wrap(function()
				self.MakeMilkUI()

				self.Maid:GiveTask(MilkFrame.InfoFrame.Close.MouseButton1Click:Connect(function()
					self.TempData.InfoFrame.Visible = false
					CurrentMilkSelected_dat = nil
					MilkFrame.InfoFrame.HintLabel.Text = "Hint: [Click to reveal]"
					if self.Maid[CurrentMaidId] then
						self.Maid[CurrentMaidId] = nil
					end
				end))
				local buyclickcooldown = false
				self.Maid:GiveTask(self.TempData.InfoFrame.Buy.MouseButton1Click:Connect(function()
					if buyclickcooldown then return end
					buyclickcooldown = true
					if self.TempData.CurrentMilkSelected.Current ~= nil then
						if self.PlayerHasMilk(self.TempData.CurrentMilkSelected.Current.Name) ~= true then
							local Rarity = self.TempData.CurrentMilkSelected.Current.Rarity.Value
							local RarityIds = {
								Easy = 1261189301,
								Normal = 1261189359,
								Medium = 1261189411,
								Hard = 1261189458,
								Extreme = 1261189528,
							}
							if RarityIds[Rarity] then
								self.TempData.CurrentMilkSelected[Rarity] = self.TempData.CurrentMilkSelected.Current
								MarketplaceService:PromptProductPurchase(self.Player,RarityIds[Rarity])
							else
								warn("No id fond for rarity:" .. Rarity)
							end
						end
					end
					delay(3.5,function() if self==nil or self.Disconnected or self.Player == nil then return end
						buyclickcooldown = false
					end)
				end))
				self.Maid:GiveTask(MilkFrame.InfoFrame.HintLabel.MouseButton1Click:Connect(function()
					MilkFrame.InfoFrame.HintLabel.Text = "Hint: " .. MilkFrame.InfoFrame.HintLabel.hint.Value
				end))
			end)()

			--// Daily Milks
			coroutine.wrap(function()
				self.TempData.DailyMilkRarity = {
					Easy = 50,
					Normal = 25,
					Medium = 15,
					Hard = 8,
					Extreme = 2,
				}
				self.TempData.CurrentDailyMilks = {}

				function self.AssignDailyMilk()
					local TotalWeight = 0
					for _,Milk in pairs(Milks:GetChildren()) do
						TotalWeight = TotalWeight + self.TempData.DailyMilkRarity[Milk.Rarity.Value]
					end
					local function chooseRandomMilk()
						local Chance = math.random(1,TotalWeight)
						local Counter = 0
						for _,Milk in pairs(Milks:GetChildren()) do
							Counter = Counter + self.TempData.DailyMilkRarity[Milk.Rarity.Value]
							if Chance <= Counter then
								return Milk
							end
						end
					end

					local milkSelected = {}
					while #milkSelected ~= 8 do
						local chosen = chooseRandomMilk()
						if chosen.Name ~= "Strawberry Milk" then
							if #milkSelected == 0 then
								table.insert(milkSelected,chosen)
							else
								local alreadyinserted = false
								for _,v in pairs(milkSelected) do
									if v.Name == chosen.Name then
										alreadyinserted = true
										break
									end
								end
								if alreadyinserted == false then
									table.insert(milkSelected,chosen)
								end
							end
						end
					end
					table.clear(self.Profile.Data.DailyMilk)
					for _,v in pairs(milkSelected) do
						table.insert(self.Profile.Data.DailyMilk,v.Name)
					end

				end

				--self.AssignDailyMilk()

				function self.MakeDailyMilk()

					for _,milkName in pairs(self.Profile.Data.DailyMilk) do
						coroutine.wrap(function()
							local MilkVal = self.GetMilkVal(milkName)

						end)()
					end
				end

			end)()
		end)()

		-- Settings
		local SettingsFrame = UI.SettingsFrame
		coroutine.wrap(function()
			local function MusicMU()
				if self.Profile.Data.Settings.MuteMusic then
					UI.Music.Volume = 0
				else
					UI.Music.Volume = 1
				end
				SettingsFrame.Music.disabled.Visible = self.Profile.Data.Settings.MuteMusic
			end
			local function TBarTToggle()
				if self.Profile.Data.Settings.TBarToggle then
					SettingsFrame.TBarToggle.Text = "?"
					self.UI.ToolBar.ToolBar.UIPageLayout.TouchInputEnabled = true
				else
					SettingsFrame.TBarToggle.Text = " "
					self.UI.ToolBar.ToolBar.UIPageLayout.TouchInputEnabled = false
				end
			end
			coroutine.wrap(MusicMU)()
			coroutine.wrap(TBarTToggle)()
			self.Maid:GiveTask(SettingsFrame.Music.MouseButton1Click:Connect(function()
				self.Profile.Data.Settings.MuteMusic = not self.Profile.Data.Settings.MuteMusic
				SettingsFrame.Music.disabled.Visible = self.Profile.Data.Settings.MuteMusic
				MusicMU()
			end))
			self.Maid:GiveTask(SettingsFrame.TBarToggle.MouseButton1Click:Connect(function()
				self.Profile.Data.Settings.TBarToggle = not self.Profile.Data.Settings.TBarToggle
				TBarTToggle()
			end))
		end)()

		--Shop
		local ShopFrame = UI.ShopFrame
		coroutine.wrap(function()
			local sucUtl,errUtl = pcall(function()
				local function RegisterBtn(Button, ProductId, g)
					local function p()
						if g then
							MarketplaceService:PromptGamePassPurchase(self.Player,ProductId)
						else
							MarketplaceService:PromptProductPurchase(self.Player,ProductId)
						end
					end
					self.Maid:GiveTask(Button.MouseButton1Click:Connect(p))
					self.Maid:GiveTask(Button.PurchaseFrame.Buy.MouseButton1Click:Connect(p))
				end
				local ProductsF = ShopFrame.Products.Container
				RegisterBtn(ProductsF.DevProducts["KillAll"], 1261427956)
				RegisterBtn(ProductsF.DevProducts["500Coins"], 1266559885)
				RegisterBtn(ProductsF.DevProducts["1_25k_coins"], 1266559917)
				RegisterBtn(ProductsF.DevProducts_2["6.5k Coins"], 1266559945)
				RegisterBtn(ProductsF.DevProducts_2["12.5k Coins"], 1266559995)
				RegisterBtn(ProductsF.DevProducts_2["25k Coins"], 1266560059)

				RegisterBtn(ProductsF.Gamepass["GCoil"], 42687770,true)
				RegisterBtn(ProductsF.Gamepass["SCoil"], 42687988,true)
				RegisterBtn(ProductsF.Gamepass["FCoil"], 42688142,true)
				RegisterBtn(ProductsF.Gamepass_2["FlingGlove"], 42803975,true)
				RegisterBtn(ProductsF.Gamepass_2["Blower"], 42804068,true)
				RegisterBtn(ProductsF.Gamepass_2["GrappleHook"], 43150904,true)
				RegisterBtn(ProductsF.Gamepass_3["MagicCarpet"], 43633906,true)
				RegisterBtn(ProductsF.Gamepass_3["2xCoins"], 48899382,true)
				RegisterBtn(ProductsF.Gamepass_3["Handgun"], 48899382,true)
				RegisterBtn(ProductsF.Gamepass_4["tp"], 720828709,true)
			end) if not sucUtl then print("Unable to util UI part for " .. self.Player.Name .. ": " .. errUtl) end
		end)()

		-- Teleport UI
		coroutine.wrap(function()
			local TeleportFrame = UI:FindFirstChild("TeleportFrame")

			local function GetNoOfMilksFoundByZone(Zone)
				local count = 0
				for _, itemA in ipairs(Zone) do
					for _, itemB in ipairs(self.Profile.Data.MilkFound) do
						if itemA == itemB then
							count = count + 1
							break
						end
					end
				end
				return count
			end

			local function getMapCompletionRatio()
				local count = 0

				local function allItemsExistInTableA(tbl)
					for _, item in ipairs(tbl) do
						if not self.Profile.Data.MilkFound[item] then
							return false
						end
					end
					return true
				end

				for _, tbl in pairs(MilksByZoneData) do
					if allItemsExistInTableA(tbl) then
						count = count + 1
					end
				end
				return count .. "/" .. 8
			end

			function self.UpdateProgressUI()
				local succ,err = pcall(function()
					for i,v in pairs(MilksByZoneData) do
						coroutine.wrap(function()
							local FrameFound = TeleportFrame.Container:FindFirstChild(i)
							local Collected,CanCollect = false,false
							if GetNoOfMilksFoundByZone(MilksByZoneData[i]) == #v then
								if not self.Profile.Data.RewardsCollected[i] then
									if not self.TempData.CollectRewardButtonInited[i] then
										CanCollect = true
										self.TempData.CollectRewardButtonInited[i] = self.Maid:GiveTask(FrameFound.CollectButton.MouseButton1Click:Connect(function()
											self.Profile.Data.RewardsCollected[i] = i
											self.Maid[self.TempData.CollectRewardButtonInited[i]] = nil
											self.Profile.Data.Coins += _L.DataIndex.ZoneRewards[i] or 1
											Collected = true
											self.UpdateProgressUI()
										end))
									end
								else
									Collected = true
								end
							elseif self.Profile.Data.RewardsCollected[i] then
								Collected = true
							end
							if FrameFound then
								local _Current = GetNoOfMilksFoundByZone(MilksByZoneData[i])
								local _Max = #MilksByZoneData[i]
								FrameFound.Progress.Desc.Text = _Current .. "/" .. _Max
								if Collected then
									FrameFound.CollectButton.Text = "  COLLECTED  "
									FrameFound.CollectButton.Amount.Text = _L.DataIndex.ZoneRewards[i]
									FrameFound.CollectButton.BackgroundColor3 = Color3.fromRGB(71, 71, 71)
								elseif Collected == false and CanCollect then
									FrameFound.CollectButton.Text = "   COLLECT   "
									FrameFound.CollectButton.Amount.Text = _L.DataIndex.ZoneRewards[i]
									FrameFound.CollectButton.BackgroundColor3 = Color3.fromRGB(255, 215, 0)
								else
									FrameFound.CollectButton.Text = "   COLLECT   "
									FrameFound.CollectButton.Amount.Text = _L.DataIndex.ZoneRewards[i]
									FrameFound.CollectButton.BackgroundColor3 = Color3.fromRGB(115, 115, 115)
								end
								_L.Statistics.UpdateProgressBar(FrameFound.Progress.Fill, _Current, _Max)
							end
							local FrameFound2 = MilkFrame.Container:FindFirstChild(i)
							if FrameFound2 then
								FrameFound2 = FrameFound2:FindFirstChild(i)
								local _Current = GetNoOfMilksFoundByZone(MilksByZoneData[i])
								local _Max = #MilksByZoneData[i]
								FrameFound2.Progress.Desc.Text = _Current .. "/" .. _Max
								_L.Statistics.UpdateProgressBar(FrameFound2.Progress.Fill, _Current, _Max)
							end
						end)()
					end
					TeleportFrame.Found.Text = "("..getMapCompletionRatio()..") COMPLETED"
				end)
				if not succ then
					print("Unable to update progress/tp UI:", err)
				end
			end
			self.UpdateProgressUI()

			local succ,err = pcall(function()
				for i,v in pairs(TeleportFrame.Container:GetChildren()) do
					if v:IsA("Frame") then
						if MilksByZoneData[v.Name] then
							if v.Name == game.ReplicatedStorage:FindFirstChild("PlaceName").Value then
								v.Button.Text = "\nSTAY HERE\n"
								v.Button.BackgroundColor3 = Color3.fromRGB(115, 115, 115)
								v.Button.Name = "ButtonStayHere"
							else
								self.Maid:GiveTask(v.Button.MouseButton1Click:Connect(function()
									if self.TempData.GamepassData.OwnsTp then
										local succk,errk = pcall(function()
											if _L.Functions.Portals[v.Name] then
												_L.Functions.InitTeleportation(self.Player,_L.Functions.Portals[v.Name].PrestigeNeed,_L.Functions.Portals[v.Name].PlaceId,_L.Functions.Portals[v.Name].PlaceId_TESTING,2)
											else
												print("error: portal data not found in _L.Functions.Portals")
											end
										end)
										if not succk then print("Error while tping:",errk) end
									else
										MarketplaceService:PromptGamePassPurchase(self.Player,720828709)
									end
								end))
							end
						else
							print("Error: v not found in MilksByZoneData[v.Name]",v.Name)
						end
					end
				end
			end)
			if not succ then print("Unable to init teleport ui:",err) end
		end)()

		-- Buttons
		local Buttons = UI.Buttons
		coroutine.wrap(function()
			self.Maid:GiveTask(Buttons.Sprint.MouseButton1Click:Connect(function()
				self.TempData.Sprint = not self.TempData.Sprint
			end))
			self.Maid:GiveTask(Buttons.Spwan.MouseButton1Click:Connect(function()
				if self.TempData.SpawnCooldown == false then
					self.TempData.SpawnCooldown = true
					self.Player.Character:MoveTo(workspace.Map.SpawnLocation.Position)
					_L.Functions.Network.Fire("CHANGESKY_QGNQ", self.Player, "Default_Sky")
					delay(2.1,function() if self==nil or self.Disconnected or self.Player == nil then return end
						self.TempData.SpawnCooldown = false
					end)
				end
			end))

		end)()

		--popups
		local function PopUp(Context, Explaination, YesText, NoText, CloseButton)
			local OldFrame,OldFrame2,OldFrame3 = self.UI:FindFirstChild("PopUpYN"),self.UI:FindFirstChild("PopUpC"),self.UI:FindFirstChild("InfoPopUp")
			if (OldFrame) then OldFrame:Destroy() end if (OldFrame2) then OldFrame2:Destroy() end if (OldFrame3) then OldFrame3:Destroy() end self.UI.NotEnoughCoinsPopup_.Visible = false
			local Frame = self.UI.PopUpYN_:Clone()
			self.Maid:GiveTask(Frame)
			Frame.Name = "PopUpYN"
			Frame.Context.Text = tostring(Context)
			Frame.Explanation.Text = (Explaination or "")
			Frame.Y.TextLabel.Text = (YesText or "YES")
			Frame.N.TextLabel.Text = (NoText or "NO")
			Frame.Visible = true
			Frame.Parent = self.UI
			Frame.LocalScript.Disabled = false
			return Frame
		end
		self.UIFunctions.PopUpFrame = PopUp
		function self.UIFunctions.PopUpInfoFrame2(Context, CloseButtonText)
			local OldFrame,OldFrame2,OldFrame3 = self.UI:FindFirstChild("PopUpYN"),self.UI:FindFirstChild("PopUpC"),self.UI:FindFirstChild("InfoPopUp")
			if (OldFrame) then OldFrame:Destroy() end if (OldFrame2) then OldFrame2:Destroy() end if (OldFrame3) then OldFrame3:Destroy() end self.UI.NotEnoughCoinsPopup_.Visible = false
			local Frame = self.UI.InfoPopUp_:Clone()
			self.Maid:GiveTask(Frame)
			Frame.Name = "InfoPopUp"
			Frame.Context.Text = tostring(Context)
			Frame.CloseButton.TextLabel.Text = (CloseButtonText or "CLOSE")
			Frame.Visible = true
			Frame.Parent = self.UI
			Frame.LocalScript.Disabled = false
			return Frame
		end
		function self.UIFunctions.NotEnoughCoinsPopup()
			local OldFrame,OldFrame2,OldFrame3 = self.UI:FindFirstChild("PopUpYN"),self.UI:FindFirstChild("PopUpC"),self.UI:FindFirstChild("InfoPopUp")
			if (OldFrame) then OldFrame:Destroy() end if (OldFrame2) then OldFrame2:Destroy() end if (OldFrame3) then OldFrame3:Destroy() end self.UI.NotEnoughCoinsPopup_.Visible = false
			local Frame = self.UI.NotEnoughCoinsPopup_
			Frame.Visible = true
			return Frame
		end

		-- Effects Inventory
		local InventoryFrame = self.UI:WaitForChild("InventoryFrame")
		local BuyCoolDown = false

		coroutine.wrap(function()
			local ItemsData = require(game.ServerStorage.Storage.Assets.Modules.ItemsData)
			local RarityColor = {
				Common = Color3.fromRGB(116, 251, 76),
				Rare = Color3.fromRGB(0, 0, 245),
				Epic = Color3.fromRGB(234, 51, 247),
				Legendary = Color3.fromRGB(255, 255, 84),
				CommonLayoutOrder = 1,
				RareLayoutOrder = 2,
				EpicLayoutOrder = 3,
				LegendaryLayoutOrder = 4
			}

			local function GetItemFromName(ItemName)
				local Item_ = nil
				for _,v in pairs(ItemsData.InventoryItems) do
					if v.Name == ItemName then
						Item_ = v
						break
					end
				end
				return Item_
			end
			local function GetItemFromPlayerInventory(ItemName)
				local Item_ = nil
				for _,v in pairs(self.Profile.Data.Inventory)  do
					if v.Name == ItemName then
						Item_ = v
						break
					end
				end
				return Item_
			end
			local function PlayerHasItem(ItemName)
				local ItemFound = GetItemFromName(ItemName)
				if ItemFound == nil then if ItemName == nil then print("Inventory Error: Item not found in the inventory's item table: " .. ItemName) end return false end
				local Has_ = false
				for _,v in pairs(self.Profile.Data.Inventory) do
					if v.Name == ItemFound.Name then
						Has_ = true
						break
					end
				end
				return Has_
			end
			self.TempData.PlayerHasItem = PlayerHasItem

			function self.TempData.InventoryData.Functions.UpdateInventoryDisplay()
				for _,Data in pairs(self.TempData.InventoryData.InventoryDisplayTemps) do
					local HasItem = PlayerHasItem(Data.ItemName)
					if HasItem == true then
						Data.Temp.Owned.Visible = false
						Data.Temp.LayoutOrder = -math.abs(Data.Temp.LayoutOrder)
						local PlayerInventoryItemData = GetItemFromPlayerInventory(Data.ItemName)
						if PlayerInventoryItemData ~= nil then
							if PlayerInventoryItemData.Equipped == true then
								Data.Temp.BackgroundColor3 = Color3.fromRGB(0, 30, 0)
							else
								Data.Temp.BackgroundColor3 = Color3.fromRGB(42, 42, 42)
							end
						end
					else
						Data.Temp.Owned.Visible = true
						Data.Temp.LayoutOrder = math.abs(Data.Temp.LayoutOrder)
						Data.Temp.BackgroundColor3 = Color3.fromRGB(42, 42, 42)
					end
				end
			end

			local function MakeItemsUI()
				for i,v in pairs(ItemsData.InventoryItems) do
					local suc,err = pcall(function()
						local NewTemp = game.ServerStorage.Storage.Assets.InventoryTemplate:Clone()
						self.Maid:GiveTask(NewTemp)
						NewTemp.Name = v.Name
						NewTemp.Type.Value = v.Type
						NewTemp.NameLabel.Text = v.Name
						--print(v.Name)
						NewTemp.RarityFrame.BackgroundColor3 = (RarityColor[v.RarityName] or Color3.new(1,1,1))
						NewTemp.LayoutOrder = (RarityColor[v.RarityName.."LayoutOrder"] or i)
						local CustomImage = game.ServerStorage.Storage.Assets.ItemsImage:FindFirstChild(v.Name)
						if v.Type == "Trails" then
							NewTemp.TrailFrame.Visible = true
							NewTemp.TrailFrame.UIGradient.Color = (v.Item.Color or ColorSequence.new({ColorSequenceKeypoint.new(0,Color3.new(1,1,1)),ColorSequenceKeypoint.new(1,Color3.new(1,1,1))}))
						elseif v.Type == "Halos" then
							NewTemp.Halo.Visible = true
							NewTemp.Halo.ImageColor3 = v.Item.Handle.Color
							if (CustomImage) then
								NewTemp.Halo.Image = CustomImage.Image
							end
							if (v.Item:FindFirstChild("IsCrown")) then
								NewTemp.Halo.Image = "rbxassetid://8173689292"
							end
						end
						self.Maid:GiveTask(NewTemp.MouseButton1Click:Connect(function()
							self.TempData.InventoryData.Functions.UpdateInventoryDisplay()
							if PlayerHasItem(v.Name) == false then
								if v.Type == "Trails" then
									coroutine.wrap(function()
										local suc,err = self.BuyItemFromRobux(v.Name)
										if suc == false then
											print(err)
										end
									end)()
								elseif v.Type == "Halos" then
									if v.Name == "Golden Halo" then
										local PopUpYN = PopUp('Would you like to buy <font color="rgb(255, 255, 0)">Golden Halo</font> for <font color="rgb(255, 255, 70)">500K Coins</font>?')
										local c1,c2,d1
										c1 = self.Maid:GiveTask(PopUpYN.Y.MouseButton1Click:Connect(function()
											if BuyCoolDown then return end
											BuyCoolDown = true
											if self.PlayerStoredData.Coins >= 500000 then
												self.PlayerStoredData.Coins -= 500000
												self.AddItemInInventory("Golden Halo")
											else
												self.UIFunctions.NotEnoughCoinsPopup()
											end
											PopUpYN:Destroy()
											self.Maid[c1] = nil
											self.Maid[c2] = nil
											self.Maid[d1] = nil
											delay(1,function() if self==nil or self.Disconnected or self.Player == nil then return end
												BuyCoolDown = false
											end)
										end))
										c2 = self.Maid:GiveTask(PopUpYN.N.MouseButton1Click:Connect(function()
											self.Maid[c1] = nil
											self.Maid[c2] = nil
											self.Maid[d1] = nil
											PopUpYN:Destroy()
										end))
										d1 = self.Maid:GiveTask(PopUpYN.Destroying:Connect(function()
											self.Maid[c1] = nil
											self.Maid[c2] = nil
											self.Maid[d1] = nil
										end))
									else
										self.UIFunctions.PopUpInfoFrame2(tostring(ItemsData.HaloDesc[v.Name]))
									end
								end
							else
								self.EquipUnEquipItem(v.Name)
							end
						end))
						table.insert(self.TempData.InventoryData.InventoryDisplayTemps, {ItemName = v.Name, Temp = NewTemp})
						NewTemp.Parent = InventoryFrame.Container
					end)
					if not suc then print(err) end
				end
				self.TempData.InventoryData.Functions.UpdateInventoryDisplay()
			end

			local MakingInventorySuccess,MakingInventoryError = pcall(MakeItemsUI)
			if not MakingInventorySuccess then print(MakingInventoryError) end
			local UpdateInventoryDisplaySuccess,UpdateInventoryDisplayError = pcall(self.TempData.InventoryData.Functions.UpdateInventoryDisplay)
			if not UpdateInventoryDisplaySuccess then print(UpdateInventoryDisplayError) end

			function self.TempData.ItemsEquipUnEquipData.Functions.EquipTrail(TrailName)
				local PlayerInventoryItemData = GetItemFromPlayerInventory(TrailName)
				if PlayerInventoryItemData ~= nil then
					if PlayerHasItem(TrailName) then
						PlayerInventoryItemData.Equipped = true
						local TrailFound = GetItemFromName(TrailName)
						if TrailFound then
							--print(TrailFound)
							if self.TempData.TrailAttachments.one ~= nil and self.TempData.TrailAttachments.two ~= nil then
								local NewTrail = TrailFound.Item:Clone()
								self.Maid:GiveTask(NewTrail)
								NewTrail.Parent = self.Player.Character.HumanoidRootPart
								NewTrail.Attachment0 = self.TempData.TrailAttachments.one
								NewTrail.Attachment1 = self.TempData.TrailAttachments.two
							end
						end
					end
				end
			end
			function self.TempData.ItemsEquipUnEquipData.Functions.UnEquipTrail(TrailName)
				local PlayerInventoryItemData = GetItemFromPlayerInventory(TrailName)
				if PlayerInventoryItemData ~= nil then
					if PlayerHasItem(TrailName) then
						PlayerInventoryItemData.Equipped = false
						for _,v in pairs(self.Player.Character.HumanoidRootPart:GetChildren()) do
							if v:IsA('Trail') then
								v:Destroy()
							end
						end
						--local TrailFound = self.Player.Character.HumanoidRootPart:FindFirstChild(TrailName)
						--if TrailFound then
						--	TrailFound:Destroy()
						--end
					end
				end
			end
			function self.TempData.ItemsEquipUnEquipData.Functions.EquipHalo(HaloName)
				local PlayerInventoryItemData = GetItemFromPlayerInventory(HaloName)
				if PlayerInventoryItemData ~= nil then
					if PlayerHasItem(HaloName) then
						PlayerInventoryItemData.Equipped = true
						local HaloFound = GetItemFromName(HaloName)
						if HaloFound then
							local NewParticle = HaloFound.Item:Clone()
							self.Maid:GiveTask(NewParticle)
							NewParticle.Parent = self.Player.Character
						end
					end
				end
			end
			function self.TempData.ItemsEquipUnEquipData.Functions.UnEquipHalo(HaloName)
				local PlayerInventoryItemData = GetItemFromPlayerInventory(HaloName)
				if PlayerInventoryItemData ~= nil then
					if PlayerHasItem(HaloName) then
						PlayerInventoryItemData.Equipped = false
						local ParticleFound = self.Player.Character:FindFirstChild(HaloName)
						if ParticleFound then
							ParticleFound:Destroy()
						end
					end
				end
			end

			self.TempData.ItemsEquipUnEquipData.Cooldowns.TrailCD = false
			local function EquipUnEquipTrail(ItemData)
				if ItemData ~= nil then
					if ItemData.Equipped then
						self.TempData.ItemsEquipUnEquipData.Functions.UnEquipTrail(ItemData.Name)
					else
						self.TempData.ItemsEquipUnEquipData.Functions.EquipTrail(ItemData.Name)
					end
				end
			end
			local function EquipUnEquipHalo(ItemData)
				if ItemData ~= nil then
					if ItemData.Equipped then
						self.TempData.ItemsEquipUnEquipData.Functions.UnEquipHalo(ItemData.Name)
					else
						self.TempData.ItemsEquipUnEquipData.Functions.EquipHalo(ItemData.Name)
					end
				end
			end

			local ItemBuyIDs = {Common = 1268446763, Rare = 1268446841, Epic = 1268447027, Legendary = 1268447074}
			function self.BuyItemFromRobux(ItemName)
				local ItemData = GetItemFromName(ItemName)
				if ItemData ~= nil then
					if PlayerHasItem(ItemData.Name) == false then
						if (ItemData.Type):lower() == ("Trails"):lower() or (ItemData.Type):lower() == ("Particles"):lower() or (ItemData.Type):lower() == ("Auras"):lower() then
							if (ItemData.RarityName):lower() == ("Common"):lower() then
								self.TempData.ItemsBuyingInProcess.Common = ItemData.Name
								MarketplaceService:PromptProductPurchase(self.Player, ItemBuyIDs.Common)
							elseif (ItemData.RarityName):lower() == ("Rare"):lower() then
								self.TempData.ItemsBuyingInProcess.Rare = ItemData.Name
								MarketplaceService:PromptProductPurchase(self.Player, ItemBuyIDs.Rare)
							elseif (ItemData.RarityName):lower() == ("Epic"):lower() then
								self.TempData.ItemsBuyingInProcess.Epic = ItemData.Name
								MarketplaceService:PromptProductPurchase(self.Player, ItemBuyIDs.Epic)
							elseif (ItemData.RarityName):lower() == ("Legendary"):lower() then
								self.TempData.ItemsBuyingInProcess.Legendary = ItemData.Name
								MarketplaceService:PromptProductPurchase(self.Player, ItemBuyIDs.Legendary)
							else
								return false, "An unknown error ocurred 3."
							end
							return true
						else
							return false, "An unknown error ocurred 2."
						end
					else
						return false,"You already own the item"
					end
				else
					return false,"An unknown error ocurred 1."
				end
			end

			function self.BoughtItemFromRobux(ItemName)
				local ItemData = GetItemFromName(ItemName)
				if ItemData ~= nil then
					if PlayerHasItem(ItemName) == false then
						local retu = self.AddItemInInventory(ItemName)
						self.TempData.InventoryData.Functions.UpdateInventoryDisplay()
						if retu == true then
							return true
						else
							return false,"An unknown error ocurred"
						end
					else
						return false, "An error ocurred: Player already has item"
					end
				else
					return false, "An error ocurred: Item data not found"
				end
			end

			local EquipCooldown = false
			--delay(7,function() if self==nil or self.Disconnected or self.Player == nil then return end
			--	EquipCooldown = false
			--end)
			function self.TempData.ItemsEquipUnEquipData.Functions.DoEquipUnEquip(ItemName, EquipUnEquip, ForceEquip)
				if EquipCooldown then return end
				EquipCooldown = true
				local PlayerInventoryItemData = GetItemFromPlayerInventory(ItemName)
				for _,v in pairs(self.PlayerStoredData.Inventory) do
					if v.Name ~= ItemName then
						local PlayerInventoryItemData_ = GetItemFromPlayerInventory(v.Name)
						if PlayerInventoryItemData_ ~= nil and PlayerInventoryItemData ~= nil then
							if PlayerInventoryItemData_.Equipped == true then
								if (PlayerInventoryItemData_.Type):lower() == ("Trails"):lower() and (PlayerInventoryItemData.Type):lower() == ("Trails"):lower() then
									self.TempData.ItemsEquipUnEquipData.Functions.UnEquipTrail(v.Name)
								elseif (PlayerInventoryItemData_.Type):lower() == ("Halos"):lower() and (PlayerInventoryItemData.Type):lower() == ("Halos"):lower() then
									self.TempData.ItemsEquipUnEquipData.Functions.UnEquipHalo(v.Name)
								end
							end
						end
					end
				end
				for _,v in pairs(self.PlayerStoredData.Inventory) do
					if v.Name == ItemName then
						if PlayerHasItem(ItemName) then
							if PlayerInventoryItemData ~= nil then
								if (PlayerInventoryItemData.Type):lower() == ("Trails"):lower() then
									EquipUnEquipTrail(PlayerInventoryItemData)
								elseif (PlayerInventoryItemData.Type):lower() == ("Halos"):lower() then
									EquipUnEquipHalo(PlayerInventoryItemData)
								end
								self.TempData.InventoryData.Functions.UpdateInventoryDisplay()
							end
						end
					end
				end
				delay(0.1,function() if self==nil or self.Disconnected or self.Player == nil then return end
					EquipCooldown = false
				end)
			end

			function self.EquipUnEquipItem(ItemName)
				self.TempData.ItemsEquipUnEquipData.Functions.DoEquipUnEquip(ItemName, true, false)
			end

			function self.ForceEquipItems()
				if EquipCooldown then
					repeat wait() until EquipCooldown == false
				end
				EquipCooldown = true
				for _,v in pairs(self.PlayerStoredData.Inventory) do
					local PlayerInventoryItemData = GetItemFromPlayerInventory(v.Name)
					if PlayerInventoryItemData ~= nil then
						if PlayerInventoryItemData.Equipped == true then
							if (PlayerInventoryItemData.Type):lower() == ("Trails"):lower() then
								self.TempData.ItemsEquipUnEquipData.Functions.EquipTrail(v.Name)
							elseif (PlayerInventoryItemData.Type):lower() == ("Halos"):lower() then
								self.TempData.ItemsEquipUnEquipData.Functions.EquipHalo(v.Name)
							end
						end
					end
				end
				EquipCooldown = false
			end

			function self.AddItemInInventory(ItemName, CheckAdd, ObjAdd)
				local ItemDataFound = GetItemFromName(ItemName)
				if ItemDataFound ~= nil then
					if PlayerHasItem(ItemDataFound.Name) then
						if CheckAdd == false then
							print("Inventory error: Player already has Item: " .. ItemName)
						end
						if ObjAdd == true then
							return "Player already has Item."
						end
						return false
					end
					table.insert(self.PlayerStoredData.Inventory,{Name = tostring(ItemDataFound.Name), Type = tostring(ItemDataFound.Type), Equipped = false})
					coroutine.wrap(function()
						self.TempData.InventoryData.Functions.UpdateInventoryDisplay()
					end)()
					if ObjAdd == true then
						return "Added " .. ItemName .. " Into " .. self.Player.Name .. "'s Inventory."
					end
					return true
				else
					if ObjAdd == true then
						return "Item not found."
					end
					print("Inventory error: Item data not found to add in inventory: " .. ItemName)
					return false
				end
			end
			function self.RemoveItemInInventory(ItemName, CheckAdd, ObjRemove)
				local ItemDataFound = GetItemFromName(ItemName)
				if ItemDataFound ~= nil then
					if PlayerHasItem(ItemDataFound.Name) == false then
						if CheckAdd == false then
							print("Inventory error: Player already has Item: " .. ItemName)
						end
						if ObjRemove == true then
							return "Player does not own the Item."
						end
						return false
					end
					for i,v in pairs(self.PlayerStoredData.Inventory) do
						if v.Name == tostring(ItemDataFound.Name) then
							pcall(function()
								if v.Equipped == true then
									self.EquipUnEquipItem(v.Name)
								end
							end)
							table.remove(self.PlayerStoredData.Inventory,i)
						end
					end
					coroutine.wrap(function()
						self.TempData.InventoryData.Functions.UpdateInventoryDisplay()
					end)()
					if ObjRemove == true then
						return "Removed " .. ItemName .. " from " .. self.Player.Name .. "'s Inventory."
					end
					return true
				else
					if ObjRemove == true then
						return "Item not found."
					end
					print("Inventory error: Item data not found to add in inventory: " .. ItemName)
					return false
				end
			end
			--self.AddItemInInventory("Alpha")

			-- Creates
			coroutine.wrap(function()
				local CaseOpeningCoolDown = false
				local function OpenCase(IsMegaCase)
					local SelectedTable = ItemsData.NormalData
					if IsMegaCase then
						SelectedTable = ItemsData.MegaData
					end
					--coroutine.wrap(self.FireSelfRemote)("effectbought")
					--local function chooseRandomItem()
					--	local Chance = math.random(1,#SelectedTable.Items)
					--	local Counter = 0
					--	for _,ItemData in pairs(SelectedTable.Items) do
					--		Counter = Counter + ItemData[2]
					--		if Chance <= Counter then
					--			return ItemData
					--		end
					--	end
					--end
					local chosenid = SelectedTable.Chances[math.random(1,#SelectedTable.Chances)]
					local ChosenData = SelectedTable.Data[chosenid[1].Name]
					local ChosedItemData = GetItemFromName(chosenid[1].Name)

					local Duplicate = false
					local RefundedAmount = 0
					if PlayerHasItem(ChosedItemData.Name) then
						Duplicate = true
					end
					--for _,v in pairs(self.PlayerStoredData.Inventory) do
					--	if v.Name == ChosenData.Name then
					--		Duplicate = true
					--	end
					--end
					if Duplicate == false then
						table.insert(self.PlayerStoredData.Inventory,{Name = tostring(ChosedItemData.Name), Type = tostring(ChosedItemData.Type), Equipped = false})
					else
						if ChosenData.RarityName == "Common" then
							self.PlayerStoredData.Coins += 200
							RefundedAmount = 200
						elseif ChosenData.RarityName == "Rare" then
							self.PlayerStoredData.Coins += 350
							RefundedAmount = 350
						elseif ChosenData.RarityName == "Epic" then
							self.PlayerStoredData.Coins += 600
							RefundedAmount = 600
						elseif ChosenData.RarityName == "Legendary" then
							self.PlayerStoredData.Coins += 800
							RefundedAmount = 800
						end
					end
					self.TempData.InventoryData.Functions.UpdateInventoryDisplay()
					local function ShowOpeningAnimation()
						local CaseOpeningFrame = game.ServerStorage.Storage.Assets.CaseOpeningFrame:Clone()
						self.Maid:GiveTask(CaseOpeningFrame)
						CaseOpeningFrame.Parent = self.UI
						CaseOpeningFrame.Visible = false
						CaseOpeningFrame.Position = UDim2.new(0.5,0,-0.5,0)
						local TempDataFound = nil
						for _,v in pairs(self.TempData.InventoryData.InventoryDisplayTemps) do if v.ItemName == tostring(ChosedItemData.Name) then TempDataFound = v.Temp end end
						local Template = CaseOpeningFrame.Template
						Template.Visible = false
						for _,v in pairs(Template:GetChildren()) do
							if v:IsA("UIAspectRatioConstraint") or v:IsA("UIScale") then else
								v:Destroy()
							end
						end
						for _,v in pairs(TempDataFound:GetChildren()) do
							if v:IsA("Frame") or v:IsA("ImageLabel") or v:IsA("TextLabel") then
								local cloned = v:Clone()
								self.Maid:GiveTask(cloned)
								cloned.ZIndex = 7
								cloned.Parent = Template
							end
						end
						CaseOpeningFrame.Visible = true
						local DroppingTween = TweenService:Create(CaseOpeningFrame, TweenInfo.new(1, Enum.EasingStyle.Bounce, Enum.EasingDirection.Out),{Position = UDim2.new(0.5,0,0.5,0)})
						DroppingTween:Play()
						DroppingTween.Completed:Wait()
						Template.Visible = true
						local CaseT1,CaseT2,CaseT3,CaseT4 = TweenService:Create(CaseOpeningFrame.Case.Top, TweenInfo.new(0.8,Enum.EasingStyle.Linear),{
							Position = UDim2.new(0.5,0,-1,0)
						}),TweenService:Create(CaseOpeningFrame.Case.Front, TweenInfo.new(0.8,Enum.EasingStyle.Linear),{
							Position = UDim2.new(0.5,0,2,0)
						}),TweenService:Create(CaseOpeningFrame.Case.Back, TweenInfo.new(0.8,Enum.EasingStyle.Linear),{
							Position = UDim2.new(0.5,0,2,0)
						}),TweenService:Create(CaseOpeningFrame.Template.UIScale, TweenInfo.new(1,Enum.EasingStyle.Cubic,Enum.EasingDirection.Out),{
							Scale = 1.5
						})
						CaseT1:Play()
						CaseT2:Play()
						CaseT3:Play()
						CaseT1.Completed:Wait()
						local TemplateCon
						local Canceled = false
						CaseT4:Play()
						CaseOpeningFrame.Case.Visible = false
						CaseOpeningFrame.TextLabel.Visible = true
						local clr = (RarityColor[ChosenData.RarityName] or Color3.new(1,1,1))
						if Duplicate then
							CaseOpeningFrame.TextLabel.Text = '<font color="#FFFF00">+'.. RefundedAmount .. '</font> Duplicate'..' <font color="rgb('..math.floor(clr.R*255)..','..math.floor(clr.G*255)..','..math.floor(clr.B*255)..')">'.. ChosenData.RarityName .."</font> Item Unlocked!"
						else
							CaseOpeningFrame.TextLabel.Text = 'New <font color="rgb('..math.floor(clr.R*255)..','..math.floor(clr.G*255)..','..math.floor(clr.B*255)..')">'.. ChosenData.RarityName .."</font> Item Unlocked!"
						end
						TemplateCon = self.Maid:GiveTask(Template.MouseButton1Click:Connect(function()
							self.Maid[TemplateCon] = nil
							CaseOpeningFrame:Destroy()
							CaseT4:Cancel()
						end))
						delay(2,function() if self==nil or self.Disconnected or self.Player == nil then return end
							if Canceled == false then
								CaseOpeningFrame:Destroy()
							end
						end)
					end
					local succ,errr = pcall(function()
						ShowOpeningAnimation()
					end) if not succ then print(errr) end
				end
				self.OpenCase = OpenCase
				self.Maid:GiveTask(self.UI:WaitForChild("InventoryFrame"):WaitForChild("Container"):WaitForChild("BoxFrame").Normal.buy.MouseButton1Click:Connect(function()
					if CaseOpeningCoolDown then return end
					CaseOpeningCoolDown = true
					if self.PlayerStoredData.Coins >= 500 then
						self.PlayerStoredData.Coins -= 500
						coroutine.wrap(function()
							OpenCase()
						end)()
					else
						self.UIFunctions.NotEnoughCoinsPopup()
					end
					delay(0.5,function() if self==nil or self.Disconnected or self.Player == nil then return end
						CaseOpeningCoolDown = false
					end)
				end))
				self.Maid:GiveTask(self.UI:WaitForChild("InventoryFrame"):WaitForChild("Container"):WaitForChild("BoxFrame").Fancy.buy.MouseButton1Click:Connect(function()
					MarketplaceService:PromptProductPurchase(self.Player, 1269120860)
				end))
			end)()
		end)()
	end

	--// Touched Milk Func
	function self.TouchedMilk(MilkId, Purchased)
		if self.TempData.TouchCoolDown then return end
		self.TempData.TouchCoolDown = true
		local FoundDisplay
		local suc,err = pcall(function()
			local MilkVal = self.GetMilkVal(MilkId)
			if MilkVal == nil then return delay(2,function()if self==nil or self.Disconnected or self.Player == nil then return end self.TempData.TouchCoolDown = false end) end
			local PlayerHasMilk = self.PlayerHasMilk(MilkId)
			if PlayerHasMilk then if Purchased == true then self.NotifyPlayer("The milk you just purchased was already owned by you!") end return delay(2,function()if self==nil or self.Disconnected or self.Player == nil then return end self.TempData.TouchCoolDown = false end) end
			if _L.CustomMilkFuncs[MilkId] then
				local result
				local succ,errr = pcall(function()result = _L.CustomMilkFuncs[MilkId](self,self.Profile.Data.MilkFound,_L) end)
				if not succ then print(errr) return delay(2,function()if self==nil or self.Disconnected or self.Player == nil then return end self.TempData.TouchCoolDown = false end) end
				if result == false or result == nil then
					return delay(2,function()if self==nil or self.Disconnected or self.Player == nil then return end self.TempData.TouchCoolDown = false end)
				end
			end
			table.insert(self.Profile.Data.MilkFound,MilkId)
			coroutine.wrap(self.UpdateInvUI)()
			coroutine.wrap(_L.Functions.AwardBadge)(self.Player,(MilkVal.BadgeId.Value or 0000))
			FoundDisplay = self.UI.FoundDisplay
			pcall(function()
				FoundDisplay.ImageLabel.Image = MilkVal.Image.Value
				FoundDisplay.NameLabel.Text = MilkId
				FoundDisplay.NameLabel.TextColor3 = (self.TempData.RarityData[MilkVal.Rarity.Value] or Color3.new(1,1,1))
				FoundDisplay.Visible = true
				FoundDisplay.FoundLabel.Text = "Found"
			end)
		end)
		if not suc then print(err) end
		delay(5,function()
			if self==nil or self.Disconnected or self.Player == nil then return end
			self.TempData.TouchCoolDown = false
			if FoundDisplay ~= nil then FoundDisplay.Visible = false end
		end)
	end

	function self.PurchasedMilk(MilkId)
		self.TempData.TouchCoolDown = true
		local FoundDisplay
		local suc,err = pcall(function()
			local MilkVal = self.GetMilkVal(MilkId)
			if MilkVal == nil then self.NotifyPlayer("An unknown error occured, please file a bug report in our server.") return end
			local PlayerHasMilk = self.PlayerHasMilk(MilkId)
			if PlayerHasMilk then self.NotifyPlayer("The milk you just purchased was already owned by you!") return end

			table.insert(self.Profile.Data.MilkFound,MilkId)
			coroutine.wrap(self.UpdateInvUI)()

			coroutine.wrap(_L.Functions.AwardBadge)(self.Player,(MilkVal.BadgeId.Value or 0000))
			FoundDisplay = self.UI.FoundDisplay
			pcall(function()
				FoundDisplay.ImageLabel.Image = MilkVal.Image.Value
				FoundDisplay.NameLabel.Text = MilkId
				FoundDisplay.NameLabel.TextColor3 = (self.TempData.RarityData[MilkVal.Rarity.Value] or Color3.new(1,1,1))
				FoundDisplay.Visible = true
				FoundDisplay.FoundLabel.Text = "Purchased"
			end)
		end)
		if not suc then print(err) end
		delay(5,function() if self==nil or self.Disconnected or self.Player == nil then return end
			self.TempData.TouchCoolDown = false
			if FoundDisplay ~= nil then FoundDisplay.Visible = false end
		end)
	end

	--// Collected Coin
	function self.CollectedCoin(customamount)
		local amount = tonumber((tonumber(customamount) or 20))
		if self.TempData.GamepassData.OwnsDoubleCoins then amount = amount*2 end
		self.Profile.Data.Coins += tonumber(amount)
		_L.Functions.Network.Fire("PlayCoinSound",self.Player)
	end

	--// Tool Equip/Unequip Function
	function self.EquipUnEquipTool(ToolName, Slot)
		if self.Player.Character == nil then return end

		local ecd = false
		local function equip()
			if ecd then return end ecd = true
			local ToolFound = game.ServerStorage.Storage.Assets.Tools:FindFirstChild(ToolName)
			if ToolFound then
				local newTool = ToolFound:Clone()
				self.Maid:GiveTask(newTool)
				newTool.Parent = self.Player.Backpack
				delay(0.1,function()
					newTool.Parent = self.Player.Character
					self.TempData.CurrentToolEquipped = newTool
					pcall(function()
						self.UI.ToolBar.ToolBar["2"][tostring(Slot)].BackgroundTransparency = 0
					end)
					ecd = false
				end)
			end
		end
		local function unequipall()
			self.TempData.CurrentToolEquipped.Parent = self.Player.Backpack
			self.TempData.CurrentToolEquipped:Destroy()
			self.TempData.CurrentToolEquipped = nil
			pcall(function()
				for _,v in pairs(self.UI.ToolBar.ToolBar["2"]:GetChildren()) do
					if v:IsA('TextButton') then
						v.BackgroundTransparency = 0.5
					end
				end
			end)
		end

		if self.TempData.CurrentToolEquipped == nil then
			equip()
		else
			if self.TempData.CurrentToolEquipped.Name == ToolName then
				unequipall()
			else
				unequipall()
				equip()
			end
		end
	end

	--// Fired Server
	function self.ServerEventFired(PlayerFired, Type, Args)
		if PlayerFired.UserId ~= self.Player.UserId then return warn(self.Player.Name .. "'s plrfunc event was fire by " .. PlayerFired.Name .. ". This might be a hacking/exploit case or a major framework malfunction.") end
		local suc,err = pcall(function()
			if Type == "lightingchanged9283th" then
				if math.floor(Args) == 0 or math.floor(Args) == 24 then
					self.TempData.TempMilkData.CanCollect_SleepyMilk = true
				else
					self.TempData.TempMilkData.CanCollect_SleepyMilk = false
				end
			elseif Type == "OneMilkPlease_9ubgqf" then
				local MilksThere = 0
				for _,v in pairs(game.ServerStorage.Storage.Items.Milks.Milks:GetChildren())do if v:IsA("ObjectValue")  then if v.Value then MilksThere+=1 end end end
				local minrequired = 50 --<<<<<<< important
				if #self.Profile.Data.MilkFound >= minrequired then -- MilksThere-1

					local amountRemoved = 0
					while (amountRemoved < minrequired) do
						local milkfound = false
						for i = 1, #self.Profile.Data.MilkFound, 1 do
							if self.Profile.Data.MilkFound[i] then
								table.remove(self.Profile.Data.MilkFound, i)
								amountRemoved = amountRemoved + 1
								milkfound = true
								break
							end
						end
						if not milkfound then break end
					end

					self.TouchedMilk("Strawberry Milk")
					self.Profile.Data.Prestige += 1
					coroutine.wrap(self.UpdateInvUI)()

					delay(.5,function()
						if self==nil or self.Disconnected or self.Player == nil then return end

						_L.Functions.Network.Fire("NPCINTERACTION_TW4HR", self.Player,  workspace.Map.InteractingParts.NPCs.Dad.Head, "Be sure to take care of it.")
					end)

				else
					_L.Functions.Network.Fire("NPCINTERACTION_TW4HR", self.Player,  workspace.Map.InteractingParts.NPCs.Dad.Head, "Come back when you've collected the milks you fool..")
				end

			elseif Type == "ResetMilk_24F83" then
				if #self.Profile.Data.MilkFound > 0 then

					table.clear(self.Profile.Data.MilkFound)
					self.UpdateInvUI()

					delay(1,function()
						if self==nil or self.Disconnected or self.Player == nil then return end

						_L.Functions.Network.Fire("NPCINTERACTION_TW4HR", self.Player,  workspace.Map.InteractingParts.NPCs.Dad.Head, "As you wish.")
					end)
				else
					_L.Functions.Network.Fire("NPCINTERACTION_TW4HR", self.Player, workspace.Map.InteractingParts.NPCs.Dad.Head, "At least find some milk first!")
				end
			elseif Type == "ACTIVATEDTOOL823H_F32" then
				if typeof(Args) ~= 'number' then return end
				if Args == 1 then
					if self.TempData.GamepassData.OwnsGravityCoil then
						self.EquipUnEquipTool("GravityCoil", 1)
					else
						MarketplaceService:PromptGamePassPurchase(self.Player,42687770)
					end
				elseif Args == 2 then
					if self.TempData.GamepassData.OwnsSpeedCoil then
						self.EquipUnEquipTool("SpeedCoil", 2)
					else
						MarketplaceService:PromptGamePassPurchase(self.Player,42687988)
					end
				elseif Args == 3 then
					if self.TempData.GamepassData.OwnsFusionCoil then
						self.EquipUnEquipTool("FusionCoil", 3)
					else
						MarketplaceService:PromptGamePassPurchase(self.Player,42688142)
					end
				elseif Args == 4 then
					if self.TempData.GamepassData.OwnsFlingGlove then
						self.EquipUnEquipTool("Fling Glove", 4)
					else
						MarketplaceService:PromptGamePassPurchase(self.Player,42803975)
					end
				elseif Args == 5 then
					if self.TempData.GamepassData.OwnsBlower then
						self.EquipUnEquipTool("Blower", 5)
					else
						MarketplaceService:PromptGamePassPurchase(self.Player,42804068)
					end
				elseif Args == 6 then
					if self.TempData.GamepassData.OwnsGrappleHook then
						self.EquipUnEquipTool("GrappleHook", 6)
					else
						MarketplaceService:PromptGamePassPurchase(self.Player,43150904)
					end
				elseif Args == 7 then
					if self.TempData.GamepassData.OwnsMagicCarpet then
						self.EquipUnEquipTool("MagicCarpet", 7)
					else
						MarketplaceService:PromptGamePassPurchase(self.Player,43633906)
					end
				elseif Args == 8 then
					if self.TempData.GamepassData.OwnsHandGun then
						self.EquipUnEquipTool("Handgun", 8)
					else
						MarketplaceService:PromptGamePassPurchase(self.Player,721178117)
					end
				end
			end
		end)
		if not suc then
			print("error while handling server event firing: " .. err)
		end
	end

	--// Notification
	function self.NotifyPlayer(Text, Size)
		local newNTemp = game.ServerStorage.Storage.Assets.NotifTemp:Clone()
		local tmaidid = self.Maid:GiveTask(newNTemp)
		local clickmaidid
		newNTemp.Text = Text
		if typeof(Size) == 'UDim2' then
			newNTemp.Size = Size
		end
		newNTemp.Parent = self.UI.ToolBar.Notif
		local function fadeaway()
			local tween = game:GetService('TweenService'):Create(newNTemp,TweenInfo.new(1),{BackgroundTransparency = 1,TextTransparency = 1})
			tween:Play()
			delay(1,function() if self==nil or self.Disconnected or self.Player == nil then return end
				self.Maid[tmaidid] = nil
				if clickmaidid then self.Maid[clickmaidid] = nil end
			end)
		end

		delay(6, function() if self==nil or self.Disconnected or self.Player == nil then return end
			if newNTemp then
				fadeaway()
			end
		end)
		clickmaidid = self.Maid:GiveTask(newNTemp.MouseButton1Click:Connect(function() if self==nil or self.Disconnected or self.Player == nil then return end
			if newNTemp then
				fadeaway()
			end
		end))
	end

	--// Custom Chat funcs
	self.Maid:GiveTask(self.Player.Chatted:Connect(function(msg)
		if string.lower(msg) == "ribbit ribbit" then
			if self.Player.Character then
				local hrp = self.Player.Character:FindFirstChild("HumanoidRootPart")
				local frMain = workspace.Map.InteractingParts.ConvenienceFolder.FrogMushroomFairy.Main
				if hrp then
					local dist = (hrp.Position-frMain.Position).Magnitude
					if dist <= 10 then
						self.TempData.TempMilkData.CanCollectMushroomMilk = true
						_L.Functions.Network.Fire("CLIENTMILKSHOW_8GQA3", self.Player, "Mushroom Milk Carton")
						delay(10,function() if self==nil or self.Disconnected or self.Player == nil then return end
							self.TempData.TempMilkData.CanCollectMushroomMilk = false 
						end)
					end
				end
			end
		end
	end))

	--// Runs
	function self.RunEveryMinute()
		if self then
			if self.Profile then
				coroutine.wrap(function()
					if self.TempData.PlayerHasItem and self.AddItemInInventory then
						local ItemsNeeded = {
							"Time Halo",
							"Coral Halo",
							"Pink Halo",
							"Red Halo",
							"Purple Halo",
							"Golden Halo",
							"Aqua Halo"
						}
						for i,v in pairs(ItemsNeeded) do
							if self.TempData.PlayerHasItem(v) == false then
								return
							end
						end
						self.AddItemInInventory("Crystal Halo",true)
					end
				end)()
			end
		end
	end
	function self.RunEverySecond()
		if self then
			if self.Profile then
				if self.Profile.Data then
					self.Profile.Data.TimePlayed += 1

					if self.TempData then
						if self.TempData.LBFolder then
							if self.TempData.LBFolder.Prestige then
								if self.Profile.Data.Prestige then
									if self.TempData.LBFolder.Prestige.Value ~= self.Profile.Data.Prestige then
										self.TempData.LBFolder.Prestige.Value = self.Profile.Data.Prestige
									end
								end
							end
						end

						pcall(function()
							if self.UI then
								if self.UI:FindFirstChild("CoinsDisplay") then
									self.UI.CoinsDisplay.Amount.Text = tostring(self.Profile.Data.Coins)
								end
							end
						end)

						coroutine.wrap(function()
							for i,v in pairs({
								["Time Halo"] = 180000,}) do
								if self.PlayerStoredData.TimePlayed >= v then
									if self.TempData.PlayerHasItem("Time Halo") == false then
										self.AddItemInInventory(i, true)
									end
									--pcall(function()
									--	local GameModule = require(script.Parent.Game)
									--	GameModule:AwardBadge(self.Player, 2124902235)
									--end)
								end
							end
						end)()
						coroutine.wrap(function()
							for i,v in pairs({
								["Pink Halo"] = 1,
								["Coral Halo"] = 5,
								["Red Halo"] = 25,
								["Purple Halo"] = 50,
								['White Halo'] = 100}) do
								if self then
									if self.PlayerStoredData then
										if self.PlayerStoredData.Prestige >= v then
											if self.AddItemInInventory ~= nil then
												if self.TempData.PlayerHasItem(i) == false then
													self.AddItemInInventory(i, true)
												end
											end
										end
									end
								end
							end
						end)()
					end
				end
			end
		end
	end
	function self.RunOnStepped()
		if self then
			if self.Player then
				if self.Player.Character then
					if self.Player.Character.Humanoid then
						if self.TempData.Sprint and (self.TempData.CurrentToolEquipped ~= nil and (self.TempData.CurrentToolEquipped.Name == "SpeedCoil" or self.TempData.CurrentToolEquipped.Name == "FusionCoil")) then
							self.Player.Character.Humanoid.WalkSpeed = 36
						elseif self.TempData.Sprint == false and (self.TempData.CurrentToolEquipped ~= nil and (self.TempData.CurrentToolEquipped.Name == "SpeedCoil" or self.TempData.CurrentToolEquipped.Name == "FusionCoil")) then
							self.Player.Character.Humanoid.WalkSpeed = 26
						elseif self.TempData.Sprint then
							self.Player.Character.Humanoid.WalkSpeed = 26
						else
							self.Player.Character.Humanoid.WalkSpeed = 16
						end
						self.Player.Character.Humanoid.JumpPower = 50
					end
				end
			end
		end
	end

	--// PRuns
	function self.PRun()
		if self.TempData.LBFolder == nil then
			self.TempData.LBFolder = Instance.new("Folder",self.Player)
			self.Maid:GiveTask(self.TempData.LBFolder)
			self.TempData.LBFolder.Name = "leaderstats"
			local Prestige = Instance.new('NumberValue',self.TempData.LBFolder)
			self.Maid:GiveTask(Prestige)
			Prestige.Name = "Prestige"
			Prestige.Value = self.Profile.Data.Prestige
		end
		delay(2, function()
			if self==nil or self.Disconnected or self.Player == nil then return end

			self.LoadCharacterUtils(self.Player.Character)
		end)

		function self.CheckOwnsGears()
			local suc,err = pcall(function()
				self.TempData.GamepassData.OwnsGravityCoil = MarketplaceService:UserOwnsGamePassAsync(self.Player.UserId,42687770) if self==nil or self.Disconnected or self.Player == nil then return end
				self.TempData.GamepassData.OwnsSpeedCoil = MarketplaceService:UserOwnsGamePassAsync(self.Player.UserId,42687988) if self==nil or self.Disconnected or self.Player == nil then return end
				self.TempData.GamepassData.OwnsFusionCoil = MarketplaceService:UserOwnsGamePassAsync(self.Player.UserId,42688142) if self==nil or self.Disconnected or self.Player == nil then return end
				self.TempData.GamepassData.OwnsFlingGlove = MarketplaceService:UserOwnsGamePassAsync(self.Player.UserId,42803975) if self==nil or self.Disconnected or self.Player == nil then return end
				self.TempData.GamepassData.OwnsBlower = MarketplaceService:UserOwnsGamePassAsync(self.Player.UserId,42804068) if self==nil or self.Disconnected or self.Player == nil then return end
				self.TempData.GamepassData.OwnsGrappleHook = MarketplaceService:UserOwnsGamePassAsync(self.Player.UserId,43150904) if self==nil or self.Disconnected or self.Player == nil then return end
				self.TempData.GamepassData.OwnsMagicCarpet = MarketplaceService:UserOwnsGamePassAsync(self.Player.UserId,43633906) if self==nil or self.Disconnected or self.Player == nil then return end
				self.TempData.GamepassData.OwnsDoubleCoins = MarketplaceService:UserOwnsGamePassAsync(self.Player.UserId,48899382) if self==nil or self.Disconnected or self.Player == nil then return end
				self.TempData.GamepassData.OwnsHandGun = MarketplaceService:UserOwnsGamePassAsync(self.Player.UserId,721178117) if self==nil or self.Disconnected or self.Player == nil then return end
				self.TempData.GamepassData.OwnsTp = MarketplaceService:UserOwnsGamePassAsync(self.Player.UserId,720828709) if self==nil or self.Disconnected or self.Player == nil then return end
			end)
			if not suc then print(err) end
		end
		self.CheckOwnsGears()
	end

	--// Connections
	coroutine.wrap(self.PRun)()
	self.Maid:GiveTask(self.Player.CharacterAdded:Connect(self.LoadCharacterUtils))
	coroutine.wrap(function()
		local suc,err = pcall(self.InitUI)
		if not suc then print("Failers to init UI for ".. Player_Object.Name ..": " .. err) end
	end)()

	setmetatable(self, PlayerModule)
	return self
end

function PlayerModule.GetPlayerFunction(Player)
	return PlayerModule.PlayerFunctions[Player]
end

local PrevSec_ = 0
workspace:GetPropertyChangedSignal("DistributedGameTime"):Connect(function()
	if PrevSec_ ~= math.floor(workspace.DistributedGameTime) then PrevSec_ = math.floor(workspace.DistributedGameTime)
		for i,pfunc in pairs(PlayerModule.PlayerFunctions) do
			coroutine.wrap(function()
				local suc, err = pcall(function()
					if pfunc then
						if pfunc.Player and pfunc.Disconnected == false then
							if pfunc.RunEverySecond then
								pfunc.RunEverySecond()
							end
						end
					end
				end)if not suc then print(err) end
			end)()
		end
	end
end)
game:GetService("RunService").Stepped:Connect(function()
	for i,pfunc in pairs(PlayerModule.PlayerFunctions) do
		coroutine.wrap(function()
			local suc, err = pcall(function()
				if pfunc then
					if pfunc.Player then
						if pfunc.RunOnStepped and pfunc.Disconnected == false then
							pfunc.RunOnStepped()
						end
					end
				end
			end)if not suc then print(err) end
		end)()
	end
end)

coroutine.wrap(function()
	repeat wait(0.5) until _L ~= nil
	_L.Functions.Network.Fired("SPECIALCLIENTEVENTS_32TQR"):Connect(function(Plr, Type, Args)
		local pfunc = PlayerModule.GetPlayerFunction(Plr)
		if pfunc then
			pfunc.ServerEventFired(Plr,Type,Args)
		else
			warn(Plr.Name .. " fired a server event (SPECIALCLIENTEVENTS) before even the PlayerFunction was loaded, might be a hacking/exploiting case [1] [most likely Could be possible because player has trigerred a server event from client before PlrFunc even loaded].")
		end
	end)
end)()

coroutine.wrap(function()
	local function onPromptGamePassPurchaseFinished(player, purchasedPassID, purchaseSuccess)

		if purchaseSuccess == true then
			local pfunc = PlayerModule.GetPlayerFunction(player)
			if pfunc ~= nil then
				local IDs = {
					[42687770] = "OwnsGravityCoil",
					[42687988] = "OwnsSpeedCoil",
					[42688142] = "OwnsFusionCoil",
					[42803975] = "OwnsFlingGlove",
					[42804068] = "OwnsBlower",
					[43150904] = "OwnsGrappleHook",
					[43633906] = "OwnsMagicCarpet",
					[48899382] = "OwnsDoubleCoins",
					[721178117] = "OwnsHandGun",
					[720828709] = "OwnsTp"
				}

				if IDs[purchasedPassID] then
					pfunc.TempData.GamepassData[IDs[purchasedPassID]] = true
				end
			end
		end
	end

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(onPromptGamePassPurchaseFinished)
end)()


coroutine.wrap(function()
	local suc,err = pcall(function()
		local ChatServiceRunner = game.ServerScriptService:WaitForChild("ChatServiceRunner",math.huge)
		local ChatService = require(ChatServiceRunner:FindFirstChild("ChatService", true))
		ChatService.SpeakerAdded:Connect(function(playerName)
			delay(2.5,function()
				local player = game.Players:FindFirstChild(playerName)
				if not player then return end
				local speaker = ChatService:GetSpeaker(playerName)
				local plrfunc = PlayerModule.GetPlayerFunction(player)

				if plrfunc then
					if plrfunc.Profile then
						if plrfunc.Profile.Data then
							if plrfunc.Profile.Data.AmountDonated > 0 then
								speaker:SetExtraData("Tags",{{TagText = "DONATOR", TagColor = Color3.fromRGB(0, 255, 0)}})
							end
						end
					end
				end
			end)
		end)
	end)
	if not suc then print(err) end
end)()

return PlayerModule