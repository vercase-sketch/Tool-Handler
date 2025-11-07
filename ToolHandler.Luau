--[[
	Author: TheOneAndOnlyReza
	Details: reader there are no comments of annotations because I think thats more than enough for you to understand. Thanks for reading
	This script handles tools and uses my AMA to receive and handle sending targetc0 cframes for the right shoulder regarding the camera's Y orientation 
]]--
-- DEBUGGING MODE
local Debug = false

-- Services 
local RunService = game:GetService("RunService") 
local ReplicatedStorage = game:GetService("ReplicatedStorage")
-- Remote events
local RM = ReplicatedStorage:WaitForChild("RM", 30)
local RME = RM:WaitForChild("MOVEMENT", 30) :: RemoteEvent
-- Module scripts

if not RM or not RME then 
	error("RM or RME not found in replicated storage") 
end

local MDS = ReplicatedStorage:FindFirstChild("MDS") :: Folder 									
if not MDS then
	error("MDS returned incorrect parameter") 
end

local CSA_Module = MDS:FindFirstChild("ClientServerAccessible") :: ModuleScript					
if not CSA_Module then 
	error("CSA MODULE RETURNED INCORRECT PARAMETER") 
end
local CSA = require(CSA_Module) :: ModuleScript
local AMA = require(MDS:FindFirstChild("ArmMovementAnimator")) :: ModuleScript

if not CSA or not AMA then 
	error("CSA OR AMA FAILED TO LOAD")
end

local SENDOR = "SR" --> This is a key for receiving target animation data from server and sending them to the server
-- Player info
local BackPack = CSA.LocalPlayer().Backpack  :: Backpack 
local Character = CSA.Character(CSA.LocalPlayer()):: Model 
-- Key Variables for ArmMovementAnimator Modulescript
AMA.RunService = RunService 
AMA.LP = CSA.LocalPlayer() :: Player 
AMA.RME =  RME
AMA.CAMERA = CSA.Camera() --> Returns currentcamera 

local ToolInstances = {} --> This table will track tools
local ActiveConnections = {} --> This table will track equipped unequipped self connections for the tools
local Tools = AMA.Tools --> Returns a table of functions for tools
local Player = AMA.LP

local function UpdateArmReferences(char)

	if not char then
		if Debug then
			warn("Char does not exist!")
		end
		return
	end

	AMA.targetC0 = CFrame.new() --> Reset TargetC0 to 0
	AMA.CHAR = CSA.Character(CSA.LocalPlayer()):: Model --> Get the players character again in case moved or nil
	AMA.RIGHTARM, AMA.RIGHTJOINT6D = CSA.GCP(char, Enum.BodyPartR15.RightUpperArm)  -- Get the rightupperarm of the character 

	if AMA.RIGHTARM then
		-- Gets the Motor6D if AMA.Rightarm is not nil
		AMA.RIGHTJOINT6D = AMA.RIGHTARM:FindFirstChild("RightShoulder")
		if AMA.RIGHTJOINT6D then
			AMA.PrevPos = CFrame.new(AMA.RIGHTJOINT6D.C0.Position) -- if Motor6D has been found store its previous position into AMA.PrevPos so when unequipping the tool arm moves back to its original position
		else
			if Debug then
				warn("Could not find RightJoint6D")
			end
		end
	else 
		if Debug then
			warn("Could not find Rightarm!")

		end
	end
end

local function SetupTool(tool:Tool)
	if not tool:IsA("Tool") then
		if Debug  then
			warn("Passed in parameter is not a tool!")
		end
		return 
	end --> Obviously need to know if this is a tool

	if ToolInstances[tool] then --> If this tool already has a record inside ToolInstances then there is no need to set it up again
		if Debug then
			print("Tool instance already exists do not setup further")
		end
		return 
	end 
	local conna, connb
	local ToolId = AMA.New(tool) -- Returns new self parameters for the tool mainly for the arm movement animations

	if not ToolId then -- If it returned false then there is no need to set up the tool
		if Debug then
			print("Toolid returned false!")
		end
		return
	end

	local toolattribute = tool:GetAttribute("Type") --> Returns the name of the tool in a string
	if toolattribute ~= nil then -- If nothing returned then print this out
		if Debug then
			warn("ToolType does not exist!")
		end
	end

	-- Checks if tool name exists inside Tools tables and set up connections for the tool to work if equipped and unequipped
	if Tools.Equipped[toolattribute] then
		conna = tool.Equipped:Connect(function()
			Tools.Equipped[toolattribute](ToolId)
		end)
	else
		if Debug then
			warn("Tools does not have equipped for this tool!!")
		end
	end

	if Tools.Unequipped[toolattribute] then
		connb = tool.Unequipped:Connect(function()
			Tools.Unequipped[toolattribute](ToolId)
		end)
	else
		if Debug then
			warn("Tools does not have equipped for this tool!!")
		end
	end
	-- Store the connections and insert them into a ToolInstances  
	ToolInstances[tool] = {ToolId, conna, connb}
