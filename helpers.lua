local api = require("api")
local defaultSettings = require('Accountant/util/default_settings')

local helpers = {}
local settings
helpers.periods = {'Day', 'Month', 'Week', 'Year', 'All time'}

local filename = 'Accountant/data.txt'

--[[
    Reads the data from the file and returns it. If the file does not exist,
    an empty table is returned.

    @return table The data from the file
]]
function helpers.getData()
    local data = api.File:Read(filename)
    if data == nil then return {} end
    return data
end

--[[
    Saves the data to the file. If the file does not exist, it will be created.
    If the file does exist, the contents will be overwritten.

    @param data table The data to be saved
]]
function helpers.saveData(data) api.File:Write(filename, data) end

--[[
    Returns a table of all saved character names
    @return table A table containing all saved character names
]]
function helpers.getSavedCharacters()
    -- Read the data from the file
    local data = helpers.getData()

    -- Create a table of all the saved character names
    local characters = {}
    for k, v in pairs(data) do table.insert(characters, k) end

    -- Return the table of character names
    return characters
end

--[[
    Returns the decimal part of a number as a string
    @param num number The number to get the decimal part from
    @return string The decimal part of the number
]]
local function getDec(num) return tostring(num):match("%.(%d+)") end

--[[
    Trims whitespace from both ends of a string
    @param s string The string to be trimmed
    @return string The trimmed string
]]
function helpers.trim(s) return (s:gsub("^%s*(.-)%s*$", "%1")) end

--[[
    Splits a string by a delimiter and returns a table of the split strings
    @param input string The string to be split
    @param delimiter string The delimiter to split the string by
    @return table A table containing the split strings
]]
function helpers.splitString(input, delimiter)
    -- Create a table to hold the split strings
    local result = {}

    -- Create a pattern to match the delimiter
    local pattern = string.format("([^%s]+)", delimiter)

    -- Iterate over the string and split it by the delimiter
    for word in string.gmatch(input, pattern) do
        -- Trim the whitespace from the split string and add it to the result
        table.insert(result, helpers.trim(word))
    end
    return result
end

--[[
    Checks if a value is in a table
    @param tbl table The table to check
    @param x any The value to check for
    @return boolean True if the value is in the table, false otherwise
]]
function helpers.table_contains(tbl, x)
    -- Create a variable to hold the result
    local found = false

    -- Iterate over the table and check if the value is present
    for _, v in pairs(tbl) do
        -- If the value is found, set the result to true
        if v == x then found = true end
    end
    -- Return the result
    return found
end

-- money things

--[[
    Gets the last saved money for a character
    @param character number The character to get the money for. 1 for all characters
    @return string The last saved money for the character. Formatted as "goldsilvercopper"
]]
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

        -- convert copper to silver and gold
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

        -- format the money string
        return allmoney.gold .. string.format("%02d", allmoney.silver) ..
                   string.format("%02d", allmoney.copper)
    else
        -- a specific character
        local characters = helpers.getSavedCharacters()
        local characterName = characters[character - 1]

        if data[characterName] == nil then return 0 end
        return data[characterName].lastSavedMoney
    end

end

--[[
    Prettify the money string from the saved data to a table
    @param money (string) The money string from the saved data
    @return (table) A table with gold, silver and copper
        gold: Gold amount
        silver: Silver amount
        copper: Copper amount
]]
function helpers.prettifyMoney(money)
    local table = {copper = 0, silver = 0, gold = 0}

    if money ~= nil then
        table.copper = tonumber(string.sub(money, -2)) or 0
        table.silver = tonumber(string.sub(money, -4, -3)) or 0
        table.gold = tonumber(string.sub(money, 0, -5)) or 0
    end

    return table
end

--[[
    Uglify the money table to a string
    @param money (table) The money table to uglify
    @return (string) The uglified money string
        The string is in the format of "goldsilvercopper"
]]
function helpers.uglifyMoney(money)
    return tostring(money.gold) .. string.format("%02d", money.silver) ..
               string.format("%02d", money.copper)
end

--[[
    Gets the settings for the addon. If a setting does not exist, it will be
    created with the default value from the defaultSettings table.

    @return table The settings for the addon
]]
function helpers.getSettings()
    local settings = api.GetSettings("Accountant")
    -- loop for set default settings if not exists
    for k, v in pairs(defaultSettings) do
        if settings[k] == nil then settings[k] = v end
    end
    return settings
end

--[[
    Updates the settings for the addon and saves them to the file.

    @return table The settings for the addon
]]
function helpers.updateSettings()
    -- Save the settings to the file
    api.SaveSettings()
    -- Log a message to say that the settings have been saved
    api.Log:Info('Accountant settings saved')
    -- Get the settings again
    local settings = helpers.getSettings()
    -- Return the settings
    return settings
