local ADDON_NAME = "QuickLFG"
local VANILLA_LFG_ADDON = "Blizzard_GroupFinder_VanillaStyle"

local classFilterBox
local hotkeyOwner
local hooked
local applyingFilter
local searchWaitingSince
local lastSearchRan
local pendingRefreshPrompt
local lastOurRefreshAt = 0
local revealResultsAt = 0
local throttleTimer
local lfgHasFocus
local REFRESH_THROTTLE = 1.5
local STUCK_REFRESH_TEXT = "Search did not finish. Press R or Refresh to search again."

local function ParseFilters(text)
	text = strlower(strtrim(text or ""))
	if text == "" then
		return {}
	end

	text = gsub(text, "[,/]", " ")
	local filters = {}
	for token in string.gmatch(text, "%S+") do
		filters[#filters + 1] = token
	end
	return filters
end

local function PlayerMatchesClassOrExpandedFilter(playerInfo, userFilters)
	if not playerInfo or not userFilters or #userFilters == 0 then
		return false
	end

	for i = 1, #userFilters do
		local token = userFilters[i]
		if FilterExpansion:Filter(token, playerInfo) then
			return true
		end
	end

	return false
end

local function ResultMatchesFilter(resultID, userFilters)
	local searchResultInfo = C_LFGList.GetSearchResultInfo(resultID)
	if not searchResultInfo or searchResultInfo.numMembers ~= 1 then
		return false
	end

	local playerInfo = C_LFGList.GetSearchResultPlayerInfo(resultID, 1)
	return PlayerMatchesClassOrExpandedFilter(playerInfo, userFilters)
end

local function ApplyFilterToResults(browseFrame)
	local userFilters = ParseFilters(classFilterBox and classFilterBox:GetText())
	if #userFilters == 0 or not browseFrame.results then
		return false
	end

	local filtered = {}
	for i = 1, #browseFrame.results do
		local resultID = browseFrame.results[i]
		if ResultMatchesFilter(resultID, userFilters) then
			filtered[#filtered + 1] = resultID
		end
	end

	browseFrame.results = filtered
	browseFrame.totalResults = #filtered
	return true
end

local function RefreshBrowseResults()
	if LFGBrowseFrame and LFGBrowseFrame.UpdateResultList and not LFGBrowseFrame.searching then
		LFGBrowseFrame:UpdateResultList()
	end
end

local function BrowseIsVisible()
	return LFGBrowseFrame and LFGBrowseFrame:IsVisible()
end

local function ClearClassFilterFocusIfNeeded()
	if not classFilterBox or not classFilterBox:HasFocus() then
		return
	end
	if classFilterBox:IsMouseOver() then
		return
	end
	if classFilterBox.clearButton and classFilterBox.clearButton:IsShown() and classFilterBox.clearButton:IsMouseOver() then
		return
	end
	classFilterBox:ClearFocus()
end

local function MarkSearchWaiting()
	if LFGBrowseFrame and LFGBrowseFrame.searching then
		searchWaitingSince = GetTime()
	end
end

local function MarkSearchFinished()
	searchWaitingSince = nil
	pendingRefreshPrompt = nil
end

local function ShowRefreshPrompt()
	pendingRefreshPrompt = true
	local label = LFGBrowseFrame and LFGBrowseFrame.NoResultsFound
	if not label then
		return
	end
	label:SetText(STUCK_REFRESH_TEXT)
	label:Show()
end

local function ClearStuckSearch()
	if not LFGBrowseFrame then
		return
	end
	LFGBrowseFrame.searching = false
	LFGBrowseFrame.searchFailed = false
	if LFGBrowseFrame.SearchingSpinner then
		LFGBrowseFrame.SearchingSpinner:Hide()
	end
	if LFGBrowseFrame.UpdateResultList then
		LFGBrowseFrame:UpdateResultList()
	end
	if LFGBrowseFrame.UpdateButtonState then
		LFGBrowseFrame:UpdateButtonState()
	end
	MarkSearchFinished()
end

local function TryRefreshOnOpen()
	if not LFGBrowseFrame or not LFGBrowseFrame.searching or not searchWaitingSince then
		return
	end
	if (GetTime() - searchWaitingSince) < 1 then
		return
	end

	lastSearchRan = false
	ClearStuckSearch()
	LFGBrowse_DoSearch()
	if lastSearchRan then
		return
	end
	ClearStuckSearch()
	ShowRefreshPrompt()
end

local function SetSpinnerLabel(text)
	local spinner = LFGBrowseFrame and LFGBrowseFrame.SearchingSpinner
	if spinner and spinner.Label then
		spinner.Label:SetText(text)
	end
end

local function ShowThrottleSpinner()
	if not LFGBrowseFrame or not LFGBrowseFrame.SearchingSpinner then
		return
	end
	SetSpinnerLabel("Throttling...")
	LFGBrowseFrame.SearchingSpinner:Show()
	if LFGBrowseFrame.NoResultsFound then
		LFGBrowseFrame.NoResultsFound:Hide()
	end
end

local function HoldingThrottle()
	return revealResultsAt > 0 and GetTime() < revealResultsAt
end

local function HoldThrottleDisplay(browseFrame)
	if not HoldingThrottle() then
		return false
	end
	if browseFrame.ScrollBox then
		browseFrame.ScrollBox:RemoveDataProvider()
	end
	ShowThrottleSpinner()
	return true
end

local function EndThrottleWait()
	throttleTimer = nil
	revealResultsAt = 0
	SetSpinnerLabel(SEARCHING)
	if LFGBrowseFrame and LFGBrowseFrame.UpdateResultList and not LFGBrowseFrame.searching then
		LFGBrowseFrame:UpdateResultList()
	elseif LFGBrowseFrame and LFGBrowseFrame.SearchingSpinner and not LFGBrowseFrame.searching then
		LFGBrowseFrame.SearchingSpinner:Hide()
	end
end

local function ScheduleThrottleEnd()
	if throttleTimer then
		throttleTimer:Cancel()
		throttleTimer = nil
	end
	local wait = revealResultsAt - GetTime()
	if wait <= 0 then
		EndThrottleWait()
		return
	end
	throttleTimer = C_Timer.NewTimer(wait, EndThrottleWait)
end

local function CancelOurRefreshThrottle()
	if throttleTimer then
		throttleTimer:Cancel()
		throttleTimer = nil
	end
	revealResultsAt = 0
	SetSpinnerLabel(SEARCHING)
	if LFGBrowseFrame and not LFGBrowseFrame.searching and LFGBrowseFrame.SearchingSpinner then
		LFGBrowseFrame.SearchingSpinner:Hide()
	end
end

local function PerformOurRefresh()
	CancelOurRefreshThrottle()
	SetSpinnerLabel(SEARCHING)
	lastSearchRan = false
	LFGBrowse_DoSearch()
	if lastSearchRan then
		lastOurRefreshAt = GetTime()
	end
end

local function RequestOurRefresh()
	if not BrowseIsVisible() or not lfgHasFocus then
		return
	end
	if GetCurrentKeyBoardFocus() then
		return
	end
	if LFGBrowseFrame and LFGBrowseFrame.searching then
		return
	end

	local wait = lastOurRefreshAt + REFRESH_THROTTLE - GetTime()
	if wait > 0 then
		revealResultsAt = lastOurRefreshAt + REFRESH_THROTTLE
		ShowThrottleSpinner()
		if LFGBrowseFrame and LFGBrowseFrame.ScrollBox then
			LFGBrowseFrame.ScrollBox:RemoveDataProvider()
		end
		ScheduleThrottleEnd()
		return
	end

	PerformOurRefresh()
end

local function HasForeignKeyboardFocus()
	local focus = GetCurrentKeyBoardFocus()
	if not focus then
		return false
	end
	if classFilterBox and focus == classFilterBox then
		return false
	end
	return true
end

local function BindRefreshKey()
	if not hotkeyOwner then
		return
	end
	if BrowseIsVisible() and lfgHasFocus and not HasForeignKeyboardFocus() then
		SetOverrideBindingClick(hotkeyOwner, true, "R", "QuickLFGRefreshHotkey")
	else
		ClearOverrideBindings(hotkeyOwner)
	end
end

local function CreateClassFilterBox(browseFrame)
	local overlay = CreateFrame("Frame", "QuickLFGOverlay", browseFrame)
	overlay:SetSize(1, 1)
	overlay:SetPoint("TOPLEFT", browseFrame, "TOPLEFT")
	overlay:EnableMouse(false)

	local box = CreateFrame("EditBox", "QuickLFGClassBox", overlay, "SearchBoxTemplate")
	box:SetAutoFocus(false)
	box:SetMaxLetters(64)
	box:SetHeight(20)
	box:SetPoint("BOTTOMLEFT", browseFrame.ActivityDropdown, "TOPLEFT", 4, 6)
	box:SetPoint("RIGHT", browseFrame.ActivityDropdown, "RIGHT", 0, 0)
	box.Instructions:SetText("Class/Role")

	box:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText("Filter by class or role")
		GameTooltip:AddLine("Separate terms with space, comma, or slash. Prefixes match.", 1, 1, 1, true)
		GameTooltip:AddLine("Example: hunt tank resto  or  sham,ret,rog", 0.8, 0.8, 0.8, true)
		GameTooltip:Show()
	end)
	box:SetScript("OnLeave", GameTooltip_Hide)
	box:SetScript("OnEnterPressed", EditBox_ClearFocus)
	box:SetScript("OnEscapePressed", function(self) 
        box:SetText("")
        SearchBoxTemplate_OnTextChanged(self)
        EditBox_ClearFocus(self)
        RefreshBrowseResults()
        end)
	box:SetScript("OnTextChanged", function(self)
		SearchBoxTemplate_OnTextChanged(self)
		RefreshBrowseResults()
	end)
	if box.clearButton then
		box.clearButton:HookScript("OnClick", RefreshBrowseResults)
	end

	classFilterBox = box

	local hint = overlay:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
	hint:SetText("Refresh key: R")
	hint:SetJustifyH("LEFT")
	hint:SetWordWrap(false)
	hint:SetPoint("LEFT", browseFrame.CategoryDropdown, "LEFT", 10, 0)
	hint:SetPoint("RIGHT", box, "LEFT", -10, 0)
	hint:SetPoint("BOTTOM", box, "BOTTOM", 0, 2)
end

local function SetupRefreshHotkey()
	hotkeyOwner = CreateFrame("Frame", "QuickLFGHotkeyOwner")

	local hotkeyButton = CreateFrame("Button", "QuickLFGRefreshHotkey", hotkeyOwner)
	hotkeyButton:RegisterForClicks("AnyDown")
	hotkeyButton:SetScript("OnClick", function()
		if not BrowseIsVisible() then
			return
		end
		if GetCurrentKeyBoardFocus() then
			return
		end
		RequestOurRefresh()
	end)
end

local function HookBrowseFrame(browseFrame)
	if hooked then
		return
	end
	hooked = true

	hooksecurefunc(browseFrame, "UpdateResults", function(self)
		if applyingFilter or self.searching then
			return
		end
		if HoldThrottleDisplay(self) then
			return
		end
		if ApplyFilterToResults(self) then
			applyingFilter = true
			self:UpdateResults()
			applyingFilter = false
		end
		if pendingRefreshPrompt then
			ShowRefreshPrompt()
		end
	end)

	hooksecurefunc("LFGBrowse_DoSearch", MarkSearchWaiting)
	if C_LFGList and C_LFGList.Search then
		hooksecurefunc(C_LFGList, "Search", function()
			lastSearchRan = true
		end)
	end

	CreateClassFilterBox(browseFrame)
	SetupRefreshHotkey()

	local function OnGroupFinderOpened()
		lfgHasFocus = true
		TryRefreshOnOpen()
		BindRefreshKey()
	end

	hooksecurefunc("ShowLFGParentFrame", OnGroupFinderOpened)
	hooksecurefunc("ToggleLFGParentFrame", function()
		if LFGParentFrame and LFGParentFrame:IsShown() then
			OnGroupFinderOpened()
		end
	end)
	hooksecurefunc("ShowUIPanel", function(frame)
		if frame == LFGParentFrame then
			OnGroupFinderOpened()
		end
	end)
	hooksecurefunc("HideUIPanel", function(frame)
		if frame == LFGParentFrame then
			lfgHasFocus = nil
			if hotkeyOwner then
				ClearOverrideBindings(hotkeyOwner)
			end
			CancelOurRefreshThrottle()
		end
	end)
	if ChatEdit_ActivateChat then
		hooksecurefunc("ChatEdit_ActivateChat", BindRefreshKey)
	end
	if ChatEdit_DeactivateChat then
		hooksecurefunc("ChatEdit_DeactivateChat", BindRefreshKey)
	end
	hooksecurefunc("LFGParentFrameTab1_OnClick", BindRefreshKey)
	hooksecurefunc("LFGParentFrameTab2_OnClick", function()
		TryRefreshOnOpen()
		BindRefreshKey()
	end)

	if browseFrame.searching then
		searchWaitingSince = GetTime()
	end
	BindRefreshKey()
end

local function TryInitBrowseFilter()
	if LFGBrowseFrame then
		HookBrowseFrame(LFGBrowseFrame)
	end
end

local function IsVanillaLFGLoaded()
	if C_AddOns and C_AddOns.IsAddOnLoaded then
		return C_AddOns.IsAddOnLoaded(VANILLA_LFG_ADDON)
	end
	return IsAddOnLoaded(VANILLA_LFG_ADDON)
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:RegisterEvent("LFG_LIST_SEARCH_RESULTS_RECEIVED")
loader:RegisterEvent("LFG_LIST_SEARCH_FAILED")
loader:RegisterEvent("GLOBAL_MOUSE_DOWN")
loader:SetScript("OnEvent", function(self, event, arg1)
	if event == "ADDON_LOADED" then
		if arg1 == ADDON_NAME or arg1 == VANILLA_LFG_ADDON then
			if IsVanillaLFGLoaded() then
				TryInitBrowseFilter()
			end
		end
	elseif event == "GLOBAL_MOUSE_DOWN" then
		ClearClassFilterFocusIfNeeded()
		if LFGParentFrame and LFGParentFrame:IsShown() then
			lfgHasFocus = LFGParentFrame:IsMouseOver()
			BindRefreshKey()
		end
	else
		MarkSearchFinished()
	end
end)