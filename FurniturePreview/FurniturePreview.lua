
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
		if self.settings.disablePreviewOnClick then
			d("activated preview on click")
		else
			d("disabled preview on click")
		end
		self:SetPreviewOnClick(not self.settings.disablePreviewOnClick)
	end
	
	SLASH_COMMANDS["/previewarmor"] = function()
		if self.settings.disablePreviewArmor then
			d("activated armor preview")
		else
			d("disabled armor preview")
		end
		self:SetPreviewArmor(not self.settings.disablePreviewArmor)
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
	
	
	-- add trading house armor preview
	ZO_PreHook("ZO_TradingHouse_OnSearchResultClicked", function(searchResultSlot, button)
		if button == MOUSE_BUTTON_INDEX_LEFT then
			local inventorySlot, listPart, multiIconPart = ZO_InventorySlot_GetInventorySlotComponents(searchResultSlot)
			local tradingHouseIndex = ZO_Inventory_GetSlotIndex(inventorySlot)
			if tradingHouseIndex ~= nil then
				local itemLink = GetTradingHouseSearchResultItemLink(tradingHouseIndex)
				if FurPreview:IsItemLinkPreviewableArmor(itemLink) then
					TRADING_HOUSE:PreviewSearchResult(tradingHouseIndex)
					return true
				end
			end
		end
	end)
	
	local function GetTradingHouseIndexForPreviewFromSlot(storeEntrySlot)
		local inventorySlot, listPart, multiIconPart = ZO_InventorySlot_GetInventorySlotComponents(storeEntrySlot)

		local slotType = ZO_InventorySlot_GetType(inventorySlot)
		if slotType == SLOT_TYPE_TRADING_HOUSE_ITEM_RESULT then
			local tradingHouseIndex = ZO_Inventory_GetSlotIndex(inventorySlot)
			local itemLink = GetTradingHouseSearchResultItemLink(tradingHouseIndex)
			if ZO_ItemPreview_Shared.CanItemLinkBePreviewedAsFurniture(itemLink) then
				return tradingHouseIndex
			end
			if FurPreview:IsItemLinkPreviewableArmor(itemLink) then
				return tradingHouseIndex
			end
		end

		return nil
	end
	
	function ZO_TradingHouse_OnSearchResultMouseEnter(searchResultSlot)
		ZO_InventorySlot_OnMouseEnter(searchResultSlot)

		local tradingHouseIndex = GetTradingHouseIndexForPreviewFromSlot(searchResultSlot)

		local cursor = MOUSE_CURSOR_DO_NOT_CARE
		if tradingHouseIndex ~= nil then
			cursor = MOUSE_CURSOR_PREVIEW
		end

		WINDOW_MANAGER:SetMouseCursor(cursor)
	end
	--[[
	function TRADING_HOUSE:TogglePreviewMode(shouldBeRealWorld)
		if shouldBeRealWorld then
			ITEM_PREVIEW_KEYBOARD:ToggleInteractionCameraPreview(FRAME_TARGET_STANDARD_RIGHT_PANEL_FRAGMENT, FRAME_PLAYER_ON_SCENE_HIDDEN_FRAGMENT, RIGHT_BG_ITEM_PREVIEW_OPTIONS_FRAGMENT)
		else
			ITEM_PREVIEW_KEYBOARD:ToggleInteractionCameraPreview(FRAME_TARGET_STANDARD_RIGHT_PANEL_FRAGMENT, FRAME_PLAYER_ON_SCENE_HIDDEN_FRAGMENT, RIGHT_BG_EMPTY_WORLD_ITEM_PREVIEW_OPTIONS_FRAGMENT)
		end
		KEYBIND_STRIP:UpdateKeybindButtonGroup(self.keybindStripDescriptor)
	end
	
	function TRADING_HOUSE:PreviewSearchResult(tradingHouseIndex)
		
		local itemLink = GetTradingHouseSearchResultItemLink(tradingHouseIndex)
		if FurPreview:IsItemLinkPreviewableArmor(itemLink) then
			PREVIEW:PreviewItemLink(itemLink)
			return true
		end
		local itemType, specializedItemType = GetItemLinkItemType(itemLink)
		local shouldBeEmptyWorld = not (itemType == ITEMTYPE_ARMOR)
		
		if not ITEM_PREVIEW_KEYBOARD:IsInteractionCameraPreviewEnabled() then
			self:TogglePreviewMode(not shouldBeEmptyWorld)
		else
			if shouldBeEmptyWorld ~= ITEM_PREVIEW_KEYBOARD.previewInEmptyWorld then
				self:TogglePreviewMode(shouldBeEmptyWorld)
				self:TogglePreviewMode(not shouldBeEmptyWorld)
			end
		end
		
		if shouldBeEmptyWorld then
			ITEM_PREVIEW_KEYBOARD:PreviewTradingHouseSearchResultAsFurniture(tradingHouseIndex)
		else
			if PREVIEW:CanPreviewItemLink(itemLink) then
				PREVIEW:PreviewItemLink(itemLink)
			end
		end
		KEYBIND_STRIP:UpdateKeybindButtonGroup(self.keybindStripDescriptor)
	end
	--]]
	
	ZO_PreHook(TRADING_HOUSE, "PreviewSearchResult", function(self, tradingHouseIndex)
		local itemLink = GetTradingHouseSearchResultItemLink(tradingHouseIndex)
		if FurPreview:IsItemLinkPreviewableArmor(itemLink) then
			PREVIEW:PreviewItemLink(itemLink)
			return true
		end
	end)
end

function FurPreview:IsItemLinkPreviewableArmor(itemLink)
	if self.settings.disablePreviewArmor then return false end
	return (PREVIEW:GetOutfitCollectibleFromItemLink(itemLink) ~= nil)
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

function FurPreview:SetPreviewArmor(disablePreviewArmor)
	self.settings.disablePreviewArmor = disablePreviewArmor
end

-- how to get the item link for the specific item slot types
local slotTypeToItemLink = {
	--[SLOT_TYPE_TRADING_HOUSE_ITEM_RESULT] = function(inventorySlot) return GetTradingHouseSearchResultItemLink(ZO_Inventory_GetSlotIndex(inventorySlot)) end,
	[SLOT_TYPE_TRADING_HOUSE_ITEM_LISTING] = function(inventorySlot) return GetTradingHouseListingItemLink(ZO_Inventory_GetSlotIndex(inventorySlot)) end,
	
	[SLOT_TYPE_CRAFTING_COMPONENT] = function(inventorySlot) return GetItemLink(ZO_Inventory_GetBagAndIndex(inventorySlot)) end,
	
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
	
	self.inventorySlot = inventorySlot
	self.itemLink = itemLink
	
	if inventorySlot ~= nil then
		if slotType == SLOT_TYPE_ITEM or slotType == SLOT_TYPE_BANK_ITEM or slotType == SLOT_TYPE_GUILD_BANK_ITEM then
			if not FurPreview:IsItemLinkPreviewableArmor(itemLink) then
				PREVIEW:PreviewInventoryItemAsFurniture(ZO_Inventory_GetBagAndIndex(inventorySlot))
				return
			end
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
	end
	
end