end

function helpers.getDate(timestamp)
    local timestamp = timestamp or api.Time:GetLocalTime()
    local timezone_offset = settings.timezone_offset * 3600
    local localTimestamp = X2Util:StrNumericAdd(tostring(timestamp),
                                                tostring(timezone_offset))

    -- Количество секунд в сутках
    local secondsInADay = "86400"

    -- Вычисляем количество дней, прошедших с 1 января 1970
    local daysSinceEpoch = tonumber(X2Util:DivideNumberString(localTimestamp,
                                                              secondsInADay))
    -- Определяем год
    local year = 1970
    while daysSinceEpoch >= 365 do
        -- Проверяем високосный год
        local isLeapYear = (year % 4 == 0 and year % 100 ~= 0) or
                               (year % 400 == 0)
        local daysInYear = isLeapYear and 366 or 365

        -- Если дней хватает на целый год, вычитаем его
        if daysSinceEpoch >= daysInYear then
            daysSinceEpoch = tonumber(X2Util:StrNumericSub(tostring(
                                                               daysSinceEpoch),
                                                           tostring(daysInYear)))
            year = year + 1
        else
            break
        end
    end

    -- Определяем месяц и день
    local month = 1
    local daysInMonth = {31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31}

    -- Учитываем високосные годы
    if (year % 4 == 0 and year % 100 ~= 0) or (year % 400 == 0) then
        daysInMonth[2] = 29
    end

    while daysSinceEpoch >= daysInMonth[month] do
        daysSinceEpoch = tonumber(X2Util:StrNumericSub(tostring(daysSinceEpoch),
                                                       tostring(
                                                           daysInMonth[month])))
        month = month + 1
    end

    local day = X2Util:StrNumericAdd(tostring(daysSinceEpoch), "1") -- Дни считаются с 0, поэтому +1

    -- Вычисляем часы, минуты, секунды
    local fullDaysInSeconds = X2Util:StrIntegerMul(
                                  X2Util:DivideNumberString(localTimestamp,
                                                            secondsInADay),
                                  secondsInADay)
    local remainingSeconds = X2Util:StrNumericSub(localTimestamp,
                                                  fullDaysInSeconds)

    local hours = X2Util:DivideNumberString(remainingSeconds, "3600")
    local hoursInSeconds = X2Util:StrIntegerMul(hours, "3600")

    local minutes = X2Util:DivideNumberString(
                        X2Util:StrNumericSub(remainingSeconds, hoursInSeconds),
                        "60")
    local minutesInSeconds = X2Util:StrIntegerMul(minutes, "60")

    local seconds = X2Util:StrNumericSub(
                        X2Util:StrNumericSub(remainingSeconds, hoursInSeconds),
                        minutesInSeconds)

    local weekday = (tonumber(daysSinceEpoch) + 4) % 7

    -- Посчитаем день в году
    local dayOfYear = 0
    for m = 1, month - 1 do dayOfYear = dayOfYear + daysInMonth[m] end
    dayOfYear = dayOfYear + tonumber(day)

    -- Определяем день недели 1 января
    local jan1Weekday = (weekday - (dayOfYear % 7) + 7) % 7 -- День недели 1 января

    -- ISO-нумерация недель (первая неделя начинается с понедельника)
    local weekNumber = math.floor((dayOfYear + jan1Weekday - 1) / 7) + 1

    return {
        year = year,
        month = month,
        day = tonumber(day),
        hours = tonumber(hours),
        minutes = tonumber(minutes),
        seconds = tonumber(seconds),
        weekday = weekday,
        weekNumber = weekNumber, -- Номер недели
        dayOfYear = dayOfYear
    }

end

function helpers.getAllChanges(character)
    local data = helpers.getData()
    local changes = {}
    local characters = helpers.getSavedCharacters()
    local characterName = characters[character]
    changes = data[characterName].changes
    return changes
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
    local date = helpers.getDate()

    -- filtering by period
    if periodName == nil then periodName = 'Day' end
    for k, v in pairs(changes) do
        local split = helpers.splitString(v, '|')
        local timestamp = split[1]
        local currency = split[2]
        local logDate = helpers.getDate(timestamp)
        if periodName == 'Day' and logDate.year == date.year and logDate.month ==
            date.month then
            if logDate.day == date.day then
                table.insert(filteredChanges, v)
            end
        end
        if periodName == 'Month' then
            if logDate.month == date.month and logDate.year == date.year then
                table.insert(filteredChanges, v)
            end
        end
        if periodName == 'Week' then
            if logDate.weekNumber == date.weekNumber and logDate.year ==
                date.year then table.insert(filteredChanges, v) end
        end
        if periodName == 'Year' then
            if logDate.year == date.year then
                table.insert(filteredChanges, v)
            end
        end
        if periodName == 'All time' then table.insert(filteredChanges, v) end
    end

    return filteredChanges
