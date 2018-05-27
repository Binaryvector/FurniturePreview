-- libPreview by Shinni
-- this library simplifies the preview of items
-- the easiest way to use it is via:
--[[

-- load the library
local PREVIEW = LibStub("LibPreview")

-- preview an item
PREVIEW:PreviewItemLink(itemLink)

-- if you want to close the preview again
PREVIEW:DisablePreviewMode()

--]]

local LIB_NAME = "LibPreview"
local VERSION = 13
local lib = LibStub:NewLibrary(LIB_NAME, VERSION)
if not lib then return end

lib.dataLoaded = false

if lib.Unload then lib:Unload() end

function lib:Debug(...)
	if lib.debugOutput then
		d(...)
	end
end

local NUM_SAVED_SETS = 4

function lib:Initialize()
	
	self.itemIdToMarkedId = {}
	for marketId, marketData in pairs(self.MarkedIdToItemInfo) do
		self.itemIdToMarkedId[ marketData[1] ] = marketId
	end
	
	self.defaultOptionsFragment = ZO_ItemPreviewOptionsFragment:New({
		paddingLeft = 0,
		paddingRight = 0,
		dynamicFramingConsumedWidth = 1050,
		dynamicFramingConsumedHeight = 300,
		maintainsPreviewCollection = true,
	})
	
	self.defaultLeftOptionsFragment = ZO_ItemPreviewOptionsFragment:New({
		paddingLeft = 0,
		paddingRight = 950,
		dynamicFramingConsumedWidth = 1150,
		dynamicFramingConsumedHeight = 300,
		maintainsPreviewCollection = true,
	})
	
	self.framePlayerFragment = ZO_FramePlayerFragment:New()
	self.framePlayerFragment:RegisterCallback("StateChange", function(oldState, newState)
		if newState == SCENE_HIDING then
			self:DisablePreviewMode()
		end
	end)
	
	local OUTFIT_COLLECTION = #ITEM_PREVIEW_KEYBOARD.previewTypeObjects + 1
	lib.hookedTypes[OUTFIT_COLLECTION] = true
	local ZO_ItemPreviewType_OutfitCollection = ZO_ItemPreviewType:Subclass()
	ZO_ItemPreviewType_OutfitCollection.queuedSlots = {}
	ZO_ItemPreviewType_OutfitCollection.pendingItemMaterialIndex = ZO_OUTFIT_STYLE_DEFAULT_ITEM_MATERIAL_INDEX
	function ZO_ItemPreviewType_OutfitCollection:SetStaticParameters(list)
		zo_mixin(self.queuedSlots, list)
	end

	function ZO_ItemPreviewType_OutfitCollection:ResetStaticParameters()
		self.queuedSlots = {}
	end

	function ZO_ItemPreviewType_OutfitCollection:HasStaticParameters()
		return false
	end
	
	function ZO_ItemPreviewType_OutfitCollection:GetPendingDyeData()
		self.queuedSlots[self.outfitSlotIndex] = nil
		return GetSavedDyeSetDyes(self.previewVariationIndex-1)
	end
	
	function ZO_ItemPreviewType_OutfitCollection:GetNumVariations()
		--if self.showDyeStampSets then return NUM_SAVED_SETS end
		--return 0
		return NUM_SAVED_SETS
	end

	function ZO_ItemPreviewType_OutfitCollection:GetVariationName(variationIndex)
		if variationIndex == 1 then return "No Dye Set" end
		return "Saved Dye Set " .. tostring(variationIndex-1)
	end
	
	
	function ZO_ItemPreviewType_OutfitCollection:Apply(variationIndex)
		if self.previewVariationIndex ~= variationIndex then
			self.previewVariationIndex = variationIndex
			list = {}
			local result
			local previewCollectionId = SYSTEMS:GetObject("itemPreview"):GetPreviewCollectionId()
			for outfitSlot = OUTFIT_SLOT_MIN_VALUE, OUTFIT_SLOT_MAX_VALUE do
				result = GetOutfitSlotInfoForOutfitSlotInPreviewCollection(previewCollectionId, outfitSlot)
				if result ~= 0 then
					list[outfitSlot] = result
				end
			end
			zo_mixin(list, self.queuedSlots)
			self.queuedSlots = list
		end
		self.outfitSlotIndex, self.pendingCollectibleId = next(self.queuedSlots)
		local shouldRefresh = true
		if next(self.queuedSlots, self.outfitSlotIndex) then
			-- set this value, so in the next frame we will preview the next outfit slot
			SYSTEMS:GetObject("itemPreview").previewAtMS = GetFrameTimeMilliseconds()
			shouldRefresh = false
		end
		-- preview one entry
		return ZO_OutfitSlotManipulator.UpdatePreview(self, shouldRefresh)
	end
	--]]
	
	function ZO_ItemPreviewType_OutfitCollection:IsAnyChangePending()
		return next(self.queuedSlots) ~= nil
	end
	
	ITEM_PREVIEW_KEYBOARD.previewTypeObjects[OUTFIT_COLLECTION] = ZO_ItemPreviewType_OutfitCollection:New()
	ITEM_PREVIEW_GAMEPAD.previewTypeObjects[OUTFIT_COLLECTION] = ZO_ItemPreviewType_OutfitCollection:New()
	
	function ZO_ItemPreview_Shared:PreviewOutfitCollection(list)
		self:SharedPreviewSetup(OUTFIT_COLLECTION, list)
	end
	
	local weaponSlots = {
		[OUTFIT_SLOT_WEAPON_BOW] = true,
		[OUTFIT_SLOT_WEAPON_BOW_BACKUP] = true,
		[OUTFIT_SLOT_WEAPON_MAIN_HAND] = true,
		[OUTFIT_SLOT_WEAPON_MAIN_HAND_BACKUP] = true,
		[OUTFIT_SLOT_WEAPON_OFF_HAND] = true,
		[OUTFIT_SLOT_WEAPON_OFF_HAND_BACKUP] = true,
		[OUTFIT_SLOT_WEAPON_STAFF] = true,
		[OUTFIT_SLOT_WEAPON_STAFF_BACKUP] = true,
		[OUTFIT_SLOT_WEAPON_TWO_HANDED] = true,
		[OUTFIT_SLOT_WEAPON_TWO_HANDED_BACKUP] = true,
		[OUTFIT_SLOT_SHIELD] = true,
		[OUTFIT_SLOT_SHIELD_BACKUP] = true,
	}
	
	function ZO_ItemPreview_Shared:PreviewItemLink(itemLink)
		local marketId = lib:GetMarketIdFromItemLink(itemLink)
	
		if marketId then
			if IsItemLinkPlaceableFurniture(itemLink) then
				self:PreviewFurnitureMarketProduct(marketId)
			else
				self:PreviewMarketProduct(marketId)
			end
			return
		end
		
		if self.currentPreviewType ~= OUTFIT_COLLECTION then-- ZO_ITEM_PREVIEW_OUTFIT then
			self:RefreshState()
			--self:PreviewUnequipOutfit()
			--local showDyeStampSets = true
			self:SharedPreviewSetup(ZO_ITEM_PREVIEW_OUTFIT, self.previewCollectionId, UNEQUIPPED_OUTFIT_INDEX)
		end
		
		local collectibleData = lib:GetOutfitCollectibleFromItemLink(itemLink)
		if not collectibleData then return end
			
		local previewCollectionId = self:GetPreviewCollectionId()
		local preferredOutfitSlot = ZO_OUTFIT_MANAGER:GetPreferredOutfitSlotForStyle(collectibleData)
		
		if weaponSlots[preferredOutfitSlot] then
			for slot in pairs(weaponSlots) do
				ClearOutfitSlotPreviewElementFromPreviewCollection(previewCollectionId, slot)
			end
		end
		
		self:PreviewOutfitCollection({[preferredOutfitSlot] = collectibleData:GetId()})
	end
	
	ZO_PreHook("PreviewInventoryItemAsFurniture", function()
		self:Debug("preview inventory furniture")
	end)
	
	ZO_PreHook("PreviewInventoryItem", function()
		self:Debug("preview inventory item/armor")
	end)
	
	-- fragment which is added to the scene.
	-- when the scene changes, we know the preview is terminated
	self.externalPreviewExitFragment = ZO_SceneFragment:New()
	self.externalPreviewExitFragment:RegisterCallback("StateChange", function(oldState, newState)
		if newState == SCENE_HIDING then
			self:DisablePreviewMode()
		end
	end)
	
	-- create a preview scene, which is used when we try to preview an item during the HUD or HUDUI scene
	self.scene = ZO_Scene:New(LIB_NAME, SCENE_MANAGER)
	self.scene:AddFragmentGroup(FRAGMENT_GROUP.MOUSE_DRIVEN_UI_WINDOW)
	self.scene:AddFragmentGroup(FRAGMENT_GROUP.FRAME_TARGET_CENTERED_NO_BLUR)
	self.scene:AddFragment(ITEM_PREVIEW_KEYBOARD:GetFragment())
	self.scene:AddFragment(self.externalPreviewExitFragment)
	
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
	
	self.initialized = true
