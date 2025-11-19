--[[
	Details: This script handles tools and allows use of other tools with just one script allowing
	it to run better for older model phones that are bad with multi-tasking
	Script context: LocalScript
	Special thanks to you for reading my application. I hope I have explained everything well and 
	following the rules. Have a great day.
]]--

-- Part 1

--[[
Debugging mode is to find out what went wrong with the script, if debugging is set to true it will
print or warn or sometimes even error depending on what I will be passing through the debugging function 

Services:
Runservice will be used to animate the localplayer RightUpperArm (inaccessible inside this script.
Its used inside a ModuleScript)
ReplicatedStorage will be used to store ModuleScripts, Remote events that are accessible by the
server and the client 


Module Script loading safety:
Each module script is located in its own folder like MDS (All modulescripts), RM (All remote events)
to keep things organised
And if no folder or modulescript can be found or required it will error out 

Module CSA Use case:
Module CSA has all the basics down to get data from the player 
such as Player, Character, BodyParts, Assigning MOTOR6D to keep things organised 
and in case something is wrong I will only have to edit one function inside CSA

Module AMA Use Case
AMA is mainly used to animate the players arm and send the players arm orientation 
to the server while also having all the tool functions stored inside there
such as: Equipped Unequipped Functions, Tool Activation functions and more

Player BackPack will be accuired using my CSA module
Use Case: Track items inside backpack to know if player has equipped/unequipped the tool or
dropped the tool

Player Character Use case: Track which tool has been equipped/Unequipped/Dropped and also to
 locate the arm and store it inside a variable inside AMA

CODE WITH NO COMMENTS AND EMPTY LINES: https://github.com/vercase-sketch/Tool-Handler/blob/main/ToolHandler2.Luau
]]

-- Services 
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Folders
local MDS = ReplicatedStorage:WaitForChild("MDS", 30) 									
local RM = ReplicatedStorage:WaitForChild("RM", 30)

-- DEBUG_MODE MODE
local DEBUG_MODE = true
--> Debounce for charsetup to prevent race fighting
local functionIsRunning = false

local function attemptDebug(value:string, TYPE) : boolean
	if value == nil then 
		warn("AttemptDebug received incorrect arguments!")
		return false
	end
	value = tostring(value)
	TYPE = TYPE or print --> If TYPE was not passed in then use standard print function
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

-- Module scripts

local CSA_Module = MDS:WaitForChild("ClientServerAccessible", 30) 					
if not CSA_Module then 
	attemptDebug("CSA MODULE RETURNED INCORRECT PARAMETER", warn) 
end

local CSA = require(CSA_Module)
local AMA = require(MDS:WaitForChild("ArmMovementAnimator", 30)) 

if not CSA or not AMA then 
	attemptDebug("CSA OR AMA FAILED TO LOAD", warn)
end

-- Player info
local character = CSA.Character(CSA.LocalPlayer()) 
local backpack = CSA.LocalPlayer():WaitForChild("Backpack", 5)  

-- Remote events
local RME = RM:WaitForChild("MOVEMENT", 30)

if not RME then 
	attemptDebug("RM or RME not found in replicated storage", warn) 
end

-- Remote event keys
--> Key for when receiving data from the server in this case this key will be used to receive other
--> players arm animation data
local SENDOR = "SR" 

-- Part 2
--[[
LocalPlayer is required to be able to keep track of the players tools in case when 
the player dies or respawns
RME = Remote event to send data to server about the players Right Upper Arm CFrames
Camera is required to be able to determine what angle the arm should be pointing at

ToolInstances table will track all the created tools and their connections
ActiveConnections table will track the connections for where the tools go to detect
when the tool has been equipped / unequipped
Tools = a reference variable for a table of functions for tools 
Player is just a reference to LocalPlayer
]]

-- Key Variables for ArmMovementAnimator Modulescript
AMA.LP = CSA.LocalPlayer() :: Player --> Returns localplayer
AMA.RME =  RME 
AMA.CAMERA = CSA.Camera() --> Returns currentcamera 

-- Tables
local toolInstances = {} 
local activeConnections = {} 
local Tools = AMA.Tools 
local player = AMA.LP

-- Functions

