local api = require("api")
local helpers = require("Accountant/helpers")

local CANVAS
local bagButton
local uiShowed = false
local WINDOW
local paddingX = 15
local characterSelectOptions = {'All Chars'}
local reactiveElements = {}

local GOLD = 1
local SILVER = 2
local COPPER = 3
local iconNames = {
    {"gold", "aapointGold"}, {"silver", "aapointSilver"},
    {"copper", "aapointCopper"}
}

-- helpers
local function createButton(id, parent, text, x, y)
    local button = api.Interface:CreateWidget('button', id, parent)
    button:AddAnchor("TOPLEFT", x, y)
    button:SetExtent(55, 25)
    button:SetText(text)
    api.Interface:ApplyButtonSkin(button, BUTTON_BASIC.DEFAULT)
    return button
end
function DefaultTooltipSetting(widget)
    ApplyTextColor(widget, FONT_COLOR.SOFT_BROWN)
    widget:SetInset(10, 10, 10, 10)
    widget:SetLineSpace(4)
    widget.style:SetSnap(true)
end
local function createTooltip(id, parent, text, x, y)
    local tooltip = api.Interface:CreateWidget("gametooltip", id, parent)
    tooltip:AddAnchor("TOPLEFT", x, y)
    tooltip:EnablePick(false)
    tooltip:Show(false)
    DefaultTooltipSetting(tooltip)
    tooltip:SetInset(7, 7, 7, 7)
    tooltip.bg = tooltip:CreateNinePartDrawable('ui/common_new/default.dds',
                                                "background")
    tooltip.bg:SetTextureInfo("tooltip")
    tooltip.bg:AddAnchor("TOPLEFT", tooltip, 0, 0)
    tooltip.bg:AddAnchor("BOTTOMRIGHT", tooltip, 0, 0)
    tooltip:SetInset(10, 10, 10, 10)
    tooltip:ClearLines()
    tooltip:AddLine(text, "", 0, "left", ALIGN.LEFT, 0)
    return tooltip
end
local function createComboBox(parent, values, x, y)
    local dropdownBtn = W_CTRL.CreateComboBox(parent)
    dropdownBtn:AddAnchor("TOPLEFT", parent, x, y)
    dropdownBtn:SetExtent(200, 25)
    dropdownBtn.dropdownItem = values
    return dropdownBtn
end
local function createLabel(id, parent, text, x, y, fontSize)
    local label = api.Interface:CreateWidget('label', id, parent)
    label:AddAnchor("TOPLEFT", x, y)
    label:SetExtent(255, 20)
    label:SetText(text)
    label.style:SetColor(FONT_COLOR.TITLE[1], FONT_COLOR.TITLE[2],
                         FONT_COLOR.TITLE[3], 1)
    label.style:SetAlign(ALIGN.LEFT)
    label.style:SetFontSize(fontSize or 18)

    return label
end

local function createEdit(id, parent, text, x, y)
    local field = W_CTRL.CreateEdit(id, parent)
    field:SetExtent(255, 25)
    field:AddAnchor("TOPLEFT", x, y)
    field:SetText(tostring(text))
    field.style:SetColor(0, 0, 0, 1)
    field.style:SetAlign(ALIGN.LEFT)
    -- field:SetDigit(true)
    field:SetInitVal(text)
    field:SetMaxTextLength(4)
    return field
end

local CreateMoneyEdit = function(id, parent)
    local edit = W_CTRL.CreateEdit(id, parent)
    edit:SetStyle("blue")
    edit:SetInset(5, 7, 20, 7)
    edit.style:SetAlign(ALIGN.RIGHT)
    edit.style:SetSnap(true)
    edit:SetText("0")
    edit:SetDigit(true)
    edit.minValue = 0
    edit.maxValue = 100000000
    edit.lastChar = "0"
    edit.lastMsg = "0"
    return edit
end