end

function lib:IsInitialized()
	return self.initialized
end

function lib:GetOutfitCollectibleFromItemLink(itemLink)
	local outfitStyleId = GetItemLinkOutfitStyleId(itemLink)
	local categoryIndex, numSubCategories
	if IsOutfitStyleWeapon(outfitStyleId) then
		categoryIndex = 13
		numSubCategories = 5 -- 5 weapon types
	end
	if IsOutfitStyleArmor(outfitStyleId) then
		categoryIndex = 12
		numSubCategories = 7 -- 7 armor types
	end
	if not categoryIndex then return nil end
	
	for subCategoryIndex = 1, numSubCategories do
		local outfitCategory = ZO_COLLECTIBLE_DATA_MANAGER:GetCategoryDataByIndicies(categoryIndex, subCategoryIndex)
		for index, collectible in outfitCategory:CollectibleIterator() do
			if collectible.referenceId == outfitStyleId then
				return collectible
			end
		end
	end
	
	return nil
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
	return (self:GetMarketIdFromItemLink(itemLink) ~= nil) or (self:GetOutfitCollectibleFromItemLink(itemLink) ~= nil)
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
	
	if self.previewStartedByLibrary then
		if self.keybindFragment:IsHidden() then
			self:Debug("re-add keybind")
			SCENE_MANAGER:AddFragment(self.keybindFragment)
		end
		return
	end
	self.previewStartedByLibrary = true
	
	-- select the correct frame position
	if not frameFragment then
		if SYSTEMS:IsShowing(ZO_TRADING_HOUSE_SYSTEM_NAME) or SYSTEMS:IsShowing("trade") then
			frameFragment = FRAME_TARGET_STANDARD_RIGHT_PANEL_FRAGMENT
			previewOptionsFragment = previewOptionsFragment or self.defaultLeftOptionsFragment
		elseif lib.isFraming then
			-- if the player is already framed (eg inventory) then don't change anything
			frameFragment = NO_TARGET_CHANGE_FRAME
		elseif HUD_SCENE:IsShowing() or HUD_UI_SCENE:IsShowing() then
			-- when showing the base scene, we can display the character in the center
			frameFragment = FRAME_TARGET_CENTERED_FRAGMENT
		elseif IsInteractionUsingInteractCamera() then
			frameFragment = FRAME_TARGET_CENTERED_FRAGMENT
		else
			-- otherwise use the slightly shifted to the left preview (most UI is on the right, so the preview should not be occluded)
			frameFragment = FRAME_TARGET_STANDARD_RIGHT_PANEL_FRAGMENT--FRAME_TARGET_CRAFTING_FRAGMENT
			previewOptionsFragment = previewOptionsFragment or self.defaultLeftOptionsFragment
		end
	end
	
	self.usedInteractionPreview = false
	self.addedPreviewFragment = false
	
	if not IsInteractionUsingInteractCamera() then
		
		-- if we are in the base scene, trigger the preview scene
		if HUD_SCENE:IsShowing() or HUD_UI_SCENE:IsShowing() then
			self:Debug("enable preview scene")
			self.frameFragment = nil
			SCENE_MANAGER:Toggle(LIB_NAME)
			SCENE_MANAGER:AddFragment(previewOptionsFragment or self.defaultOptionsFragment)
			return
		end
		-- otherwise add preview to the currently viewed scene
		
		-- remember frame and options fragment so we can remove them when disabling the preview
		self.frameFragment = frameFragment
		self.previewOptionsFragment = previewOptionsFragment or self.defaultOptionsFragment
		
		SCENE_MANAGER:AddFragment(FRAME_PLAYER_ON_SCENE_HIDDEN_FRAGMENT)
		SCENE_MANAGER:AddFragment(self.frameFragment)
		SCENE_MANAGER:AddFragment(self.previewOptionsFragment)
		
		if not ITEM_PREVIEW_KEYBOARD:GetFragment():IsShowing() then
			SCENE_MANAGER:AddFragment(ITEM_PREVIEW_KEYBOARD:GetFragment())
			self.addedPreviewFragment = true
		end
		
	else
		-- if we are interacting (eg trader or crafting) then use ZOS' the interaction preview system
		
		-- remember frame and options fragment so we can remove them when disabling the preview
		self.frameFragment = frameFragment
		self.previewOptionsFragment = previewOptionsFragment or self.defaultOptionsFragment
		self.usedInteractionPreview = true
		SYSTEMS:GetObject("itemPreview"):SetInteractionCameraPreviewEnabled(
			true,
			self.frameFragment,
			self.framePlayerFragment,
			self.previewOptionsFragment)
		
	end
	
	if self.keybindFragment:IsHidden() then
		self:Debug("add keybind")
		SCENE_MANAGER:AddFragment(self.keybindFragment)
	end
	
	SCENE_MANAGER:AddFragment(self.externalPreviewExitFragment)
	
