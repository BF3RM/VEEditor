local m_ReservedLuaKeywords = {
	"and", "break", "do", "else", "elseif",
	"end", "false", "for", "function", "goto", "if",
	"in", "local", "nil", "not", "or",
	"repeat", "return", "then", "true", "until",
	"while"
}

local function _FormatMemberName(p_Name)
	local s_MemberName = ""

	if p_Name:len() == 1 then
		s_MemberName = string.lower(p_Name)
		return s_MemberName
	end

	-- first character has to be lowercased
	s_MemberName = string.lower(p_Name:sub(1, 1))

	for i = 2, p_Name:len() do
		-- this letter is uppercase
		if string.match(p_Name:sub(i, i), "%u") then
			-- the next letter is uppercase as well or this is the first char
			if string.match(p_Name:sub(i + 1, i + 1), "%u") then
				s_MemberName = s_MemberName .. string.lower(p_Name:sub(i, i))
			else
				s_MemberName = s_MemberName .. p_Name:sub(i, i)
			end
		else
			s_MemberName = s_MemberName .. p_Name:sub(i, p_Name:len())
			break
		end
	end

	for _, l_ReservedLuaKeyword in ipairs(m_ReservedLuaKeywords) do
		if l_ReservedLuaKeyword == string.lower(s_MemberName) then
			s_MemberName = s_MemberName .. "Value"
		end
	end

	return s_MemberName
end

local PARTITIONGUID = ""

local function _ProcessFieldType(p_FieldValue, p_TypeInfo)
	if p_TypeInfo and p_TypeInfo.enum then
		for _, innerField in ipairs(p_TypeInfo.fields) do
			if _G[p_TypeInfo.name][innerField.name] == p_FieldValue then
				return innerField.name
			end
		end

		return p_FieldValue or "null"
	elseif type(p_FieldValue) == "boolean" then
		return p_FieldValue
	elseif type(p_FieldValue) == "boolean" or type(p_FieldValue) == "number" or type(p_FieldValue) == "string" or
		type(p_FieldValue) == "nil" then
		return p_FieldValue ~= nil and p_FieldValue or "null"
	elseif type(p_FieldValue) == "userdata" then
		-- Struct
		if p_FieldValue.isReadOnly == nil then
			if p_TypeInfo.name == "Guid" then
				return p_FieldValue and p_FieldValue:ToString("D") or "null"
			else
				local s_Table = {}

				for _, l_Field in ipairs(p_TypeInfo.fields) do
					s_Table = _ProcessFields(s_Table, l_Field, p_FieldValue)
				end

				return s_Table
			end
			-- Instance
		else
			if p_FieldValue.instanceGuid == nil then
				error("InstanceGuid for " .. p_FieldValue.typeInfo.name .. " not found. ")
			end

			local s_Table = {
				InstanceGuid = p_FieldValue.instanceGuid:ToString("D")
			}

			if p_FieldValue.partitionGuid then
				s_Table.PartitionGuid = p_FieldValue.partitionGuid:ToString("D")
			elseif p_FieldValue.partition then
				s_Table.PartitionGuid = p_FieldValue.partition.guid:ToString("D")
			else
				s_Table.PartitionGuid = PARTITIONGUID
				--error("PartitionGuid for " .. p_FieldValue.typeInfo.name .. " not found. ")
			end

			return s_Table
		end
	else
		error(p_FieldValue.typeInfo.name .. " is unhandled. ")
	end
end

---@param p_InstanceTable table
---@param p_Field FieldInformation
function _ProcessFields(p_InstanceTable, p_Field, p_Instance, p_State)
	-- fixes for VEXT
	local fieldName = _FormatMemberName(p_Field.name)

	-- handle LinearTransform.left
	if p_Field.typeInfo and p_Field.typeInfo.name == "Vec3" and fieldName == "right" then
		fieldName = "left"
	end

	local fieldValue = p_State and p_State[fieldName] or p_Instance and p_Instance[fieldName]

	if p_Field.typeInfo and p_Field.typeInfo.array then
		p_InstanceTable[p_Field.name] = { IsArray = true }

		if fieldValue and #fieldValue > 0 then
			for i = 1, #fieldValue do
				p_InstanceTable[p_Field.name][i] = _ProcessFieldType(fieldValue[i], p_Field.typeInfo.elementType)
			end
		end
	else
		p_InstanceTable[p_Field.name] = _ProcessFieldType(fieldValue, p_Field.typeInfo)
	end

	return p_InstanceTable
end

---@param p_Instance DataContainer
local function _ProcessInstance(p_Instance, p_State)
	local s_InstanceTable = {
		["$type"] = p_Instance.typeInfo.name
	}

	local s_TypeInfo = p_Instance.typeInfo

	while s_TypeInfo and s_TypeInfo.name ~= "DataContainer" do
		for _, l_Field in ipairs(s_TypeInfo.fields) do
			_ProcessFields(s_InstanceTable, l_Field, p_Instance, p_State)
		end
		s_TypeInfo = s_TypeInfo.super
	end

	return s_InstanceTable
end

local function _AddTabsToString(p_Str, p_NoOfTabs)
	for i = p_NoOfTabs, 1, -1 do
		p_Str = p_Str .. '  '
	end

	return p_Str
end

