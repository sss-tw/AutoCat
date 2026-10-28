-- AutoCat 独立设置界面
-- 不依赖 FuBar、Dewdrop 或 Tablet，直接渲染 CatOptions.lua 中的配置表。

AutoCatSettingsUI = AutoCatSettingsUI or {}
local UI = AutoCatSettingsUI

local ROWS_PER_COLUMN = 18
local COLUMN_COUNT = 2
local PANEL_WIDTH = 930
local PANEL_HEIGHT = 680
local CONTENT_LEFT = 150
local COLUMN_WIDTH = 375
local ROW_HEIGHT = 33
local rows = {}
local categories = {}
local currentCategory = 1
local frame

local function Print(message)
	if DEFAULT_CHAT_FRAME then
		DEFAULT_CHAT_FRAME:AddMessage("|cff33AAFFAutoCat:|r " .. message)
	end
end

local function IsHidden(option)
	if not option then
		return true
	end
	if type(option.hidden) == "function" then
		return option.hidden()
	end
	return option.hidden and true or false
end

local function GetOptionName(option, fallback)
	if option and type(option.name) == "function" then
		return option.name()
	end
	if option and option.name then
		return option.name
	end
	return fallback or ""
end

local function SortedOptions(args)
	local result = {}
	if not args then
		return result
	end

	for key, option in pairs(args) do
		if not IsHidden(option) then
			local entry = { key = key, option = option }
			local inserted = false
			local order = tonumber(option.order) or 1000
			for index = 1, table.getn(result) do
				local other = result[index]
				local otherOrder = tonumber(other.option.order) or 1000
				if order < otherOrder
					or (order == otherOrder and GetOptionName(option, key) < GetOptionName(other.option, other.key)) then
					table.insert(result, index, entry)
					inserted = true
					break
				end
			end
			if not inserted then
				table.insert(result, entry)
			end
		end
	end

	return result
end

local function AddOptions(target, args, depth)
	local options = SortedOptions(args)
	for index = 1, table.getn(options) do
		local entry = options[index]
		local option = entry.option
		if option.type == "group" then
			table.insert(target, {
				type = "header",
				name = GetOptionName(option, entry.key),
				desc = option.desc,
				depth = depth
			})
			AddOptions(target, option.args, depth + 1)
		else
			table.insert(target, {
				type = option.type,
				name = GetOptionName(option, entry.key),
				desc = option.desc,
				option = option,
				depth = depth
			})
		end
	end
end

local function GetCurrentItems()
	local items = {}
	local category = categories[currentCategory]
	if category and category.option then
		AddOptions(items, category.option.args, 0)
	end
	return items
end

local function FindColumnSplit(items)
	local total = table.getn(items)
	if total <= ROWS_PER_COLUMN then
		return total
	end

	local target = math.ceil(total / COLUMN_COUNT)
	local bestSplit
	local bestDistance
	for index = 2, total do
		if items[index].type == "header" then
			local split = index - 1
			local rightCount = total - split
			if split <= ROWS_PER_COLUMN and rightCount <= ROWS_PER_COLUMN then
				local distance = math.abs(split - target)
				if not bestDistance or distance < bestDistance then
					bestSplit = split
					bestDistance = distance
				end
			end
		end
	end

	if bestSplit then
		return bestSplit
	end
	return math.min(target, ROWS_PER_COLUMN)
end

local function ShowTooltip(owner, item)
	if not item or not item.desc or item.desc == "" then
		return
	end
	GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
	GameTooltip:SetText(item.name or "", 1, 0.82, 0)
	GameTooltip:AddLine(item.desc, 0.8, 0.8, 0.8, 1)
	GameTooltip:Show()
end

local function HideTooltip()
	GameTooltip:Hide()
end

local function HideRow(row)
	row.item = nil
	row.container:Hide()
	row.header:ClearAllPoints()
	row.toggle:ClearAllPoints()
	row.slider:ClearAllPoints()
	row.dropdown:ClearAllPoints()
	row.action:ClearAllPoints()
	row.header:Hide()
	row.toggle:Hide()
	row.slider:Hide()
	row.slider.label:Hide()
	row.slider.valueText:Hide()
	row.dropdown:Hide()
	row.dropdown.label:Hide()
	row.action:Hide()
end

