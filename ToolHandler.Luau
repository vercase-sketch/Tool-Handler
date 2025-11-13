--[[
	Author: TheOneAndOnlyReza
	Details: This script handles tools and allows use of other tools with just one script allowing it to run better for older model phones that are bad with multi-tasking
	Script context: LocalScript

]]--

-- Part 1

--[[
Debugging mode is to find out what went wrong with the script, if debugging is set to true it will print or warn or sometimes even error depending on what I will be passing through the debugging function 

Services:
Runservice will be used to animate the localplayer RightUpperArm (inaccessible inside this script. Its used inside a ModuleScript)
ReplicatedStorage will be used to store ModuleScripts, Remote events that are accessible by the server and the client 


Module Script loading safety:
Each module script is located in its own folder like MDS (All modulescripts), RM (All remote events) to keep things organised
And if no folder or modulescript can be found or required it will error out 

Module CSA Use case:
Module CSA has all the basics down to get data from the player 
such as Player, Character, BodyParts, Assigning MOTOR6D to keep things organised and in case something is wrong I will only have to edit one function inside CSA

Module AMA Use Case
AMA is mainly used to animate the players arm and send the players arm orientation to the server while also having all the tool functions stored inside there
such as: Equipped Unequipped Functions, Tool Activation functions and more

Player BackPack will be accuired using my CSA module
Use Case: Track items inside backpack to know if player has equipped/unequipped the tool or dropped the tool

Player Character Use case: Track which tool has been equipped/Unequipped/Dropped and also to locate the arm and store it inside a variable inside AMA

]]


-- DEBUG_MODE MODE
local DEBUG_MODE = true

-- Services 
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Folders
local MDS = ReplicatedStorage:WaitForChild("MDS", 30) 									
local RM = ReplicatedStorage:WaitForChild("RM", 30)

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
local BackPack = CSA.LocalPlayer().Backpack  
local Character = CSA.Character(CSA.LocalPlayer()) 

-- Remote events
local RME = RM:WaitForChild("MOVEMENT", 30)

if not RM or not RME then 
	attemptDebug("RM or RME not found in replicated storage", warn) 
end

-- Remote event keys
--> Key for when receiving data from the server in this case this key will be used to receive other players arm animation data
local SENDOR = "SR" 

-- Part 2
--[[
LocalPlayer is required to be able to keep track of the players tools in case when the player dies or respawns
RME = Remote event to send data to server about the players Right Upper Arm CFrames
Camera is required to be able to determine what angle the arm should be pointing at

ToolInstances table will track all the created tools and their connections
ActiveConnections table will track the connections for where the tools go to detect when the tool has been equipped / unequipped
Tools = a reference variable for a table of functions for tools 
Player is just a reference to LocalPlayer
]]

-- Key Variables for ArmMovementAnimator Modulescript
AMA.LP = CSA.LocalPlayer() :: Player --> Returns localplayer
AMA.RME =  RME 
AMA.CAMERA = CSA.Camera() --> Returns currentcamera 

-- Tables
local ToolInstances = {} 
local ActiveConnections = {} 
local Tools = AMA.Tools 
local Player = AMA.LP

-- Functions

-- Part 3
--[[

Function attemptDebug(value, TYPE) is a function to prompt debug messages
	--> Value = the value to be printed
	--> TYPE  = the type of function to be used (print, warn, error)
	
	if Debugging is not enabled then it wont print anything. Returns true or false if the debugging worked or not
end

Function UpdateArmReferences(char) is a function to update the arm references for the player when the player respawns
	--> Char = the character to update the arm references for
	
	Stores the RightShoulder (Motor6D) into Arm Movement Animator to control the arm's CFrame
	Resets TargetC0 to 0 so the arm wont trip when turning the arm movement animator 
	TargetC0 stores the calculated CFrame's of the arm from the Camera's Y angle 
	ReAssigns Character values to the AMA modulescript in case destroyed or moved
	Store the players previous RightUpperShoulder inside AMA.PrevPos to swap the players arm back to the previous position when tool is unequipped/Disabled AMA
	
]]--

