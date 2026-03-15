PartyGreeter = PartyGreeter or {}
local addon = PartyGreeter
local ADDON_NAME = "PartyGreeter"

addon.DEFAULTS = {
    greetings = { "Hi", "Hello" },
    groupTerms = { "folks", "everyone" },
    ignoredPlayers = {},
    delay = 2,
    randomDelayEnabled = true,
    delayLowerBound = 1,
    delayUpperBound = 3,
    includeRealm = false,
    includePlayerName = false,
    useInRaid = false,
    ignoreListEnabled = true,
    promptBeforeGreeting = true,
    antiRepeatEnabled = true,
    antiRepeatCooldownMinutes = 60,
    antiRepeatOncePerSession = false,
    quietModeEnabled = true,
    quietModeSuppressInCombat = true,
    quietModeSuppressDuringBossPulls = true,
    quietModeSuppressAfterKeyStart = true,
    quietModeSuppressInMatchmadeGroups = true,
}
addon.ANTI_REPEAT_HISTORY_RETENTION_SECONDS = 30 * 24 * 60 * 60

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

local function sortStringsCaseInsensitive(list)
    table.sort(list, function(left, right)
        return string.lower(left) < string.lower(right)
    end)
end

function addon.NormalizeNameList(value)
    if type(value) ~= "table" then
        return {}
    end

    local normalized = {}
    local seen = {}
    for _, item in ipairs(value) do
        local trimmedItem = addon.TrimWhitespace(item)
        if trimmedItem ~= "" then
            local lookupKey = string.lower(trimmedItem)
            if not seen[lookupKey] then
                seen[lookupKey] = true
                table.insert(normalized, trimmedItem)
            end
        end
    end

    sortStringsCaseInsensitive(normalized)
    return normalized
end

function addon.AddUniqueName(list, value)
    local normalized = addon.NormalizeNameList(list)
    local trimmedValue = addon.TrimWhitespace(value)
    if trimmedValue == "" then
        return normalized, false
    end

    local lookupKey = string.lower(trimmedValue)
    for _, item in ipairs(normalized) do
        if string.lower(item) == lookupKey then
            return normalized, false
        end
    end

    table.insert(normalized, trimmedValue)
    sortStringsCaseInsensitive(normalized)
    return normalized, true
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
    PartyGreeterDB.ignoredPlayers = addon.NormalizeNameList(PartyGreeterDB.ignoredPlayers)

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
    if type(PartyGreeterDB.ignoreListEnabled) ~= "boolean" then
        PartyGreeterDB.ignoreListEnabled = addon.DEFAULTS.ignoreListEnabled
    end
    if type(PartyGreeterDB.promptBeforeGreeting) ~= "boolean" then
        PartyGreeterDB.promptBeforeGreeting = addon.DEFAULTS.promptBeforeGreeting
    end

    if type(PartyGreeterDB.randomDelayEnabled) ~= "boolean" then
        PartyGreeterDB.randomDelayEnabled = addon.DEFAULTS.randomDelayEnabled
    end
    if type(PartyGreeterDB.antiRepeatEnabled) ~= "boolean" then
        PartyGreeterDB.antiRepeatEnabled = addon.DEFAULTS.antiRepeatEnabled
    end
    if type(PartyGreeterDB.antiRepeatOncePerSession) ~= "boolean" then
        PartyGreeterDB.antiRepeatOncePerSession = addon.DEFAULTS.antiRepeatOncePerSession
    end
    if type(PartyGreeterDB.quietModeEnabled) ~= "boolean" then
        PartyGreeterDB.quietModeEnabled = addon.DEFAULTS.quietModeEnabled
    end
    if type(PartyGreeterDB.quietModeSuppressInCombat) ~= "boolean" then
        PartyGreeterDB.quietModeSuppressInCombat = addon.DEFAULTS.quietModeSuppressInCombat
    end
    if type(PartyGreeterDB.quietModeSuppressDuringBossPulls) ~= "boolean" then
        PartyGreeterDB.quietModeSuppressDuringBossPulls = addon.DEFAULTS.quietModeSuppressDuringBossPulls
    end
    if type(PartyGreeterDB.quietModeSuppressAfterKeyStart) ~= "boolean" then
        PartyGreeterDB.quietModeSuppressAfterKeyStart = addon.DEFAULTS.quietModeSuppressAfterKeyStart
    end
    if type(PartyGreeterDB.quietModeSuppressInMatchmadeGroups) ~= "boolean" then
        PartyGreeterDB.quietModeSuppressInMatchmadeGroups = addon.DEFAULTS.quietModeSuppressInMatchmadeGroups
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

    local antiRepeatMinutes = tonumber(PartyGreeterDB.antiRepeatCooldownMinutes)
    if not antiRepeatMinutes then
        antiRepeatMinutes = addon.DEFAULTS.antiRepeatCooldownMinutes
    end
    antiRepeatMinutes = math.floor(antiRepeatMinutes + 0.5)
    if antiRepeatMinutes < 1 then
        antiRepeatMinutes = 1
    end
    if antiRepeatMinutes > 1440 then
        antiRepeatMinutes = 1440
    end
    PartyGreeterDB.antiRepeatCooldownMinutes = antiRepeatMinutes

    local now = GetServerTime()
    local retentionCutoff = now - addon.ANTI_REPEAT_HISTORY_RETENTION_SECONDS
    local normalizedGreetingHistory = {}
    if type(PartyGreeterDB.greetingHistory) == "table" then
        for guid, timestamp in pairs(PartyGreeterDB.greetingHistory) do
            local numericTimestamp = tonumber(timestamp)
            if type(guid) == "string" and guid ~= "" and numericTimestamp and numericTimestamp >= retentionCutoff then
                normalizedGreetingHistory[guid] = numericTimestamp
            end
        end
    end
    PartyGreeterDB.greetingHistory = normalizedGreetingHistory

    local normalizedSessionGreetingHistory = {}
    if type(PartyGreeterDB.sessionGreetingHistory) == "table" then
        for guid, greeted in pairs(PartyGreeterDB.sessionGreetingHistory) do
            if type(guid) == "string" and guid ~= "" and greeted then
                normalizedSessionGreetingHistory[guid] = true
            end
        end
    end
    PartyGreeterDB.sessionGreetingHistory = normalizedSessionGreetingHistory
end

addon.optionsCategory = nil

local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("ADDON_LOADED")
initFrame:SetScript("OnEvent", function(self, event, loadedAddonName)
    if loadedAddonName ~= ADDON_NAME then
        return
    end

    addon.NormalizeDatabase()
    if addon.RegisterSettingsPanel then
        addon.RegisterSettingsPanel()
    end
    self:UnregisterEvent("ADDON_LOADED")
end)
