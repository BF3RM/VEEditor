-- require editorLayer Preset
local m_EditorLayer = require('EditorLayer')

-- require VEEditor
local m_Editor = require('VEEditor')

-- Send Preset to VEManager
Events:Dispatch('VEManager:RegisterPreset', m_EditorLayer)

-- Grab Textures from Partitions
g_TextureAssets = {}

Events:Subscribe('Partition:Loaded', function(p_Partition)
	if p_Partition.primaryInstance:Is('TextureAsset') then
		local name = p_Partition.name:lower()
		-- Save /sky/ or /Lighting/ textures
		for _, l_Parameter in pairs(VEE_CONFIG.SEARCH_PARAMETERS_FOR_TEXTURES) do

			if string.find(name, l_Parameter) then

				m_Logger:Write("Loaded TextureAsset: " .. name)
				-- Save texture in the list
				g_TextureAssets[name] = p_Partition.primaryInstance
			end
		end
	end
end)