-- main UI
local function updateElements()
    local selectedCharacter =
        reactiveElements.characterSelect:GetSelectedIndex()
    local lastMoneySaved = helpers.prettifyMoney(
                               helpers.getLastSavedMoney(selectedCharacter))
    reactiveElements.goldEdit:SetText(tostring(lastMoneySaved.gold))
    reactiveElements.silverEdit:SetText(tostring(lastMoneySaved.silver))
    reactiveElements.copperEdit:SetText(tostring(lastMoneySaved.copper))

    local period = reactiveElements.periodSelect:GetSelectedIndex()
    local profits = helpers.calcProfits(selectedCharacter, period)

    reactiveElements.revenueGoldEdit:SetText(tostring(profits.revenue.gold))
    reactiveElements.revenueSilverEdit:SetText(tostring(profits.revenue.silver))
    reactiveElements.revenueCopperEdit:SetText(tostring(profits.revenue.copper))

    reactiveElements.expendituresGoldEdit:SetText(tostring(
                                                      profits.expenditures.gold))
    reactiveElements.expendituresSilverEdit:SetText(tostring(
                                                        profits.expenditures
                                                            .silver))
    reactiveElements.expendituresCopperEdit:SetText(tostring(
                                                        profits.expenditures
                                                            .copper))

    reactiveElements.netprofitGoldEdit:SetText(tostring(profits.netprofit.gold))
    reactiveElements.netprofitSilverEdit:SetText(
        tostring(profits.netprofit.silver))
    reactiveElements.netprofitCopperEdit:SetText(
        tostring(profits.netprofit.copper))

    if profits.netprofit.isProfit then
        reactiveElements.profitLabel.style:SetColor(0.0157, 0.7333, 0.1412, 1)
        reactiveElements.profitLabel:SetText('Net profit')
    else
        reactiveElements.profitLabel.style:SetColor(0.878, 0.071, 0.059, 1)
        reactiveElements.profitLabel:SetText('Net loss')
    end

    -- update time on tooltip
    local month, day, year = helpers.getDate()
    reactiveElements.dateTooltip:ClearLines()
    reactiveElements.dateTooltip:AddLine('The offset starts from GMT +0', "", 0,
                                         "left", ALIGN.LEFT, 0)
    reactiveElements.dateTooltip:AddLine(
        string.format('Current date: %s.%s.%s', day, month, year), "", 0,
        "left", ALIGN.LEFT, 0)

end

local function toggleUI(state)
    if state then
        WINDOW:Show(true)
        uiShowed = true
        updateElements()
    else
        WINDOW:Show(false)
        uiShowed = false
    end
end