local function _HandleTablePrint(p_Table, p_NoOfTabs)
	local str = ''
	local closing = _AddTabsToString('', p_NoOfTabs)

	if p_Table.IsArray then
		p_Table.IsArray = nil
		str = str .. '[\n'
		closing = closing .. ']'
	else
		str = str .. '{\n'
		closing = closing .. '}'
	end

	local s_TableCount = 0

	for k, v in pairs(p_Table) do
		s_TableCount = s_TableCount + 1
	end

	p_NoOfTabs = p_NoOfTabs + 1

	for l_FieldName, l_FieldValue in pairs(p_Table) do
		str = _AddTabsToString(str, p_NoOfTabs)

		if type(l_FieldName) == "string" then
			str = str .. '"' .. l_FieldName .. '": '
		end

		if type(l_FieldValue) == "table" then
			str = str .. _HandleTablePrint(l_FieldValue, p_NoOfTabs)
		elseif type(l_FieldValue) == "string" then
			if l_FieldValue == "null" then
				str = str .. l_FieldValue
			else
				str = str .. '"' .. l_FieldValue .. '"'
			end
		else
			str = str .. tostring(l_FieldValue)
		end

		s_TableCount = s_TableCount - 1

		if s_TableCount == 0 then
			str = str .. '\n'
		else
			str = str .. ',\n'
		end
	end

	return str .. closing
end

---@param p_Partition DatabasePartition
function DumpPartition(p_Partition)
	if p_Partition == nil then return end
	if not p_Partition.name then return end
	if not p_Partition.primaryInstance then return end
	if not p_Partition.instances then return end

	print("Dumping partition " .. p_Partition.name)

	local s_EBXPartition = {}

	s_EBXPartition.Name = p_Partition.name
	s_EBXPartition.PartitionGuid = p_Partition.guid:ToString("D")
	s_EBXPartition.PrimaryInstanceGuid = p_Partition.primaryInstance.instanceGuid:ToString("D") or
		MathUtils:RandomGuid():ToString("D")
	s_EBXPartition.Instances = {}

	for _, l_Instance in ipairs(p_Partition.instances) do
		l_Instance = _G[l_Instance.typeInfo.name](l_Instance)

		local str_InstanceGuid = l_Instance.instanceGuid and tostring(l_Instance.instanceGuid) or
			tostring(MathUtils:RandomGuid())

		s_EBXPartition.Instances[str_InstanceGuid] = _ProcessInstance(l_Instance)
	end

	print('\n' .. _HandleTablePrint(s_EBXPartition, 0))
end

function DumpVEPreset(p_VEPreset, p_Name, p_SupportedClasses)
	print("Dumping partition " .. p_Name)

	local s_EBXPartition = {}

	s_EBXPartition.Name = p_Name:lower()
	s_EBXPartition.PartitionGuid = MathUtils:RandomGuid():ToString("D")
	s_EBXPartition.Instances = {}

	PARTITIONGUID = s_EBXPartition.PartitionGuid

	local s_VisualEnvironmentEntityData = VisualEnvironmentEntityData(MathUtils:RandomGuid())
	local s_Index = 0

	for _, l_ClassName in pairs(p_SupportedClasses) do
		if p_VEPreset[firstToLower(l_ClassName)] then
			if not _G[l_ClassName .. "ComponentData"] then
				error(l_ClassName .. " not supported.")
			else
				print("dumping " .. l_ClassName)
			end

			local s_Instance = _G[l_ClassName .. "ComponentData"](MathUtils:RandomGuid())
			s_Index = s_Index + 1
			s_Instance.indexInBlueprint = s_Index

			local str_InstanceGuid = s_Instance.instanceGuid and tostring(s_Instance.instanceGuid)

			s_EBXPartition.Instances[str_InstanceGuid] = _ProcessInstance(s_Instance, p_VEPreset[firstToLower(l_ClassName)])
			s_VisualEnvironmentEntityData.components:add(s_Instance)
			s_VisualEnvironmentEntityData.runtimeComponentCount = s_Index
		end
	end

	if s_Index == 0 then
		error("VePreset is empty.")
	end

	s_VisualEnvironmentEntityData.enabled = true
	s_VisualEnvironmentEntityData.indexInBlueprint = 0
	s_VisualEnvironmentEntityData.isEventConnectionTarget = 0
	s_VisualEnvironmentEntityData.isPropertyConnectionTarget = 0
	s_VisualEnvironmentEntityData.priority = 1
	s_VisualEnvironmentEntityData.visibility = 1.0

	local s_VisualEnvironmentBlueprint = VisualEnvironmentBlueprint(MathUtils:RandomGuid())
	s_VisualEnvironmentBlueprint.object = s_VisualEnvironmentEntityData
	s_VisualEnvironmentBlueprint.name = p_Name

	s_EBXPartition.PrimaryInstanceGuid = tostring(s_VisualEnvironmentBlueprint.instanceGuid)
	s_EBXPartition.Instances[s_EBXPartition.PrimaryInstanceGuid] = _ProcessInstance(s_VisualEnvironmentBlueprint)

	local str_InstanceGuid = tostring(s_VisualEnvironmentEntityData.instanceGuid)
	s_EBXPartition.Instances[str_InstanceGuid] = _ProcessInstance(s_VisualEnvironmentEntityData)

	print('\n' .. _HandleTablePrint(s_EBXPartition, 0))
end
