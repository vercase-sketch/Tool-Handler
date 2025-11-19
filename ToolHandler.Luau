--[[
	Tool handler
	handles tool setup, equip'/unequip events and arm animatons for player
	optimized for lower end devices
	context: Localscript
]]--


-- Services 
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Folders
local MDS = ReplicatedStorage:WaitForChild("MDS", 30) 									
local RM = ReplicatedStorage:WaitForChild("RM", 30)

-- Folders safety checks
if not RM then
	warn("RM does not exist")
end

if not MDS then
	warn("MDS returned incorrect parameter") 
end

-- Module scripts
local CSA_Module = MDS:WaitForChild("ClientServerAccessible", 30) 					
local AMA_Module = MDS:WaitForChild("MovementAnimator", 30) 

local CSA = require(CSA_Module)
local AMA = require(AMA_Module)

-- Constants
local DEBUG_MODE = true
local SENDOR = "SR" 

-- debounce to prevent race conditions
local functionIsRunning = false

-- Tables
local Tools = AMA.Tools 
local toolInstances = {} 
local activeConnections = {} 

-- Remote events
local RME = RM:WaitForChild("MOVEMENT", 30)
AMA.RME =  RME

-- Player references
local character = CSA.Character(CSA.LocalPlayer()) 
local backpack = CSA.LocalPlayer():WaitForChild("Backpack", 5)  
local player = CSA.LocalPlayer() -- Returns localplayer safely

-- Assign player references 
AMA.LP = player
AMA.CAMERA = CSA.Camera() -- Returns currentcamera 

-- Debug function
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

-- Update arm references for local player
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

-- Setup tool connections
local function setupTool(tool:Tool)
	local conna, connb
	if not tool:IsA("Tool") then
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

	local toolattribute = tool:GetAttribute("Type") --> Returns the name of the tool in a string
	if toolattribute == nil then -- If nothing returned then print this out
		warn("Tool has no attribute!")
		return
	end

	if Tools.Equipped[toolattribute] then
		conna = tool.Equipped:Connect(function()
			Tools.Equipped[toolattribute](toolId)
		end)
	else
		attemptDebug("Tools does not have equipped for this tool!", warn)
	end

	if Tools.Unequipped[toolattribute] then
		connb = tool.Unequipped:Connect(function()
			Tools.Unequipped[toolattribute](toolId)
		end)
	else
		attemptDebug("Tools does not have unequipped for this tool", warn)
	end 
	toolInstances[tool] = {ID = toolId, Equip = conna, Unequip = connb}
end

-- Remove tool connections and clean memory
function unregisterTool(child, chosen, force)
	if child:IsA("Tool") then
		if not force and chosen and chosen:IsAncestorOf(child) then 
			attemptDebug("Tool has failed to destroy attempt using force", print)			
			return 
		end 

		local data = toolInstances[child]
		if data then
			if data["ID"] ~= nil then
				data["ID"]:_Destroy()  data["ID"] = nil
			end --> Data1 is the modulescript self parameters
			if data["Equip"] ~= nil then
				data["Equip"]:Disconnect() data["Equip"] = nil 
			end --> Data2, Data3 is the equipped unequipped connections 
			if data["Unequip"] ~= nil then
				data["Unequip"]:Disconnect() data["Unequip"] = nil
			end
		end

		toolInstances[child] = nil
	else
		attemptDebug("Tool is not a tool?", warn)
	end
end

-- Stop tracking all tracked tools
function stopTracking(char, Humanoid, Data)
	Humanoid.Died:Once(function()  
		for tool, data_ in pairs(toolInstances) do
			unregisterTool(tool, backpack, true)
		end
	end)
end

-- Start tracking tools
function startTracking(Char)	
	local Humanoid = CSA.Humanoid(Char) :: Humanoid
	local a = Char.ChildAdded:Connect(function(child)
		setupTool(child)
	end)

	local b = Char.ChildRemoved:Connect(function(child)
		unregisterTool(child, backpack)
	end)

	local c = backpack.ChildRemoved:Connect(function(child)
		unregisterTool(child, Char)
	end)

	local data = {a, b, c}
	table.insert(activeConnections, a)
	table.insert(activeConnections, b)
	table.insert(activeConnections, c)

	stopTracking(Char, Humanoid, data)
end

-- Character setup handler on spawn
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
	for _, con in ipairs(activeConnections) do
		if typeof(con) == "RBXScriptConnection" then
			ConnForceCleared = true
			con:Disconnect()
		end
	end
	table.clear(activeConnections)

	if ConnForceCleared then
		attemptDebug("Player somehow respawnewd first and then died.", warn)
	end

	updateArmReferences(Char) 
	startTracking(Char)
	functionIsRunning = false
end

-- Handle events from server for other players arms
function publicArmHandler(Key:string, Data:{any})
	if Key == SENDOR then 
		for i, playerdata in ipairs(Data) do
			if typeof(playerdata) ~= "table" then
				continue
			end

			local PlayerCharacter = playerdata[1] 	-- Get the playercharacter
			local TargetC0 = playerdata[2] 			-- Get the targetCFrame0

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

-- Initial setup
charSetup(character)

-- Respawn handling
player.CharacterAdded:Connect(function(character) 
	charSetup(character)
end)

-- Remote event listener
RME.OnClientEvent:Connect(publicArmHandler)