-- libPreview by Shinni
-- this library simplifies the preview of furniture items outside of the inventory screen
--
-- This library is still in developement. You can use it, but beware of bugs

local LIB_NAME = "LibPreview"
local VERSION = 8
local lib = LibStub:NewLibrary(LIB_NAME, VERSION)
if not lib then return end

lib.dataLoaded = false

if lib.Unload then lib:Unload() end

function lib:Initialize()
	self.initialized = true
	self.stack = 0
	self.itemIdToMarkedId = {}
	for marketId, marketData in pairs(self.MarkedIdToItemInfo) do
		self.itemIdToMarkedId[ marketData[1] ] = marketId
	end
	
	function ZO_ItemPreview_Shared:PreviewItemLink(itemLink)
		local marketId = lib:GetMarketIdFromItemLink(itemLink)
	
		if marketId then
			if IsItemLinkPlaceableFurniture(itemLink) then
				self:PreviewFurnitureMarketProduct(marketId)
			else
				self:PreviewMarketProduct(marketId)
			end
		end
	end
	
	-- add store preview API to the item preview manager
	local STORE_PREVIEW = #ITEM_PREVIEW_KEYBOARD.previewTypeObjects + 1
	local ZO_ItemPreviewType_Store = ZO_ItemPreviewType:Subclass()
	function ZO_ItemPreviewType_Store:SetStaticParameters(index)
		self.index = index
	end
	function ZO_ItemPreviewType_Store:GetStaticParameters()
		return self.index
	end
	function ZO_ItemPreviewType_Store:HasStaticParameters(index)
		return index == self.index
	end
	function ZO_ItemPreviewType_Store:ResetStaticParameters()
		self.index = nil
	end
	function ZO_ItemPreviewType_Store:Apply()
		PreviewStoreEntryAsFurniture(self.index)
	end
	ITEM_PREVIEW_KEYBOARD.previewTypeObjects[STORE_PREVIEW] = ZO_ItemPreviewType_Store:New()
	ITEM_PREVIEW_GAMEPAD.previewTypeObjects[STORE_PREVIEW] = ZO_ItemPreviewType_Store:New()
	
	function ZO_ItemPreview_Shared:PreviewStoreEntryAsFurniture(index)
		self:SharedPreviewSetup(STORE_PREVIEW, index)
	end
	
	------------------------------------------------------------
	
	local INVENTORY_ITEM = #ITEM_PREVIEW_KEYBOARD.previewTypeObjects + 1
	local ZO_ItemPreviewType_InventoryItem = ZO_ItemPreviewType:Subclass()
	function ZO_ItemPreviewType_InventoryItem:SetStaticParameters(bag, slot)
		self.bag = bag
		self.slot = slot
	end

	function ZO_ItemPreviewType_InventoryItem:ResetStaticParameters()
		self.bag = 0
		self.slot = 0
	end

	function ZO_ItemPreviewType_InventoryItem:HasStaticParameters(bag, slot)
		return self.bag == bag and self.slot == slot
	end

	function ZO_ItemPreviewType_InventoryItem:Apply(variationIndex)
		if variationIndex > 1 then variationIndex = variationIndex + 3 end
		PreviewInventoryItem(self.bag, self.slot, variationIndex)
	end
	function ZO_ItemPreviewType_InventoryItem:GetNumVariations()
		return 1001
	end

	function ZO_ItemPreviewType_InventoryItem:GetVariationName(variationIndex)
		if variationIndex == 1 then return "Default" end
		return GetItemLinkName("|H1:item:" .. tostring(83517 + variationIndex) .. ":0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h")
	end
	ITEM_PREVIEW_KEYBOARD.previewTypeObjects[INVENTORY_ITEM] = ZO_ItemPreviewType_InventoryItem:New()
	ITEM_PREVIEW_GAMEPAD.previewTypeObjects[INVENTORY_ITEM] = ZO_ItemPreviewType_InventoryItem:New()
	
	function ZO_ItemPreview_Shared:PreviewInventoryItem(bag, slot)
		self:SharedPreviewSetup(INVENTORY_ITEM, bag, slot)
	end
	
	-- add trading house preview API to the item preview manager
	local TRADING_HOUSE_PREVIEW = #ITEM_PREVIEW_KEYBOARD.previewTypeObjects + 1
	local ZO_ItemPreviewType_TradingHouse = ZO_ItemPreviewType:Subclass()
	function ZO_ItemPreviewType_TradingHouse:SetStaticParameters(index, dyeStamp)
		self.index = index
		self.dyeStamp = dyeStamp
	end
	function ZO_ItemPreviewType_TradingHouse:GetStaticParameters()
		return self.index, self.dyeStamp
	end
	function ZO_ItemPreviewType_TradingHouse:HasStaticParameters(index)
		return self.index == index
	end
	function ZO_ItemPreviewType_TradingHouse:ResetStaticParameters()
		self.index = 0
		self.dyeStamp = nil
	end
	function ZO_ItemPreviewType_TradingHouse:Apply(variationIndex)
		if variationIndex > 1 then variationIndex = variationIndex + 3 end
		PreviewTradingHouseSearchResultItem(self.index, variationIndex)
	end
	function ZO_ItemPreviewType_TradingHouse:GetNumVariations()
		return 1001
	end

	function ZO_ItemPreviewType_TradingHouse:GetVariationName(variationIndex)
		if variationIndex == 1 then return "Default" end
		return GetItemLinkName("|H1:item:" .. tostring(83517 + variationIndex) .. ":0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h")
	end
	ITEM_PREVIEW_KEYBOARD.previewTypeObjects[TRADING_HOUSE_PREVIEW] = ZO_ItemPreviewType_TradingHouse:New()
	ITEM_PREVIEW_GAMEPAD.previewTypeObjects[TRADING_HOUSE_PREVIEW] = ZO_ItemPreviewType_TradingHouse:New()
	
	function ZO_ItemPreview_Shared:PreviewTradingHouseSearchResult(index, dyeStamp)
		self:SharedPreviewSetup(TRADING_HOUSE_PREVIEW, index, dyeStamp)
	end
	
	-- this way we can use it outside of interactions, i.e. in the mail scene
	ZO_ItemPreview_Shared.IsInteractionCameraPreviewEnabled = IsInPreviewMode
	
	-- create a preview scene, which is used when we try to preview an item during the HUD or HUDUI scene
	self.scene = ZO_Scene:New(LIB_NAME, SCENE_MANAGER)
	self.scene:AddFragmentGroup(FRAGMENT_GROUP.MOUSE_DRIVEN_UI_WINDOW)
	self.scene:AddFragmentGroup(FRAGMENT_GROUP.FRAME_TARGET_CENTERED_NO_BLUR)
	
	-- quaternary end preview keybind
	local function GetDescriptorFromButton(buttonOrEtherealDescriptor)
		if type(buttonOrEtherealDescriptor) == "userdata" then
			return buttonOrEtherealDescriptor.keybindButtonDescriptor
		end
		return buttonOrEtherealDescriptor
	end
	
	self.keybindButtonGroup = {
		alignment = KEYBIND_STRIP_ALIGN_CENTER,
		{
			name =      GetString(SI_CRAFTING_EXIT_PREVIEW_MODE),
			keybind =   "UI_SHORTCUT_QUATERNARY",--"UI_SHORTCUT_NEGATIVE",
			visible =   function()
								--d(IsCurrentlyPreviewing())
								return not self.keybindFragment:IsHidden()--IsCurrentlyPreviewing()--self.PreviewStartedByLibrary
						end,
			callback =  function()
							self:DisablePreviewMode()
						end,
		}
	}
	
	self.keybindFragment = ZO_SceneFragment:New()
	self.keybindFragment:RegisterCallback("StateChange", function(oldState, newState)
		if newState == SCENE_SHOWN then
			local descriptor = GetDescriptorFromButton(KEYBIND_STRIP.keybinds["UI_SHORTCUT_QUATERNARY"])
			if descriptor then
				KEYBIND_STRIP:RemoveKeybindButton(descriptor)
			end
			KEYBIND_STRIP:AddKeybindButtonGroup(self.keybindButtonGroup)
			
			if descriptor then
				if descriptor.keybindButtonGroupDescriptor then
					--local myDescriptor = GetDescriptorFromButton(KEYBIND_STRIP.keybinds["UI_SHORTCUT_QUATERNARY"])
					--d(descriptor.keybindButtonGroupDescriptor)
					for key, keybind in pairs(descriptor.keybindButtonGroupDescriptor) do
						if type(keybind) == "table" and keybind.keybind == "UI_SHORTCUT_QUATERNARY" then
							self.keybindFragment.originalKeybind = keybind
							self.keybindFragment.originalKey = key
							self.keybindFragment.originalGroup = descriptor.keybindButtonGroupDescriptor
							descriptor.keybindButtonGroupDescriptor[key] = nil--myDescriptor.keybindButtonGroupDescriptor[1]
							break
						end
					end
				end
			end
			--]]
		elseif newState == SCENE_HIDING then
			if self.keybindFragment.originalGroup then
				self.keybindFragment.originalGroup[self.keybindFragment.originalKey] = self.keybindFragment.originalKeybind
				self.keybindFragment.originalGroup = nil
				self.keybindFragment.originalKey = nil
				self.keybindFragment.originalKeybind = nil
			end
			KEYBIND_STRIP:RemoveKeybindButtonGroup(self.keybindButtonGroup)
		end
	end )
