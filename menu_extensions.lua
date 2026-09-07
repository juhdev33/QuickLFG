QuickLFG = QuickLFG or {}

local pendingSearchEntry
local hookedInit

local function HookSearchEntry(entry)
	if entry.QuickLFGMenuHooked then
		return
	end
	entry.QuickLFGMenuHooked = true

	entry:HookScript("OnMouseDown", function(self, button)
		if button == "RightButton" then
			pendingSearchEntry = self
		end
	end)

	-- Original OnClick may return early (delisted / own listing) without opening
	-- a menu. Clear the pending frame so it cannot leak into a later menu.
	entry:HookScript("OnClick", function(self, button)
		if button == "RightButton" then
			pendingSearchEntry = nil
		end
	end)
end

local function TryHookSearchEntries()
	if hookedInit or not LFGBrowseSearchEntry_Init then
		return
	end
	hookedInit = true
	hooksecurefunc("LFGBrowseSearchEntry_Init", HookSearchEntry)
	if LFGBrowseFrame and LFGBrowseFrame.ScrollBox and LFGBrowseFrame.ScrollBox.ForEachFrame then
		LFGBrowseFrame.ScrollBox:ForEachFrame(HookSearchEntry)
	end
end

local function TakeSearchEntry()
	local entry = pendingSearchEntry
	pendingSearchEntry = nil
	if entry and entry.resultID then
		return entry
	end
end

local function IsSearchEntryMenu(rootDescription)
	if not rootDescription or not rootDescription.EnumerateElementDescriptions then
		return false
	end
	for _, element in rootDescription:EnumerateElementDescriptions() do
		if MenuUtil.GetElementText(element) == REPORT_GROUP_FINDER_ADVERTISEMENT then
			return true
		end
	end
	return false
end

local function GetRegionTag()
    local regionId = GetCurrentRegion()
    local regionMap = {
        [1] = "us",
        [2] = "kr",
        [3] = "eu",
        [4] = "tw",
        [5] = "cn"
    }
    return regionMap[regionId] or "unknown region"
end

local function AddSearchEntryButtons(rootDescription, searchEntry)
	local resultID = searchEntry.resultID
	local searchResultInfo = C_LFGList.GetSearchResultInfo(resultID)
	if not searchResultInfo then
		return
	end

	local playerInfo = searchResultInfo.numMembers == 1 and C_LFGList.GetSearchResultPlayerInfo(resultID, 1)
	if not playerInfo then
		return
	end

	rootDescription:CreateDivider()

    local regionTag = GetRegionTag()
    local name = playerInfo.name
    local realm = GetRealmName()
    realm = gsub(realm, "%s+", "-")
    local logUri = "https://fresh.warcraftlogs.com/character/" .. regionTag .. "/" .. strlower(realm) .. "/" .. strlower(name)

    if regionTag ~= "unknown region" then
        rootDescription:CreateButton("Copy logs URL", function()
            QuickLFG.ShowCopyFrame(logUri)
        end)
    else
        rootDescription:CreateButton("Unknown region", function()
            QuickLFG.ShowCopyFrame("Report issue to developer." .. " RegionID: " .. GetCurrentRegion())
        end)
    end
    rootDescription:CreateButton(COPY_CHARACTER_NAME, function()
        QuickLFG.ShowCopyFrame(playerInfo.name)
    end)
end

hooksecurefunc(Menu, "PopulateDescription", function(_, _, rootDescription)
	if not IsSearchEntryMenu(rootDescription) then
		return
	end
	local searchEntry = TakeSearchEntry()
	if not searchEntry then
		return
	end
	AddSearchEntryButtons(rootDescription, searchEntry)
end)

local VANILLA_LFG_ADDON = "Blizzard_GroupFinder_VanillaStyle"
local function IsVanillaLFGLoaded()
	if C_AddOns and C_AddOns.IsAddOnLoaded then
		return C_AddOns.IsAddOnLoaded(VANILLA_LFG_ADDON)
	end
	return IsAddOnLoaded(VANILLA_LFG_ADDON)
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:SetScript("OnEvent", function(_, _, addonName)
	if addonName == "QuickLFG" or addonName == "Blizzard_GroupFinder_VanillaStyle" then
        if IsVanillaLFGLoaded() then
            TryHookSearchEntries()
            loader:UnregisterEvent("ADDON_LOADED")
        end
	end
end)