function attemptDebug(value:string, TYPE) : boolean
	if value == nil or TYPE == nil then 
		print("Value or type cannot be nil!")
		return false
	end
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
	AMA.CHAR = CSA.Character(CSA.LocalPlayer()):: Model 
	AMA.RIGHTARM, AMA.RIGHTJOINT6D = CSA.GCP(char, Enum.BodyPartR15.RightUpperArm)  
	if AMA.RIGHTARM then 
		AMA.RIGHTJOINT6D = AMA.RIGHTARM:FindFirstChild("RightShoulder")
		if AMA.RIGHTJOINT6D then
			AMA.PrevPos = CFrame.new(AMA.RIGHTJOINT6D.C0.Position) 
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

SetupTool is called everytime a new tool is equipped and only runs if the tool is valid and Tool is not already set up
	--> Tool = the tool to set up
	
	Checks if the tool is a Tool and if it is not already set up in ToolInstances
	Sets up ArmMovementAnimator for the tool and stores it inside the ToolInstances table if ToolId exists
	
	Checks if the tool has a Type Attribute 
	Assign the tool to equipped and unequipped with the tool's attribute and pass in ToolId self parameters to allow functionality of for example a flashlight: returns parts of the tool to turn it on and off
	Then store all those connections inside ToolInstances within a dictionary findable by the tool	
]]

local function setupTool(tool:Tool)
	local conna, connb
	
	if not tool:IsA("Tool") then
			attemptDebug("Passed in parameter is not a tool!", warn)
		return 
	end 
	
	if ToolInstances[tool] then --> If this tool already has a record inside ToolInstances then there is no need to set it up again
		attemptDebug("Tool instance already exists do not setup further", print)
		return 
	end 

	local ToolId = AMA.New(tool) -- Returns new self parameters for the tool mainly for the arm movement animations
	if not ToolId then -- If it returned false then there is no need to set up the tool
		attemptDebug("ToolId returned false!")
		return
	end

	local toolattribute = tool:GetAttribute("Type") --> Returns the name of the tool in a string
	if toolattribute == nil then -- If nothing returned then print this out
		attemptDebug("ToolType does not exist!", warn)
		return
	end
	
	-- Checks if tool name exists inside Tools tables and set up connections for the tool to work if equipped and unequipped
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
		attemptDebug("Tools does not have equipped for this tool", warn)
	end -- Store the connections and insert them into a ToolInstances  
	ToolInstances[tool] = {ToolId, conna, connb}
end

-- Part 5
--[[
Use case:  Destroy and DestroyImmediate is used when the tool suddenly becomes nil or gets removed from the character / backpack 
to prevent errors on Runservice for when the tool becomes void

function Destroy(child, chosen, force)
	--> child	= to check wether if it is a tool and check if chosen is ancestor of child
	--> chosen	= ^
	--> force	= if true then dont check if chosen is ancestor of child
	
	Heartbeat:Wait() used for when the player moved his tool
	In DestroyImmediate this isnt called because DestroyImmediate will only be called if the the tool falls into the void or player and attempt to instantly destroy the connections before garbage collection picks them up
	
end
]]

function destroy(child, chosen, force) --> If the tool is removed from the players character this function is called
	if child:IsA("Tool") then
		RunService.Heartbeat:Wait() 	
		if not force and chosen:IsAncestorOf(child) then  --> Chosen argument is the parent of the tool that I want to exclude from destroying the tools if force is true then chosen does not matter
			attemptDebug("tool failed to destroy attempt using force", print)
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
			end-- Wether it worked or not it needs to remove itself from the table and clean up memory
			Data = nil
			ToolInstances[child] = nil
		else
			attemptDebug("Tool is not existing in toolinstances somehow", warn)
		end
	end
end

function destroyImmediate(child, chosen, force) --> This function destroys the tool data instantly if the tool suddenly becomes nil or gets removed from the character to prevent errors on Runservice for the sudden nil issue
	if child:IsA("Tool") then
		if not force and chosen:IsAncestorOf(child) then  --> Chosen argument is the parent of the tool that I want to exclude from destroying the tools if force is true then chosen does not matter
				attemptDebug("Tool has failed to destroy attempt using force", print)			
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
		end-- Wether it worked or not it needs to remove itself from the table and clean up memory 
		Data = nil			
		ToolInstances[child] = nil
	else
		attemptDebug("Tool is not existing in toolinstances somehow", warn)
	end