-- Part 3
--[[

Function attemptDebug(value, TYPE) is a function to prompt debug messages
	--> Value = the value to be printed
	--> TYPE  = the type of function to be used (print, warn, error)
	
	if Debugging is not enabled then it wont print anything. Returns true 
	or false if the debugging worked or not
end

Function UpdateArmReferences(char) is a function to update the arm references 
	for the player when the player respawns
	--> Char = the character to update the arm references for
	
	Stores the RightShoulder (Motor6D) into Arm Movement Animator to control the arm's 
	CFrame Resets TargetC0 to 0 so the arm wont trip when turning the arm movement animator 
	TargetC0 stores the calculated CFrame's of the arm from the Camera's Y angle 
	ReAssigns Character values to the AMA modulescript in case destroyed or moved
	Store the players previous RightUpperShoulder inside AMA.PrevPos to swap the
	 players arm back to the previous position when tool is unequipped/Disabled AMA
	
]]--



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

-- Part 4
--[[
SetupTool(Tool)

SetupTool is called everytime a new tool is equipped and only runs if the tool is valid
and Tool is not already set up

	--> Tool = the tool to set up
	
	Checks if the tool is a Tool and if it is not already set up in
	ToolInstances and Attribute Type must match
	Sets up ArmMovementAnimator for the tool and stores it inside the
	ToolInstances table if ToolId exists
	
	Checks if the tool has a Type Attribute 
	Assign the tool to equipped and unequipped with the tool's attribute and pass in ToolId 
	self parameters to allow functionality of for example a flashlight: returns parts of the tool to turn it on and off
	Then store all those connections inside ToolInstances within a dictionary findable by the tool	
]]

local function setupTool(tool:Tool)
	local conna, connb
	if not tool:IsA("Tool") then
			attemptDebug("Passed in parameter is not a tool!", warn)
		return 
	end 
	--> If this tool already has a record inside ToolInstances then there is no need to set it up again
	if toolInstances[tool] then 
		attemptDebug("Tool instance already exists do not setup further", print)
		return 
	end 
	-- Returns new self parameters for the tool mainly for the arm movement animations
	local toolId = AMA.New(tool) 
	if not toolId then 
		attemptDebug("toolId returned false!", warn)
		return
	end
	-- If it returned false then there is no need to set up the tool
	local toolattribute = tool:GetAttribute("Type") --> Returns the name of the tool in a string
	if toolattribute == nil then -- If nothing returned then print this out
		warn("Tool has no attribute!")
		return
	end
	
	-- Checks if tool name exists inside Tools tables and set up connections for the tool
	-- to work if equipped and unequipped
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
	-- Store the connections and insert them into a ToolInstances
	toolInstances[tool] = {ID = ToolId, Equip = conna, Unequip = connb}
end

-- Part 5
--[[
Use case:  unregistertool is used when the tool suddenly becomes nil or gets removed
from the character / backpack 
to prevent errors on Runservice for when the tool becomes void

function unregisterTool(child, chosen, force)
	--> child	= to check wether if it is a tool and check if chosen is ancestor of child
	--> chosen	= ^
	--> force	= if true then dont check if chosen is ancestor of child
	--> Simply tries to remove the tool from memory by disconnecting itself	
end
]]

function unregisterTool(child, chosen, force) --> This function unregisters registered tools when player drops them
	if child:IsA("Tool") then
		 --> Chosen argument is the parent of the tool that I want to exclude from destroying 
		 --> the tools if force is true then chosen does not matter
		if not force and chosen and chosen:IsAncestorOf(child) then 
				attemptDebug("Tool has failed to destroy attempt using force", print)			
			return 
		end 
		-- If the tool exists within setted up toolinstances continue
		local data = toolInstances[child] --> Shorten the variable to make it easier to read
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
		-- Wether it worked or not it needs to remove itself from the table and clean up memory 
		toolInstances[child] = nil
	else
		attemptDebug("Tool is not existing in toolinstances somehow", warn)
	end
end

-- Part 6: Character Setup

