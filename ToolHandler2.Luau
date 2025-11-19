--> This code has no empty spaces and no comments. Total lines of code: 215
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MDS = ReplicatedStorage:WaitForChild("MDS", 30)
local RM = ReplicatedStorage:WaitForChild("RM", 30)
local DEBUG_MODE = true
local functionIsRunning = false
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
if not RM then
	attemptDebug("RM does not exist", warn)
end
if not MDS then
	attemptDebug("MDS returned incorrect parameter", warn)
end
local CSA_Module = MDS:WaitForChild("ClientServerAccessible", 30)
if not CSA_Module then
	attemptDebug("CSA MODULE RETURNED INCORRECT PARAMETER", warn)
end
local CSA = require(CSA_Module)
local AMA = require(MDS:WaitForChild("ArmMovementAnimator", 30))
if not CSA or not AMA then
	attemptDebug("CSA OR AMA FAILED TO LOAD", warn)
end
local BackPack = CSA.LocalPlayer():WaitForChild("Backpack", 5)
local Character = CSA.Character(CSA.LocalPlayer())
local RME = RM:WaitForChild("MOVEMENT", 30)
if not RME then
	attemptDebug("RM or RME not found in replicated storage", warn)
end
local SENDOR = "SR"
AMA.LP = CSA.LocalPlayer() :: Player
AMA.RME = RME
AMA.CAMERA = CSA.Camera()
local ToolInstances = {}
local ActiveConnections = {}
local Tools = AMA.Tools
local Player = AMA.LP
local function updateArmReferences(char)
	if not char then
		attemptDebug("Char does not exist!", warn)
		return
	end
	AMA.targetC0 = CFrame.new()
	AMA.CHAR = CSA.Character(CSA.LocalPlayer()) :: Model
	AMA.RIGHTARM, AMA.RIGHTJOINT6D = CSA.GCP(char, Enum.BodyPartR15.RightUpperArm)
	if AMA.RIGHTARM then
		AMA.RIGHTJOINT6D = AMA.RIGHTARM:FindFirstChild("RightShoulder")
		if AMA.RIGHTJOINT6D then
			AMA.PrevPos = AMA.RIGHTJOINT6D.C0
		else
			attemptDebug("Could not find Rightjoint6D", warn)
		end
	else
		attemptDebug("Could not find Rightarm!", warn)
	end
end
local function setupTool(tool:Tool)
	local conna, connb
	if not tool:IsA("Tool") then
		attemptDebug("Passed in parameter is not a tool!", warn)
		return
	end
	if ToolInstances[tool] then
		attemptDebug("Tool instance already exists do not setup further", print)
		return
	end
	local ToolId = AMA.New(tool)
	if not ToolId then
		attemptDebug("ToolId returned false!", warn)
		return
	end
	local toolattribute = tool:GetAttribute("Type")
	if toolattribute == nil then
		warn("Tool has no attribute!")
		return
	end
	if Tools.Equipped[toolattribute] then
		conna = tool.Equipped:Connect(function()
			Tools.Equipped[toolattribute](ToolId)
		end)
	else
		attemptDebug("Tools does not have equipped for this tool!", warn)
	end
	if Tools.Unequipped[toolattribute] then
		connb = tool.Unequipped:Connect(function()
			Tools.Unequipped[toolattribute](ToolId)
		end)
	else
		attemptDebug("Tools does not have unequipped for this tool", warn)
	end
	ToolInstances[tool] = {ID = ToolId, Equip = conna, Unequip = connb}
end
function unregisterTool(child, chosen, force)
	if child:IsA("Tool") then
		if not force and chosen and chosen:IsAncestorOf(child) then
			attemptDebug("Tool has failed to destroy attempt using force", print)
			return
		end
		local Data = ToolInstances[child]
		if Data then
			if Data["ID"] ~= nil then
				Data["ID"]:_Destroy()
				Data["ID"] = nil
			end
			if Data["Equip"] ~= nil then
				Data["Equip"]:Disconnect()
				Data["Equip"] = nil
			end
			if Data["Unequip"] ~= nil then
				Data["Unequip"]:Disconnect()
				Data["Unequip"] = nil
			end
		end
		ToolInstances[child] = nil
	else
		attemptDebug("Tool is not existing in toolinstances somehow", warn)
	end
end
function stopTracking(Char, Humanoid, Data)
	Humanoid.Died:Once(function()
		for tool, data_ in pairs(ToolInstances) do
			unregisterTool(tool, BackPack, true)
		end
	end)
end
function startTracking(Char)
	local Humanoid = CSA.Humanoid(Char) :: Humanoid
	local a = Char.ChildAdded:Connect(function(child)
		setupTool(child)
	end)
	local b = Char.ChildRemoved:Connect(function(child)
		unregisterTool(child, BackPack)
	end)
	local c = BackPack.ChildRemoved:Connect(function(child)
		unregisterTool(child, Char)
	end)
	local Data = {a, b, c}
	table.insert(ActiveConnections, a)
	table.insert(ActiveConnections, b)
	table.insert(ActiveConnections, c)
	stopTracking(Char, Humanoid, Data)
end
function charSetup(Char:Model)
	if functionIsRunning then
		return
	end
	functionIsRunning = true
	if not Char then
		attemptDebug("Character does not exist in charsetup", warn)
		return
	end
	local ConnForceCleared
	for _, con in ipairs(ActiveConnections) do
		if typeof(con) == "RBXScriptConnection" then
			ConnForceCleared = true
			con:Disconnect()
		end
	end
	table.clear(ActiveConnections)
	if ConnForceCleared then
		attemptDebug("Player somehow respawnewd first and then died.", warn)
	end
	updateArmReferences(Char)
	startTracking(Char)
	functionIsRunning = false
end
function publicArmHandler(Key:string, Data:{any})
	if Key == SENDOR then
		for i, PlayerData in ipairs(Data) do
			if typeof(PlayerData) ~= "table" then
				continue
			end
			local PlayerCharacter = PlayerData[1]
			local TargetC0 = PlayerData[2]
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
charSetup(Character)
Player.CharacterAdded:Connect(function(Character)
	charSetup(Character)
end)
RME.OnClientEvent:Connect(publicArmHandler)