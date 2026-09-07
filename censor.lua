local idCounter = 0;

hooksecurefunc("LFGBrowseSearchEntry_Update", function(self)
	idCounter = idCounter + 1;
	local searchResultInfo = C_LFGList.GetSearchResultInfo(self.resultID);
	if not searchResultInfo or searchResultInfo.numMembers ~= 1 then
		local leaderInfo = C_LFGList.GetSearchResultLeaderInfo(self.resultID);
		self.Name:SetText(leaderInfo.classFilename .. idCounter);
		return
	end
	local memberInfo = C_LFGList.GetSearchResultPlayerInfo(self.resultID, 1);
	self.Name:SetText(memberInfo.classFilename .. idCounter);
end)

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

hooksecurefunc(Menu, "PopulateDescription", function(_, _, rootDescription)
	if not IsSearchEntryMenu(rootDescription) then
		return
	end

	-- AddInitializer repaints the text or something
	for _, elem in rootDescription:EnumerateElementDescriptions() do
		local censored = "Playername" .. idCounter
		MenuUtil.SetElementText(elem, censored)
		elem:AddInitializer(function(frame, description)
			local text = MenuUtil.GetElementText(description)
			if frame.fontString then
				frame.fontString:SetTextToFit(text or "")
			end
		end)
		break
	end

    idCounter = idCounter + 1
end)
