--!strict

--  _   _ ___ _   _ _       _     _ _       _     _
-- | | | |_ _| | | (_) __ _| |__ | (_) __ _| |__ | |_ ___ _ __
-- | | | || || |_| | |/ _` | '_ \| | |/ _` | '_ \| __/ _ \ '__|
-- | |_| || ||  _  | | (_| | | | | | | (_| | | | | ||  __/ |
--  \___/|___|_| |_|_|\__, |_| |_|_|_|\__, |_| |_|\__\___|_|
--                    |___/           |___/

-- made with ❤️ by biotoxin495

-- UIHighlighter
-- A lightweight client-side utility for highlighting GuiObjects with animated arrows.

-- Example:
-- 	local UIHighlighter = require(ReplicatedStorage.UIHighlighter)

-- 	local highlight = UIHighlighter.Highlight(button, {
-- 		ArrowSize = 48,
-- 		Padding = 12,
-- 		Animation = {
-- 			ColorA = Color3.fromRGB(255, 83, 83),
-- 			ColorB = Color3.fromRGB(255, 215, 0),
-- 		},
-- 	})

-- 	highlight:Destroy()

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local GuiService = game:GetService("GuiService")

export type AnimationConfig = {
	Enabled: boolean?,
	PulseSpeed: number?,
	PulseDistance: number?,
	RotationWiggle: number?,
	ColorA: Color3?,
	ColorB: Color3?,
}

export type HighlightConfig = {
	ArrowImageId: string?,
	ArrowSize: number?,
	ScaleMultiplier: number?,
	Padding: number?,
	ZIndex: number?,
	Animation: AnimationConfig?,
}

export type Highlight = {
	Target: GuiObject,
	Container: Frame,
	Arrows: { [string]: ImageLabel },
	Enabled: boolean,

	Destroy: (self: Highlight) -> (),
	SetEnabled: (self: Highlight, enabled: boolean) -> (),
	IsDestroyed: (self: Highlight) -> boolean,
}

type ResolvedAnimationConfig = {
	Enabled: boolean,
	PulseSpeed: number,
	PulseDistance: number,
	RotationWiggle: number,
	ColorA: Color3,
	ColorB: Color3,
}

type ResolvedHighlightConfig = {
	ArrowImageId: string,
	ArrowSize: number,
	ScaleMultiplier: number,
	Padding: number,
	ZIndex: number,
	Animation: ResolvedAnimationConfig,
}

type InternalHighlight = Highlight & {
	_config: ResolvedHighlightConfig,
	_destroyed: boolean,
	_baseRotations: { [string]: number },
}

local DEFAULT_CONFIG: ResolvedHighlightConfig = {
	ArrowImageId = "rbxassetid://119492233291268",
	ArrowSize = 64,
	ScaleMultiplier = 1.25,
	Padding = 0,
	ZIndex = 100,
	Animation = {
		Enabled = true,
		PulseSpeed = 3,
		PulseDistance = 25,
		RotationWiggle = 5,
		ColorA = Color3.fromRGB(255, 83, 83),
		ColorB = Color3.fromRGB(255, 215, 0),
	},
}

local ARROW_CONFIG = {
	TopLeft = {
		Rotation = -135,
		Position = UDim2.fromScale(0, 0),
		PulseDirection = Vector2.new(-1, -1).Unit,
	},
	TopRight = {
		Rotation = -45,
		Position = UDim2.fromScale(1, 0),
		PulseDirection = Vector2.new(1, -1).Unit,
	},
	BottomRight = {
		Rotation = 45,
		Position = UDim2.fromScale(1, 1),
		PulseDirection = Vector2.new(1, 1).Unit,
	},
	BottomLeft = {
		Rotation = 135,
		Position = UDim2.fromScale(0, 1),
		PulseDirection = Vector2.new(-1, 1).Unit,
	},
}

local UIHighlighter = {}
local HighlightMethods = {}
HighlightMethods.__index = HighlightMethods

local overlayGui: ScreenGui? = nil
local renderConnection: RBXScriptConnection? = nil
local activeHighlights: { InternalHighlight } = {}
local highlightsByTarget: { [GuiObject]: InternalHighlight } = {}

local function resolveConfig(config: HighlightConfig?): ResolvedHighlightConfig
	local animation = if config then config.Animation else nil

	return {
		ArrowImageId = if config and config.ArrowImageId ~= nil
			then config.ArrowImageId
			else DEFAULT_CONFIG.ArrowImageId,
		ArrowSize = if config and config.ArrowSize ~= nil
			then math.max(config.ArrowSize, 0)
			else DEFAULT_CONFIG.ArrowSize,
		ScaleMultiplier = if config and config.ScaleMultiplier ~= nil
			then math.max(config.ScaleMultiplier, 0)
			else DEFAULT_CONFIG.ScaleMultiplier,
		Padding = if config and config.Padding ~= nil then math.max(config.Padding, 0) else DEFAULT_CONFIG.Padding,
		ZIndex = if config and config.ZIndex ~= nil then config.ZIndex else DEFAULT_CONFIG.ZIndex,
		Animation = {
			Enabled = if animation and animation.Enabled ~= nil
				then animation.Enabled
				else DEFAULT_CONFIG.Animation.Enabled,
			PulseSpeed = if animation and animation.PulseSpeed ~= nil
				then animation.PulseSpeed
				else DEFAULT_CONFIG.Animation.PulseSpeed,
			PulseDistance = if animation and animation.PulseDistance ~= nil
				then animation.PulseDistance
				else DEFAULT_CONFIG.Animation.PulseDistance,
			RotationWiggle = if animation and animation.RotationWiggle ~= nil
				then animation.RotationWiggle
				else DEFAULT_CONFIG.Animation.RotationWiggle,
			ColorA = if animation and animation.ColorA ~= nil
				then animation.ColorA
				else DEFAULT_CONFIG.Animation.ColorA,
			ColorB = if animation and animation.ColorB ~= nil
				then animation.ColorB
				else DEFAULT_CONFIG.Animation.ColorB,
		},
	}
end

local function getOverlayGui(): ScreenGui
	if overlayGui and overlayGui.Parent then
		return overlayGui
	end

	assert(RunService:IsClient(), "[UIHighlighter] UIHighlighter can only be used on the client")

	local player = Players.LocalPlayer
	assert(player, "[UIHighlighter] LocalPlayer is unavailable")

	local playerGui = player:WaitForChild("PlayerGui") :: PlayerGui

	local existing = playerGui:FindFirstChild("UIHighlightOverlay")
	if existing and existing:IsA("ScreenGui") then
		overlayGui = existing
		return existing
	end

	local gui = Instance.new("ScreenGui")
	gui.Name = "UIHighlightOverlay"
	gui.DisplayOrder = 999
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = playerGui

	overlayGui = gui
	return gui
end

local function getTargetScreenOffset(target: GuiObject): Vector2
	local screenGui = target:FindFirstAncestorWhichIsA("ScreenGui")
	if screenGui and not screenGui.IgnoreGuiInset then
		local topLeftInset = GuiService:GetGuiInset()
		return topLeftInset
	end

	return Vector2.zero
end

local function isActuallyVisible(target: GuiObject): boolean
	if not target.Visible then
		return false
	end

	local ancestor = target.Parent
	while ancestor do
		if ancestor:IsA("GuiObject") and not ancestor.Visible then
			return false
		end
		ancestor = ancestor.Parent
	end

	return true
end

local function removeFromActiveList(highlight: InternalHighlight)
	for index, activeHighlight in ipairs(activeHighlights) do
		if activeHighlight == highlight then
			table.remove(activeHighlights, index)
			break
		end
	end
end

local function stopRenderLoopIfUnused()
	if #activeHighlights == 0 and renderConnection then
		renderConnection:Disconnect()
		renderConnection = nil
	end
end

local function destroyHighlight(highlight: InternalHighlight)
	if highlight._destroyed then
		return
	end

	highlight._destroyed = true

	if highlightsByTarget[highlight.Target] == highlight then
		highlightsByTarget[highlight.Target] = nil
	end

	removeFromActiveList(highlight)

	if highlight.Container.Parent then
		highlight.Container:Destroy()
	end

	stopRenderLoopIfUnused()
end

local function updateHighlight(highlight: InternalHighlight, currentTime: number)
	local target = highlight.Target
	local container = highlight.Container
	local config = highlight._config
	local animation = config.Animation

	if not target:IsDescendantOf(game) then
		destroyHighlight(highlight)
		return
	end

	local absoluteSize = target.AbsoluteSize
	local shouldShow = highlight.Enabled and isActuallyVisible(target) and absoluteSize.X > 0 and absoluteSize.Y > 0

	container.Visible = shouldShow
	if not shouldShow then
		return
	end

	local absolutePosition = target.AbsolutePosition
	local screenOffset = getTargetScreenOffset(target)
	local center = absolutePosition + (absoluteSize / 2) + screenOffset

	container.Position = UDim2.fromOffset(center.X, center.Y)
	container.Size = UDim2.fromOffset(
		absoluteSize.X * config.ScaleMultiplier + config.Padding * 2,
		absoluteSize.Y * config.ScaleMultiplier + config.Padding * 2
	)

	local alpha = 0
	local rotationOffset = 0
	local currentColor = animation.ColorA

	if animation.Enabled then
		local wave = math.sin(currentTime * animation.PulseSpeed)
		alpha = (wave + 1) / 2
		rotationOffset = wave * animation.RotationWiggle
		currentColor = animation.ColorA:Lerp(animation.ColorB, alpha)
	end

	for cornerName, arrow in pairs(highlight.Arrows) do
		local arrowConfig = ARROW_CONFIG[cornerName]
		local pulseOffset = arrowConfig.PulseDirection * (alpha * animation.PulseDistance)

		arrow.Position =
			UDim2.new(arrowConfig.Position.X.Scale, pulseOffset.X, arrowConfig.Position.Y.Scale, pulseOffset.Y)
		arrow.Rotation = highlight._baseRotations[cornerName] + rotationOffset
		arrow.ImageColor3 = currentColor
	end
end

local function startRenderLoop()
	if renderConnection then
		return
	end

	renderConnection = RunService.RenderStepped:Connect(function()
		local currentTime = os.clock()

		for index = #activeHighlights, 1, -1 do
			local highlight = activeHighlights[index]
			if not highlight._destroyed then
				updateHighlight(highlight, currentTime)
			end
		end
	end)
end

local function createHighlight(target: GuiObject, config: ResolvedHighlightConfig): InternalHighlight
	local container = Instance.new("Frame")
	container.Name = "UIHighlighter"
	container.BackgroundTransparency = 1
	container.AnchorPoint = Vector2.new(0.5, 0.5)
	container.ZIndex = config.ZIndex
	container.Parent = getOverlayGui()

	local arrows: { [string]: ImageLabel } = {}
	local baseRotations: { [string]: number } = {}

	for cornerName, arrowConfig in pairs(ARROW_CONFIG) do
		local arrow = Instance.new("ImageLabel")
		arrow.Name = cornerName
		arrow.BackgroundTransparency = 1
		arrow.AnchorPoint = Vector2.new(0.5, 0.5)
		arrow.Image = config.ArrowImageId
		arrow.ImageColor3 = config.Animation.ColorA
		arrow.Position = arrowConfig.Position
		arrow.Rotation = arrowConfig.Rotation
		arrow.Size = UDim2.fromOffset(config.ArrowSize, config.ArrowSize)
		arrow.ZIndex = config.ZIndex + 1
		arrow.Parent = container

		arrows[cornerName] = arrow
		baseRotations[cornerName] = arrowConfig.Rotation
	end

	local highlight = setmetatable({
		Target = target,
		Container = container,
		Arrows = arrows,
		Enabled = true,
		_config = config,
		_destroyed = false,
		_baseRotations = baseRotations,
	}, HighlightMethods) :: any

	return highlight
end

function HighlightMethods:Destroy()
	destroyHighlight(self :: any)
end

function HighlightMethods:SetEnabled(enabled: boolean)
	if self._destroyed then
		return
	end

	self.Enabled = enabled
	self.Container.Visible = enabled
end

function HighlightMethods:IsDestroyed(): boolean
	return self._destroyed
end

-- Creates a highlight, replacing any existing highlight on the same target.
function UIHighlighter.Highlight(target: GuiObject, config: HighlightConfig?): Highlight
	assert(typeof(target) == "Instance" and target:IsA("GuiObject"), "[UIHighlighter] target must be a GuiObject")

	local existing = highlightsByTarget[target]
	if existing then
		destroyHighlight(existing)
	end

	local highlight = createHighlight(target, resolveConfig(config))
	highlightsByTarget[target] = highlight
	table.insert(activeHighlights, highlight)

	startRenderLoop()
	updateHighlight(highlight, os.clock())

	return highlight
end

-- Removes the highlight attached to a target.
function UIHighlighter.Remove(target: GuiObject)
	local highlight = highlightsByTarget[target]
	if highlight then
		destroyHighlight(highlight)
	end
end

-- Removes every active highlight.
function UIHighlighter.RemoveAll()
	while #activeHighlights > 0 do
		destroyHighlight(activeHighlights[#activeHighlights])
	end
end

-- Returns whether a target currently has a live highlight.
function UIHighlighter.HasHighlight(target: GuiObject): boolean
	local highlight = highlightsByTarget[target]
	return highlight ~= nil and not highlight._destroyed
end

-- Returns the highlight attached to a target, if one exists.
function UIHighlighter.GetHighlight(target: GuiObject): Highlight?
	local highlight = highlightsByTarget[target]
	if highlight and not highlight._destroyed then
		return highlight
	end

	return nil
end

-- Completely tears down the module-created overlay and all highlights.
function UIHighlighter.Destroy()
	UIHighlighter.RemoveAll()

	if overlayGui then
		overlayGui:Destroy()
		overlayGui = nil
	end
end

return table.freeze(UIHighlighter)
