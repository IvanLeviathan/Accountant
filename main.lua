local api = require("api")
local UI = require('Accountant/ui')
local helpers = require('Accountant/helpers')

local addon = {
    name = "Accountant",
    author = "Misosoup",
    desc = "Tracking gold",
    version = "0.3.6"
}

local CANVAS
local lastUpdate = 0
local playerId = api.Unit:GetUnitId('player')

local function checkMoney(_, dt)
    lastUpdate = lastUpdate + dt
    if lastUpdate < 5000 then return end
    -- 

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

    -- 
    lastUpdate = dt
end

local function Load()
    CANVAS = api.Interface:CreateEmptyWindow("Accountant")
    CANVAS:Show(true)
    CANVAS:SetHandler("OnUpdate", checkMoney)
    CANVAS.playerInfo = api.Unit:GetUnitInfoById(playerId)
    UI.Load(CANVAS)
    api.Log:Info("Loaded " .. addon.name .. " v" .. addon.version .. " by " ..
                     addon.author)
end

local function Unload()
    if CANVAS ~= nil then
        CANVAS:Show(false)
        CANVAS = nil
    end
    UI.Unload()
end

addon.OnLoad = Load
addon.OnUnload = Unload

return addon