local function Refresh()
	if not frame then
		return
	end

	local items = GetCurrentItems()
	local splitIndex = FindColumnSplit(items)

	for index = 1, table.getn(rows) do
		HideRow(rows[index])
		local item = items[index]
		if item then
			local row = rows[index]
			local columnIndex = 0
			local rowIndex = index
			if index > splitIndex then
				columnIndex = 1
				rowIndex = index - splitIndex
			end
			row.container:ClearAllPoints()
			row.container:SetPoint(
				"TOPLEFT",
				frame,
				"TOPLEFT",
				CONTENT_LEFT + columnIndex * COLUMN_WIDTH,
				-51 - (rowIndex - 1) * ROW_HEIGHT
			)
			row.item = item
			row.container:Show()

			local indent = (item.depth or 0) * 16
			if item.type == "header" then
				row.header:SetPoint("LEFT", row.container, "LEFT", indent, 0)
				row.header:SetText("|cffFFD700" .. (item.name or "") .. "|r")
				row.header:Show()
			elseif item.type == "toggle" then
				row.toggle:SetPoint("LEFT", row.container, "LEFT", indent, 0)
				row.toggle.text:SetText(item.name or "")
				local checked = false
				if item.option and type(item.option.get) == "function" then
					checked = item.option.get() and true or false
				end
				row.toggle:SetChecked(checked)
				row.toggle:Show()
			elseif item.type == "range" then
				row.slider:SetPoint("LEFT", row.container, "LEFT", indent + 130, 0)
				row.slider.label:SetText(item.name or "")
				local minimum = tonumber(item.option.min) or 0
				local maximum = tonumber(item.option.max) or 100
				local step = tonumber(item.option.step) or 1
				local value = minimum
				if type(item.option.get) == "function" then
					value = tonumber(item.option.get()) or minimum
				end
				row.updating = true
				row.slider:SetMinMaxValues(minimum, maximum)
				row.slider:SetValueStep(step)
				row.slider:SetValue(value)
				row.slider.valueText:SetText(tostring(value))
				row.updating = false
				row.slider:Show()
				row.slider.label:Show()
				row.slider.valueText:Show()
			elseif item.type == "text" then
				local value
				if type(item.option.get) == "function" then
					value = item.option.get()
				end
				if type(item.option.validate) ~= "table" then
					row.header:SetPoint("LEFT", row.container, "LEFT", indent, 0)
					row.header:SetText((item.name or "") .. "：|cffFFFFFF" .. tostring(value or "") .. "|r")
					row.header:Show()
				else
					row.dropdown:SetPoint("LEFT", row.container, "LEFT", indent + 120, -2)
					row.dropdown.label:SetText(item.name or "")
					local display = value
					if item.option.validate[value] then
						display = item.option.validate[value]
					end
					UIDropDownMenu_SetText(display or "请选择", row.dropdown)
					row.dropdown:Show()
					row.dropdown.label:Show()
				end
			elseif item.type == "execute" then
				row.action:SetPoint("LEFT", row.container, "LEFT", indent, 0)
				row.action:SetText(item.name or "执行")
				row.action:Show()
			else
				row.header:SetPoint("LEFT", row.container, "LEFT", indent, 0)
				row.header:SetText(item.name or "")
				row.header:Show()
			end
		end
	end

	for index = 1, table.getn(categories) do
		local button = categories[index].button
		if index == currentCategory then
			button:Disable()
		else
			button:Enable()
		end
	end
end

