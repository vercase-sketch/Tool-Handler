--[[
	Arm movement animator module for toolhandler
	Handles tool equipping unequipping, switching ON/OFF, and Arm movement animation for first person tools
]]

local AMA  = {
	SWITCH = "SW", -- Remote event constant (Turning on/off tools)
	SENDOR = "SR", -- Remote event constant (Sending in arm data)
	TWEENSPEED = 8, -- Arm animation smoothness constant
}

-- Metatable for all objects created with AMA.new()
AMA.__index = AMA

-- Services
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Tables
local Tools = {} -- Stores the functions that run when a tool is equipped/unequipped
local SetupTools = {} -- Stores the functions that set up each tool (like finding lights)
local SwitchFunctions = {} -- Stores the functions that run when a tool is toggled on/off

AMA.Tools = Tools
Tools.Equipped = {}
Tools.Unequipped = {}

-- Boolean Values
local Playing = false -- Global boolean value for arm movement animation

-- Functions

-- checks if a tool object has a valid TOOL reference
-- @param item: the AMA tool object
-- @return boolean: true if the tool is valid, false otherwise
-- Warns if the tool reference is missing to help catch errors
function safeCall(item)
	if not item.TOOL then
		warn("ITEM TOOL NIL")
		return false
	end
	return true
end

-- Equipped/Unequipped functions

-- called when the flashlight is equipped by the player
-- @param item: the AMA flashlight object
Tools.Equipped.Flashlight = function(item)
	local safeToRun = safeCall(item)
	if safeToRun then
		item:Enable() -- equips the tool: plays equip sound, starts arm-animation, and connects input events
	end
end

-- called when the flashlight is unequipped by the player
-- @param item: the AMA flashlight object
Tools.Unequipped.Flashlight = function(item)
	local safeToRun = safeCall(item)
	if safeToRun then
		item:Disable() -- unequips the tool: plays equip sound, stops arm-animation, and disconnects input events
	end
end

Tools.Equipped.Match = function(item)
	local safeToRun = safeCall(item)
	if safeToRun then
		item:Enable()
	end
end

Tools.Unequipped.Match = function(item)
	local safeToRun = safeCall(item)
	if safeToRun then
		item:Disable()
	end
end

Tools.Equipped.EMF = function(item)
	local safeToRun = safeCall(item)
	if safeToRun then
		item:Enable()
	end
end

Tools.Unequipped.EMF = function(item)
	local safeToRun = safeCall(item)
	if safeToRun then
		item:Disable()
	end
end

Tools.Equipped.LockPick = function(item)
	local safeToRun = safeCall(item)
	if safeToRun then
		item:Enable()
	end
end

Tools.Unequipped.LockPick = function(item)
	local safeToRun = safeCall(item)
	if safeToRun then
		item:Disable()
	end
end

-- Switch functions - called when the tool is toggled on/off
SwitchFunctions.EMF = function(self, BoolValue:boolean)
	print("EMF!")
end

-- flashlight on/off logic
-- enables or disables the flashlight locally, updates material, notifies the server,
-- and temporarily pauses the arm movement animation
-- @param self: the AMA flashlight object
-- @param BoolValue: true to turn on, false to turn off
SwitchFunctions.Flashlight = function(self, BoolValue:boolean) -- Replicates locally and then through server for other players
	self.Enabled = BoolValue
	if self.SurfaceLight then
		-- Enable or disable the light
		self.SurfaceLight.Enabled = self.Enabled
		self.LightEmitter.Material = self.Enabled and Enum.Material.Neon or Enum.Material.SmoothPlastic
		-- Replicate to server
		self.RemoteEvent:FireServer(self.SWITCH, {self.Enabled, self.TOOL})
	end
	
	-- Temporarily stop arm movement animation
	Playing = false
	task.wait(1)
	Playing = true
end

SwitchFunctions.LockPick = function(self, BoolValue:boolean)
	print("LockPick!")
end

SwitchFunctions.Match = function(self, BoolValue: boolean)
	print("Matches")
end


-- Setup flashlight parts (called once when tool object is created) 
SetupTools.Flashlight= function(self)
	self.TurnOffOnDrop = false
	self.LightEmitter = self.TOOL:FindFirstChild("Light")
	
	-- if the flashlight has a Light part store its surfacelight
	if self.LightEmitter then	
		self.SurfaceLight = self.LightEmitter.SurfaceLight
	end
