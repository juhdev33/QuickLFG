QuickLFG = QuickLFG or {}

local copyFrame
local copyEditBox
local closeButton
local detailsButton

local function SetDetailsOption(buttonText, onAddDetails)
	copyFrame.onAddDetails = onAddDetails
	copyFrame.buttonText = buttonText
	if onAddDetails then
		closeButton:SetSize(96, 22)
		closeButton:ClearAllPoints()
		closeButton:SetPoint("BOTTOM", -64, 18)
		detailsButton:SetText(buttonText)
		detailsButton:Show()
	else
		closeButton:SetSize(128, 32)
		closeButton:ClearAllPoints()
		closeButton:SetPoint("BOTTOM", 0, 16)
		detailsButton:Hide()
	end
end

local function CreateCopyFrame()
	copyFrame = CreateFrame("Frame", "QuickLFGCopyFrame", UIParent, "DialogBoxFrame")
	copyFrame:SetSize(420, 120)
	copyFrame:SetPoint("CENTER")
	copyFrame:SetMovable(true)
	copyFrame:EnableMouse(true)
	copyFrame:SetClampedToScreen(true)
	copyFrame:RegisterForDrag("LeftButton")
	copyFrame:SetScript("OnDragStart", copyFrame.StartMoving)
	copyFrame:SetScript("OnDragStop", copyFrame.StopMovingOrSizing)

	closeButton = _G[copyFrame:GetName() .. "Button"]
	if closeButton then
		closeButton:SetText("Close")
	end

	local title = copyFrame:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	title:SetPoint("TOP", 0, -16)
	title:SetText("Copy URL")

	local scroll = CreateFrame("ScrollFrame", nil, copyFrame, "UIPanelScrollFrameTemplate")
	scroll:SetPoint("TOPLEFT", 16, -40)
	scroll:SetPoint("BOTTOMRIGHT", -36, 52)

	copyEditBox = CreateFrame("EditBox", nil, scroll)
	copyEditBox:SetMultiLine(true)
	copyEditBox:SetAutoFocus(true)
	copyEditBox:EnableMouse(true)
	copyEditBox:SetFontObject(ChatFontNormal)
	copyEditBox:SetSize(410, 60)
	copyEditBox:SetScript("OnEscapePressed", function()
		copyFrame:Hide()
	end)
	copyEditBox:SetScript("OnTextChanged", function(self)
		self:HighlightText()
	end)

	scroll:SetScrollChild(copyEditBox)

	detailsButton = CreateFrame("Button", nil, copyFrame, "UIPanelButtonTemplate")
	detailsButton:SetSize(120, 22)
	detailsButton:SetPoint("BOTTOM", 64, 18)
	detailsButton:SetText("Not Set")
	detailsButton:SetScript("OnClick", function()
		local callback = copyFrame.onAddDetails
		copyFrame:Hide()
		if callback then
			callback()
		end
	end)
	detailsButton:Hide()
end

function QuickLFG.ShowCopyFrame(text, buttonText, onAddDetails)
	if not copyFrame then
		CreateCopyFrame()
	end
	SetDetailsOption(buttonText, onAddDetails)
	copyEditBox:SetText(text or "")
	copyFrame:Show()
	copyEditBox:SetFocus()
	copyEditBox:HighlightText()
end