end

function helpers.indexOf(array, value)
    for i, v in ipairs(array) do if v == value then return i end end
    return nil
end

function helpers.calcProfits(character, period)
    settings = helpers.getSettings()
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
        local allChanges = helpers.getAllChanges(characterIndex)
        local prevCurrency
        for k, v in pairs(changes) do
            local split = helpers.splitString(v, '|')
            local currency = helpers.prettifyMoney(split[2])

            if prevCurrency == nil then
                local index = helpers.indexOf(allChanges, v)
                if index > 1 then
                    local prevSplit = helpers.splitString(allChanges[index - 1],
                                                          '|')
                    prevCurrency = helpers.prettifyMoney(prevSplit[2])
                else
                    prevCurrency = currency
                end

            end

            local isProfit = false
            local comparsion = X2Util:CompareMoneyString(
                                   helpers.uglifyMoney(currency),
                                   helpers.uglifyMoney(prevCurrency))
            if (comparsion > 0) then isProfit = true end

            local diffStr = X2Util:StrNumericSub(helpers.uglifyMoney(currency),
                                                 helpers.uglifyMoney(
                                                     prevCurrency))
            local diff = helpers.prettifyMoney(diffStr)
            diff.gold = math.abs(diff.gold)
            diff.silver = math.abs(diff.silver)
            diff.copper = math.abs(diff.copper)

            if fetched[characterIndex] == nil then
                fetched[characterIndex] = {
                    revenue = {copper = 0, silver = 0, gold = 0},
                    expenditures = {copper = 0, silver = 0, gold = 0},
                    netprofit = {copper = 0, silver = 0, gold = 0}
                }
            end

            if isProfit then
                fetched[characterIndex].revenue.copper =
                    fetched[characterIndex].revenue.copper + diff.copper
                fetched[characterIndex].revenue.silver =
                    fetched[characterIndex].revenue.silver + diff.silver
                fetched[characterIndex].revenue.gold =
                    fetched[characterIndex].revenue.gold + diff.gold
            else
                fetched[characterIndex].expenditures.copper =
                    fetched[characterIndex].expenditures.copper + diff.copper
                fetched[characterIndex].expenditures.silver =
                    fetched[characterIndex].expenditures.silver + diff.silver
                fetched[characterIndex].expenditures.gold =
                    fetched[characterIndex].expenditures.gold + diff.gold
            end

            prevCurrency = currency

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
        local div = profits.revenue.copper / 100
        local extra = math.floor(div)
        profits.revenue.silver = profits.revenue.silver + extra
        profits.revenue.copper = getDec(string.format('%.2f', div))
    end

    if profits.expenditures.copper >= 100 then
        local div = profits.expenditures.copper / 100
        local extra = math.floor(div)
        profits.expenditures.silver = profits.expenditures.silver + extra
        profits.expenditures.copper = getDec(string.format('%.2f', div))
    end

    if profits.revenue.silver >= 100 then
        local div = profits.revenue.silver / 100
        local extra = math.floor(div)
        profits.revenue.gold = profits.revenue.gold + extra
        profits.revenue.silver = getDec(string.format('%.2f', div))
    end

    if profits.expenditures.silver >= 100 then
        local div = profits.expenditures.silver / 100
        local extra = math.floor(div)
        profits.expenditures.gold = profits.expenditures.gold + extra
        profits.expenditures.silver = getDec(string.format('%.2f', div))
    end

    local revStr = helpers.uglifyMoney(profits.revenue)
    local expStr = helpers.uglifyMoney(profits.expenditures)
    local comparsion = X2Util:CompareMoneyString(revStr, expStr)
    local profitDiff = helpers.prettifyMoney(
                           X2Util:StrNumericSub(revStr, expStr))

    -- format numbers for pretty view
    profits.revenue.copper = string.format("%02d", profits.revenue.copper)
    profits.revenue.silver = string.format("%02d", profits.revenue.silver)

    profits.expenditures.copper = string.format("%02d",
                                                profits.expenditures.copper)
    profits.expenditures.silver = string.format("%02d",
                                                profits.expenditures.silver)

    profitDiff.copper = string.format('%02d', profitDiff.copper)
    profitDiff.silver = string.format('%02d', profitDiff.silver)

    profits.netprofit = profitDiff

    if comparsion > 0 then
        profits.netprofit.isProfit = true
    else
        profits.netprofit.isProfit = false
    end

    return profits
end

return helpers