end

SetupTools.EMF = function(self)
	-- Empty
end

SetupTools.Match = function(self)
	-- Empty	
end

-- Functions

-- Creates a new AMA tool object
-- @param Tool: the roblox tool instance to wrap
-- @ return self: a new ama object with setup functions and connections

function AMA.New(Tool) 
	-- Create  a new object with Arm Movement Animator  as its metatable
	local self = setmetatable({}, AMA)
	self.TOOL = Tool
	
	-- Tables to store temporary and persistent connections
	self.TempConnections = {}
	self.StoredConnections = {}
	
	-- Track tool state
	self.Enabled, self.Equipped = false, false
	
	-- Get tooltype from its attribute to assign setupfunctions and equip/unequip/Switchfunctions properly and store it
	local ToolAttribute = Tool:GetAttribute("Type")
	if not ToolAttribute then
		warn("Tool has no type attribute")
		return false
	end
	self.TOOLATTRIBUTE = ToolAttribute
	
	-- Run setup function for this tool type (e.g. fin prats like lights)
	local ToolData
	if SetupTools[ToolAttribute] then
		ToolData = SetupTools[ToolAttribute](self)
	end	
	
	-- Find optional sounds
	self.EQUIPSOUND 	= self.TOOL:FindFirstChild("EquipSound") 
	self.SWITCHSOUND 	= self.TOOL:FindFirstChild("SwitchSound") 
		
	-- Try grab tool Id for equipped/unequipped/Activated functions
	local toolAttribute = Tool:GetAttribute("Type") 
	if toolAttribute == nil then 
		warn("Tool has no attribute!")
		return
	end
		
	-- Ensure equipped/unequipped functions exist for this tool type
	if not Tools.Equipped[toolAttribute]  then
		warn("Tool does not have equipped for ".. toolAttribute)
	elseif not Tools.Unequipped[toolAttribute] then
		warn("Tool does not have equipped for".. toolAttribute)
	end
	
	-- Store references to the tool's equipped and unequipped functions	
	self.equippedFunction = Tools.Equipped[toolAttribute]
	self.unequippedFunction = Tools.Unequipped[toolAttribute]
	
	return self
end


-- Handler for switching tool on / off
-- Plays switch sound calls appropriate tool-specific switch function

-- @param self: the AMA tool object
-- @param BoolValue: true to turn on false to turn off
local function Switch(self, BoolValue: boolean)
	-- Play the switch sound if hte tool is being toggled on or is already enabled
	if self.Enabled or BoolValue then
		if self.SWITCHSOUND then
			self.SWITCHSOUND:Play()
		end
	end
	
	-- Call the corresponding switch function for this tool
	local ToolAttribute = self.TOOLATTRIBUTE
	if ToolAttribute then
		if SwitchFunctions[ToolAttribute] then
			SwitchFunctions[ToolAttribute](self, BoolValue)
		else
			warn("Switchfunctions does not have a switchfunction for this tool")
		end
	else
		warn("ToolAttribute does not exist")
	end

end

-- Enables the tool: starts arm animation and connects input events
-- Plays the equip sound if available, starts coroutine to replicate arm movement to server
-- and sets up event connections for tool activation and animation updates.
-- @param item: the tool object being enabled (optional)