local function createWindow()
    WINDOW = api.Interface:CreateWindow('mainWindow', 'Accountant', 600, 275)
    WINDOW:AddAnchor("CENTER", "UIParent", 0, 0)
    WINDOW:SetHandler("OnCloseByEsc", function() toggleUI(false) end)
    function WINDOW:OnClose() toggleUI(false) end

    local paddingY = 50

    -- character select
    local savedCharacters = helpers.getSavedCharacters()
    for k, v in pairs(savedCharacters) do
        table.insert(characterSelectOptions, v)
    end

    -- what if playerName did not loaded, first time init
    if not helpers.table_contains(characterSelectOptions, CANVAS.playerInfo.name) then
        table.insert(characterSelectOptions, CANVAS.playerInfo.name)
    end

    local characterSelect = createComboBox(WINDOW, characterSelectOptions,
                                           paddingX, paddingY)
    characterSelect:Select(1)
    function characterSelect:SelectedProc() updateElements() end

    reactiveElements.characterSelect = characterSelect

    -- period
    local periodSelect = createComboBox(WINDOW, helpers.periods,
                                        (paddingX * 2) + 200, paddingY)
    periodSelect:Select(1)
    function periodSelect:SelectedProc() updateElements() end
    reactiveElements.periodSelect = periodSelect

    -- timezone
    local timezoneLabel = createLabel('timezoneLabel', WINDOW, 'Timezone:',
                                      paddingX + 420, paddingY, 14)
    local timezoneEdit = createEdit('timezoneEdit', WINDOW, '', paddingX + 490,
                                    paddingY)
    timezoneEdit:SetExtent(50, 25)
    timezoneEdit:SetMaxTextLength(3)
    timezoneEdit:SetText(tostring(CANVAS.settings.timezone_offset))

    local dateTooltip = createTooltip('dateTooltip', timezoneEdit, '', -25, 30)

    function timezoneEdit.OnEnter(self)
        dateTooltip:Show(true)
        updateElements()
    end
    timezoneEdit:SetHandler("OnEnter", timezoneEdit.OnEnter)
    function timezoneEdit.OnLeave(self) dateTooltip:Show(false) end
    timezoneEdit:SetHandler("OnLeave", timezoneEdit.OnLeave)

    reactiveElements.timezoneEdit = timezoneEdit
    reactiveElements.dateTooltip = dateTooltip

    paddingY = 85
    -- money
    createLabel('goldLabel', WINDOW, 'Last record:', paddingX, paddingY, 16)

    local goldEdit = CreateMoneyEdit('goldEdit', WINDOW)
    goldEdit:AddAnchor("TOPLEFT", 150, paddingY)
    goldEdit:SetExtent(125, 25)
    goldEdit:SetMaxTextLength(6)
    local goldIcon = W_ICON.DrawMoneyIcon(goldEdit, iconNames[GOLD][1])
    goldIcon:AddAnchor("RIGHT", goldEdit, -3, 0)
    goldEdit.goldIcon = goldIcon
    goldEdit:SetEnable(false)
    goldEdit:SetReadOnly(true)
    goldEdit:SetText('0')
    reactiveElements.goldEdit = goldEdit

    local silverEdit = CreateMoneyEdit('silverEdit', WINDOW)
    silverEdit:AddAnchor("TOPLEFT", 285, paddingY)
    silverEdit:SetExtent(75, 25)
    silverEdit:SetMaxTextLength(2)
    local silverIcon = W_ICON.DrawMoneyIcon(silverEdit, iconNames[SILVER][1])
    silverIcon:AddAnchor("RIGHT", silverEdit, -3, 0)
    silverEdit.silverIcon = silverIcon
    silverEdit:SetEnable(false)
    silverEdit:SetReadOnly(true)
    silverEdit:SetText('0')
    reactiveElements.silverEdit = silverEdit

    local copperEdit = CreateMoneyEdit('copperEdit', WINDOW)
    copperEdit:AddAnchor("TOPLEFT", 370, paddingY)
    copperEdit:SetExtent(75, 25)
    copperEdit:SetMaxTextLength(2)
    local copperIcon = W_ICON.DrawMoneyIcon(copperEdit, iconNames[COPPER][1])
    copperIcon:AddAnchor("RIGHT", copperEdit, -3, 0)
    copperEdit.copperIcon = copperIcon
    copperEdit:SetEnable(false)
    copperEdit:SetReadOnly(true)
    copperEdit:SetText('0')
    reactiveElements.copperEdit = copperEdit

    -- calcs
    paddingY = 125
    createLabel('revenue', WINDOW, 'Revenue:', paddingX, paddingY, 16)

    local revenueGoldEdit = CreateMoneyEdit('revenueGoldEdit', WINDOW)
    revenueGoldEdit:AddAnchor("TOPLEFT", 150, paddingY)
    revenueGoldEdit:SetExtent(125, 25)
    revenueGoldEdit:SetMaxTextLength(6)
    local goldIcon = W_ICON.DrawMoneyIcon(revenueGoldEdit, iconNames[GOLD][1])
    goldIcon:AddAnchor("RIGHT", revenueGoldEdit, -3, 0)
    revenueGoldEdit.goldIcon = goldIcon
    revenueGoldEdit:SetEnable(false)
    revenueGoldEdit:SetReadOnly(true)
    revenueGoldEdit:SetText('0')
    reactiveElements.revenueGoldEdit = revenueGoldEdit

    local revenueSilverEdit = CreateMoneyEdit('revenueSilverEdit', WINDOW)
    revenueSilverEdit:AddAnchor("TOPLEFT", 285, paddingY)
    revenueSilverEdit:SetExtent(75, 25)
    revenueSilverEdit:SetMaxTextLength(2)
    local silverIcon = W_ICON.DrawMoneyIcon(revenueSilverEdit,
                                            iconNames[SILVER][1])
    silverIcon:AddAnchor("RIGHT", revenueSilverEdit, -3, 0)
    revenueSilverEdit.silverIcon = silverIcon
    revenueSilverEdit:SetEnable(false)
    revenueSilverEdit:SetReadOnly(true)
    revenueSilverEdit:SetText('0')
    reactiveElements.revenueSilverEdit = revenueSilverEdit

    local revenueCopperEdit = CreateMoneyEdit('revenueCopperEdit', WINDOW)
    revenueCopperEdit:AddAnchor("TOPLEFT", 370, paddingY)
    revenueCopperEdit:SetExtent(75, 25)
    revenueCopperEdit:SetMaxTextLength(2)
    local copperIcon = W_ICON.DrawMoneyIcon(revenueCopperEdit,
                                            iconNames[COPPER][1])
    copperIcon:AddAnchor("RIGHT", revenueCopperEdit, -3, 0)
    revenueCopperEdit.copperIcon = copperIcon
    revenueCopperEdit:SetEnable(false)
    revenueCopperEdit:SetReadOnly(true)
    revenueCopperEdit:SetText('0')
    reactiveElements.revenueCopperEdit = revenueCopperEdit

    paddingY = 160
    createLabel('expenditures', WINDOW, 'Expenditures:', paddingX, paddingY, 16)

    local expendituresGoldEdit = CreateMoneyEdit('expendituresGoldEdit', WINDOW)
    expendituresGoldEdit:AddAnchor("TOPLEFT", 150, paddingY)
    expendituresGoldEdit:SetExtent(125, 25)
    expendituresGoldEdit:SetMaxTextLength(6)
    local goldIcon = W_ICON.DrawMoneyIcon(expendituresGoldEdit,
                                          iconNames[GOLD][1])
    goldIcon:AddAnchor("RIGHT", expendituresGoldEdit, -3, 0)
    expendituresGoldEdit.goldIcon = goldIcon
    expendituresGoldEdit:SetEnable(false)
    expendituresGoldEdit:SetReadOnly(true)
    expendituresGoldEdit:SetText('0')
    reactiveElements.expendituresGoldEdit = expendituresGoldEdit

    local expendituresSilverEdit = CreateMoneyEdit('expendituresSilverEdit',
                                                   WINDOW)
    expendituresSilverEdit:AddAnchor("TOPLEFT", 285, paddingY)
    expendituresSilverEdit:SetExtent(75, 25)
    expendituresSilverEdit:SetMaxTextLength(2)
    local silverIcon = W_ICON.DrawMoneyIcon(expendituresSilverEdit,
                                            iconNames[SILVER][1])
    silverIcon:AddAnchor("RIGHT", expendituresSilverEdit, -3, 0)
    expendituresSilverEdit.silverIcon = silverIcon
    expendituresSilverEdit:SetEnable(false)
    expendituresSilverEdit:SetReadOnly(true)
    expendituresSilverEdit:SetText('0')
    reactiveElements.expendituresSilverEdit = expendituresSilverEdit

    local expendituresCopperEdit = CreateMoneyEdit('expendituresCopperEdit',
                                                   WINDOW)
    expendituresCopperEdit:AddAnchor("TOPLEFT", 370, paddingY)
    expendituresCopperEdit:SetExtent(75, 25)
    expendituresCopperEdit:SetMaxTextLength(2)
    local copperIcon = W_ICON.DrawMoneyIcon(expendituresCopperEdit,
                                            iconNames[COPPER][1])
    copperIcon:AddAnchor("RIGHT", expendituresCopperEdit, -3, 0)
    expendituresCopperEdit.copperIcon = copperIcon
    expendituresCopperEdit:SetEnable(false)
    expendituresCopperEdit:SetReadOnly(true)
    expendituresCopperEdit:SetText('0')
    reactiveElements.expendituresCopperEdit = expendituresCopperEdit

    paddingY = 195
    local netProfitLabel = createLabel('netprofit', WINDOW, 'Net profit:',
                                       paddingX, paddingY, 16)
    reactiveElements.profitLabel = netProfitLabel

    local netprofitGoldEdit = CreateMoneyEdit('netprofitGoldEdit', WINDOW)
    netprofitGoldEdit:AddAnchor("TOPLEFT", 150, paddingY)
    netprofitGoldEdit:SetExtent(125, 25)
    netprofitGoldEdit:SetMaxTextLength(6)
    local goldIcon = W_ICON.DrawMoneyIcon(netprofitGoldEdit, iconNames[GOLD][1])
    goldIcon:AddAnchor("RIGHT", netprofitGoldEdit, -3, 0)
    netprofitGoldEdit.goldIcon = goldIcon
    netprofitGoldEdit:SetEnable(false)
    netprofitGoldEdit:SetReadOnly(true)
    netprofitGoldEdit:SetText('0')
    reactiveElements.netprofitGoldEdit = netprofitGoldEdit

    local netprofitSilverEdit = CreateMoneyEdit('netprofitSilverEdit', WINDOW)
    netprofitSilverEdit:AddAnchor("TOPLEFT", 285, paddingY)
    netprofitSilverEdit:SetExtent(75, 25)
    netprofitSilverEdit:SetMaxTextLength(2)
    local silverIcon = W_ICON.DrawMoneyIcon(netprofitSilverEdit,
                                            iconNames[SILVER][1])
    silverIcon:AddAnchor("RIGHT", netprofitSilverEdit, -3, 0)
    netprofitSilverEdit.silverIcon = silverIcon
    netprofitSilverEdit:SetEnable(false)
    netprofitSilverEdit:SetReadOnly(true)
    netprofitSilverEdit:SetText('0')
    reactiveElements.netprofitSilverEdit = netprofitSilverEdit

    local netprofitCopperEdit = CreateMoneyEdit('netprofitCopperEdit', WINDOW)
    netprofitCopperEdit:AddAnchor("TOPLEFT", 370, paddingY)
    netprofitCopperEdit:SetExtent(75, 25)
    netprofitCopperEdit:SetMaxTextLength(2)
    local copperIcon = W_ICON.DrawMoneyIcon(netprofitCopperEdit,
                                            iconNames[COPPER][1])
    copperIcon:AddAnchor("RIGHT", netprofitCopperEdit, -3, 0)
    netprofitCopperEdit.copperIcon = copperIcon
    netprofitCopperEdit:SetEnable(false)
    netprofitCopperEdit:SetReadOnly(true)
    netprofitCopperEdit:SetText('0')
    reactiveElements.netprofitCopperEdit = netprofitCopperEdit

    -- save button
    local saveButton = createButton('saveButton', WINDOW, 'Save', 0, 0)
    saveButton:AddAnchor("TOPLEFT", WINDOW, "BOTTOMLEFT", paddingX, -45)
    if not saveButton:HasHandler("OnClick") then
        saveButton:SetHandler("OnClick", function()
            local newTimezone =
                tonumber(reactiveElements.timezoneEdit:GetText()) or 0
            reactiveElements.timezoneEdit:SetText(tostring(newTimezone))
            CANVAS.settings.timezone_offset = newTimezone
            helpers.updateSettings()
            updateElements()
        end)
    end

end

local function createMainButton()
    local bagMngr = ADDON:GetContent(UIC.BAG)
    bagButton = createButton('bagButton', bagMngr, 'Accountant', paddingX, 10)
    function bagButton:OnClick() toggleUI(not uiShowed) end
    bagButton:SetHandler("OnClick", bagButton.OnClick)
end

local lastUpdate = 0
local function updateWindow(_, dt)
    lastUpdate = lastUpdate + dt
    if lastUpdate < 5000 then return end
    lastUpdate = dt
    updateElements()

end

local ui = {}
function ui.Load(cnv)
    CANVAS = cnv
    CANVAS.settings = helpers.getSettings()
    createMainButton()
    createWindow()
    WINDOW:SetHandler("OnUpdate", updateWindow)
end

function ui.Unload()
    if CANVAS ~= nil then
        CANVAS:Show(false)
        CANVAS = nil
    end
    if bagButton ~= nil then
        bagButton:Show(false)
        bagButton = nil
    end
    if WINDOW ~= nil then
        WINDOW:Show(false)
        WINDOW = nil
    end
end

return ui
