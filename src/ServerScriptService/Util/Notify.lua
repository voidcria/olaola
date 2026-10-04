-- Envia uma notificação curta para o cliente (toast).
-- kind: "Info" | "Success" | "Error" | "Reward"
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Remotes = require(ReplicatedStorage:WaitForChild("Modules").Remotes)

local notifyEvent = Remotes.Event("Notify")

return function(player: Player, text: string, kind: string?)
	notifyEvent:FireClient(player, text, kind or "Info")
end
