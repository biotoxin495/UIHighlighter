# UIHighlighter — An animated arrow highlighter for Roblox UI

**UIHighlighter**, a lightweight, standalone utility for drawing the player's attention to a piece of Roblox UI.

UIHighlighter lets you register any `GuiObject`—such as a button, frame, or icon—and surround it with four pulsing corner arrows, useful for tutorials, quest markers, "new feature" callouts, and any other UI element that needs to stand out.

The module handles overlay creation, per-frame positioning, pulse and color animation, and cleanup internally, while keeping the public API small and simple.

## Quick example

UIHighlighter attaches to any `GuiObject` through `Highlight`.

```lua
local UIHighlighter = require(ReplicatedStorage.UIHighlighter)

local highlight = UIHighlighter.Highlight(script.Parent.PlayButton)
```

Four animated arrows immediately appear around the corners of `PlayButton`, pulsing outward and cycling color. Calling `highlight:Destroy()` removes them.

## 🚀 Features

### Corner arrow highlighting

Register a highlight on any `GuiObject` and UIHighlighter surrounds it with four arrows, one per corner.

```lua
UIHighlighter.Highlight(script.Parent.PlayButton)
```

Arrows are repositioned and resized every frame to track the target's `AbsolutePosition` and `AbsoluteSize`, so the highlight follows the target through layout changes, tweens, and screen resizes.

### Pulsing color animation

Arrows pulse outward from the target and smoothly lerp between two colors, with an optional rotation wiggle.

```lua
UIHighlighter.Highlight(script.Parent.PlayButton, {
	Animation = {
		PulseSpeed = 4,
		PulseDistance = 18,
		ColorA = Color3.fromRGB(80, 200, 255),
		ColorB = Color3.fromRGB(255, 255, 255),
	},
})
```

Setting `Animation.Enabled` to `false` freezes the arrows in place using `ColorA`.

### Automatic visibility tracking

The highlight checks the target's `Visible` property—and that of every ancestor—every frame, and hides itself whenever the target is not actually on screen or has zero size, reappearing automatically once it is visible again.

### Single highlight per target

Calling `Highlight` again on a target that already has one replaces the previous highlight instead of stacking a second set of arrows on top of it.

### Efficient by design

All active highlights share a single `RenderStepped` connection instead of running one loop per highlight. The loop starts automatically when the first highlight is created and stops automatically once none remain.

### Fully typed, no dependencies

The module ships with a fully typed Luau API and has no external dependencies or framework requirements.

## 📖 Basic usage

Place the `UIHighlighter` ModuleScript somewhere accessible to your client scripts, such as `ReplicatedStorage`. UIHighlighter must be required and used from a `LocalScript`.

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UIHighlighter = require(ReplicatedStorage.UIHighlighter)

local highlight = UIHighlighter.Highlight(script.Parent.PlayButton)
```

### Example: tutorial arrow pointing at a button

```lua
local highlight = UIHighlighter.Highlight(script.Parent.ShopButton, {
	ArrowSize = 48,
	Padding = 8,
})

shopButton.Activated:Connect(function()
	highlight:Destroy()
end)
```

### Example: temporarily disabling a highlight

```lua
local highlight = UIHighlighter.Highlight(script.Parent.QuestButton)

-- Hide the arrows without losing the registration
highlight:SetEnabled(false)

