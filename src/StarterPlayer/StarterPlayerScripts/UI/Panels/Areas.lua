-- Painel Areas: progressão das áreas da pista (o ovo para no portão da área bloqueada).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Modules = ReplicatedStorage:WaitForChild("Modules")
local NumberFormat = require(Modules.NumberFormat)
local AreaConfig = require(Modules.AreaConfig)

return function(ctx)
	local UI = ctx.UI
	local T = UI.Theme
	local window, content = ctx.UIController:CreateWindow("Areas", "AREAS", "Areas", Color3.fromRGB(255, 120, 90), Vector2.new(720, 470))

	local scroll = UI.new("ScrollingFrame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ScrollBarThickness = 6,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = content,
	})
	UI.list(scroll, true, 10)

	local rows = {}
	for i, area in AreaConfig.Areas do
		local c = area.FloorColor
		local color = Color3.fromRGB(c[1], c[2], c[3])
		local row = UI.new("Frame", { Size = UDim2.new(1, -10, 0, 86), BackgroundColor3 = T.PanelLight, LayoutOrder = i, Parent = scroll })
		UI.corner(row, 14)
		local stroke = UI.stroke(row, T.Gray, 2.5)
		local swatch = UI.new("Frame", { Size = UDim2.fromOffset(62, 62), Position = UDim2.new(0, 12, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), BackgroundColor3 = color, Parent = row })
		UI.corner(swatch, 12)
		UI.stroke(swatch, T.Stroke, 2)
		UI.label({ Text = tostring(area.Id), Size = UDim2.fromScale(0.7, 0.7), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), Parent = swatch })
		UI.label({
			Text = "Area " .. area.Id .. " - " .. area.Name,
			Size = UDim2.new(0.6, 0, 0, 30),
			Position = UDim2.fromOffset(88, 10),
			TextXAlignment = Enum.TextXAlignment.Left,
			MaxTextSize = 26,
			Parent = row,
		})
		local info = UI.label({
			Text = "",
			Size = UDim2.new(0.62, 0, 0, 36),
			Position = UDim2.fromOffset(88, 42),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = T.SubText,
			TextWrapped = true,
			Font = T.BodyFont,
			NoStroke = true,
			MaxTextSize = 16,
			Parent = row,
		})
		local button = UI.button({
			Text = "",
			Color = T.Green,
			Size = UDim2.new(0.24, 0, 0, 52),
			Position = UDim2.new(1, -12, 0.5, 0),
			AnchorPoint = Vector2.new(1, 0.5),
			TextSize = 22,
			Parent = row,
			OnClick = function()
				local ok = ctx.UIController:Invoke("UnlockArea", area.Id)
				if ok then
					ctx.Controllers.SoundController:Play("Reveal")
				end
			end,
		})
		rows[i] = { Stroke = stroke, Info = info, Button = button }
	end

	local panel = { Window = window }
	function panel:Refresh(data)
		for i, area in AreaConfig.Areas do
			local row = rows[i]
			local range = NumberFormat.Distance(area.Start) .. " - " .. NumberFormat.Distance(area.End)
			if i <= data.HighestArea then
				row.Stroke.Color = T.Green
				row.Info.Text = "Unlocked  |  " .. range
				row.Button.Visible = false
			else
				local req = area.Requirements
				local parts = {}
				if req.BestDistance then
					table.insert(parts, "Best " .. NumberFormat.Distance(req.BestDistance))
				end
				if req.Rebirths then
					table.insert(parts, req.Rebirths .. " Rebirths")
				end
				if req.Strength then
					table.insert(parts, NumberFormat.Abbreviate(req.Strength) .. " Strength")
				end
				row.Info.Text = "Needs: " .. table.concat(parts, ", ") .. "  |  " .. range
				row.Button.Visible = true
				local isNext = i == data.HighestArea + 1
				row.Stroke.Color = if isNext then T.Gold else T.Gray
				UI.setButtonText(row.Button, if isNext then NumberFormat.Abbreviate(req.Coins or 0) .. " Coins" else "LOCKED")
				local ready = isNext
					and data.Coins >= (req.Coins or 0)
					and data.BestDistance >= (req.BestDistance or 0)
					and data.Rebirths >= (req.Rebirths or 0)
					and data.Strength >= (req.Strength or 0)
				UI.setButtonColor(row.Button, if ready then T.Green else T.Gray)
			end
		end
	end
	return panel
end
