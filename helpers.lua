local api = require("api")

local helpers = {}
helpers.periods = {'Day', 'Month'}

local filename = 'Accountant/data.txt'

function helpers.getData()
    local data = api.File:Read(filename)
    if data == nil then return {} end
    return data
end
function helpers.saveData(data) api.File:Write(filename, data) end

function helpers.getSavedCharacters()
    local data = helpers.getData()
    local characters = {}
    for k, v in pairs(data) do table.insert(characters, k) end
    return characters
end

local function getDec(num) return tonumber(tostring(num):match("%.(%d+)")) end
-- trim string function 
function helpers.trim(s) return (s:gsub("^%s*(.-)%s*$", "%1")) end
function helpers.splitString(input, delimiter)
    local result = {}
    local pattern = string.format("([^%s]+)", delimiter)
    for word in string.gmatch(input, pattern) do
        table.insert(result, helpers.trim(word))
    end
    return result
end

-- money things
function helpers.getLastSavedMoney(character)
    local data = helpers.getData()
    if (character == 1) then
        -- all chars
        local allmoney = {copper = 0, silver = 0, gold = 0}
        for k, v in pairs(data) do
            local moneyTable = helpers.prettifyMoney(v.lastSavedMoney)
            allmoney.gold = allmoney.gold + moneyTable.gold
            allmoney.silver = allmoney.silver + moneyTable.silver
            allmoney.copper = allmoney.copper + moneyTable.copper
        end

        if allmoney.copper >= 100 then
            local div = allmoney.copper / 100
            local extra = math.floor(div)
            allmoney.silver = allmoney.silver + extra
            allmoney.copper = getDec(div)
        end

        if allmoney.silver >= 100 then
            local div = allmoney.silver / 100
            local extra = math.floor(div)
            allmoney.gold = allmoney.gold + extra
            allmoney.silver = getDec(div)
        end
        return allmoney.gold .. string.format("%02d", allmoney.silver) ..
                   string.format("%02d", allmoney.copper)
    else
        local characters = helpers.getSavedCharacters()
        local characterName = characters[character - 1]

        if data[characterName] == nil then return 0 end
        return data[characterName].lastSavedMoney
    end

end

function helpers.prettifyMoney(money)
    local table = {copper = 0, silver = 0, gold = 0}

    if money ~= nil then
        table.copper = tonumber(string.sub(money, -2)) or 0
        table.silver = tonumber(string.sub(money, -4, -3)) or 0
        table.gold = tonumber(string.sub(money, 0, -5)) or 0
    end

    return table
end

local getDate = function(unix)
    -- Given unix date, return string date
    local tabIndexOverflow = function(seed, table)
        for i = 1, #table do
            if seed - table[i] <= 0 then return i, seed end
            seed = seed - table[i]
        end
    end
    local unix = unix or api.Time:GetLocalTime()

    local dayCount = function(yr)
        return (yr % 4 == 0 and (yr % 100 ~= 0 or yr % 400 == 0)) and 366 or 365
    end
    local year, days, month = 1970, math.ceil(unix / 86400)
    while days >= dayCount(year) do
        days = days - dayCount(year)
        year = year + 1
    end -- Calculate year and days into that year

    month, days = tabIndexOverflow(days, {
        31, (dayCount(year) == 366 and 29 or 28), 31, 30, 31, 30, 31, 31, 30,
        31, 30, 31
    })

    return month, days, year
end

function helpers.getChangesByPeriod(character, period)
    local data = helpers.getData()
    local changes = {}
    local characters = helpers.getSavedCharacters()
    local characterName = characters[character]
    changes = data[characterName].changes

    local filteredChanges = {}

    if changes == nil then return {} end

    local periodName = helpers.periods[period]
    local month, day, year = getDate()

    -- filtering by period
    if periodName == nil then periodName = 'Day' end
    for k, v in pairs(changes) do
        local split = helpers.splitString(v, '|')
        local timestamp = split[1]
        local currency = split[2]
        local logMonth, logDay, logYear = getDate(timestamp)
        if periodName == 'Day' then
            if logDay == day then table.insert(filteredChanges, v) end
        end
        if periodName == 'Month' then
            if logMonth == month then
                table.insert(filteredChanges, v)
            end
        end
    end

    return filteredChanges