local function CreateRow(parent, index)
	local row = {}
	row.container = CreateFrame("Frame", nil, parent)
	row.container:SetWidth(COLUMN_WIDTH - 10)
	row.container:SetHeight(31)
	row.container:SetPoint("TOPLEFT", parent, "TOPLEFT", CONTENT_LEFT, -51)

	row.header = row.container:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	row.header:SetWidth(COLUMN_WIDTH - 40)
	row.header:SetJustifyH("LEFT")

	row.toggle = CreateFrame("CheckButton", nil, row.container, "UICheckButtonTemplate")
	row.toggle:SetWidth(28)
	row.toggle:SetHeight(28)
	row.toggle.text = row.toggle:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	row.toggle.text:SetPoint("LEFT", row.toggle, "RIGHT", 4, 0)
	row.toggle.text:SetWidth(COLUMN_WIDTH - 55)
	row.toggle.text:SetJustifyH("LEFT")
	row.toggle:SetScript("OnClick", function()
		if row.item and row.item.option and type(row.item.option.set) == "function" then
			row.item.option.set(this:GetChecked() and true or false)
			Refresh()
		end
	end)

	row.slider = CreateFrame("Slider", "AutoCatSettingsSlider" .. index, row.container, "OptionsSliderTemplate")
	row.slider:SetWidth(150)
	row.slider:SetHeight(16)
	row.slider.label = row.container:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	row.slider.label:SetPoint("RIGHT", row.slider, "LEFT", -14, 0)
	row.slider.label:SetWidth(120)
	row.slider.label:SetJustifyH("RIGHT")
	row.slider.valueText = row.container:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	row.slider.valueText:SetPoint("LEFT", row.slider, "RIGHT", 12, 0)
	row.slider.valueText:SetWidth(50)
	row.slider.valueText:SetJustifyH("LEFT")
	local low = getglobal(row.slider:GetName() .. "Low")
	local high = getglobal(row.slider:GetName() .. "High")
	local text = getglobal(row.slider:GetName() .. "Text")
	if low then low:Hide() end
	if high then high:Hide() end
	if text then text:Hide() end
	row.slider:SetScript("OnValueChanged", function()
		if row.updating or not row.item or not row.item.option then
			return
		end
		local option = row.item.option
		local step = tonumber(option.step) or 1
		local value = arg1
		if step >= 1 then
			value = math.floor((value / step) + 0.5) * step
		else
			value = math.floor((value / step) + 0.5) * step
			value = tonumber(string.format("%.2f", value))
		end
		row.slider.valueText:SetText(tostring(value))
		if type(option.set) == "function" then
			option.set(value)
		end
	end)

	row.dropdown = CreateFrame("Frame", "AutoCatSettingsDropdown" .. index, row.container, "UIDropDownMenuTemplate")
	row.dropdown.label = row.container:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	row.dropdown.label:SetPoint("RIGHT", row.dropdown, "LEFT", -4, 2)
	row.dropdown.label:SetWidth(115)
	row.dropdown.label:SetJustifyH("RIGHT")
	UIDropDownMenu_SetWidth(180, row.dropdown)
	UIDropDownMenu_Initialize(row.dropdown, function()
		if not row.item or not row.item.option then
			return
		end
		local option = row.item.option
		local values = option.validate or {}
		local sorted = {}
		for value, label in pairs(values) do
			if type(value) == "number" then
				table.insert(sorted, { value = label, label = label })
			else
				table.insert(sorted, { value = value, label = label })
			end
		end
		for valueIndex = 1, table.getn(sorted) do
			for compareIndex = valueIndex + 1, table.getn(sorted) do
				if tostring(sorted[compareIndex].label) < tostring(sorted[valueIndex].label) then
					local swap = sorted[valueIndex]
					sorted[valueIndex] = sorted[compareIndex]
					sorted[compareIndex] = swap
				end
			end
		end
		for valueIndex = 1, table.getn(sorted) do
			local entry = sorted[valueIndex]
			local info = {}
			info.text = entry.label
			info.value = entry.value
			info.func = function()
				if row.item and row.item.option and type(row.item.option.set) == "function" then
					row.item.option.set(this.value)
					UIDropDownMenu_SetText(this:GetText(), row.dropdown)
					Refresh()
				end
			end
			UIDropDownMenu_AddButton(info)
		end
	end)

	row.action = CreateFrame("Button", nil, row.container, "UIPanelButtonTemplate")
	row.action:SetWidth(180)
	row.action:SetHeight(24)
	row.action:SetScript("OnClick", function()
		if row.item and row.item.option and type(row.item.option.func) == "function" then
			row.item.option.func()
			Refresh()
		end
	end)

	local tooltipControls = { row.container, row.toggle, row.slider, row.dropdown, row.action }
	for controlIndex = 1, table.getn(tooltipControls) do
		local control = tooltipControls[controlIndex]
		control:EnableMouse(true)
		control:SetScript("OnEnter", function() ShowTooltip(this, row.item) end)
		control:SetScript("OnLeave", HideTooltip)
	end

	HideRow(row)
	return row
end

local function BuildCategories()
	categories = {}
	local root = Cat and Cat.OnMenuRequest
	if not root or not root.args then
		return
	end

	local options = SortedOptions(root.args)
	for index = 1, table.getn(options) do
		local entry = options[index]
		if entry.option.type == "group" then
			local category = {
				key = entry.key,
				name = GetOptionName(entry.option, entry.key),
				option = entry.option
			}
			category.button = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
			category.button:SetWidth(118)
			category.button:SetHeight(28)
			category.button:SetPoint("TOPLEFT", frame, "TOPLEFT", 18, -55 - table.getn(categories) * 36)
			category.button:SetText(category.name)
			table.insert(categories, category)
			local categoryIndex = table.getn(categories)
			category.button.categoryIndex = categoryIndex
			category.button:SetScript("OnClick", function()
				currentCategory = this.categoryIndex
				Refresh()
			end)
		end
	end
end