-- Show them again later
highlight:SetEnabled(true)
```

### Example: custom colors, arrow image, and animation speed

```lua
UIHighlighter.Highlight(script.Parent.RewardIcon, {
	ArrowImageId = "rbxassetid://0000000000",
	ArrowSize = 40,
	ScaleMultiplier = 1.4,
	ZIndex = 250,
	Animation = {
		PulseSpeed = 5,
		PulseDistance = 15,
		RotationWiggle = 8,
		ColorA = Color3.fromRGB(255, 215, 0),
		ColorB = Color3.fromRGB(255, 255, 255),
	},
})
```

## ⚙️ API

### `UIHighlighter.Highlight(target, config?)`

Creates a highlight around a `GuiObject` and returns its controller. Replaces any existing highlight already registered on the same target.

```lua
local highlight = UIHighlighter.Highlight(Button, config)
```

### `UIHighlighter.Remove(target)`

Removes the highlight attached to a target, if one exists.

```lua
UIHighlighter.Remove(Button)
```

### `UIHighlighter.RemoveAll()`

Removes every currently active highlight.

```lua
UIHighlighter.RemoveAll()
```

### `UIHighlighter.HasHighlight(target)`

Returns whether a target currently has a live highlight.

```lua
local hasHighlight = UIHighlighter.HasHighlight(Button)
```

### `UIHighlighter.GetHighlight(target)`

Returns the highlight controller attached to a target, or `nil` if none exists.

```lua
local highlight = UIHighlighter.GetHighlight(Button)
```

### `UIHighlighter.Destroy()`

Completely tears down the module: removes every active highlight and destroys the generated overlay `ScreenGui`.

```lua
UIHighlighter.Destroy()
```

### `highlight:SetEnabled(enabled)`

Shows or hides this highlight's arrows without unregistering it.

```lua
highlight:SetEnabled(false)
```

### `highlight:IsDestroyed()`

Returns whether this highlight has already been destroyed.

```lua
local destroyed = highlight:IsDestroyed()
```

### `highlight:Destroy()`

Removes this highlight's arrows and unregisters it from its target.

```lua
highlight:Destroy()
```

A highlight is also destroyed automatically once its target leaves the game tree.

## Complete options reference

You normally only need to provide the options you want to change. Any omitted options use the module defaults.

```lua
{
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
```

| Option | Type | Description |
| --- | --- | --- |
| `ArrowImageId` | `string` | Asset ID used for each corner arrow |
| `ArrowSize` | `number` | Side length of each arrow, in pixels |
| `ScaleMultiplier` | `number` | Scales the highlight box relative to the target's size |
| `Padding` | `number` | Additional pixels added around the target before scaling |
| `ZIndex` | `number` | ZIndex of the highlight container; arrows render one above it |
| `Animation.Enabled` | `boolean` | Enables the pulse, wiggle, and color animation |
| `Animation.PulseSpeed` | `number` | Speed of the pulsing sine wave |
| `Animation.PulseDistance` | `number` | Maximum distance arrows travel outward while pulsing |
| `Animation.RotationWiggle` | `number` | Maximum rotation offset applied while pulsing, in degrees |
| `Animation.ColorA` | `Color3` | First color in the pulse's color cycle |
| `Animation.ColorB` | `Color3` | Second color in the pulse's color cycle |

## Behavior

Only one highlight is active per target at a time; registering a new one on the same target replaces the old one.

Each frame, the highlight recomputes its target's `AbsolutePosition` and `AbsoluteSize`, accounting for the topbar inset when the target's `ScreenGui` does not ignore it, then repositions all four arrows and updates their pulse offset, rotation, and color.

If the target becomes invisible, shrinks to zero size, or is destroyed, the highlight hides or removes itself automatically without any extra bookkeeping on your part.

## 📝 Notes

* UIHighlighter is intended for client-side UI and must be required from a `LocalScript`.
* All highlights render inside a single shared overlay `ScreenGui` created under `PlayerGui`, above the rest of your interface.
* The module creates arrow-based corner highlights and does not currently support arbitrary custom highlight shapes or full-border outlines.
* Call `UIHighlighter.Destroy()` when you no longer need any highlights to clean up the generated overlay and stop the render loop.

## 🛠️ Installation

### Manual installation

Place the `UIHighlighter` ModuleScript somewhere accessible to your client scripts.

Recommended structure:

```text
ReplicatedStorage
└── UIHighlighter
```

Then require it with:

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UIHighlighter = require(ReplicatedStorage.UIHighlighter)
```

## License

This project is released under the MIT License. See `LICENSE` for details.

made with ❤️ by biotoxin495
