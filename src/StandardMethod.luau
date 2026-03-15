--!strict
type ReferenceTable = {{Instance: Instance, ReferenceName: string}}

local floor = math.floor

local HttpService = game:GetService("HttpService")
local ReflectionService = game:GetService("ReflectionService")

local SerializeDataType

function GetReferenceName(instance: Instance, references: ReferenceTable?): string?
	if instance == game then
		return "game"
	end
	
	if instance == workspace then
		return "workspace"
	end
	
	local className = instance.ClassName
	local success, result = pcall(game.GetService, game, className)

	if success and result then
		return `game:GetService({SerializeDataType(className)})`
	end
	
	if references then
		for _, referenceData in pairs(references) do
			if referenceData.Instance == instance then
				return referenceData.ReferenceName
			end
		end
	end
	
	return nil
end

function SerializeDataType(value: any, references: ReferenceTable?): string
	local valueType = typeof(value)
	
	if
		valueType == "nil" or
		valueType == "boolean" or
		valueType == "number"
	then
		return tostring(value)
	elseif valueType == "string" then
		return HttpService:JSONEncode(value)
	elseif valueType == "EnumItem" then
		return `Enum.{value.EnumType}.{value.Name}`
	elseif valueType == "Instance" then
		return GetReferenceName(value, references) or SerializeDataType(nil)
	elseif
		valueType == "Axes" or
		valueType == "Faces"
	then
		local arguments: {string} = {}

		for _, normalId in ipairs(Enum.NormalId:GetEnumItems()) do
			if value[normalId.Name] then
				table.insert(arguments, SerializeDataType(normalId))
			end
		end

		return `{valueType}.new({table.concat(arguments, ", ")})`
	elseif valueType == "BrickColor" then
		return `BrickColor.new({SerializeDataType(value.Name)})`
	elseif valueType == "CFrame" then
		return `CFrame.new({table.concat({value:GetComponents()}, ", ")})`
	elseif valueType == "Color3" then
		return `Color3.fromRGB({table.concat({
			SerializeDataType(floor(value.R * 255)),
			SerializeDataType(floor(value.G * 255)),
			SerializeDataType(floor(value.B * 255))
		}, ", ")})`
	elseif valueType == "ColorSequenceKeyPoint" then
		return `ColorSequenceKeypoint.new({table.concat({
			SerializeDataType(value.Time),
			SerializeDataType(value.Value)
		}, ", ")})`
	elseif valueType == "NumberSequenceKeypoint" then
		return `NumberSequenceKeypoint.new({table.concat({
			SerializeDataType(value.Time),
			SerializeDataType(value.Value),
			SerializeDataType(value.Envelope)
		}, ", ")})`
	elseif
		valueType == "ColorSequence" or
		valueType == "NumberSequence"
	then
		local arguments = table.clone(value.Keypoints)

		for index, keypoint in ipairs(arguments) do
			arguments[index] = SerializeDataType(keypoint)
		end

		return `{valueType}.new({table.concat(arguments, ", ")})`
	elseif valueType == "Content" then
		local sourceType = value.SourceType
		if sourceType == Enum.ContentSourceType.Uri then
			return `Content.fromUri({SerializeDataType(value.Uri)})`
		elseif sourceType == Enum.ContentSourceType.None then
			return `Content.none`
		else
			error(`Unsupported source type for "Content": {sourceType.Name}`)
		end
	elseif valueType == "Font" then
		return `Font.new({table.concat({
			SerializeDataType(value.Family),
			SerializeDataType(value.Weight),
			SerializeDataType(value.Style)
		}, ", ")})`
	elseif valueType == "NumberRange" then
		return `NumberRange.new({SerializeDataType(value.Min)}, {SerializeDataType(value.Max)})`
	elseif valueType == "PhysicalProperties" then
		return `PhysicalProperties.new({table.concat({
			SerializeDataType(value.Density),
			SerializeDataType(value.Friction),
			SerializeDataType(value.Elasticity),
			SerializeDataType(value.FrictionWeight),
			SerializeDataType(value.ElasticityWeight),
			SerializeDataType(value.AcousticAbsorption)
		}, ", ")})`
	elseif valueType == "Vector2" then
		return `Vector2.new({table.concat({
			SerializeDataType(value.X),
			SerializeDataType(value.Y)
		}, ", ")})`
	elseif valueType == "Vector3" then
		return `Vector3.new({table.concat({
			SerializeDataType(value.X),
			SerializeDataType(value.Y),
			SerializeDataType(value.Z)
		}, ", ")})`
	elseif valueType == "Ray" then
		return `Ray.new({table.concat({
			SerializeDataType(value.Origin),
			SerializeDataType(value.Direction)
		}, ", ")})`
	elseif valueType == "Rect" then
		return `Rect.new({table.concat({
			SerializeDataType(value.Min),
			SerializeDataType(value.Min)
		}, ", ")})`
	elseif valueType == "SecurityCapabilities" then
		local arguments: {string} = {}

		for _, capability in pairs(Enum.SecurityCapability:GetEnumItems()) do
			if value:Contains(capability) then
				table.insert(arguments, SerializeDataType(capability))
			end
		end

		return `SecurityCapabilities.new({table.concat(arguments, ", ")})`
	elseif valueType == "UDim" then
		return `UDim.new({table.concat({
			SerializeDataType(value.Scale),
			SerializeDataType(value.Offset)
		}, ", ")})`
	elseif valueType == "UDim2" then
		return `UDim2.new({table.concat({
			SerializeDataType(value.X.Scale),
			SerializeDataType(value.X.Offset),
			SerializeDataType(value.Y.Scale),
			SerializeDataType(value.Y.Offset)
		}, ", ")})`
	else
		error(`Unsupported data type: {valueType}`)
	end
