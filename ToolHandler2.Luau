local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MDS = ReplicatedStorage:WaitForChild("MDS", 30)
local RM = ReplicatedStorage:WaitForChild("RM", 30)
if not RM then
	warn("RM does not exist")
end
if not MDS then
	warn("MDS returned incorrect parameter")
end
local CSA_Module = MDS:WaitForChild("ClientServerAccessible", 30)
local AMA_Module = MDS:WaitForChild("ArmMovementAnimator", 30)
local CSA = require(CSA_Module)
local AMA = require(AMA_Module)
local DEBUG_MODE = true
local SENDOR = "SR"
local functionIsRunning = false
local Tools = AMA.Tools
local toolInstances = {}
local activeConnections = {}
local RME = RM:WaitForChild("MOVEMENT", 30)
AMA.RME = RME
local character = CSA.Character(CSA.LocalPlayer())
local backpack = CSA.LocalPlayer():WaitForChild("Backpack", 5)
local player = CSA.LocalPlayer()
AMA.LP = player
AMA.CAMERA = CSA.Camera()
local function attemptDebug(value:string, TYPE) : boolean
	if value == nil then
		warn("AttemptDebug received incorrect arguments!")
		return false
	end
	value = tostring(value)
	TYPE = TYPE or print
	if typeof(TYPE) == "function" then
		if DEBUG_MODE then
			if typeof(value) == "string" then
				TYPE(value)
				return true
			end
		end
	else
		warn("typeof TYPE is not a function!")
		return false
	end
	return false
end
local function updateArmReferences(char)
	if not char then
		attemptDebug("Char does not exist!", warn)
		return
	end
	AMA.targetC0 = CFrame.new()
	AMA.char = char
	AMA.rightarm, AMA.rightjoint6d = CSA.GCP(char, Enum.BodyPartR15.RightUpperArm)
	if AMA.rightarm then
		AMA.rightjoint6d = AMA.rightarm:FindFirstChild("RightShoulder")
		if AMA.rightjoint6d then
			AMA.prevpos = AMA.rightjoint6d.C0
		else
			attemptDebug("Could not find Rightjoint6D", warn)
		end
	else
		attemptDebug("Could not find Rightarm!", warn)
	end
end
local function setupTool(tool:Tool)
	local conna, connb
	if tool == nil or not tool:IsA("Tool") then
		attemptDebug("Passed in parameter is not a tool!", warn)
		return
	end
	if toolInstances[tool] then
		attemptDebug("Tool instance already exists do not setup further", print)
		return
	end
	local toolId = AMA.New(tool)
	if not toolId then
		attemptDebug("toolId returned false!", warn)
		return
	end
	local toolAttribute = tool:GetAttribute("Type")
	if toolAttribute == nil then
		warn("Tool has no attribute!")
		return
	end
	if Tools.Equipped[toolAttribute] then
		conna = tool.Equipped:Connect(function()
			Tools.Equipped[toolAttribute](toolId)
		end)
	else
		attemptDebug("Tools does not have equipped for this tool!", warn)
	end
	if Tools.Unequipped[toolAttribute] then
		connb = tool.Unequipped:Connect(function()
			Tools.Unequipped[toolAttribute](toolId)
		end)
	else
		attemptDebug("Tools does not have unequipped for this tool", warn)
	end
	toolInstances[tool] = {ID = toolId, Equip = conna, Unequip = connb}
end
local function unregisterTool(child, chosen, force)
	if child:IsA("Tool") then
		if not force and chosen and chosen:IsAncestorOf(child) then
			attemptDebug("Tool has failed to destroy attempt using force", print)
			return
		end
		local data = toolInstances[child]
		if data then
			if data["ID"] ~= nil then
				data["ID"]:_Destroy()  data["ID"] = nil
			end
			if data["Equip"] ~= nil then
				data["Equip"]:Disconnect() data["Equip"] = nil
			end
			if data["Unequip"] ~= nil then
				data["Unequip"]:Disconnect() data["Unequip"] = nil
			end
		end
		toolInstances[child] = nil
	else
		attemptDebug("Tool is not a tool?", warn)
	end
end
local function humanoidDeath(character)
	if character and typeof(character) == "Instance" and character:IsA("Model") then
		local humanoid = CSA.Humanoid(character)
		local health = humanoid.Health
		if health == 0 then
			return true, health
		else
			return false, health
		end
	end
	return false
end
local function stopTrackingTracker(humanoid)
	humanoid.Died:Once(function()
		for tool in pairs(toolInstances) do
			unregisterTool(tool, backpack, true)
		end
	end)
end
local function startTracking(Char)
	local a = Char.ChildAdded:Connect(function(child)
		setupTool(child)
	end)
	local b = Char.ChildRemoved:Connect(function(child)
		local died = humanoidDeath(character)
		if not died then
			unregisterTool(child, backpack)
		end
	end)
	local c = backpack.ChildRemoved:Connect(function(child)
		local died = humanoidDeath(character)
		if not died then
			unregisterTool(child, Char)
		end
	end)
	local data = {a, b, c}
	table.insert(activeConnections, a)
	table.insert(activeConnections, b)
	table.insert(activeConnections, c)
end
local function charSetup(Char:Model)
	if functionIsRunning then
		return
	end
	functionIsRunning = true
	if not Char then
		attemptDebug("Character does not exist in charsetup", warn)
		return
	end
	local ConnForceCleared
	for _, con in ipairs(activeConnections) do
		if typeof(con) == "RBXScriptConnection" then
			ConnForceCleared = true
			con:Disconnect()
		end
	end
	table.clear(activeConnections)
	updateArmReferences(Char)
	startTracking(Char)
	local humanoid = CSA.Humanoid(Char)
	stopTrackingTracker(humanoid)
	functionIsRunning = false
end
local function publicArmHandler(Key:string, Data:{any})
	if Key == SENDOR then
		for i, playerdata in ipairs(Data) do
			if typeof(playerdata) ~= "table" then
				continue
			end
			local PlayerCharacter = playerdata[1]
			local TargetC0 = playerdata[2]
			if not PlayerCharacter or not TargetC0 then
				attemptDebug("PlayerCharacter or TargetC0 does not exist..", warn)
				continue
			end
			local RUA = PlayerCharacter:FindFirstChild("RightUpperArm") :: BasePart
			if RUA then
				local RS = RUA:FindFirstChild("RightShoulder") :: Motor6D
				if RS then
					RS.C0 = TargetC0
				else
					attemptDebug("RS IS NIL", warn)
				end
			else
				attemptDebug("rua is nil", warn)
			end
		end
	end
end
charSetup(character)
player.CharacterAdded:Connect(function(character)
	charSetup(character)
end)
RME.OnClientEvent:Connect(publicArmHandler)
