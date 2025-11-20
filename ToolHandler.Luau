--[[
	Tool handler
	handles tool setup, equip'/unequip events and arm animatons for player
	optimized for lower end devices
	context: Localscript in ScreenGui
	ResetOnSpawn = false
	No comments no empty space: https://github.com/vercase-sketch/Tool-Handler/blob/main/ToolHandler2.Luau
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
local AMA_Module = MDS:WaitForChild("ArmMovementAnimator", 30) 

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
AMA.RME = RME

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

	-- Reset Arm angle CFrame's and reassign the character, rightarm to Module script
	AMA.targetC0 = CFrame.new() 
	AMA.char = char
	AMA.rightarm, AMA.rightjoint6d = CSA.GCP(char, Enum.BodyPartR15.RightUpperArm)  

	if AMA.rightarm then 
		AMA.rightjoint6d = AMA.rightarm:FindFirstChild("RightShoulder")
		if AMA.rightjoint6d then
			-- Safely get the rightjoint6d and store its contents into previous position 
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

	-- Check if argument is a Tool
	if tool == nil or not tool:IsA("Tool") then
		attemptDebug("Passed in parameter is not a tool!", warn)
		return 
	end 

	-- Stop if tool already exists
	if toolInstances[tool] then 
		attemptDebug("Tool instance already exists do not setup further", print)
		return 
	end 

	-- Try get new self parameters for tool
	local toolId = AMA.New(tool) 
	if not toolId then 
		attemptDebug("toolId returned false!", warn)
		return
	end

	-- Try grab tool Id for equipped/unequipped/Activated functions
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
	-- Tool setup successful store in toolInstances to prevent duplicate setup
	toolInstances[tool] = {ID = toolId, Equip = conna, Unequip = connb}
end

-- Remove tool connections and clean memory
local function unregisterTool(child, chosen, force)
	if child:IsA("Tool") then
		-- Prevent unregistering tools that were moved but not actually removed unless forced
		if not force and chosen and chosen:IsAncestorOf(child) then 
			attemptDebug("Tool has failed to destroy attempt using force", print)			
			return 
		end 

		-- Find tool inside toolInstances and disable tool
		local data = toolInstances[child]
		if data then
			if data["ID"] ~= nil then
				data["ID"]:_Destroy()  data["ID"] = nil -- This function disconnects tool.Activated and cleans self
			end 
			if data["Equip"] ~= nil then
				data["Equip"]:Disconnect() data["Equip"] = nil 
			end
			if data["Unequip"] ~= nil then
				data["Unequip"]:Disconnect() data["Unequip"] = nil
			end
		end
		-- Remove tool entry
		toolInstances[child] = nil
	else
		attemptDebug("Tool is not a tool?", warn)
	end
end

-- Check if humanoid is dead with several safety checks
local function humanoidDeath(character)
	if character and
		typeof(character) == "Instance" and 
		character:IsA("Model") then

		local humanoid = CSA.Humanoid(character)
		local health = humanoid.Health

		if health == 0 then
			return true, health -- humanoid has died
		else
			return false, health
		end
	end
	return false -- humanoid has not died
end

-- Stop tracking all tracked tools
local function stopTrackingTracker(humanoid)
	humanoid.Died:Once(function()  
		for tool in pairs(toolInstances) do
			unregisterTool(tool, backpack, true)
		end
	end)
end

-- Start tracking tools
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

-- Character setup handler on spawn
local function charSetup(Char:Model)
	if functionIsRunning then  
		return
	end 

	functionIsRunning = true
	if not Char then
		attemptDebug("Character does not exist in charsetup", warn)
		return 
	end

	-- Clean up previous connections if they exist may happen if the player dies.
	for _, con in ipairs(activeConnections) do
		if typeof(con) == "RBXScriptConnection" then
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

-- Handle events from server for other players arms
local function publicArmHandler(Key:string, Data:{any})
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