function AMA:Enable(item) 
	Playing = true
	
	-- Close existing coroutine if it exists
	if self.Correlation and coroutine.status(self.Correlation) ~= "dead" then
		coroutine.close(self.Correlation)
	end
	
	-- Attempt to play Equipsound
	if self.EQUIPSOUND then
		self.EQUIPSOUND:Play()
	end
	
	self.Equipped = true
	
	-- Connect tool activation to switch tool on/off and store inside TempConnections
	self.TempConnections["Activated"] = self.TOOL.Activated:Connect(function()
		Switch(self, not self.Enabled)
	end)
	
	-- Coroutine to continuously replicate arm movement while equipped	
	self.Correlation = coroutine.create(function()
		while true do
			if not self.TOOL then
				warn("Possible memory leak prevention has passed!") -- dunno if this works we'll have to check on release on the error logs on site
				coroutine.close(self.Correlation)
			end
			
			-- Sends/Yields the current/previous CFrame of the right joint to the server
			if self.Equipped then
				if AMA.targetC0 ~= nil then
					self.RemoteEvent:FireServer(AMA.SENDOR, AMA.targetC0) -- TargetCFrame is set in RenderStepped
				end
			else
				self.RemoteEvent:FireServer(AMA.SENDOR, AMA.previousCFrame) -- previousCFrame is set prior to setup
				coroutine.yield()
			end
			task.wait(0.2) -- Executes this task every 200 ms
		end
	end)
	
	-- if Motor6D exists then setup Runservice connection and store inside TempConnections
	if AMA.rightjoint6d then
		self.TempConnections["RS"] = RunService.RenderStepped:Connect(function(DT)
			local y, x, z = self.CAMERA.CFrame:ToEulerAnglesYXZ()	-- Get the camera's rotation angles (yaw, pitch, roll)

			local pos = AMA.rightjoint6d.C0.Position				-- Clamp the pitch (Y-axis rotation) to prevent unnatural arm movement

			local clampedY = math.clamp(y, -1.5, 2)					-- Store the current position of the right arm joint

			local currentC0 = AMA.rightjoint6d.C0 					-- Keep a reference to the current CFrame of the right arm joint for interpolation


			-- Move the arm either back to its original position (previousCFrame) 
			-- or smoothly toward the target CFrame (targetC0) based on animation state
			if Playing then 
				AMA.targetC0 = CFrame.new(pos) * CFrame.Angles(clampedY, 0, 0)
				AMA.rightjoint6d.C0 = currentC0:Lerp(AMA.targetC0, self.TWEENSPEED * DT)
			else
				AMA.rightjoint6d.C0 = currentC0:Lerp(AMA.previousCFrame, self.TWEENSPEED * DT)
			end

		end)
	end
	
	-- Resume coroutine if suspended
	if coroutine.status(self.Correlation) == "suspended" then
		coroutine.resume(self.Correlation)
	end
	
	-- Store the temporary connections for later cleanup
	table.insert(self.StoredConnections, self.TempConnections)
	self.TempConnections = nil
end

-- Disables the tool on unequip: stops arm animation and disconnects input events
-- @param: TurnOffTool: boolean, wether to turn off the tool when disabling (Used in destroy)

function AMA:Disable(TurnOffTool)
	-- Stop arm movement animation
	Playing = false
	self.Equipped = false
	
	-- Close the coroutine that was replicating arm movement
	if self.Correlation and coroutine.status(self.Correlation) ~= "dead" then
		coroutine.close(self.Correlation)
		self.Correlation = nil
	end
	
	-- Disconnect all stored connections for this tool
	for _, Connections in ipairs(self.StoredConnections) do
		if Connections["RS"] then
			Connections["RS"]:Disconnect()
			Connections["RS"] = nil
			AMA.rightjoint6d.C0 = AMA.previousCFrame
		end
		
		-- Disconnect tool activation connection and optionally play equip sound
		if Connections["Activated"] then
			if self.EQUIPSOUND then				
				self.EQUIPSOUND:Play()
			end
			Connections["Activated"]:Disconnect()
			Connections["Activated"] = nil
			
			-- Turn off the tool if the tool is enabled and TurnOffTool is enabled
			if self.Enabled and TurnOffTool then
				Switch(self, false)
			end
			
		end
	end
	self.StoredConnections = {}
end

-- unregisters and cleans up the tool object
-- disables the tool closes coroutines and disconnects events and clears all references
-- to ensure proper garbage collection
-- @private
function AMA:_unregTool()
	-- Disable the tool respecting TurnOffOnDrop flag
	self:Disable(self.TurnOffOnDrop or false)

	-- Close any running coroutine
	if self.Correlation then
		coroutine.close(self.Correlation)
		self.Correlation = nil
	end

	-- Clear connection tables (disable emptied the tables)
	self.TempConnections = nil
	self.StoredConnections = nil
	
	-- Clear state flags
	self.Enabled = nil
	self.Equipped = nil

	-- Clear equipped/unequipped cunction references
	self.equippedFunction = nil
	self.unequippedFunction = nil

	-- Clear optional sound references
	self.EQUIPSOUND = nil
	self.SWITCHSOUND = nil

	-- Remove any Roblox instance references from the object
	for Key, Value in pairs(self) do
		if typeof(Value) == "Instance" then
			self[Key] = nil
		end
	end
end
return AMA