end
-- Destroy and Destroy2 is used when the tool suddenly becomes nil or gets removed from the character / backpack to prevent errors on Runservice for the sudden nil issue
function Destroy(child, chosen, force) --> If the tool is removed from the players character this function is called
	if child:IsA("Tool") then
		RunService.Heartbeat:Wait() --> this is to make sure the tool is moved properly before destroying it

		if not force and chosen:IsAncestorOf(child) then  --> Chosen argument is the parent of the tool that I want to exclude from destroying the tools if force is true then chosen does not matter
			if Debug then
				print("Tool failed to destroy attempt using force")	
			end
			return 
		end 
		-- If the tool exists within setted up toolinstances continue
		if ToolInstances[child] then --> Should not fail unless tool is void
			local Data = ToolInstances[child] --> Shorten the variable to make it easier to read			
			if Data then
				if Data[1] ~= nil then
					Data[1]:_Destroy()  Data[1] = nil 
				end --> Data1 is the modulescript self parameters
				if Data[2] ~= nil then 
					Data[2]:Disconnect() Data[2] = nil 
				end --> Data2, Data3 is the equipped unequipped connections 
				if Data[3] ~= nil then 
					Data[3]:Disconnect() Data[3] = nil 
				end
			end
			-- Wether it worked or not it needs to remove itself from the table and clean up memory
			Data = nil
			ToolInstances[child] = nil
		else
			if Debug then
				warn("Tool is not existing in toolinstances somehow")
			end
		end
	end
end

function Destroy2(child, chosen, force) --> This function destroys the tool data instantly if the tool suddenly becomes nil or gets removed from the character to prevent errors on Runservice for the sudden nil issue
	if child:IsA("Tool") then
		if not force and chosen:IsAncestorOf(child) then  --> Chosen argument is the parent of the tool that I want to exclude from destroying the tools if force is true then chosen does not matter
			if Debug then
				print("Tool failed to destroy attempt using force")	
			end
			return 
		end 
		-- If the tool exists within setted up toolinstances continue
		local Data = ToolInstances[child] --> Shorten the variable to make it easier to read
		if Data then
			if Data[1] ~= nil then
				Data[1]:_Destroy()  Data[1] = nil
			end --> Data1 is the modulescript self parameters
			if Data[2] ~= nil then
				Data[2]:Disconnect() Data[2] = nil 
			end --> Data2, Data3 is the equipped unequipped connections 
			if Data[3] ~= nil then
				Data[3]:Disconnect() Data[3] = nil
			end
		end
		-- Wether it worked or not it needs to remove itself from the table and clean up memory 
		Data = nil			
		ToolInstances[child] = nil
	else
		if Debug then
			warn("Tool is not existing in toolinstances somehow")
		end
	end
end

function CharSetup(Char:Model)
	-- If player somehow respawns before dying or something clear up the connections
	for _, con in ipairs(ActiveConnections) do
		if Debug then
			warn("Player somehow respawned first and then died?")
		end
		con:Disconnect()
	end
	table.clear(ActiveConnections)

	UpdateArmReferences(Char) --> Either setup the armreferences or Reset the arm references just in case the Character variable becomes nil 

	--> If player equips a tool attempt to setup the tool
	local a = Char.ChildAdded:Connect(function(child)
		SetupTool(child)
	end)

	--> If a player unequips tool attempt to destroy the tool data 
	local b = Char.ChildRemoved:Connect(function(child)
		Destroy(child, BackPack)
	end)

	--> If a player unequips the tool attempt to destroy the tool data
	local c = BackPack.ChildRemoved:Connect(function(child)
		Destroy(child, Char)
	end)

	-- Store all the connections inside a table and track them when the player dies
	table.insert(ActiveConnections, a)
	table.insert(ActiveConnections, b)
	table.insert(ActiveConnections, c)

	local Humanoid = CSA.Humanoid(Char) :: Humanoid

	Humanoid.Died:Once(function()  --> Once the player dies clear up the connections and destroy all the tool data

		a:Disconnect()
		b:Disconnect()
		c:Disconnect()
		a, b, c = nil, nil, nil

		local BackPackitems = BackPack:GetDescendants() --> Get all backpack items
		local CharItems = Char:GetDescendants() --> Get all character items (I dont use findfirstchildofclass because sometimes there can be a bug where you have two tools equipped at the same time)

		for _, tool in ipairs(BackPackitems) do --> Loop through all backpack items and forcefully remove the tooldata
			Destroy2(tool, BackPack, true)
		end

		for _, tool in ipairs(CharItems) do --> Loop through all character items and forcefully remove the tooldata and obviously tools only
			Destroy2(tool, Char, true)
		end
	end)
end

CharSetup(Character) --> Initial setup (blocks execution until character is there)

Player.CharacterAdded:Connect(function(Character) --> Player respawn setup
	CharSetup(Character)
end)
-- Check for server sending you other player arm angles to you and assign properly. Expected data send rate is 500ms (Will start handling this with tables to reduce strain)
-- Needs update (Handle everyone in a table sent by server instead of per player each)
RME.OnClientEvent:Connect(function(Key:string, Data:table)

	if Key == SENDOR then --> the key SENDOR is for the arm animation to validate just in case 
		for i, PlayerData in ipairs(Data) do
			local PlayerCharacter = PlayerData[1] -- Get the playercharacter
			local TargetC0 = PlayerData[2] -- Get the targetCFrame0
			if not PlayerCharacter or not TargetC0 then -- If none of those exist then dont do anything
				if Debug then
					print("PlayerCharacter or TargetC0 does not exist..")
				end
				continue
			end 
			local RUA = PlayerCharacter:FindFirstChild("RightUpperArm") :: BasePart --> Get the rightupperarm of that player 
			if RUA then
				local RS = RUA:FindFirstChild("RightShoulder") :: Motor6D --> Get the Shoulder Motor6D of that arm if the arm exists
				if RS then -- If the Motor6D exists then assign the TargetCFrame to the motor6d
					RS.C0 = TargetC0
				else
					if RS then
						if Debug then
							warn("RS is NIL")
						end
					end
				end
			else 
				if Debug then
					warn("RUA is nil")
				end
			end

		end
	end
end)
