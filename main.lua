local api = require("api")
local UI = require('Accountant/ui')
local helpers = require('Accountant/helpers')

local addon = {
    name = "Accountant",
    author = "Misosoup",
    desc = "Tracking gold",
    version = "0.1"
}

local CANVAS
local lastUpdate = 0
local playerId = api.Unit:GetUnitId('player')
local playerInfo = api.Unit:GetUnitInfoById(playerId)

local function checkMoney(_, dt)
    lastUpdate = lastUpdate + dt
    if lastUpdate < 5000 then return end
    -- 

    local data = helpers.getData()
    local curMoney = X2Util.GetMyMoneyString()

    -- saving money with timestamp if it changed
    if data[playerInfo.name] == nil then data[playerInfo.name] = {} end

    if (data[playerInfo.name].lastSavedMoney ~= curMoney) then
        data[playerInfo.name].lastSavedMoney = curMoney

        if data[playerInfo.name].changes == nil then
            data[playerInfo.name].changes = {}
        end
        table.insert(data[playerInfo.name].changes,
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