end

function lib:DisablePreviewMode()
	if not self.previewStartedByLibrary then return end
	self.previewStartedByLibrary = false
	
	SCENE_MANAGER:RemoveFragment(self.externalPreviewExitFragment)
	
	-- if preview via adding scene
	if self.scene:IsShowing() then
		SCENE_MANAGER:Show("hudui")
		return
	end
	
	SCENE_MANAGER:RemoveFragment(self.externalPreviewExitFragment)
	
	-- if preview using ZOS' interaction preview
	if self.usedInteractionPreview then
		SYSTEMS:GetObject("itemPreview"):SetInteractionCameraPreviewEnabled(
			false,
			self.frameFragment,
			self.framePlayerFragment,
			self.previewOptionsFragment)
		SCENE_MANAGER:RemoveFragment(self.keybindFragment)
		return
	end
	
	-- if preview via adding fragments
	SCENE_MANAGER:RemoveFragment(FRAME_PLAYER_ON_SCENE_HIDDEN_FRAGMENT)
	SCENE_MANAGER:RemoveFragment(self.frameFragment)
	SCENE_MANAGER:RemoveFragment(self.previewOptionsFragment)
	if self.addedPreviewFragment then
		SCENE_MANAGER:RemoveFragment(ITEM_PREVIEW_KEYBOARD:GetFragment())
	else
		ITEM_PREVIEW_KEYBOARD:EndCurrentPreview()
	end
	SCENE_MANAGER:RemoveFragment(self.keybindFragment)
	