end

function lib:IsInitialized()
	return self.initialized
end

function lib:GetMarketIdFromItemLink(itemLink)
	-- if this is a recipe, preview the crafting result
	local resultItemLink = GetItemLinkRecipeResultItemLink(itemLink)
	if resultItemLink and resultItemLink ~= "" then
		itemLink = resultItemLink
	end
	
	if not IsItemLinkPlaceableFurniture(itemLink) then return end
	
	local _, _, _, itemId = ZO_LinkHandler_ParseLink(itemLink)
	itemId = tonumber(itemId)
	
	local marketId = self.itemIdToMarkedId[ itemId ]
	if not marketId then return end
	
	if not CanPreviewMarketProduct(marketId) then return end
	
	return marketId
end

---
-- Returns true if the given itemLink can be previewed
function lib:CanPreviewItemLink(itemLink)
	return lib:GetMarketIdFromItemLink(itemLink) ~= nil
end

local FRAME_PLAYER_ON_SCENE_HIDDEN_FRAGMENT = ZO_SceneFragment:New()
-- dummy frame fragment which doesn't do anything. this is used if there is already a frame fragment active
local NO_TARGET_CHANGE_FRAME = ZO_SceneFragment:New()

-- if we are already framing the player, we don't want to change the player location within the frame
-- with this little hack we can see if the framing is active already
lib.isFraming = false
ZO_PreHook("SetFrameLocalPlayerInGameCamera", function(value)
	lib.isFraming = value
end)

