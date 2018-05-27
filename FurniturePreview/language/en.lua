
FurPreview = FurPreview or {}

local lang = {
	startWithClick = "Preview on mouse click",
	previewArmor = "Preview armor and weapons",
	scenes = "Scenes",
	smithing = "Preview deconstructables at crafting station",
	inventory = "Preview items in inventory",
	bank = "Preview items at bank",
	guildBank = "Preview items at guild bank",
	mailInbox = "Preview items in mail inbox",
	mailSend = "Preview items in mail outbox",
	trade = "Preview items during trading",
	tradinghouse = "Preview items in guild stores",
}

FurPreview.lang = FurPreview.lang or {}
for key, value in pairs(lang) do
	FurPreview.lang[key] = value
end