end

-- Part 6: Character Setup

--[[
	This script sets up connections to start tracking the tools to find out wether tool has been equipped or not
	Needs to be ran everytime the player respawns because some connections become invalid and then the script will stop tracking certain areas of the players tools
	
	Safety measures: Check if connections already exist. if they exist then disconnect them and clear the table to prevent memory leaks or race fights or complete halt of script
	
	Script runs UpdateArmReferences and also starts tracking the tools and store the data
	Script adds a connection to check wether the player has died to clear up the connections and then will create new connections to track the tools again
	Needs to run every spawn because when the player dies a part of tracking stops working and arm references will be nil 
]]

function charSetup(Char:Model)
	if not Char then
		attemptDebug("Character does not exist in charsetup", warn)
		return 
	end
	
	local conncleared
	-- If player somehow respawns before dying or something clear up the connections
	for _, con in ipairs(ActiveConnections) do
		conncleared = true
		con:Disconnect()
	end
	table.clear(ActiveConnections)
	
	if conncleared then
		attemptDebug("Player somehow respawnewd first and then died.", warn)
	end
	
	updateArmReferences(Char) --> Either setup the armreferences or Reset the arm references just in case the Characters child variable becomes nil 

	--> Create connections to track the tools and store the data
	local a = Char.ChildAdded:Connect(function(child)
		setupTool(child)
	end)

	--> If a player unequips tool attempt to destroy the tool data 
	local b = Char.ChildRemoved:Connect(function(child)
		destroy(child, BackPack)
	end)

	--> If a player unequips the tool attempt to destroy the tool data
	local c = BackPack.ChildRemoved:Connect(function(child)
		destroy(child, Char)
	end)

	-- Store all the connections inside a table and disconnect them when the player dies
	table.insert(ActiveConnections, a)
	table.insert(ActiveConnections, b)
	table.insert(ActiveConnections, c)

	local Humanoid = CSA.Humanoid(Char) :: Humanoid
	Humanoid.Died:Once(function()  --> Once the player dies clear up the connections and destroy all the tool data No need to store this because it will run only once and is needed only once (when humanoid dies you need to reconnect humanoid)
		a:Disconnect()
		b:Disconnect()
		c:Disconnect()
		a, b, c = nil, nil, nil
		
		local BackPackitems = BackPack:GetDescendants() --> Get all backpack items
		local CharItems = Char:GetDescendants() --> Get all character items (I dont use findfirstchildofclass because sometimes there can be a bug where you have two tools equipped at the same time)
		for _, tool in ipairs(BackPackitems) do --> Loop through all backpack items and forcefully remove the tooldata to clean memory
			destroyImmediate(tool, BackPack, true)
		end

		for _, tool in ipairs(CharItems) do --> Loop through all character items and forcefully remove the tooldata and obviously tools only to clean memory
			destroyImmediate(tool, Char, true)
		end
	end)
end

-- Part 7:
--[[
Function PublicArmHandler(Key, Data)
--> Use case: Assigns other player's assigned Arm CFrames to their arms because the server is not replicating the animation. Its all replicated locally through remote events
	--> Key = to determine wether the server is sending CFrames of others
	--> Data = is an dictionary of the players with their assigned arm CFrames stored inside their dictionaries
	--> Updates arm data if all validations pass
	
	Function is linked to the RemoteEvent OnclientEvent RBXSignal
end
]]

function publicArmHandler(Key:StringValue, Data:table)
	if Key == SENDOR then --> If the key is sendor then we know how to handle data
		for i, PlayerData in ipairs(Data) do
			local PlayerCharacter = PlayerData[1] -- Get the playercharacter
			local TargetC0 = PlayerData[2] -- Get the targetCFrame0
			if not PlayerCharacter or not TargetC0 then -- If none of those exist then dont do anything
					print("PlayerCharacter or TargetC0 does not exist..")
				continue
			end 
			local RUA = PlayerCharacter:FindFirstChild("RightUpperArm") :: BasePart --> Get the rightupperarm of that player 
			if RUA then
				local RS = RUA:FindFirstChild("RightShoulder") :: Motor6D --> Get the Shoulder Motor6D of that arm if the arm exists
				if RS then -- If the Motor6D exists then assign the TargetCFrame to the motor6d
					RS.C0 = TargetC0
				else
					if RS then
						attemptDebug("RS IS NIL", warn)
					end
				end
			else 
				attemptDebug("rua is nil", warn)
			end
		end
	end
