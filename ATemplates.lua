function ATemplates_SetTab(parent, id)
  PanelTemplates_SetTab(parent, id)
  for i=1,parent.numTabs do
  	local page = getglobal(parent:GetName().."Page"..i)
  	if i ~= id then
  		page:Hide()
  	else
  		page:Show()
  	end
  end
end

function ATemplates_SetColumnWidth(column, width)
  column:SetWidth(width)
  getglobal(column:GetName().."Middle"):SetWidth(width - 9)
end
