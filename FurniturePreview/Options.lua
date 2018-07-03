function FurPreview:SetupOptions()
	local panelData = {
		type = "panel",
		name = "ItemPreview",
		author = "Shinni",
		version = "1.14",
		registerForDefaults = true,
	}
	
	local lang = self.lang
	
	self.optionsTable = {
		{
			type = "checkbox",
			name = lang.previewArmor,
			getFunc = function() return not self.settings.disablePreviewArmor end,
			setFunc = function(value)
				self:SetPreviewArmor(value)
			end,
			width = "full",	--or "half" (optional)
			default = true,
		},
		{
			type = "checkbox",
			name = lang.startWithClick,
			getFunc = function() return not self.settings.disablePreviewOnClick end,
			setFunc = function(value)
				self:SetPreviewOnClick(value)
			end,
			width = "full",	--or "half" (optional)
			default = true,
		},
		{
			type = "header",
			name = lang.scenes,
			width = "full",	--or "half" (optional)
		},
	}
	
	local scenes = {"smithing", "inventory", "bank", "guildBank", "mailInbox", "mailSend", "tradinghouse", "trade"}
	for _, scene in pairs(scenes) do
		local tag = scene
		table.insert(self.optionsTable, {
			type = "checkbox",
			name = lang[tag],
			getFunc = function() return self.settings[tag] end,
			setFunc = function(value) self.settings[tag] = value end,
			width = "full",	--or "half" (optional)
			default = true,
		})
	end
	

	local LAM = LibStub("LibAddonMenu-2.0")
	LAM:RegisterAddonPanel("FurniturePreviewOptions", panelData)
	LAM:RegisterOptionControls("FurniturePreviewOptions", self.optionsTable)
end