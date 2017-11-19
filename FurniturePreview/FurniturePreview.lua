
FurPreview = {}
local PREVIEW = LibStub("LibPreview")

-- copied from esoui code:
local function GetInventorySlotComponents(inventorySlot)
	-- Figure out what got passed in...inventorySlot could be a list or button type...
	local buttonPart = inventorySlot
	local listPart
	local multiIconPart

	local controlType = inventorySlot:GetType()
	if controlType == CT_CONTROL and buttonPart.slotControlType and buttonPart.slotControlType == "listSlot" then
		listPart = inventorySlot
		buttonPart = inventorySlot:GetNamedChild("Button")
		multiIconPart = inventorySlot:GetNamedChild("MultiIcon")
	elseif controlType == CT_BUTTON then
		listPart = buttonPart:GetParent()
	end
	
	return buttonPart, listPart, multiIconPart
end


EVENT_MANAGER:RegisterForEvent("FurniturePreview", EVENT_ADD_ON_LOADED, function(...) FurPreview:OnAddonLoaded(...) end)
function FurPreview:OnAddonLoaded(_, addon)
	if addon ~= "FurniturePreview" then return end
	
	self.settings = ZO_SavedVars:NewAccountWide("FurniturePreview_SavedVars", 1, "settings", {disablePreviewOnClick = false} )
	
	self.ZO_InventorySlot_OnSlotClicked = ZO_InventorySlot_OnSlotClicked
	
	self:SetPreviewOnClick(self.settings.disablePreviewOnClick)
	
	SLASH_COMMANDS["/previewonclick"] = function()
		d("toggle  preview on click")
		self:SetPreviewOnClick(not self.settings.disablePreviewOnClick)
	end
	
	-- Update the mouse over cursor icon. display a preview cursor when previewing is possible
	ZO_PreHook(ZO_ItemSlotActionsController, "SetInventorySlot", function(self, inventorySlot)
		if(GetCursorContentType() ~= MOUSE_CONTENT_EMPTY) then return end
		
		if not inventorySlot then
			WINDOW_MANAGER:SetMouseCursor(MOUSE_CURSOR_DO_NOT_CARE)
			return
		end
		
		local itemLink, slotType = FurPreview:GetInventorySlotItemData(inventorySlot)
		if FurPreview:CanPreviewItem(inventorySlot, itemLink) then
			WINDOW_MANAGER:SetMouseCursor(MOUSE_CURSOR_PREVIEW)
		end
	end)
	
	-- end preview when switching tabs in the guild store
	ZO_PreHook(TRADING_HOUSE, "HandleTabSwitch", function(_, tabData)
		FurPreview:EndPreview()
	end)
	
	-- Add the preview option to the right click menu for item links (ie. chat)
	local original_OnLinkMouseUp = ZO_LinkHandler_OnLinkMouseUp
	ZO_LinkHandler_OnLinkMouseUp = function(itemLink, button, control)
		if (type(itemLink) == 'string' and #itemLink > 0) then
			local handled = LINK_HANDLER:FireCallbacks(LINK_HANDLER.LINK_MOUSE_UP_EVENT, itemLink, button, ZO_LinkHandler_ParseLink(itemLink))
			if (not handled) then
				original_OnLinkMouseUp(itemLink, button, control)
				if (button == 2 and itemLink ~= '') then
					local inventorySlot = nil
					if FurPreview:CanPreviewItem(inventorySlot, itemLink) then
						AddCustomMenuItem(GetString(SI_CRAFTING_ENTER_PREVIEW_MODE), function()
							FurPreview:Preview(inventorySlot, itemLink)
						end)
						ShowMenu(control)
					end
				end
			end
		end
	end
	
	ZO_PreHook("ZO_InventorySlot_ShowContextMenu", function(control)
		zo_callLater(function() 
			if FurPreview:CanPreviewItem(control) then
				AddCustomMenuItem(GetString(SI_CRAFTING_ENTER_PREVIEW_MODE), function()
					FurPreview:Preview(control)
				end)
				ShowMenu(control)
			end
		end, 50)
	end)
	
end

function FurPreview:SetPreviewOnClick(disablePreviewOnClick)
	self.settings.disablePreviewOnClick = disablePreviewOnClick
	-- Add preview when adding on an item slot (inventory, guild store, trade, mail etc. )
	local BUTTON_LEFT = 1
	ZO_InventorySlot_OnSlotClicked = FurPreview.ZO_InventorySlot_OnSlotClicked
	if not disablePreviewOnClick then
		ZO_PreHook("ZO_InventorySlot_OnSlotClicked", function(inventorySlot, button)
			if(button ~= BUTTON_LEFT) then return end
			if(GetCursorContentType() ~= MOUSE_CONTENT_EMPTY) then return end
			
			inventorySlot = GetInventorySlotComponents(inventorySlot)
			
			if FurPreview:CanPreviewItem(inventorySlot) then
				FurPreview:Preview(inventorySlot)
				WINDOW_MANAGER:SetMouseCursor(MOUSE_CURSOR_PREVIEW)
				return true
			end
			
		end)
	end
end

-- how to get the item link for the specific item slot types
local slotTypeToItemLink = {
	--[SLOT_TYPE_TRADING_HOUSE_ITEM_RESULT] = function(inventorySlot) return GetTradingHouseSearchResultItemLink(ZO_Inventory_GetSlotIndex(inventorySlot)) end,
	[SLOT_TYPE_TRADING_HOUSE_ITEM_LISTING] = function(inventorySlot) return GetTradingHouseListingItemLink(ZO_Inventory_GetSlotIndex(inventorySlot)) end,
	
	--[SLOT_TYPE_STORE_BUY] = function(inventorySlot) return GetStoreItemLink(inventorySlot.index) end,
	[SLOT_TYPE_STORE_BUYBACK] = function(inventorySlot) return GetBuybackItemLink(inventorySlot.index) end,
	
	[SLOT_TYPE_THEIR_TRADE] = function(inventorySlot) return GetTradeItemLink(TRADE_THEM, inventorySlot.index) end,
	[SLOT_TYPE_MY_TRADE] = function(inventorySlot) return GetTradeItemLink(TRADE_ME, inventorySlot.index) end,
	
	[SLOT_TYPE_ITEM] = function(inventorySlot) return GetItemLink(ZO_Inventory_GetBagAndIndex(inventorySlot)) end,
	[SLOT_TYPE_BANK_ITEM] = function(inventorySlot) return GetItemLink(ZO_Inventory_GetBagAndIndex(inventorySlot)) end,
	[SLOT_TYPE_GUILD_BANK_ITEM] = function(inventorySlot) return GetItemLink(ZO_Inventory_GetBagAndIndex(inventorySlot)) end,
	
	[SLOT_TYPE_MAIL_QUEUED_ATTACHMENT] = function(inventorySlot) return GetItemLink(ZO_Inventory_GetBagAndIndex(inventorySlot)) end,
	[SLOT_TYPE_MAIL_ATTACHMENT] = function(inventorySlot)
		local attachmentIndex = ZO_Inventory_GetSlotIndex(inventorySlot)
		if(attachmentIndex) then
			if not inventorySlot.money then
				if(inventorySlot.stackCount > 0) then
					return GetAttachedItemLink(MAIL_INBOX:GetOpenMailId(), attachmentIndex)
				end
			end
		end
	end,
}

function FurPreview:GetInventorySlotItemData(inventorySlot)
	if not inventorySlot then return end
	local slotType = ZO_InventorySlot_GetType(inventorySlot)
	local itemLink
	
	local getItemLink = slotTypeToItemLink[slotType]
	if getItemLink then
		itemLink = getItemLink(inventorySlot)
	end
	
	return itemLink, slotType
end

function FurPreview:Preview(inventorySlot, itemLink)
	
	local slotType
	if inventorySlot then
		itemLink, slotType = FurPreview:GetInventorySlotItemData(inventorySlot)
	end
	-- clicking twice on the same item deactivates the preview
	if IsCurrentlyPreviewing() and inventorySlot and inventorySlot == self.inventorySlot and itemLink == self.itemLink then
		self:EndPreview()
		return
	end
	
	self.inventorySlot = inventorySlot
	self.itemLink = itemLink
	
	if inventorySlot ~= nil then
		if slotType == SLOT_TYPE_ITEM or slotType == SLOT_TYPE_BANK_ITEM or slotType == SLOT_TYPE_GUILD_BANK_ITEM then
			PREVIEW:EnablePreviewMode()
			SYSTEMS:GetObject("itemPreview"):PreviewInventoryItemAsFurniture(ZO_Inventory_GetBagAndIndex(inventorySlot))--PreviewInventoryItemAsFurniture
			return
		--elseif slotType == SLOT_TYPE_TRADING_HOUSE_ITEM_RESULT then
		--	PREVIEW:EnablePreviewMode()
		--	SYSTEMS:GetObject("itemPreview"):PreviewTradingHouseSearchResultItemAsFurniture(ZO_Inventory_GetSlotIndex(inventorySlot))
		--elseif slotType == SLOT_TYPE_STORE_BUY then
		--	PREVIEW:EnablePreviewMode()
		--	SYSTEMS:GetObject("itemPreview"):PreviewStoreEntryAsFurniture(inventorySlot.index)
		end
	end
	if PREVIEW:CanPreviewItemLink(itemLink) then
		PREVIEW:PreviewItemLink(itemLink)
	end
end

function FurPreview:EndPreview()
	self.inventorySlot = nil
	self.itemLink = nil
	PREVIEW:DisablePreviewMode()
end

function FurPreview:CanPreviewItem(inventorySlot, itemLink)
	local slotType
	if inventorySlot then
		itemLink, slotType = FurPreview:GetInventorySlotItemData(inventorySlot)
	end
	
	if PREVIEW:CanPreviewItemLink(itemLink) then return true end
	
	if slotType == SLOT_TYPE_ITEM or slotType == SLOT_TYPE_BANK_ITEM or slotType == SLOT_TYPE_GUILD_BANK_ITEM then
		return IsItemPlaceableFurniture(ZO_Inventory_GetBagAndIndex(inventorySlot)) or IsItemLinkPlaceableFurniture(GetItemLinkRecipeResultItemLink(itemLink))
	--elseif slotType == SLOT_TYPE_STORE_BUY then -- slotType == SLOT_TYPE_TRADING_HOUSE_ITEM_RESULT or
	--	return IsItemLinkPlaceableFurniture(itemLink) or IsItemLinkPlaceableFurniture(GetItemLinkRecipeResultItemLink(itemLink))
	end
	
end