end

function helpers.calcProfits(character, period)
    local profits = {
        revenue = {copper = 0, silver = 0, gold = 0},
        expenditures = {copper = 0, silver = 0, gold = 0},
        netprofit = {copper = 0, silver = 0, gold = 0}
    }

    local needFetch = {}
    local fetched = {}

    if character == 1 then
        local characters = helpers.getSavedCharacters()
        for i = 1, #characters do table.insert(needFetch, i) end
    else
        table.insert(needFetch, character - 1)
    end

    for index, characterIndex in pairs(needFetch) do
        local changes = helpers.getChangesByPeriod(characterIndex, period)
        local prevCurrency

        for k, v in pairs(changes) do
            local split = helpers.splitString(v, '|')
            local currency = helpers.prettifyMoney(split[2])

            if prevCurrency == nil then prevCurrency = currency end

            -- calc revenue and expenditures from all changes
            local goldDiff = currency.gold - prevCurrency.gold
            local silverDiff = currency.silver - prevCurrency.silver
            local copperDiff = currency.copper - prevCurrency.copper

            prevCurrency = currency

            if fetched[characterIndex] == nil then
                fetched[characterIndex] = {
                    revenue = {copper = 0, silver = 0, gold = 0},
                    expenditures = {copper = 0, silver = 0, gold = 0},
                    netprofit = {copper = 0, silver = 0, gold = 0}
                }
            end

            if goldDiff < 0 then
                fetched[characterIndex].expenditures.gold =
                    (fetched[characterIndex].expenditures.gold or 0) +
                        math.abs(goldDiff)
            end
            if goldDiff > 0 then
                fetched[characterIndex].revenue.gold =
                    (fetched[characterIndex].revenue.gold or 0) + goldDiff
            end

            if silverDiff < 0 then
                fetched[characterIndex].expenditures.silver =
                    (fetched[characterIndex].expenditures.silver or 0) +
                        math.abs(silverDiff)
            end
            if silverDiff > 0 then
                fetched[characterIndex].revenue.silver =
                    (fetched[characterIndex].revenue.silver or 0) + silverDiff
            end

            if copperDiff < 0 then
                fetched[characterIndex].expenditures.copper =
                    (fetched[characterIndex].expenditures.copper or 0) +
                        math.abs(copperDiff)
            end
            if copperDiff > 0 then
                fetched[characterIndex].revenue.copper =
                    (fetched[characterIndex].revenue.copper or 0) + copperDiff
            end

        end
    end

    for k, v in pairs(fetched) do
        profits.revenue.copper = profits.revenue.copper + v.revenue.copper
        profits.revenue.silver = profits.revenue.silver + v.revenue.silver
        profits.revenue.gold = profits.revenue.gold + v.revenue.gold
        profits.expenditures.copper = profits.expenditures.copper +
                                          v.expenditures.copper
        profits.expenditures.silver = profits.expenditures.silver +
                                          v.expenditures.silver
        profits.expenditures.gold = profits.expenditures.gold +
                                        v.expenditures.gold
    end

    -- calc net profit
    if profits.revenue.copper >= 100 then
        profits.revenue.copper = profits.revenue.copper - 100
        profits.revenue.silver = profits.revenue.silver + 1
    end

    if profits.expenditures.copper >= 100 then
        profits.expenditures.copper = profits.expenditures.copper - 100
        profits.expenditures.silver = profits.expenditures.silver + 1
    end

    if profits.revenue.silver >= 100 then
        profits.revenue.silver = profits.revenue.silver - 100
        profits.revenue.gold = profits.revenue.gold + 1
    end

    if profits.expenditures.silver >= 100 then
        profits.expenditures.silver = profits.expenditures.silver - 100
        profits.expenditures.gold = profits.expenditures.gold + 1
    end

    profits.netprofit.gold = profits.revenue.gold - profits.expenditures.gold
    profits.netprofit.silver = math.abs(profits.revenue.silver -
                                            profits.expenditures.silver)
    profits.netprofit.copper = math.abs(profits.revenue.copper -
                                            profits.expenditures.copper)

    return profits
end

return helpers
