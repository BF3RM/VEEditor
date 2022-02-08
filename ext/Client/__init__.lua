local m_Logger = Logger("Init", false)

-- require editorLayer Preset
local m_EditorLayer = require('EditorLayer')

-- require VEEditor
local m_Editor = require('VEEditor')

-- require DebugGUI Client Script
local m_DebugGUI = require('DebugGUI')

g_TextureAssets = {}
local m_CurrentMap
Events:Subscribe('Level:LoadResources', function(p_LevelName, p_GameMode, p_IsDedicatedServer)
    -- Send Preset to VEManager
	Events:Dispatch('VEManager:RegisterPreset', 'EditorLayer', m_EditorLayer)
	if m_CurrentMap ~= p_LevelName then
		g_TextureAssets = {}
	end
	m_CurrentMap = p_LevelName
end)

Events:Subscribe('Partition:Loaded', function(p_Partition)
	if p_Partition.primaryInstance:Is('TextureAsset') then
		local name = p_Partition.name:lower()
		-- Save /sky/ or /Lighting/ textures
		for _, l_Parameter in pairs(VEE_CONFIG.SEARCH_PARAMETERS_FOR_TEXTURES) do

			if string.find(name, l_Parameter) then
				m_Logger:Write("Saved TextureAsset: " .. name)
				-- Save texture name in the list
				table.insert(g_TextureAssets, name)
			end
		end
	end
end)

