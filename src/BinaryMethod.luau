--!strict
local SelectionService = game:GetService("Selection")
local SerializationService = game:GetService("SerializationService")
local ChangeHistoryService = game:GetService("ChangeHistoryService")

local SerializeButton = plugin:CreateToolbar("Fishy Serializer"):CreateButton(
	"SerializeButton",
	"Select target instances in the explorer and click this button to convert them into module scripts",
	"rbxasset://studio_svg_textures/Lua/ActivityHistory/Light/Large/Script@3x.png",
	"Serialize"
)

SerializeButton.ClickableWhenViewportHidden = true
SerializeButton.Click:Connect(function()
	local changeHistoryRecordIdentifier = ChangeHistoryService:TryBeginRecording("FishySerialization", "Fishy Serialization")
	if changeHistoryRecordIdentifier then
		SerializeButton.Enabled = false
		
		local success, result = (pcall :: any)(function()
			local selectedInstances = SelectionService:Get()
			for _, instance in pairs(selectedInstances) do
				local serializedBuffer = SerializationService:SerializeInstancesAsync({instance})
				local outputScript = Instance.new("ModuleScript")

				outputScript.Source = `return game:GetService("SerializationService"):DeserializeInstancesAsync(buffer.fromstring("`

				for index = 0, buffer.len(serializedBuffer) - 1, 1 do
					outputScript.Source ..= string.format("\\x%02x", buffer.readu8(serializedBuffer, index))
				end

				outputScript.Source ..= `"))[1]`
				outputScript.Name = `Serialized: {instance.Name}`
				outputScript.Parent = instance.Parent
			end
		end)
		
		ChangeHistoryService:FinishRecording(changeHistoryRecordIdentifier, Enum.FinishRecordingOperation[if success then "Append" else "Cancel"])
		SerializeButton.Enabled = true
		
		if not success then
			warn("Fishy Serializer:", result)
		end
	end
end)