--[[
	This script sets up connections to start tracking the tools
	to find out wether tool has been equipped or not
	
	Needs to be ran everytime the player respawns because some connections
	become invalid and then the script will stop tracking certain areas of the players tools
	Safety measures: Check if connections already exist. if they exist then disconnect them
	and clear the table to prevent memory leaks or race fights or complete halt of script
	
	Script runs UpdateArmReferences and also starts tracking the tools and store the data
	Script runs Register which adds a connection to check wether the player has died to clear up the
	connections and then will create new connections to track the tools again
	Needs to run every spawn because when the player dies a part of tracking stops working and arm references will be nil 
]]

--> Once the player dies clear up the connections and destroy all 
--> the tool data No need to store this because it will run only once and is needed 
--> only once (when humanoid dies you need to reconnect humanoid)		
function stopTracking(char, Humanoid, Data)
	Humanoid.Died:Once(function()  
		for tool, data_ in pairs(toolInstances) do --> Loop through all backpack items and forcefully remove the tooldata to clean memory
			unregisterTool(tool, backpack, true)
		end
	end)
end

function startTracking(Char)	
	local Humanoid = CSA.Humanoid(Char) :: Humanoid
	--> Create connections to track the tools and store the data
	local a = Char.ChildAdded:Connect(function(child)
		setupTool(child)
	end)

	--> If a player unequips tool attempt to destroy the tool data 
	local b = Char.ChildRemoved:Connect(function(child)
		unregisterTool(child, backpack)
	end)

	--> If a player unequips the tool attempt to destroy the tool data
	local c = backpack.ChildRemoved:Connect(function(child)
		unregisterTool(child, Char)
	end)

	-- Store all the connections inside a table and disconnect them when the player dies
	local Data = {a, b, c}
	table.insert(ActiveConnections, a)
	table.insert(ActiveConnections, b)
	table.insert(ActiveConnections, c)

	--> Assigns a connection that will track on the players death
	stopTracking(Char, Humanoid, Data)
	--> If player dies it needs to stop tracking and start tracking again upon respawn
end

function charSetup(Char:Model)
	if functionIsRunning then  --> Safety measurement against Race fights
		return
	end 
	functionIsRunning = true
	if not Char then
		attemptDebug("Character does not exist in charsetup", warn)
		return 
	end
	
	local ConnForceCleared
	-- If player somehow respawns before dying or something clear up the connections
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
	--> Either setup the armreferences or Reset the arm references just in case
	--> the Characters child variable becomes nil 
	updateArmReferences(Char) 
	startTracking(Char)
	functionIsRunning = false
end

-- Part 7:
--[[
Function publicArmHandler(Key, Data)
--> Use case: Assigns other player's assigned Arm CFrames to their arms because the server
 is not replicating the animation. Its all replicated locally through remote events
	--> Key = to determine wether the server is sending CFrames of others
	--> Data = is an dictionary of the players with their assigned arm CFrames stored inside their dictionaries
	--> Updates arm data if all validations pass
	
	Function is linked to the RemoteEvent OnclientEvent RBXSignal
end
]]

function publicArmHandler(Key:string, Data:{any})
	if Key == SENDOR then --> If the key is sendor then we know how to handle data
		for i, playerdata in ipairs(Data) do
			if typeof(playerdata) ~= "table" then
				continue
			end
			local PlayerCharacter = playerdata[1] -- Get the playercharacter
			local TargetC0 = playerdata[2] -- Get the targetCFrame0
			if not PlayerCharacter or not TargetC0 then -- If none of those exist then dont do anything
					attemptDebug("PlayerCharacter or TargetC0 does not exist..", warn)
				continue
			end 
			local RUA = PlayerCharacter:FindFirstChild("RightUpperArm") :: BasePart --> Get the rightupperarm of that player 
			if RUA then
				local RS = RUA:FindFirstChild("RightShoulder") :: Motor6D --> Get the Shoulder Motor6D of that arm if the arm exists
				if RS then -- If the Motor6D exists then assign the TargetCFrame to the motor6d
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

charSetup(character) --> Initial setup (blocks execution until character is there)
--> Every time the player respawns the character needs to be setup again because parts like the arm references will become nil
Player.CharacterAdded:Connect(function(character) 
	charSetup(character)
end)

-- Check for server sending you other player arm angles to you and assign properly. 
--Expected data send rate is 500ms (Will start handling this with tables to reduce strain)
-- Needs update (Handle everyone in a table sent by server instead of per player each)
RME.OnClientEvent:Connect(publicArmHandler)