function lib:EnablePreviewMode(frameFragment, previewOptionsFragment)
	if not self.validHook then
		d("FurniturePreview no valid hook created yet")
		return
	end
	
	if self.previewStartedByLibrary then
		if self.keybindFragment:IsHidden() then
			SCENE_MANAGER:AddFragment(self.keybindFragment)
		end
	end
	
	previewOptionsFragment = previewOptionsFragment or CRAFTING_PREVIEW_OPTIONS_FRAGMENT
	local previewSystem = SYSTEMS:GetObject("itemPreview")
	
	if (not previewOptionsFragment.options.previewInEmptyWorld) ~= (not previewSystem.previewInEmptyWorld) then
		previewSystem:SetPreviewInEmptyWorld(not not previewOptionsFragment.options.previewInEmptyWorld)
	end
	
	--if IsCurrentlyPreviewing() then
	--	return
	--end
	
	if not frameFragment then
		if SYSTEMS:IsShowing(ZO_TRADING_HOUSE_SYSTEM_NAME) or SYSTEMS:IsShowing("trade") then
			-- for the trade scene and the guild store, we want the preview to be on the far left side
			frameFragment = FRAME_TARGET_STANDARD_RIGHT_PANEL_FRAGMENT
		elseif lib.isFraming then
			-- if there is already a frame fragment active, use the dummy one
			frameFragment = NO_TARGET_CHANGE_FRAME
		elseif HUD_SCENE:IsShowing() or HUD_UI_SCENE:IsShowing() then
			-- in the hud scene, the center is empty
			frameFragment = FRAME_TARGET_CENTERED_FRAGMENT
		else
			-- otherwise use the lisghtly shifted to the left preview (most UI is on the right, so the preview should not be occluded)
			frameFragment = FRAME_TARGET_CRAFTING_FRAGMENT
		end
	end
	
	if HUD_SCENE:IsShowing() or HUD_SCENE:IsShowing() then
		SCENE_MANAGER:Toggle(LIB_NAME)
	end
	
	if self.keybindFragment:IsHidden() then
		SCENE_MANAGER:AddFragment(self.keybindFragment)
	end
	
	if previewSystem:IsInteractionCameraPreviewEnabled() then return false end
	self.PreviewStartedByLibrary = true
	
	self.frameFragment = frameFragment
	self.previewOptionsFragment = previewOptionsFragment
	previewSystem:SetInteractionCameraPreviewEnabled(
		true,
		self.frameFragment,
		FRAME_PLAYER_FRAGMENT,
		self.previewOptionsFragment)
	
end

function lib:DisablePreviewMode()
	if self.scene:IsShowing() then
		SCENE_MANAGER:Show("hudui")
	end
	SCENE_MANAGER:RemoveFragment(self.keybindFragment)
	if not self.PreviewStartedByLibrary then
		self.PreviewStartedByLibrary = false
		SYSTEMS:GetObject("itemPreview"):EndCurrentPreview()
		return
	end
	self.PreviewStartedByLibrary = false
	
	SYSTEMS:GetObject("itemPreview"):SetInteractionCameraPreviewEnabled(
		false,
		self.frameFragment,
		FRAME_PLAYER_FRAGMENT,
		self.previewOptionsFragment)
	
	EndCurrentItemPreview()
end