end

charSetup(Character) --> Initial setup (blocks execution until character is there)

Player.CharacterAdded:Connect(function(Character) --> Every time the player respawns the character needs to be setup again because parts like the arm references will become nil
	charSetup(Character)
end)

-- Check for server sending you other player arm angles to you and assign properly. Expected data send rate is 500ms (Will start handling this with tables to reduce strain)
-- Needs update (Handle everyone in a table sent by server instead of per player each)
RME.OnClientEvent:Connect(publicArmHandler)

--> In the rules it was stated to explain the code as if you know the Roblox API very well. Specifically asked about CFrames, Therefore I have added some code from the AMA module that handles the arm movement. Explaining it broadly as if you know absolutely nothing about coding

	self.Correlation = coroutine.create(function() --> To keep things simple I am using a coroutine to allow multitasking of the use of the tool whilst also being able to disable it whenever it is required example: needs to play other animations to replace the battery 
		while true do
			if not self.TOOL then --> This is a memory leak prevention 
				warn("Possible memory leak prevention has passed!") -- dunno if this works we'll have to check on release on the error logs on site
				coroutine.close(self.Correlation)
			end --> These lines above are a safety check. if the tool is missing or destroyed it stops the coroutine to avoid wasting memory. It also sends out a warning so the developer can see it later

            --> Sending data to the server.
            --> Understanding server logic:
            --> Player sends TargetCFrames for his RightUpperShoulder, Server checks if the CFrame meets its minimum-Maximum angle requirements 
            --> If those requirements meet it will store his data inside a Dictionary and every 0.4 seconds it hands out the dictionary to all the recipients excluding the data of the recipient 


            --> This portion sends TargetCFrames stored by Runservice to the server over a remote event. When the tool is equipped it sends the current CFrames of the RightShoulder Motor6D
            --> Which contains its position and orientation
            --> If the tool is no longer equipped it will send its previous CFrame which is obtained inside UpdateCharReference(Char) And then yield

			if self.Equipped then
				if self.targetC0 ~= nil then
					self.RME:FireServer(AMA.SENDOR, self.targetC0)
				end
			else
				self.RME:FireServer(AMA.SENDOR, AMA.PrevPos)
				coroutine.yield()
			end
			task.wait(0.2)
		end
	end)
	
    --> Smooth Arm movement
    --> This is where the arm animation happens.


	if self.RIGHTJOINT6D then
		self.TempConnections["RS"] = self.RunService.RenderStepped:Connect(function(DT) --> Stores the Runservice connection inside temporary connections to disconnect once the player no longer equipped his tool
			local x, y, z = self.CAMERA.CFrame:ToEulerAnglesYXZ() --> This line of code looks at the players camera's angle favoring the Y axis first to allow the player to look at other angles without his arm breaking
			local pos = self.RIGHTJOINT6D.C0.Position --> This stores the position of the Rightjoint C0 CFrame to make it easier to read
			local clampedX = math.clamp(x, -1.5, 2) --> Here we clamp the x value (it actually is Y but this just works in my favor)
			local currentC0 = self.RIGHTJOINT6D.C0 --> Get the current CFrame of the RightShoulder Motor6D
			self.targetC0 = CFrame.new(pos) * CFrame.Angles(clampedX, 0, 0) --> Store the TargetC0 for the coroutine to pick up the data and send out to the server
			self.RIGHTJOINT6D.C0 = currentC0:Lerp(self.targetC0, self.TWEENSPEED * DT) --> Smoothly moves the Arm around 
		end)
	end
    --> Starting the Coroutine to send the TargetCFrame to the server
	if coroutine.status(self.Correlation) == "suspended" then
		coroutine.resume(self.Correlation)
	end
    --> Also store the Runservice connection inside Temporary connections for when AMA:Disable() is called it cleans up those temporary connections and stops the runservice
	table.insert(self.StoredConnections, self.TempConnections)
end



