local api = require("api")
local UI = require('Accountant/ui')
local helpers = require('Accountant/helpers')

local addon = {
    name = "Accountant",
    author = "Misosoup",
    desc = "Tracking gold",
    version = "0.6"
}

local CANVAS
local playerId = api.Unit:GetUnitId('player')

local function checkMoney(_, dt)

    local data = helpers.getData()
    local curMoney = X2Util.GetMyMoneyString()

    -- saving money with timestamp if it changed
    if data[CANVAS.playerInfo.name] == nil then
        data[CANVAS.playerInfo.name] = {}
    end

    if (data[CANVAS.playerInfo.name].lastSavedMoney ~= curMoney) then
        data[CANVAS.playerInfo.name].lastSavedMoney = curMoney

        if data[CANVAS.playerInfo.name].changes == nil then
            data[CANVAS.playerInfo.name].changes = {}
        end
        table.insert(data[CANVAS.playerInfo.name].changes,
                     tostring(api.Time:GetLocalTime()) .. '|' .. curMoney)

        helpers.saveData(data)
    end

end

local eventName = "PLAYER_MONEY";

local function Load()
    CANVAS = api.Interface:CreateEmptyWindow("Accountant")
    CANVAS:Show(true)
    CANVAS.playerInfo = api.Unit:GetUnitInfoById(playerId)
    UI.Load(CANVAS)
    api.Log:Info("Loaded " .. addon.name .. " v" .. addon.version .. " by " ..
                     addon.author)
    checkMoney();
    -- Event Handlers
    function CANVAS:OnEvent(event, ...)
        if (event == eventName) then
            local change = unpack(arg);
            local revenue = true;
            if (change < 0) then revenue = false; end

            -- TODO REVAMP
            checkMoney();

        end
    end
    CANVAS:SetHandler("OnEvent", CANVAS.OnEvent)
    CANVAS:RegisterEvent(eventName);
end

local function Unload()
    if CANVAS ~= nil then
        checkMoney();
        CANVAS:Show(false)
        CANVAS:ReleaseHandler("OnEvent")
        CANVAS = nil
    end
    UI.Unload()
end

addon.OnLoad = Load
addon.OnUnload = Unload

return addon