function lib:PreviewItemLink(itemLink)
	if not self.validHook then
		d("FurniturePreview no valid hook created yet")
		return
	end
	lib:EnablePreviewMode()
	SYSTEMS:GetObject("itemPreview"):PreviewItemLink(itemLink)
end

local function OnActivated()
	EVENT_MANAGER:UnregisterForEvent(LIB_NAME, EVENT_PLAYER_ACTIVATED)
	
	lib:Initialize()
end

function lib:Load()
	EVENT_MANAGER:RegisterForEvent(LIB_NAME, EVENT_PLAYER_ACTIVATED, OnActivated)
	
	local previewStarted = false
	local fastOnUpdate = true
	local untaintedFunction
	self.validHook = false
	HUD_SCENE:AddFragment(SYSTEMS:GetObject("itemPreview").fragment)
	lib.origOnPreviewShowing = ZO_ItemPreview_Shared.OnPreviewShowing
	lib.log = {}
	ZO_PreHook(ZO_ItemPreview_Shared, "OnPreviewShowing", function()
		local success, msg = pcall(function() error("") end)
		local count = 0
		for start, endIndex in string.gfind(msg,"user:/AddOns") do
			count = count + 1
		end
		--d("num addon calls", count)
		--d(msg)
		if count ~= 3 then
			ZO_ERROR_FRAME:OnUIError(msg)
			d("FurniturePreview error. No valid hook")
			return
		end
		
		ZO_ItemPreview_Shared.OnPreviewShowing = lib.origOnPreviewShowing
		lib.origRegisterForUpdate = EVENT_MANAGER.RegisterForUpdate
		ZO_PreHook(EVENT_MANAGER, "RegisterForUpdate", function(self, name, interval, func)
			if name == "ZO_ItemPreview_Shared" then
				local success, msg = pcall(function() error("") end)
				local count = 0
				for start, endIndex in string.gfind(msg,"user:/AddOns") do
					count = count + 1
				end
				--d("num addon calls", count)
				--d(msg)
				if count ~= 3 then
					ZO_ERROR_FRAME:OnUIError(msg)
					d("FurniturePreview error. No valid hook")
					return
				end
				
				lib.validHook = true
				
				EVENT_MANAGER.RegisterForUpdate = lib.origRegisterForUpdate
				ZO_ItemPreview_Shared.OnPreviewShowing = function(...)
					lib.origOnPreviewShowing(...)
					EVENT_MANAGER:UnregisterForUpdate(name)
					EVENT_MANAGER:RegisterForUpdate(name, 0, func)
					fastOnUpdate = true
					ZO_PreHook(ZO_ItemPreview_Shared, "OnUpdate", function()
						if fastOnUpdate then
							EVENT_MANAGER:UnregisterForUpdate(name)
							EVENT_MANAGER:RegisterForUpdate(name, interval, func)
							fastOnUpdate = false
						end
					end)
				end
			end
		end)
		zo_callLater(function()
			local fragment = SYSTEMS:GetObject("itemPreview").fragment
			fragment:SetHideOnSceneHidden(false)
			HUD_SCENE:RemoveFragment(fragment)
			fragment:SetHideOnSceneHidden(true)
		end, 0)
	end)
	
	local hookedTypes = {
		[ZO_ITEM_PREVIEW_FURNITURE_MARKET_PRODUCT] = true,
		[ZO_ITEM_PREVIEW_MARKET_PRODUCT] = true,
	}
	
	lib.origSharedPreviewSetup = ZO_ItemPreview_Shared.SharedPreviewSetup
	ZO_PreHook(ZO_ItemPreview_Shared, "SharedPreviewSetup", function(self, previewType, ...)
		if hookedTypes[previewType] then
			previewStarted = true
			fastOnUpdate = true
		end
	end)
	
	lib.origIsCharacterPreviewingAvailable = IsCharacterPreviewingAvailable
	ZO_PreHook("IsCharacterPreviewingAvailable", function()
		if previewStarted then
			previewStarted = false
			ITEM_PREVIEW_KEYBOARD.previewAtMS = GetFrameTimeMilliseconds()-- + ITEM_PREVIEW_KEYBOARD.previewBufferMS
			return true
		end
	end)

end

function lib:Unload()
	ZO_ItemPreview_Shared.OnPreviewShowing = lib.origOnPreviewShowing
	ZO_ItemPreview_Shared.SharedPreviewSetup = lib.origSharedPreviewSetup
	IsCharacterPreviewingAvailable = lib.origIsCharacterPreviewingAvailable
	HUD_SCENE:RemoveFragment(SYSTEMS:GetObject("itemPreview").fragment)
	EVENT_MANAGER:UnregisterForEvent(LIB_NAME, EVENT_PLAYER_ACTIVATED)
end

lib:Load()
