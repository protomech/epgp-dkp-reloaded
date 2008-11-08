-- Call the Confirm_GP popup like this:
--
--local itemID = 34541  -- (debug)
--
--local itemName, itemLink, itemRarity, _, _, _, _, _, _, itemTexture = GetItemInfo(itemID) 
--local r, g, b = GetItemQualityColor(itemRarity);
--
--StaticPopup_Show("EPGP_CONFIRM_GP_CREDIT", "", "", {["texture"] = itemTexture, ["name"] = itemName, ["color"] = {r, g, b, 1}, ["link"] = itemLink, ["index"] = nil, ["count"] = 1});

EPGP_TEXT_CONFIRM_GP_CREDIT = "Add GP to member"

StaticPopupDialogs["EPGP_CONFIRM_GP_CREDIT"] = {
	text = EPGP_TEXT_CONFIRM_GP_CREDIT,
	button1 = "Full",
	button3 = "Offspec",
	button2 = CANCEL,
	timeout = 0,
	whileDead = 1,
	maxLetters = 16,
	hideOnEscape = 1,
	hasEditBox = 1,
	hasItemFrame = 1,
	
	OnAccept = function()
	--todo : hook it!
	end,
	
	OnCancel = function()
		self:GetParent():Hide();
		ClearCursor();
	end,
	
	OnShow = function()
		local itemFrame = getglobal(this:GetName().."ItemFrame")
		local editBox = getglobal(this:GetName().."EditBox")
		local button1 = getglobal(this:GetName().."Button1")
        
		editBox:SetText("410")
		editBox:HighlightText()
		itemFrame:SetPoint("TOPLEFT", 55, -35)
		editBox:SetPoint("TOPLEFT", itemFrame, "TOPRIGHT", 150, -10)
		button1:SetPoint("TOPRIGHT", itemFrame, "BOTTOMLEFT", 94, -6)		
	end,
	
	OnHide = function()
		if ( ChatFrameEditBox:IsShown() ) then
			ChatFrameEditBox:SetFocus();
		end
	end,
	
	EditBoxOnEnterPressed = function() 
	--todo : hook it!
	end,
	
	EditBoxOnTextChanged = function(self)
		local parent = self:GetParent();
		if ( strupper(parent.editBox:GetText()) ==  "" ) then
			parent.button1:Disable();
			parent.button3:Disable();
		else
			parent.button1:Enable();
			parent.button3:Enable();
		end
	end,
	
	EditBoxOnEscapePressed = function(self)
		self:GetParent():Hide();
		ClearCursor();
	end
}