end

function lib:PreviewItemLink(itemLink, frameFragment, optionsFragment)
	if not self.validHook then
		d("preview error: no valid hook created yet")
		return
	end
	self:EnablePreviewMode(frameFragment, optionsFragment)
	SYSTEMS:GetObject("itemPreview"):PreviewItemLink(itemLink)
end

function lib:PreviewInventoryItemAsFurniture(bagId, slotIndex)
	if not self.validHook then
		d("preview error: no valid hook created yet")
		return
	end
	self:EnablePreviewMode()
	ITEM_PREVIEW_KEYBOARD:PreviewInventoryItemAsFurniture(bagId, slotIndex)
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
		
		local origGetPreviewModeEnabled = GetPreviewModeEnabled
		GetPreviewModeEnabled = function()
			GetPreviewModeEnabled = origGetPreviewModeEnabled
			return true
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
	
	lib.hookedTypes = {
		[ZO_ITEM_PREVIEW_FURNITURE_MARKET_PRODUCT] = true,
		[ZO_ITEM_PREVIEW_MARKET_PRODUCT] = true,
	}
	
	lib.origSharedPreviewSetup = ZO_ItemPreview_Shared.SharedPreviewSetup
	ZO_PreHook(ZO_ItemPreview_Shared, "SharedPreviewSetup", function(self, previewType, ...)
		if lib.hookedTypes[previewType] then
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