local function CreateMinimapButton()
	if UI.minimapButton then
		return
	end

	AutoCatUI = AutoCatUI or {}
	local button = CreateFrame("Button", "AutoCatMinimapButton", Minimap)
	UI.minimapButton = button
	button:SetWidth(32)
	button:SetHeight(32)
	button:SetFrameStrata("HIGH")
	button:SetFrameLevel(8)
	button:SetMovable(true)
	button:EnableMouse(true)
	button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	button:RegisterForDrag("LeftButton")
	button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

	local x = tonumber(AutoCatUI.minimapX) or 54
	local y = tonumber(AutoCatUI.minimapY) or -58
	button:SetPoint("CENTER", Minimap, "CENTER", x, y)

	button.background = button:CreateTexture(nil, "BACKGROUND")
	button.background:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcons")
	button.background:SetTexCoord(0.5, 1, 0.5, 1)
	button.background:SetWidth(24)
	button.background:SetHeight(24)
	button.background:SetPoint("CENTER", 0, 0)

	button.icon = button:CreateTexture(nil, "ARTWORK")
	button.icon:SetTexture("Interface\\Icons\\Ability_Druid_CatForm")
	button.icon:SetWidth(24)
	button.icon:SetHeight(24)
	button.icon:SetPoint("CENTER", 0, 0)

	button:SetScript("OnDragStart", function()
		this.dragging = true
	end)
	button:SetScript("OnDragStop", function()
		this.dragging = false
	end)
	button:SetScript("OnUpdate", function()
		if not this.dragging then
			return
		end
		local mx, my = Minimap:GetCenter()
		local px, py = GetCursorPosition()
		local scale = UIParent:GetScale()
		mx = mx * scale
		my = my * scale
		local angle = math.atan2(py - my, px - mx)
		local newX = math.cos(angle) * 80
		local newY = math.sin(angle) * 80
		this:ClearAllPoints()
		this:SetPoint("CENTER", Minimap, "CENTER", newX, newY)
		AutoCatUI.minimapX = newX
		AutoCatUI.minimapY = newY
	end)
	button:SetScript("OnClick", function()
		UI:Toggle()
	end)
	button:SetScript("OnEnter", function()
		GameTooltip:SetOwner(this, "ANCHOR_LEFT")
		GameTooltip:SetText("|cff33AAFFAutoCat|r 设置", 1, 1, 1)
		GameTooltip:AddLine("左键/右键：打开设置画面", 0.8, 0.8, 0.8)
		GameTooltip:AddLine("拖动：移动按钮", 0.6, 0.6, 0.6)
		GameTooltip:Show()
	end)
	button:SetScript("OnLeave", HideTooltip)
	button:Show()
end

local function CreateFrameIfNeeded()
	if frame then
		return
	end

	frame = CreateFrame("Frame", "AutoCatSettingsFrame", UIParent)
	UI.frame = frame
	frame:SetWidth(PANEL_WIDTH)
	frame:SetHeight(PANEL_HEIGHT)
	frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
	frame:SetFrameStrata("DIALOG")
	frame:SetFrameLevel(20)
	frame:SetMovable(true)
	frame:EnableMouse(true)
	frame:RegisterForDrag("LeftButton")
	frame:SetBackdrop({
		bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
		edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
		tile = true,
		tileSize = 16,
		edgeSize = 16,
		insets = { left = 4, right = 4, top = 4, bottom = 4 }
	})
	frame:SetBackdropColor(0.05, 0.05, 0.1, 0.96)
	frame:SetScript("OnDragStart", function() this:StartMoving() end)
	frame:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)
	frame:Hide()
	table.insert(UISpecialFrames, "AutoCatSettingsFrame")

	local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	title:SetPoint("TOP", frame, "TOP", 0, -16)
	title:SetText("|cff33AAFFAutoCat|r 设置")

	local closeButton = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
	closeButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -4, -4)

	local divider = frame:CreateTexture(nil, "ARTWORK")
	divider:SetTexture("Interface\\Tooltips\\UI-Tooltip-Border")
	divider:SetTexCoord(0.81, 0.94, 0.5, 1)
	divider:SetVertexColor(0.5, 0.5, 0.5)
	divider:SetWidth(PANEL_WIDTH - 20)
	divider:SetHeight(3)
	divider:SetPoint("TOP", frame, "TOP", 0, -42)

	for index = 1, ROWS_PER_COLUMN * COLUMN_COUNT do
		rows[index] = CreateRow(frame, index)
	end

	BuildCategories()
end

function UI:Show()
	if not Cat or not Cat.db or not Cat.db.profile or not Cat.OnMenuRequest then
		Print("设置尚未初始化，请进入游戏后重试。")
		return
	end
	CreateFrameIfNeeded()
	Refresh()
	frame:Show()
	frame:Raise()
end

function UI:Hide()
	if frame then
		frame:Hide()
	end
end

function UI:Toggle()
	if frame and frame:IsShown() then
		self:Hide()
	else
		self:Show()
	end
end

CreateMinimapButton()

-- 兼容旧代码中用于显示插件设置的调用。
function Cat:Show()
	UI:Show()
end
