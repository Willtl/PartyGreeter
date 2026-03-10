PartyGreeter = PartyGreeter or {}
local addon = PartyGreeter

addon.DEFAULTS = {
    greetings = { "Hi", "Hello", "Sup" },
    groupTerms = { "guys", "folks", "everyone", "all" },
    delay = 4,
    randomDelayEnabled = false,
    delayLowerBound = 2,
    delayUpperBound = 6,
    includeRealm = false,
    includePlayerName = true,
    useInRaid = false,
}

function addon.TrimWhitespace(text)
    if type(text) ~= "string" then
        return ""
    end

    return string.match(text, "^%s*(.-)%s*$")
end

function addon.CloneList(list)
    local copy = {}
    for i, value in ipairs(list) do
        copy[i] = value
    end
    return copy
end

function addon.ParseCommaSeparatedList(value)
    local parsedItems = {}
    for item in string.gmatch(value or "", "([^,]+)") do
        local trimmedItem = addon.TrimWhitespace(item)
        if trimmedItem ~= "" then
            table.insert(parsedItems, trimmedItem)
        end
    end

    if #parsedItems == 0 then
        return nil
    end

    return parsedItems
end

function addon.ListToDisplayText(list)
    return table.concat(list, ", ")
end

local function normalizeList(value, fallback)
    if type(value) ~= "table" then
        return addon.CloneList(fallback)
    end

    local normalized = {}
    for _, item in ipairs(value) do
        local trimmedItem = addon.TrimWhitespace(item)
        if trimmedItem ~= "" then
            table.insert(normalized, trimmedItem)
        end
    end

    if #normalized == 0 then
        return addon.CloneList(fallback)
    end

    return normalized
end

function addon.NormalizeDatabase()
    PartyGreeterDB = PartyGreeterDB or {}

    local legacyKeys = {
        greetings = "greetings",
        groupTerms = "groupTerms",
        delay = "delay",
        includeRealm = "includeRealm",
        includePlayerName = "includePlayerName",
        useInRaid = "useInRaid",
    }

    for legacyKey, dbKey in pairs(legacyKeys) do
        if PartyGreeterDB[dbKey] == nil and _G[legacyKey] ~= nil then
            PartyGreeterDB[dbKey] = _G[legacyKey]
        end

        _G[legacyKey] = nil
    end

    PartyGreeterDB.greetings = normalizeList(PartyGreeterDB.greetings, addon.DEFAULTS.greetings)
    PartyGreeterDB.groupTerms = normalizeList(PartyGreeterDB.groupTerms, addon.DEFAULTS.groupTerms)

    local numericDelay = tonumber(PartyGreeterDB.delay)
    if not numericDelay then
        numericDelay = addon.DEFAULTS.delay
    end
    if numericDelay < 0 then
        numericDelay = 0
    end
    PartyGreeterDB.delay = numericDelay

    if type(PartyGreeterDB.includeRealm) ~= "boolean" then
        PartyGreeterDB.includeRealm = addon.DEFAULTS.includeRealm
    end
    if type(PartyGreeterDB.includePlayerName) ~= "boolean" then
        PartyGreeterDB.includePlayerName = addon.DEFAULTS.includePlayerName
    end
    if type(PartyGreeterDB.useInRaid) ~= "boolean" then
        PartyGreeterDB.useInRaid = addon.DEFAULTS.useInRaid
    end

    if type(PartyGreeterDB.randomDelayEnabled) ~= "boolean" then
        PartyGreeterDB.randomDelayEnabled = addon.DEFAULTS.randomDelayEnabled
    end

    local lowerBound = tonumber(PartyGreeterDB.delayLowerBound)
    if not lowerBound then
        lowerBound = addon.DEFAULTS.delayLowerBound
    end
    local upperBound = tonumber(PartyGreeterDB.delayUpperBound)
    if not upperBound then
        upperBound = addon.DEFAULTS.delayUpperBound
    end

    lowerBound = math.floor(lowerBound + 0.5)
    upperBound = math.floor(upperBound + 0.5)
    if lowerBound < 0 then
        lowerBound = 0
    end
    if upperBound < 0 then
        upperBound = 0
    end
    if lowerBound > upperBound then
        lowerBound, upperBound = upperBound, lowerBound
    end

    PartyGreeterDB.delayLowerBound = lowerBound
    PartyGreeterDB.delayUpperBound = upperBound
end

addon.optionsCategory = nil
addon.NormalizeDatabase()
