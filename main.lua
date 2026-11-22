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

-- cached data: loaded once, written to disk at most every SAVE_INTERVAL ms
local data
local dirty = false
local sinceSave = 0
local SAVE_INTERVAL = 5000

local function flush()
    if dirty and data ~= nil then
        helpers.saveData(data)
        dirty = false
        sinceSave = 0
    end
end

local function checkMoney(_, dt)

    if data == nil then data = helpers.getData() end
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

        dirty = true
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
    flush()
    -- Event Handlers
    function CANVAS:OnEvent(event, ...)
        if (event == eventName) then
            checkMoney();
        end
    end
    CANVAS:SetHandler("OnEvent", CANVAS.OnEvent)
    CANVAS:RegisterEvent(eventName);

    -- write pending changes to disk every few seconds instead of on every event
    CANVAS:SetHandler("OnUpdate", function(_, dt)
        if dirty then
            sinceSave = sinceSave + (dt or 16)
            if sinceSave >= SAVE_INTERVAL then flush() end
        end
    end)
end

local function Unload()
    if CANVAS ~= nil then
        checkMoney();
        flush()
        CANVAS:Show(false)
        CANVAS:ReleaseHandler("OnEvent")
        CANVAS:ReleaseHandler("OnUpdate")
        CANVAS = nil
    end
    UI.Unload()
end

addon.OnLoad = Load
addon.OnUnload = Unload

return addon