end

local Formats = {
	Initialization = "local %s = Instance.new(%s)",
	Property = "%s.%s = %s",
	SpecialProperty = "%s[%s] = %s",
	Attribute = "%s:SetAttribute(%s, %s)",
	Tag = "%s:AddTag(%s)"
}

-- Some properties serve the same purpose
type ListPropertyNames = {[string]: {string}}

local IgnoredPropertyNames: ListPropertyNames = {
	BasePart = {"Position", "Rotation", "Orientation", "BrickColor"},
	GuiObject = {"BackgroundColor", "BorderColor", "TextColor", "Transparency", "Font"}
}

-- Some properties does not included in ReflectionService
local ForcedPropertyNames: ListPropertyNames = {
	LuaSourceContainer = {"Source"}
}

function NormalizeName(inputName: string): string
	inputName = inputName:gsub("[^%w_]", "_")

	if inputName:match("^%d") then
		inputName = "_" .. inputName
	end

	return inputName
end

function LogWarning(...: string)
	warn("[Fishy Serializer]:", ...)
end

function GetReferenceInstance(name: string, references: ReferenceTable?): Instance?
	if references then
		for _, referenceData in pairs(references) do
			if referenceData.ReferenceName == name then
				return referenceData.Instance
			end
		end
	end

	return nil
end

function SerializeInstance(rootInstance: Instance): string
	local references: ReferenceTable = {}
	local initializationSegments: {string} = {}

	local function createReference(instance: Instance)
		if not GetReferenceName(instance) then
			local normalizedName = NormalizeName(instance.Name)
			local referenceName = normalizedName

			if GetReferenceInstance(referenceName, references) then
				local index = 2

				while GetReferenceInstance(`{normalizedName}_{index}`, references) do
					index += 1
				end

				referenceName = `{normalizedName}_{index}`
			end

			table.insert(references, {Instance = instance, ReferenceName = referenceName})
			table.insert(initializationSegments, Formats.Initialization:format(referenceName, SerializeDataType(instance.ClassName)))
		end
		
		for _, child in pairs(instance:GetChildren()) do
			createReference(child)
		end
	end

	createReference(rootInstance)
	
	local propertiesSegments: {string} = {}
	
	for _, referenceData in ipairs(references) do
		local instance = referenceData.Instance
		local referenceName = referenceData.ReferenceName
		
		local excludedPropertyNames: {string} = {}
		
		for className, propertyNames in pairs(IgnoredPropertyNames) do
			if instance:IsA(className) then
				for _, propertyName in pairs(propertyNames) do
					table.insert(excludedPropertyNames, propertyName)
				end
			end
		end
		
		local classPropertyNames: {string} = {}
		
		local classPropertiesData = ReflectionService:GetPropertiesOfClass(instance.ClassName)
		if classPropertiesData then
			for _, propertyData in ipairs(classPropertiesData) do
				local propertyName = propertyData.Name
				local propertyDisplay = propertyData.Display or {} :: any
				
				if
					not table.find(classPropertyNames, propertyName) and
					not propertyDisplay.DeprecationMessage and
					not table.find(excludedPropertyNames, propertyName)
				then
					table.insert(classPropertyNames, propertyName)
				end
			end
		else
			LogWarning(`Missing properties data for class {instance.ClassName}, skipped`)
		end
		
		for className, forcedPropertyNames in pairs(ForcedPropertyNames) do
			if instance:IsA(className) then
				for _, forcedPropertyName in pairs(forcedPropertyNames) do
					table.insert(classPropertyNames, forcedPropertyName)
				end
			end
		end
		
		--[[if instance == rootInstance then
			local parentPropertyNameIndex = table.find(classPropertyNames, "Parent")

			if parentPropertyNameIndex then
				table.remove(classPropertyNames, parentPropertyNameIndex)
			end
		end]]
		
		local propertySegments: {string} = {}

		for _, propertyName in ipairs(classPropertyNames) do
			local success, result = pcall(instance.IsPropertyModified, instance, propertyName)

			if success and result then
				local serializedValue = SerializeDataType((instance :: any)[propertyName], references)
				table.insert(propertySegments, if propertyName == NormalizeName(propertyName) then Formats.Property:format(referenceName, propertyName, serializedValue) else Formats.SpecialProperty:format(referenceName, SerializeDataType(propertyName), serializedValue))
			end
		end

		if #propertySegments > 0 then
			table.insert(propertiesSegments, table.concat(propertySegments, "\n"))
		end
	end
	
	local attributeSegments: {string} = {}
	
	for _, referenceData in ipairs(references) do
		local referenceName = referenceData.ReferenceName
		
		for attributeName, attributeValue in pairs(referenceData.Instance:GetAttributes()) do
			table.insert(attributeSegments, Formats.Attribute:format(referenceName, SerializeDataType(attributeName), SerializeDataType(attributeValue, references)))
		end
	end
	
	local tagSegments: {string} = {}
	
	for _, referenceData in ipairs(references) do
		local referenceName = referenceData.ReferenceName
		
		for _, tagName in pairs(referenceData.Instance:GetTags()) do
			table.insert(tagSegments, Formats.Tag:format(referenceName, SerializeDataType(tagName)))
		end
	end
	
	local finalSegments: {string} = {}
	
	if #initializationSegments > 0 then
		table.insert(finalSegments, table.concat(initializationSegments, "\n"))
	end
	
	if #propertiesSegments > 0 then
		table.insert(finalSegments, table.concat(propertiesSegments, "\n\n"))
	end
	
	if #attributeSegments > 0 then
		table.insert(finalSegments, table.concat(attributeSegments, "\n"))
	end
	
	if #tagSegments > 0 then
		table.insert(finalSegments, table.concat(tagSegments, "\n"))
	end
	
	return if #finalSegments > 0 then table.concat(finalSegments, "\n\n")..`\n\nreturn {GetReferenceName(rootInstance, references)}` else ""
end

local SelectionService = game:GetService("Selection")
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
				local outputScript = Instance.new("ModuleScript")
				outputScript.Source = SerializeInstance(instance)
				outputScript.Name = `Serialized: {instance.Name}`
				outputScript.Parent = if GetReferenceName(instance) then instance else instance.Parent
			end
		end)

		ChangeHistoryService:FinishRecording(changeHistoryRecordIdentifier, Enum.FinishRecordingOperation[if success then "Append" else "Cancel"])
		SerializeButton.Enabled = true

		if not success then
			LogWarning(result)
		end
	end
end)
